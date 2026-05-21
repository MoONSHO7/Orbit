-- [ STRATA ENGINE ] ---------------------------------------------------------------------------------
-- Root-container Z-index only; new plugins must be added to PopulateDefaults() and call GetFrameLevel("Global_HUD", "Orbit_PluginName") in OnLoad. Session-only offsets.
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

-- [ BUMPING ] ---------------------------------------------------------------------------------------
-- Swap entity with its neighbor. Fires ORBIT_STRATA_UPDATED so plugins re-apply.
function Engine:BumpUp(scopeID, entityID)
    local scope = self:GetScopeData(scopeID)
    local index
    for i, id in ipairs(scope.entities) do
        if id == entityID then index = i; break end
    end
    assert(index, "StrataEngine: Unregistered entity: " .. tostring(entityID))
    if index < #scope.entities then
        scope.entities[index], scope.entities[index + 1] = scope.entities[index + 1], scope.entities[index]
        self:_NotifyScope(scopeID)
    end
end

function Engine:BumpDown(scopeID, entityID)
    local scope = self:GetScopeData(scopeID)
    local index
    for i, id in ipairs(scope.entities) do
        if id == entityID then index = i; break end
    end
    assert(index, "StrataEngine: Unregistered entity: " .. tostring(entityID))
    if index > 1 then
        scope.entities[index], scope.entities[index - 1] = scope.entities[index - 1], scope.entities[index]
        self:_NotifyScope(scopeID)
    end
end

function Engine:BumpAbove(scopeID, entityID, targetEntityID)
    local scope = self:GetScopeData(scopeID)
    local sourceIndex, targetIndex
    for i, id in ipairs(scope.entities) do
        if id == entityID then sourceIndex = i end
        if id == targetEntityID then targetIndex = i end
    end
    assert(sourceIndex, "StrataEngine: Unregistered entity: " .. tostring(entityID))
    assert(targetIndex, "StrataEngine: Unregistered target: " .. tostring(targetEntityID))
    if sourceIndex == targetIndex then return end
    table.remove(scope.entities, sourceIndex)
    for i, id in ipairs(scope.entities) do
        if id == targetEntityID then targetIndex = i; break end
    end
    table.insert(scope.entities, targetIndex + 1, entityID)
    self:_NotifyScope(scopeID)
end

function Engine:_NotifyScope(scopeID)
    Orbit.EventBus:Fire("ORBIT_STRATA_UPDATED", scopeID)
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
