-- [ ORBIT FRAME ANCHOR ]----------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameAnchor = Engine.FrameAnchor or {}
local Anchor = Engine.FrameAnchor

Anchor.anchors = Anchor.anchors or {}

local hookedParents = setmetatable({}, { __mode = "k" })

local ANCHOR_THRESHOLD = 5
local DEFAULT_PADDING = 2

local DEFAULT_OPTIONS = {
    horizontal = true, -- Allow LEFT/RIGHT edge anchoring (horizontal expansion)
    vertical = true, -- Allow TOP/BOTTOM edge anchoring (vertical stacking)
    syncScale = true,
    syncDimensions = true,
    mergeBorders = false, -- If true and Distance=0, redundant borders are hidden
    align = nil, -- Alignment override: TOP/CENTER/BOTTOM or LEFT/CENTER/RIGHT
    useRowDimension = false, -- Use parent's orbitRowHeight/orbitColumnWidth
}

local function GetFrameOptions(frame)
    if frame:IsForbidden() then
        return DEFAULT_OPTIONS
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

    return opts
end

local function HookParentSizeChange(parent, anchorModule)
    if hookedParents[parent] or parent:IsForbidden() then
        return
    end

    parent:HookScript("OnSizeChanged", function(self)
        anchorModule:SyncChildren(self)
    end)

    hookedParents[parent] = true
end

-- Helper to apply position without triggering side effects
local function ApplyAnchorPosition(child, parent, edge, padding, align, syncOptions)
    -- Prevent moving protected frames in combat to avoid taint/action blocked errors
    if InCombatLockdown() and child:IsProtected() then
        return
    end

    child:ClearAllPoints()

    local parentOptions = GetFrameOptions(parent)

    -- Merge Borders Logic
    local overlap = 0
    if
        syncOptions
        and syncOptions.mergeBorders
        and parentOptions.mergeBorders
        and syncOptions.syncScale
        and syncOptions.syncDimensions
        and padding == 0
    then
        -- Calculate Overlap needed to make contents touch
        -- We want to remove the space of BOTH borders (since both are hidden)
        -- Overlap = ParentBorder + ChildBorder
        local pSize = (parent.borderPixelSize or 1)
        local cSize = (child.borderPixelSize or 1)

        -- If we can't find exact size, we might guess based on Pixel scale, but exact is better.
        -- If missing, we'll try to calculate or default to "1 pixel" in screen coords?
        if not parent.borderPixelSize then
            local pixelScale = (Orbit.Engine.Pixel and Orbit.Engine.Pixel:GetScale()) or 1
            local scale = parent:GetEffectiveScale() or 1
            pSize = (1 * pixelScale) / scale
        end
        if not child.borderPixelSize then
            local pixelScale = (Orbit.Engine.Pixel and Orbit.Engine.Pixel:GetScale()) or 1
            local scale = child:GetEffectiveScale() or 1
            cSize = (1 * pixelScale) / scale
        end

        overlap = pSize + cSize

        -- We are merged. Determine which borders to hide.
        if edge == "BOTTOM" then
            if parent.SetBorderHidden then
                parent:SetBorderHidden("Bottom", true)
            end
            if child.SetBorderHidden then
                child:SetBorderHidden("Top", true)
            end
            -- Inset child's top background to prevent overlap
            if child.SetBackgroundInset then
                child:SetBackgroundInset("Top", overlap)
            end
        elseif edge == "TOP" then
            if parent.SetBorderHidden then
                parent:SetBorderHidden("Top", true)
            end
            if child.SetBorderHidden then
                child:SetBorderHidden("Bottom", true)
            end
            -- Inset child's bottom background to prevent overlap
            if child.SetBackgroundInset then
                child:SetBackgroundInset("Bottom", overlap)
            end
        elseif edge == "LEFT" then
            if parent.SetBorderHidden then
                parent:SetBorderHidden("Left", true)
            end
            if child.SetBorderHidden then
                child:SetBorderHidden("Right", true)
            end
            -- Inset child's right background to prevent overlap
            if child.SetBackgroundInset then
                child:SetBackgroundInset("Right", overlap)
            end
        elseif edge == "RIGHT" then
            if parent.SetBorderHidden then
                parent:SetBorderHidden("Right", true)
            end
            if child.SetBorderHidden then
                child:SetBorderHidden("Left", true)
            end
            -- Inset child's left background to prevent overlap
            if child.SetBackgroundInset then
                child:SetBackgroundInset("Left", overlap)
            end
        end
    else
        -- Not merged - restore borders and reset background insets
        if syncOptions and syncOptions.mergeBorders then
            if edge == "BOTTOM" then
                if parent.SetBorderHidden then
                    parent:SetBorderHidden("Bottom", false)
                end
                if child.SetBorderHidden then
                    child:SetBorderHidden("Top", false)
                end
                if child.SetBackgroundInset then
                    child:SetBackgroundInset("Top", 0)
                end
            elseif edge == "TOP" then
                if parent.SetBorderHidden then
                    parent:SetBorderHidden("Top", false)
                end
                if child.SetBorderHidden then
                    child:SetBorderHidden("Bottom", false)
                end
                if child.SetBackgroundInset then
                    child:SetBackgroundInset("Bottom", 0)
                end
            elseif edge == "LEFT" then
                if parent.SetBorderHidden then
                    parent:SetBorderHidden("Left", false)
                end
                if child.SetBorderHidden then
                    child:SetBorderHidden("Right", false)
                end
                if child.SetBackgroundInset then
                    child:SetBackgroundInset("Right", 0)
                end
            elseif edge == "RIGHT" then
                if parent.SetBorderHidden then
                    parent:SetBorderHidden("Right", false)
                end
                if child.SetBorderHidden then
                    child:SetBorderHidden("Left", false)
                end
                if child.SetBackgroundInset then
                    child:SetBackgroundInset("Left", 0)
                end
            end
        end
    end

    -- Snap padding to physical pixels
    if Orbit.Engine.Pixel then
        padding = Orbit.Engine.Pixel:Snap(padding, child:GetEffectiveScale())
    end

    if edge == "BOTTOM" then
        if align == "LEFT" then
            child:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -padding + overlap)
        elseif align == "RIGHT" then
            child:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -padding + overlap)
        else
            child:SetPoint("TOP", parent, "BOTTOM", 0, -padding + overlap)
        end
    elseif edge == "TOP" then
        if align == "LEFT" then
            child:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, padding - overlap)
        elseif align == "RIGHT" then
            child:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, padding - overlap)
        else
            child:SetPoint("BOTTOM", parent, "TOP", 0, padding - overlap)
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
end

