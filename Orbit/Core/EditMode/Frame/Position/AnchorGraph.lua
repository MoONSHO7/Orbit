-- [ ORBIT ANCHOR GRAPH ]------------------------------------------------------------------------
-- Pure-data directed graph companion to Anchor.lua.
-- Tracks virtual/disabled state and provides graph traversal
-- without screen-coordinate dependencies.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.AnchorGraph = {}
local Graph = Engine.AnchorGraph

-- [ CONSTANTS ] --------------------------------------------------------------------------------
local HORIZONTAL_EDGES = { LEFT = true, RIGHT = true }

-- [ STATE ] ------------------------------------------------------------------------------------
-- Additive tracking layered over Anchor.anchors/childrenOf.
-- virtualNodes: content-empty frames that remain structurally registered
-- disabledNodes: profile-level disabled frames severed from layout
Graph.virtualNodes = {}
Graph.disabledNodes = {}

-- References set by Anchor.lua via Graph:Init()
Graph.anchors = nil
Graph.childrenOf = nil

-- [ INITIALIZATION ] ---------------------------------------------------------------------------
function Graph:Init(anchors, childrenOf)
    self.anchors = anchors
    self.childrenOf = childrenOf
end

-- [ VIRTUAL STATE ] ----------------------------------------------------------------------------
function Graph:SetVirtual(frame, virtual)
    local was = self.virtualNodes[frame]
    if (not not was) == (not not virtual) then return false end
    self.virtualNodes[frame] = virtual or nil
    return true
end

function Graph:IsVirtual(frame)
    return self.virtualNodes[frame] == true
end

-- [ DISABLED STATE ] ---------------------------------------------------------------------------
function Graph:SetDisabled(frame, disabled)
    local was = self.disabledNodes[frame]
    if (not not was) == (not not disabled) then return false end
    self.disabledNodes[frame] = disabled or nil
    return true
end

function Graph:IsDisabled(frame)
    return self.disabledNodes[frame] == true
end

-- [ COMBINED SKIP CHECK ] ----------------------------------------------------------------------
function Graph:IsSkipped(frame)
    return self.virtualNodes[frame] or self.disabledNodes[frame] or false
end

-- [ CYCLE DETECTION ] --------------------------------------------------------------------------
-- Pure-data walk. No GetNumPoints() calls.
function Graph:WouldCreateCycle(child, parent)
    local visited = {}
    local current = parent
    while current do
        if current == child then return true end
        if visited[current] then break end
        visited[current] = true
        local anchor = self.anchors[current]
        current = anchor and anchor.parent or nil
    end
    return false
end

-- [ CHAIN ROOT ] -------------------------------------------------------------------------------
function Graph:GetChainRoot(frame)
    local current = frame
    while true do
        local anchor = self.anchors[current]
        if not anchor or not anchor.parent then return current end
        current = anchor.parent
    end
end

-- [ HORIZONTAL CHAIN ROOT ] --------------------------------------------------------------------
function Graph:GetHorizontalChainRoot(frame)
    if not frame.orbitChainSync then return frame end
    local root = frame
    while true do
        local a = self.anchors[root]
        if not a or not HORIZONTAL_EDGES[a.edge] then break end
        if not a.parent.orbitChainSync then break end
        root = a.parent
    end
    return root
end

-- [ HORIZONTAL CHAIN NODES ] -------------------------------------------------------------------
function Graph:GetHorizontalChainNodes(frame)
    if not frame.orbitChainSync then return nil end
    local root = self:GetHorizontalChainRoot(frame)
    local frames = { root }
    local function walk(parent)
        local children = self.childrenOf[parent]
        if not children then return end
        for child in pairs(children) do
            local a = self.anchors[child]
            if a and HORIZONTAL_EDGES[a.edge] and child.orbitChainSync then
                frames[#frames + 1] = child
                walk(child)
            end
        end
    end
    walk(root)
    return frames
end

-- [ DEPENDENTS ] -------------------------------------------------------------------------------
function Graph:GetDependents(frame, chainSyncOnly)
    local result = {}
    local function walk(parent)
        local children = self.childrenOf[parent]
        if not children then return end
        for child in pairs(children) do
            if not chainSyncOnly or child.orbitChainSync then
                result[#result + 1] = child
                walk(child)
            end
        end
    end
    walk(frame)
    return result
end

-- [ CHILDREN ON EDGE ] -------------------------------------------------------------------------
function Graph:GetChildrenOnEdge(frame, edge)
    local result = {}
    local children = self.childrenOf[frame]
    if not children then return result end
    for child in pairs(children) do
        local a = self.anchors[child]
        if a and a.edge == edge then
            result[#result + 1] = child
        end
    end
    return result
end

-- [ TARGETED RECONCILIATION ] ------------------------------------------------------------------
-- Walks a single chain, re-parenting children of skipped (virtual/disabled)
-- frames to the nearest non-skipped ancestor. Replaces RepairAllChains()
-- with O(chain) instead of O(all_anchors) complexity.
function Graph:ReconcileChain(root, anchorModule)
    if InCombatLockdown() then return end
    local visited = {}
    local isEditMode = Orbit:IsEditMode()

    local function Reconcile(parent)
        if visited[parent] then return end
        visited[parent] = true
        local children = anchorModule:GetAnchoredChildren(parent)
        local i = 1
        while i <= #children do
            local child = children[i]
            if not visited[child] then
                local shouldSkip = self:IsSkipped(child) and not isEditMode
                if shouldSkip then
                    visited[child] = true
                    local grandchildren = anchorModule:GetAnchoredChildren(child)
                    for _, gc in ipairs(grandchildren) do
                        local gcAnchor = self.anchors[gc]
                        if gcAnchor then
                            anchorModule:CreateAnchor(gc, parent, gcAnchor.edge, gcAnchor.padding, gcAnchor.syncOptions, gcAnchor.align, true)
                            children[#children + 1] = gc
                        end
                    end
                else
                    Reconcile(child)
                end
            end
            i = i + 1
        end
    end

    local shouldSkipRoot = self:IsSkipped(root) and not isEditMode
    if shouldSkipRoot then
        visited[root] = true
        local children = anchorModule:GetAnchoredChildren(root)
        for _, gc in ipairs(children) do
            local fallback = nil
            if Orbit.Engine.PositionManager then
                local saved = Orbit.Engine.PositionManager:GetAnchor(gc)
                if saved and saved.fallback then fallback = _G[saved.fallback] end
            end
            if not fallback and gc.orbitPlugin and gc.systemIndex then
                local conf = gc.orbitPlugin:GetSetting(gc.systemIndex, "Anchor")
                if conf and conf.fallback then fallback = _G[conf.fallback] end
            end
            if fallback then
                local gcAnchor = self.anchors[gc]
                if gcAnchor then
                    anchorModule:CreateAnchor(gc, fallback, gcAnchor.edge, gcAnchor.padding, gcAnchor.syncOptions, gcAnchor.align, true)
                    self:ReconcileChain(fallback, anchorModule)
                end
            else
                Reconcile(gc)
            end
        end
    else
        Reconcile(root)
    end
end

-- [ RECONCILE ALL ] ----------------------------------------------------------------------------
-- Targeted replacement for RepairAllChains. Collects unique roots
-- then reconciles each. Same result, explicit about what it does.
function Graph:ReconcileAll(anchorModule)
    if InCombatLockdown() then return end
    local roots = {}
    for child in pairs(self.anchors) do
        roots[self:GetChainRoot(child)] = true
    end
    for root in pairs(roots) do
        self:ReconcileChain(root, anchorModule)
    end
end
