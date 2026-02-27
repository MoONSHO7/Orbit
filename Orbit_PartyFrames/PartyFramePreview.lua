---@type Orbit
local Orbit = Orbit
local LSM = LibStub("LibSharedMedia-3.0")
local LCG = LibStub("LibCustomGlow-1.0")

-- Define Mixin
Orbit.PartyFramePreviewMixin = {}

-- Reference to shared helpers
local Helpers = nil -- Will be set when first needed

-- Constants
local MAX_PREVIEW_FRAMES = 5 -- 4 party + 1 potential player
local DEBOUNCE_DELAY = Orbit.Constants.Timing.DefaultDebounce

local PRIVATE_AURA_ICON_SIZE = 24


-- Combat-safe wrappers (matches PartyFrame.lua)
local function SafeRegisterUnitWatch(frame)
    if not frame then
        return
    end
    Orbit:SafeAction(function() RegisterUnitWatch(frame) end)
end

local function SafeUnregisterUnitWatch(frame)
    if not frame then
        return
    end
    Orbit:SafeAction(function() UnregisterUnitWatch(frame) end)
end

-- Preview defaults - varied values for realistic appearance
local PREVIEW_DEFAULTS = {
    HealthPercents = { 95, 72, 45, 28, 100 }, -- 5th is player
    PowerPercents = { 85, 60, 40, 15, 80 },
    Names = { "Healbot", "Tankenstein", "Stabby", "Pyromancer", "You" },
    Classes = { "PRIEST", "WARRIOR", "ROGUE", "MAGE", "PALADIN" },
    Status = { nil, nil, nil, "Offline", nil },
    Roles = { "HEALER", "TANK", "DAMAGER", "DAMAGER", "HEALER" },

}

-- Sample debuff icons for preview (harmful auras)
local SAMPLE_DEBUFF_ICONS = {
    136096, -- Moonfire
    136118, -- Corruption
    132158, -- Nature's Grasp (Roots)
    136048, -- Insect Swarm
    132212, -- Faerie Fire
}

-- Sample buff icons for preview (helpful auras from player)
local SAMPLE_BUFF_ICONS = {
    135907, -- Rejuvenation
    136048, -- Regrowth
    136041, -- Power Word: Shield
    135944, -- Renew
    135987, -- Earth Shield
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
        -- Canvas Mode active on one of our frames
        for _, frame in ipairs(self.frames) do
            if OrbitEngine.CanvasMode.currentFrame == frame then
                isCanvasMode = true
                break
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
    if OrbitEngine.FrameSelection then OrbitEngine.FrameSelection:ForceUpdate(self.container) end

    -- Apply preview visuals after a short delay to ensure they aren't overwritten
    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.frames then
            self:ApplyPreviewVisuals()
        end
    end)
end

