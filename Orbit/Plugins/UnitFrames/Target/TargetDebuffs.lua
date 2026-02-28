---@type Orbit
local Orbit = Orbit

local Plugin = Orbit:RegisterPlugin("Target Debuffs", "Orbit_TargetDebuffs", {
    defaults = Orbit.UnitAuraGridMixin.sharedDebuffDefaults,
})

Mixin(Plugin, Orbit.AuraMixin)
Mixin(Plugin, Orbit.UnitAuraGridMixin)

function Plugin:IsEnabled()
    local enabled = Orbit:ReadPluginSetting("Orbit_TargetFrame", Enum.EditModeUnitFrameSystemIndices.Target, "EnableDebuffs")
    return enabled ~= false
end

function Plugin:AddSettings(dialog, systemFrame) self:AddAuraGridSettings(dialog, systemFrame) end

function Plugin:OnLoad()
    self:CreateAuraGridPlugin({
        unit = "target", auraFilter = "HARMFUL|PLAYER", isHarmful = true,
        frameName = "OrbitTargetDebuffsFrame", editModeName = "Target Debuffs",
        anchorParent = "OrbitTargetFrame", anchorGap = -50,
        defaultX = 200, defaultY = -220, initialWidth = 200, initialHeight = 20,
        changeEvent = "PLAYER_TARGET_CHANGED", maxRowsMax = 4,
        showTimer = true, enablePandemic = true,
    })
    Orbit.EventBus:On("TARGET_SETTINGS_CHANGED", function() self:UpdateVisibility() end, self)
end
