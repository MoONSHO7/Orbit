-- [ ORBIT FRAME ANCHOR ]-----------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameAnchor = Engine.FrameAnchor or {}
local Anchor = Engine.FrameAnchor

-- [ PHYSICAL GRAPH ] --------------------------------------------------------------------------------
-- Current physical attachments; rewritten by ReconcileChain when virtual/disabled frames shift.
Anchor.anchors = Anchor.anchors or {}
Anchor.childrenOf = Anchor.childrenOf or setmetatable({}, { __mode = "k" })

-- [ LOGICAL GRAPH ] ---------------------------------------------------------------------------------
-- User-intended anchoring; untouched by physical re-parenting so children can restore home.
Anchor.logicalAnchors = Anchor.logicalAnchors or {}
Anchor.logicalChildrenOf = Anchor.logicalChildrenOf or setmetatable({}, { __mode = "k" })

-- Initialize the graph companion with our authoritative tables
local Graph = Engine.AnchorGraph
Graph:Init(Anchor.anchors, Anchor.childrenOf, Anchor.logicalAnchors, Anchor.logicalChildrenOf)

local hookedParents = setmetatable({}, { __mode = "k" })
local optionsCache = setmetatable({}, { __mode = "k" })

local ANCHOR_THRESHOLD = 5
local DEFAULT_PADDING = 2
local NINESLICE_DEFAULT_PADDING = 10

-- [ AXIS REFS ] -------------------------------------------------------------------------------------
local AxisNS = Engine.Axis
local SyncEnabled = AxisNS.SyncEnabled
local AxisForEdge = AxisNS.ForEdge

local DEFAULT_OPTIONS = {
    horizontal        = true,
    vertical          = true,
    mergeBorders      = false,
    align             = nil,
    useRowDimension   = false,
    independentHeight = false,
    independentWidth  = false,
}

local function ShouldMergeBorders(opts, edge)
    local mb = opts.mergeBorders
    if not mb then return false end
    if mb == true then return true end
    if edge == "LEFT" or edge == "RIGHT" then return mb.x end
    return mb.y
end

local function GetFrameOptions(frame)
    if frame:IsForbidden() then return DEFAULT_OPTIONS end
    local cached = optionsCache[frame]
    if cached then return cached end
    local opts = {}
    for k, v in pairs(DEFAULT_OPTIONS) do opts[k] = v end
    if frame.anchorOptions then
        for k, v in pairs(frame.anchorOptions) do opts[k] = v end
    end
    optionsCache[frame] = opts
    return opts
end

local function HookParentSizeChange(parent, anchorModule)
    if hookedParents[parent] or parent:IsForbidden() then
        return
    end

    parent:HookScript("OnSizeChanged", function(self)
        if not anchorModule.childrenOf[self] or not next(anchorModule.childrenOf[self]) then return end
        anchorModule:SyncChildren(self)
    end)

    hookedParents[parent] = true
end

local function SetMergeBorderState(parent, child, edge, hidden, deferExecution)
    local function execute()
        if parent and parent.SetBorderHidden then
            parent:SetBorderHidden(hidden)
        end
        if child.SetBorderHidden then
            child:SetBorderHidden(hidden)
        end
        -- Clear group flag on the child only; parent may still be merged with other children
        if not hidden then
            child._groupBorderActive = nil
        end
        -- Update group border on the merge root directly — no deferral needed since
        -- bounding box is computed from anchor data, not screen coordinates.
        if Orbit.Skin and Orbit.Skin.UpdateGroupBorder then
            local mergeRoot = parent or child
            while true do
                local pa = Anchor.anchors[mergeRoot]
                if not pa or pa.padding ~= 0 then break end
                local pO = GetFrameOptions(pa.parent)
                local cO = GetFrameOptions(mergeRoot)
                if not (ShouldMergeBorders(pO, pa.edge) and ShouldMergeBorders(cO, pa.edge)) then break end
                mergeRoot = pa.parent
            end
            if mergeRoot and mergeRoot.GetFrameLevel then Orbit.Skin:UpdateGroupBorder(mergeRoot) end
            -- Only clear stale group overlays on the child when UN-merging; during merge,
            -- UpdateGroupBorder already handles hiding stale overlays on non-root frames.
            if not hidden and child and child.GetFrameLevel then Orbit.Skin:ClearGroupBorder(child) end
        end
    end

    if deferExecution then
        local mergeRoot = parent or child
        while true do
            local pa = Anchor.anchors[mergeRoot]
            if not pa or pa.padding ~= 0 then break end
            local pO = GetFrameOptions(pa.parent)
            local cO = GetFrameOptions(mergeRoot)
            if not (ShouldMergeBorders(pO, pa.edge) and ShouldMergeBorders(cO, pa.edge)) then break end
            mergeRoot = pa.parent
        end
        if mergeRoot and mergeRoot._groupBorderOverlay then
            mergeRoot._groupBorderOverlay:ClearAllPoints()
            mergeRoot._groupBorderOverlay:Hide()
        end
        Orbit.Async:Debounce("ApplyGroupBorder_"..tostring(child), execute, 0.05)
    else
        execute()
    end
