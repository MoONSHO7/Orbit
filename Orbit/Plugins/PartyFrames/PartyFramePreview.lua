---@type Orbit
local Orbit = Orbit
local LSM = LibStub("LibSharedMedia-3.0")
local LCG = LibStub("LibCustomGlow-1.0")
local OrbitEngine = Orbit.Engine

-- Define Mixin
Orbit.PartyFramePreviewMixin = {}

-- Reference to shared helpers
local Helpers = nil -- Will be set when first needed

-- Constants
local MAX_PREVIEW_FRAMES = 5 -- 4 party + 1 potential player
local DEBOUNCE_DELAY = Orbit.Constants.Timing.DefaultDebounce

local PRIVATE_AURA_ICON_SIZE = 24
local HEALER_AURA_ICON_SIZE = 16
local HealerReg = Orbit.HealerAuraRegistry


-- Combat-safe wrappers (from Core GroupFrameMixin)
local SafeRegisterUnitWatch = Orbit.GroupFrameMixin.SafeRegisterUnitWatch
local SafeUnregisterUnitWatch = Orbit.GroupFrameMixin.SafeUnregisterUnitWatch

-- Preview defaults - varied values for realistic appearance
local PREVIEW_DEFAULTS = {
    HealthPercents = { 95, 72, 45, 28, 100 }, -- 5th is player
    PowerPercents = { 85, 60, 40, 15, 80 },
    Names = { "Healbot", "Tankenstein", "Stabby", "Pyromancer", "You" },
    Classes = { "PRIEST", "WARRIOR", "ROGUE", "MAGE", "PALADIN" },
    Status = { nil, nil, nil, nil, nil },
    Roles = { "HEALER", "TANK", "DAMAGER", "DAMAGER", "HEALER" },

}


local ApplyIconPosition = function(icon, parentFrame, pos)
    Orbit.Engine.PositionUtils.ApplyIconPosition(icon, parentFrame, pos)
end

-- [ PREVIEW LOGIC ]---------------------------------------------------------------------------------

function Orbit.PartyFramePreviewMixin:ShowPreview()
    if InCombatLockdown() then
        return
    end
    if not self.frames or not self.container then
        return
    end

    -- Lazy-load helpers reference
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end

    -- Disable visibility driver for preview so we can manually show frames
    UnregisterStateDriver(self.container, "visibility")
    self.container:Show()

    -- Check if we're in Canvas Mode (right-click component editing)
    local isCanvasMode = false
    local OrbitEngine = Orbit.Engine
    if OrbitEngine and OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then
        if OrbitEngine.CanvasMode.currentFrame == self.container then isCanvasMode = true
        else
            for _, frame in ipairs(self.frames) do
                if OrbitEngine.CanvasMode.currentFrame == frame then isCanvasMode = true; break end
            end
        end
    end

    -- In Canvas Mode show only 1 frame; in Edit Mode show based on settings
    local includePlayer = self:GetSetting(1, "IncludePlayer")
    local baseFrames = isCanvasMode and 1 or 4
    local framesToShow = includePlayer and (baseFrames + 1) or baseFrames

    -- Disable UnitWatch and show frames for preview
    for i = 1, MAX_PREVIEW_FRAMES do
        if self.frames[i] then
            SafeUnregisterUnitWatch(self.frames[i])
            if i <= framesToShow then
                self.frames[i].preview = true
                self.frames[i]:Show()
            else
                self.frames[i].preview = nil
                self.frames[i]:Hide()
            end
        end
    end

    -- Position frames within container
    self:PositionFrames()

    -- Update container size for preview
    self:UpdateContainerSize()

    -- Re-sync selection highlight after container resize
    local OrbitEngine = Orbit.Engine
    OrbitEngine.FrameSelection:ForceUpdate(self.container)
    -- Apply preview visuals after a short delay to ensure they aren't overwritten
    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.frames then
            self:ApplyPreviewVisuals()
            -- Start animation in Edit Mode only (not Canvas Mode)
            if not isCanvasMode then self:StartPreviewAnimation() end
        end
    end)

    Orbit.PreviewAnimator:WatchCanvas(self)
end

