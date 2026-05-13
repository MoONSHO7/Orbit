-- [ ORBIT FRAME SNAP ]-------------------------------------------------------------------------------
-- Handles snap-to-grid and snap-to-frame during drag operations

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameSnap = Engine.FrameSnap or {}
local Snap = Engine.FrameSnap

local SNAP_THRESHOLD = 5
local ANCHOR_THRESHOLD = 10
local ALIGN_THIRD = 1 / 3

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

    local parentLeft, parentTop, parentRight, parentBottom = left, top, right, bottom
    local parentCenterX, parentCenterY = (parentLeft + parentRight) / 2, (parentTop + parentBottom) / 2
    local centerX, centerY = (left + right) / 2, (top + bottom) / 2

    local closestX, closestY = nil, nil
    local minDiffX, minDiffY = threshold, threshold

    -- Anchor candidates (use separate threshold for anchors)
    local anchorCandidateX_Target, anchorCandidateX_Edge, anchorCandidateX_CenterDist = nil, nil, nil
    local anchorCandidateY_Target, anchorCandidateY_Edge, anchorCandidateY_CenterDist = nil, nil, nil
    local minDiffX_Anchor, minDiffY_Anchor = anchorThreshold, anchorThreshold

    -- Get frame options
    local opts = Engine.FrameAnchor.GetFrameOptions(frame)
    local canAnchorHorizontal = (opts.horizontal ~= false)
    local canAnchorVertical = (opts.vertical ~= false)
    -- Per-axis cross-sync flags (for IsEdgeOccupied: frame syncs cross-of-T/B = width, cross-of-L/R = height).
    local syncsWidth  = Engine.Axis.SyncEnabled(frame, Engine.Axis.horizontal)
    local syncsHeight = Engine.Axis.SyncEnabled(frame, Engine.Axis.vertical)

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

                local horizontalOverlap = (parentRight > tLeft and parentLeft < tRight)
                local verticalOverlap   = (parentTop > tBottom and parentBottom < tTop)

                -- X axis: alignment snaps + L/R anchor candidates (only when vertically overlapping).
                local snapPointsX = {
                    { diff = tLeft - left, pos = tLeft, align = "LEFT" },
                    { diff = tRight - right, pos = tRight, align = "RIGHT" },
                    { diff = tCenterX - centerX, pos = tCenterX, align = "CENTER" },
                }
                if verticalOverlap then
                    if not Engine.FrameAnchor:IsEdgeOccupied(target, "LEFT", frame, syncsHeight) then
                        table.insert(snapPointsX, { diff = tLeft - right, pos = tLeft, edge = "LEFT", target = target })
                    end
                    if not Engine.FrameAnchor:IsEdgeOccupied(target, "RIGHT", frame, syncsHeight) then
                        table.insert(snapPointsX, { diff = tRight - left, pos = tRight, edge = "RIGHT", target = target })
                    end
                end

                for _, sp in ipairs(snapPointsX) do
                    local absDiff = math.abs(sp.diff)
                    if absDiff < minDiffX then
                        minDiffX = absDiff
                        closestX = sp.diff
                    end
                    if sp.edge and absDiff < minDiffX_Anchor then
                        anchorCandidateX_Target = sp.target
                        anchorCandidateX_Edge = sp.edge
                        minDiffX_Anchor = absDiff
                        anchorCandidateX_CenterDist = math.abs(tCenterY - centerY)
                    elseif sp.edge and absDiff == minDiffX_Anchor then
                        local dist = math.abs(tCenterY - centerY)
                        if dist < (anchorCandidateX_CenterDist or math.huge) then
                            anchorCandidateX_Target = sp.target
                            anchorCandidateX_Edge = sp.edge
                            anchorCandidateX_CenterDist = dist
                        end
                    end
                end

                -- Y axis: alignment snaps + T/B anchor candidates (only when horizontally overlapping).
                local snapPointsY = {
                    { diff = tTop - top, pos = tTop, align = "TOP" },
                    { diff = tBottom - bottom, pos = tBottom, align = "BOTTOM" },
                    { diff = tCenterY - centerY, pos = tCenterY, align = "CENTER" },
                }
                if horizontalOverlap then
                    if not Engine.FrameAnchor:IsEdgeOccupied(target, "BOTTOM", frame, syncsWidth) then
                        table.insert(snapPointsY, { diff = tBottom - top, pos = tBottom, edge = "BOTTOM", target = target })
                    end
                    if not Engine.FrameAnchor:IsEdgeOccupied(target, "TOP", frame, syncsWidth) then
                        table.insert(snapPointsY, { diff = tTop - bottom, pos = tTop, edge = "TOP", target = target })
                    end
                end

                for _, sp in ipairs(snapPointsY) do
                    local absDiff = math.abs(sp.diff)
                    if absDiff < minDiffY then
                        minDiffY = absDiff
                        closestY = sp.diff
                    end
                    if sp.edge and absDiff < minDiffY_Anchor then
                        anchorCandidateY_Target = sp.target
                        anchorCandidateY_Edge = sp.edge
                        minDiffY_Anchor = absDiff
                        anchorCandidateY_CenterDist = math.abs(tCenterX - centerX)
                    elseif sp.edge and absDiff == minDiffY_Anchor then
                        local dist = math.abs(tCenterX - centerX)
                        if dist < (anchorCandidateY_CenterDist or math.huge) then
                            anchorCandidateY_Target = sp.target
                            anchorCandidateY_Edge = sp.edge
                            anchorCandidateY_CenterDist = dist
                        end
                    end
                end
            end
        end
    end

    -- Per-axis Blizzard grid + UIParent edges. These correspond to the red magnetism preview lines.
    -- Frame-to-frame anchor candidates take priority: an axis with an anchor candidate is locked to
    -- the anchor and the grid/UIParent fallback is skipped on that axis. Where no anchor candidate
    -- exists, the grid/UIParent candidate (if within blizRange) wins over a tighter alignment match.
    if EditModeManagerFrame and EditModeManagerFrame:IsShown()
        and EditModeManagerFrame.IsSnapEnabled and EditModeManagerFrame:IsSnapEnabled() then
        local blizRange = (EditModeMagnetismManager and EditModeMagnetismManager.magnetismRange) or 8
        local uiScale = UIParent:GetEffectiveScale()
        local uiL = UIParent:GetLeft() * uiScale
        local uiR = (UIParent:GetLeft() + UIParent:GetWidth()) * uiScale
        local uiB = UIParent:GetBottom() * uiScale
        local uiT = (UIParent:GetBottom() + UIParent:GetHeight()) * uiScale
        local uiCX, uiCY = (uiL + uiR) / 2, (uiB + uiT) / 2
        local gridLines = EditModeMagnetismManager and EditModeMagnetismManager.magneticGridLines

        if not anchorCandidateX_Target then
            local bestX, bestXDiff = nil, blizRange + 1
            local function offerX(diff)
                local abs = math.abs(diff)
                if abs <= blizRange and abs < bestXDiff then
                    bestXDiff = abs
                    bestX = diff
                end
            end
            offerX(uiL - parentLeft)
            offerX(uiR - parentRight)
            offerX(uiCX - parentCenterX)
            if gridLines and gridLines.vertical then
                for _, offset in pairs(gridLines.vertical) do
                    local screenX = offset * uiScale
                    offerX(screenX - parentLeft)
                    offerX(screenX - parentRight)
                    offerX(screenX - parentCenterX)
                end
            end
            if bestX then
                closestX = bestX
            end
        end

        if not anchorCandidateY_Target then
            local bestY, bestYDiff = nil, blizRange + 1
            local function offerY(diff)
                local abs = math.abs(diff)
                if abs <= blizRange and abs < bestYDiff then
                    bestYDiff = abs
                    bestY = diff
                end
            end
            offerY(uiB - parentBottom)
            offerY(uiT - parentTop)
            offerY(uiCY - parentCenterY)
            if gridLines and gridLines.horizontal then
                for _, offset in pairs(gridLines.horizontal) do
                    local screenY = offset * uiScale
                    offerY(screenY - parentBottom)
                    offerY(screenY - parentTop)
                    offerY(screenY - parentCenterY)
                end
            end
            if bestY then
                closestY = bestY
            end
        end
    end

    -- Resolve final anchor (pick closest)
    local anchorTarget, anchorEdge, anchorAlign = nil, nil, nil

    if anchorCandidateX_Target and anchorCandidateY_Target then
        if minDiffX_Anchor < minDiffY_Anchor then
            anchorTarget = anchorCandidateX_Target
            anchorEdge = anchorCandidateX_Edge
        else
            anchorTarget = anchorCandidateY_Target
            anchorEdge = anchorCandidateY_Edge
        end
    elseif anchorCandidateX_Target then
        anchorTarget = anchorCandidateX_Target
        anchorEdge = anchorCandidateX_Edge
    elseif anchorCandidateY_Target then
        anchorTarget = anchorCandidateY_Target
        anchorEdge = anchorCandidateY_Edge
    end

    if anchorTarget then
        local tScale = anchorTarget:GetEffectiveScale()
        if anchorEdge == "LEFT" or anchorEdge == "RIGHT" then
            -- L/R anchor's align is on vertical axis: classify against target's own T/B edges.
            local alignBottom = anchorTarget:GetBottom() * tScale
            local alignTop    = anchorTarget:GetTop() * tScale
            local ratio = (alignTop - parentCenterY) / (alignTop - alignBottom)
            anchorAlign = (ratio < ALIGN_THIRD) and "TOP" or (ratio > (1 - ALIGN_THIRD)) and "BOTTOM" or "CENTER"
        else
            -- T/B anchor's align is on horizontal axis: classify against target's own L/R edges.
            local alignLeft  = anchorTarget:GetLeft() * tScale
            local alignRight = anchorTarget:GetRight() * tScale
            local ratio = (parentCenterX - alignLeft) / (alignRight - alignLeft)
            anchorAlign = (ratio < ALIGN_THIRD) and "LEFT" or (ratio > (1 - ALIGN_THIRD)) and "RIGHT" or "CENTER"
        end

        -- Align-slot fallback: only relevant for non-sync children (they share the edge via slots).
        -- Sync children fully occupy the edge and can't share.
        local edgeCrossSync = (anchorEdge == "LEFT" or anchorEdge == "RIGHT") and syncsHeight or syncsWidth
        if not edgeCrossSync then
            local isOccupied = Engine.FrameAnchor.IsEdgeOccupied
            local slots = (anchorEdge == "LEFT" or anchorEdge == "RIGHT") and { "TOP", "CENTER", "BOTTOM" } or { "LEFT", "CENTER", "RIGHT" }
            local preferred = anchorAlign
            local fallbackOrder = { preferred, slots[2] }
            for _, s in ipairs(slots) do
                if s ~= preferred and s ~= slots[2] then
                    fallbackOrder[3] = s
                end
            end
            local resolved = nil
            for _, candidate in ipairs(fallbackOrder) do
                if not isOccupied(Engine.FrameAnchor, anchorTarget, anchorEdge, frame, false, candidate) then
                    resolved = candidate
                    break
                end
            end
            if resolved then
                anchorAlign = resolved
            else
                anchorTarget, anchorEdge, anchorAlign = nil, nil, nil
            end
        end
    end

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

    -- Apply snap on drop. Snap the final L/B through Pixel:Snap (not the delta) so the frame edge
    -- lands on the exact pixel of the guideline even if the drag left the frame at a sub-pixel offset.
    if not showGuides and (closestX or closestY) then
        local effectiveScale = frame:GetEffectiveScale()
        local l, b = frame:GetLeft(), frame:GetBottom()
        if closestX then l = l + (closestX / fScale) end
        if closestY then b = b + (closestY / fScale) end
        if Engine.Pixel then
            l = Engine.Pixel:Snap(l, effectiveScale)
            b = Engine.Pixel:Snap(b, effectiveScale)
        end

        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
    end

    return closestX, closestY, anchorTarget, anchorEdge, anchorAlign
