local _, addonTable = ...
local Orbit = addonTable

-- Abstract Mixin for Orbit Plugins
---@class OrbitPluginMixin
Orbit.PluginMixin = {}

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

    if Orbit.EventBus then
        Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
            Orbit.Async:Debounce(debounceKey, function()
                self:ApplySettings()
            end, debounceDelay)
        end, self)
    end

    if Orbit.Engine and Orbit.Engine.EditMode then
        Orbit.Engine.EditMode:RegisterCallbacks({
            Enter = function()
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

-- Check if a component is disabled via Canvas Mode drag-to-disable (O(1) set lookup)
function Orbit.PluginMixin:IsComponentDisabled(componentKey)
    local disabled = self:GetSetting(self.frame and self.frame.systemIndex or 1, "DisabledComponents") or {}
    for _, key in ipairs(disabled) do
        if key == componentKey then return true end
    end
    return false
end

function Orbit.PluginMixin:GetLayoutID()
    return "Orbit"
end

function Orbit.PluginMixin:GetSetting(systemIndex, key)
    systemIndex = systemIndex or 1
    local layoutID = self:GetLayoutID()
    local db = Orbit.runtime and Orbit.runtime.Layouts

    -- Global Inheritance
    if key == "Texture" or key == "Font" or key == "BorderSize" or key == "BackdropColour" then
        return Orbit.db.GlobalSettings[key]
    end

    local val = nil
    if db and db[layoutID] and db[layoutID][self.system] and db[layoutID][self.system][systemIndex] then
        val = db[layoutID][self.system][systemIndex][key]
    end
    -- Backward compatibility: Fallback to "Default" layout
    if val == nil and db and db["Default"] and db["Default"][self.system] and db["Default"][self.system][systemIndex] then
        val = db["Default"][self.system][systemIndex][key]
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
function Orbit.PluginMixin:RegisterVisibilityEvents()
    if not Orbit.EventBus then
        return
    end
    Orbit.EventBus:On("PET_BATTLE_OPENING_START", function()
        self:UpdateVisibility()
    end, self)
    Orbit.EventBus:On("PET_BATTLE_CLOSE", function()
        self:UpdateVisibility()
    end, self)
    Orbit.EventBus:On("UNIT_ENTERED_VEHICLE", function(unit)
        if unit == "player" then
            self:UpdateVisibility()
        end
    end, self)
    Orbit.EventBus:On("UNIT_EXITED_VEHICLE", function(unit)
        if unit == "player" then
            self:UpdateVisibility()
        end
    end, self)
    self:UpdateVisibility()
end

function Orbit.PluginMixin:UpdateVisibility()
    local shouldHide = (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player"))
    local framesToUpdate = {}
    if self.frame then
        table.insert(framesToUpdate, self.frame)
    end
    if self.containers then
        for _, container in pairs(self.containers) do
            table.insert(framesToUpdate, container)
        end
    end
    for _, frame in ipairs(framesToUpdate) do
        if shouldHide then
            if frame.Hide then
                frame:Hide()
            end
        elseif self.ApplySettings then
            self:ApplySettings(frame)
        elseif frame.Show then
            frame:Show()
        end
    end
end
