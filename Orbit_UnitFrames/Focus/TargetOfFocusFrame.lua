---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_TargetOfFocusFrame"
local TOF_FRAME_INDEX = 101 -- Custom index for Orbit-only frames
local FOCUS_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Focus
local FRAME_LEVEL_DEMOTE = 5

local Plugin = Orbit:RegisterPlugin("Target of Focus", SYSTEM_ID, {
    canvasMode = true, -- Enable Canvas Mode for component editing
    defaults = {
        Width = 100,
        Height = 20,
        DisabledComponents = { "HealthText" },
        ComponentPositions = {
            Name = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
        },
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

-- Apply Mixin
Mixin(Plugin, Orbit.UnitFrameMixin)

-- [ HELPER ]----------------------------------------------------------------------------------------
function Plugin:IsEnabled()
    -- Read EnableFocusTarget setting from FocusFrame plugin
    local focusPlugin = Orbit:GetPlugin("Orbit_FocusFrame")
    if focusPlugin and focusPlugin.GetSetting then
        local enabled = focusPlugin:GetSetting(FOCUS_FRAME_INDEX, "EnableFocusTarget")
        return enabled == true
    end
    return false
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex
    if systemIndex ~= TOF_FRAME_INDEX then
        return
    end

    local schema = {
        hideNativeSettings = true,
        controls = {
            { type = "slider", key = "Width", label = "Width", min = 50, max = 200, step = 5, default = 100 },
            { type = "slider", key = "Height", label = "Height", min = 10, max = 40, step = 5, default = 20 },
        },
    }

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self:RegisterStandardEvents()

    -- Hide native FocusFrameToT
    self:HideNativeUnitFrame(FocusFrameToT, "OrbitHiddenToFParent")

    -- Create frame directly on UIParent
    self.frame = OrbitEngine.UnitButton:Create(UIParent, "focustarget", "OrbitTargetOfFocusFrame")
    self.frame:SetFrameLevel(math.max(1, self.frame:GetFrameLevel() - FRAME_LEVEL_DEMOTE))
    self.frame.editModeName = "Target of Focus"
    self.frame.systemIndex = TOF_FRAME_INDEX

    -- Enable Anchoring: both horizontal and vertical
    -- Disable Property Sync: keep own scale and dimensions
    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
        syncScale = false,
        syncDimensions = false,
        mergeBorders = true,
    }

    -- Attach to Orbit Frame system
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, TOF_FRAME_INDEX)

    -- Canvas Mode: Register draggable components
    if OrbitEngine.ComponentDrag and self.frame.Name then
        OrbitEngine.ComponentDrag:Attach(self.frame.Name, self.frame, {
            key = "Name",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = self:GetSetting(TOF_FRAME_INDEX, "ComponentPositions") or {}
                positions.Name = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                self:SetSetting(TOF_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
    end

    -- Attach HealthText for drag in Canvas Mode
    if self.frame.HealthText then
        OrbitEngine.ComponentDrag:Attach(self.frame.HealthText, self.frame, {
            key = "HealthText",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = self:GetSetting(TOF_FRAME_INDEX, "ComponentPositions") or {}
                positions.HealthText = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                self:SetSetting(TOF_FRAME_INDEX, "ComponentPositions", positions)
            end,
        })
    end

    local plugin = self
    local originalOnEvent = self.frame:GetScript("OnEvent")
    self.frame:SetScript("OnEvent", function(f, event, unit, ...)
        if event == "PLAYER_FOCUS_CHANGED" or (event == "UNIT_TARGET" and unit == "focus") then
            -- Only update if enabled (or in Edit Mode AND enabled)
            if plugin:IsEnabled() then
                f:UpdateAll()
            end
            return
        end
        -- Handle UNIT_HEALTH: skip comparisons, just update (UnitHealth API handles focustarget correctly)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            if UnitExists("focustarget") then
                f:UpdateHealth()
                f:UpdateHealthText()
            end
            return
        end
        -- Handle pet battle/vehicle visibility
        if event == "PET_BATTLE_OPENING_START" or event == "UNIT_ENTERED_VEHICLE" then
            Orbit:SafeAction(function()
                f:Hide()
            end)
            return
        end
        if event == "PET_BATTLE_CLOSE" or event == "UNIT_EXITED_VEHICLE" then
            plugin:ApplySettings(f)
            return
        end
        if originalOnEvent then
            originalOnEvent(f, event, unit, ...)
        end
    end)

    -- Apply settings
    self:ApplySettings(self.frame)

    -- Default Position
    OrbitEngine.Frame:RestorePosition(self.frame, self, TOF_FRAME_INDEX)
    if not self.frame:GetPoint() then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", -200, -180)
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:RegisterEvents(enabled)
    local frame = self.frame
    if not frame then
        return
    end

    if enabled then
        -- Enable UnitWatch (Standard WoW behavior)
        RegisterUnitWatch(frame)

        frame:RegisterEvent("UNIT_TARGET")
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        frame:RegisterEvent("PET_BATTLE_OPENING_START")
        frame:RegisterEvent("PET_BATTLE_CLOSE")
        frame:RegisterEvent("UNIT_ENTERED_VEHICLE")
        frame:RegisterEvent("UNIT_EXITED_VEHICLE")
    else
        -- Disable UnitWatch
        UnregisterUnitWatch(frame)

        frame:UnregisterEvent("UNIT_TARGET")
        frame:UnregisterEvent("PLAYER_FOCUS_CHANGED")
        frame:UnregisterEvent("PET_BATTLE_OPENING_START")
        frame:UnregisterEvent("PET_BATTLE_CLOSE")
        frame:UnregisterEvent("UNIT_ENTERED_VEHICLE")
        frame:UnregisterEvent("UNIT_EXITED_VEHICLE")
    end
end

function Plugin:ApplySettings(frame)
    frame = self.frame
    if not frame or InCombatLockdown() then
        return
    end
    local systemIndex = TOF_FRAME_INDEX

    -- Check if enabled via FocusFrame setting
    local enabled = self:IsEnabled()
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    -- If disabled, hide the frame completely (including in Edit Mode)
    if not enabled then
        UnregisterUnitWatch(frame)
        frame:Hide()
        return
    end

    if inEditMode then
        -- In Edit Mode AND enabled: manually show for positioning
        UnregisterUnitWatch(frame)

        -- Use player as preview unit if no actual unit exists
        if not UnitExists("focustarget") then
            frame.unit = "player"
        end

        frame:Show()
        frame:UpdateAll()
    else
        -- Normal operation: revert unit and let RegisterUnitWatch handle visibility
        frame.unit = "focustarget"
        self:RegisterEvents(enabled)
    end

    -- Get settings
    local width = self:GetSetting(systemIndex, "Width") or 100
    local height = self:GetSetting(systemIndex, "Height") or 20

    -- Apply size
    frame:SetSize(width, height)

    -- Apply Base Settings via Mixin
    self:ApplyBaseVisuals(frame, systemIndex)

    -- ToF Specific Visuals
    local globalFontName = Orbit.db.GlobalSettings.Font
    local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"

    if frame.Name then
        local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 10, 18, 0.25)
        frame.Name:SetFont(fontPath, textSize, Orbit.Skin:GetFontOutline())
        frame.Name:ClearAllPoints()
        frame.Name:SetPoint("CENTER", 0, 0)
        frame.Name:SetJustifyH("CENTER")
        frame.Name:SetShadowColor(0, 0, 0, 1)
        frame.Name:SetShadowOffset(1, -1)
    end

    -- Check if HealthText is disabled in Canvas Mode
    if self:IsComponentDisabled("HealthText") then
        frame.healthTextEnabled = false
        if frame.HealthText then
            frame.HealthText:Hide()
        end
    else
        frame.healthTextEnabled = true
        if frame.HealthText then
            frame.HealthText:Show()
            frame:UpdateHealthText()
        end
    end

    -- Stub UpdateTextLayout to prevent it from overriding centered name
    frame.UpdateTextLayout = function() end

    -- Hide Power Bar
    if frame.Power then
        frame.Power:Hide()
    end

    -- Enable Class Colour (inherited from player) and Reaction Color
    local classColour = self:GetPlayerSetting("ClassColour")
    frame:SetClassColour(classColour)

    if frame.SetReactionColour then
        frame:SetReactionColour(true)
    end

    -- Update frame
    if enabled then
        frame:UpdateAll()
    end

    local isInCanvasMode = OrbitEngine.ComponentEdit and OrbitEngine.ComponentEdit:IsActive(frame)
    if not isInCanvasMode then
        local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
        if savedPositions then
            if OrbitEngine.ComponentDrag then OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions) end
            if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end
        end
    end
end

function Plugin:UpdateVisuals(frame)
    if frame and frame.UpdateAll and (self:IsEnabled() or (EditModeManagerFrame and EditModeManagerFrame:IsShown())) then
        frame:UpdateAll()
    end
end
