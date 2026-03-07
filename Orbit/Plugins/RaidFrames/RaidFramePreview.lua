---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local LCG = LibStub("LibCustomGlow-1.0")

Orbit.RaidFramePreviewMixin = {}

local Helpers = nil

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_PREVIEW_FRAMES = 20
local PREVIEW_GROUPS = 4
local DEBOUNCE_DELAY = 0.05

local GF = Orbit.Constants.GroupFrames
local OFFLINE_ALPHA = GF.OfflineAlpha
local CANVAS_ICON_SIZE = 18
local CANVAS_ICON_SPACING = 22
local PRIVATE_AURA_ICON_SIZE = 18
local HEALER_AURA_ICON_SIZE = 12
local HealerReg = Orbit.HealerAuraRegistry

local PREVIEW_NAMES = {
    "Arthas", "Jaina", "Thrall", "Sylvanas", "Anduin",
    "Illidan", "Tyrande", "Velen", "Malfurion", "Genn",
    "Bolvar", "Khadgar", "Yrel", "Garrosh", "Saurfang",
    "Baine", "Talanji", "Alleria", "Turalyon", "Magni",
}
local PREVIEW_CLASSES = {
    "DEATHKNIGHT", "MAGE", "SHAMAN", "HUNTER", "PRIEST",
    "DEMONHUNTER", "DRUID", "PALADIN", "DRUID", "WARRIOR",
    "PALADIN", "MAGE", "PALADIN", "WARRIOR", "WARRIOR",
    "DRUID", "PRIEST", "HUNTER", "PALADIN", "SHAMAN",
}
local PREVIEW_HEALTH_PCTS = {
    100, 85, 60, 40, 95,
    75, 90, 50, 80, 70,
    65, 100, 88, 55, 72,
    92, 78, 83, 95, 100,
}
local PREVIEW_STATUS = {}
local PREVIEW_ROLES = {
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "HEALER",
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER",
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER",
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "HEALER",
}


local ApplyIconPosition = function(icon, parentFrame, pos)
    OrbitEngine.PositionUtils.ApplyIconPosition(icon, parentFrame, pos)
end

-- [ CANVAS MODE DETECTION ]-------------------------------------------------------------------------

local function IsCanvasModeActive(plugin)
    if OrbitEngine and OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then
        if OrbitEngine.CanvasMode.currentFrame == plugin.container then return true end
        for _, frame in ipairs(plugin.frames) do
            if OrbitEngine.CanvasMode.currentFrame == frame then return true end
        end
    end
    return false
end

-- [ PREVIEW SORT ORDER ]----------------------------------------------------------------------------

local ROLE_PRIORITY = GF.RolePriority

local function GetPreviewSortOrder(plugin)
    local sortMode = plugin:GetSetting(1, "SortMode") or "Group"
    local order = {}
    for i = 1, MAX_PREVIEW_FRAMES do order[i] = i end
    if sortMode == "Role" then
        table.sort(order, function(a, b)
            local pa, pb = ROLE_PRIORITY[PREVIEW_ROLES[a]] or 4, ROLE_PRIORITY[PREVIEW_ROLES[b]] or 4
            if pa ~= pb then return pa < pb end
            return (PREVIEW_NAMES[a] or "") < (PREVIEW_NAMES[b] or "")
        end)
    elseif sortMode == "Alphabetical" then
        table.sort(order, function(a, b) return (PREVIEW_NAMES[a] or "") < (PREVIEW_NAMES[b] or "") end)
    end
    return order
end

