-- [ ORBIT INIT ]------------------------------------------------------------------------------------

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
Orbit.Engine = Orbit.Engine or {}
local OrbitEngine = Orbit.Engine
Orbit.Layout = OrbitEngine.Layout
Orbit.Config = OrbitEngine.Config
Orbit.Frame = OrbitEngine.Frame

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local MAX_ERRORS = 50
local INIT_TIMER_DELAY = 0.05

local GLOBAL_DEFAULTS = {
    Font = "PT Sans Narrow",
    Texture = "Solid",
    BorderSize = 2,
    TextScale = "Medium",
    FontOutline = "OUTLINE",
    BackdropColour = { r = 0.145, g = 0.145, b = 0.145, a = 0.7 },
}

-- [ ERROR HANDLER ]---------------------------------------------------------------------------------

Orbit.ErrorHandler = {}
local ErrorHandler = Orbit.ErrorHandler

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

function ErrorHandler:LogError(source, method, err)
    if not Orbit.db then return end
    if not Orbit.db.ErrorLog then
        Orbit.db.ErrorLog = {}
        Orbit.db.ErrorLogIndex = 0
    end

    local index = (Orbit.db.ErrorLogIndex % MAX_ERRORS) + 1
    Orbit.db.ErrorLogIndex = index
    Orbit.db.ErrorLog[index] = {
        time = time(), date = date("%Y-%m-%d %H:%M:%S"),
        source = tostring(source), method = tostring(method), error = tostring(err),
    }
end

-- [ VISIBILITY MANAGER ]----------------------------------------------------------------------------

Orbit.Visibility = {}

function Orbit.Visibility:ApplyState(frame, visibilityMode)
    if frame.isOrbitUpdating then return end
    frame.isOrbitUpdating = true

    local driver
    if Orbit:IsEditMode() then
        driver = "show"
        frame:SetAlpha(1)
        frame.orbitLastVisibilityDriver = nil
    else
        local vis = visibilityMode or 0
        if vis == 3 then driver = "hide"
        elseif vis == 1 then driver = "[combat] show; hide"
        elseif vis == 2 then driver = "[combat] hide; show"
        else driver = "show" end
    end

    if frame.orbitLastVisibilityDriver == driver then
        frame.isOrbitUpdating = false
        return
    end
    frame.orbitLastVisibilityDriver = driver

    if driver then RegisterStateDriver(frame, "visibility", driver)
    else
        UnregisterStateDriver(frame, "visibility")
        frame:Show()
    end

    frame.isOrbitUpdating = false
end

-- [ EDIT MODE QUERY ]-------------------------------------------------------------------------------

function Orbit:IsEditMode()
    return EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() or false
end

-- [ COMBAT-SAFE HELPERS ]---------------------------------------------------------------------------

function Orbit:SafeAction(callback)
    if InCombatLockdown() then
        if self.CombatManager then self.CombatManager:QueueUpdate(callback) end
        return false
    end
    callback()
    return true
end

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------

function Orbit:RegisterPlugin(name, system, mixin)
    local combinedMixin = Mixin({}, Orbit.PluginMixin, mixin)
    local plugin = OrbitEngine:RegisterSystem(name, system, combinedMixin)

    if plugin.ApplySettings then
        local originalApplySettings = plugin.ApplySettings
        plugin.ApplySettings = function(self, ...)
            if not Orbit:IsPluginEnabled(self.name) then
                if self.frame and self.frame.Hide then self.frame:Hide() end
                return
            end
            return originalApplySettings(self, ...)
        end
    end

    return plugin
end

function Orbit:GetPlugin(system) return OrbitEngine:GetSystem(system) end

function Orbit:InitializePlugins()
    for _, plugin in ipairs(OrbitEngine.systems) do
        if self:IsPluginEnabled(plugin.name) and plugin.OnLoad then
            self.ErrorHandler:Wrap(function() plugin:OnLoad() end, plugin.name .. ".OnLoad")()
        end
    end
    for _, plugin in ipairs(OrbitEngine.systems) do
        if self:IsPluginEnabled(plugin.name) and plugin.ApplySettings then plugin:ApplySettings() end
    end
end

-- [ ADDON INITIALIZATION ]--------------------------------------------------------------------------

Orbit.addonName = addonName
Orbit.version = "1.0"
Orbit.title = "Orbit"
_G["Orbit"] = Orbit
OrbitDB = OrbitDB or {}

function Orbit:OnLoad()
    self.db = OrbitDB
    self.db.GlobalSettings = self.db.GlobalSettings or {}
    for k, v in pairs(GLOBAL_DEFAULTS) do
        if self.db.GlobalSettings[k] == nil then
            self.db.GlobalSettings[k] = type(v) == "table" and Orbit.Profile and Orbit.Profile.CopyTable and Orbit.Profile.CopyTable(v, {}) or v
        end
    end

    if self.Profile then self.Profile:Initialize() end
    self:InitializePlugins()

    if NSAPI and NSAPI.RegisterCallback and self.EventBus then
        NSAPI:RegisterCallback("NSRT_NICKNAME_UPDATED", function() self.EventBus:Fire("ORBIT_NICKNAME_UPDATED") end, self)
    end

    if self.EventBus then
        self.EventBus:On("ORBIT_DISPLAY_SIZE_CHANGED", function()
            if self.Engine and self.Engine.systems then
                for _, plugin in ipairs(self.Engine.systems) do
                    if plugin.ApplyAll then plugin:ApplyAll()
                    elseif plugin.ApplySettings then plugin:ApplySettings() end
                end
            end
        end)
    end

    self:Print("loaded. Type /orbit for config")
end

function Orbit:Print(...) print("|cFF00FFFF" .. self.title .. ":|r", ...) end

function Orbit:IsPluginEnabled(name)
    if not self.db or not self.db.DisabledPlugins then return true end
    return not self.db.DisabledPlugins[name]
end

function Orbit:SetPluginEnabled(name, enabled)
    if not self.db then return end
    if not self.db.DisabledPlugins then self.db.DisabledPlugins = {} end
    self.db.DisabledPlugins[name] = (not enabled) or nil
end

-- [ EVENT HANDLERS ]--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Orbit:OnLoad()
    elseif event == "PLAYER_LOGOUT" then
        if Orbit.Engine and Orbit.Engine.PositionManager then Orbit.Engine.PositionManager:FlushToStorage() end
        if Orbit.Profile then Orbit.Profile:FlushGlobalSettings() end
    end
end)
