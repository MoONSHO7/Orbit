---@type Orbit
local Orbit = Orbit
local L = Orbit.L

local Plugin = Orbit:RegisterPlugin("Focus Power", "Orbit_FocusPower", {
    displayName = L.PLG_NAME_FOCUS_POWER,
    liveToggle = true,
    canvasMode = true,
    defaults = Orbit.UnitPowerBarMixin.sharedDefaults,
})

Mixin(Plugin, Orbit.UnitPowerBarMixin)

function Plugin:AddSettings(dialog, systemFrame)
    self:AddPowerBarSettings(dialog, systemFrame)
end

function Plugin:OnLoad()
    self:CreatePowerBarPlugin({
        unit = "focus",
        frameName = "FocusPower",
        displayName = "Focus Power",
        parentPlugin = "Orbit_FocusFrame",
        parentIndex = Enum.EditModeUnitFrameSystemIndices.Focus,
        enableKey = "EnableFocusPower",
        changeEvent = "PLAYER_FOCUS_CHANGED",
        yOffset = -200,
        textAnchor = { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = -2 },
        exposeMountedConfig = true,
    })
    Orbit.EventBus:On("ORBIT_FOCUS_SETTINGS_CHANGED", function() self:UpdateVisibility() end, self)
end
