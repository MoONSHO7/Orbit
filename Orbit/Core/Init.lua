local addonName, addonTable = ...

---@class Orbit
---@field Engine OrbitEngine
---@field Constants OrbitConstants
---@field Profile OrbitProfileManager
---@field CombatManager OrbitCombatManager
---@field PluginMixin OrbitPluginMixin
---@field EventBus OrbitEventBus
---@field Async OrbitAsync
---@field API OrbitAPI
---@field AuraMixin OrbitAuraMixin
---@field CastBarMixin OrbitCastBarMixin
---@field UnitFrameMixin OrbitUnitFrameMixin
---@field ResourceBarMixin OrbitResourceBarMixin
---@field Skin OrbitSkin
---@field Frame OrbitFrameManager
---@field Config OrbitConfig
---@field Layout OrbitLayout
Orbit = addonTable

-- Engine Integration
local OrbitEngine = Orbit.Engine
Orbit.Layout = OrbitEngine.Layout
Orbit.Config = OrbitEngine.Config
Orbit.Frame = OrbitEngine.Frame

-- [ ERROR HANDLER ]---------------------------------------------------------------------------------

Orbit.ErrorHandler = {}
local ErrorHandler = Orbit.ErrorHandler

--- Wrap a function with error handling
-- Returns a new function that catches and logs errors
-- @param func (function): The function to wrap
-- @param context (string): Optional context for error messages
-- @return function: Error-safe wrapper function
function ErrorHandler:Wrap(func, context)
    return function(...)
        local success, result = pcall(func, ...)
        if not success then
            local contextStr = context or "Unknown"
            Orbit:Print("|cFFFF0000ERROR:|r", contextStr, "-", tostring(result))
            self:LogError(contextStr, "wrapped_call", result)
        end
        return result
    end
end

--- Log an error to SavedVariables for later debugging
-- Uses circular buffer for O(1) insertion (avoids O(n) table.remove)
-- @param source (string): Where the error occurred
-- @param method (string): Method or context
-- @param error (string): Error message
function ErrorHandler:LogError(source, method, err)
    if not Orbit.db then
        return
    end

    if not Orbit.db.ErrorLog then
        Orbit.db.ErrorLog = {}
        Orbit.db.ErrorLogIndex = 0  -- Circular buffer pointer
    end

    -- Circular buffer: O(1) insertion by overwriting oldest entry
    local MAX_ERRORS = 50
    local index = (Orbit.db.ErrorLogIndex % MAX_ERRORS) + 1
    Orbit.db.ErrorLogIndex = index

    Orbit.db.ErrorLog[index] = {
        time = time(),
        date = date("%Y-%m-%d %H:%M:%S"),
        source = tostring(source),
        method = tostring(method),
        error = tostring(err),
    }
end

-- [ VISIBILITY MANAGER ]----------------------------------------------------------------------------

Orbit.Visibility = {}

--- ApplyState (Centralized StateDriver)
-- Handles visibility states (Combat/OOC) via RegisterStateDriver to avoid Taint.
-- Includes Recursion Guard to prevent "Show() -> UpdateVisibility -> Show()" loops.
-- @param frame: The secure frame to control.
-- @param visibilityMode:
--     0 or nil = Always Visible (Show)
--     1 = In Combat (Show in Combat, Hide OOC)
--     2 = Out of Combat (Hide in Combat, Show OOC)
--     3 = Hidden (Always Hide)
function Orbit.Visibility:ApplyState(frame, visibilityMode)
    -- Recursion Guard
    if frame.isOrbitUpdating then
        return
    end
    frame.isOrbitUpdating = true

    local driver
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
        driver = "show"
        frame:SetAlpha(1) -- Ensure alpha is up
    else
        local vis = visibilityMode or 0
        if vis == 3 then
            driver = "hide"
        elseif vis == 1 then
            driver = "[combat] show; hide"
        elseif vis == 2 then
            driver = "[combat] hide; show"
        else
            driver = "show"
        end
    end

    -- Caching: Prevent redundant RegisterStateDriver calls/recursion
    if frame.orbitLastVisibilityDriver == driver then
        frame.isOrbitUpdating = false
        return
    end
    frame.orbitLastVisibilityDriver = driver

    if driver then
        RegisterStateDriver(frame, "visibility", driver)
    else
        UnregisterStateDriver(frame, "visibility")
        frame:Show()
    end

    frame.isOrbitUpdating = false
