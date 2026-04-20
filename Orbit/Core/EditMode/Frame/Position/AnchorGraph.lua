-- [ ORBIT ANCHOR GRAPH ] ----------------------------------------------------------------------------
-- Pure-data graph companion to Anchor.lua; virtual/disabled state and traversal without coordinates.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.AnchorGraph = {}
local Graph = Engine.AnchorGraph

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local HORIZONTAL_EDGES = { LEFT = true, RIGHT = true }

-- [ STATE ] -----------------------------------------------------------------------------------------
-- Additive tracking: virtualNodes = content-empty, disabledNodes = profile-level disabled.
Graph.virtualNodes = {}
Graph.disabledNodes = {}

-- References set by Anchor.lua via Graph:Init()
Graph.anchors = nil
Graph.childrenOf = nil
Graph.logicalAnchors = nil
Graph.logicalChildrenOf = nil

-- [ INITIALIZATION ] --------------------------------------------------------------------------------
function Graph:Init(anchors, childrenOf, logicalAnchors, logicalChildrenOf)
    self.anchors = anchors
    self.childrenOf = childrenOf
    self.logicalAnchors = logicalAnchors
    self.logicalChildrenOf = logicalChildrenOf
end

-- [ VIRTUAL STATE ] ---------------------------------------------------------------------------------
function Graph:SetVirtual(frame, virtual)
    local was = self.virtualNodes[frame]
    if (not not was) == (not not virtual) then return false end
    self.virtualNodes[frame] = virtual or nil
    return true
end

function Graph:IsVirtual(frame)
    return self.virtualNodes[frame] == true
end

-- [ DISABLED STATE ] --------------------------------------------------------------------------------
function Graph:SetDisabled(frame, disabled)
    local was = self.disabledNodes[frame]
    if (not not was) == (not not disabled) then return false end
    self.disabledNodes[frame] = disabled or nil
    return true
end

function Graph:IsDisabled(frame)
    return self.disabledNodes[frame] == true
end

-- [ COMBINED SKIP CHECK ] ---------------------------------------------------------------------------
function Graph:IsSkipped(frame)
    return self.virtualNodes[frame] or self.disabledNodes[frame] or false
end

-- [ CYCLE DETECTION ] -------------------------------------------------------------------------------
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

-- [ CHAIN ROOT ] ------------------------------------------------------------------------------------
function Graph:GetChainRoot(frame)
    local current = frame
    local visited = {}
    while true do
        if visited[current] then return current end
        visited[current] = true
        local anchor = self.anchors[current]
        if not anchor or not anchor.parent then return current end
        current = anchor.parent
    end
end

-- [ HORIZONTAL CHAIN ROOT ] -------------------------------------------------------------------------
function Graph:GetHorizontalChainRoot(frame)
    if not frame.orbitChainSync then return frame end
    local root = frame
    local visited = {}
    while true do
        if visited[root] then break end
        visited[root] = true
        local a = self.anchors[root]
        if not a or not HORIZONTAL_EDGES[a.edge] then break end
        if not a.parent.orbitChainSync then break end
        root = a.parent
    end
    return root
end

-- [ HORIZONTAL CHAIN NODES ] ------------------------------------------------------------------------
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

-- [ DEPENDENTS ] ------------------------------------------------------------------------------------
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

-- [ CHILDREN ON EDGE ] ------------------------------------------------------------------------------
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

-- [ TARGETED RECONCILIATION ] -----------------------------------------------------------------------
-- Walk one chain, promote children past skipped frames; O(chain). skipLogical preserves intent.
function Graph:RestoreLogicalChildren(parent, anchorModule)
    if not self.logicalChildrenOf or not self.logicalChildrenOf[parent] then return end
    for child in pairs(self.logicalChildrenOf[parent]) do
        local physical = self.anchors[child]
        if physical and physical.parent ~= parent then
            local logical = self.logicalAnchors[child]
            if logical then
                anchorModule:CreateAnchor(child, parent, logical.edge, logical.padding, logical.syncOptions, logical.align, true, true)
            end
        end
    end
