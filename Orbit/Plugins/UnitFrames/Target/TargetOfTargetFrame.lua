---@type Orbit
local Orbit = Orbit

local TOT_FRAME_INDEX = 100

local Plugin = Orbit:RegisterPlugin("Target of Target", "Orbit_TargetOfTargetFrame", {
    canvasMode = true,
    defaults = Orbit.SecondaryUnitFrameMixin.sharedDefaults,
})

Mixin(Plugin, Orbit.UnitFrameMixin)
Mixin(Plugin, Orbit.SecondaryUnitFrameMixin)

function Plugin:IsEnabled()
    return Orbit:ReadPluginSetting("Orbit_TargetFrame", Enum.EditModeUnitFrameSystemIndices.Target, "EnableTargetTarget") == true
end

function Plugin:AddSettings(dialog, systemFrame) self:AddSecondarySettings(dialog, systemFrame) end

function Plugin:OnLoad()
    self:CreateSecondaryPlugin({
        unit = "targettarget", parentUnit = "target",
        frameName = "OrbitTargetOfTargetFrame", editModeName = "Target of Target",
        frameIndex = TOT_FRAME_INDEX,
        nativeFrame = TargetFrameToT, hiddenParentName = "OrbitHiddenToTParent",
        changeEvent = "PLAYER_TARGET_CHANGED",
        defaultX = 200, defaultY = -180,
    })
    Orbit.EventBus:On("TARGET_SETTINGS_CHANGED", function() self:UpdateVisibility() end, self)
end
