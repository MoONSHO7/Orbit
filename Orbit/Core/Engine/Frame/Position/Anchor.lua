-- [ ORBIT FRAME ANCHOR ]----------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameAnchor = Engine.FrameAnchor or {}
local Anchor = Engine.FrameAnchor

Anchor.anchors = Anchor.anchors or {}
Anchor.childrenOf = Anchor.childrenOf or setmetatable({}, { __mode = "k" })

local hookedParents = setmetatable({}, { __mode = "k" })

local ANCHOR_THRESHOLD = 5
local DEFAULT_PADDING = 2
local MIN_SYNC_HEIGHT = 5
local MIN_SYNC_WIDTH = 10

local EDGE_BORDER_MAP = {
    BOTTOM = { parent = "Bottom", child = "Top", inset = "Top" },
    TOP = { parent = "Top", child = "Bottom", inset = "Bottom" },
    LEFT = { parent = "Left", child = "Right", inset = "Right" },
    RIGHT = { parent = "Right", child = "Left", inset = "Left" },
}

local DEFAULT_OPTIONS = {
    horizontal = true, -- Allow LEFT/RIGHT edge anchoring (horizontal expansion)
    vertical = true, -- Allow TOP/BOTTOM edge anchoring (vertical stacking)
    syncScale = true,
    syncDimensions = true,
    mergeBorders = false, -- If true and Distance=0, redundant borders are hidden
    align = nil, -- Alignment override: TOP/CENTER/BOTTOM or LEFT/CENTER/RIGHT
    useRowDimension = false, -- Use parent's orbitRowHeight/orbitColumnWidth
}

local optionsCache = setmetatable({}, { __mode = "k" })

local function GetFrameOptions(frame)
    if frame:IsForbidden() then
        return DEFAULT_OPTIONS
    end
    if optionsCache[frame] then
        return optionsCache[frame]
    end
    local opts = {}
    for k, v in pairs(DEFAULT_OPTIONS) do
        opts[k] = v
    end
    if frame.anchorOptions then
        for k, v in pairs(frame.anchorOptions) do
            opts[k] = v
        end
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

local function SetMergeBorderState(parent, child, edge, hidden, overlap)
    local map = EDGE_BORDER_MAP[edge]
    if not map then
        return
    end
    if parent and parent.SetBorderHidden then
        parent:SetBorderHidden(map.parent, hidden)
    end
    if child.SetBorderHidden then
        child:SetBorderHidden(map.child, hidden)
    end
    if child.SetBackgroundInset then
        child:SetBackgroundInset(map.inset, hidden and overlap or 0)
    end
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

local function ApplyAnchorPosition(child, parent, edge, padding, align, syncOptions, chainOffsetX)
    if InCombatLockdown() and child:IsProtected() then
        return false
    end

    child:ClearAllPoints()

    local parentOptions = GetFrameOptions(parent)

    -- The Gelatinous Cube absorbs both borders, leaving nothing between
    local overlap = 0
    if syncOptions and syncOptions.mergeBorders and parentOptions.mergeBorders and syncOptions.syncScale and syncOptions.syncDimensions and padding == 0 then
        local pSize = (parent.borderPixelSize or 0)
        local cSize = (child.borderPixelSize or 0)
        if pSize == 0 then
            pSize = Orbit.Engine.Pixel:Multiple(1, parent:GetEffectiveScale() or 1)
        end
        if cSize == 0 then
            cSize = Orbit.Engine.Pixel:Multiple(1, child:GetEffectiveScale() or 1)
        end
        overlap = pSize + cSize
        SetMergeBorderState(parent, child, edge, true, overlap)
    elseif syncOptions and syncOptions.mergeBorders then
        SetMergeBorderState(parent, child, edge, false, 0)
    end

    -- Snap padding to physical pixels
    if Orbit.Engine.Pixel then
        padding = Orbit.Engine.Pixel:Snap(padding, child:GetEffectiveScale())
    end

    local ok, err = pcall(function()
        if edge == "BOTTOM" then
            if chainOffsetX then
                child:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", chainOffsetX, -padding + overlap)
            else
                local cLeft, cWidth = GetChainExtentForAlign(parent)
                if cLeft then
                    local parentW = parent:GetWidth()
                    if align == "LEFT" then
                        child:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", cLeft, -padding + overlap)
                    elseif align == "RIGHT" then
                        child:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", cLeft + cWidth - parentW, -padding + overlap)
                    else
                        child:SetPoint("TOP", parent, "BOTTOM", cLeft + cWidth / 2 - parentW / 2, -padding + overlap)
                    end
                elseif align == "LEFT" then
                    child:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -padding + overlap)
                elseif align == "RIGHT" then
                    child:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -padding + overlap)
                else
                    child:SetPoint("TOP", parent, "BOTTOM", 0, -padding + overlap)
                end
            end
        elseif edge == "TOP" then
            if chainOffsetX then
                child:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", chainOffsetX, padding - overlap)
            else
                local cLeft, cWidth = GetChainExtentForAlign(parent)
                if cLeft then
                    local parentW = parent:GetWidth()
                    if align == "LEFT" then
                        child:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", cLeft, padding - overlap)
                    elseif align == "RIGHT" then
                        child:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", cLeft + cWidth - parentW, padding - overlap)
                    else
                        child:SetPoint("BOTTOM", parent, "TOP", cLeft + cWidth / 2 - parentW / 2, padding - overlap)
                    end
                elseif align == "LEFT" then
                    child:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, padding - overlap)
                elseif align == "RIGHT" then
                    child:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, padding - overlap)
                else
                    child:SetPoint("BOTTOM", parent, "TOP", 0, padding - overlap)
                end
            end
        elseif edge == "LEFT" then
            if align == "TOP" then
                child:SetPoint("TOPRIGHT", parent, "TOPLEFT", -padding + overlap, 0)
            elseif align == "BOTTOM" then
                child:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", -padding + overlap, 0)
            else
                child:SetPoint("RIGHT", parent, "LEFT", -padding + overlap, 0)
            end
        elseif edge == "RIGHT" then
            if align == "TOP" then
                child:SetPoint("TOPLEFT", parent, "TOPRIGHT", padding - overlap, 0)
            elseif align == "BOTTOM" then
                child:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", padding - overlap, 0)
            else
                child:SetPoint("LEFT", parent, "RIGHT", padding - overlap, 0)
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
-- Walks Orbit anchor chain + native GetPoint relatives to catch orphaned SetPoint refs
local function WouldCreateCycle(anchors, child, parent)
    local visited = {}
    local current = parent
    while current do
        if current == child then
            return true
        end
        if visited[current] then
            break
        end
        visited[current] = true
        local anchor = anchors[current]
        local nextFrame = anchor and anchor.parent or nil
        if not nextFrame and current.GetNumPoints then
            for i = 1, current:GetNumPoints() do
                local _, relativeTo = current:GetPoint(i)
                if relativeTo == child then
                    return true
                end
            end
        end
        current = nextFrame
    end
    return false
