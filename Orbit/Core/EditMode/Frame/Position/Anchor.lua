-- [ ORBIT FRAME ANCHOR ]----------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameAnchor = Engine.FrameAnchor or {}
local Anchor = Engine.FrameAnchor

Anchor.anchors = Anchor.anchors or {}
Anchor.childrenOf = Anchor.childrenOf or setmetatable({}, { __mode = "k" })

-- Initialize the graph companion with our authoritative tables
local Graph = Engine.AnchorGraph
Graph:Init(Anchor.anchors, Anchor.childrenOf)

local hookedParents = setmetatable({}, { __mode = "k" })
local optionsCache = setmetatable({}, { __mode = "k" })

local ANCHOR_THRESHOLD = 5
local DEFAULT_PADDING = 2
local NINESLICE_DEFAULT_PADDING = 10
local MIN_SYNC_HEIGHT = 5
local MIN_SYNC_WIDTH = 10



local DEFAULT_OPTIONS = {
    horizontal = true,
    vertical = true,
    syncScale = true,
    syncDimensions = true,
    mergeBorders = false,
    align = nil,
    useRowDimension = false,
    independentHeight = false,
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

local syncingChainRoot = false

local function HookParentSizeChange(parent, anchorModule)
    if hookedParents[parent] or parent:IsForbidden() then
        return
    end

    parent:HookScript("OnSizeChanged", function(self)
        if not anchorModule.childrenOf[self] or not next(anchorModule.childrenOf[self]) then return end
        anchorModule:SyncChildren(self)
        if not syncingChainRoot then
            local a = anchorModule.anchors[self]
            if a and (a.edge == "LEFT" or a.edge == "RIGHT") then
                local root = anchorModule:GetRootParent(self)
                if root and root ~= self then
                    syncingChainRoot = true
                    anchorModule:SyncChildren(root)
                    syncingChainRoot = false
                end
            end
        end
    end)

    hookedParents[parent] = true
end

local function SetMergeBorderState(parent, child, edge, hidden)
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

local function GetChainExtentForAlign(parent)
    if not parent.orbitChainSync then
        return nil
    end
    local chainWidth, leftOffset = Anchor:GetHorizontalChainExtent(parent)
    if not chainWidth then
        return nil
    end
    return leftOffset, chainWidth
end

ApplyAnchorPosition = function(child, parent, edge, padding, align, syncOptions, chainOffsetX)
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
            if chainOffsetX then
                child:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", Orbit.Engine.Pixel:Snap(chainOffsetX, child:GetEffectiveScale()), -padding)
            else
                local cLeft, cWidth = GetChainExtentForAlign(parent)
                if cLeft then
                    local parentW = parent:GetWidth()
                    if align == "LEFT" then
                        child:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", Orbit.Engine.Pixel:Snap(cLeft, child:GetEffectiveScale()), -padding)
                    elseif align == "RIGHT" then
                        child:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", Orbit.Engine.Pixel:Snap(cLeft + cWidth - parentW, child:GetEffectiveScale()), -padding)
                    else
                        child:SetPoint("TOP", parent, "BOTTOM", Orbit.Engine.Pixel:Snap(cLeft + cWidth / 2 - parentW / 2, child:GetEffectiveScale()), -padding)
                    end
                elseif align == "LEFT" then
                    child:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -padding)
                elseif align == "RIGHT" then
                    child:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -padding)
                else
                    child:SetPoint("TOP", parent, "BOTTOM", 0, -padding)
                end
            end
        elseif edge == "TOP" then
            if chainOffsetX then
                child:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", Orbit.Engine.Pixel:Snap(chainOffsetX, child:GetEffectiveScale()), padding)
            else
                local cLeft, cWidth = GetChainExtentForAlign(parent)
                if cLeft then
                    local parentW = parent:GetWidth()
                    if align == "LEFT" then
                        child:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", Orbit.Engine.Pixel:Snap(cLeft, child:GetEffectiveScale()), padding)
                    elseif align == "RIGHT" then
                        child:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", Orbit.Engine.Pixel:Snap(cLeft + cWidth - parentW, child:GetEffectiveScale()), padding)
                    else
                        child:SetPoint("BOTTOM", parent, "TOP", Orbit.Engine.Pixel:Snap(cLeft + cWidth / 2 - parentW / 2, child:GetEffectiveScale()), padding)
                    end
                elseif align == "LEFT" then
                    child:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, padding)
                elseif align == "RIGHT" then
                    child:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, padding)
                else
                    child:SetPoint("BOTTOM", parent, "TOP", 0, padding)
                end
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
        Orbit.ErrorHandler:Warn("Anchor", "SetPoint rejected: " .. tostring(err))
        return false
    end
    return true
