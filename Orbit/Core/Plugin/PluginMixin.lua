local _, addonTable = ...
local Orbit = addonTable

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local DEFAULT_LAYOUT_ID = "Default"

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

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        Orbit.Async:Debounce(debounceKey, function()
            self:ApplySettings()
        end, debounceDelay)
    end, self)

    Orbit.EventBus:On("COLORS_CHANGED", function()
        Orbit.Async:Debounce(debounceKey, function()
            self:ApplySettings()
        end, debounceDelay)
    end, self)

    Orbit.EventBus:On("STRATA_UPDATED", function()
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
        local profilerActive = Orbit.Profiler and Orbit.Profiler:IsActive()
        local start = profilerActive and debugprofilestop() or nil
        
        callback(self, elapsed)
        
        if start then
            Orbit.Profiler:RecordContext(self, "OnUpdate", debugprofilestop() - start)
        end
    end)
end

function Orbit.PluginMixin:RemoveUpdate()
    if self._updateFrame then
        self._updateFrame:SetScript("OnUpdate", nil)
    end
end

function Orbit.PluginMixin:NewTicker(interval, callback, iterations)
    return C_Timer.NewTicker(interval, function()
        local profilerActive = Orbit.Profiler and Orbit.Profiler:IsActive()
        local start = profilerActive and debugprofilestop() or nil
        
        callback(self)
        
        if start then
            Orbit.Profiler:RecordContext(self, "C_Timer.Ticker", debugprofilestop() - start)
        end
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

-- Weak-keyed side cache so we never pollute SavedVariables with the lazy hash set.
local _disabledHashCache = setmetatable({}, { __mode = "k" })

function Orbit.PluginMixin:IsComponentDisabled(componentKey)
    local txn = self:_ActiveTransaction()
    local disabled = txn and txn:GetDisabledComponents() or self:GetSetting(self.frame and self.frame.systemIndex or 1, "DisabledComponents") or {}
    local hash = _disabledHashCache[disabled]
    if not hash then
        hash = {}
        for _, key in ipairs(disabled) do hash[key] = true end
        _disabledHashCache[disabled] = hash
    end
    return hash[componentKey] or false
end

-- Single entry point for Canvas Mode Apply — updates live frames + edit mode previews
function Orbit.PluginMixin:OnCanvasApply()
    if self.ApplySettings then self:ApplySettings() end
    if self.SchedulePreviewUpdate then self:SchedulePreviewUpdate() end
end

-- Subscribe to live preview updates during Canvas Mode editing
function Orbit.PluginMixin:WatchCanvasChanges()
    self._canvasLiveCallback = function(targetPlugin)
        if targetPlugin ~= self then return end
        if InCombatLockdown() then return end
        local txn = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode.Transaction
        local sysIdx = txn and txn:GetSystemIndex()
        local frame = sysIdx and self.GetFrameBySystemIndex and self:GetFrameBySystemIndex(sysIdx)
        if self.ApplySettings then self:ApplySettings(frame) end
    end
    Orbit.EventBus:On("CANVAS_SETTINGS_CHANGED", self._canvasLiveCallback)
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

-- [ SETTINGS ]---------------------------------------------------------------------------------------
function Orbit.PluginMixin:GetSetting(systemIndex, key)
    systemIndex = systemIndex or 1
    local layoutID = self:GetLayoutID()
    local db = Orbit.runtime and Orbit.runtime.Layouts

    -- Global Inheritance
    if key == "Texture" or key == "Font" or key == "BorderSize" or key == "BackdropColour" then
        local val = Orbit.db.GlobalSettings[key]

        return val
    end
    -- Canvas Mode Transaction override — return staged values during live preview
    local txn = self:_ActiveTransaction()
    if txn then
        local pending = txn:GetPending(key)
        if pending ~= nil then return pending end
    end

    local node = SafeTablePath(db, layoutID, self.system, systemIndex)
    local val = node and node[key]
    -- Backward compatibility: Fallback to "Default" layout
    if val == nil then
        node = SafeTablePath(db, DEFAULT_LAYOUT_ID, self.system, systemIndex)
        val = node and node[key]
    end

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
    local layoutID = self:GetLayoutID()
    local db = Orbit.runtime and Orbit.runtime.Layouts
    if not self.system then
        Orbit:Print("Warning: Plugin", self.name, "has no system identifier")
        return
    end
    db[layoutID] = db[layoutID] or {}
    db[layoutID][self.system] = db[layoutID][self.system] or {}
    db[layoutID][self.system][systemIndex] = db[layoutID][self.system][systemIndex] or {}
    db[layoutID][self.system][systemIndex][key] = value
end

-- [ SPEC-SCOPED STORAGE ] ---------------------------------------------------------------------------
-- Per-character, per-spec storage layered under Orbit.db.SpecData[charKey][specID][systemIndex][key].
-- Used by plugins whose settings must differ between specs (Tracked's items/positions,
-- CooldownManager's injected icons). Plugins that override GetSetting/SetSetting to redirect
-- individual keys into this store (e.g. TrackedPlugin.SPEC_SCOPED_KEYS) get spec scoping for free;
-- callers that only need a handful of keys can hit these methods directly.
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
local VISIBILITY_EVENTS = { "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "PLAYER_MOUNT_DISPLAY_CHANGED", "ZONE_CHANGED_NEW_AREA", "MOUNTED_VISIBILITY_CHANGED" }
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
