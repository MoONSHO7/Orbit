---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local Plugin = Orbit:RegisterPlugin("Player Buffs", "Orbit_PlayerBuffs", {
    liveToggle = true,
    defaults = Orbit.UnitAuraGridMixin.playerBuffDefaults,
})

Mixin(Plugin, Orbit.AuraMixin)
Mixin(Plugin, Orbit.UnitAuraGridMixin)

function Plugin:IsEnabled() return true end

function Plugin:AddSettings(dialog, systemFrame) self:AddAuraGridSettings(dialog, systemFrame) end

function Plugin:OnLoad()
    self:CreateAuraGridPlugin({
        unit = "player", auraFilter = "HELPFUL", isHarmful = false,
        frameName = "OrbitPlayerBuffsFrame", editModeName = "Player Buffs",
        defaultX = 230, defaultY = 360, initialWidth = 400, initialHeight = 20,
        changeEvent = "PLAYER_ENTERING_WORLD",
        showTimer = true, enablePandemic = false,
        showIconLimit = true, defaultIconLimit = 20,
        showRows = true,
    })
    if BuffFrame then OrbitEngine.NativeFrame:Protect(BuffFrame) end
end
