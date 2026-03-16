local _, addonTable = ...
local Orbit = addonTable

local DEFAULT_LAYOUT_ID = "Default"

-- Traverse nested tables safely, returning nil if any key is missing
local function SafeTablePath(tbl, ...)
    for i = 1, select("#", ...) do
        if type(tbl) ~= "table" then return nil end
        tbl = tbl[select(i, ...)]
    end
    return tbl
end

---@class OrbitPluginMixin
Orbit.PluginMixin = {}

local function ApplyFrameLayerSettings(frame, strata, level)
    if not frame then return end
    if strata and frame.SetFrameStrata then
        frame:SetFrameStrata(strata)
    end
    if level ~= nil and frame.SetFrameLevel then
        frame:SetFrameLevel(level)
    end
end

function Orbit.PluginMixin:Init() end

function Orbit.PluginMixin:OnLoad() end

-- Called when the Edit Mode Settings Dialog is opening for a system this plugin manages
-- @param dialog: The actual Edit Mode Settings Dialog frame (EditModeSystemSettingsDialog)
-- @param systemFrame: The specific system frame being edited (e.g., MainMenuBar, PlayerFrame)
function Orbit.PluginMixin:AddSettings(dialog, systemFrame) end

-- Standard event registration helper (registers world entry and Edit Mode callbacks)
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

    if Orbit.Engine and Orbit.Engine.EditMode then
        Orbit.Engine.EditMode:RegisterCallbacks({
            Enter = function()
                if self.skipEditModeApply then return end
                Orbit.Async:Debounce(debounceKey, function()
                    self:ApplySettings()
                end, debounceDelay)
            end,
            Exit = function()
                self:ApplySettings()
            end, -- No debounce: must run before combat lockdown
        }, self)
    end
end

-- Returns the active Transaction if it belongs to this plugin, or nil.
function Orbit.PluginMixin:_ActiveTransaction()
    local Txn = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode.Transaction
    if Txn and Txn:IsActive() and Txn:GetPlugin() == self then return Txn end
end

-- Returns ComponentPositions, preferring any active Transaction's staged positions.
function Orbit.PluginMixin:GetComponentPositions(systemIndex)
    local txn = self:_ActiveTransaction()
    return (txn and txn:GetPositions()) or self:GetSetting(systemIndex or 1, "ComponentPositions") or {}
end

-- Check if a component is disabled via Canvas Mode drag-to-disable (linear scan, small N)
function Orbit.PluginMixin:IsComponentDisabled(componentKey)
    local txn = self:_ActiveTransaction()
    local disabled = txn and txn:GetDisabledComponents() or self:GetSetting(self.frame and self.frame.systemIndex or 1, "DisabledComponents") or {}
    for _, key in ipairs(disabled) do
        if key == componentKey then return true end
    end
    return false
end

-- Single entry point for Canvas Mode Apply — updates live frames + edit mode previews
function Orbit.PluginMixin:OnCanvasApply()
    if self.ApplySettings then self:ApplySettings() end
    if self.SchedulePreviewUpdate then self:SchedulePreviewUpdate() end
end

function Orbit.PluginMixin:RegisterFrameForSettings(frame, systemIndex)
    if not frame then return end
    self._orbitFramesBySystemIndex = self._orbitFramesBySystemIndex or {}
    self._orbitFramesBySystemIndex[systemIndex or frame.systemIndex or 1] = frame
end

function Orbit.PluginMixin:ApplyStoredFrameLayers(frame, systemIndex)
    if frame and frame.GetFrameLevel then
        local idx = systemIndex or frame.systemIndex or 1
        ApplyFrameLayerSettings(frame, self:GetSetting(idx, "FrameStrata"), self:GetSetting(idx, "FrameLevel"))
        return
    end

    if not self._orbitFramesBySystemIndex then return end
    for idx, registeredFrame in pairs(self._orbitFramesBySystemIndex) do
        ApplyFrameLayerSettings(registeredFrame, self:GetSetting(idx, "FrameStrata"), self:GetSetting(idx, "FrameLevel"))
    end
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

function Orbit.PluginMixin:GetSetting(systemIndex, key)
    systemIndex = systemIndex or 1
    local layoutID = self:GetLayoutID()
    local db = Orbit.runtime and Orbit.runtime.Layouts

    -- Global Inheritance
    if key == "Texture" or key == "Font" or key == "BorderSize" or key == "BackdropColour" then
        local val = Orbit.db.GlobalSettings[key]
        if key == "BackdropColour" and not Orbit._backdropMigrated then
            Orbit._backdropMigrated = true
            if val and val.pins then
                local pin = val.pins[1]
                val = pin and pin.color or { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }
                Orbit.db.GlobalSettings[key] = val
            end
        end
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

-- For plugins with insecure frames that need Pet Battle / Vehicle visibility
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
    local shouldHide = (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player"))
        or (Orbit.MountedVisibility:ShouldHide())
    if shouldHide then
        if self.frame then self.frame:SetAlpha(0) end
        if self.containers then
            for _, container in pairs(self.containers) do container:SetAlpha(0) end
        end
        return
    end
    if self.ApplySettings then self:ApplySettings() return end
    if self.frame then self.frame:SetAlpha(1) end
    if self.containers then
        for _, container in pairs(self.containers) do container:SetAlpha(1) end
    end
end