end

-- Normalize position to nearest anchor point
function Snap:NormalizePosition(frame)
    local parent = frame:GetParent()
    if not parent then return end

    local scale = frame:GetScale()
    local left, top, right, bottom = frame:GetLeft(), frame:GetTop(), frame:GetRight(), frame:GetBottom()
    if not scale or not left then return end

    left, top, right, bottom = left * scale, top * scale, right * scale, bottom * scale

    local parentWidth, parentHeight = parent:GetSize()
    local x, y, point

    if frame.orbitForceAnchorPoint then
        point = frame.orbitForceAnchorPoint
        local hasTop = point:find("TOP")
        local hasBottom = point:find("BOTTOM")
        local hasLeft = point:find("LEFT")
        local hasRight = point:find("RIGHT")
        x = hasLeft and left or hasRight and (right - parentWidth) or ((left + right) / 2 - parentWidth / 2)
        y = hasBottom and bottom or hasTop and (top - parentHeight) or ((bottom + top) / 2 - parentHeight / 2)
    else
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

        if point == "" then point = "CENTER" end
    end

    if Engine.Pixel then
        local effectiveScale = frame:GetEffectiveScale()
        if effectiveScale then
            local rawX, rawY = x / scale, y / scale
            rawX, rawY = Engine.Pixel:SnapPosition(rawX, rawY, point, frame:GetWidth(), frame:GetHeight(), effectiveScale)
            x = rawX * scale
            y = rawY * scale
        end
    end

    return point, x / scale, y / scale
end