end

function Anchor:CreateAnchor(child, parent, edge, padding, syncOptions, align, suppressApplySettings)
    if padding == nil then
        padding = DEFAULT_PADDING -- Default 2px gap
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
                local height = (opts.useRowDimension and parent.orbitRowHeight) or parentHeight
                child:SetHeight(math.max(height, MIN_SYNC_HEIGHT))
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

        if oldAnchor.syncOptions and oldAnchor.syncOptions.mergeBorders then
            SetMergeBorderState(oldAnchor.parent, child, oldAnchor.edge, false, 0)
        end

        self.anchors[child] = nil
        if oldAnchor.parent and self.childrenOf[oldAnchor.parent] then
            self.childrenOf[oldAnchor.parent][child] = nil
        end

        if not suppressApplySettings and child.orbitPlugin and child.orbitPlugin.ApplySettings then
            child.orbitPlugin:ApplySettings(child)
        end

        if child.OnAnchorChanged then
            child:OnAnchorChanged(nil, nil, nil)
        end

        return true
    end
    return false
end

-- [ DESTROY ANCHOR ]--------------------------------------------------------------------------------
-- Removes a frame from the anchor chain, re-anchoring its children to its parent.
-- If the frame has no parent, children are restored to their default positions.
function Anchor:DestroyAnchor(frame)
    local parentAnchor = self.anchors[frame]
    local children = self:GetAnchoredChildren(frame)

    -- Break the destroyed frame's own anchor FIRST to free up the occupied edge
    self:BreakAnchor(frame, true)

    if parentAnchor and #children > 0 then
        for _, child in ipairs(children) do
            local childAnchor = self.anchors[child]
            if childAnchor then
                self:CreateAnchor(child, parentAnchor.parent, childAnchor.edge, childAnchor.padding, childAnchor.syncOptions, childAnchor.align, true)
            end
        end
    else
        for _, child in ipairs(children) do
            self:BreakAnchor(child, false)
            child:ClearAllPoints()
            local dp = child.defaultPosition
            if dp then
                child:SetPoint(dp.point or "CENTER", dp.relativeTo or UIParent, dp.relativePoint or "CENTER", dp.x or 0, dp.y or 0)
            else
                child:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
            if child.orbitPlugin and child.systemIndex then
                child.orbitPlugin:SetSetting(child.systemIndex, "Anchor", nil)
            end
        end
    end
end

-- Centralized helper for setting frame disabled state
function Anchor:SetFrameDisabled(frame, disabled)
    frame.orbitDisabled = disabled
    if disabled then
        self:DestroyAnchor(frame)
        if frame.orbitPlugin and frame.systemIndex then
            frame.orbitPlugin:SetSetting(frame.systemIndex, "Anchor", nil)
        end
    end
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
    local minX, maxX = 0, root:GetWidth()
    local function walk(parent, parentLeft)
        local children = self.childrenOf[parent]
        if not children then
            return
        end
        for child in pairs(children) do
            local a = self.anchors[child]
            if a and (a.edge == "LEFT" or a.edge == "RIGHT") and child.orbitChainSync then
                local childLeft = (a.edge == "RIGHT") and (parentLeft + parent:GetWidth() + (a.padding or 0))
                    or (parentLeft - (a.padding or 0) - child:GetWidth())
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
        if a.edge == "RIGHT" then
            frameRelX = frameRelX + a.parent:GetWidth() + (a.padding or 0)
        elseif a.edge == "LEFT" then
            frameRelX = frameRelX - (a.padding or 0) - current:GetWidth()
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
            local h = (opts.useRowDimension and parent.orbitRowHeight) or parentHeight
            child:SetHeight(math.max(h, MIN_SYNC_HEIGHT))
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

function Anchor:SyncChildren(parent, suppressApplySettings, visited)
    if not parent or not parent.GetScale or not parent.GetWidth then
        return
    end

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

        if canSync then
            SyncChild(child, parent, anchor, parentScale, parentWidth, parentHeight)

            if child.orbitPlugin then
                if child.orbitPlugin.UpdateLayout then
                    child.orbitPlugin:UpdateLayout(child)
                elseif not isEditMode and not suppressApplySettings and child.orbitPlugin.ApplySettings then
                    child.orbitPlugin:ApplySettings(child)
                end
            end

            self:SyncChildren(child, suppressApplySettings, visited)
        end
    end
end

Anchor.GetFrameOptions = GetFrameOptions
Anchor.DEFAULT_OPTIONS = DEFAULT_OPTIONS
