---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ MYTHIC+ TRACKER ]--------------------------------------------------------------------------------
local MODE_MPLUS = "mplus"
local TIMER_THROTTLE = 0.2
local TIMER_FONT_SIZE = 26
local FORCES_FONT_SIZE = 26   -- same size as the timer; the two lines are a centred pair
local CENTER_LINE = 13        -- half the line spacing: timer sits +CENTER_LINE, forces -CENTER_LINE, so the pair is centred on the orb
-- +2/+3 deadlines as fractions of par. With Challenger's Peril (affix 152) it's (par-90)*f+90 — the 90s the affix adds isn't scaled (matches WarpDeplete). The death penalty is already baked into GetWorldElapsedTime, so it is NOT added again here.
local PLUS2_FACTOR, PLUS3_FACTOR = 0.8, 0.6
local CHALLENGERS_PERIL_AFFIX = 152
local CHALLENGE_TIMER_TYPE = (Enum.WorldElapsedTimerTypes and Enum.WorldElapsedTimerTypes.ChallengeMode) or 1
local MYTHIC_KEYSTONE_DIFFICULTY = 8   -- GetInstanceInfo difficultyID for a keystone dungeon; the tracker lives until you leave it

local TIER_PLUS3   = { r = 1.00, g = 0.82, b = 0.35 }
local TIER_PLUS2   = { r = 0.78, g = 0.80, b = 0.86 }
local TIER_PLUS1   = { r = 0.45, g = 0.85, b = 0.45 }
local TIER_OVER    = { r = 0.95, g = 0.30, b = 0.25 }
local TIER_NEUTRAL = { r = 0.95, g = 0.95, b = 0.95 }
local TIER_BY_KEY  = { [3] = TIER_PLUS3, [2] = TIER_PLUS2, [1] = TIER_PLUS1, [-1] = TIER_OVER, [0] = TIER_NEUTRAL }
local FORCES_COLOR = { r = 0.88, g = 0.88, b = 0.90 }
local BOSS_DONE    = { r = 0.55, g = 0.82, b = 0.40 }
local BOSS_TODO    = { r = 0.78, g = 0.78, b = 0.78 }
local LABEL_COLOR  = { r = 0.70, g = 0.70, b = 0.70 }
local GOLD         = { r = 1.00, g = 0.82, b = 0.25 }

-- Two reading ticks marking the +3 / +2 deadlines, positioned per-run (CP-aware) by _PositionMPlusTicks. Fill sweeps bottom-origin clockwise; flip TICK_DIR if a /reload shows them mirrored.
local TICK_START, TICK_DIR = -math.pi / 2, -1

-- Info panel (right of the orb). Width matches the loot-roll panels so the shared side stack (_LayoutRolls) aligns.
local PANEL_W = 200
local PANEL_PAD = 9
local AFFIX_SIZE, AFFIX_GAP, MAX_AFFIX = 16, 4, 5
local MAX_BOSS = 6
local HEADER_SIZE, STAT_SIZE, BOSS_SIZE = 14, 12, 12
local ROW_H, SECTION_GAP = 16, 7

-- [ SETUP ]------------------------------------------------------------------------------------------
function Plugin:SetupMythicPlus()
    -- Centre timer (top) + forces-remaining % (bottom) + ticks are rebuilt every OnLoad: a live re-enable recreates self.frame (like SetupFillModes' cracked metal).
    local size = self.frame:GetWidth()
    -- Timer (top) + forces % (bottom): same size, both centred, the pair straddling the orb's middle (timer +CENTER_LINE, forces -CENTER_LINE).
    local timer = self.frame.Center:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timer:SetPoint("CENTER", self.frame.Center, "CENTER", 0, CENTER_LINE)
    timer:SetJustifyH("CENTER")
    timer:SetShadowColor(0, 0, 0, 0.95)
    timer:SetShadowOffset(1.5, -1.5)
    timer:Hide()
    self.frame.MPlusTimer = timer

    local forces = self.frame.Center:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    forces:SetPoint("CENTER", self.frame.Center, "CENTER", 0, -CENTER_LINE)
    forces:SetJustifyH("CENTER")
    forces:SetShadowColor(0, 0, 0, 0.95)
    forces:SetShadowOffset(1.5, -1.5)
    forces:Hide()
    self.frame.MPlusForces = forces

    self:_BuildMPlusTicks()
    self:_BuildMPlusPanel()   -- must run every OnLoad: stores the panel ref on the (recreated) self.frame
    self:ApplyMPlusFont()

    if self._mplusHooked then
        self:_SyncMPlusState()
        return
    end
    self._mplusHooked = true

    -- Dedicated frame (never the shared EventBus): the prey-hunt removal showed instanced-run reads on the shared frame cascade taint into EditMode.
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHALLENGE_MODE_START")
    f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    f:RegisterEvent("CHALLENGE_MODE_RESET")
    f:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    f:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    f:RegisterEvent("SCENARIO_UPDATE")
    f:RegisterEvent("WORLD_STATE_TIMER_START")
    f:RegisterEvent("WORLD_STATE_TIMER_STOP")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, ...) self:OnMPlusEvent(event, ...) end)
    self._mplusFrame = f

    self:_SyncMPlusState()
end