end

Graph._reconcilingChains = Graph._reconcilingChains or {}

function Graph:ReconcileChain(root, anchorModule)
    if InCombatLockdown() then return end
    if self._reconcilingChains[root] then return end
    self._reconcilingChains[root] = true
    local visited = {}

    -- Promote a grandchild of a skipped frame up to the nearest non-skipped
    -- ancestor. CreateAnchor's SetPoint places the grandchild on the promoted
    -- parent's edge, which is exactly what we want: empty children should
    -- stack under the grandparent's content in edit mode instead of following
    -- the skipped parent to its parked position.
    local function PromoteGrandchild(gc, parent)
        local gcAnchor = self.anchors[gc]
        if not gcAnchor then return false end
        return anchorModule:CreateAnchor(gc, parent, gcAnchor.edge, gcAnchor.padding, gcAnchor.syncOptions, gcAnchor.align, true, true)
    end

    local function Reconcile(parent)
        if visited[parent] then return end
        visited[parent] = true
        -- Before walking, pull any logically-owned children back home.
        self:RestoreLogicalChildren(parent, anchorModule)
        local children = anchorModule:GetAnchoredChildren(parent)
        local i = 1
        while i <= #children do
            local child = children[i]
            if not visited[child] then
                if self:IsSkipped(child) then
                    visited[child] = true
                    local grandchildren = anchorModule:GetAnchoredChildren(child)
                    for _, gc in ipairs(grandchildren) do
                        if PromoteGrandchild(gc, parent) then
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

    if self:IsSkipped(root) then
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
                if PromoteGrandchild(gc, fallback) then
                    self:ReconcileChain(fallback, anchorModule)
                end
            else
                Reconcile(gc)
            end
        end
    else
        Reconcile(root)
    end
    self._reconcilingChains[root] = nil
end

-- [ RECONCILE ALL ] ---------------------------------------------------------------------------------
-- Collects unique roots then reconciles each chain.
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

-- [ BATCH RECONCILIATION ] --------------------------------------------------------------------------
-- Coalesces per-root reconciles into a single next-frame flush; ScheduleAll supersedes per-root.
Graph.pendingRoots = {}
Graph.pendingModule = nil
Graph.pendingAll = false
Graph.flushScheduled = false

function Graph:EnsureFlushScheduled()
    if self.flushScheduled then return end
    self.flushScheduled = true
    C_Timer.After(0, function() self:FlushPendingReconciles() end)
end

function Graph:ScheduleReconcileChain(root, anchorModule)
    if not root then return end
    if self.pendingAll then return end
    self.pendingRoots[root] = true
    self.pendingModule = anchorModule or self.pendingModule
    self:EnsureFlushScheduled()
end

function Graph:ScheduleReconcileAll(anchorModule)
    self.pendingAll = true
    self.pendingModule = anchorModule or self.pendingModule
    self:EnsureFlushScheduled()
end

function Graph:FlushPendingReconciles()
    self.flushScheduled = false
    if InCombatLockdown() then
        -- Drop pending work into CombatManager for deferred replay after combat ends.
        if Orbit.CombatManager and Orbit.CombatManager.QueueUpdate then
            Orbit.CombatManager:QueueUpdate(function() self:FlushPendingReconciles() end)
        end
        return
    end
    local anchorModule = self.pendingModule
    self.pendingModule = nil
    if self.pendingAll then
        self.pendingAll = false
        self.pendingRoots = {}
        if anchorModule then self:ReconcileAll(anchorModule) end
        return
    end
    local roots = self.pendingRoots
    self.pendingRoots = {}
    if not anchorModule then return end
    -- Root may have shifted (GetChainRoot chases parents) if another scheduled
    -- change reparented it. Resolve at flush time, then dedupe resolved roots
    -- so we never walk the same chain twice.
    local resolved = {}
    for root in pairs(roots) do
        local current = self:GetChainRoot(root)
        if current then resolved[current] = true end
    end
    for root in pairs(resolved) do
        self:ReconcileChain(root, anchorModule)
    end
end