end

-- Check if anchoring child to parent would create a circular dependency
-- Delegates to AnchorGraph for pure-data traversal (no GetNumPoints calls)
local function WouldCreateCycle(anchors, child, parent)
    return Graph:WouldCreateCycle(child, parent)
end

function Anchor:CreateAnchor(child, parent, edge, padding, syncOptions, align, suppressApplySettings)
    if padding == nil then
        local style = Orbit.Skin and Orbit.Skin:GetActiveBorderStyle()
        padding = (style and style.edgeFile) and NINESLICE_DEFAULT_PADDING or DEFAULT_PADDING
    end

    -- Prevent circular anchoring (checks full chain, not just immediate parent)
    if WouldCreateCycle(self.anchors, child, parent) then
        return false
    end

    local opts = syncOptions or GetFrameOptions(child)

    if self:IsEdgeOccupied(parent, edge, child, opts.syncDimensions, align) then
        return false
    end

    self:BreakAnchor(child, true)
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

    HookParentSizeChange(parent, self)

    local chainOffsetX = nil
    if not InCombatLockdown() then
        local parentScale = parent:GetScale()
        local parentWidth = parent:GetWidth()
        local parentHeight = parent:GetHeight()

        if opts.syncScale then
            child:SetScale(parentScale)
        end
        if opts.syncDimensions then
            if edge == "LEFT" or edge == "RIGHT" then
                if not (opts.independentHeight and suppressApplySettings) then
                    local height = math.max((opts.useRowDimension and parent.orbitRowHeight) or parentHeight, MIN_SYNC_HEIGHT)
                    child:SetHeight(height)
                    if opts.independentHeight and child.orbitPlugin and child.orbitPlugin.SetSetting and child.systemIndex then
                        child.orbitPlugin:SetSetting(child.systemIndex, "Height", math.floor(height + 0.5))
                    end
                end
            else
                local chainWidth, offsetX = self:GetHorizontalChainExtent(parent)
                if chainWidth then
                    child:SetWidth(math.max(chainWidth, MIN_SYNC_WIDTH))
                    chainOffsetX = offsetX
                else
                    local width = (opts.useRowDimension and parent.orbitColumnWidth) or parentWidth
                    child:SetWidth(math.max(width, MIN_SYNC_WIDTH))
                end
            end
        elseif opts.useRowDimension then
            if (edge == "LEFT" or edge == "RIGHT") and parent.orbitRowHeight then
                child:SetHeight(math.max(parent.orbitRowHeight, MIN_SYNC_HEIGHT))
            elseif parent.orbitColumnWidth then
                child:SetWidth(math.max(parent.orbitColumnWidth, MIN_SYNC_WIDTH))
            end
        end
    end

    if not ApplyAnchorPosition(child, parent, edge, padding, align, opts, chainOffsetX) then
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

function Anchor:BreakAnchor(child, suppressApplySettings)
    if self.anchors[child] then
        local oldAnchor = self.anchors[child]
        local oldParent = oldAnchor.parent
        local wasHorizontal = (oldAnchor.edge == "LEFT" or oldAnchor.edge == "RIGHT")

        -- Capture chain state before break for rebalancing
        local root, oldScreenCenterX
        if not suppressApplySettings and wasHorizontal and oldParent then
            root = self:GetRootParent(oldParent)
            if root then
                local minLeft, maxRight = self:GetHorizontalChainScreenBounds(root)
                if minLeft then oldScreenCenterX = (minLeft + maxRight) / 2 end
            end
        end

        self.anchors[child] = nil
        if oldAnchor.parent and self.childrenOf[oldAnchor.parent] then
            self.childrenOf[oldAnchor.parent][child] = nil
        end

        local pOpts = GetFrameOptions(oldParent)
        local cOpts = GetFrameOptions(child)
        if ShouldMergeBorders(pOpts, oldAnchor.edge) and ShouldMergeBorders(cOpts, oldAnchor.edge) then
            SetMergeBorderState(oldParent, child, oldAnchor.edge, false)
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

        -- Re-sync chain width and rebalance center
        if root then
            self:SyncChildren(root)
            self:RebalanceChainCenter(root, oldScreenCenterX)
        end

        return true
    end
    return false
