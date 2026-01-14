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

-- Standard event registration helper (DRY pattern)
-- Registers PLAYER_ENTERING_WORLD and Edit Mode Enter/Exit callbacks to call ApplySettings
function Orbit.PluginMixin:RegisterStandardEvents()
    if not self.ApplySettings then
        return
    end

    local debounceKey = (self.name or "Plugin") .. "_Apply"
    local Constants = Orbit.Constants
    local debounceDelay = Constants and Constants.Timing and Constants.Timing.DefaultDebounce or 0.1

    -- Register for world entry
    if Orbit.EventBus then
        Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
            Orbit.Async:Debounce(debounceKey, function()
                self:ApplySettings()
            end, debounceDelay)
        end, self)
    end

    -- Register for Edit Mode Enter/Exit
    local Engine = Orbit.Engine
    if Engine and Engine.EditMode then
        Engine.EditMode:RegisterCallbacks({
            Enter = function()
                Orbit.Async:Debounce(debounceKey, function()
                    self:ApplySettings()
                end, debounceDelay)
            end,
            Exit = function()
                Orbit.Async:Debounce(debounceKey, function()
                    self:ApplySettings()
                end, debounceDelay)
            end,
        }, self)
    end
end

-- Persistence Helpers

-- Returns fixed layout key for storing Orbit settings
-- Decoupled from Blizzard's Edit Mode layouts for simpler, predictable behavior
function Orbit.PluginMixin:GetLayoutID()
    return "Orbit"
end

function Orbit.PluginMixin:GetSetting(systemIndex, key)
    systemIndex = systemIndex or 1
    local layoutID = self:GetLayoutID() -- Now always returns "Orbit"
    local db = Orbit.runtime and Orbit.runtime.Layouts

    -- Global Inheritance (Enforced for specific keys)
    if key == "Texture" or key == "Font" or key == "BorderSize" or key == "BackdropColour" then
        if Orbit.db and Orbit.db.GlobalSettings then
            return Orbit.db.GlobalSettings[key]
        end
    end

    -- Get value from saved settings
    local val = nil

    -- First try current layout ("Orbit")
    if db and db[layoutID] and db[layoutID][self.system] and db[layoutID][self.system][systemIndex] then
        val = db[layoutID][self.system][systemIndex][key]
    end

    -- Backward compatibility: Fallback to "Default" layout (old saved data)
    if val == nil and db and db["Default"] then
        if db["Default"][self.system] and db["Default"][self.system][systemIndex] then
            val = db["Default"][self.system][systemIndex][key]
        end
    end

    -- If no saved value, check plugin defaults table
    if val == nil and self.defaults and self.defaults[key] ~= nil then
        return self.defaults[key]
    end

    return val
end

function Orbit.PluginMixin:SetSetting(systemIndex, key, value)
    systemIndex = systemIndex or 1
    local layoutID = self:GetLayoutID()
    local db = Orbit.runtime and Orbit.runtime.Layouts

    -- Safety: Ensure system identifier exists
    if not self.system then
        Orbit:Print("Warning: Plugin", self.name, "has no system identifier")
        return
    end

    if not db[layoutID] then
        db[layoutID] = {}
    end
    if not db[layoutID][self.system] then
        db[layoutID][self.system] = {}
    end
    if not db[layoutID][self.system][systemIndex] then
        db[layoutID][self.system][systemIndex] = {}
    end

    db[layoutID][self.system][systemIndex][key] = value
end

-- [ VISIBILITY HELPERS ]----------------------------------------------------------------------------
-- For plugins that cannot use Secure State Drivers (insecure frames)
-- Can be called manually or via RegisterStandardEvents if we decide to include it there (currently opt-in)

function Orbit.PluginMixin:RegisterVisibilityEvents()
    if not Orbit.EventBus then
        return
    end

    -- Pet Battle Events
    Orbit.EventBus:On("PET_BATTLE_OPENING_START", function()
        self:UpdateVisibility()
    end, self)
    Orbit.EventBus:On("PET_BATTLE_CLOSE", function()
        self:UpdateVisibility()
    end, self)

    -- Vehicle Events
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

    -- Initial check
    self:UpdateVisibility()
end

function Orbit.PluginMixin:UpdateVisibility()
    -- Note: self.frame can be a single frame or we might need to iterate containers
    -- Only works for insecure frames or out-of-combat secure frames

    local inPetBattle = C_PetBattles and C_PetBattles.IsInBattle()
    local inVehicle = UnitHasVehicleUI and UnitHasVehicleUI("player")

    local shouldHide = inPetBattle or inVehicle

    -- Check if we have a single main frame
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
            -- Force hide
            if frame.Hide then
                frame:Hide()
            end
        else
            -- Restore visibility (respecting enabled state logic)
            -- ApplySettings usually handles "Show if enabled" logic
            if self.ApplySettings then
                self:ApplySettings(frame)
            elseif frame.Show then
                frame:Show()
            end
        end
    end
end
