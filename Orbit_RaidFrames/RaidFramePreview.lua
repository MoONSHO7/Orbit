---@type Orbit
local Orbit = Orbit
local LSM = LibStub("LibSharedMedia-3.0")

Orbit.RaidFramePreviewMixin = {}

local Helpers = nil
local DEBOUNCE_DELAY = 0.05

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_PREVIEW_FRAMES = 20
local PREVIEW_GROUPS = 4
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
    65, 100, 88, 55, 45,
    92, 78, 83, 97, 100,
}
local PREVIEW_ROLES = {
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "HEALER",
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER",
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER",
    "TANK", "HEALER", "DAMAGER", "DAMAGER", "HEALER",
}

-- [ PREVIEW SHOW ]---------------------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:ShowPreview()
    if InCombatLockdown() or not self.frames or not self.container then return end
    if not Helpers then Helpers = Orbit.RaidFrameHelpers end

    for i = 1, Helpers.LAYOUT.MaxRaidFrames do
        local frame = self.frames[i]
        if frame then
            Orbit:SafeAction(function() UnregisterUnitWatch(frame) end)
            frame:SetAttribute("unit", nil)
            frame.unit = nil
            frame:EnableMouse(false)
            if i <= MAX_PREVIEW_FRAMES then
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

    local width = self:GetSetting(1, "Width") or Helpers.LAYOUT.DefaultWidth
    local height = self:GetSetting(1, "Height") or Helpers.LAYOUT.DefaultHeight
    local borderSize = self:GetSetting(1, "BorderSize") or 1
    local showPower = self:GetSetting(1, "ShowPowerBar")
    if showPower == nil then showPower = true end
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
    local roleAtlases = Orbit.RoleAtlases

    for i = 1, MAX_PREVIEW_FRAMES do
        local frame = self.frames[i]
        if frame and frame.preview then
            frame:SetSize(width, height)
            Helpers:UpdateFrameLayout(frame, borderSize, showPower)

            if frame.Health then
                frame.Health:SetStatusBarTexture(texturePath)
                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(PREVIEW_HEALTH_PCTS[i])
                local className = PREVIEW_CLASSES[i]
                local classColor = RAID_CLASS_COLORS[className]
                if classColor then frame.Health:SetStatusBarColor(classColor.r, classColor.g, classColor.b) end
                frame.Health:Show()
            end

            if frame.Power then
                frame.Power:SetStatusBarTexture(texturePath)
                if showPower then
                    frame.Power:SetMinMaxValues(0, 100)
                    frame.Power:SetValue(80)
                    frame.Power:SetStatusBarColor(0.0, 0.44, 0.87)
                    frame.Power:Show()
                else
                    frame.Power:Hide()
                end
            end

            if frame.SetBorder then frame:SetBorder(borderSize) end
            self:ApplyBackdrop(frame)

            local isDisabled = self.IsComponentDisabled and function(key) return self:IsComponentDisabled(key) end or function() return false end

            if frame.Name then
                if isDisabled("Name") then frame.Name:Hide()
                else frame.Name:SetText(PREVIEW_NAMES[i]); frame.Name:Show() end
            end

            if frame.HealthText then
                if isDisabled("HealthText") then frame.HealthText:Hide()
                else frame.HealthText:SetText(PREVIEW_HEALTH_PCTS[i] .. "%"); frame.HealthText:Show() end
            end

            if self.ApplyTextStyling then self:ApplyTextStyling(frame) end

            if frame.RoleIcon and roleAtlases then
                if isDisabled("RoleIcon") then frame.RoleIcon:Hide()
                else
                    local role = PREVIEW_ROLES[i]
                    if roleAtlases[role] then frame.RoleIcon:SetAtlas(roleAtlases[role]); frame.RoleIcon:Show()
                    else frame.RoleIcon:Hide() end
                end
            end

            if frame.LeaderIcon then
                if isDisabled("LeaderIcon") then frame.LeaderIcon:Hide()
                elseif i == 1 then frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon"); frame.LeaderIcon:Show()
                else frame.LeaderIcon:Hide() end
            end

            for _, key in ipairs({ "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "MarkerIcon", "DefensiveIcon", "ImportantIcon", "CrowdControlIcon" }) do
                if frame[key] then frame[key]:Hide() end
            end

            if frame.SelectionHighlight then frame.SelectionHighlight:Hide() end
            if frame.aggroBorder then frame.aggroBorder:Hide() end

            local savedPositions = self:GetSetting(1, "ComponentPositions")
            if savedPositions then
                if frame.ApplyComponentPositions then frame:ApplyComponentPositions(savedPositions) end
                local icons = { "RoleIcon", "LeaderIcon", "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "MarkerIcon", "DefensiveIcon", "ImportantIcon", "CrowdControlIcon" }
                for _, iconKey in ipairs(icons) do
                    if frame[iconKey] and savedPositions[iconKey] then
                        local pos = savedPositions[iconKey]
                        local anchorX = pos.anchorX or "CENTER"
                        local anchorY = pos.anchorY or "CENTER"
                        local anchorPoint
                        if anchorY == "CENTER" and anchorX == "CENTER" then anchorPoint = "CENTER"
                        elseif anchorY == "CENTER" then anchorPoint = anchorX
                        elseif anchorX == "CENTER" then anchorPoint = anchorY
                        else anchorPoint = anchorY .. anchorX end
                        local finalX = pos.offsetX or 0
                        local finalY = pos.offsetY or 0
                        if anchorX == "RIGHT" then finalX = -finalX end
                        if anchorY == "TOP" then finalY = -finalY end
                        frame[iconKey]:ClearAllPoints()
                        frame[iconKey]:SetPoint("CENTER", frame, anchorPoint, finalX, finalY)
                    end
                end
            end
        end
    end
end

-- [ PREVIEW HIDE ]----------------------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:HidePreview()
    if InCombatLockdown() or not self.frames then return end

    for i = 1, (Helpers or Orbit.RaidFrameHelpers).LAYOUT.MaxRaidFrames do
        local frame = self.frames[i]
        if frame then
            frame.preview = nil
            frame:EnableMouse(true)
            local token = "raid" .. i
            frame:SetAttribute("unit", token)
            frame.unit = token
            frame:Hide()
        end
    end

    self:UpdateFrameUnits()
end

-- [ SCHEDULED PREVIEW UPDATE ]----------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:SchedulePreviewUpdate()
    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.frames and self.frames[1] and self.frames[1].preview then
            self:ApplyPreviewVisuals()
        end
    end)
end

-- [ BACKDROP HELPER ]-------------------------------------------------------------------------------

function Orbit.RaidFramePreviewMixin:ApplyBackdrop(frame)
    if not frame then return end
    self:CreateBackground(frame)
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(frame, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)
end