end

function Anchor:RebalanceChainCenter(root, oldScreenCenterX)
    if not oldScreenCenterX or not root then return end
    local scale = root:GetEffectiveScale()
    if not scale or scale == 0 then return end

    local newScreenCenterX
    local newMinLeft, newMaxRight = self:GetHorizontalChainScreenBounds(root)
    if newMinLeft then
        newScreenCenterX = (newMinLeft + newMaxRight) / 2
    else
        local left, right = root:GetLeft(), root:GetRight()
        if left and right then newScreenCenterX = (left + right) / 2 * scale end
    end
    if not newScreenCenterX then return end

    local shift = oldScreenCenterX - newScreenCenterX
    if math.abs(shift) < 0.5 then return end

    local point, relativeTo, relativePoint, offsetX, offsetY = root:GetPoint(1)
    if not point or not relativeTo then return end
    root:ClearAllPoints()
    root:SetPoint(point, relativeTo, relativePoint, offsetX + shift / scale, offsetY)
end

-- Shared re-insert: reads saved anchor data and splices frame back into its chain
local function ReInsertFromSaved(self, frame)
    if not (frame.orbitPlugin and frame.systemIndex) then return end
    local saved
    if Orbit.Engine.PositionManager then
        saved = Orbit.Engine.PositionManager:GetAnchor(frame)
    end
    if not saved then
        saved = frame.orbitPlugin:GetSetting(frame.systemIndex, "Anchor")
    end
    if not (saved and saved.target) then return end
    local parent = _G[saved.target]
    if not parent then return end
    local displaced
    if self.childrenOf[parent] then
        for child in pairs(self.childrenOf[parent]) do
            local a = self.anchors[child]
            if a and a.edge == saved.edge and child ~= frame then
                displaced = { frame = child, edge = a.edge, padding = a.padding, syncOptions = a.syncOptions, align = a.align }
                break
            end
        end
    end
    if displaced then self:BreakAnchor(displaced.frame, true) end
    self:CreateAnchor(frame, parent, saved.edge, saved.padding or 0, nil, saved.align, true)
    if displaced then self:CreateAnchor(displaced.frame, frame, displaced.edge, displaced.padding or 0, displaced.syncOptions, displaced.align, true) end
end

-- Move frame to its default position (off-screen stash)
local function ParkFrame(frame)
    frame:ClearAllPoints()
    local def = frame.defaultPosition
    if not (def and def.point) then return end
    local x, y = def.x or 0, def.y or 0
    if Orbit.Engine.Pixel then
        x, y = Orbit.Engine.Pixel:SnapPosition(x, y, def.point, frame:GetWidth(), frame:GetHeight(), frame:GetEffectiveScale())
    end
    frame:SetPoint(def.point, def.relativeTo, def.relativePoint, x, y)
end

-- Profile-level disable: severs the frame from the chain entirely.
-- Re-enabling requires saved data to reconstruct the relationship.
function Anchor:SetFrameDisabled(frame, disabled)
    if not Graph:SetDisabled(frame, disabled) then return end
    frame.orbitDisabled = Graph:IsSkipped(frame)

    if disabled then
        ParkFrame(frame)
    else
        ReInsertFromSaved(self, frame)
    end
    local root = self:GetRootParent(frame)
    if root then Graph:ReconcileChain(root, self) end
end

-- Content-empty toggle: marks frames with no content (no spell, no auras)
-- for layout bypass. Children are re-parented to the nearest non-skipped
-- ancestor. Clearing virtual re-inserts from saved data.
function Anchor:SetFrameVirtual(frame, virtual)
    if not Graph:SetVirtual(frame, virtual) then return end
    frame.orbitDisabled = Graph:IsSkipped(frame)

    if virtual then
        ParkFrame(frame)
    else
        ReInsertFromSaved(self, frame)
    end
    local root = self:GetRootParent(frame)
    if root then Graph:ReconcileChain(root, self) end
end

function Anchor:GetAnchorParent(child)
    local anchor = self.anchors[child]
    return anchor and anchor.parent or nil
