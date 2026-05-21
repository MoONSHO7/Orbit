---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

local Plugin = Orbit:RegisterPlugin("Player Buffs", "Orbit_PlayerBuffs", {
    displayName = L.PLG_NAME_PLAYER_BUFFS,
    defaults = Orbit.UnitAuraGridMixin.playerBuffDefaults,
    canvasMode = true,
})

Mixin(Plugin, Orbit.AuraMixin)
Mixin(Plugin, Orbit.UnitAuraGridMixin)

function Plugin:IsEnabled() return true end

function Plugin:AddSettings(dialog, systemFrame) self:AddAuraGridSettings(dialog, systemFrame) end

function Plugin:OnLoad()
    self:CreateAuraGridPlugin({
        unit = "player", auraFilter = "HELPFUL", isHarmful = false,
        frameName = "OrbitPlayerBuffsFrame", editModeName = self.displayName,
        defaultX = 230, defaultY = 360, initialWidth = 400, initialHeight = 20,
        changeEvent = "PLAYER_ENTERING_WORLD",
        showTimer = true, enablePandemic = false,
        showIconLimit = true, defaultIconLimit = 20,
        showRows = true,
        useBlizzardButtons = true, blizzardFrame = BuffFrame,
        exposeMountedConfig = true,
    })
    if BuffFrame then OrbitEngine.NativeFrame:KeepAliveHidden(BuffFrame) end
    SetCVar("buffDurations", 0)
    Orbit.EventBus:On("PLAYER_LOGOUT", function() SetCVar("buffDurations", 1) end)
end

function Plugin:OnDisable()
    SetCVar("buffDurations", 1)
end
