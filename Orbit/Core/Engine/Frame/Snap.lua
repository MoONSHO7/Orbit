-- [ ORBIT FRAME SNAP ]------------------------------------------------------------------------------
-- Handles snap-to-grid and snap-to-frame during drag operations

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameSnap = Engine.FrameSnap or {}
local Snap = Engine.FrameSnap

local SNAP_THRESHOLD = 5
local ANCHOR_THRESHOLD = 10
local CENTER_ALIGN_BONUS = 2

-- Main snap detection function
-- @param frame The frame being dragged
-- @param showGuides If true, show guide lines (during drag). If false, apply snap (on drop)
-- @param targets Array of potential snap targets
-- @param isLockedFn Function to check if a frame is locked
-- @return closestX, closestY, anchorTarget, anchorEdge
function Snap:DetectSnap(frame, showGuides, targets, isLockedFn)
    local threshold = SNAP_THRESHOLD
    local anchorThreshold = ANCHOR_THRESHOLD
    local fScale = frame:GetEffectiveScale()
    local left, top, right, bottom = frame:GetLeft(), frame:GetTop(), frame:GetRight(), frame:GetBottom()
    if not left or not fScale then
        return
    end

    -- Normalize to screen space
    left, top, right, bottom = left * fScale, top * fScale, right * fScale, bottom * fScale
    local centerX, centerY = (left + right) / 2, (top + bottom) / 2

    local closestX, closestY = nil, nil
    local minDiffX, minDiffY = threshold, threshold

    local closestAlignX, closestAlignY = nil, nil

    -- Anchor candidates (use separate threshold for anchors)
    local anchorCandidateX_Target, anchorCandidateX_Edge = nil, nil
    local anchorCandidateY_Target, anchorCandidateY_Edge = nil, nil
    local minDiffX_Anchor, minDiffY_Anchor = anchorThreshold, anchorThreshold

    -- Get frame options
    local opts = Engine.FrameAnchor.GetFrameOptions(frame)
    local canAnchorHorizontal = (opts.horizontal ~= false)
    local canAnchorVertical = (opts.vertical ~= false)
    local frameSyncDims = (opts.syncDimensions ~= false)

    for _, target in ipairs(targets) do
        -- Skip locked frames
        if isLockedFn and isLockedFn(target) then
            -- Skip
        else
            local tScale = target:GetEffectiveScale()
            local tLeft, tRight, tTop, tBottom = target:GetLeft(), target:GetRight(), target:GetTop(), target:GetBottom()

            if tLeft and tScale then
                tLeft, tRight, tTop, tBottom = tLeft * tScale, tRight * tScale, tTop * tScale, tBottom * tScale
                local tCenterX, tCenterY = (tLeft + tRight) / 2, (tTop + tBottom) / 2

                -- STRICT OVERLAP DETECTION
                -- Horizontal overlap: dragged frame's X range overlaps target's X range
                -- Required for TOP/BOTTOM anchoring (frame must be directly above/below)
                local horizontalOverlap = (right > tLeft and left < tRight)

                -- Vertical overlap: dragged frame's Y range overlaps target's Y range
                -- Required for LEFT/RIGHT anchoring (frame must be directly beside)
                local verticalOverlap = (top > tBottom and bottom < tTop)

                -- X Axis snap points (alignment only, no threshold modification)
                local snapPointsX = {
                    { diff = tLeft - left, pos = tLeft, align = "LEFT" },
                    { diff = tRight - right, pos = tRight, align = "RIGHT" },
                    { diff = tCenterX - centerX, pos = tCenterX, align = "CENTER" },
                }
                -- LEFT/RIGHT anchor points only if frames are at same Y level (verticalOverlap)
                if verticalOverlap then
                    if not Engine.FrameAnchor:IsEdgeOccupied(target, "LEFT", frame, frameSyncDims) then
                        table.insert(snapPointsX, { diff = tLeft - right, pos = tLeft, edge = "LEFT", target = target })
                    end
                    if not Engine.FrameAnchor:IsEdgeOccupied(target, "RIGHT", frame, frameSyncDims) then
                        table.insert(snapPointsX, { diff = tRight - left, pos = tRight, edge = "RIGHT", target = target })
                    end
                end

                for _, sp in ipairs(snapPointsX) do
                    local absDiff = math.abs(sp.diff)
                    local biasedDiff = (sp.align == "CENTER") and math.max(absDiff - CENTER_ALIGN_BONUS, 0) or absDiff

                    if biasedDiff < minDiffX then
                        minDiffX = biasedDiff
                        closestX = sp.diff
                        closestAlignX = sp.align or nil
                    end

                    if sp.edge and absDiff < minDiffX_Anchor then
                        anchorCandidateX_Target = sp.target
                        anchorCandidateX_Edge = sp.edge
                        minDiffX_Anchor = absDiff
                    end
                end

                -- Y Axis snap points (alignment only)
                local snapPointsY = {
                    { diff = tTop - top, pos = tTop, align = "TOP" },
                    { diff = tBottom - bottom, pos = tBottom, align = "BOTTOM" },
                    { diff = tCenterY - centerY, pos = tCenterY, align = "CENTER" },
                }
                if horizontalOverlap then
                    if not Engine.FrameAnchor:IsEdgeOccupied(target, "BOTTOM", frame, frameSyncDims) then
                        table.insert(snapPointsY, { diff = tBottom - top, pos = tBottom, edge = "BOTTOM", target = target })
                    end
                    if not Engine.FrameAnchor:IsEdgeOccupied(target, "TOP", frame, frameSyncDims) then
                        table.insert(snapPointsY, { diff = tTop - bottom, pos = tTop, edge = "TOP", target = target })
                    end
                end

                for _, sp in ipairs(snapPointsY) do
                    local absDiff = math.abs(sp.diff)
                    local biasedDiff = (sp.align == "CENTER") and math.max(absDiff - CENTER_ALIGN_BONUS, 0) or absDiff

                    if biasedDiff < minDiffY then
                        minDiffY = biasedDiff
                        closestY = sp.diff
                        closestAlignY = sp.align or nil
                    end

                    if sp.edge and absDiff < minDiffY_Anchor then
                        anchorCandidateY_Target = sp.target
                        anchorCandidateY_Edge = sp.edge
                        minDiffY_Anchor = absDiff
                    end
                end
            end
        end
    end

    -- Resolve final anchor (pick closest)
    local anchorTarget, anchorEdge, anchorAlign = nil, nil, nil

    if anchorCandidateX_Target and anchorCandidateY_Target then
        if minDiffX_Anchor < minDiffY_Anchor then
            anchorTarget = anchorCandidateX_Target
            anchorEdge = anchorCandidateX_Edge
            anchorAlign = closestAlignY -- X is Anchor (Side-by-side), Y determines alignment (Top/Bottom/Center)
        else
            anchorTarget = anchorCandidateY_Target
            anchorEdge = anchorCandidateY_Edge
            anchorAlign = closestAlignX -- Y is Anchor (Stacked), X determines alignment (Left/Right/Center)
        end
    elseif anchorCandidateX_Target then
        anchorTarget = anchorCandidateX_Target
        anchorEdge = anchorCandidateX_Edge
        anchorAlign = closestAlignY
    elseif anchorCandidateY_Target then
        anchorTarget = anchorCandidateY_Target
        anchorEdge = anchorCandidateY_Edge
        anchorAlign = closestAlignX
    end

    -- Default alignment if none detected
    -- Horizontal anchors (LEFT/RIGHT) default to TOP alignment
    -- Vertical anchors (TOP/BOTTOM) default to LEFT alignment
    if anchorTarget and not anchorAlign then
        if anchorEdge == "LEFT" or anchorEdge == "RIGHT" then
            anchorAlign = "TOP"
        else
            anchorAlign = "LEFT"
        end
    end

    -- Apply alignment override from anchorOptions if set
    if anchorTarget and opts.align then
        anchorAlign = opts.align
    end

    -- Filter anchor based on horizontal/vertical options
    -- horizontal = false disables LEFT/RIGHT edge anchoring (horizontal expansion)
    -- vertical = false disables TOP/BOTTOM edge anchoring (vertical stacking)
    if anchorTarget then
        if (anchorEdge == "LEFT" or anchorEdge == "RIGHT") and not canAnchorHorizontal then
            anchorTarget, anchorEdge, anchorAlign = nil, nil, nil
        elseif (anchorEdge == "TOP" or anchorEdge == "BOTTOM") and not canAnchorVertical then
            anchorTarget, anchorEdge, anchorAlign = nil, nil, nil
        end
    end

    -- Apply snap on drop
    if not showGuides and (closestX or closestY) then
        local l, b = frame:GetLeft(), frame:GetBottom()
        if closestX then
            local val = (closestX / fScale)
            if Engine.Pixel then
                val = Engine.Pixel:Snap(val, frame:GetEffectiveScale())
            end
            l = l + val
        end
        if closestY then
            local val = (closestY / fScale)
            if Engine.Pixel then
                val = Engine.Pixel:Snap(val, frame:GetEffectiveScale())
            end
            b = b + val
        end

        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
    end

    return closestX, closestY, anchorTarget, anchorEdge, anchorAlign
