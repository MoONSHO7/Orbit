-- [ MOUNTED VISIBILITY MANAGER ]--------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

local MOUNTED_COMBAT_PREFIX = "[mounted,nocombat] hide; "
local MOUNTED_ALWAYS_PREFIX = "[mounted] hide; "
local OPEN_WORLD_INSTANCE_TYPES = { ["none"] = true, ["scenario"] = true }
local REAPPLY_DELAY = 0.5

local BLIZZARD_HIDE_FRAMES = {
    "ObjectiveTrackerFrame", "BuffFrame", "DebuffFrame",
    "ZoneTextFrame", "SubZoneTextFrame", "DurabilityFrame", "VehicleSeatIndicator",
    "GameTimeFrame", "StreamingIcon",
    "TimeManagerClockButton", "AddonCompartmentFrame",
    "DamageMeter",
}

---@class MountedVisibilityManager
local Manager = {}
Orbit.MountedVisibility = Manager

local cachedShouldHide = false
local suppressedPlugins = {}
local combatRestoredPlugins = {}
local NOOP = function() end

-- [ CORE LOGIC ]------------------------------------------------------------------------------------
local function IsMountedHideActive()
    if not Orbit.db or not Orbit.db.GlobalSettings or not Orbit.db.GlobalSettings.HideWhenMounted then return false end
    if Orbit.IsEditMode and Orbit:IsEditMode() then return false end
    if not IsMounted() then return false end
    local _, instanceType = IsInInstance()
    return OPEN_WORLD_INSTANCE_TYPES[instanceType] == true
end

function Manager:ShouldHide() return IsMountedHideActive() end

function Manager:GetMountedDriver(baseDriver, combatEssential)
    if not self:ShouldHide() then return baseDriver end
    local prefix = combatEssential and MOUNTED_COMBAT_PREFIX or MOUNTED_ALWAYS_PREFIX
    return prefix .. baseDriver
end

-- [ PLUGIN SUPPRESSION ]----------------------------------------------------------------------------
local function SuppressPlugin(plugin)
    local frame = plugin.mountedFrame
    if not frame then return end
    if not suppressedPlugins[plugin] then
        suppressedPlugins[plugin] = {
            UpdateVisibility = plugin.UpdateVisibility,
            ApplySettings = plugin.ApplySettings,
        }
        plugin.UpdateVisibility = NOOP
        plugin.ApplySettings = NOOP
    end
    frame.orbitMountedSuppressed = true
    frame:SetAlpha(0)
    if plugin.mountedHoverReveal then
        if not frame.orbitHoverOverlay then
            local overlay = CreateFrame("Frame", nil, frame)
            overlay:SetAllPoints()
            overlay:SetFrameLevel(frame:GetFrameLevel() + 100)
            overlay:EnableMouse(true)
            overlay:SetMouseMotionEnabled(true)
            overlay:SetMouseClickEnabled(false)
            overlay:SetScript("OnEnter", function(self)
                frame.orbitMountedSuppressed = false
                frame:SetAlpha(1)
                self:Hide()
                frame:SetScript("OnUpdate", function()
                    if not frame:IsMouseOver() then
                        if suppressedPlugins[plugin] then
                            frame.orbitMountedSuppressed = true
                            frame:SetAlpha(0)
                            if not self:IsShown() then self:Show() end
                        else
                            frame:SetScript("OnUpdate", nil)
                        end
                    end
                end)
            end)
            frame.orbitHoverOverlay = overlay
        end
        frame.orbitHoverOverlay:Show()
    end
end

local function RestorePlugin(plugin)
    local saved = suppressedPlugins[plugin]
    if not saved then return end
    suppressedPlugins[plugin] = nil
    combatRestoredPlugins[plugin] = nil
    if saved.UpdateVisibility then plugin.UpdateVisibility = saved.UpdateVisibility end
    if saved.ApplySettings then plugin.ApplySettings = saved.ApplySettings end
    local frame = plugin.mountedFrame
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame.orbitMountedSuppressed = nil
        frame.orbitLastVisibilityDriver = nil
        if plugin.mountedHoverReveal and Orbit.Animation then Orbit.Animation:StopHoverFade(frame) end
        frame:SetAlpha(1)
        if frame.orbitHoverOverlay then frame.orbitHoverOverlay:Hide() end
    end
    if plugin.ApplySettings then
        plugin:ApplySettings()
        if plugin.mountedHoverReveal then
            C_Timer.After(0, function() plugin:ApplySettings() end)
        end
    end
