-- [ MOUNTED VISIBILITY MANAGER ]--------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MOUNTED_COMBAT_PREFIX = "[mounted,nocombat] hide; "
local MOUNTED_ALWAYS_PREFIX = "[mounted] hide; "
local OPEN_WORLD_INSTANCE_TYPES = { ["none"] = true, ["scenario"] = true }
local REAPPLY_DELAY = 0.5
local OVERLAY_LEVEL_BOOST = 100
local DRUID_TRAVEL_FORMS = { [DRUID_TRAVEL_FORM] = true, [DRUID_FLIGHT_FORM] = true }
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
local isEditModeRestoring = false

-- [ CONFIG READER ]---------------------------------------------------------------------------------
-- The party's scout reads the mounted config scroll before engaging
local function GetConfig(plugin) return plugin.mountedConfig end
local function GetFrame(plugin) local cfg = GetConfig(plugin); return cfg and cfg.frame end

-- [ FRAME SUPPRESS / REVEAL ]-----------------------------------------------------------------------
local function SuppressFrame(frame)
    frame.orbitMountedSuppressed = true
    frame:SetAlpha(0)
    if frame.Portrait then frame.Portrait:Hide() end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.NameFrame then child.NameFrame:Hide() end
    end
end

local function RevealFrame(frame)
    frame.orbitMountedSuppressed = false
    frame:SetAlpha(1)
    if frame.UpdatePortrait then frame:UpdatePortrait() end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.NameFrame then child.NameFrame:Show() end
    end
end

-- [ CORE LOGIC ]------------------------------------------------------------------------------------
local function IsInDruidTravelForm() return DRUID_TRAVEL_FORMS[GetShapeshiftFormID()] == true end

local function IsMountedHideActive()
    if Orbit.IsEditMode and Orbit:IsEditMode() then return false end
    if OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then return false end
    if not IsMounted() and not IsInDruidTravelForm() then return false end
    -- Check if any frame actually has hideMounted enabled in VE
    if Orbit.VisibilityEngine then
        if not Orbit.VisibilityEngine:AnyFrameHasSetting("hideMounted") then return false end
    else
        -- Fallback to legacy global setting if VE not loaded yet
        if not Orbit.db or not Orbit.db.GlobalSettings or not Orbit.db.GlobalSettings.HideWhenMounted then return false end
    end
    local _, instanceType = IsInInstance()
    return OPEN_WORLD_INSTANCE_TYPES[instanceType] == true
end

function Manager:ShouldHide() return IsMountedHideActive() end

-- Check per-frame VE hideMounted setting for a plugin
local function ShouldHidePlugin(plugin)
    if not Orbit.VisibilityEngine then return false end
    local veKey = Orbit.VisibilityEngine:GetKeyForPlugin(plugin.name, (plugin.mountedConfig and plugin.mountedConfig.frame and plugin.mountedConfig.frame.systemIndex) or 1)
    if not veKey then return false end
    return Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted")
end
function Manager:ShouldHidePlugin(plugin) return ShouldHidePlugin(plugin) end

-- Check per-frame VE hideMounted setting for a Blizzard frame key
local function ShouldHideBlizzard(veKey)
    if not Orbit.VisibilityEngine then return false end
    return Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted")
end
function Manager:ShouldHideBlizzard(veKey) return ShouldHideBlizzard(veKey) end

function Manager:GetMountedDriver(baseDriver, combatEssential)
    if not self:ShouldHide() then return baseDriver end
    local prefix = combatEssential and MOUNTED_COMBAT_PREFIX or MOUNTED_ALWAYS_PREFIX
    return prefix .. baseDriver
end

-- [ HOVER OVERLAY FACTORY ]-------------------------------------------------------------------------
local function CreateHoverOverlay(frame, plugin)
    if frame.orbitHoverOverlay then return end
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + OVERLAY_LEVEL_BOOST)
    overlay:EnableMouse(true)
    overlay:SetMouseMotionEnabled(true)
    overlay:SetMouseClickEnabled(false)
    overlay:SetScript("OnEnter", function(self)
        RevealFrame(frame)
        self:Hide()
        frame:SetScript("OnUpdate", function()
            if not frame:IsMouseOver() then
                if not suppressedPlugins[plugin] then
                    frame:SetScript("OnUpdate", nil)
                elseif frame.orbitTargetRevealed then
                    frame:SetScript("OnUpdate", nil)
                else
                    SuppressFrame(frame)
                    if not self:IsShown() then self:Show() end
                end
            end
        end)
    end)
    frame.orbitHoverOverlay = overlay
end

-- [ PLUGIN SUPPRESSION ]----------------------------------------------------------------------------
local function SuppressPlugin(plugin)
    local cfg = GetConfig(plugin)
    if not cfg then return end
    local frame = cfg.frame
    if not frame then return end
    suppressedPlugins[plugin] = true
    SuppressFrame(frame)
    if cfg.hoverReveal then
        CreateHoverOverlay(frame, plugin)
        frame.orbitHoverOverlay:Show()
        if cfg.targetReveal and UnitExists("target") then
            frame.orbitTargetRevealed = true
            RevealFrame(frame)
            frame.orbitHoverOverlay:Hide()
        end
    end
end