function Plugin:ApplyMPlusFont()
    local font = Orbit.db.GlobalSettings.Font
    if self.frame and self.frame.MPlusTimer then Orbit.Skin:SkinText(self.frame.MPlusTimer, { font = font, textSize = TIMER_FONT_SIZE }) end
    if self.frame and self.frame.MPlusForces then Orbit.Skin:SkinText(self.frame.MPlusForces, { font = font, textSize = FORCES_FONT_SIZE }) end
    if self.frame and self.frame.MPlusPanel then self:_StyleMPlusPanel() end
end

-- [ EVENTS ]-----------------------------------------------------------------------------------------
function Plugin:OnMPlusEvent(event, ...)
    if event == "CHALLENGE_MODE_START" then
        if self._mplusResults then self:_EndMPlus() end   -- a new key supersedes a lingering results screen
        self:_SyncMPlusState()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- The tracker lives until you leave the dungeon: a loading screen out of the keystone instance ends it (results included).
        if (self._mplusActive or self._mplusResults) and select(3, GetInstanceInfo()) ~= MYTHIC_KEYSTONE_DIFFICULTY then
            self:_EndMPlus()
        end
        self:_SyncMPlusState()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        self:_OnMPlusComplete()
    elseif event == "CHALLENGE_MODE_RESET" then
        self:_EndMPlus()
    elseif event == "WORLD_STATE_TIMER_START" then
        if self._mplusActive and not self._mplusResults then self:_BindTimer(...) end
    elseif event == "CHALLENGE_MODE_DEATH_COUNT_UPDATED" then
        if self._mplusActive and not self._mplusResults then self:_RefreshDeaths(); self:OnEvent() end   -- never during the hold: it would mutate the frozen final stats
    elseif event == "SCENARIO_CRITERIA_UPDATE" or event == "SCENARIO_UPDATE" then
        if self._mplusActive and not self._mplusResults then self:_RefreshForces(); self:OnEvent() end   -- a trailing criteria update after completion must not overwrite the final forces
    end
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:_SyncMPlusState()
    if not self:GetSetting(self.system, "MPlusEnabled") then
        if self._mplusActive or self._mplusResults then self:_EndMPlus() end
        return
    end
    if self._mplusResults then return end   -- holding the results tracker; leaving / a new key / reset clears it
    local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    if mapID then
        if not self._mplusActive then
            -- Only START for a LIVE key: the map id stays set after completion while you're still in the instance, so a /reload there must NOT resurrect the run (IsChallengeModeActive goes false at completion — matches WarpDeplete).
            local liveKey = not C_ChallengeMode.IsChallengeModeActive or C_ChallengeMode.IsChallengeModeActive()
            if liveKey then self:_BeginMPlus(mapID) end
        else
            self:_SetBlizMPlusHidden(self:GetSetting(self.system, "ReplaceBlizzardTimer"))   -- re-apply live if the toggle changed
            self:_BindTimerFromActive()   -- re-sync the live clock after a /reload mid-key
            self:_ComputeMPlusThresholds()
            self:_PositionMPlusTicks(); self:_SetMPlusTicksShown(true)   -- re-show the ticks after a re-sync (they don't persist a /reload)
            self:_RefreshForces(); self:_RefreshDeaths()
            self:UpdateBar()
        end
    elseif self._mplusActive then
        self:_EndMPlus()
    end
end

function Plugin:_BeginMPlus(mapID)
    self._mplusActive = true
    self._mplusResults = false
    self._mplusMapID = mapID
    self._mplusBossKills, self._mplusBossSeen = {}, {}
    self._mplusAffixFid, self._mplusPanelSig = {}, nil
    self._mplusTierKey = nil
    self:_RefreshMapInfo()
    local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
    self._mplusLevel = level or 0
    self._mplusAffixes = affixes or {}
    self._mplusHasPeril = false
    for _, id in ipairs(self._mplusAffixes) do
        if id == CHALLENGERS_PERIL_AFFIX then self._mplusHasPeril = true end
    end
    self:_ComputeMPlusThresholds()
    self:_PositionMPlusTicks()
    self:_RefreshDeaths()
    self:_BindTimerFromActive()   -- bind the clock before the first forces read so kill-time stamps are valid
    self:_RefreshForces()
    self:_StartMPlusDriver()
    self:_SetMPlusTicksShown(true)
    if self:GetSetting(self.system, "ReplaceBlizzardTimer") then self:_SetBlizMPlusHidden(true) end
    self:RevealOrb()
    self:UpdateBar()
end

function Plugin:_EndMPlus()
    self._mplusActive, self._mplusResults = false, false
    if self._mplusDriver then self._mplusDriver:Hide() end
    if self.frame and self.frame.MPlusTimer then self.frame.MPlusTimer:Hide() end
    if self.frame and self.frame.MPlusForces then self.frame.MPlusForces:Hide() end
    self:_SetMPlusTicksShown(false)
    if self.frame and self.frame.MPlusPanel then self.frame.MPlusPanel:Hide() end
    self:_SetBlizMPlusHidden(false)
    if self.frame then self:UpdateBar(); self:ConcealOrb() end
end

function Plugin:_OnMPlusComplete()
    if not self._mplusActive then return end   -- already wrapped up (e.g. a duplicate CHALLENGE_MODE_COMPLETED)
    local info = C_ChallengeMode.GetChallengeCompletionInfo and C_ChallengeMode.GetChallengeCompletionInfo()
    self:_FinishMPlus(info and info.onTime)
end

-- Run's over. Drop out of the LIVE state (silencing ends → Blizzard's completion/vault/loot toasts come back; we never override Blizzard's ChallengeMode toast), freeze the clock, and play the transient "+N" celebration. It takes over the centre, plays out, then the centre RETURNS to the frozen timer/forces — the tracker stays in MODE_MPLUS until you leave the instance.
function Plugin:_FinishMPlus(timed)
    if not self._mplusActive then return end
    if not self:GetSetting(self.system, "MPlusEnabled") then self:_EndMPlus(); return end
    local level = self._mplusLevel or 0
    self._mplusActive, self._mplusResults = false, true
    if self._mplusDriver then self._mplusDriver:Hide() end   -- freeze the clock at the final time
    self:_SetBlizMPlusHidden(false)                          -- hand Blizzard's tracker + completion toast back
    self:PlayMPlusCompleteFlourish(level, timed)
    self:UpdateBar()
end

-- [ DATA READS ]-------------------------------------------------------------------------------------
function Plugin:_RefreshMapInfo()
    local name, _, timeLimit = C_ChallengeMode.GetMapUIInfo(self._mplusMapID)
    self._mplusName = name or ""
    self._mplusTimeLimit = timeLimit or 0
end

-- +2/+3 deadlines (absolute seconds). Challenger's Peril adds a flat 90s to par that isn't scaled into the thresholds.
function Plugin:_ComputeMPlusThresholds()
    local limit = self._mplusTimeLimit or 0
    if self._mplusHasPeril then
        local base = limit - 90
        self._mplusPlus2, self._mplusPlus3 = base * PLUS2_FACTOR + 90, base * PLUS3_FACTOR + 90
    else
        self._mplusPlus2, self._mplusPlus3 = limit * PLUS2_FACTOR, limit * PLUS3_FACTOR
    end
end

function Plugin:_RefreshDeaths()
    local count, lost = C_ChallengeMode.GetDeathCount()
    self._mplusDeaths = count or 0
    self._mplusTimeLost = lost or 0
end

-- Reuses the forces table + pools boss entry tables across the frequent SCENARIO_CRITERIA_UPDATE events (no per-event allocation).
function Plugin:_RefreshForces()
    self._mplusForces = nil
    self._mplusBosses = self._mplusBosses or {}
    local bosses, n = self._mplusBosses, 0
    local C = C_ScenarioInfo
    if C and C.GetScenarioStepInfo and C.GetCriteriaInfo then
        local step = C.GetScenarioStepInfo()
        for i = 1, (step and step.numCriteria or 0) do
            local info = C.GetCriteriaInfo(i)
            if info then
                if info.isWeightedProgress then
                    -- quantityString carries the absolute count (despite a trailing %); the raw .quantity field reads as a count that can exceed the total. Mirror WarpDeplete.
                    local qs = info.quantityString
                    if issecretvalue(qs) then qs = nil end
                    local t = self._forcesData or {}
                    self._forcesData = t
                    t.current = qs and tonumber(qs:match("%d+")) or 0
                    t.total = info.totalQuantity or 0
                    self._mplusForces = t
                else
                    local name, done = info.description, info.completed
                    n = n + 1
                    local b = bosses[n] or {}
                    bosses[n] = b
                    b.name, b.done = name, done
                    -- Stamp the kill time only on a watched alive -> dead transition; a boss already dead when we sync (e.g. /reload mid-key) is never "seen alive", so it shows no fabricated time.
                    if name and self._mplusBossSeen then
                        if issecretvalue(done) or not done then
                            self._mplusBossSeen[name] = true
                        elseif self._mplusBossSeen[name] and self._mplusBossKills[name] == nil then
                            self._mplusBossKills[name] = math.floor(self:_MPlusElapsed())
                        end
                    end
                end
            end
        end
    end
    for i = #bosses, n + 1, -1 do bosses[i] = nil end   -- trim leftover pooled entries
    if self._mplusTimeLimit == 0 then   -- GetMapUIInfo may have returned nothing at run start
        self:_RefreshMapInfo()
        if self._mplusTimeLimit > 0 then self:_ComputeMPlusThresholds(); self:_PositionMPlusTicks() end
    end
end

-- Forces REMAINING as a 0-100 percentage (counts down to 0 as trash is cleared); never negative on overkill.
function Plugin:_MPlusForcesRemaining()
    local f = self._mplusForces
    if not f or not f.total or f.total <= 0 then return 100 end
    return math.max(0, 100 - math.min(f.current / f.total * 100, 100))
end

-- Forces CLEARED as a 0-1 fraction (the radial fills toward a full clear); the hover view of the bar.
function Plugin:_MPlusForcesProgress()
    local f = self._mplusForces
    if not f or not f.total or f.total <= 0 then return 0 end
    return math.min(f.current / f.total, 1)
end

-- [ LIVE CLOCK ]-------------------------------------------------------------------------------------
-- Blizzard's pattern: snapshot the C-side elapsed once, then advance it locally by OnUpdate's delta (no per-frame C poll, no GetTime).
function Plugin:_BindTimer(timerID)
    if not (timerID and GetWorldElapsedTime) then return end
    local _, elapsed, ttype = GetWorldElapsedTime(timerID)
    if ttype ~= CHALLENGE_TIMER_TYPE then return end
    self._mplusTimerID = timerID
    self._mplusBaseTime = elapsed or 0
    self._mplusTimeSince = 0
end

function Plugin:_BindTimerFromActive()
    if not (GetWorldElapsedTimers and GetWorldElapsedTime) then return end
    for _, timerID in ipairs({ GetWorldElapsedTimers() }) do
        local _, elapsed, ttype = GetWorldElapsedTime(timerID)
        if ttype == CHALLENGE_TIMER_TYPE then
            self._mplusTimerID = timerID
            self._mplusBaseTime = elapsed or 0
            self._mplusTimeSince = 0
            return
        end
    end
end

-- The death penalty is already in GetWorldElapsedTime (Blizzard adds it live), so elapsed is the effective run time — timeLost is NOT added again (that would double-count). It's shown only on the deaths line.
function Plugin:_MPlusElapsed()
    return (self._mplusBaseTime or 0) + (self._mplusTimeSince or 0)
end

function Plugin:_MPlusTierKey()
    local limit = self._mplusTimeLimit or 0
    if limit <= 0 then return 0 end
    local e = self:_MPlusElapsed()
    if e >= limit then return -1 end
    if e <= (self._mplusPlus3 or 0) then return 3 end
    if e <= (self._mplusPlus2 or 0) then return 2 end
    return 1
end

function Plugin:_StartMPlusDriver()
    if not self._mplusDriver then
        local d = CreateFrame("Frame", nil, UIParent)
        d:Hide()
        d:SetScript("OnUpdate", function(driver, elapsed)
            self._mplusTimeSince = (self._mplusTimeSince or 0) + elapsed
            self._mplusTick = (self._mplusTick or 0) + elapsed
            if self._mplusTick < TIMER_THROTTLE then return end
            self._mplusTick = 0
            if not self._mplusActive then driver:Hide(); return end   -- completion stops the driver, freezing the clock
            self:_UpdateMPlusFill()     -- the radial fills with the live timer
            self:_UpdateMPlusCenter()   -- centre: time remaining + forces remaining
            -- A tier crossing changes the panel projection, so refresh the bar then (not every tick).
            local key = self:_MPlusTierKey()
            if key ~= self._mplusTierKey then self._mplusTierKey = key; self:UpdateBar() end
        end)
        self._mplusDriver = d
    end
    self._mplusTick = TIMER_THROTTLE
    self._mplusDriver:Show()
end

-- [ RADIAL: FILL + TICKS ]---------------------------------------------------------------------------
-- The fill (now the dungeon timer) carries the projected-pace tier colour.
function Plugin:_MPlusTierColor()
    return TIER_BY_KEY[self:_MPlusTierKey()] or TIER_NEUTRAL
end

-- The radial fills with the live timer (elapsed / par), tier-coloured. Plain non-secret numbers, so the Lua division is safe.
function Plugin:_UpdateMPlusFill()
    local fill = self.frame and self.frame.Fill
    if not fill then return end
    if self._hovered then   -- hover swaps the bar to forces-cleared progress (ticks hidden by the hover handler)
        fill:SetSwipeColor(FORCES_COLOR.r, FORCES_COLOR.g, FORCES_COLOR.b, 1)
        CooldownFrame_SetDisplayAsPercentage(fill, self:_MPlusForcesProgress())
        return
    end
    local col = self:_MPlusTierColor()
    fill:SetSwipeColor(col.r, col.g, col.b, col.a or 1)
    local limit = self._mplusTimeLimit or 0
    CooldownFrame_SetDisplayAsPercentage(fill, limit > 0 and math.min(self:_MPlusElapsed() / limit, 1) or 0)
end

function Plugin:_BuildMPlusTicks()
    local size = self.frame:GetWidth()
    -- On borderHost (above the fill, where the ring-crack overlay also lives) so the ticks draw OVER the bar — Content-level textures render UNDER the fill/border child frames and were invisible.
    local host = self.frame.Border:GetParent()
    self.frame.MPlusTicks = {}
    for _ = 1, 2 do
        local tick = host:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(1, 1, 1, 1)   -- clean solid white pixel tick
        tick:SetSize(size * 0.028, size * 0.09)
        if tick.SetSnapToPixelGrid then tick:SetSnapToPixelGrid(false) end   -- keep the edges crisp, not texel-snapped/blurred
        if tick.SetTexelSnappingBias then tick:SetTexelSnappingBias(0) end
        tick:Hide()
        self.frame.MPlusTicks[#self.frame.MPlusTicks + 1] = tick
    end
end

-- Place the two ticks at the +3 / +2 deadline fractions of the timer bar (CP-aware).
function Plugin:_PositionMPlusTicks()
    local ticks = self.frame and self.frame.MPlusTicks
    if not ticks then return end
    local limit = self._mplusTimeLimit or 0
    local fracs = {
        limit > 0 and (self._mplusPlus3 or 0) / limit or PLUS3_FACTOR,
        limit > 0 and (self._mplusPlus2 or 0) / limit or PLUS2_FACTOR,
    }
    local size = self.frame:GetWidth()
    local r = size * 0.42   -- band centre, so the tick sits on the fill track
    for i, tick in ipairs(ticks) do
        local angle = TICK_START + TICK_DIR * fracs[i] * 2 * math.pi
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", self.frame.Content, "CENTER", r * math.cos(angle), r * math.sin(angle))
        tick:SetRotation(angle - math.pi / 2)
    end
end

function Plugin:_SetMPlusTicksShown(show)
    if not self.frame or not self.frame.MPlusTicks then return end
    for _, tick in ipairs(self.frame.MPlusTicks) do tick:SetShown(show) end
end

-- [ CENTRE: TIMER + FORCES ]-------------------------------------------------------------------------
-- Centre shows the remaining time (top, tier-coloured) + forces remaining % (bottom). Yields to a flourish and to the durability warning, re-asserted from UpdateBar.
function Plugin:_UpdateMPlusCenter()
    local timer, forces = self.frame and self.frame.MPlusTimer, self.frame and self.frame.MPlusForces
    if not timer then return end
    local duraYield = self._mplusActive and self:_DuraWarnActive()   -- the durability warning only competes during the live run, not the frozen results tracker
    if not ((self._mplusActive or self._mplusResults) and self._event == nil and not duraYield) then
        timer:Hide(); if forces then forces:Hide() end
        return
    end
    local limit = self._mplusTimeLimit or 0
    local col = self:_MPlusTierColor()
    if limit <= 0 then
        timer:SetText(SecondsToClock(math.floor(self:_MPlusElapsed())))
    else
        local remaining = limit - self:_MPlusElapsed()
        if remaining >= 0 then timer:SetText(SecondsToClock(math.floor(remaining)))
        else timer:SetText("-" .. SecondsToClock(math.floor(-remaining))) end
    end
    timer:SetTextColor(col.r, col.g, col.b)
    timer:Show()
    if forces then
        forces:SetText(("%d%%"):format(self:_MPlusForcesRemaining()))
        forces:SetTextColor(FORCES_COLOR.r, FORCES_COLOR.g, FORCES_COLOR.b)
        forces:Show()
    end
end

-- The radial = the dungeon timer (elapsed / par). The driver keeps it live; this is the on-event seed.
function Plugin:MythicPlusRecord()
    local label = (self._mplusLevel and self._mplusLevel > 0) and L.PLU_SB_V2_MPLUS_KEY_F:format(self._mplusLevel) or ""
    local name = self._mplusName ~= "" and self._mplusName or label
    if self._hovered then   -- hover seeds the radial (+ tooltip) with the forces bar instead of the timer
        local f = self._mplusForces
        return { mode = MODE_MPLUS, name = name, level = label,
            current = f and f.current or 0, max = (f and f.total and f.total > 0) and f.total or 1, color = FORCES_COLOR }
    end
    return {
        mode = MODE_MPLUS,
        name = name,
        level = label,
        current = math.floor(self:_MPlusElapsed()), max = (self._mplusTimeLimit or 0) > 0 and self._mplusTimeLimit or 1,
        color = self:_MPlusTierColor(),
    }
end

-- [ INFO PANEL ]-------------------------------------------------------------------------------------
local function MakeStat(panel)
    local l = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); l:SetJustifyH("LEFT")
    local v = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); v:SetJustifyH("RIGHT")
    panel._stats[#panel._stats + 1] = l
    panel._stats[#panel._stats + 1] = v
    return l, v
end

function Plugin:_BuildMPlusPanel()
    -- The panel lives on UIParent (persists across a live re-enable); just re-point the recreated frame's field at it.
    if self._mplusPanel then self.frame.MPlusPanel = self._mplusPanel; return end
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetWidth(PANEL_W)
    panel:SetFrameStrata("MEDIUM")
    panel:Hide()
    Orbit.Engine.Pixel:Enforce(panel)
    panel._stats = {}

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(panel)
    panel.bg = bg
    Orbit.Skin:RegisterMaskedSurface(panel, bg)

    panel.Header = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); panel.Header:SetJustifyH("LEFT"); panel.Header:SetWordWrap(false)
    panel.KeyLevel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); panel.KeyLevel:SetJustifyH("RIGHT")

    panel.Affix = {}
    for _ = 1, MAX_AFFIX do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(AFFIX_SIZE, AFFIX_SIZE)
        local t = b:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(b); b.Icon = t
        b:SetScript("OnEnter", function(self2)
            if not self2._affixID then return end
            GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
            local n, d = C_ChallengeMode.GetAffixInfo(self2._affixID)
            if n then GameTooltip:SetText(n) end
            if d then GameTooltip:AddLine(d, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:Hide()
        panel.Affix[#panel.Affix + 1] = b
    end

    panel.ForcesL, panel.ForcesV = MakeStat(panel)
    panel.DeathsL, panel.DeathsV = MakeStat(panel)
    panel.ProjL, panel.ProjV = MakeStat(panel)
    panel.Plus2L, panel.Plus2V = MakeStat(panel)
    panel.Plus3L, panel.Plus3V = MakeStat(panel)

    panel.Divider = panel:CreateTexture(nil, "ARTWORK")
    panel.Divider:SetColorTexture(1, 1, 1, 0.12)
    panel.Divider:SetHeight(1)
    panel.Divider:Hide()
    panel.BossHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); panel.BossHeader:SetJustifyH("LEFT"); panel.BossHeader:Hide()

    panel.Boss = {}
    for _ = 1, MAX_BOSS do
        local check = panel:CreateTexture(nil, "ARTWORK"); check:SetSize(12, 12); check:Hide()
        local name = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); name:SetJustifyH("LEFT"); name:SetWordWrap(false); name:Hide()
        local time = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); time:SetJustifyH("RIGHT"); time:Hide()
        panel.Boss[#panel.Boss + 1] = { Check = check, Name = name, Time = time }
    end

    self._mplusPanel = panel
    self.frame.MPlusPanel = panel
    self:_StyleMPlusPanel()
end

-- Re-read theme bg/border/fonts; per-line colours are set in _RefreshMPlusPanel.
function Plugin:_StyleMPlusPanel()
    local panel = self.frame and self.frame.MPlusPanel
    if not panel then return end
    local gs = Orbit.db.GlobalSettings
    local c = Orbit.Skin:GetBackgroundColor()
    panel.bg:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    Orbit.Skin:SkinBorder(panel, panel, (gs and gs.BorderSize) or 1)
    Orbit.Skin:SkinText(panel.Header, { font = gs and gs.Font, textSize = HEADER_SIZE })
    Orbit.Skin:SkinText(panel.KeyLevel, { font = gs and gs.Font, textSize = HEADER_SIZE })
    Orbit.Skin:SkinText(panel.BossHeader, { font = gs and gs.Font, textSize = STAT_SIZE })
    for _, fs in ipairs(panel._stats) do Orbit.Skin:SkinText(fs, { font = gs and gs.Font, textSize = STAT_SIZE }) end
    for _, row in ipairs(panel.Boss) do
        Orbit.Skin:SkinText(row.Name, { font = gs and gs.Font, textSize = BOSS_SIZE })
        Orbit.Skin:SkinText(row.Time, { font = gs and gs.Font, textSize = BOSS_SIZE })
    end
end

-- [ PANEL COLLAPSE ]---------------------------------------------------------------------------------
-- Toggled by left-clicking the orb during a key (StatusWidget OnMouseUp); persisted per profile, default collapsed.
function Plugin:_ToggleMPlusCollapsed()
    self:SetSetting(self.system, "MPlusCollapsed", not self:GetSetting(self.system, "MPlusCollapsed"))
    self:_RefreshMPlusPanel()
end

-- Count of affixes that currently resolve an icon (resolves + caches each fileID once; constant once loaded). Drives both the layout and the shape signature so a late-resolving icon forces a relayout.
function Plugin:_MPlusAffixCount()
    self._mplusAffixFid = self._mplusAffixFid or {}
    local count = 0
    if self._mplusAffixes and C_ChallengeMode.GetAffixInfo then
        for i = 1, MAX_AFFIX do
            local id = self._mplusAffixes[i]
            if id then
                local fid = self._mplusAffixFid[id]
                if not fid then
                    fid = select(3, C_ChallengeMode.GetAffixInfo(id))
                    if fid then self._mplusAffixFid[id] = fid end
                end
                if fid then count = count + 1 end
            end
        end
    end
    return count
end

-- A signature of the panel's row SHAPE (counts/visibility), not its values; an unchanged signature means no SetPoint relayout is needed.
function Plugin:_MPlusPanelSig()
    return (self._mplusBosses and #self._mplusBosses or 0)
        .. "|" .. ((self._mplusDeaths or 0) > 0 and 1 or 0)
        .. "|" .. self:_MPlusAffixCount()
        .. "|" .. ((self._mplusTimeLimit or 0) > 0 and 1 or 0)
end

-- Fast path: refresh only the dynamic text/colours on the already-positioned rows (header, forces, deaths, projection, boss check/colour/time) — no SetPoint.
function Plugin:_UpdateMPlusPanelValues()
    local panel = self.frame.MPlusPanel
    panel.Header:SetText(self._mplusName ~= "" and self._mplusName or L.PLU_SB_V2_MPLUS_KEY_F:format(self._mplusLevel or 0))
    panel.ForcesV:SetText(("%d%%"):format(self:_MPlusForcesRemaining()))
    if (self._mplusDeaths or 0) > 0 then
        panel.DeathsV:SetText(L.PLU_SB_V2_MPLUS_DEATHS_F:format(self._mplusDeaths, SecondsToClock(self._mplusTimeLost or 0)))
    end
    if (self._mplusTimeLimit or 0) > 0 then
        local key = self:_MPlusTierKey()
        local pcol = key == 3 and TIER_PLUS3 or key == 2 and TIER_PLUS2 or key == 1 and TIER_PLUS1 or TIER_OVER
        panel.ProjV:SetText(key > 0 and L.PLU_SB_V2_MPLUS_PROJECTED_F:format(key) or L.PLU_SB_V2_MPLUS_DEPLETED)
        panel.ProjV:SetTextColor(pcol.r, pcol.g, pcol.b)
    end
    for i, row in ipairs(panel.Boss) do
        local b = self._mplusBosses and self._mplusBosses[i]
        if b then
            local done = b.done
            if issecretvalue(done) then done = false end
            local c = done and BOSS_DONE or BOSS_TODO
            if done then row.Check:SetAtlas("ui-questtracker-tracker-check"); row.Check:Show() else row.Check:Hide() end
            row.Name:SetTextColor(c.r, c.g, c.b)
            local kt = self._mplusBossKills and self._mplusBossKills[b.name]
            row.Time:SetText(kt and SecondsToClock(kt) or ""); row.Time:SetTextColor(c.r, c.g, c.b)
        end
    end
end

function Plugin:_RefreshMPlusPanel()
    local panel = self.frame and self.frame.MPlusPanel
    if not panel then return end
    local show = self._mplusActive or self._mplusResults
    -- The results tracker forces the panel open (ignores MPlusCollapsed) so people can read the run.
    if not show or (self:GetSetting(self.system, "MPlusCollapsed") and not self._mplusResults) then panel:Hide(); self._mplusPanelSig = nil; self:_LayoutRolls(); return end

    local sig = self:_MPlusPanelSig()
    if panel:IsShown() and sig == self._mplusPanelSig then self:_UpdateMPlusPanelValues(); return end
    self._mplusPanelSig = sig

    local pad, y = PANEL_PAD, PANEL_PAD

    panel.Header:SetText(self._mplusName ~= "" and self._mplusName or L.PLU_SB_V2_MPLUS_KEY_F:format(self._mplusLevel or 0))
    panel.Header:ClearAllPoints(); panel.Header:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y)
    panel.Header:SetPoint("RIGHT", panel, "TOPRIGHT", -pad - 40, 0)
    panel.KeyLevel:SetText((self._mplusLevel and self._mplusLevel > 0) and ("+" .. self._mplusLevel) or "")
    panel.KeyLevel:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
    panel.KeyLevel:ClearAllPoints(); panel.KeyLevel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -y)
    y = y + HEADER_SIZE + 6

    self._mplusAffixFid = self._mplusAffixFid or {}
    local shown = 0
    for i, b in ipairs(panel.Affix) do
        local id = self._mplusAffixes and self._mplusAffixes[i]
        local fid = id and self._mplusAffixFid[id]
        if id and not fid and C_ChallengeMode.GetAffixInfo then   -- resolve each affix icon once, then cache (constant for the run)
            fid = select(3, C_ChallengeMode.GetAffixInfo(id))
            if fid then self._mplusAffixFid[id] = fid end
        end
        if id and fid then
            b._affixID = id
            b.Icon:SetTexture(fid)
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", panel, "TOPLEFT", pad + shown * (AFFIX_SIZE + AFFIX_GAP), -y)
            b:Show()
            shown = shown + 1
        else
            b:Hide()
        end
    end
    if shown > 0 then y = y + AFFIX_SIZE + SECTION_GAP end

    local function statRow(l, v, labelText, valueText, col)
        l:SetText(labelText); l:SetTextColor(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b)
        l:ClearAllPoints(); l:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y); l:Show()
        v:SetText(valueText); v:SetTextColor(col.r, col.g, col.b)
        v:ClearAllPoints(); v:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -y); v:Show()
        y = y + ROW_H
    end
    statRow(panel.ForcesL, panel.ForcesV, L.PLU_SB_V2_MPLUS_FORCES, ("%d%%"):format(self:_MPlusForcesRemaining()), TIER_NEUTRAL)
    if self._mplusDeaths and self._mplusDeaths > 0 then
        statRow(panel.DeathsL, panel.DeathsV, L.PLU_SB_V2_MPLUS_DEATHS, L.PLU_SB_V2_MPLUS_DEATHS_F:format(self._mplusDeaths, SecondsToClock(self._mplusTimeLost or 0)), TIER_OVER)
    else
        panel.DeathsL:Hide(); panel.DeathsV:Hide()
    end
    local limit = self._mplusTimeLimit or 0
    if limit > 0 then
        local key = self:_MPlusTierKey()
        local pcol = TIER_BY_KEY[key] or TIER_NEUTRAL
        local ptext = key > 0 and L.PLU_SB_V2_MPLUS_PROJECTED_F:format(key) or L.PLU_SB_V2_MPLUS_DEPLETED
        statRow(panel.ProjL, panel.ProjV, L.PLU_SB_V2_MPLUS_PROJECTED, ptext, pcol)
        statRow(panel.Plus2L, panel.Plus2V, L.PLU_SB_V2_MPLUS_PLUS2, SecondsToClock(math.floor(self._mplusPlus2 or 0)), TIER_PLUS2)
        statRow(panel.Plus3L, panel.Plus3V, L.PLU_SB_V2_MPLUS_PLUS3, SecondsToClock(math.floor(self._mplusPlus3 or 0)), TIER_PLUS3)
    else
        for _, fs in ipairs({ panel.ProjL, panel.ProjV, panel.Plus2L, panel.Plus2V, panel.Plus3L, panel.Plus3V }) do fs:Hide() end
    end

    local bosses = self._mplusBosses or {}
    if #bosses > 0 then
        y = y + 2
        panel.Divider:ClearAllPoints()
        panel.Divider:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y)
        panel.Divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -y)
        panel.Divider:Show()
        y = y + SECTION_GAP
        panel.BossHeader:SetText(L.PLU_SB_V2_MPLUS_BOSSES); panel.BossHeader:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
        panel.BossHeader:ClearAllPoints(); panel.BossHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y); panel.BossHeader:Show()
        y = y + ROW_H
    else
        panel.Divider:Hide(); panel.BossHeader:Hide()
    end
    for i, row in ipairs(panel.Boss) do
        local b = bosses[i]
        if b then
            local done = b.done
            if issecretvalue(done) then done = false end
            local c = done and BOSS_DONE or BOSS_TODO
            row.Check:ClearAllPoints(); row.Check:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y + 1)
            if done then row.Check:SetAtlas("ui-questtracker-tracker-check"); row.Check:Show() else row.Check:Hide() end
            row.Name:SetText(b.name or ""); row.Name:SetTextColor(c.r, c.g, c.b)
            row.Name:ClearAllPoints()
            row.Name:SetPoint("TOPLEFT", panel, "TOPLEFT", pad + 16, -y)
            row.Name:SetPoint("RIGHT", panel, "TOPRIGHT", -pad - 44, 0)
            local kt = self._mplusBossKills and self._mplusBossKills[b.name]
            row.Time:SetText(kt and SecondsToClock(kt) or ""); row.Time:SetTextColor(c.r, c.g, c.b)
            row.Time:ClearAllPoints(); row.Time:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -y)
            row.Name:Show(); row.Time:Show()
            y = y + ROW_H
        else
            row.Check:Hide(); row.Name:Hide(); row.Time:Hide()
        end
    end

    panel:SetHeight(y + pad)
    panel:Show()
    self:_LayoutRolls()   -- the M+ panel + the loot/bonus roll panels share one screen-edge-aware side stack (no overlap)
