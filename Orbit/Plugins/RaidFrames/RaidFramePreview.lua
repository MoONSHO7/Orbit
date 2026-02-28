---@type Orbit
local Orbit = Orbit
local LSM = LibStub("LibSharedMedia-3.0")
local LCG = LibStub("LibCustomGlow-1.0")
local OrbitEngine = Orbit.Engine

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
    65, 100, 88, 0, 0,
    92, 78, 83, 95, 100,
}
local PREVIEW_STATUS = {
    nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil,
    nil, nil, nil, "Dead", "Dead",
    nil, nil, nil, "Offline", "Offline",
}
local PREVIEW_ROLES = {
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "HEALER",
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER",
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER",
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "HEALER",
}
local SAMPLE_DEBUFF_ICONS = { 136096, 136118, 132158, 136048, 132212 }
local SAMPLE_BUFF_ICONS = { 135907, 136048, 136041, 135944, 135987 }


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
        if self.frames then self:ApplyPreviewVisuals() end
    end)
end

-- [ PREVIEW VISUALS ]-------------------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then return end
    if not Helpers then Helpers = Orbit.RaidFrameHelpers end

    local isCanvasMode = IsCanvasModeActive(self)
    local width = self:GetSetting(1, "Width") or Helpers.LAYOUT.DefaultWidth
    local height = self:GetSetting(1, "Height") or Helpers.LAYOUT.DefaultHeight
    local borderSize = self:GetSetting(1, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(self.container:GetEffectiveScale() or 1)
    local showHealerPower = self:GetSetting(1, "ShowPowerBar")
    if showHealerPower == nil then showHealerPower = true end
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
    local roleAtlases = Orbit.RoleAtlases
    local globalSettings = Orbit.db.GlobalSettings or {}
    local componentPositions = self:GetSetting(1, "ComponentPositions") or {}

    local isDisabled = self.IsComponentDisabled and function(key) return self:IsComponentDisabled(key) end or function() return false end

    local sortOrder = GetPreviewSortOrder(self)

    for i = 1, MAX_PREVIEW_FRAMES do
        local frame = self.frames[i]
        if frame and frame.preview then
            local dataIdx = sortOrder[i]
            local isHealer = PREVIEW_ROLES[dataIdx] == "HEALER"
            local showThisPower = showHealerPower and isHealer
            frame:SetSize(width, height)
            Helpers:UpdateFrameLayout(frame, borderSize, showThisPower)

            if self.ApplyPreviewBackdrop then self:ApplyPreviewBackdrop(frame)
            elseif self.CreateBackground then
                self:CreateBackground(frame)
                Orbit.Skin:ApplyGradientBackground(frame, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)
            end

            -- [ Health Bar ]------------------------------------------------------------------------
            if frame.Health then
                Orbit.Skin:SkinStatusBar(frame.Health, textureName, nil, true)
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
                if frame.HealthDamageBar then frame.HealthDamageBar:Hide() end
                if frame.HealthDamageTexture then frame.HealthDamageTexture:Hide() end
            end

            -- [ Power Bar ]-------------------------------------------------------------------------
            if frame.Power then
                if showThisPower then
                    Orbit.Skin:SkinStatusBar(frame.Power, textureName, nil, true)
                    frame.Power:SetMinMaxValues(0, 100)
                    frame.Power:SetValue(80)
                    frame.Power:SetStatusBarColor(0.0, 0.44, 0.87)
                    Orbit.Skin:ApplyGradientBackground(frame.Power, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)
                    frame.Power:Show()
                else
                    frame.Power:Hide()
                end
            end

            if frame.SetBorder then frame:SetBorder(borderSize) end

            -- [ Name ]------------------------------------------------------------------------------
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

            -- [ Health Text ]-----------------------------------------------------------------------
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
                    else
                        frame.HealthText:SetText("Offline")
                    end
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

            -- [ Status Text ]-----------------------------------------------------------------------
            frame:SetAlpha(isDeadOrOffline and OFFLINE_ALPHA or 1)

            if self.ApplyTextStyling then self:ApplyTextStyling(frame) end

            -- [ Component Overrides + Positions ]--------------------------------------------------
            frame.previewClassFile = PREVIEW_CLASSES[dataIdx]
            if frame.ApplyComponentPositions then frame:ApplyComponentPositions(componentPositions) end

            -- [ Role Icon ]-------------------------------------------------------------------------
            if frame.RoleIcon and roleAtlases then
                if isDisabled("RoleIcon") then frame.RoleIcon:Hide()
                else
                    local role = PREVIEW_ROLES[dataIdx]
                    if roleAtlases[role] then
                        frame.RoleIcon:SetAtlas(roleAtlases[role])
                        frame.RoleIcon:Show()
                        if componentPositions.RoleIcon then ApplyIconPosition(frame.RoleIcon, frame, componentPositions.RoleIcon) end
                    else frame.RoleIcon:Hide() end
                end
            end

            -- [ Leader Icon ]-----------------------------------------------------------------------
            if frame.LeaderIcon then
                if isDisabled("LeaderIcon") then frame.LeaderIcon:Hide()
                elseif i == 1 then
                    frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
                    frame.LeaderIcon:Show()
                    if componentPositions.LeaderIcon then ApplyIconPosition(frame.LeaderIcon, frame, componentPositions.LeaderIcon) end
                else frame.LeaderIcon:Hide() end
            end

            -- [ Main Tank Icon ]--------------------------------------------------------------------
            if frame.MainTankIcon then
                if isDisabled("MainTankIcon") then frame.MainTankIcon:Hide()
                elseif isCanvasMode or (PREVIEW_ROLES[dataIdx] == "TANK" and i <= 2) then
                    frame.MainTankIcon:SetAtlas(i == 1 and "RaidFrame-Icon-MainTank" or "RaidFrame-Icon-MainAssist")
                    frame.MainTankIcon:Show()
                    if componentPositions.MainTankIcon then ApplyIconPosition(frame.MainTankIcon, frame, componentPositions.MainTankIcon) end
                else frame.MainTankIcon:Hide() end
            end

            -- [ Selection / Aggro ]-----------------------------------------------------------------
            if frame.SelectionHighlight then
                if i == 2 then frame.SelectionHighlight:Show() else frame.SelectionHighlight:Hide() end
            end
            if frame.AggroHighlight then
                if i == 2 then frame.AggroHighlight:SetVertexColor(1.0, 0.6, 0.0, 0.6); frame.AggroHighlight:Show()
                else frame.AggroHighlight:Hide() end
            end

            -- [ Canvas Mode Status Icons ]----------------------------------------------------------
            if isCanvasMode then
                local previewAtlases = Orbit.IconPreviewAtlases or {}
                local savedPositions = self:GetSetting(1, "ComponentPositions") or {}

                for idx, key in ipairs({ "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }) do
                    if frame[key] then
                        frame[key]:SetAtlas(previewAtlases[key])
                        frame[key]:SetSize(CANVAS_ICON_SIZE, CANVAS_ICON_SIZE)
                        if not savedPositions[key] then
                            frame[key]:ClearAllPoints()
                            frame[key]:SetPoint("CENTER", frame, "CENTER", Orbit.Engine.Pixel:Snap(CANVAS_ICON_SPACING * (idx - 2.5), frame:GetEffectiveScale()), 0)
                        end
                        frame[key]:Show()
                    end
                end

                local auraIconEntries = {
                    { key = "DefensiveIcon", anchor = "LEFT", xMul = 0.5 },
                    { key = "CrowdControlIcon", anchor = "TOP", yMul = -0.5 },
                }
                for _, entry in ipairs(auraIconEntries) do
                    local btn = frame[entry.key]
                    if btn and not isDisabled(entry.key) then
                        local texMethod = "Get" .. entry.key:gsub("Icon$", "") .. "Texture"
                        btn.Icon:SetTexture(Orbit.StatusIconMixin[texMethod](Orbit.StatusIconMixin))
                        btn:SetSize(CANVAS_ICON_SIZE, CANVAS_ICON_SIZE)
                        if not savedPositions[entry.key] then
                            btn:ClearAllPoints()
                            local xOff = OrbitEngine.Pixel:Snap((entry.xMul or 0) * (CANVAS_ICON_SIZE + 2), 1)
                            local yOff = OrbitEngine.Pixel:Snap((entry.yMul or 0) * (CANVAS_ICON_SIZE + 2), 1)
                            btn:SetPoint("CENTER", frame, entry.anchor, xOff, yOff)
                        end
                        if Orbit.Skin and Orbit.Skin.Icons then
                            Orbit.Skin.Icons:ApplyCustom(btn, { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = false })
                        end
                        btn:Show()
                    elseif btn then btn:Hide() end
                end

                local paa = frame.PrivateAuraAnchor
                if paa and not isDisabled("PrivateAuraAnchor") then
                    local posData = savedPositions and savedPositions.PrivateAuraAnchor
                    Orbit.AuraPreview:ShowPrivateAuras(frame, posData, PRIVATE_AURA_ICON_SIZE)
                elseif paa then paa:Hide() end
            else
                for _, key in ipairs({ "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "DefensiveIcon", "CrowdControlIcon", "PrivateAuraAnchor", "MainTankIcon" }) do
                    if frame[key] then frame[key]:Hide() end
                end
            end

            -- [ Preview Auras ]---------------------------------------------------------------------
            if frame.debuffPool then frame.debuffPool:ReleaseAll() end
            if frame.buffPool then frame.buffPool:ReleaseAll() end
            self:ShowPreviewAuras(frame, i)

            -- [ Dispel Glow ]-----------------------------------------------------------------------
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

-- [ PREVIEW AURAS ]---------------------------------------------------------------------------------

local RAID_PREVIEW_AURA_CFG = {
    helpers = function() return Orbit.RaidFrameHelpers end,
    defaultAnchorX = "RIGHT", defaultJustifyH = "LEFT",
}
local RAID_PREVIEW_BUFF_CFG = {
    helpers = function() return Orbit.RaidFrameHelpers end,
    defaultAnchorX = "LEFT", defaultJustifyH = "RIGHT",
}

function Orbit.RaidFramePreviewMixin:ShowPreviewAuras(frame, frameIndex)
    local componentPositions = self:GetSetting(1, "ComponentPositions") or {}
    local debuffData = componentPositions.Debuffs or {}
    local buffData = componentPositions.Buffs or {}
    local debuffDisabled = self.IsComponentDisabled and self:IsComponentDisabled("Debuffs")
    local buffDisabled = self.IsComponentDisabled and self:IsComponentDisabled("Buffs")
    local maxDebuffs = (debuffData.overrides or {}).MaxIcons or 3
    local maxBuffs = (buffData.overrides or {}).MaxIcons or 3
    Orbit.AuraPreview:ShowIcons(frame, "debuff", debuffData, debuffDisabled and 0 or maxDebuffs, SAMPLE_DEBUFF_ICONS, debuffData.overrides, RAID_PREVIEW_AURA_CFG)
    Orbit.AuraPreview:ShowIcons(frame, "buff", buffData, buffDisabled and 0 or maxBuffs, SAMPLE_BUFF_ICONS, buffData.overrides, RAID_PREVIEW_BUFF_CFG)
end

-- [ PREVIEW HIDE ]----------------------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:HidePreview()
    if InCombatLockdown() or not self.frames then return end
    if not Helpers then Helpers = Orbit.RaidFrameHelpers end

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

            LCG.PixelGlow_Stop(frame, "preview")
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