local function RestorePlugin(plugin)
    if not suppressedPlugins[plugin] then return end
    suppressedPlugins[plugin] = nil
    combatRestoredPlugins[plugin] = nil
    local frame = GetFrame(plugin)
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame.orbitMountedSuppressed = nil
        frame.orbitTargetRevealed = nil
        frame.orbitLastVisibilityDriver = nil
        local cfg = GetConfig(plugin)
        if cfg.hoverReveal and Orbit.Animation then Orbit.Animation:StopHoverFade(frame) end
        frame:SetAlpha(1)
        if frame.orbitHoverOverlay then frame.orbitHoverOverlay:Hide() end
        RevealFrame(frame)
    end
    if not isEditModeRestoring and plugin.ApplySettings then
        plugin:ApplySettings()
        local cfg = GetConfig(plugin)
        if cfg.hoverReveal then C_Timer.After(0, function() plugin:ApplySettings() end) end
    end
end

-- [ CENTRALIZED TARGET REVEAL ]---------------------------------------------------------------------
local function OnTargetChanged()
    if not cachedShouldHide then return end
    local hasTarget = UnitExists("target")
    for plugin in pairs(suppressedPlugins) do
        local cfg = GetConfig(plugin)
        if cfg and cfg.targetReveal and cfg.frame then
            local frame = cfg.frame
            if hasTarget then
                frame.orbitTargetRevealed = true
                RevealFrame(frame)
                frame:SetScript("OnUpdate", nil)
                if frame.orbitHoverOverlay then frame.orbitHoverOverlay:Hide() end
            else
                frame.orbitTargetRevealed = false
                SuppressFrame(frame)
                if frame.orbitHoverOverlay then frame.orbitHoverOverlay:Show() end
            end
        end
    end
end

-- [ COMBAT-ESSENTIAL RESTORE ]----------------------------------------------------------------------
local function RestoreCombatEssentials()
    for plugin in pairs(suppressedPlugins) do
        local cfg = GetConfig(plugin)
        if cfg and cfg.combatRestore and cfg.frame then
            cfg.frame:SetAlpha(1)
            combatRestoredPlugins[plugin] = true
        end
    end
end

local function SuppressCombatEssentials()
    for plugin in pairs(combatRestoredPlugins) do
        local frame = GetFrame(plugin)
        if suppressedPlugins[plugin] and frame then
            if not frame.orbitTargetRevealed then
                frame:SetScript("OnUpdate", nil)
                frame:SetAlpha(0)
            end
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

local function CreateSimpleHoverOverlay(frame, revealFn, suppressFn)
    if not frame or frame.orbitHoverOverlay then return end
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + OVERLAY_LEVEL_BOOST)
    overlay:EnableMouse(true); overlay:SetMouseMotionEnabled(true); overlay:SetMouseClickEnabled(false)
    overlay:SetScript("OnEnter", function(self)
        revealFn()
        self:Hide()
        frame:SetScript("OnUpdate", function()
            if not frame:IsMouseOver() then
                frame:SetScript("OnUpdate", nil)
                if cachedShouldHide then suppressFn(); self:Show() end
            end
        end)
    end)
    frame.orbitHoverOverlay = overlay
    overlay:Hide()
end

local function ToggleOverlay(frame, shouldHide)
    if not frame or not frame.orbitHoverOverlay then return end
    if shouldHide then frame.orbitHoverOverlay:Show() else frame:SetScript("OnUpdate", nil); frame.orbitHoverOverlay:Hide() end
end

local HOVER_REVEAL_FRAMES = { "BuffFrame", "DebuffFrame" }

local function SetupMinimapHoverOverlay()
    local cluster = _G["MinimapCluster"]
    if not cluster then return end
    CreateSimpleHoverOverlay(cluster, function() SetBlizzardFramesAlpha(1) end, function() SetBlizzardFramesAlpha(0) end)
end

local function SetupObjectiveHoverOverlay()
    local objective = _G["ObjectiveTrackerFrame"]
    if not objective then return end
    CreateSimpleHoverOverlay(objective, function() objective:SetAlpha(1) end, function() objective:SetAlpha(0) end)
end

-- [ REFRESH ALL SYSTEMS ]---------------------------------------------------------------------------
function Manager:Refresh(force)
    local shouldHide = self:ShouldHide()
    if not force and shouldHide == cachedShouldHide then return end
    cachedShouldHide = shouldHide

    SetBlizzardFramesAlpha(shouldHide and 0 or 1)
    SetupMinimapHoverOverlay()
    ToggleOverlay(_G["MinimapCluster"], shouldHide)

    SetupObjectiveHoverOverlay()
    ToggleOverlay(_G["ObjectiveTrackerFrame"], shouldHide)

    for _, name in ipairs(HOVER_REVEAL_FRAMES) do
        local frame = _G[name]
        if frame then
            CreateSimpleHoverOverlay(frame, function() frame:SetAlpha(1) end, function() frame:SetAlpha(0) end)
            ToggleOverlay(frame, shouldHide)
        end
    end

    local systems = OrbitEngine.systems
    if not systems then return end
    for _, plugin in pairs(systems) do
        local cfg = GetConfig(plugin)
        if shouldHide and cfg and cfg.frame then
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
    Orbit.EventBus:Fire("MOUNTED_VISIBILITY_CHANGED", shouldHide)
end

-- [ EVENT REGISTRATION ]----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Manager:Refresh(true)
        C_Timer.After(REAPPLY_DELAY, function() Manager:Refresh(true) end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        RestoreCombatEssentials()
    elseif event == "PLAYER_REGEN_ENABLED" then
        SuppressCombatEssentials()
        Manager:Refresh()
    elseif event == "PLAYER_TARGET_CHANGED" then
        OnTargetChanged()
    else
        Manager:Refresh()
    end
end)

if EditModeManagerFrame then
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
        C_Timer.After(0, function()
            isEditModeRestoring = true
            Manager:Refresh(true)
            isEditModeRestoring = false
        end)
    end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() Manager:Refresh(true) end)
end
