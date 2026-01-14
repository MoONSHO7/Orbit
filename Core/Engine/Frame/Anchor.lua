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
        local pSize = (parent.borderPixelSize or 1) -- fallback to 1 logic unit? or 0?
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
        elseif edge == "TOP" then
            if parent.SetBorderHidden then
                parent:SetBorderHidden("Top", true)
            end
            if child.SetBorderHidden then
                child:SetBorderHidden("Bottom", true)
            end
        elseif edge == "LEFT" then
            if parent.SetBorderHidden then
                parent:SetBorderHidden("Left", true)
            end
            if child.SetBorderHidden then
                child:SetBorderHidden("Right", true)
            end
        elseif edge == "RIGHT" then
            if parent.SetBorderHidden then
                parent:SetBorderHidden("Right", true)
            end
            if child.SetBorderHidden then
                child:SetBorderHidden("Left", true)
            end
        end
    else
        -- Not merged
        if syncOptions and syncOptions.mergeBorders then
            if edge == "BOTTOM" then
                if parent.SetBorderHidden then
                    parent:SetBorderHidden("Bottom", false)
                end
                if child.SetBorderHidden then
                    child:SetBorderHidden("Top", false)
                end
            elseif edge == "TOP" then
                if parent.SetBorderHidden then
                    parent:SetBorderHidden("Top", false)
                end
                if child.SetBorderHidden then
                    child:SetBorderHidden("Bottom", false)
                end
            elseif edge == "LEFT" then
                if parent.SetBorderHidden then
                    parent:SetBorderHidden("Left", false)
                end
                if child.SetBorderHidden then
                    child:SetBorderHidden("Right", false)
                end
            elseif edge == "RIGHT" then
                if parent.SetBorderHidden then
                    parent:SetBorderHidden("Right", false)
                end
                if child.SetBorderHidden then
                    child:SetBorderHidden("Left", false)
                end
            end
        end
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

function Anchor:CreateAnchor(child, parent, edge, padding, syncOptions, align, suppressApplySettings)
    if padding == nil then
        padding = DEFAULT_PADDING -- Default 4px gap
    end

    -- Prevent circular anchoring
    if self.anchors[parent] and self.anchors[parent].parent == child then
        return false
    end

    -- Prevent anchoring to an edge that's already occupied by another child
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
                child:SetHeight(height)
            else
                local width = parentWidth
                if opts.useRowDimension and parent.orbitColumnWidth then
                    width = parent.orbitColumnWidth
                end
                child:SetWidth(width)
            end
        end
    end

    ApplyAnchorPosition(child, parent, edge, padding, align, opts)

    if child.orbitPlugin then
        if child.orbitPlugin.UpdateLayout then
            child.orbitPlugin:UpdateLayout(child)
        elseif not suppressApplySettings and child.orbitPlugin.ApplySettings then
            if not (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then
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

        -- Restore borders if they were merged
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
            elseif e == "TOP" then
                if p and p.SetBorderHidden then
                    p:SetBorderHidden("Top", false)
                end
                if c.SetBorderHidden then
                    c:SetBorderHidden("Bottom", false)
                end
            elseif e == "LEFT" then
                if p and p.SetBorderHidden then
                    p:SetBorderHidden("Left", false)
                end
                if c.SetBorderHidden then
                    c:SetBorderHidden("Right", false)
                end
            elseif e == "RIGHT" then
                if p and p.SetBorderHidden then
                    p:SetBorderHidden("Right", false)
                end
                if c.SetBorderHidden then
                    c:SetBorderHidden("Left", false)
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

function Anchor:SyncChildren(parent, suppressApplySettings)
    if not parent or not parent.GetScale or not parent.GetWidth then
        return
    end

    local parentScale = parent:GetScale()
    local parentWidth = parent:GetWidth()
    local parentHeight = parent:GetHeight()

    -- Fast Path: During Edit Mode, just reposition children without full ApplySettings cascade
    -- This prevents exponential performance cost when dragging linked chains
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() and not InCombatLockdown() then
        for child, anchor in pairs(self.anchors) do
            if anchor.parent == parent then
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
                            child:SetHeight(height)
                        else
                            local width = parentWidth
                            if opts.useRowDimension and parent.orbitColumnWidth then
                                width = parent.orbitColumnWidth
                            end
                            child:SetWidth(width)
                        end
                    end

                    -- Use helper instead of CreateAnchor to avoid recursion
                    ApplyAnchorPosition(child, parent, anchor.edge, anchor.padding, anchor.align, opts)

                    -- Recursively update grandchildren using fast path (without full sync)
                    self:SyncChildren(child, suppressApplySettings)
                end
            end
        end
        return
    end

    for child, anchor in pairs(self.anchors) do
        if anchor.parent == parent then
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
                        child:SetHeight(height)
                    else
                        local width = parentWidth
                        if opts.useRowDimension and parent.orbitColumnWidth then
                            width = parent.orbitColumnWidth
                        end
                        child:SetWidth(width)
                    end
                end

                if child.orbitPlugin then
                    if child.orbitPlugin.UpdateLayout then
                        child.orbitPlugin:UpdateLayout(child)
                    elseif not suppressApplySettings and child.orbitPlugin.ApplySettings then
                        child.orbitPlugin:ApplySettings(child)
                    end
                end

                self:SyncChildren(child, suppressApplySettings)
            end
        end
    end
end

Anchor.GetFrameOptions = GetFrameOptions
Anchor.DEFAULT_OPTIONS = DEFAULT_OPTIONS