function Orbit.PartyFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then
        return
    end

    -- Lazy-load helpers
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end

    -- Check if we're in Canvas Mode (right-click component editing)
    local isCanvasMode = false
    local OrbitEngine = Orbit.Engine
    if OrbitEngine and OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then
        -- Canvas Mode is active on one of our frames (or container)
        for _, frame in ipairs(self.frames) do
            if OrbitEngine.CanvasMode.currentFrame == frame or OrbitEngine.CanvasMode.currentFrame == self.container then
                isCanvasMode = true
                break
            end
        end
    end

    -- Get settings
    local width = self:GetSetting(1, "Width") or Helpers.LAYOUT.DefaultWidth
    local height = self:GetSetting(1, "Height") or Helpers.LAYOUT.DefaultHeight
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
    local borderSize = self:GetSetting(1, "BorderSize") or (Orbit.Engine.Pixel and Orbit.Engine.Pixel:Multiple(1, self.container:GetEffectiveScale() or 1) or 1)

    -- Get Colors tab global settings (for reference only - helpers read them)
    local globalSettings = Orbit.db.GlobalSettings or {}

    for i = 1, MAX_PREVIEW_FRAMES do
        if self.frames[i] and self.frames[i].preview then
            local frame = self.frames[i]

            -- Determine per-frame power bar visibility (healers always show)
            local showPower = self:GetSetting(1, "ShowPowerBar")
            if showPower == nil then showPower = true end
            local showThisPower = showPower or (PREVIEW_DEFAULTS.Roles[i] == "HEALER")

            frame:SetSize(width, height)
            Helpers:UpdateFrameLayout(frame, borderSize, showThisPower)

            -- Apply backdrop color using shared helper
            if self.ApplyPreviewBackdrop then
                self:ApplyPreviewBackdrop(frame)
            end

            -- Apply texture and set up health bar
            if frame.Health then
                -- Use SkinStatusBar with isUnitFrame=true (respects OverlayAllFrames)
                Orbit.Skin:SkinStatusBar(frame.Health, textureName, nil, true)

                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(PREVIEW_DEFAULTS.HealthPercents[i])

                -- Apply color using shared helper (party members are players)
                if self.GetPreviewHealthColor then
                    local r, g, b = self:GetPreviewHealthColor(true, PREVIEW_DEFAULTS.Classes[i], nil)
                    frame.Health:SetStatusBarColor(r, g, b)
                else
                    -- Fallback to class color
                    local classColor = C_ClassColor.GetClassColor(PREVIEW_DEFAULTS.Classes[i])
                    if classColor then
                        frame.Health:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
                    end
                end
                frame.Health:Show()
                if frame.HealthDamageBar then frame.HealthDamageBar:Hide() end
                if frame.HealthDamageTexture then frame.HealthDamageTexture:Hide() end
            end

            -- Apply texture and set up power bar (healers always show power bar)
            if frame.Power then
                if showThisPower then
                    Orbit.Skin:SkinStatusBar(frame.Power, textureName, nil, true)
                    frame.Power:SetMinMaxValues(0, 100)
                    frame.Power:SetValue(PREVIEW_DEFAULTS.PowerPercents[i])
                    frame.Power:SetStatusBarColor(0, 0.5, 1)
                    Orbit.Skin:ApplyGradientBackground(frame.Power, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)
                    frame.Power:Show()
                else
                    frame.Power:Hide()
                end
            end

            -- Preview name - ensure visible and override any unit data
            -- Check if Name is disabled
            local disabledComponents = self:GetSetting(1, "DisabledComponents") or {}
            local isNameDisabled = false
            local isHealthTextDisabled = false
            for _, key in ipairs(disabledComponents) do
                if key == "Name" then
                    isNameDisabled = true
                end
                if key == "HealthText" then
                    isHealthTextDisabled = true
                end
            end

            if frame.Name then
                if isNameDisabled then
                    frame.Name:Hide()
                else
                    frame.Name:SetText(PREVIEW_DEFAULTS.Names[i])

                    -- Apply font color using shared helper (party members are players)
                    if self.GetPreviewTextColor then
                        local r, g, b, a = self:GetPreviewTextColor(true, PREVIEW_DEFAULTS.Classes[i], nil)
                        frame.Name:SetTextColor(r, g, b, a)
                    else
                        frame.Name:SetTextColor(1, 1, 1, 1)
                    end
                    frame.Name:Show()
                end
            end

            -- Preview health text - override UpdateHealthText
            if frame.HealthText then
                local showHealthValue = self:GetSetting(1, "ShowHealthValue")
                if showHealthValue == nil then showHealthValue = true end
                local previewStatus = PREVIEW_DEFAULTS.Status[i]
                local isDeadOrOffline = (previewStatus == "Dead" or previewStatus == "Offline")
                if isHealthTextDisabled then
                    frame.HealthText:Hide()
                elseif isDeadOrOffline then
                    frame.HealthText:SetText(previewStatus)
                    frame.HealthText:SetTextColor(0.7, 0.7, 0.7, 1)
                    frame.HealthText:Show()
                elseif not showHealthValue then
                    frame.HealthText:Hide()
                else
                    local healthTextMode = self:GetSetting(1, "HealthTextMode") or "percent_short"
                    local pct = PREVIEW_DEFAULTS.HealthPercents[i]
                    local shortVals = { "125K", "98.5K", "45.2K", "22.1K", "150K" }
                    local rawVals = { "125,000", "98,500", "45,200", "22,100", "150,000" }
                    local fmtMap = {
                        percent = pct .. "%",
                        short = shortVals[i],
                        raw = rawVals[i],
                        percent_short = pct .. "%",
                        percent_raw = pct .. "%",
                        short_percent = shortVals[i],
                        short_raw = shortVals[i],
                        raw_short = rawVals[i],
                        raw_percent = rawVals[i],
                        short_and_percent = shortVals[i] .. " - " .. pct .. "%",
                    }
                    frame.HealthText:SetText(fmtMap[healthTextMode] or (pct .. "%"))
                    if self.GetPreviewTextColor then
                        local r, g, b, a = self:GetPreviewTextColor(true, PREVIEW_DEFAULTS.Classes[i], nil)
                        frame.HealthText:SetTextColor(r, g, b, a)
                    else
                        frame.HealthText:SetTextColor(1, 1, 1, 1)
                    end
                    frame.HealthText:Show()
                end
                frame:SetAlpha(isDeadOrOffline and 0.35 or 1)
            end

            -- Apply global text styling (font, size, shadow)
            if self.ApplyTextStyling then
                self:ApplyTextStyling(frame)
            end

            -- Apply Canvas Mode component overrides + saved positions
            frame.previewClassFile = PREVIEW_DEFAULTS.Classes[i]
            if frame.ApplyComponentPositions then
                frame:ApplyComponentPositions()
            end

            -- Preview Status Indicators
            -- Role Icon (show varied roles for preview)
            local previewRoles = { "HEALER", "TANK", "DAMAGER", "DAMAGER" }
            local roleAtlases = Orbit.RoleAtlases
            local componentPositions = self:GetSetting(1, "ComponentPositions") or {}

            if self:GetSetting(1, "ShowRoleIcon") ~= false and frame.RoleIcon then
                local roleAtlas = roleAtlases[previewRoles[i]]
                if roleAtlas then
                    frame.RoleIcon:SetAtlas(roleAtlas)
                    frame.RoleIcon:Show()
                    -- Apply saved position if exists
                    if componentPositions.RoleIcon then
                        ApplyIconPosition(frame.RoleIcon, frame, componentPositions.RoleIcon)
                    end
                end
            elseif frame.RoleIcon then
                frame.RoleIcon:Hide()
            end

            -- Leader Icon (show on first frame only)
            if self:GetSetting(1, "ShowLeaderIcon") ~= false and frame.LeaderIcon then
                if i == 1 then
                    frame.LeaderIcon:SetAtlas(Orbit.IconPreviewAtlases.LeaderIcon)
                    frame.LeaderIcon:Show()
                    -- Apply saved position if exists
                    if componentPositions.LeaderIcon then
                        ApplyIconPosition(frame.LeaderIcon, frame, componentPositions.LeaderIcon)
                    end
                else
                    frame.LeaderIcon:Hide()
                end
            elseif frame.LeaderIcon then
                frame.LeaderIcon:Hide()
            end

            -- Selection Highlight (show on second frame for preview)
            if self:GetSetting(1, "ShowSelectionHighlight") ~= false and frame.SelectionHighlight then
                if i == 2 then
                    frame.SelectionHighlight:Show()
                else
                    frame.SelectionHighlight:Hide()
                end
            elseif frame.SelectionHighlight then
                frame.SelectionHighlight:Hide()
            end

            -- Aggro Highlight (show on third frame - tank has aggro preview)
            if self:GetSetting(1, "ShowAggroHighlight") ~= false and frame.AggroHighlight then
                if i == 2 then -- Tank has aggro
                    frame.AggroHighlight:SetVertexColor(1.0, 0.6, 0.0, 0.6) -- Orange
                    frame.AggroHighlight:Show()
                else
                    frame.AggroHighlight:Hide()
                end
            elseif frame.AggroHighlight then
                frame.AggroHighlight:Hide()
            end

            -- Center status icons - show in Canvas Mode for positioning, hide in normal preview
            if isCanvasMode then
                local iconSize = 24 -- Size for visibility
                local spacing = 28 -- Spacing between icons
                local previewAtlases = Orbit.IconPreviewAtlases or {}

                -- Phase Icon - show with mock atlas (offset left)
                if frame.PhaseIcon then
                    frame.PhaseIcon:SetAtlas(previewAtlases.PhaseIcon)
                    frame.PhaseIcon:SetSize(iconSize, iconSize)
                    -- Only set default position if no saved position exists
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.PhaseIcon then
                        frame.PhaseIcon:ClearAllPoints()
                        frame.PhaseIcon:SetPoint("CENTER", frame, "CENTER", Orbit.Engine.Pixel:Snap(-spacing * 1.5, frame:GetEffectiveScale()), 0)
                    end
                    frame.PhaseIcon:Show()
                end
                -- Ready Check Icon - show with mock atlas (offset left-center)
                if frame.ReadyCheckIcon then
                    frame.ReadyCheckIcon:SetAtlas(previewAtlases.ReadyCheckIcon)
                    frame.ReadyCheckIcon:SetSize(iconSize, iconSize)
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.ReadyCheckIcon then
                        frame.ReadyCheckIcon:ClearAllPoints()
                        frame.ReadyCheckIcon:SetPoint("CENTER", frame, "CENTER", Orbit.Engine.Pixel:Snap(-spacing * 0.5, frame:GetEffectiveScale()), 0)
                    end
                    frame.ReadyCheckIcon:Show()
                end
                -- Incoming Res Icon - show with mock atlas (offset right-center)
                if frame.ResIcon then
                    frame.ResIcon:SetAtlas(previewAtlases.ResIcon)
                    frame.ResIcon:SetSize(iconSize, iconSize)
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.ResIcon then
                        frame.ResIcon:ClearAllPoints()
                        frame.ResIcon:SetPoint("CENTER", frame, "CENTER", Orbit.Engine.Pixel:Snap(spacing * 0.5, frame:GetEffectiveScale()), 0)
                    end
                    frame.ResIcon:Show()
                end
                -- Incoming Summon Icon - show with mock atlas (offset right)
                if frame.SummonIcon then
                    frame.SummonIcon:SetAtlas(previewAtlases.SummonIcon)
                    frame.SummonIcon:SetSize(iconSize, iconSize)
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.SummonIcon then
                        frame.SummonIcon:ClearAllPoints()
                        frame.SummonIcon:SetPoint("CENTER", frame, "CENTER", Orbit.Engine.Pixel:Snap(spacing * 1.5, frame:GetEffectiveScale()), 0)
                    end
                    frame.SummonIcon:Show()
                end

                -- DefensiveIcon - skinned preview with class-specific texture
                if frame.DefensiveIcon and not (self.IsComponentDisabled and self:IsComponentDisabled("DefensiveIcon")) then
                    frame.DefensiveIcon.Icon:SetTexture(Orbit.StatusIconMixin:GetDefensiveTexture())
                    frame.DefensiveIcon:SetSize(iconSize, iconSize)
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.DefensiveIcon then
                        frame.DefensiveIcon:ClearAllPoints()
                        frame.DefensiveIcon:SetPoint("CENTER", frame, "LEFT", Orbit.Engine.Pixel:Snap(iconSize * 0.5 + 2, frame:GetEffectiveScale()), 0)
                    end
                    if Orbit.Skin and Orbit.Skin.Icons then
                        Orbit.Skin.Icons:ApplyCustom(frame.DefensiveIcon, { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = false })
                    end
                    frame.DefensiveIcon:Show()
                elseif frame.DefensiveIcon then
                    frame.DefensiveIcon:Hide()
                end


                -- CrowdControlIcon - skinned preview with class-specific texture
                if frame.CrowdControlIcon and not (self.IsComponentDisabled and self:IsComponentDisabled("CrowdControlIcon")) then
                    frame.CrowdControlIcon.Icon:SetTexture(Orbit.StatusIconMixin:GetCrowdControlTexture())
                    frame.CrowdControlIcon:SetSize(iconSize, iconSize)
                    local savedPositions = self:GetSetting(1, "ComponentPositions")
                    if not savedPositions or not savedPositions.CrowdControlIcon then
                        frame.CrowdControlIcon:ClearAllPoints()
                        frame.CrowdControlIcon:SetPoint("CENTER", frame, "TOP", 0, Orbit.Engine.Pixel:Snap(-(iconSize * 0.5 + 2), frame:GetEffectiveScale()))
                    end
                    if Orbit.Skin and Orbit.Skin.Icons then
                        Orbit.Skin.Icons:ApplyCustom(frame.CrowdControlIcon, { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = false })
                    end
                    frame.CrowdControlIcon:Show()
                elseif frame.CrowdControlIcon then
                    frame.CrowdControlIcon:Hide()
                end

                if frame.PrivateAuraAnchor and not (self.IsComponentDisabled and self:IsComponentDisabled("PrivateAuraAnchor")) then
                    local posData = savedPositions and savedPositions.PrivateAuraAnchor
                    Orbit.AuraPreview:ShowPrivateAuras(frame, posData, PRIVATE_AURA_ICON_SIZE)
                elseif frame.PrivateAuraAnchor then
                    frame.PrivateAuraAnchor:Hide()
                end
            else
                -- Hide in normal Edit Mode preview (they overlap)
                if frame.PhaseIcon then
                    frame.PhaseIcon:Hide()
                end
                if frame.ReadyCheckIcon then
                    frame.ReadyCheckIcon:Hide()
                end
                if frame.ResIcon then
                    frame.ResIcon:Hide()
                end
                if frame.SummonIcon then
                    frame.SummonIcon:Hide()
                end
                if frame.DefensiveIcon then
                    frame.DefensiveIcon:Hide()
                end

                if frame.CrowdControlIcon then
                    frame.CrowdControlIcon:Hide()
                end
                if frame.PrivateAuraAnchor then
                    frame.PrivateAuraAnchor:Hide()
                end
            end

            -- Hide real aura pools before showing preview auras
            if frame.debuffPool then
                frame.debuffPool:ReleaseAll()
            end
            if frame.buffPool then
                frame.buffPool:ReleaseAll()
            end

            -- Show preview auras (debuffs and buffs)
            self:ShowPreviewAuras(frame, i)

            -- Show pixel glow on frame 2 (to demonstrate dispel indicator)
            local dispelEnabled = self:GetSetting(1, "DispelIndicatorEnabled")
            if dispelEnabled and i == 2 then
                -- Get dispel settings
                local thickness = self:GetSetting(1, "DispelThickness") or 2
                local frequency = self:GetSetting(1, "DispelFrequency") or 0.25
                local numLines = self:GetSetting(1, "DispelNumLines") or 8

                -- Sample magic color (blue)
                local color = { 0.0, 0.4, 1.0, 1 }

                LCG.PixelGlow_Start(
                    frame,
                    color,
                    numLines,
                    frequency,
                    nil, -- length (auto)
                    thickness,
                    0, -- xOffset
                    0, -- yOffset
                    true, -- border
                    "preview", -- key
                    Orbit.Constants.Levels.Glow -- frameLevel (below text)
                )
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
}
local PARTY_PREVIEW_BUFF_CFG = {
    helpers = function() return Orbit.PartyFrameHelpers end,
    defaultAnchorX = "LEFT", defaultJustifyH = "RIGHT",
}