-- Check if anchoring child to parent would create a circular dependency
-- Walks up the anchor chain from parent to see if it eventually reaches child
local function WouldCreateCycle(anchors, child, parent)
    local visited = {}
    local current = parent
    while current do
        if current == child then
            return true -- Found child in parent's ancestor chain = cycle
        end
        if visited[current] then
            break -- Already visited, prevent infinite loop from existing bad state
        end
        visited[current] = true
        local anchor = anchors[current]
        current = anchor and anchor.parent or nil
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

    -- Prevent anchoring to an edge that's already occupied by another child
    -- TODO: Maybe adjust this in the future for non-width synced frames?
    if self:IsEdgeOccupied(parent, edge, child) then
        return false
    end

    local opts = syncOptions or GetFrameOptions(child)

    self:BreakAnchor(child, true)
    self.anchors[child] = {
        parent = parent,
        edge = edge,
        padding = padding,
        syncOptions = opts,
        align = align, -- Store alignment
    }

    HookParentSizeChange(parent, self)

    if not InCombatLockdown() then
        local parentScale = parent:GetScale()
        local parentWidth = parent:GetWidth()
        local parentHeight = parent:GetHeight()

        if opts.syncScale then
            child:SetScale(parentScale)
        end

        if opts.syncDimensions then
            if edge == "LEFT" or edge == "RIGHT" then
                local height = parentHeight
                if opts.useRowDimension and parent.orbitRowHeight then
                    height = parent.orbitRowHeight
                end
                child:SetHeight(math.max(height, 5))
            else
                local width = parentWidth
                if opts.useRowDimension and parent.orbitColumnWidth then
                    width = parent.orbitColumnWidth
                end
                child:SetWidth(math.max(width, 10))
            end
        end
    end

    ApplyAnchorPosition(child, parent, edge, padding, align, opts)

    if child.orbitPlugin then
        if child.orbitPlugin.UpdateLayout then
            child.orbitPlugin:UpdateLayout(child)
        elseif not suppressApplySettings and child.orbitPlugin.ApplySettings then
            local isEditMode = EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
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

        -- Restore borders and background insets if they were merged
        if oldAnchor.syncOptions and oldAnchor.syncOptions.mergeBorders then
            local p = oldAnchor.parent
            local c = child
            local e = oldAnchor.edge

            if e == "BOTTOM" then
                if p and p.SetBorderHidden then
                    p:SetBorderHidden("Bottom", false)
                end
                if c.SetBorderHidden then
                    c:SetBorderHidden("Top", false)
                end
                if c.SetBackgroundInset then
                    c:SetBackgroundInset("Top", 0)
                end
            elseif e == "TOP" then
                if p and p.SetBorderHidden then
                    p:SetBorderHidden("Top", false)
                end
                if c.SetBorderHidden then
                    c:SetBorderHidden("Bottom", false)
                end
                if c.SetBackgroundInset then
                    c:SetBackgroundInset("Bottom", 0)
                end
            elseif e == "LEFT" then
                if p and p.SetBorderHidden then
                    p:SetBorderHidden("Left", false)
                end
                if c.SetBorderHidden then
                    c:SetBorderHidden("Right", false)
                end
                if c.SetBackgroundInset then
                    c:SetBackgroundInset("Right", 0)
                end
            elseif e == "RIGHT" then
                if p and p.SetBorderHidden then
                    p:SetBorderHidden("Right", false)
                end
                if c.SetBorderHidden then
                    c:SetBorderHidden("Left", false)
                end
                if c.SetBackgroundInset then
                    c:SetBackgroundInset("Left", 0)
                end
            end
        end

        self.anchors[child] = nil

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