-- [ PREVIEW SHOW ]----------------------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:ShowPreview()
    if InCombatLockdown() or not self.frames or not self.container then return end
    if not Helpers then Helpers = Orbit.RaidFrameHelpers end

    local isCanvasMode = IsCanvasModeActive(self)
    local framesToShow = isCanvasMode and 1 or MAX_PREVIEW_FRAMES

    for i = 1, Helpers.LAYOUT.MaxRaidFrames do
        local frame = self.frames[i]
        if frame then
            Orbit:SafeAction(function() UnregisterUnitWatch(frame) end)
            frame:SetAttribute("unit", nil)
            frame.unit = nil
            frame:EnableMouse(false)
            if i <= framesToShow then
                frame.preview = true
                frame:Show()
            else
                frame.preview = nil
                frame:Hide()
            end
        end
    end

    self:PositionFrames()
    self:UpdateContainerSize()
    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.frames then
            self:ApplyPreviewVisuals()
            if not isCanvasMode then self:StartPreviewAnimation() end
        end
    end)

    Orbit.PreviewAnimator:WatchCanvas(self)
end

-- [ PREVIEW VISUALS ]-------------------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then return end
    if not Helpers then Helpers = Orbit.RaidFrameHelpers end

    local isCanvasMode = IsCanvasModeActive(self)
    local globalSettings = Orbit.db.GlobalSettings or {}
    local roleAtlases = Orbit.RoleAtlases
    local componentPositions = self:GetComponentPositions(1)
    local isDisabled = self.IsComponentDisabled and function(key) return self:IsComponentDisabled(key) end or function() return false end
    local sortOrder = GetPreviewSortOrder(self)
    local showHealerPower = self:GetSetting(1, "ShowPowerBar")
    if showHealerPower == nil then showHealerPower = true end

    for i = 1, MAX_PREVIEW_FRAMES do
        local frame = self.frames[i]
        if frame and frame.preview then
            local dataIdx = sortOrder[i]
            local isHealer = PREVIEW_ROLES[dataIdx] == "HEALER"
            local showThisPower = showHealerPower and isHealer

            -- Shared styling (size, border, texture, text, positions, overrides)
            self:ApplyFrameStyle(frame, showThisPower)

            -- Preview-only: backdrop
            if self.ApplyPreviewBackdrop then self:ApplyPreviewBackdrop(frame)
            elseif self.CreateBackground then
                self:CreateBackground(frame)
                Orbit.Skin:ApplyGradientBackground(frame, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)
            end

            -- Preview-only: fake health data
            if frame.Health then
                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(PREVIEW_HEALTH_PCTS[dataIdx])
                if self.GetPreviewHealthColor then
                    local r, g, b = self:GetPreviewHealthColor(true, PREVIEW_CLASSES[dataIdx], nil)
                    frame.Health:SetStatusBarColor(r, g, b)
                else
                    local classColor = RAID_CLASS_COLORS[PREVIEW_CLASSES[dataIdx]]
                    if classColor then frame.Health:SetStatusBarColor(classColor.r, classColor.g, classColor.b) end
                end
                frame.Health:Show()
            end

            -- Preview-only: fake power data
            if frame.Power and showThisPower then
                frame.Power:SetMinMaxValues(0, 100)
                frame.Power:SetValue(80)
                frame.Power:SetStatusBarColor(0.0, 0.44, 0.87)
                Orbit.Skin:ApplyGradientBackground(frame.Power, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)
            end

            -- Preview-only: fake name
            if frame.Name then
                if isDisabled("Name") then frame.Name:Hide()
                else
                    frame.Name:SetText(PREVIEW_NAMES[dataIdx])
                    if self.GetPreviewTextColor then
                        local r, g, b, a = self:GetPreviewTextColor(true, PREVIEW_CLASSES[dataIdx], nil)
                        frame.Name:SetTextColor(r, g, b, a)
                    else frame.Name:SetTextColor(1, 1, 1, 1) end
                    frame.Name:Show()
                end
            end

            -- Preview-only: fake health text
            local showHealthValue = self:GetSetting(1, "ShowHealthValue")
            if showHealthValue == nil then showHealthValue = true end
            local previewStatus = (not isCanvasMode) and PREVIEW_STATUS[dataIdx]
            local isDeadOrOffline = (previewStatus == "Dead" or previewStatus == "Offline")
            if frame.HealthText then
                if isCanvasMode then
                    if showHealthValue then
                        local mode = self:GetSetting(1, "HealthTextMode") or "percent_short"
                        local SAMPLE_TEXT = {
                            percent = "100%", short = "106K", raw = "106000",
                            short_and_percent = "106K - 100%",
                            percent_short = "100%", percent_raw = "100%",
                            short_percent = "106K", short_raw = "106K",
                            raw_short = "106000", raw_percent = "106000",
                        }
                        frame.HealthText:SetText(SAMPLE_TEXT[mode] or "100%")
                    else frame.HealthText:SetText("Offline") end
                    if self.GetPreviewTextColor then
                        local r, g, b, a = self:GetPreviewTextColor(true, PREVIEW_CLASSES[dataIdx], nil)
                        frame.HealthText:SetTextColor(r, g, b, a)
                    else frame.HealthText:SetTextColor(1, 1, 1, 1) end
                    frame.HealthText:Show()
                elseif isDeadOrOffline then
                    frame.HealthText:SetText(previewStatus)
                    frame.HealthText:SetTextColor(0.7, 0.7, 0.7, 1)
                    frame.HealthText:Show()
                elseif not showHealthValue then frame.HealthText:Hide()
                else
                    frame.HealthText:SetText(PREVIEW_HEALTH_PCTS[dataIdx] .. "%")
                    if self.GetPreviewTextColor then
                        local r, g, b, a = self:GetPreviewTextColor(true, PREVIEW_CLASSES[dataIdx], nil)
                        frame.HealthText:SetTextColor(r, g, b, a)
                    else frame.HealthText:SetTextColor(1, 1, 1, 1) end
                    frame.HealthText:Show()
                end
            end

            frame:SetAlpha(isDeadOrOffline and OFFLINE_ALPHA or 1)
            frame.previewClassFile = PREVIEW_CLASSES[dataIdx]

            -- Preview-only: role/leader/tank/selection/aggro icons with fake data
            if frame.RoleIcon and roleAtlases then
                if isDisabled("RoleIcon") then frame.RoleIcon:Hide()
                else
                    local role = PREVIEW_ROLES[dataIdx]
                    local roleOverrides = componentPositions.RoleIcon and componentPositions.RoleIcon.overrides
                    local hideDPS = roleOverrides and roleOverrides.HideDPS
                    if role == "DAMAGER" and hideDPS then frame.RoleIcon:Hide()
                    elseif roleAtlases[role] then
                        frame.RoleIcon:SetAtlas(roleAtlases[role])
                        frame.RoleIcon:Show()
                        if componentPositions.RoleIcon then ApplyIconPosition(frame.RoleIcon, frame, componentPositions.RoleIcon) end
                    else frame.RoleIcon:Hide() end
                end
            end

            if frame.LeaderIcon then
                if isDisabled("LeaderIcon") then frame.LeaderIcon:Hide()
                elseif i == 1 then
                    frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
                    frame.LeaderIcon:Show()
                    if componentPositions.LeaderIcon then ApplyIconPosition(frame.LeaderIcon, frame, componentPositions.LeaderIcon) end
                else frame.LeaderIcon:Hide() end
            end

            if frame.MainTankIcon then
                if isDisabled("MainTankIcon") then frame.MainTankIcon:Hide()
                elseif isCanvasMode or (PREVIEW_ROLES[dataIdx] == "TANK" and i <= 2) then
                    frame.MainTankIcon:SetAtlas(i == 1 and "RaidFrame-Icon-MainTank" or "RaidFrame-Icon-MainAssist")
                    frame.MainTankIcon:Show()
                    if componentPositions.MainTankIcon then ApplyIconPosition(frame.MainTankIcon, frame, componentPositions.MainTankIcon) end
                else frame.MainTankIcon:Hide() end
            end

            if frame.SelectionHighlight then
                if i == 2 then frame.SelectionHighlight:Show() else frame.SelectionHighlight:Hide() end
            end
            if frame.AggroHighlight then
                if i == 2 then frame.AggroHighlight:SetVertexColor(1.0, 0.6, 0.0, 0.6); frame.AggroHighlight:Show()
                else frame.AggroHighlight:Hide() end
            end

            -- Canvas Mode icons (status, defensive, CC, PAA, healer, raidbuff)
            Orbit.GroupCanvasRegistration:ShowCanvasModeIcons(self, frame, isCanvasMode, {
                statusIcons = { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" },
                statusIconSize = CANVAS_ICON_SIZE, statusIconSpacing = CANVAS_ICON_SPACING,
                privateAuraSize = PRIVATE_AURA_ICON_SIZE,
                healerAuraSize = HEALER_AURA_ICON_SIZE,
                hideKeys = { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "DefensiveIcon", "CrowdControlIcon", "PrivateAuraAnchor", "MainTankIcon" },
            }, HealerReg:ActiveSlots(), HealerReg:ActiveRaidBuffs(), HealerReg:ActiveKeys())

            -- Preview auras (skip if animator is handling them, unless in Canvas Mode)
            if isCanvasMode or not Orbit.PreviewAnimator:IsRunning() then
                if frame.debuffPool then frame.debuffPool:ReleaseAll() end
                if frame.buffPool then frame.buffPool:ReleaseAll() end
                self:ShowPreviewAuras(frame, i)
            end

            -- Preview dispel glow (skip if animator is handling them)
            if not Orbit.PreviewAnimator:IsRunning() then
                local dispelEnabled = self:GetSetting(1, "DispelIndicatorEnabled")
                local dispelColorMap = { [4] = "DispelColorMagic", [9] = "DispelColorCurse", [14] = "DispelColorPoison" }
                local dispelKey = dispelColorMap[i]
                if dispelEnabled and dispelKey then
                    local thickness = self:GetSetting(1, "DispelThickness") or 2
                    local frequency = self:GetSetting(1, "DispelFrequency") or 0.25
                    local c = self:GetSetting(1, dispelKey) or { r = 0.2, g = 0.6, b = 1.0, a = 1 }
                    LCG.PixelGlow_Start(frame, { c.r, c.g, c.b, c.a }, 8, frequency, nil, thickness, 0, 0, true, "preview", Orbit.Constants.Levels.Glow)
                else
                    LCG.PixelGlow_Stop(frame, "preview")
                end
            end
        end
    end
end

-- [ PREVIEW AURAS ]---------------------------------------------------------------------------------

local RAID_PREVIEW_AURA_CFG = {
    helpers = function() return Orbit.RaidFrameHelpers end,
    defaultAnchorX = "RIGHT", defaultJustifyH = "LEFT",
    defaultMax = 3,
}
local RAID_PREVIEW_BUFF_CFG = {
    helpers = function() return Orbit.RaidFrameHelpers end,
    defaultAnchorX = "LEFT", defaultJustifyH = "RIGHT",
    defaultMax = 3,
}

function Orbit.RaidFramePreviewMixin:ShowPreviewAuras(frame, frameIndex)
    Orbit.AuraPreview:ShowFrameAuras(self, frame, RAID_PREVIEW_AURA_CFG, RAID_PREVIEW_BUFF_CFG)
end

-- [ PREVIEW HIDE ]----------------------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:HidePreview()
    if InCombatLockdown() or not self.frames then return end
    if not Helpers then Helpers = Orbit.RaidFrameHelpers end

    -- Stop animation
    Orbit.PreviewAnimator:Stop(self)
    Orbit.PreviewAnimator:StopAuras(self)
    Orbit.PreviewAnimator:StopHealerAuras(self)
    Orbit.PreviewAnimator:StopDispels(self)

    Orbit.PreviewAnimator:UnwatchCanvas(self)

    for i = 1, Helpers.LAYOUT.MaxRaidFrames do
        local frame = self.frames[i]
        if frame then
            frame.preview = nil
            frame:SetAlpha(1)
            frame:EnableMouse(true)
            local token = "raid" .. i
            frame:SetAttribute("unit", token)
            frame.unit = token
            frame:Hide()
            if frame.previewDebuffs then
                for _, icon in ipairs(frame.previewDebuffs) do icon:Hide() end
                wipe(frame.previewDebuffs)
            end
            if frame.previewBuffs then
                for _, icon in ipairs(frame.previewBuffs) do icon:Hide() end
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
        end
    end

    self:UpdateFrameUnits()
    if self.ApplySettings then self:ApplySettings() end
    self:UpdateContainerSize()
end

-- [ SCHEDULED PREVIEW UPDATE ]----------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:SchedulePreviewUpdate()
    if not self._previewVisualsScheduled then
        self._previewVisualsScheduled = true
        C_Timer.After(DEBOUNCE_DELAY, function()
            self._previewVisualsScheduled = false
            if self.frames then
                self:ApplyPreviewVisuals()
                self:PositionFrames()
                self:UpdateContainerSize()
            end
        end)
    end
end

-- [ BACKDROP HELPER ]-------------------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:ApplyPreviewBackdrop(frame)
    if not frame then return end
    self:CreateBackground(frame)
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(frame, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)
end

function Orbit.RaidFramePreviewMixin:StartPreviewAnimation()
    if not self.frames then return end
    local sortOrder = GetPreviewSortOrder(self)
    local HealerReg = Orbit.HealerAuraRegistry
    local healerSlots = HealerReg:ActiveSlots()
    local isDisabled = self.IsComponentDisabled and function(k) return self:IsComponentDisabled(k) end or function() return false end
    local enabledSlots = {}
    for _, slot in ipairs(healerSlots) do
        if not isDisabled(slot.key) then enabledSlots[#enabledSlots + 1] = slot end
    end
    local visibleFrames = {}
    for i = 1, MAX_PREVIEW_FRAMES do
        local f = self.frames[i]
        if f and f.preview and f:IsShown() then visibleFrames[#visibleFrames + 1] = f end
    end
    local dispelEnabled = self:GetSetting(1, "DispelIndicatorEnabled")
    Orbit.PreviewAnimator:StartAll(self, {
        frames = visibleFrames,
        getHelpers = function() return Orbit.RaidFrameHelpers end,
        getHealth = function(i) local idx = sortOrder[i]; return (PREVIEW_HEALTH_PCTS[idx] or 75) / 100 end,
        getDead = function(i) local idx = sortOrder[i]; local s = PREVIEW_STATUS[idx]; return s == "Dead" or s == "Offline" end,
        healerSlots = enabledSlots,
        raidBuffKey = not isDisabled("RaidBuff") and "RaidBuff" or nil,
        dispelSettings = dispelEnabled and {
            thickness = self:GetSetting(1, "DispelThickness") or 2,
            frequency = self:GetSetting(1, "DispelFrequency") or 0.25,
            numLines = self:GetSetting(1, "DispelNumLines") or 8,
            colors = {
                Magic = self:GetSetting(1, "DispelColorMagic") or { r = 0.2, g = 0.6, b = 1.0, a = 1 },
                Curse = self:GetSetting(1, "DispelColorCurse") or { r = 0.6, g = 0.0, b = 1.0, a = 1 },
                Disease = self:GetSetting(1, "DispelColorDisease") or { r = 0.6, g = 0.4, b = 0.0, a = 1 },
                Poison = self:GetSetting(1, "DispelColorPoison") or { r = 0.0, g = 0.6, b = 0.0, a = 1 },
            },
        } or nil,
    })
end
