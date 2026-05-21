local _, addonTable = ...
local Orbit = addonTable

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local NUM_CONTAINER_FRAMES = 13
local MAX_BACKPACK_BAG_INDEX = 5

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.BagHider = {}
local BagHider = Orbit.BagHider

-- [ STATE OVERRIDES ]--------------------------------------------------------------------------------
local function PluginIsOpen()
    local plugin = Orbit:GetPlugin("Orbit_Bag")
    return plugin and plugin._isOpen or false
end

local function SetPluginClosed()
    local plugin = Orbit:GetPlugin("Orbit_Bag")
    if not plugin then return end
    if plugin._isOpen then
        plugin._isOpen = false
        plugin:Refresh()
    end
end

local function InstallStateOverrides()
    if BagHider._overridesInstalled then return end
    BagHider._overridesInstalled = true
    IsBackpackOpen = PluginIsOpen
    IsAnyBagOpen = PluginIsOpen
    IsAnyStandardHeldBagOpen = PluginIsOpen
    IsBagOpen = function(id)
        if id and id >= 0 and id <= MAX_BACKPACK_BAG_INDEX then return PluginIsOpen() end
        return false
    end
end

-- [ PARK BLIZZARD FRAMES ]---------------------------------------------------------------------------
local function ParkFrame(name)
    local frame = _G[name]
    if frame and Orbit.Engine.NativeFrame then Orbit.Engine.NativeFrame:Park(frame) end
end

local function HookCloseFromTemplate()
    if BagHider._closeHookInstalled then return end
    local combined = _G.ContainerFrameCombinedBags
    if not combined then return end
    BagHider._closeHookInstalled = true
    hooksecurefunc(combined, "Hide", SetPluginClosed)
end

function BagHider:HideAll()
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:HideAll() end)
        return
    end
    ParkFrame("ContainerFrameCombinedBags")
    for i = 1, NUM_CONTAINER_FRAMES do ParkFrame("ContainerFrame" .. i) end
    InstallStateOverrides()
    HookCloseFromTemplate()
end