end

-- Normalize position to nearest anchor point
function Snap:NormalizePosition(frame)
    local parent = frame:GetParent()
    if not parent then
        return
    end

    local scale = frame:GetScale()
    if not scale then
        return
    end

    local left = frame:GetLeft() * scale
    local top = frame:GetTop() * scale
    local right = frame:GetRight() * scale
    local bottom = frame:GetBottom() * scale

    local parentWidth, parentHeight = parent:GetSize()
    local x, y, point

    -- Horizontal
    if left < (parentWidth - right) and left < math.abs((left + right) / 2 - parentWidth / 2) then
        x = left
        point = "LEFT"
    elseif (parentWidth - right) < math.abs((left + right) / 2 - parentWidth / 2) then
        x = right - parentWidth
        point = "RIGHT"
    else
        x = (left + right) / 2 - parentWidth / 2
        point = ""
    end

    -- Vertical
    if bottom < (parentHeight - top) and bottom < math.abs((bottom + top) / 2 - parentHeight / 2) then
        y = bottom
        point = "BOTTOM" .. point
    elseif (parentHeight - top) < math.abs((bottom + top) / 2 - parentHeight / 2) then
        y = top - parentHeight
        point = "TOP" .. point
    else
        y = (bottom + top) / 2 - parentHeight / 2
        point = "" .. point
    end

    if point == "" then
        point = "CENTER"
    end

    -- Snap to pixel grid
    if Engine.Pixel then
        local effectiveScale = frame:GetEffectiveScale()
        if effectiveScale then
            x = Engine.Pixel:Snap(x / scale, effectiveScale) * scale
            y = Engine.Pixel:Snap(y / scale, effectiveScale) * scale
        end
    end

    return point, x / scale, y / scale
end