end

function Anchor:GetRootParent(frame)
    local current = frame
    local parent = self:GetAnchorParent(current)
    while parent do
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

function Anchor:GetAnchoredDescendants(frame)
    local result = {}
    local function walk(parent)
        if not self.childrenOf[parent] then return end
        for child in pairs(self.childrenOf[parent]) do
            if child.orbitChainSync then
                table.insert(result, child)
                walk(child)
            end
        end
    end
    walk(frame)
    return result
end

local function GetChainRoot(anchors, frame)
    local root = frame
    while true do
        local a = anchors[root]
        if not a or (a.edge ~= "LEFT" and a.edge ~= "RIGHT") then break end
        if not a.parent.orbitChainSync then break end
        root = a.parent
    end
    return root
end

function Anchor:GetHorizontalChainFrames(frame)
    if not frame.orbitChainSync then
        return nil
    end
    local root = GetChainRoot(self.anchors, frame)
    local frames = { root }
    local function walk(parent)
        local children = self.childrenOf[parent]
        if not children then
            return
        end
        for child in pairs(children) do
            local a = self.anchors[child]
            if a and (a.edge == "LEFT" or a.edge == "RIGHT") and child.orbitChainSync then
                table.insert(frames, child)
                walk(child)
            end
        end
    end
    walk(root)
    return frames
end

-- [ HORIZONTAL CHAIN EXTENT ]------------------------------------------------------------------------
function Anchor:GetHorizontalChainExtent(frame)
    if not frame.orbitChainSync then
        return nil, nil
    end
    local root = GetChainRoot(self.anchors, frame)
    local rootScale = root:GetEffectiveScale()
    local minX, maxX = 0, root:GetWidth()
    local function walk(parent, parentLeft)
        local children = self.childrenOf[parent]
        if not children then
            return
        end
        for child in pairs(children) do
            local a = self.anchors[child]
            if a and (a.edge == "LEFT" or a.edge == "RIGHT") and child.orbitChainSync then
                local pad = Orbit.Engine.Pixel:Multiple(a.padding or 0, rootScale)
                local childLeft = (a.edge == "RIGHT") and (parentLeft + parent:GetWidth() + pad)
                    or (parentLeft - pad - child:GetWidth())
                local childRight = childLeft + child:GetWidth()
                if childLeft < minX then
                    minX = childLeft
                end
                if childRight > maxX then
                    maxX = childRight
                end
                walk(child, childLeft)
            end
        end
    end
    walk(root, 0)
    local chainWidth = maxX - minX
    if chainWidth <= root:GetWidth() + 1 then
        return nil, nil
    end
    local frameRelX = 0
    local current = frame
    while current ~= root do
        local a = self.anchors[current]
        if not a then
            break
        end
        local pad = Orbit.Engine.Pixel:Multiple(a.padding or 0, rootScale)
        if a.edge == "RIGHT" then
            frameRelX = frameRelX + a.parent:GetWidth() + pad
        elseif a.edge == "LEFT" then
            frameRelX = frameRelX - pad - current:GetWidth()
        end
        current = a.parent
    end
    return chainWidth, minX - frameRelX
end

-- [ HORIZONTAL CHAIN SCREEN BOUNDS ]----------------------------------------------------------------
function Anchor:GetHorizontalChainScreenBounds(frame)
    local chainFrames = self:GetHorizontalChainFrames(frame)
    if not chainFrames or #chainFrames <= 1 then
        return nil
    end
    local minLeft, maxRight, minBottom, maxTop
    local root = chainFrames[1]
    for _, f in ipairs(chainFrames) do
        local s = f:GetEffectiveScale()
        local fl, fr, ft, fb = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
        if fl and s then
            fl, fr, ft, fb = fl * s, fr * s, ft * s, fb * s
            if not minLeft or fl < minLeft then
                minLeft = fl
            end
            if not maxRight or fr > maxRight then
                maxRight = fr
            end
            if not minBottom or fb < minBottom then
                minBottom = fb
            end
            if not maxTop or ft > maxTop then
                maxTop = ft
            end
        end
    end
    if not minLeft then
        return nil
    end
    return minLeft, maxRight, maxTop, minBottom, root
end

