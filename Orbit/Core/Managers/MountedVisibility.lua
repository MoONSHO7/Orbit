-- [ MOUNTED VISIBILITY MANAGER ]--------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

local MOUNTED_PREFIX = "[mounted] hide; "
local OPEN_WORLD_INSTANCE_TYPES = { ["none"] = true, ["scenario"] = true }

-- Blizzard frames to alpha-hide when mounted (the party left behind at the tavern)
local BLIZZARD_HIDE_FRAMES = {
    "ObjectiveTrackerFrame", "BuffFrame", "DebuffFrame",
    "ZoneTextFrame", "SubZoneTextFrame", "DurabilityFrame", "VehicleSeatIndicator",
    "MinimapZoneTextButton", "GameTimeFrame", "StreamingIcon",
    "TimeManagerClockButton", "AddonCompartmentFrame",
    "DamageMeter",
}

---@class MountedVisibilityManager
local Manager = {}
Orbit.MountedVisibility = Manager

local cachedShouldHide = false
local suppressedPlugins = {}

-- [ CORE LOGIC ]------------------------------------------------------------------------------------
local function IsMountedHideActive()
    if not Orbit.db or not Orbit.db.GlobalSettings or not Orbit.db.GlobalSettings.HideWhenMounted then return false end
    if not IsMounted() then return false end
    local _, instanceType = IsInInstance()
    return OPEN_WORLD_INSTANCE_TYPES[instanceType] == true
end

function Manager:ShouldHide() return IsMountedHideActive() end

function Manager:GetMountedDriver(baseDriver)
    if self:ShouldHide() then return MOUNTED_PREFIX .. baseDriver end
    return baseDriver
end

-- [ PLUGIN SUPPRESSION ]----------------------------------------------------------------------------
local function SuppressPlugin(plugin)
    local frame = plugin.mountedFrame
    if not frame then return end
    if not suppressedPlugins[plugin] then
        suppressedPlugins[plugin] = plugin.UpdateVisibility or true
        if plugin.UpdateVisibility then
            plugin.UpdateVisibility = function() end
        end
    end
    if not InCombatLockdown() and frame.GetAttribute and frame:GetAttribute("unit") then
        UnregisterUnitWatch(frame)
    end
    frame:Hide()
end

local function RestorePlugin(plugin)
    local origFn = suppressedPlugins[plugin]
    if not origFn then return end
    suppressedPlugins[plugin] = nil
    if origFn ~= true then plugin.UpdateVisibility = origFn end
    if plugin.UpdateVisibility then plugin:UpdateVisibility() end
end

-- [ BLIZZARD FRAME CONTROL ]------------------------------------------------------------------------
local function SetBlizzardFramesAlpha(alpha)
    for _, frameName in ipairs(BLIZZARD_HIDE_FRAMES) do
        local frame = _G[frameName]
        if frame and frame.SetAlpha then frame:SetAlpha(alpha) end
    end
    local cluster = _G["MinimapCluster"]
    if cluster then
        if cluster.BorderTop then
            cluster.BorderTop:SetAlpha(alpha)
            for _, child in pairs({ cluster.BorderTop:GetChildren() }) do child:SetAlpha(alpha) end
            for _, region in pairs({ cluster.BorderTop:GetRegions() }) do region:SetAlpha(alpha) end
        end
        if cluster.ZoneTextButton then cluster.ZoneTextButton:SetAlpha(alpha) end
        if cluster.Tracking then cluster.Tracking:SetAlpha(alpha) end
        if cluster.IndicatorFrame then cluster.IndicatorFrame:SetAlpha(alpha) end
    end
    local minimap = _G["Minimap"]
    if minimap then
        for _, child in pairs({ minimap:GetChildren() }) do
            local childName = child:GetName()
            if childName and childName:find("LibDBIcon") then child:SetAlpha(alpha) end
        end
    end
end

-- [ REFRESH ALL SYSTEMS ]---------------------------------------------------------------------------
function Manager:Refresh()
    local shouldHide = self:ShouldHide()
    if shouldHide == cachedShouldHide then return end
    cachedShouldHide = shouldHide

    if InCombatLockdown() then return end

    SetBlizzardFramesAlpha(shouldHide and 0 or 1)

    local systems = OrbitEngine.systems
    if not systems then return end
    for _, plugin in pairs(systems) do
        if shouldHide and plugin.mountedFrame then
            SuppressPlugin(plugin)
        elseif not shouldHide and suppressedPlugins[plugin] then
            RestorePlugin(plugin)
        else
            if plugin.UpdateVisibilityDriver then plugin:UpdateVisibilityDriver() end
            if plugin.UpdateVisibility then plugin:UpdateVisibility() end
        end
    end
end

-- [ EVENT REGISTRATION ]----------------------------------------------------------------------------
function Manager:Init()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and cachedShouldHide ~= self:ShouldHide() then
            self:Refresh()
            return
        end
        self:Refresh()
    end)
end

Manager:Init()
