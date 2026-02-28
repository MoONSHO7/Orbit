-- [ SECONDARY UNIT FRAME MIXIN ]--------------------------------------------------------------------
-- Shared mixin for TargetOfTarget and TargetOfFocus plugins.
-- Consumer files Mixin(Plugin, UnitFrameMixin) first, then Mixin(Plugin, SecondaryUnitFrameMixin).
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local FRAME_LEVEL_DEMOTE = 5

Orbit.SecondaryUnitFrameMixin = {}
local Mixin = Orbit.SecondaryUnitFrameMixin

Mixin.sharedDefaults = {
    Width = 100, Height = 20,
    DisabledComponents = { "HealthText" },
    ComponentPositions = { Name = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" } },
}

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Mixin:AddSecondarySettings(dialog, systemFrame)
    local cfg = self._sufConfig
    if systemFrame.systemIndex ~= cfg.frameIndex then return end
    Orbit.Config:Render(dialog, systemFrame, self, {
        hideNativeSettings = true,
        controls = {
            { type = "slider", key = "Width", label = "Width", min = 50, max = 200, step = 1, default = 100 },
            { type = "slider", key = "Height", label = "Height", min = 10, max = 40, step = 1, default = 20 },
        },
    })
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Mixin:CreateSecondaryPlugin(config)
    self._sufConfig = config
    self:RegisterStandardEvents()
    self:HideNativeUnitFrame(config.nativeFrame, config.hiddenParentName)

    self.frame = OrbitEngine.UnitButton:Create(UIParent, config.unit, config.frameName)
    if config.exposeMountedConfig then self.mountedConfig = { frame = self.frame } end
    self.frame:SetFrameLevel(math.max(1, self.frame:GetFrameLevel() - FRAME_LEVEL_DEMOTE))
    self.frame.editModeName = config.editModeName
    self.frame.systemIndex = config.frameIndex
    self.frame.anchorOptions = { horizontal = true, vertical = true, syncScale = false, syncDimensions = false, mergeBorders = true }

    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, config.frameIndex)

    -- Canvas Mode: draggable components
    if OrbitEngine.ComponentDrag and self.frame.Name then
        OrbitEngine.ComponentDrag:Attach(self.frame.Name, self.frame, {
            key = "Name", onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, config.frameIndex, "Name"),
        })
    end
    if self.frame.HealthText then
        OrbitEngine.ComponentDrag:Attach(self.frame.HealthText, self.frame, {
            key = "HealthText", onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, config.frameIndex, "HealthText"),
        })
    end

    local plugin = self
    local originalOnEvent = self.frame:GetScript("OnEvent")
    self.frame:SetScript("OnEvent", function(f, event, unit, ...)
        if event == config.changeEvent or (event == "UNIT_TARGET" and unit == config.parentUnit) then
            if plugin:IsEnabled() then f:UpdateAll() end
            return
        end
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            if UnitExists(config.unit) then f:UpdateHealth(); f:UpdateHealthText() end
            return
        end
        if event == "PET_BATTLE_OPENING_START" or event == "UNIT_ENTERED_VEHICLE" then
            Orbit:SafeAction(function() f:Hide() end)
            return
        end
        if event == "PET_BATTLE_CLOSE" or event == "UNIT_EXITED_VEHICLE" then
            plugin:ApplySettings(f)
            return
        end
        if originalOnEvent then originalOnEvent(f, event, unit, ...) end
    end)

    self:ApplySettings(self.frame)

    OrbitEngine.Frame:RestorePosition(self.frame, self, config.frameIndex)
    if not self.frame:GetPoint() then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", config.defaultX or 0, config.defaultY or -180)
    end
end

-- [ EVENTS ]----------------------------------------------------------------------------------------
function Mixin:RegisterSecondaryEvents(enabled)
    local frame = self.frame
    local cfg = self._sufConfig
    if not frame then return end
    local events = { "UNIT_TARGET", cfg.changeEvent, "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }
    for _, ev in ipairs(events) do
        if enabled then frame:RegisterEvent(ev) else frame:UnregisterEvent(ev) end
    end
    if enabled then RegisterUnitWatch(frame) else UnregisterUnitWatch(frame) end
end

function Mixin:UpdateVisibility() self:ApplySettings() end

-- [ APPLY SETTINGS ]--------------------------------------------------------------------------------
function Mixin:ApplySettings()
    local frame = self.frame
    local cfg = self._sufConfig
    if not frame or InCombatLockdown() then return end

    local systemIndex = cfg.frameIndex
    local enabled = self:IsEnabled()
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    if not enabled then
        UnregisterUnitWatch(frame)
        frame:Hide()
        return
    end

    if inEditMode then
        UnregisterUnitWatch(frame)
        if not UnitExists(cfg.unit) then frame.unit = "player" end
        frame:Show()
        frame:UpdateAll()
    else
        frame.unit = cfg.unit
        self:RegisterSecondaryEvents(enabled)
    end

    frame:SetSize(self:GetSetting(systemIndex, "Width") or 100, self:GetSetting(systemIndex, "Height") or 20)
    self:ApplyBaseVisuals(frame, systemIndex)

    local fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font) or "Fonts\\FRIZQT__.TTF"
    if frame.Name then
        local h = frame:GetHeight()
        frame.Name:SetFont(fontPath, Orbit.Skin:GetAdaptiveTextSize(h, 10, 18, 0.25), Orbit.Skin:GetFontOutline())
        frame.Name:ClearAllPoints()
        frame.Name:SetPoint("CENTER", 0, 0)
        frame.Name:SetJustifyH("CENTER")
        frame.Name:SetShadowColor(0, 0, 0, 1)
        frame.Name:SetShadowOffset(1, -1)
    end

    if self:IsComponentDisabled("HealthText") then
        frame.healthTextEnabled = false
        if frame.HealthText then frame.HealthText:Hide() end
    else
        frame.healthTextEnabled = true
        if frame.HealthText then frame.HealthText:Show(); frame:UpdateHealthText() end
    end

    frame.UpdateTextLayout = function() end
    if frame.Power then frame.Power:Hide() end

    frame:SetClassColour(self:GetPlayerSetting("ClassColour"))
    if frame.SetReactionColour then frame:SetReactionColour(true) end
    if enabled then frame:UpdateAll() end

    local isInCanvasMode = OrbitEngine.CanvasMode:IsActive(frame)
    if not isInCanvasMode then
        local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
        if savedPositions then
            OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
            if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end
        end
    end
end

function Mixin:UpdateVisuals(frame)
    if frame and frame.UpdateAll and (self:IsEnabled() or (EditModeManagerFrame and EditModeManagerFrame:IsShown())) then
        frame:UpdateAll()
    end
end