-- Check if a specific edge of a parent frame is already occupied by an anchored child
-- @param parent The parent frame to check
-- @param edge The edge to check ("TOP", "BOTTOM", "LEFT", "RIGHT")
-- @param excludeChild Optional child to exclude from check (for re-anchoring same child)
-- @return true if edge is occupied, false otherwise
local EDGE_ALIGN_SLOTS = {
    TOP = { "LEFT", "CENTER", "RIGHT" },
    BOTTOM = { "LEFT", "CENTER", "RIGHT" },
    LEFT = { "TOP", "CENTER", "BOTTOM" },
    RIGHT = { "TOP", "CENTER", "BOTTOM" },
}

function Anchor:IsEdgeOccupied(parent, edge, excludeChild, incomingSyncDims, incomingAlign)
    if not self.childrenOf[parent] then
        return false
    end

    local occupiedAligns = {}
    for child in pairs(self.childrenOf[parent]) do
        local anchor = self.anchors[child]
        if anchor and anchor.edge == edge and not child.orbitDisabled and child ~= excludeChild then
            local childSyncDims = anchor.syncOptions and anchor.syncOptions.syncDimensions
            if childSyncDims ~= false or not anchor.align then
                return true
            end
            occupiedAligns[anchor.align] = true
        end
    end

    if not next(occupiedAligns) then
        return false
    end
    if incomingSyncDims ~= false then
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

local function SyncChild(child, parent, anchor, parentScale, parentWidth, parentHeight)
    local opts = anchor.syncOptions or GetFrameOptions(child)
    if opts.syncScale then
        child:SetScale(parentScale)
    end
    local chainOffsetX = nil
    if opts.syncDimensions then
        if anchor.edge == "LEFT" or anchor.edge == "RIGHT" then
            if not opts.independentHeight then
                local h = (opts.useRowDimension and parent.orbitRowHeight) or parentHeight
                child:SetHeight(math.max(h, MIN_SYNC_HEIGHT))
            end
        else
            local chainWidth, offsetX = Anchor:GetHorizontalChainExtent(parent)
            if chainWidth then
                child:SetWidth(math.max(chainWidth, MIN_SYNC_WIDTH))
                chainOffsetX = offsetX
            else
                local w = (opts.useRowDimension and parent.orbitColumnWidth) or parentWidth
                child:SetWidth(math.max(w, MIN_SYNC_WIDTH))
            end
        end
    elseif opts.useRowDimension then
        if (anchor.edge == "LEFT" or anchor.edge == "RIGHT") and parent.orbitRowHeight then
            child:SetHeight(math.max(parent.orbitRowHeight, MIN_SYNC_HEIGHT))
        elseif parent.orbitColumnWidth then
            child:SetWidth(math.max(parent.orbitColumnWidth, MIN_SYNC_WIDTH))
        end
    end
    ApplyAnchorPosition(child, parent, anchor.edge, anchor.padding, anchor.align, opts, chainOffsetX)
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

    local parentScale = parent:GetScale()
    local parentWidth = parent:GetWidth()
    local parentHeight = parent:GetHeight()

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
            SyncChild(child, parent, anchor, parentScale, parentWidth, parentHeight)

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

-- [ REPAIR CHAIN ]----------------------------------------------------------------------------------
-- Delegates to AnchorGraph:ReconcileChain for targeted chain reconciliation.
function Anchor:RepairChain(root)
    if not root or InCombatLockdown() then return end
    Graph:ReconcileChain(root, self)
end

-- Repair all anchor chains across the entire system.
-- Delegates to AnchorGraph:ReconcileAll.
function Anchor:RepairAllChains()
    if InCombatLockdown() then return end
    Graph:ReconcileAll(self)
end

-- [ RESYNC ALL ]-------------------------------------------------------------------------------------
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

-- Re-sync after zone transitions so chain widths settle after all plugins apply settings
Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
    local delay = (Orbit.Constants and Orbit.Constants.Timing and Orbit.Constants.Timing.RetryShort) or 0.5
    C_Timer.After(delay, function() Anchor:ResyncAll() end)
end)

-- Re-reconcile chains after Edit Mode hooks to ensure plugins properly bypass empty seeds
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function()
        local delay = (Orbit.Constants and Orbit.Constants.Timing and Orbit.Constants.Timing.RetryShort) or 0.1
        C_Timer.After(delay, function() Graph:ReconcileAll(Anchor) end)
    end)
end

