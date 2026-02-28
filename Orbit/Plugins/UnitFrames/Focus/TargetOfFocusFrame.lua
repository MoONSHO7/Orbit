---@type Orbit
local Orbit = Orbit

local TOF_FRAME_INDEX = 101

local Plugin = Orbit:RegisterPlugin("Target of Focus", "Orbit_TargetOfFocusFrame", {
    canvasMode = true,
    defaults = Orbit.SecondaryUnitFrameMixin.sharedDefaults,
})

Mixin(Plugin, Orbit.UnitFrameMixin)
Mixin(Plugin, Orbit.SecondaryUnitFrameMixin)

function Plugin:IsEnabled()
    return Orbit:ReadPluginSetting("Orbit_FocusFrame", Enum.EditModeUnitFrameSystemIndices.Focus, "EnableFocusTarget") == true
end

function Plugin:AddSettings(dialog, systemFrame) self:AddSecondarySettings(dialog, systemFrame) end

function Plugin:OnLoad()
    self:CreateSecondaryPlugin({
        unit = "focustarget", parentUnit = "focus",
        frameName = "OrbitTargetOfFocusFrame", editModeName = "Target of Focus",
        frameIndex = TOF_FRAME_INDEX,
        nativeFrame = FocusFrameToT, hiddenParentName = "OrbitHiddenToFParent",
        changeEvent = "PLAYER_FOCUS_CHANGED",
        defaultX = -200, defaultY = -180,
        exposeMountedConfig = true,
    })
    Orbit.EventBus:On("FOCUS_SETTINGS_CHANGED", function() self:UpdateVisibility() end, self)
end