end

local ApplyAnchorPosition

local function ApplyMergeBorders(child, anchorModule)
    local a = anchorModule.anchors[child]
    if not a or not a.parent then return end
    local pOpts = GetFrameOptions(a.parent)
    local cOpts = GetFrameOptions(child)
    if not ShouldMergeBorders(pOpts, a.edge) or not ShouldMergeBorders(cOpts, a.edge) then return end
    if InCombatLockdown() and child:IsProtected() then return end
    ApplyAnchorPosition(child, a.parent, a.edge, a.padding, a.align, a.syncOptions)
end

local function HookChildVisibility(child, anchorModule)
    if child._orbitMergeBorderHooked then return end
    child._orbitMergeBorderHooked = true
    child:HookScript("OnShow", function(self) ApplyMergeBorders(self, anchorModule) end)
    child:HookScript("OnHide", function(self) ApplyMergeBorders(self, anchorModule) end)
end

local function ReapplyChildrenMergeBorders(parent, anchorModule)
    local children = anchorModule.childrenOf[parent]
    if not children then return end
    for child in pairs(children) do
        ApplyMergeBorders(child, anchorModule)
    end
end

local function HookParentVisibility(parent, anchorModule)
    if parent._orbitMergeParentHooked then return end
    parent._orbitMergeParentHooked = true
    parent:HookScript("OnShow", function(self) ReapplyChildrenMergeBorders(self, anchorModule) end)
    parent:HookScript("OnHide", function(self) ReapplyChildrenMergeBorders(self, anchorModule) end)
end

ApplyAnchorPosition = function(child, parent, edge, padding, align, syncOptions)
    if InCombatLockdown() and child:IsProtected() then
        return false
    end

    child:ClearAllPoints()

    local parentOptions = GetFrameOptions(parent)
    local childOptions = GetFrameOptions(child)

    local bothMerge = ShouldMergeBorders(parentOptions, edge) and ShouldMergeBorders(childOptions, edge)
    local shouldMerge = bothMerge and padding == 0
    if shouldMerge and child:IsShown() and (child:GetAlpha() > 0 or child._oocFadeHidden) then
        SetMergeBorderState(parent, child, edge, true)
    elseif bothMerge then
        SetMergeBorderState(parent, child, edge, false)
    end

    -- Snap padding to physical pixels
    if Orbit.Engine.Pixel then
        padding = Orbit.Engine.Pixel:Multiple(padding, child:GetEffectiveScale())
    end

    local ok, err = pcall(function()
        if edge == "BOTTOM" then
            if align == "LEFT" then
                child:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -padding)
            elseif align == "RIGHT" then
                child:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -padding)
            else
                child:SetPoint("TOP", parent, "BOTTOM", 0, -padding)
            end
        elseif edge == "TOP" then
            if align == "LEFT" then
                child:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, padding)
            elseif align == "RIGHT" then
                child:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, padding)
            else
                child:SetPoint("BOTTOM", parent, "TOP", 0, padding)
            end
        elseif edge == "LEFT" then
            if align == "TOP" then
                child:SetPoint("TOPRIGHT", parent, "TOPLEFT", -padding, 0)
            elseif align == "BOTTOM" then
                child:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", -padding, 0)
            else
                child:SetPoint("RIGHT", parent, "LEFT", -padding, 0)
            end
        elseif edge == "RIGHT" then
            if align == "TOP" then
                child:SetPoint("TOPLEFT", parent, "TOPRIGHT", padding, 0)
            elseif align == "BOTTOM" then
                child:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", padding, 0)
            else
                child:SetPoint("LEFT", parent, "RIGHT", padding, 0)
            end
        end
    end)

    if not ok then
        Orbit.ErrorHandler:LogError("Anchor", "SetPoint", tostring(err))
        return false
    end
    return true
