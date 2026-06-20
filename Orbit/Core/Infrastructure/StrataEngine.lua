-- [ STRATA ENGINE ] ---------------------------------------------------------------------------------
-- Root-container Z-index only; new plugins must be added to PopulateDefaults() and call GetFrameLevel("Global_HUD", "Orbit_PluginName") in OnLoad. Entity ordering is profile-persisted; only _volatileBase is session-only.
local _, Orbit = ...
local C = Orbit.Constants

Orbit.StrataEngine = {}
local Engine = Orbit.StrataEngine

-- Volatile storage for dynamic session offsets, never persisted to SavedVariables
Engine._volatileBase = {}

-- [ SCOPE DATA ] ------------------------------------------------------------------------------------
function Engine:GetScopeData(scopeID)
    local layouts = Orbit.runtime and Orbit.runtime.Layouts
    assert(layouts, "StrataEngine: Profile Layouts not yet initialized!")
    layouts.Orbit = layouts.Orbit or {}
    layouts.Orbit.Orbit_StrataEngine = layouts.Orbit.Orbit_StrataEngine or {}
    layouts.Orbit.Orbit_StrataEngine[scopeID] = layouts.Orbit.Orbit_StrataEngine[scopeID] or { entities = {} }
    return layouts.Orbit.Orbit_StrataEngine[scopeID]
end

-- [ INITIALIZATION ] --------------------------------------------------------------------------------
function Engine:InitializeScope(scopeID, baseFrameLevel)
    self._volatileBase[scopeID] = baseFrameLevel or 1
    self:GetScopeData(scopeID)
end

function Engine:Register(scopeID, entityID, defaultIndex)
    assert(self._volatileBase[scopeID], "StrataEngine: Register into uninitialized scope: " .. tostring(scopeID))
    local scope = self:GetScopeData(scopeID)
    for _, id in ipairs(scope.entities) do
        if id == entityID then return end
    end
    if defaultIndex and defaultIndex <= #scope.entities + 1 then
        table.insert(scope.entities, defaultIndex, entityID)
    else
        table.insert(scope.entities, entityID)
    end
end

-- [ QUERY ] -----------------------------------------------------------------------------------------
-- absoluteLevel = baseFrameLevel + (entityIndex × StrataBlockReserve).
function Engine:GetFrameLevel(scopeID, entityID)
    assert(self._volatileBase[scopeID], "StrataEngine: Uninitialized scope: " .. tostring(scopeID))
    local scope = self:GetScopeData(scopeID)
    for i, id in ipairs(scope.entities) do
        if id == entityID then
            return self._volatileBase[scopeID] + (i * C.Levels.StrataBlockReserve)
        end
    end
    error("StrataEngine: Unregistered entity: " .. tostring(entityID) .. " in scope: " .. tostring(scopeID))
end

-- [ STARTUP POPULATION ] ----------------------------------------------------------------------------
-- Called once during Orbit:OnLoad before any plugin initializes.
function Engine:PopulateDefaults()
    self:InitializeScope("Global_HUD", 1)
    local defaults = {
        "Orbit_PlayerFrame",
        "Orbit_TargetFrame",
        "Orbit_PlayerPetFrame",
        "Orbit_GroupFrames",
        "Orbit_BossFrames",
        "Orbit_ActionBars",
        "Orbit_CooldownViewer",
        "Orbit_Minimap",
        "Orbit_Datatexts",
    }
    for i, entityID in ipairs(defaults) do
        self:Register("Global_HUD", entityID, i)
    end
end
