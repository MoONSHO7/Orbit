---@type Orbit
local Orbit = Orbit
local L = Orbit.L

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Bag"
local DEFAULT_COLUMNS = 10
local DEFAULT_ICON_SIZE = 36
local DEFAULT_ICON_PADDING = 2

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Bag", SYSTEM_ID, {
    displayName = L.PLG_NAME_BAG,
    liveToggle = true,
    defaults = {
        Columns = DEFAULT_COLUMNS,
        IconSize = DEFAULT_ICON_SIZE,
        IconPadding = DEFAULT_ICON_PADDING,
    },
})

-- [ VISIBILITY HOOKS ]-------------------------------------------------------------------------------
local hooksInstalled = false
local function InstallToggleHooks(plugin)
    if hooksInstalled then return end
    hooksInstalled = true
    local function Show() plugin._isOpen = true; plugin:Refresh() end
    local function Hide() plugin._isOpen = false; plugin:Refresh() end
    hooksecurefunc("OpenAllBags", Show)
    hooksecurefunc("CloseAllBags", Hide)
    hooksecurefunc("OpenBackpack", Show)
    hooksecurefunc("CloseBackpack", Hide)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self._isOpen = false
    self.frame = Orbit.BagFrame:Build(self)

    local function refresh()
        Orbit.Async:Debounce("Orbit_Bag_Refresh", function() self:Refresh() end, 0.05)
    end
    Orbit.EventBus:On("BAG_UPDATE_DELAYED", refresh, self)
    Orbit.EventBus:On("BAG_CONTAINER_UPDATE", refresh, self)
    Orbit.EventBus:On("INVENTORY_SEARCH_UPDATE", refresh, self)
    Orbit.EventBus:On("BAG_NEW_ITEMS_UPDATED", refresh, self)
    Orbit.EventBus:On("ORBIT_BAG_CATEGORIES_CHANGED", refresh, self)

    if Orbit.BagHider then Orbit.BagHider:HideAll() end
    InstallToggleHooks(self)
    tinsert(UISpecialFrames, "OrbitBagFrame")
end

-- [ APPLY ]------------------------------------------------------------------------------------------
function Plugin:ApplySettings()
    self:Refresh()
end

function Plugin:Refresh()
    Orbit.BagFrame:Apply(self, self.frame)
end
