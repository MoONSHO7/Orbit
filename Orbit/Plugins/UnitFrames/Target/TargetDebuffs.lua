---@type Orbit
local Orbit = Orbit
local L = Orbit.L

local Plugin = Orbit:RegisterPlugin("Target Debuffs", "Orbit_TargetDebuffs", {
    displayName = L.PLG_NAME_TARGET_DEBUFFS,
    liveToggle = true,
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
        frameName = "OrbitTargetDebuffsFrame", editModeName = self.displayName,
        anchorParent = "OrbitTargetFrame", anchorGap = -50,
        defaultX = 200, defaultY = -220, initialWidth = 200, initialHeight = 20,
        changeEvent = "PLAYER_TARGET_CHANGED", maxRowsMax = 4,
        showTimer = true, enablePandemic = true,
        vePluginName = "Target Frame",
    })
    Orbit.EventBus:On("ORBIT_TARGET_SETTINGS_CHANGED", function() self:UpdateVisibility() end, self)
end
