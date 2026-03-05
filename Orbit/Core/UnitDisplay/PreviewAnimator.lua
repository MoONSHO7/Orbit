-- [ PREVIEW ANIMATOR ]------------------------------------------------------------------------------
-- Drives animated bars, death/OOR transitions, and healer aura randomization on preview frames.
local _, Orbit = ...

Orbit.PreviewAnimator = {}
local PA = Orbit.PreviewAnimator

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local TICK_INTERVAL = 0.05
local PHASE_SPEED = 0.015
local HEALTH_AMPLITUDE = 0.18
local SHIELD_AMPLITUDE = 0.08
local SHIELD_BASE = 0.15
local SHIELD_FREQUENCY = 0.4
local NECROTIC_AMPLITUDE = 0.05
local NECROTIC_BASE = 0.08
local NECROTIC_FREQUENCY = 0.3
local DAMAGE_BAR_DECAY = 0.04
local TWO_PI = math.pi * 2
local OFFLINE_ALPHA = 0.35
local OOR_ALPHA = 0.55
local DEATH_FADE_RATE = 0.008
local REVIVE_RATE = 0.012
local RESHUFFLE_INTERVAL = 12
local AURA_TICK_INTERVAL = 1
local AURA_DURATION_MIN = 1
local AURA_DURATION_MAX = 5
local AURA_RESPAWN_MIN = 3
local AURA_RESPAWN_MAX = 8
local HEALER_TICK_INTERVAL = 3.0
local HEALER_SHOW_CHANCE = 0.6
local RAIDBUFF_SHOW_CHANCE = 0.7
local DEFENSIVE_SHOW_CHANCE = 0.15
local CC_SHOW_CHANCE = 0.12

-- [ BEHAVIOR TYPES ]--------------------------------------------------------------------------------
local B_NORMAL = 1
local B_DYING = 2
local B_DEAD = 3
local B_REVIVING = 4
local B_OOR = 5

-- [ SESSION REGISTRY ]------------------------------------------------------------------------------
-- Keyed by owner (plugin self), so Party/Raid/Boss can animate concurrently.
local sessions = {}
local ticker
local phase = 0
local globalElapsed = 0

local auraSessions = {}
local auraTicker

local healerSessions = {}
local healerTicker