function Orbit.PartyFramePreviewMixin:ShowPreviewAuras(frame, frameIndex)
    local componentPositions = self:GetSetting(1, "ComponentPositions") or {}
    local debuffData = componentPositions.Debuffs or {}
    local buffData = componentPositions.Buffs or {}
    local debuffDisabled = self.IsComponentDisabled and self:IsComponentDisabled("Debuffs")
    local buffDisabled = self.IsComponentDisabled and self:IsComponentDisabled("Buffs")
    local maxDebuffs = (debuffData.overrides or {}).MaxIcons or 3
    local maxBuffs = (buffData.overrides or {}).MaxIcons or 3
    Orbit.AuraPreview:ShowIcons(frame, "debuff", debuffData, debuffDisabled and 0 or maxDebuffs, SAMPLE_DEBUFF_ICONS, debuffData.overrides, PARTY_PREVIEW_AURA_CFG)
    Orbit.AuraPreview:ShowIcons(frame, "buff", buffData, buffDisabled and 0 or maxBuffs, SAMPLE_BUFF_ICONS, buffData.overrides, PARTY_PREVIEW_BUFF_CFG)
end


function Orbit.PartyFramePreviewMixin:HidePreview()
    if InCombatLockdown() then
        return
    end
    if not self.frames then
        return
    end

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

        LCG.PixelGlow_Stop(frame, "preview")
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