end

-- Check if anchoring child to parent would create a cycle; delegates to AnchorGraph.
local function WouldCreateCycle(anchors, child, parent)
    return Graph:WouldCreateCycle(child, parent)
end

-- Update the logical graph (user-intended anchor); never touches physical graph.
function Anchor:SetLogicalAnchor(child, parent, edge, padding, syncOptions, align)
    local prev = self.logicalAnchors[child]
    if prev and self.logicalChildrenOf[prev.parent] then
        self.logicalChildrenOf[prev.parent][child] = nil
    end
    self.logicalAnchors[child] = {
        parent = parent,
        edge = edge,
        padding = padding,
        syncOptions = syncOptions,
        align = align,
    }
    if not self.logicalChildrenOf[parent] then
        self.logicalChildrenOf[parent] = {}
    end
    self.logicalChildrenOf[parent][child] = true
end

function Anchor:ClearLogicalAnchor(child)
    local prev = self.logicalAnchors[child]
    if prev and self.logicalChildrenOf[prev.parent] then
        self.logicalChildrenOf[prev.parent][child] = nil
    end
    self.logicalAnchors[child] = nil
end

function Anchor:GetLogicalAnchor(child)
    return self.logicalAnchors[child]
end

function Anchor:GetLogicalChildren(parent)
    local result = {}
    if self.logicalChildrenOf[parent] then
        for child in pairs(self.logicalChildrenOf[parent]) do
            result[#result + 1] = child
        end
    end
    return result
end

function Anchor:CreateAnchor(child, parent, edge, padding, syncOptions, align, suppressApplySettings, skipLogical)
    if padding == nil then
        local style = Orbit.Skin and Orbit.Skin:GetActiveBorderStyle()
        padding = (style and style.edgeFile) and NINESLICE_DEFAULT_PADDING or DEFAULT_PADDING
    end

    -- Prevent circular anchoring (checks full chain, not just immediate parent)
    if WouldCreateCycle(self.anchors, child, parent) then
        return false
    end

    local opts = syncOptions or GetFrameOptions(child)
    local edgeAxisEarly = AxisForEdge(edge)
    local incomingSyncsCross = edgeAxisEarly and SyncEnabled(child, edgeAxisEarly.perpendicular) or false

    if self:IsEdgeOccupied(parent, edge, child, incomingSyncsCross, align) then
        return false
    end

    self:BreakAnchor(child, true, false, skipLogical)
    self.anchors[child] = {
        parent = parent,
        edge = edge,
        padding = padding,
        syncOptions = opts,
        align = align,
    }
    if not self.childrenOf[parent] then
        self.childrenOf[parent] = {}
    end
    self.childrenOf[parent][child] = true

    if not skipLogical then
        self:SetLogicalAnchor(child, parent, edge, padding, opts, align)
    end

    HookParentSizeChange(parent, self)

    local edgeAxis = edgeAxisEarly
    local crossAxis = edgeAxis and edgeAxis.perpendicular
    if not InCombatLockdown() and edgeAxis then
        if SyncEnabled(child, crossAxis) then
            local indepFlag = crossAxis.independentFlag
            if not (opts[indepFlag] and suppressApplySettings) then
                local parentSize = (opts.useRowDimension and parent[crossAxis.rowDim]) or crossAxis.getSize(parent)
                local synced = math.max(parentSize, crossAxis.minSize)
                crossAxis.setSize(child, synced)
                -- Preserved quirk: when child opts out of cross-axis sync but we're applying live
                -- (not suppressed), sync anyway AND record back to the plugin's saved dimension.
                if opts[indepFlag] and child.orbitPlugin and child.orbitPlugin.SetSetting and child.systemIndex then
                    local key = (crossAxis.name == "vertical") and "Height" or "Width"
                    child.orbitPlugin:SetSetting(child.systemIndex, key, math.floor(synced + 0.5))
                end
            end
        elseif opts.useRowDimension then
            local rowSize = parent[crossAxis.rowDim]
            if rowSize then crossAxis.setSize(child, math.max(rowSize, crossAxis.minSize)) end
        end
    end

    if not ApplyAnchorPosition(child, parent, edge, padding, align, opts) then
        self.anchors[child] = nil
        return false
    end

    local pOpts = GetFrameOptions(parent)
    local cOpts = GetFrameOptions(child)
    if ShouldMergeBorders(pOpts, edge) and ShouldMergeBorders(cOpts, edge) then
        HookChildVisibility(child, self)
        HookParentVisibility(parent, self)
    end

    if child.orbitPlugin then
        if child.orbitPlugin.UpdateLayout then
            child.orbitPlugin:UpdateLayout(child)
        elseif not suppressApplySettings and child.orbitPlugin.ApplySettings then
            local isEditMode = Orbit:IsEditMode()
            if not isEditMode then
                child.orbitPlugin:ApplySettings(child)
            end
        end
    end
    -- Notify parent it gained a child
    if not suppressApplySettings and parent.orbitPlugin then
        if parent.orbitPlugin.UpdateLayout then parent.orbitPlugin:UpdateLayout(parent)
        elseif parent.orbitPlugin.ApplySettings then parent.orbitPlugin:ApplySettings(parent) end
    end

    if child.OnAnchorChanged then
        child:OnAnchorChanged(parent, edge, padding)
    end

    local root = self:GetRootParent(child)
    if root and root ~= child then
        self:SyncChildren(root, suppressApplySettings)
    end

    return true
end

function Anchor:BreakAnchor(child, suppressApplySettings, deferMergeVisuals, skipLogical)
    if self.anchors[child] then
        local oldAnchor = self.anchors[child]
        local oldParent = oldAnchor.parent
        local oldEdgeAxis = AxisForEdge(oldAnchor.edge)

        -- Parent frames are the source of truth and never move on their own when a child joins or
        -- leaves the anchor graph. Re-sync children after the break but do not shift the root.
        local root
        if not suppressApplySettings and oldEdgeAxis and oldParent then
            root = self:GetRootParent(oldParent)
        end

        self.anchors[child] = nil
        if oldAnchor.parent and self.childrenOf[oldAnchor.parent] then
            self.childrenOf[oldAnchor.parent][child] = nil
        end
        -- Only clear the logical anchor when the caller explicitly intends a
        -- user-driven break. Physical repairs (ReconcileChain) pass skipLogical=true
        -- so the user-intended parent reference survives across virtual/disabled toggles.
        if not skipLogical then
            self:ClearLogicalAnchor(child)
        end

        local pOpts = GetFrameOptions(oldParent)
        local cOpts = GetFrameOptions(child)
        if ShouldMergeBorders(pOpts, oldAnchor.edge) and ShouldMergeBorders(cOpts, oldAnchor.edge) then
            SetMergeBorderState(oldParent, child, oldAnchor.edge, false, deferMergeVisuals)
        end

        if not suppressApplySettings and child.orbitPlugin and child.orbitPlugin.ApplySettings then
            child.orbitPlugin:ApplySettings(child)
        end
        -- Notify parent it lost a child
        if not suppressApplySettings and oldParent and oldParent.orbitPlugin then
            if oldParent.orbitPlugin.UpdateLayout then oldParent.orbitPlugin:UpdateLayout(oldParent)
            elseif oldParent.orbitPlugin.ApplySettings then oldParent.orbitPlugin:ApplySettings(oldParent) end
        end

        if child.OnAnchorChanged then
            child:OnAnchorChanged(nil, nil, nil)
        end

        -- Re-sync children only. Parent stays put — it's the source of truth.
        if root then
            self:SyncChildren(root)
        end

        return true
    end
    return false
end


-- Park frame at its default position; also called by ReconcileChain for skipped grandchildren.
function Anchor:ParkFrame(frame)
    frame:ClearAllPoints()
    local def = frame.defaultPosition
    if not (def and def.point) then return end
    local x, y = def.x or 0, def.y or 0
    if Orbit.Engine.Pixel then
        x, y = Orbit.Engine.Pixel:SnapPosition(x, y, def.point, frame:GetWidth(), frame:GetHeight(), frame:GetEffectiveScale())
    end
    frame:SetPoint(def.point, def.relativeTo, def.relativePoint, x, y)
end
local function ParkFrame(frame) Anchor:ParkFrame(frame) end

-- A rescued frame's logical parent is skipped but it's physically at a live ancestor; don't re-park.
local function IsRescued(frame)
    local logical = Anchor.logicalAnchors[frame]
    local physical = Anchor.anchors[frame]
    if not (logical and physical) then return false end
    if logical.parent == physical.parent then return false end
    return Graph:IsSkipped(logical.parent) and not Graph:IsSkipped(physical.parent)
end

-- Profile-level disable: skip frame in graph, park it, and batch-reconcile children. Idempotent.
function Anchor:SetFrameDisabled(frame, disabled)
    local changed = Graph:SetDisabled(frame, disabled)
    frame.orbitDisabled = Graph:IsSkipped(frame)

    if disabled then
        if not IsRescued(frame) then ParkFrame(frame) end
    elseif not changed then
        return
    end
    local root = self:GetRootParent(frame)
    if root then Graph:ScheduleReconcileChain(root, self) end
end

-- Content-empty toggle: skip frame in graph and park it; batched and idempotent like SetFrameDisabled.
function Anchor:SetFrameVirtual(frame, virtual)
    local changed = Graph:SetVirtual(frame, virtual)
    frame.orbitDisabled = Graph:IsSkipped(frame)

    if virtual then
        if not IsRescued(frame) then ParkFrame(frame) end
    elseif not changed then
        return
    end
    local root = self:GetRootParent(frame)
    if root then Graph:ScheduleReconcileChain(root, self) end
end

function Anchor:GetAnchorParent(child)
    local anchor = self.anchors[child]
    return anchor and anchor.parent or nil
end

function Anchor:GetRootParent(frame)
    local current = frame
    local visited = {}
    local parent = self:GetAnchorParent(current)
    while parent do
        if visited[parent] then return current end
        visited[parent] = true
        current = parent
        parent = self:GetAnchorParent(current)
    end
    return current
end

function Anchor:GetAnchoredChildren(parent)
    local children = {}
    if self.childrenOf[parent] then
        for child in pairs(self.childrenOf[parent]) do
            table.insert(children, child)
        end
    end
    return children
end

-- Check if a specific edge of a parent frame is already occupied by an anchored child.
local EDGE_ALIGN_SLOTS = {
    TOP = { "LEFT", "CENTER", "RIGHT" },
    BOTTOM = { "LEFT", "CENTER", "RIGHT" },
    LEFT = { "TOP", "CENTER", "BOTTOM" },
    RIGHT = { "TOP", "CENTER", "BOTTOM" },
}

-- incomingSyncsCross: does the candidate child sync on the cross-axis of `edge`?
-- A size-synced child fills the full edge; a non-synced child shares via LEFT/CENTER/RIGHT slots.
function Anchor:IsEdgeOccupied(parent, edge, excludeChild, incomingSyncsCross, incomingAlign)
    if not self.childrenOf[parent] then
        return false
    end

    local edgeAxis = AxisForEdge(edge)
    local crossAxis = edgeAxis and edgeAxis.perpendicular

    local occupiedAligns = {}
    for child in pairs(self.childrenOf[parent]) do
        local anchor = self.anchors[child]
        if anchor and anchor.edge == edge and not child.orbitDisabled and child ~= excludeChild then
            local childSyncsCross = crossAxis and SyncEnabled(child, crossAxis) or false
            if childSyncsCross or not anchor.align then
                return true
            end
            occupiedAligns[anchor.align] = true
        end
    end

    if not next(occupiedAligns) then
        return false
    end
    if incomingSyncsCross then
        return true
    end
    if incomingAlign then
        return occupiedAligns[incomingAlign] == true
    end

    local slots = EDGE_ALIGN_SLOTS[edge]
    if not slots then
        return true
    end
    for _, slot in ipairs(slots) do
        if not occupiedAligns[slot] then
            return false
        end
    end
    return true
end

local function SyncChild(child, parent, anchor, resolvedPadding)
    local opts = anchor.syncOptions or GetFrameOptions(child)

    local edgeAxis = AxisForEdge(anchor.edge)
    local crossAxis = edgeAxis and edgeAxis.perpendicular

    if edgeAxis and SyncEnabled(child, crossAxis) then
        if not opts[crossAxis.independentFlag] then
            local parentSize = (opts.useRowDimension and parent[crossAxis.rowDim]) or crossAxis.getSize(parent)
            crossAxis.setSize(child, math.max(parentSize, crossAxis.minSize))
        end
    elseif edgeAxis and opts.useRowDimension then
        local rowSize = parent[crossAxis.rowDim]
        if rowSize then crossAxis.setSize(child, math.max(rowSize, crossAxis.minSize)) end
    end

    ApplyAnchorPosition(child, parent, anchor.edge, resolvedPadding or anchor.padding, anchor.align, opts)
    return opts
end

function Anchor:SyncChildren(parent, suppressApplySettings, visited, depth)
    if not parent or not parent.GetScale or not parent.GetWidth then
        return
    end

    depth = depth or 1
    visited = visited or {}
    if visited[parent] then
        return
    end
    visited[parent] = true

    local childrenToSync = {}
    if self.childrenOf[parent] then
        for child in pairs(self.childrenOf[parent]) do
            local anchor = self.anchors[child]
            if anchor then
                table.insert(childrenToSync, { child = child, anchor = anchor })
            end
        end
    end

    local isEditMode = Orbit:IsEditMode()

    for _, entry in ipairs(childrenToSync) do
        local child = entry.child
        local anchor = entry.anchor
        local canSync = (isEditMode and not InCombatLockdown() and not child:IsForbidden())
            or (not child:IsForbidden() and (not InCombatLockdown() or not child:IsProtected()))

        if child.orbitDisabled then canSync = false end

        if canSync then
            SyncChild(child, parent, anchor)

            if child.orbitPlugin then
                if child.orbitPlugin.UpdateLayout then
                    child.orbitPlugin:UpdateLayout(child)
                elseif not isEditMode and not suppressApplySettings and child.orbitPlugin.ApplySettings then
                    if depth > 8 then
                        local timerDelay = (Orbit.Constants and Orbit.Constants.Timing and Orbit.Constants.Timing.RetryShort) or 0.1
                        C_Timer.After(timerDelay, function() child.orbitPlugin:ApplySettings(child) end)
                    else
                        child.orbitPlugin:ApplySettings(child)
                    end
                end
            end

            self:SyncChildren(child, suppressApplySettings, visited, depth + 1)
        end
    end
end

-- [ RECONCILE CHAIN ] -------------------------------------------------------------------------------
function Anchor:ReconcileChain(root)
    if not root or InCombatLockdown() then return end
    Graph:ReconcileChain(root, self)
end

-- Reconcile all chains; delegates to AnchorGraph:ReconcileAll.
function Anchor:ReconcileAll()
    if InCombatLockdown() then return end
    Graph:ReconcileAll(self)
end

-- [ BATCHED RECONCILIATION ] ------------------------------------------------------------------------
-- Schedule reconcile for next frame; multiple calls with same root collapse to one.
function Anchor:ScheduleReconcileChain(root)
    Graph:ScheduleReconcileChain(root, self)
end

function Anchor:ScheduleReconcileAll()
    Graph:ScheduleReconcileAll(self)
end

-- [ RESYNC ALL ] ------------------------------------------------------------------------------------
-- Re-syncs all anchored frames (e.g. after border size changes affect spacing).
function Anchor:ResyncAll()
    if InCombatLockdown() then return end
    local roots = {}
    for child in pairs(self.anchors) do
        local root = self:GetRootParent(child)
        roots[root] = true
    end
    for root in pairs(roots) do
        self:SyncChildren(root)
    end
end

Anchor.GetFrameOptions = GetFrameOptions
Anchor.ShouldMergeBorders = ShouldMergeBorders
Anchor.DEFAULT_OPTIONS = DEFAULT_OPTIONS

-- Listen for border size changes to re-sync anchor distances
Orbit.EventBus:On("ORBIT_BORDER_SIZE_CHANGED", function() Anchor:ResyncAll() end)

-- Re-sync after zone transitions so child widths settle after all plugins apply settings
Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
    local delay = (Orbit.Constants and Orbit.Constants.Timing and Orbit.Constants.Timing.RetryShort) or 0.5
    C_Timer.After(delay, function() Anchor:ResyncAll() end)
end)

-- Re-reconcile chains after Edit Mode enter; scheduled to collapse with in-flight reconciles.
if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        local delay = (Orbit.Constants and Orbit.Constants.Timing and Orbit.Constants.Timing.RetryShort) or 0.1
        C_Timer.After(delay, function() Graph:ScheduleReconcileAll(Anchor) end)
    end, Anchor)
end