-- Centralized helper for setting frame disabled state
-- Automatically breaks anchor when disabled (frees up edge for other frames)
-- @param frame The frame to enable/disable
-- @param disabled true to disable, false to enable
function Anchor:SetFrameDisabled(frame, disabled)
    frame.orbitDisabled = disabled
    if disabled and self.anchors[frame] then
        self:BreakAnchor(frame, true)
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
    for child, anchor in pairs(self.anchors) do
        if anchor.parent == parent then
            table.insert(children, child)
        end
    end
    return children
end

-- Check if a specific edge of a parent frame is already occupied by an anchored child
-- @param parent The parent frame to check
-- @param edge The edge to check ("TOP", "BOTTOM", "LEFT", "RIGHT")
-- @param excludeChild Optional child to exclude from check (for re-anchoring same child)
-- @return true if edge is occupied, false otherwise
function Anchor:IsEdgeOccupied(parent, edge, excludeChild)
    for child, anchor in pairs(self.anchors) do
        if anchor.parent == parent and anchor.edge == edge then
            if excludeChild and child == excludeChild then
                -- Don't count the child we're re-anchoring
            elseif child.orbitDisabled then
                -- Don't count disabled children (they effectively release their slot)
            else
                return true
            end
        end
    end
    return false
end

function Anchor:SyncChildren(parent, suppressApplySettings, visited)
    if not parent or not parent.GetScale or not parent.GetWidth then
        return
    end

    -- Prevent infinite recursion with visited set
    visited = visited or {}
    if visited[parent] then
        return
    end
    visited[parent] = true

    local parentScale = parent:GetScale()
    local parentWidth = parent:GetWidth()
    local parentHeight = parent:GetHeight()

    -- Snapshot children to avoid modifying table during iteration
    local childrenToSync = {}
    for child, anchor in pairs(self.anchors) do
        if anchor.parent == parent then
            table.insert(childrenToSync, { child = child, anchor = anchor })
        end
    end

    local isEditMode = EditModeManagerFrame
        and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive()

    -- Fast Path: During Edit Mode, just reposition children without full ApplySettings cascade
    -- This prevents exponential performance cost when dragging linked chains
    if isEditMode and not InCombatLockdown() then
        for _, entry in ipairs(childrenToSync) do
            local child = entry.child
            local anchor = entry.anchor
            if not child:IsForbidden() then
                local opts = anchor.syncOptions or GetFrameOptions(child)

                if opts.syncScale then
                    child:SetScale(parentScale)
                end

                if opts.syncDimensions then
                    if anchor.edge == "LEFT" or anchor.edge == "RIGHT" then
                        local height = parentHeight
                        if opts.useRowDimension and parent.orbitRowHeight then
                            height = parent.orbitRowHeight
                        end
                        child:SetHeight(math.max(height, 5))
                    else
                        local width = parentWidth
                        if opts.useRowDimension and parent.orbitColumnWidth then
                            width = parent.orbitColumnWidth
                        end
                        child:SetWidth(math.max(width, 10))
                    end
                end

                -- Use helper instead of CreateAnchor to avoid recursion
                ApplyAnchorPosition(child, parent, anchor.edge, anchor.padding, anchor.align, opts)

                -- Call UpdateLayout for live icon recalculation in edit mode
                if child.orbitPlugin and child.orbitPlugin.UpdateLayout then
                    child.orbitPlugin:UpdateLayout(child)
                end

                -- Recursively update grandchildren using fast path (without full sync)
                self:SyncChildren(child, suppressApplySettings, visited)
            end
        end
        return
    end

    for _, entry in ipairs(childrenToSync) do
        local child = entry.child
        local anchor = entry.anchor
        if not child:IsForbidden() and (not InCombatLockdown() or not child:IsProtected()) then
            local opts = anchor.syncOptions or GetFrameOptions(child)

            if opts.syncScale then
                child:SetScale(parentScale)
            end

            if opts.syncDimensions then
                if anchor.edge == "LEFT" or anchor.edge == "RIGHT" then
                    local height = parentHeight
                    if opts.useRowDimension and parent.orbitRowHeight then
                        height = parent.orbitRowHeight
                    end
                    child:SetHeight(math.max(height, 5))
                else
                    local width = parentWidth
                    if opts.useRowDimension and parent.orbitColumnWidth then
                        width = parent.orbitColumnWidth
                    end
                    child:SetWidth(math.max(width, 10))
                end
            end

            -- Apply position update (was missing in normal path)
            ApplyAnchorPosition(child, parent, anchor.edge, anchor.padding, anchor.align, opts)

            if child.orbitPlugin then
                if child.orbitPlugin.UpdateLayout then
                    child.orbitPlugin:UpdateLayout(child)
                elseif not suppressApplySettings and child.orbitPlugin.ApplySettings then
                    child.orbitPlugin:ApplySettings(child)
                end
            end

            self:SyncChildren(child, suppressApplySettings, visited)
        end
    end
end

Anchor.GetFrameOptions = GetFrameOptions
Anchor.DEFAULT_OPTIONS = DEFAULT_OPTIONS