end

-- [ TOAST SILENCE GATE ]-----------------------------------------------------------------------------
-- Toasts are silenced for the whole key duration (off at start, back on at completion/reset) — automatic, not a toggle. The shared chokepoint Enqueue + the per-hook suppressors read this.
function Plugin:_MPlusSilencing()
    return self._mplusActive == true
end

-- [ BLIZZARD M+ BLOCK ]------------------------------------------------------------------------------
-- Reversible, taint-free hide: SetAlpha (insecure; ObjectiveTrackerFrame is already an insecure VE entry) re-asserted via a post-hook on the module's Update. Park is wrong here — it unregisters events + reparents with no restore, breaking delve/normal scenarios after the key.
function Plugin:_SetBlizMPlusHidden(hidden)
    self._mplusHideBliz = hidden
    local block = ScenarioObjectiveTracker
    if not block then return end
    if not self._mplusBlizHooked then
        self._mplusBlizHooked = true
        hooksecurefunc(block, "Update", function(tracker)
            if Plugin._mplusHideBliz then tracker:SetAlpha(0) end
        end)
    end
    block:SetAlpha(hidden and 0 or 1)
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
local FAKE_LIMIT = 1800

-- Stand up a fake key at a given elapsed so the orb + panel can be previewed outside a real run; while it's up, _mplusActive is true so other toasts (/orbitloot, /orbitvault, ...) are silenced.
local function FakeKey(elapsed, deaths, timeLost, peril)
    Plugin._mplusActive, Plugin._mplusResults = true, false
    Plugin._mplusMapID = 0
    Plugin._mplusName = "Test Dungeon"
    Plugin._mplusLevel = 12
    Plugin._mplusTimeLimit = FAKE_LIMIT
    Plugin._mplusHasPeril = peril and true or false
    Plugin._mplusAffixes = peril and { 10, 9, CHALLENGERS_PERIL_AFFIX } or { 10, 9 }
    Plugin:_ComputeMPlusThresholds()
    Plugin._mplusDeaths, Plugin._mplusTimeLost = deaths or 0, timeLost or 0
    local cur = math.min(100, math.floor(elapsed / FAKE_LIMIT * 115))   -- trash cleared (0-100); remaining = 100 - cur
    Plugin._mplusForces = { current = cur, total = 100 }
    Plugin._mplusBosses = {
        { name = "First Boss",  done = true },
        { name = "Second Boss", done = elapsed > FAKE_LIMIT * 0.5 },
        { name = "Final Boss",  done = false },
    }
    Plugin._mplusBossKills = { ["First Boss"] = math.floor(FAKE_LIMIT * 0.2) }
    if elapsed > FAKE_LIMIT * 0.5 then Plugin._mplusBossKills["Second Boss"] = math.floor(FAKE_LIMIT * 0.5) end
    Plugin._mplusAffixFid, Plugin._mplusPanelSig, Plugin._mplusTierKey = {}, nil, nil
    Plugin._mplusBaseTime, Plugin._mplusTimeSince = elapsed, 0
    Plugin:_PositionMPlusTicks()
    Plugin:_StartMPlusDriver()
    Plugin:_SetMPlusTicksShown(true)
    Plugin:RevealOrb()
    Plugin:UpdateBar()
end

-- /orbitmplus [+3|+2|+1|over|peril|done|depleted|off] — no arg = a representative mid-run (+2 pace, 2 deaths).
SLASH_ORBITMPLUS1 = "/orbitmplus"
SlashCmdList["ORBITMPLUS"] = function(arg)
    arg = arg and arg:lower():match("%S+")
    if arg == "off" then Plugin:_EndMPlus()
    elseif arg == "done" or arg == "depleted" then
        if not Plugin._mplusActive then FakeKey(FAKE_LIMIT * 0.70, 1, 0) end   -- stand up a quick run to complete if none is up
        Plugin:_FinishMPlus(arg == "done")
    elseif arg == "+3" or arg == "3" then FakeKey(FAKE_LIMIT * 0.45)
    elseif arg == "+2" or arg == "2" then FakeKey(FAKE_LIMIT * 0.70)
    elseif arg == "+1" or arg == "1" then FakeKey(FAKE_LIMIT * 0.90)
    elseif arg == "over" then FakeKey(FAKE_LIMIT * 1.06)
    elseif arg == "peril" then FakeKey(FAKE_LIMIT * 0.70, 2, 10, true)
    else FakeKey(FAKE_LIMIT * 0.65, 2, 10) end
end
