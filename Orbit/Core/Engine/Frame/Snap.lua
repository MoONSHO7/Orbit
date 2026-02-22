-- [ ORBIT FRAME SNAP ]------------------------------------------------------------------------------
-- Handles snap-to-grid and snap-to-frame during drag operations

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameSnap = Engine.FrameSnap or {}
local Snap = Engine.FrameSnap

local SNAP_THRESHOLD = 5
local ANCHOR_THRESHOLD = 10
local ALIGN_THIRD = 1 / 3
local CHAIN_ALIGN_EDGE = 2 / 5

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

    local Anchor = Engine.FrameAnchor
    local chainChildren = Anchor:GetAnchoredDescendants(frame)
    for _, child in ipairs(chainChildren) do
        local cl, cb, cw, ch = child:GetRect()
        if cl then
            local cs = child:GetEffectiveScale()
            local cL, cR = cl * cs, (cl + cw) * cs
            local cB, cT = cb * cs, (cb + ch) * cs
            if cL < left then left = cL end
            if cR > right then right = cR end
            if cB < bottom then bottom = cB end
            if cT > top then top = cT end
        end
    end

    local centerX, centerY = (left + right) / 2, (top + bottom) / 2

    local closestX, closestY = nil, nil
    local minDiffX, minDiffY = threshold, threshold

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

                -- Check if target is part of a horizontal chain
                local chainLeft, chainRight, chainTop, chainBottom, chainRoot = Engine.FrameAnchor:GetHorizontalChainScreenBounds(target)
                local isChainMember = (chainLeft ~= nil)

                -- Horizontal overlap uses chain-wide bounds for chain members
                local tbLeft = isChainMember and chainLeft or tLeft
                local tbRight = isChainMember and chainRight or tRight
                local tbCenterX = (tbLeft + tbRight) / 2

                -- STRICT OVERLAP DETECTION
                -- Horizontal overlap uses chain bounds for chain members
                local horizontalOverlap = (right > tbLeft and left < tbRight)

                -- Vertical overlap: dragged frame's Y range overlaps target's Y range
                -- Required for LEFT/RIGHT anchoring (frame must be directly beside)
                local verticalOverlap = (top > tBottom and bottom < tTop)

                -- X Axis snap points (alignment only, no threshold modification)
                local snapPointsX = {
                    { diff = tLeft - left, pos = tLeft, align = "LEFT" },
                    { diff = tRight - right, pos = tRight, align = "RIGHT" },
                    { diff = tCenterX - centerX, pos = tCenterX, align = "CENTER" },
                }
                -- Also add chain-edge alignment snaps when applicable
                if isChainMember then
                    table.insert(snapPointsX, { diff = chainLeft - left, pos = chainLeft, align = "LEFT" })
                    table.insert(snapPointsX, { diff = chainRight - right, pos = chainRight, align = "RIGHT" })
                    table.insert(snapPointsX, { diff = tbCenterX - centerX, pos = tbCenterX, align = "CENTER" })
                end
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
                    if absDiff < minDiffX then
                        minDiffX = absDiff
                        closestX = sp.diff
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
                -- TOP/BOTTOM anchor points: for chain members, each frame emits
                -- using its OWN edge Y (so proximity works from any member) but
                -- targeting the chain root. Chain-wide horizontal overlap used for all.
                if horizontalOverlap then
                    local anchorTargetForTB = isChainMember and chainRoot or target
                    if not Engine.FrameAnchor:IsEdgeOccupied(anchorTargetForTB, "BOTTOM", frame, frameSyncDims) then
                        table.insert(snapPointsY, { diff = tBottom - top, pos = tBottom, edge = "BOTTOM", target = anchorTargetForTB })
                    end
                    if not Engine.FrameAnchor:IsEdgeOccupied(anchorTargetForTB, "TOP", frame, frameSyncDims) then
                        table.insert(snapPointsY, { diff = tTop - bottom, pos = tTop, edge = "TOP", target = anchorTargetForTB })
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
                        anchorCandidateY_CenterDist = math.abs(tbCenterX - centerX)
                    elseif sp.edge and absDiff == minDiffY_Anchor then
                        local dist = math.abs(tbCenterX - centerX)
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
            local tTop, tBottom = anchorTarget:GetTop() * tScale, anchorTarget:GetBottom() * tScale
            local ratio = (tTop - centerY) / (tTop - tBottom)
            anchorAlign = (ratio < ALIGN_THIRD) and "TOP" or (ratio > (1 - ALIGN_THIRD)) and "BOTTOM" or "CENTER"
        else
            local cL, cR = Engine.FrameAnchor:GetHorizontalChainScreenBounds(anchorTarget)
            local alignLeft = cL or (anchorTarget:GetLeft() * tScale)
            local alignRight = cR or (anchorTarget:GetRight() * tScale)
            local ratio = (centerX - alignLeft) / (alignRight - alignLeft)
            local edgeThreshold = cL and CHAIN_ALIGN_EDGE or ALIGN_THIRD
            anchorAlign = (ratio < edgeThreshold) and "LEFT" or (ratio > (1 - edgeThreshold)) and "RIGHT" or "CENTER"
        end

        if not frameSyncDims then
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
    if not parent then return end

    local scale = frame:GetScale()
    if not scale then return end

    local left = frame:GetLeft() * scale
    local top = frame:GetTop() * scale
    local right = frame:GetRight() * scale
    local bottom = frame:GetBottom() * scale

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
            
            if not point:match("LEFT") and not point:match("RIGHT") then
                local w = frame:GetWidth()
                x = Engine.Pixel:Snap(rawX - (w / 2), effectiveScale) + (w / 2)
            else
                x = Engine.Pixel:Snap(rawX, effectiveScale)
            end
            
            if not point:match("TOP") and not point:match("BOTTOM") then
                local h = frame:GetHeight()
                y = Engine.Pixel:Snap(rawY - (h / 2), effectiveScale) + (h / 2)
            else
                y = Engine.Pixel:Snap(rawY, effectiveScale)
            end
            x = x * scale
            y = y * scale
        end
    end

    return point, x / scale, y / scale
end