-- [ BEHAVIOR ASSIGNMENT ]---------------------------------------------------------------------------
local function AssignRandomBehaviors(activeCfg)
    local candidates = {}
    for i, cfg in ipairs(activeCfg) do
        if cfg.behavior == B_NORMAL and not cfg.dead then candidates[#candidates + 1] = i end
    end
    if #candidates < 2 then return end
    for j = #candidates, 2, -1 do
        local k = math.random(1, j)
        candidates[j], candidates[k] = candidates[k], candidates[j]
    end
    local assigned = 0
    for _, idx in ipairs(candidates) do
        local cfg = activeCfg[idx]
        assigned = assigned + 1
        if assigned == 1 then
            cfg.canDie = true; cfg.dyingDelay = 2 + math.random() * 4; cfg.canOOR = false
        elseif assigned == 2 then
            cfg.canOOR = true; cfg.oorDelay = 2 + math.random() * 4; cfg.canDie = false
        else
            cfg.canDie = false; cfg.canOOR = false
        end
        cfg.showShield = (math.random() < 0.4)
        cfg.showNecrotic = (math.random() < 0.25)
        cfg.healthAmplitude = 0.10 + math.random() * 0.15
    end
end

-- [ BEHAVIOR TRANSITIONS ]--------------------------------------------------------------------------
local function TransitionBehavior(cfg, frame)
    local b = cfg.behavior
    if b == B_NORMAL then
        cfg.elapsed = cfg.elapsed + TICK_INTERVAL
        if cfg.canDie and cfg.elapsed > cfg.dyingDelay then
            cfg.behavior = B_DYING; cfg.elapsed = 0
        elseif cfg.canOOR and cfg.elapsed > cfg.oorDelay then
            cfg.behavior = B_OOR; cfg.oorDuration = 3 + math.random() * 4; cfg.elapsed = 0
        end
    elseif b == B_DYING then
        cfg.currentHealth = math.max(0, cfg.currentHealth - DEATH_FADE_RATE)
        frame.Health:SetMinMaxValues(0, 1)
        frame.Health:SetValue(cfg.currentHealth)
        if frame.HealthText and frame.HealthText:IsShown() then
            frame.HealthText:SetFormattedText("%.0f%%", cfg.currentHealth * 100)
        end
        if cfg.currentHealth <= 0 then
            cfg.currentHealth = 0
            cfg.behavior = B_DEAD; cfg.deadDuration = 3 + math.random() * 3; cfg.elapsed = 0
            frame.Health:SetValue(0)
            if frame.HealthText and frame.HealthText:IsShown() then frame.HealthText:SetText("Dead") end
            cfg.alpha = OFFLINE_ALPHA; frame:SetAlpha(OFFLINE_ALPHA)
            if frame.ResIcon then frame.ResIcon:SetAtlas("RaidFrame-Icon-Rez"); frame.ResIcon:Show() end
        end
        return true
    elseif b == B_DEAD then
        cfg.elapsed = cfg.elapsed + TICK_INTERVAL
        if cfg.elapsed > cfg.deadDuration then
            cfg.behavior = B_REVIVING; cfg.elapsed = 0
            if frame.ResIcon then frame.ResIcon:Hide() end
        end
        return true
    elseif b == B_REVIVING then
        cfg.currentHealth = math.min(cfg.baseHealth, cfg.currentHealth + REVIVE_RATE)
        frame.Health:SetMinMaxValues(0, 1)
        frame.Health:SetValue(cfg.currentHealth)
        if frame.HealthText and frame.HealthText:IsShown() then
            frame.HealthText:SetFormattedText("%.0f%%", cfg.currentHealth * 100)
        end
        if cfg.alpha < 1 then cfg.alpha = math.min(1, cfg.alpha + 0.02); frame:SetAlpha(cfg.alpha) end
        if cfg.currentHealth >= cfg.baseHealth then
            cfg.behavior = B_NORMAL; cfg.elapsed = 0; cfg.canDie = false; cfg.canOOR = false
            cfg.alpha = 1; frame:SetAlpha(1)
        end
        return true
    elseif b == B_OOR then
        cfg.elapsed = cfg.elapsed + TICK_INTERVAL
        if cfg.elapsed < cfg.oorDuration then
            if cfg.alpha > OOR_ALPHA then cfg.alpha = math.max(OOR_ALPHA, cfg.alpha - 0.02); frame:SetAlpha(cfg.alpha) end
        else
            if cfg.alpha < 1 then cfg.alpha = math.min(1, cfg.alpha + 0.02); frame:SetAlpha(cfg.alpha) end
            if cfg.alpha >= 0.99 then
                cfg.behavior = B_NORMAL; cfg.elapsed = 0; cfg.canOOR = false; cfg.canDie = false
                cfg.alpha = 1; frame:SetAlpha(1)
            end
        end
    end
    return false
end

-- [ ANIMATE OVERLAY BARS ]--------------------------------------------------------------------------
local function AnimateOverlayBars(frame, cfg, curPhase, offset)
    local healthTex = frame.Health:GetStatusBarTexture()
    local totalW = frame.Health:GetWidth()
    if frame.TotalAbsorbBar and cfg.showShield then
        local shieldWave = math.sin((curPhase + offset) * TWO_PI * SHIELD_FREQUENCY + 1.5)
        local shield = math.max(0, SHIELD_BASE + shieldWave * SHIELD_AMPLITUDE)
        frame.TotalAbsorbBar:SetMinMaxValues(0, 1)
        frame.TotalAbsorbBar:SetValue(shield)
        frame.TotalAbsorbBar:ClearAllPoints()
        frame.TotalAbsorbBar:SetWidth(totalW)
        frame.TotalAbsorbBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", 0, 0)
        frame.TotalAbsorbBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", 0, 0)
        frame.TotalAbsorbBar:Show()
        if frame.TotalAbsorbOverlay then
            frame.TotalAbsorbOverlay:Show()
            frame.TotalAbsorbOverlay:SetAllPoints(frame.TotalAbsorbBar:GetStatusBarTexture())
        end
    elseif frame.TotalAbsorbBar then
        frame.TotalAbsorbBar:Hide()
        if frame.TotalAbsorbOverlay then frame.TotalAbsorbOverlay:Hide() end
    end
    if frame.HealAbsorbBar and cfg.showNecrotic then
        local necWave = math.sin((curPhase + offset) * TWO_PI * NECROTIC_FREQUENCY + 3.0)
        local nec = math.max(0, NECROTIC_BASE + necWave * NECROTIC_AMPLITUDE)
        frame.HealAbsorbBar:SetMinMaxValues(0, 1)
        frame.HealAbsorbBar:SetValue(nec)
        frame.HealAbsorbBar:ClearAllPoints()
        frame.HealAbsorbBar:SetWidth(totalW)
        frame.HealAbsorbBar:SetPoint("TOPRIGHT", healthTex, "TOPRIGHT", 0, 0)
        frame.HealAbsorbBar:SetPoint("BOTTOMRIGHT", healthTex, "BOTTOMRIGHT", 0, 0)
        frame.HealAbsorbBar:Show()
    elseif frame.HealAbsorbBar then
        frame.HealAbsorbBar:Hide()
    end
end

-- [ CORE TICK ]-------------------------------------------------------------------------------------
local function AnimateTick()
    phase = (phase + PHASE_SPEED) % 1
    globalElapsed = globalElapsed + TICK_INTERVAL
    local shouldReshuffle = globalElapsed > RESHUFFLE_INTERVAL
    if shouldReshuffle then globalElapsed = 0 end

    for _, session in pairs(sessions) do
        if shouldReshuffle then AssignRandomBehaviors(session.cfg) end
        for i, frame in ipairs(session.frames) do
            if frame:IsShown() then
                local cfg = session.cfg[i]
                if cfg then
                    local skipNormal = TransitionBehavior(cfg, frame)
                    if not skipNormal and cfg.behavior ~= B_DEAD then
                        local offset = (i * 0.17) % 1
                        local wave = math.sin((phase + offset) * TWO_PI)
                        local hp = math.max(0.05, math.min(1.0, (cfg.baseHealth or 0.75) + wave * (cfg.healthAmplitude or HEALTH_AMPLITUDE)))
                        local prevHP = cfg.prevHealth
                        cfg.currentHealth = hp
                        frame.Health:SetMinMaxValues(0, 1)
                        frame.Health:SetValue(hp)
                        if frame.HealthDamageBar then
                            frame.HealthDamageBar:SetMinMaxValues(0, 1)
                            if hp < prevHP then
                                cfg.dmgBarVal = prevHP
                                frame.HealthDamageBar:SetValue(prevHP)
                                frame.HealthDamageBar:Show()
                                if frame.HealthDamageTexture then frame.HealthDamageTexture:Show() end
                            else
                                local decay = cfg.dmgBarVal - DAMAGE_BAR_DECAY
                                if decay <= hp then
                                    cfg.dmgBarVal = hp
                                    frame.HealthDamageBar:SetValue(hp)
                                    if frame.HealthDamageTexture then frame.HealthDamageTexture:Hide() end
                                else
                                    cfg.dmgBarVal = decay
                                    frame.HealthDamageBar:SetValue(decay)
                                end
                            end
                        end
                        AnimateOverlayBars(frame, cfg, phase, offset)
                        if frame.HealthText and frame.HealthText:IsShown() then
                            frame.HealthText:SetFormattedText("%.0f%%", hp * 100)
                        end
                        cfg.prevHealth = hp
                    end
                end
            end
        end
    end

    if not next(sessions) then ticker:Cancel(); ticker = nil end
end

-- [ AURA TICK ]-------------------------------------------------------------------------------------
local function RelayoutGroup(group)
    local c = group.container
    local col, row = 0, 0
    for _, icon in ipairs(group.icons) do
        if icon:IsShown() then
            icon:ClearAllPoints()
            col, row = Orbit.AuraLayout:PositionIcon(icon, c, c._justifyH, c._anchorY, col, row, c._iconSize, c._iconsPerRow)
        end
    end
end

local function AuraTick()
    local now = GetTime()
    local AP = Orbit.AuraPreview
    for _, session in pairs(auraSessions) do
        for i, frame in ipairs(session.frames) do
            if frame:IsShown() then
                local cfg = session.cfg[i]
                if cfg and cfg.groups then
                    for _, group in ipairs(cfg.groups) do
                        local changed = false
                        for j, slot in ipairs(group.slots) do
                            local icon = group.icons[j]
                            if icon and now >= slot.nextEvent then
                                if slot.active then
                                    icon:Hide()
                                    slot.active = false
                                    slot.nextEvent = now + math.random(AURA_RESPAWN_MIN, AURA_RESPAWN_MAX)
                                else
                                    local dur = math.random(AURA_DURATION_MIN, AURA_DURATION_MAX)
                                    icon.Icon:SetTexture(AP.GetSpellbookIcon())
                                    icon.Cooldown:SetCooldown(now, dur)
                                    icon:Show()
                                    slot.active = true
                                    slot.nextEvent = now + dur
                                end
                                changed = true
                            end
                        end
                        if changed then RelayoutGroup(group) end
                    end
                end
            end
        end
    end
    if not next(auraSessions) then auraTicker:Cancel(); auraTicker = nil end
end

-- [ HEALER AURA TICK ]------------------------------------------------------------------------------
local function HealerAuraTick()
    for _, session in pairs(healerSessions) do
        for i, frame in ipairs(session.frames) do
            if frame:IsShown() then
                local cfg = session.cfg[i]
                if cfg and cfg.healerSlots then
                    for _, slot in ipairs(cfg.healerSlots) do
                        local icon = frame[slot.key]
                        if icon then icon:SetShown(math.random() < HEALER_SHOW_CHANCE) end
                    end
                end
                if cfg and cfg.raidBuffKey and frame[cfg.raidBuffKey] then
                    frame[cfg.raidBuffKey]:SetShown(math.random() < RAIDBUFF_SHOW_CHANCE)
                end
                -- Rare defensive/CC icon toggling
                if frame.DefensiveIcon and not cfg.defensiveDisabled then
                    frame.DefensiveIcon:SetShown(math.random() < DEFENSIVE_SHOW_CHANCE)
                end
                if frame.CrowdControlIcon and not cfg.ccDisabled then
                    frame.CrowdControlIcon:SetShown(math.random() < CC_SHOW_CHANCE)
                end
            end
        end
    end
    if not next(healerSessions) then healerTicker:Cancel(); healerTicker = nil end
end

-- [ PUBLIC API ]------------------------------------------------------------------------------------
function PA:Start(owner, frames, cfgList)
    self:Stop(owner)
    for _, cfg in ipairs(cfgList) do
        cfg.prevHealth = cfg.baseHealth or 0.75
        cfg.currentHealth = cfg.baseHealth or 0.75
        cfg.dmgBarVal = cfg.baseHealth or 0.75
        cfg.elapsed = 0; cfg.alpha = 1
        cfg.behavior = cfg.behavior or B_NORMAL
        if cfg.showShield == nil then cfg.showShield = (math.random() < 0.4) end
        if cfg.showNecrotic == nil then cfg.showNecrotic = (math.random() < 0.2) end
        cfg.healthAmplitude = cfg.healthAmplitude or (0.10 + math.random() * 0.15)
    end
    AssignRandomBehaviors(cfgList)
    sessions[owner] = { frames = frames, cfg = cfgList }
    if not ticker then phase = 0; globalElapsed = 0; ticker = C_Timer.NewTicker(TICK_INTERVAL, AnimateTick) end
end

function PA:Stop(owner)
    local session = sessions[owner]
    if session then
        for _, frame in ipairs(session.frames) do
            if frame.HealthDamageBar then
                frame.HealthDamageBar:Hide()
                if frame.HealthDamageTexture then frame.HealthDamageTexture:Hide() end
            end
            if frame.TotalAbsorbBar then
                frame.TotalAbsorbBar:Hide()
                if frame.TotalAbsorbOverlay then frame.TotalAbsorbOverlay:Hide() end
            end
            if frame.HealAbsorbBar then frame.HealAbsorbBar:Hide() end
            if frame.ResIcon then frame.ResIcon:Hide() end
            frame:SetAlpha(1)
        end
        sessions[owner] = nil
    end
end

function PA:IsRunning() return ticker ~= nil end

-- [ AURA ANIMATION API ]---------------------------------------------------------------------------
function PA:StartAuras(owner, frames, cfgList)
    self:StopAuras(owner)
    local now = GetTime()
    for i, cfg in ipairs(cfgList) do
        local frame = frames[i]
        if frame:IsShown() and cfg.initAuras then
            cfg.groups = cfg.initAuras(frame)
            local offset = (i - 1) * 1.5
            for _, group in ipairs(cfg.groups) do
                group.slots = {}
                for j = 1, #group.icons do
                    group.slots[j] = { active = false, nextEvent = now + offset + math.random() * 3 + (j - 1) * 0.4 }
                end
            end
        end
    end
    auraSessions[owner] = { frames = frames, cfg = cfgList }
    if not auraTicker then auraTicker = C_Timer.NewTicker(AURA_TICK_INTERVAL, AuraTick) end
end

function PA:StopAuras(owner)
    local session = auraSessions[owner]
    if session then
        for _, frame in ipairs(session.frames) do Orbit.AuraPreview:HideFrameAuras(frame) end
    end
    auraSessions[owner] = nil
end

-- [ HEALER AURA ANIMATION API ]---------------------------------------------------------------------
function PA:StartHealerAuras(owner, frames, cfgList)
    self:StopHealerAuras(owner)
    healerSessions[owner] = { frames = frames, cfg = cfgList }
    -- Fire immediately
    for i, frame in ipairs(frames) do
        if frame:IsShown() then
            local cfg = cfgList[i]
            if cfg and cfg.healerSlots then
                for _, slot in ipairs(cfg.healerSlots) do
                    local icon = frame[slot.key]
                    if icon then icon:SetShown(math.random() < HEALER_SHOW_CHANCE) end
                end
            end
        end
    end
    if not healerTicker then healerTicker = C_Timer.NewTicker(HEALER_TICK_INTERVAL, HealerAuraTick) end
end

function PA:StopHealerAuras(owner)
    healerSessions[owner] = nil
end
