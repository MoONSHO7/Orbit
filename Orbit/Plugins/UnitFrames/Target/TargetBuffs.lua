---@type Orbit
local Orbit = Orbit

local Plugin = Orbit:RegisterPlugin("Target Buffs", "Orbit_TargetBuffs", {
    defaults = Orbit.UnitAuraGridMixin.sharedBuffDefaults,
})

Mixin(Plugin, Orbit.AuraMixin)
Mixin(Plugin, Orbit.UnitAuraGridMixin)

function Plugin:IsEnabled()
    local enabled = Orbit:ReadPluginSetting("Orbit_TargetFrame", Enum.EditModeUnitFrameSystemIndices.Target, "EnableBuffs")
    return enabled ~= false
end

function Plugin:AddSettings(dialog, systemFrame) self:AddAuraGridSettings(dialog, systemFrame) end

function Plugin:OnLoad()
    self:CreateAuraGridPlugin({
        unit = "target", auraFilter = "HELPFUL", isHarmful = false,
        frameName = "OrbitTargetBuffsFrame", editModeName = "Target Buffs",
        anchorParent = "OrbitTargetFrame", anchorGap = -50,
        defaultX = 200, defaultY = -280, initialWidth = 200, initialHeight = 20,
        changeEvent = "PLAYER_TARGET_CHANGED", maxRowsMax = 4,
        showTimer = false, enablePandemic = false,
    })
    Orbit.EventBus:On("TARGET_SETTINGS_CHANGED", function() self:UpdateVisibility() end, self)
end
