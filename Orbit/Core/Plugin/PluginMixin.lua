local _, addonTable = ...
local Orbit = addonTable
local L = Orbit.L

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
-- Theme keys inherited globally from Orbit.db.GlobalSettings; consulted by both GetSetting (read) and SetSetting (write) so the pair stays symmetric.
local GLOBAL_INHERIT_KEYS = { Texture = true, Font = true, BorderSize = true }

local function SafeTablePath(tbl, ...)
    for i = 1, select("#", ...) do
        if type(tbl) ~= "table" then return nil end
        tbl = tbl[select(i, ...)]
    end
    return tbl
end

-- [ PLUGIN MIXIN ]-----------------------------------------------------------------------------------
---@class OrbitPluginMixin
Orbit.PluginMixin = {}

function Orbit.PluginMixin:Init() end

function Orbit.PluginMixin:OnLoad() end

function Orbit.PluginMixin:AddSettings(dialog, systemFrame) end

-- [ STANDARD EVENTS ]--------------------------------------------------------------------------------
function Orbit.PluginMixin:RegisterStandardEvents()
    if not self.ApplySettings then
        return
    end

    local debounceKey = (self.name or "Plugin") .. "_Apply"
    local debounceDelay = (Orbit.Constants and Orbit.Constants.Timing and Orbit.Constants.Timing.DefaultDebounce) or 0.1

    Orbit.EventBus:On("ORBIT_PLAYER_ENTERING_WORLD", function()
        Orbit.Async:Debounce(debounceKey, function()
            self:ApplySettings()
        end, debounceDelay)
    end, self)

    Orbit.EventBus:On("ORBIT_COLORS_CHANGED", function()
        Orbit.Async:Debounce(debounceKey, function()
            self:ApplySettings()
        end, debounceDelay)
    end, self)

    if Orbit.Engine and Orbit.Engine.EditMode then
        Orbit.Engine.EditMode:RegisterCallbacks({
            Enter = function()
                if self.skipEditModeApply then return end
                Orbit.Async:Debounce(debounceKey, function()
                    self:ApplySettings()
                end, debounceDelay)
            end,
            -- Exit must run before combat lockdown — no debounce.
            Exit = function()
                self:ApplySettings()
            end,
        }, self)
    end
end

-- [ MANAGED UPDATES & TIMERS ]-----------------------------------------------------------------------
function Orbit.PluginMixin:RegisterUpdate(callback)
    if not self._updateFrame then
        self._updateFrame = CreateFrame("Frame")
    end
    self._updateFrame:SetScript("OnUpdate", function(_, elapsed)
        local start = Orbit.Profiler and Orbit.Profiler:Begin()
        callback(self, elapsed)
        if start then Orbit.Profiler:End(self, "OnUpdate", start) end
    end)
end

function Orbit.PluginMixin:RemoveUpdate()
    if self._updateFrame then
        self._updateFrame:SetScript("OnUpdate", nil)
    end
end

function Orbit.PluginMixin:NewTicker(interval, callback, iterations)
    return C_Timer.NewTicker(interval, function()
        local start = Orbit.Profiler and Orbit.Profiler:Begin()
        callback(self)
        if start then Orbit.Profiler:End(self, "C_Timer.Ticker", start) end
    end, iterations)
end

-- [ CANVAS MODE ]------------------------------------------------------------------------------------
function Orbit.PluginMixin:_ActiveTransaction()
    local Txn = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode.Transaction
    if Txn and Txn:IsActive() and Txn:GetPlugin() == self then return Txn end
end

-- Prefers any active Transaction's staged positions over saved settings.
function Orbit.PluginMixin:GetComponentPositions(systemIndex)
    local txn = self:_ActiveTransaction()
    return (txn and txn:GetPositions()) or self:GetSetting(systemIndex or 1, "ComponentPositions") or {}
end

-- Weak-keyed side cache; entry tracks array length so an in-place mutation (Canvas dock inserts/removes without changing identity) invalidates the cached hash.
local _disabledHashCache = setmetatable({}, { __mode = "k" })

