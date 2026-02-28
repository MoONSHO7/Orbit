---@type Orbit
local Orbit = Orbit

local Plugin = Orbit:RegisterPlugin("Focus Buffs", "Orbit_FocusBuffs", {
    defaults = Orbit.UnitAuraGridMixin.sharedBuffDefaults,
})

Mixin(Plugin, Orbit.AuraMixin)
Mixin(Plugin, Orbit.UnitAuraGridMixin)

function Plugin:IsEnabled()
    local enabled = Orbit:ReadPluginSetting("Orbit_FocusFrame", Enum.EditModeUnitFrameSystemIndices.Focus, "EnableBuffs")
    return enabled ~= false
end

function Plugin:AddSettings(dialog, systemFrame) self:AddAuraGridSettings(dialog, systemFrame) end

function Plugin:OnLoad()
    self:CreateAuraGridPlugin({
        unit = "focus", auraFilter = "HELPFUL", isHarmful = false,
        frameName = "OrbitFocusBuffsFrame", editModeName = "Focus Buffs",
        anchorParent = "OrbitFocusFrame", anchorGap = -50,
        defaultX = -200, defaultY = -280, initialWidth = 200, initialHeight = 40,
        changeEvent = "PLAYER_FOCUS_CHANGED", maxRowsMax = 6,
        showTimer = false, enablePandemic = false,
        exposeMountedConfig = true,
    })
    Orbit.EventBus:On("FOCUS_SETTINGS_CHANGED", function() self:UpdateVisibility() end, self)
end