function Orbit.PartyFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then return end
    if not Helpers then Helpers = Orbit.PartyFrameHelpers end

    -- Check if we're in Canvas Mode
    local isCanvasMode = false
    local OrbitEngine = Orbit.Engine
    if OrbitEngine and OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then
        if OrbitEngine.CanvasMode.currentFrame == self.container then isCanvasMode = true
        else
            for _, frame in ipairs(self.frames) do
                if OrbitEngine.CanvasMode.currentFrame == frame then isCanvasMode = true; break end
            end
        end
    end

    local globalSettings = Orbit.db.GlobalSettings or {}

    for i = 1, MAX_PREVIEW_FRAMES do
        if self.frames[i] and self.frames[i].preview then
            local frame = self.frames[i]

            -- Shared styling (size, border, texture, text, positions, overrides)
            local showPower = self:GetSetting(1, "ShowPowerBar")
            if showPower == nil then showPower = true end
            local showThisPower = showPower or (PREVIEW_DEFAULTS.Roles[i] == "HEALER")
            self:ApplyFrameStyle(frame, showThisPower)

            -- Preview-only: backdrop
            if self.ApplyPreviewBackdrop then self:ApplyPreviewBackdrop(frame) end

            -- Preview-only: fake health data
            if frame.Health then
                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(PREVIEW_DEFAULTS.HealthPercents[i])
                if self.GetPreviewHealthColor then
                    local r, g, b = self:GetPreviewHealthColor(true, PREVIEW_DEFAULTS.Classes[i], nil)
                    frame.Health:SetStatusBarColor(r, g, b)
                else
                    local classColor = C_ClassColor.GetClassColor(PREVIEW_DEFAULTS.Classes[i])
                    if classColor then frame.Health:SetStatusBarColor(classColor.r, classColor.g, classColor.b) end
                end
                frame.Health:Show()
            end

            -- Preview-only: fake power data
            if frame.Power and showThisPower then
                frame.Power:SetMinMaxValues(0, 100)
                frame.Power:SetValue(PREVIEW_DEFAULTS.PowerPercents[i])
                frame.Power:SetStatusBarColor(0, 0.5, 1)
                Orbit.Skin:ApplyGradientBackground(frame.Power, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)
            end

            -- Preview-only: fake name
            local disabledComponents = self:GetSetting(1, "DisabledComponents") or {}
            local isNameDisabled, isHealthTextDisabled = false, false
            for _, key in ipairs(disabledComponents) do
                if key == "Name" then isNameDisabled = true end
                if key == "HealthText" then isHealthTextDisabled = true end
            end

            if frame.Name then
                if isNameDisabled then frame.Name:Hide()
                else
                    frame.Name:SetText(PREVIEW_DEFAULTS.Names[i])
                    if self.GetPreviewTextColor then
                        local r, g, b, a = self:GetPreviewTextColor(true, PREVIEW_DEFAULTS.Classes[i], nil)
                        frame.Name:SetTextColor(r, g, b, a)
                    else frame.Name:SetTextColor(1, 1, 1, 1) end
                    frame.Name:Show()
                end
            end

            -- Preview-only: fake health text
            if frame.HealthText then
                local showHealthValue = self:GetSetting(1, "ShowHealthValue")
                if showHealthValue == nil then showHealthValue = true end
                local previewStatus = PREVIEW_DEFAULTS.Status[i]
                local isDeadOrOffline = (previewStatus == "Dead" or previewStatus == "Offline")
                if isHealthTextDisabled then frame.HealthText:Hide()
                elseif isDeadOrOffline then
                    frame.HealthText:SetText(previewStatus)
                    frame.HealthText:SetTextColor(0.7, 0.7, 0.7, 1)
                    frame.HealthText:Show()
                elseif not showHealthValue then frame.HealthText:Hide()
                else
                    local healthTextMode = self:GetSetting(1, "HealthTextMode") or "percent_short"
                    local pct = PREVIEW_DEFAULTS.HealthPercents[i]
                    local shortVals = { "125K", "98.5K", "45.2K", "22.1K", "150K" }
                    local rawVals = { "125,000", "98,500", "45,200", "22,100", "150,000" }
                    local fmtMap = {
                        percent = pct .. "%", short = shortVals[i], raw = rawVals[i],
                        percent_short = pct .. "%", percent_raw = pct .. "%",
                        short_percent = shortVals[i], short_raw = shortVals[i],
                        raw_short = rawVals[i], raw_percent = rawVals[i],
                        short_and_percent = shortVals[i] .. " - " .. pct .. "%",
                    }
                    frame.HealthText:SetText(fmtMap[healthTextMode] or (pct .. "%"))
                    if self.GetPreviewTextColor then
                        local r, g, b, a = self:GetPreviewTextColor(true, PREVIEW_DEFAULTS.Classes[i], nil)
                        frame.HealthText:SetTextColor(r, g, b, a)
                    else frame.HealthText:SetTextColor(1, 1, 1, 1) end
                    frame.HealthText:Show()
                end
                frame:SetAlpha(isDeadOrOffline and Orbit.Constants.GroupFrames.OfflineAlpha or 1)
            end

            -- Preview-only: class file for overrides
            frame.previewClassFile = PREVIEW_DEFAULTS.Classes[i]

            -- Preview-only: role/leader/selection/aggro icons with fake data
            local previewRoles = { "HEALER", "TANK", "DAMAGER", "DAMAGER" }
            local roleAtlases = Orbit.RoleAtlases
            local componentPositions = self:GetComponentPositions(1)

            if self:GetSetting(1, "ShowRoleIcon") ~= false and frame.RoleIcon then
                local role = previewRoles[i]
                local roleOverrides = componentPositions.RoleIcon and componentPositions.RoleIcon.overrides
                local hideDPS = roleOverrides and roleOverrides.HideDPS
                if role == "DAMAGER" and hideDPS then frame.RoleIcon:Hide()
                else
                    local roleAtlas = roleAtlases[role]
                    if roleAtlas then
                        frame.RoleIcon:SetAtlas(roleAtlas)
                        frame.RoleIcon:Show()
                        if componentPositions.RoleIcon then ApplyIconPosition(frame.RoleIcon, frame, componentPositions.RoleIcon) end
                    end
                end
            elseif frame.RoleIcon then frame.RoleIcon:Hide() end

            if self:GetSetting(1, "ShowLeaderIcon") ~= false and frame.LeaderIcon then
                if i == 1 then
                    frame.LeaderIcon:SetAtlas(Orbit.IconPreviewAtlases.LeaderIcon)
                    frame.LeaderIcon:Show()
                    if componentPositions.LeaderIcon then ApplyIconPosition(frame.LeaderIcon, frame, componentPositions.LeaderIcon) end
                else frame.LeaderIcon:Hide() end
            elseif frame.LeaderIcon then frame.LeaderIcon:Hide() end

            if self:GetSetting(1, "ShowSelectionHighlight") ~= false and frame.SelectionHighlight then
                if i == 2 then frame.SelectionHighlight:Show() else frame.SelectionHighlight:Hide() end
            elseif frame.SelectionHighlight then frame.SelectionHighlight:Hide() end

            if self:GetSetting(1, "ShowAggroHighlight") ~= false and frame.AggroHighlight then
                if i == 2 then frame.AggroHighlight:SetVertexColor(1.0, 0.6, 0.0, 0.6); frame.AggroHighlight:Show()
                else frame.AggroHighlight:Hide() end
            elseif frame.AggroHighlight then frame.AggroHighlight:Hide() end

            -- Canvas Mode icons (status, defensive, CC, PAA, healer, raidbuff)
            Orbit.GroupCanvasRegistration:ShowCanvasModeIcons(self, frame, isCanvasMode, {
                statusIcons = { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" },
                statusIconSize = 24, statusIconSpacing = 28,
                privateAuraSize = PRIVATE_AURA_ICON_SIZE,
                healerAuraSize = HEALER_AURA_ICON_SIZE,
            }, HealerReg:ActiveSlots(), HealerReg:ActiveRaidBuffs(), HealerReg:ActiveKeys())

            -- Preview auras (skip if animator is handling them, unless in Canvas Mode)
            if isCanvasMode or not Orbit.PreviewAnimator:IsRunning() then
                if frame.debuffPool then frame.debuffPool:ReleaseAll() end
                if frame.buffPool then frame.buffPool:ReleaseAll() end
                self:ShowPreviewAuras(frame, i)
            end

            -- Preview dispel glow
            local dispelEnabled = self:GetSetting(1, "DispelIndicatorEnabled")
            if dispelEnabled and i == 2 then
                local thickness = self:GetSetting(1, "DispelThickness") or 2
                local frequency = self:GetSetting(1, "DispelFrequency") or 0.25
                local numLines = self:GetSetting(1, "DispelNumLines") or 8
                local color = { 0.0, 0.4, 1.0, 1 }
                LCG.PixelGlow_Start(frame, color, numLines, frequency, nil, thickness, 0, 0, true, "preview", Orbit.Constants.Levels.Glow)
            else
                LCG.PixelGlow_Stop(frame, "preview")
            end
        end
    end
end

-- [ PREVIEW AURAS ]---------------------------------------------------------------------------------

local PARTY_PREVIEW_AURA_CFG = {
    helpers = function() return Orbit.PartyFrameHelpers end,
    defaultAnchorX = "RIGHT", defaultJustifyH = "LEFT",
    defaultMax = 3,
}
local PARTY_PREVIEW_BUFF_CFG = {
    helpers = function() return Orbit.PartyFrameHelpers end,
    defaultAnchorX = "LEFT", defaultJustifyH = "RIGHT",
    defaultMax = 3,
}

function Orbit.PartyFramePreviewMixin:ShowPreviewAuras(frame, frameIndex)
    Orbit.AuraPreview:ShowFrameAuras(self, frame, PARTY_PREVIEW_AURA_CFG, PARTY_PREVIEW_BUFF_CFG)
end


function Orbit.PartyFramePreviewMixin:HidePreview()
    if InCombatLockdown() then
        return
    end
    if not self.frames then
        return
    end

    -- Stop animation
    Orbit.PreviewAnimator:Stop(self)
    Orbit.PreviewAnimator:StopAuras(self)
    Orbit.PreviewAnimator:StopHealerAuras(self)

    Orbit.PreviewAnimator:UnwatchCanvas(self)

    -- Restore visibility driver for normal gameplay (hide in raids)
    local visibilityDriver = "[petbattle] hide; [@raid1,exists] hide; [@party1,exists] show; hide"
    RegisterStateDriver(self.container, "visibility", visibilityDriver)

    for i, frame in ipairs(self.frames) do
        frame.preview = nil
        frame:SetAlpha(1)
        SafeRegisterUnitWatch(frame)
        if frame.previewDebuffs then
            for _, icon in ipairs(frame.previewDebuffs) do
                icon:Hide()
            end
            wipe(frame.previewDebuffs)
        end

        -- Hide and clear preview buffs
        if frame.previewBuffs then
            for _, icon in ipairs(frame.previewBuffs) do
                icon:Hide()
            end
            wipe(frame.previewBuffs)
        end

        -- Clear any private aura anchors that were generated
        if frame._privateAuraIDs then
            for _, id in ipairs(frame._privateAuraIDs) do 
                C_UnitAuras.RemovePrivateAuraAnchor(id) 
            end
            wipe(frame._privateAuraIDs)
        end

        -- Hide private aura preview icons created by AuraPreview:ShowPrivateAuras
        local paa = frame.PrivateAuraAnchor
        if paa then
            if paa._previewIcons then for _, sub in ipairs(paa._previewIcons) do sub:Hide() end end
            paa:Hide()
        end

        LCG.PixelGlow_Stop(frame, "preview")
        for _, key in ipairs(HealerReg:ActiveKeys()) do
            if frame[key] then frame[key]:Hide() end
        end
        if frame.HealthDamageBar then
            frame.HealthDamageBar:Show()
        end
        if frame.HealthDamageTexture then
            frame.HealthDamageTexture:Show()
        end
        if frame.UpdateAll then
            frame:UpdateAll()
        end
    end

    if self.UpdateFrameUnits then
        self:UpdateFrameUnits()
    end

    if self.ApplySettings then
        self:ApplySettings()
    end
    self:UpdateContainerSize()
end

function Orbit.PartyFramePreviewMixin:SchedulePreviewUpdate()
    if not self._previewVisualsScheduled then
        self._previewVisualsScheduled = true
        C_Timer.After(DEBOUNCE_DELAY, function()
            self._previewVisualsScheduled = false
            if self.frames then
                self:ApplyPreviewVisuals()
                -- Reposition frames after size changes
                self:PositionFrames()
                self:UpdateContainerSize()
            end
        end)
    end
end

function Orbit.PartyFramePreviewMixin:StartPreviewAnimation()
    if not self.frames then return end
    local includePlayer = self:GetSetting(1, "IncludePlayer")
    local framesToShow = includePlayer and 5 or 4
    local HealerReg = Orbit.HealerAuraRegistry
    local healerSlots = HealerReg:ActiveSlots()
    local isDisabled = self.IsComponentDisabled and function(k) return self:IsComponentDisabled(k) end or function() return false end
    local enabledSlots = {}
    for _, slot in ipairs(healerSlots) do
        if not isDisabled(slot.key) then enabledSlots[#enabledSlots + 1] = slot end
    end
    local visibleFrames = {}
    for i = 1, framesToShow do
        local f = self.frames[i]
        if f and f.preview and f:IsShown() then visibleFrames[#visibleFrames + 1] = f end
    end
    Orbit.PreviewAnimator:StartAll(self, {
        frames = visibleFrames,
        getHelpers = function() return Orbit.PartyFrameHelpers end,
        getHealth = function(i) return (PREVIEW_DEFAULTS.HealthPercents[i] or 75) / 100 end,
        getDead = function(i) local s = PREVIEW_DEFAULTS.Status[i]; return s == "Dead" or s == "Offline" end,
        healerSlots = enabledSlots,
        raidBuffKey = not isDisabled("RaidBuff") and "RaidBuff" or nil,
    })
end
