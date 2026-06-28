---@type Orbit
local Orbit = Orbit
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ REPAIR SUMMARY ]---------------------------------------------------------------------------------
local COIN_HEIGHT = 10

-- NpcAutomation (QoL) fires ORBIT_NPC_REPAIRED with the repair cost; render the repair-NPC crosshair on the centre vignette + the coin cost beside the orb when the widget is live.
Orbit.EventBus:On("ORBIT_NPC_REPAIRED", function(cost)
    if not Plugin.frame or Plugin._disabled then return end
    Plugin:PlayRepairFlourish(GetCoinTextureString(cost, COIN_HEIGHT))
end)

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
SLASH_ORBITREPAIR1 = "/orbitrepair"
SlashCmdList["ORBITREPAIR"] = function()
    if Plugin.frame and not Plugin._disabled then Plugin:PlayRepairFlourish(GetCoinTextureString(123456, COIN_HEIGHT)) end
end