end

-- [ COMBAT-SAFE HELPERS ]---------------------------------------------------------------------------

-- Combat-safe action helper (DRY pattern for InCombatLockdown guards)
-- Returns true if action was executed, false if queued for after combat
function Orbit:SafeAction(callback)
    if InCombatLockdown() then
        if self.CombatManager then
            self.CombatManager:QueueUpdate(callback)
        end
        return false
    end
    callback()
    return true
end

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------

function Orbit:RegisterPlugin(name, system, mixin, group)
    -- Combine Orbit's persistence mixin (PluginMixin) with the specific plugin logic
    local combinedMixin = Mixin({}, Orbit.PluginMixin, mixin)

    local plugin = OrbitEngine:RegisterSystem(name, system, combinedMixin)
    plugin.group = group

    -- Wrap ApplySettings to automatically check enabled state
    if plugin.ApplySettings then
        local originalApplySettings = plugin.ApplySettings
        plugin.ApplySettings = function(self, ...)
            -- If Disabled: Hide Frame and Return
            if not Orbit:IsPluginEnabled(self.name) then
                if self.frame and self.frame.Hide then
                    self.frame:Hide()
                end
                return
            end

            return originalApplySettings(self, ...)
        end
    end

    return plugin
end

function Orbit:GetPlugin(system)
    return OrbitEngine:GetSystem(system)
end

function Orbit:InitializePlugins()
    -- Phase 1: Creation (OnLoad)
    -- Create all frames first so they exist as valid anchor targets
    for _, plugin in ipairs(OrbitEngine.systems) do
        if self:IsPluginEnabled(plugin.name) and plugin.OnLoad then
            local wrappedOnLoad = self.ErrorHandler:Wrap(function()
                plugin:OnLoad()
            end, plugin.name .. ".OnLoad")
            wrappedOnLoad()
        end
    end

    -- Phase 2: Layout (ApplySettings)
    -- Apply positions and anchors now that all targets exist
    for _, plugin in ipairs(OrbitEngine.systems) do
        if self:IsPluginEnabled(plugin.name) and plugin.ApplySettings then
            plugin:ApplySettings()
        end
    end
end

-- [ ADDON INITIALIZATION ]--------------------------------------------------------------------------

Orbit.addonName = addonName
Orbit.version = "1.0"
Orbit.title = "Orbit"

_G["Orbit"] = Orbit

-- SavedVariables
OrbitDB = OrbitDB or {}

function Orbit:OnLoad()
    self.db = OrbitDB

    -- Initialize global settings
    self.db.GlobalSettings = self.db.GlobalSettings or {}
    local globalDefaults = {
        Font = "PT Sans Narrow",
        Texture = "Solid",

        BorderSize = 2,
        TextScale = "Medium",
        BackdropColour = { r = 0.145, g = 0.145, b = 0.145, a = 0.7 },
        -- Note: NumActionBars is now per-profile, stored in Action Bar 1 settings
    }
    for k, v in pairs(globalDefaults) do
        if self.db.GlobalSettings[k] == nil then
            self.db.GlobalSettings[k] = v
        end
    end

    -- Initialize profiles (triggers spec-based profile switching)
    if self.Profile then
        self.Profile:Initialize()
    end

    self:InitializePlugins()

    -- Listen for Screen Resolution changes (Pixel Perfect Border Update)
    if self.EventBus then
        self.EventBus:On("ORBIT_DISPLAY_SIZE_CHANGED", function()
            -- Force re-application of settings to update pixel-perfect borders
            if self.Engine and self.Engine.systems then
                for _, plugin in ipairs(self.Engine.systems) do
                    if plugin.ApplyAll then
                        plugin:ApplyAll()
                    elseif plugin.ApplySettings then
                        plugin:ApplySettings()
                    end
                end
            end
        end)
    end

    self:Print("loaded. Type /orbit for config")
end

function Orbit:Print(...)
    print("|cFF00FFFF" .. self.title .. ":|r", ...)
end

function Orbit:IsPluginEnabled(name)
    -- DisabledPlugins infrastructure removed - plugins now managed via Blizzard Addon List
    return true
end

-- [ EVENT HANDLERS ]--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        Orbit:OnLoad()
    end
end)

local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        if Orbit.Engine and Orbit.Engine.PositionManager then
            Orbit.Engine.PositionManager:FlushToStorage()
        end
    end
end)