function Orbit.PluginMixin:IsComponentDisabled(componentKey)
    local txn = self:_ActiveTransaction()
    local disabled = txn and txn:GetDisabledComponents() or self:GetSetting(self.frame and self.frame.systemIndex or 1, "DisabledComponents") or {}
    local entry = _disabledHashCache[disabled]
    if not entry or entry.count ~= #disabled then
        local hash = {}
        for _, key in ipairs(disabled) do hash[key] = true end
        entry = { hash = hash, count = #disabled }
        _disabledHashCache[disabled] = entry
    end
    return entry.hash[componentKey] or false
end

-- Single entry point for Canvas Mode Apply — updates live frames + edit mode previews
function Orbit.PluginMixin:OnCanvasApply()
    if self.ApplySettings then self:ApplySettings() end
    if self.SchedulePreviewUpdate then self:SchedulePreviewUpdate() end
end

-- Single live-preview refresh hook; plugins override for bespoke refresh (default re-applies settings).
function Orbit.PluginMixin:OnCanvasLivePreview(frame)
    if self.ApplySettings then self:ApplySettings(frame) end
end

-- Subscribe to live preview updates during Canvas Mode editing. Registered with self as context so OffContext(plugin) reclaims it on teardown.
function Orbit.PluginMixin:WatchCanvasChanges()
    if self._canvasWatched then return end
    self._canvasLiveCallback = self._canvasLiveCallback or function(_, targetPlugin)
        if targetPlugin ~= self then return end
        if InCombatLockdown() then return end
        local txn = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode.Transaction
        local sysIdx = txn and txn:GetSystemIndex()
        local frame = sysIdx and self.GetFrameBySystemIndex and self:GetFrameBySystemIndex(sysIdx)
        self:OnCanvasLivePreview(frame)
    end
    Orbit.EventBus:On("ORBIT_CANVAS_SETTINGS_CHANGED", self._canvasLiveCallback, self)
    self._canvasWatched = true
end

function Orbit.PluginMixin:UnwatchCanvasChanges()
    if self._canvasLiveCallback then
        Orbit.EventBus:Off("ORBIT_CANVAS_SETTINGS_CHANGED", self._canvasLiveCallback)
    end
    self._canvasWatched = false
end

function Orbit.PluginMixin:GetLayoutID()
    return "Orbit"
end

-- Read a setting from any plugin's DB without needing a plugin reference (zero coupling)
function Orbit:ReadPluginSetting(system, systemIndex, key)
    local db = Orbit.runtime and Orbit.runtime.Layouts
    local node = SafeTablePath(db, "Orbit", system, systemIndex)
    return node and node[key]
end

-- Sanctioned read for globally-inherited theme values; the single door plugins/core use instead of indexing Orbit.db.GlobalSettings directly.
function Orbit:GetTheme(key)
    return Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings[key]
end

-- [ SETTINGS ]---------------------------------------------------------------------------------------
function Orbit.PluginMixin:GetSetting(systemIndex, key)
    systemIndex = systemIndex or 1
    local layoutID = self:GetLayoutID()
    local db = Orbit.runtime and Orbit.runtime.Layouts

    if GLOBAL_INHERIT_KEYS[key] then
        return Orbit.db.GlobalSettings[key]
    end
    -- Canvas Mode Transaction override — return staged values during live preview
    local txn = self:_ActiveTransaction()
    if txn then
        local pending = txn:GetPending(key)
        if pending ~= nil then return pending end
    end

    local node = SafeTablePath(db, layoutID, self.system, systemIndex)
    local val = node and node[key]

    if val == nil and self.indexDefaults and self.indexDefaults[systemIndex] and self.indexDefaults[systemIndex][key] ~= nil then
        return self.indexDefaults[systemIndex][key]
    end
    if val == nil and self.defaults and self.defaults[key] ~= nil then
        return self.defaults[key]
    end
    return val
end

function Orbit.PluginMixin:SetSetting(systemIndex, key, value)
    systemIndex = systemIndex or 1
    if GLOBAL_INHERIT_KEYS[key] then
        if not Orbit.db.GlobalSettings then Orbit.db.GlobalSettings = {} end
        Orbit.db.GlobalSettings[key] = value
        if Orbit.EventBus then Orbit.EventBus:Fire("ORBIT_COLORS_CHANGED") end
        return
    end
    local layoutID = self:GetLayoutID()
    local db = Orbit.runtime and Orbit.runtime.Layouts
    if not self.system then
        Orbit:Print(L.MSG_PLUGIN_NO_SYSTEM_ID_F:format(tostring(self.name)))
        return
    end
    db[layoutID] = db[layoutID] or {}
    db[layoutID][self.system] = db[layoutID][self.system] or {}
    db[layoutID][self.system][systemIndex] = db[layoutID][self.system][systemIndex] or {}
    db[layoutID][self.system][systemIndex][key] = value
end

-- [ SPEC-SCOPED STORAGE ] ---------------------------------------------------------------------------
-- Orbit.db.SpecData[charKey][specID][systemIndex][key]. Plugins overriding GetSetting/SetSetting to redirect keys get spec scoping for free (e.g. TrackedPlugin.SPEC_SCOPED_KEYS).
function Orbit.PluginMixin:GetCurrentSpecID()
    local specIndex = GetSpecialization()
    return specIndex and GetSpecializationInfo(specIndex)
end

function Orbit.PluginMixin:GetCharSpecStore()
    local root = Orbit.db.SpecData
    if not root then Orbit.db.SpecData = {}; root = Orbit.db.SpecData end
    local store = root[Orbit.CHAR_KEY]
    if not store then
        store = {}
        root[Orbit.CHAR_KEY] = store
    end
    return store
end

function Orbit.PluginMixin:GetSpecData(systemIndex, key)
    local specID = self:GetCurrentSpecID()
    if not specID then return nil end
    local store = self:GetCharSpecStore()
    local specNode = store[specID]
    local sysNode = specNode and specNode[systemIndex]
    return sysNode and sysNode[key]
end

function Orbit.PluginMixin:SetSpecData(systemIndex, key, value)
    local specID = self:GetCurrentSpecID()
    if not specID then return end
    local store = self:GetCharSpecStore()
    if not store[specID] then store[specID] = {} end
    if not store[specID][systemIndex] then store[specID][systemIndex] = {} end
    store[specID][systemIndex][key] = value
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
local VISIBILITY_EVENTS = { "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "PLAYER_MOUNT_DISPLAY_CHANGED", "ZONE_CHANGED_NEW_AREA", "ORBIT_MOUNTED_VISIBILITY_CHANGED" }
local VISIBILITY_UNIT_EVENTS = { "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }

function Orbit.PluginMixin:RegisterVisibilityEvents()
    if not Orbit.EventBus then
        return
    end
    for _, event in ipairs(VISIBILITY_EVENTS) do
        Orbit.EventBus:On(event, function()
            self:UpdateVisibility()
        end, self)
    end
    for _, event in ipairs(VISIBILITY_UNIT_EVENTS) do
        Orbit.EventBus:On(event, function(unit)
            if unit == "player" then
                self:UpdateVisibility()
            end
        end, self)
    end
    self:UpdateVisibility()
end

function Orbit.PluginMixin:UpdateVisibility()
    if not Orbit:IsPluginEnabled(self.name) then
        if self.frame then self.frame:Hide() end
        return
    end
    local pluginMounted = Orbit.VisibilityEngine and Orbit.VisibilityEngine:IsFrameMountedHidden(self.name, self.frame and self.frame.systemIndex or 1)
    local shouldHide = (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player"))
        or pluginMounted
    if shouldHide then
        if self.frame then self.frame:SetAlpha(0) end
        if self.containers then
            for _, container in pairs(self.containers) do container:SetAlpha(0) end
        end
        return
    end
    if self.ApplySettings then self:ApplySettings() return end
    local opacity = (self.frame and self.frame.systemIndex and self:GetSetting(self.frame.systemIndex, "Opacity") or 100) / 100
    if self.frame then self.frame:SetAlpha(opacity) end
    if self.containers then
        for _, container in pairs(self.containers) do container:SetAlpha(opacity) end
    end
end

if table.freeze then table.freeze(Orbit.PluginMixin) end
