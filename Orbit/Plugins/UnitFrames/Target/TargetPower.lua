---@type Orbit
local Orbit = Orbit

local Plugin = Orbit:RegisterPlugin("Target Power", "Orbit_TargetPower", {
    canvasMode = true,
    defaults = Orbit.UnitPowerBarMixin.sharedDefaults,
})

Mixin(Plugin, Orbit.UnitPowerBarMixin)

function Plugin:AddSettings(dialog, systemFrame)
    self:AddPowerBarSettings(dialog, systemFrame)
end

function Plugin:OnLoad()
    self:CreatePowerBarPlugin({
        unit = "target",
        frameName = "TargetPower",
        displayName = "Target Power",
        parentPlugin = "Orbit_TargetFrame",
        parentIndex = Enum.EditModeUnitFrameSystemIndices.Target,
        enableKey = "EnableTargetPower",
        changeEvent = "PLAYER_TARGET_CHANGED",
        yOffset = -180,
        textAnchor = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 2 },
    })
    Orbit.EventBus:On("TARGET_SETTINGS_CHANGED", function() self:UpdateVisibility() end, self)
end