end

-- [ COMBAT-ESSENTIAL RESTORE ]----------------------------------------------------------------------
local function RestoreCombatEssentials()
    for plugin in pairs(suppressedPlugins) do
        if plugin.mountedCombatRestore and plugin.mountedFrame then
            plugin.mountedFrame:SetAlpha(1)
            combatRestoredPlugins[plugin] = true
        end
    end
end

local function SuppressCombatEssentials()
    for plugin in pairs(combatRestoredPlugins) do
        if suppressedPlugins[plugin] and plugin.mountedFrame then
            plugin.mountedFrame:SetScript("OnUpdate", nil)
            plugin.mountedFrame:SetAlpha(0)
        end
    end
    wipe(combatRestoredPlugins)
end

-- [ BLIZZARD FRAME CONTROL ]------------------------------------------------------------------------
local function SetBlizzardFramesAlpha(alpha)
    for _, frameName in ipairs(BLIZZARD_HIDE_FRAMES) do
        local frame = _G[frameName]
        if frame then frame:SetAlpha(alpha) end
    end
    local cluster = _G["MinimapCluster"]
    if cluster then
        if cluster.BorderTop then cluster.BorderTop:SetAlpha(alpha) end
        if cluster.ZoneTextButton then cluster.ZoneTextButton:SetAlpha(alpha) end
        if cluster.Tracking then cluster.Tracking:SetAlpha(alpha) end
        if cluster.IndicatorFrame then cluster.IndicatorFrame:SetAlpha(alpha) end
        if cluster.InstanceDifficulty then cluster.InstanceDifficulty:SetAlpha(alpha) end
    end
    local minimap = _G["Minimap"]
    if minimap then
        for _, child in ipairs({ minimap:GetChildren() }) do
            if child.GetName and (child:GetName() or ""):find("LibDBIcon") then child:SetAlpha(alpha) end
        end
    end
end

local function SetupMinimapHoverOverlay()
    local cluster = _G["MinimapCluster"]
    if not cluster or cluster.orbitHoverOverlay then return end
    local overlay = CreateFrame("Frame", nil, cluster)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cluster:GetFrameLevel() + 100)
    overlay:EnableMouse(true)
    overlay:SetMouseMotionEnabled(true)
    overlay:SetMouseClickEnabled(false)
    overlay:SetScript("OnEnter", function(self)
        SetBlizzardFramesAlpha(1)
        self:Hide()
        cluster:SetScript("OnUpdate", function()
            if not cluster:IsMouseOver() then
                cluster:SetScript("OnUpdate", nil)
                if cachedShouldHide then
                    SetBlizzardFramesAlpha(0)
                    self:Show()
                end
            end
        end)
    end)
    cluster.orbitHoverOverlay = overlay
    overlay:Hide()
end

-- [ REFRESH ALL SYSTEMS ]---------------------------------------------------------------------------
function Manager:Refresh(force)
    local shouldHide = self:ShouldHide()
    if not force and shouldHide == cachedShouldHide then return end
    cachedShouldHide = shouldHide

    SetBlizzardFramesAlpha(shouldHide and 0 or 1)
    SetupMinimapHoverOverlay()
    local cluster = _G["MinimapCluster"]
    if cluster and cluster.orbitHoverOverlay then
        if shouldHide then
            cluster.orbitHoverOverlay:Show()
        else
            cluster:SetScript("OnUpdate", nil)
            cluster.orbitHoverOverlay:Hide()
        end
    end

    local systems = OrbitEngine.systems
    if not systems then return end
    for _, plugin in pairs(systems) do
        if shouldHide and plugin.mountedFrame then
            SuppressPlugin(plugin)
        elseif not shouldHide and suppressedPlugins[plugin] then
            RestorePlugin(plugin)
        else
            if plugin.UpdateVisibilityDriver then
                plugin:UpdateVisibilityDriver()
            elseif plugin.UpdateVisibility then
                plugin:UpdateVisibility()
            end
        end
    end
end

-- [ EVENT REGISTRATION ]----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Manager:Refresh(true)
        C_Timer.After(REAPPLY_DELAY, function() Manager:Refresh(true) end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        RestoreCombatEssentials()
    elseif event == "PLAYER_REGEN_ENABLED" then
        SuppressCombatEssentials()
        Manager:Refresh()
    else
        Manager:Refresh()
    end
end)

if EditModeManagerFrame then
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() Manager:Refresh(true) end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() Manager:Refresh(true) end)
end
