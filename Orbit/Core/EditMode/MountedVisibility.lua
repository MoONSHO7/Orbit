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

---@class MountedVisibilityManager
local Manager = {}
Orbit.MountedVisibility = Manager

local cachedShouldHide = false
local suppressedPlugins = {}
local isEditModeRestoring = false

-- [ FRAME HELPERS ]---------------------------------------------------------------------------------
local function GetPluginFrame(plugin) return plugin.mountedConfig and plugin.mountedConfig.frame end

-- [ VE HELPERS ]------------------------------------------------------------------------------------
local function GetPluginVEKey(plugin)
    if not Orbit.VisibilityEngine then return nil end
    local frame = GetPluginFrame(plugin)
    local sysIdx = (frame and frame.systemIndex) or 1
    return Orbit.VisibilityEngine:GetKeyForPlugin(plugin.name, sysIdx)
end

local function GetPluginVESetting(plugin, setting)
    local veKey = GetPluginVEKey(plugin)
    return veKey and Orbit.VisibilityEngine:GetFrameSetting(veKey, setting) or false
end

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
    if not Orbit.VisibilityEngine or not Orbit.VisibilityEngine:AnyFrameHasSetting("hideMounted") then return false end
    local _, instanceType = IsInInstance()
    return OPEN_WORLD_INSTANCE_TYPES[instanceType] == true
end

function Manager:ShouldHide() return IsMountedHideActive() end

local function ShouldHidePlugin(plugin) return GetPluginVESetting(plugin, "hideMounted") end
function Manager:ShouldHidePlugin(plugin) return ShouldHidePlugin(plugin) end

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
    local frame = GetPluginFrame(plugin)
    if not frame then return end
    suppressedPlugins[plugin] = true
    -- VE showWithTarget = skip suppress if target exists
    if GetPluginVESetting(plugin, "showWithTarget") and UnitExists("target") then
        frame.orbitTargetRevealed = true
        return
    end
    SuppressFrame(frame)
    -- VE mouseOver = hover reveal overlay
    if GetPluginVESetting(plugin, "mouseOver") then
        CreateHoverOverlay(frame, plugin)
        frame.orbitHoverOverlay:Show()
    end
end

local function RestorePlugin(plugin)
    if not suppressedPlugins[plugin] then return end
    suppressedPlugins[plugin] = nil
    local frame = GetPluginFrame(plugin)
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame.orbitMountedSuppressed = nil
        frame.orbitTargetRevealed = nil
        frame.orbitLastVisibilityDriver = nil
        if GetPluginVESetting(plugin, "mouseOver") and Orbit.Animation then Orbit.Animation:StopHoverFade(frame) end
        frame:SetAlpha(1)
        if frame.orbitHoverOverlay then frame.orbitHoverOverlay:Hide() end
        RevealFrame(frame)
    end
    if not isEditModeRestoring and plugin.ApplySettings then
        plugin:ApplySettings()
        if GetPluginVESetting(plugin, "mouseOver") then C_Timer.After(0, function() plugin:ApplySettings() end) end
    end
end

-- [ CENTRALIZED TARGET REVEAL ]---------------------------------------------------------------------
local function OnTargetChanged()
    if not cachedShouldHide then return end
    local hasTarget = UnitExists("target")
    for plugin in pairs(suppressedPlugins) do
        if GetPluginVESetting(plugin, "showWithTarget") then
            local frame = GetPluginFrame(plugin)
            if frame then
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
end

-- [ COMBAT RESTORE ]--------------------------------------------------------------------------------
local function RestoreCombatEssentials()
    for plugin in pairs(suppressedPlugins) do
        -- VE oocFade = restore in combat
        if GetPluginVESetting(plugin, "oocFade") then
            local frame = GetPluginFrame(plugin)
            if frame then frame:SetAlpha(1) end
        end
    end
end

local function SuppressCombatEssentials()
    for plugin in pairs(suppressedPlugins) do
        if GetPluginVESetting(plugin, "oocFade") then
            local frame = GetPluginFrame(plugin)
            if frame and not frame.orbitTargetRevealed then
                frame:SetScript("OnUpdate", nil)
                frame:SetAlpha(0)
            end
        end
    end
end

-- [ BLIZZARD HOVER OVERLAYS ]-----------------------------------------------------------------------
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

local function SetupMinimapHoverOverlay()
    local cluster = _G["MinimapCluster"]
    if not cluster then return end
    CreateSimpleHoverOverlay(cluster, function() cluster:SetAlpha(1) end, function() cluster:SetAlpha(0) end)
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

    -- Blizzard frames: only hide if their VE entry has hideMounted enabled
    if Orbit.VisibilityEngine then
        for _, entry in ipairs(Orbit.VisibilityEngine:GetBlizzardFrames()) do
            local frame = _G[entry.blizzardFrame]
            if frame then
                local frameHide = shouldHide and Orbit.VisibilityEngine:GetFrameSetting(entry.key, "hideMounted")
                frame:SetAlpha(frameHide and 0 or 1)
                if entry.key == "Minimap" then
                    SetupMinimapHoverOverlay()
                    ToggleOverlay(_G["MinimapCluster"], frameHide)
                elseif entry.blizzardFrame == "ObjectiveTrackerFrame" then
                    SetupObjectiveHoverOverlay()
                    ToggleOverlay(frame, frameHide)
                elseif entry.blizzardFrame == "BuffFrame" or entry.blizzardFrame == "DebuffFrame" then
                    CreateSimpleHoverOverlay(frame, function() frame:SetAlpha(1) end, function() frame:SetAlpha(0) end)
                    ToggleOverlay(frame, frameHide)
                end
            end
        end
    end

    local systems = OrbitEngine.systems
    if not systems then return end
    for _, plugin in pairs(systems) do
        local frame = GetPluginFrame(plugin)
        local pluginHide = shouldHide and frame and ShouldHidePlugin(plugin)
        if pluginHide then
            SuppressPlugin(plugin)
        elseif suppressedPlugins[plugin] then
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
