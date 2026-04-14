-- [ STRATA ENGINE ] ---------------------------------------------------------------------------------
-- Manages the dynamic visual layering (Z-index) of root-level UI containers.
-- Persists entity ordering to the active Profile via Orbit.runtime.Layouts,
-- enabling future "Bump Up / Bump Down" controls in Edit Mode and Canvas Mode.
--
-- Scope:
--   Root containers only (PlayerFrame, GroupFrames, ActionBars, etc.).
--   Sub-component layering (StatusBar, Border, Overlay) stays in Constants.Levels.
--   Frame strata (MEDIUM, DIALOG, etc.) stays in Constants.Strata.
--
-- Registration contract:
--   New plugins MUST be added to PopulateDefaults() to participate in bumping.
--   Plugins call GetFrameLevel("Global_HUD", "Orbit_PluginName") during OnLoad.
--
-- Persistence:
--   Entity order is stored in Orbit.runtime.Layouts.Orbit.Orbit_StrataEngine.
--   baseFrameLevel offsets are volatile (session-only, never saved).

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
-- Returns the absolute frame level for a registered entity.
-- Formula: baseFrameLevel + (entityIndex * StrataBlockReserve)
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
-- Swap entity with its neighbor. Fires STRATA_UPDATED so plugins re-apply.
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
    Orbit.EventBus:Fire("STRATA_UPDATED", scopeID)
end

-- [ STARTUP POPULATION ] ----------------------------------------------------------------------------
-- Seeds the Global_HUD scope with all root-level containers in default order.
-- Called once during Orbit:OnLoad(), before any plugin initializes.
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
