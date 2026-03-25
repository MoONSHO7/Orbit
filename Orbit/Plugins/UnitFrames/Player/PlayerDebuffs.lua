---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local Plugin = Orbit:RegisterPlugin("Player Debuffs", "Orbit_PlayerDebuffs", {
    defaults = Orbit.UnitAuraGridMixin.playerDebuffDefaults,
    canvasMode = true,
})

Mixin(Plugin, Orbit.AuraMixin)
Mixin(Plugin, Orbit.UnitAuraGridMixin)

function Plugin:IsEnabled() return true end

function Plugin:AddSettings(dialog, systemFrame) self:AddAuraGridSettings(dialog, systemFrame) end

function Plugin:OnLoad()
    self:CreateAuraGridPlugin({
        unit = "player", auraFilter = "HARMFUL", isHarmful = true,
        frameName = "OrbitPlayerDebuffsFrame", editModeName = "Player Debuffs",
        defaultX = 230, defaultY = 310, initialWidth = 400, initialHeight = 20,
        changeEvent = "PLAYER_ENTERING_WORLD",
        showTimer = true, enablePandemic = false,
        showIconLimit = true, defaultIconLimit = 16,
        showRows = true,
        exposeMountedConfig = true,
    })
    if DebuffFrame then OrbitEngine.NativeFrame:Protect(DebuffFrame) end
end
