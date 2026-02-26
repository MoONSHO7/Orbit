-- [ ORBIT POSITION UTILITIES ]----------------------------------------------------------------------
-- Shared position calculation functions for anchor, offset, and alignment calculations.
-- Used by CanvasModeDialog, ComponentDrag, and UnitButton.

local _, Orbit = ...
local Engine = Orbit.Engine

local PositionUtils = {}
Engine.PositionUtils = PositionUtils

-------------------------------------------------
-- ANCHOR CALCULATION
-------------------------------------------------

-- Threshold for snapping to CENTER anchor (in pixels)
-- When position is within this range of the center line, anchor to CENTER
local CENTER_THRESHOLD = 5

-- Calculate anchor type, edge offsets, and justifyH based on center-relative position
-- @param posX: X position relative to parent center (positive = right)
-- @param posY: Y position relative to parent center (positive = up)
-- @param halfW: Half width of parent frame
-- @param halfH: Half height of parent frame
-- @return anchorX, anchorY, offsetX, offsetY, justifyH
function PositionUtils.CalculateAnchor(posX, posY, halfW, halfH)
    local anchorX, offsetX, justifyH
    local anchorY, offsetY
    local isOutsideRight = posX > halfW
    local isOutsideLeft = posX < -halfW

    -- X axis: snap to CENTER if within threshold, otherwise anchor to nearest edge
    if math.abs(posX) <= CENTER_THRESHOLD then
        anchorX = "CENTER"
        offsetX = 0
        justifyH = "CENTER"
    elseif posX > 0 then
        anchorX = "RIGHT"
        offsetX = halfW - posX -- distance from right edge (negative if outside)
        -- Inside: text grows LEFT (toward center), Outside: text grows RIGHT (away)
        justifyH = isOutsideRight and "LEFT" or "RIGHT"
    else
        anchorX = "LEFT"
        offsetX = halfW + posX -- distance from left edge (negative if outside)
        -- Inside: text grows RIGHT (toward center), Outside: text grows LEFT (away)
        justifyH = isOutsideLeft and "RIGHT" or "LEFT"
    end

    -- Y axis: snap to CENTER if within threshold, otherwise anchor to nearest edge
    if math.abs(posY) <= CENTER_THRESHOLD then
        anchorY = "CENTER"
        offsetY = 0
    elseif posY > 0 then
        anchorY = "TOP"
        offsetY = halfH - posY -- distance from top edge
    else
        anchorY = "BOTTOM"
        offsetY = halfH + posY -- distance from bottom edge
    end

    return anchorX, anchorY, offsetX, offsetY, justifyH
end

-- Inverse of CalculateAnchor: convert anchor-based offsets back to center-relative coordinates
function PositionUtils.AnchorToCenter(anchorX, anchorY, offsetX, offsetY, halfW, halfH)
    local centerX, centerY = 0, 0
    if anchorX == "LEFT" then centerX = (offsetX or 0) - halfW
    elseif anchorX == "RIGHT" then centerX = halfW - (offsetX or 0) end
    if anchorY == "BOTTOM" then centerY = (offsetY or 0) - halfH
    elseif anchorY == "TOP" then centerY = halfH - (offsetY or 0) end
    return centerX, centerY
end

-------------------------------------------------
-- ANCHOR POINT BUILDER
-------------------------------------------------

-- Build anchor point string from anchorX and anchorY components
-- @param anchorX: "LEFT", "CENTER", or "RIGHT"
-- @param anchorY: "TOP", "CENTER", or "BOTTOM"
-- @return anchor point string (e.g., "TOPLEFT", "CENTER", "RIGHT")
function PositionUtils.BuildAnchorPoint(anchorX, anchorY)
    if anchorY == "CENTER" and anchorX == "CENTER" then
        return "CENTER"
    elseif anchorY == "CENTER" then
        return anchorX
    elseif anchorX == "CENTER" then
        return anchorY
    else
        return anchorY .. anchorX
    end
end

-- Build the self-anchor for SetPoint based on component type.
-- Text: uses justifyH only (horizontal edge, vertically centered)
-- Aura containers: uses justifyH + anchorY (both edges)
-- Other: CENTER
function PositionUtils.BuildComponentSelfAnchor(isFontString, isAuraContainer, anchorY, justifyH)
    if not justifyH or justifyH == "CENTER" then
        return "CENTER"
    end
    if isFontString then
        return justifyH
    end
    if isAuraContainer then
        return PositionUtils.BuildAnchorPoint(justifyH, anchorY)
    end
    return "CENTER"
end

-- Whether a component needs edge-relative offset compensation (width and optionally height)
function PositionUtils.NeedsEdgeCompensation(isFontString, isAuraContainer) return isFontString or isAuraContainer end

-- [ EDGE COMPENSATION ]-----------------------------------------------------------------------------
function PositionUtils.CalculateAnchorWithWidthCompensation(posX, posY, halfW, halfH, needsWidthComp, compWidth, compHeight, isAuraContainer)
    local anchorX, anchorY, offsetX, offsetY, justifyH = PositionUtils.CalculateAnchor(posX, posY, halfW, halfH)

    if not needsWidthComp then
        return anchorX, anchorY, offsetX, offsetY, justifyH
    end

    local compHalfW = (compWidth or 0) / 2
    local isOutsideLeft = posX < -halfW
    local isOutsideRight = posX > halfW

    if anchorX == "LEFT" then
        justifyH = isOutsideLeft and "RIGHT" or "LEFT"
        local widthComp = isOutsideLeft and compHalfW or -compHalfW
        offsetX = posX + halfW + widthComp
    elseif anchorX == "RIGHT" then
        justifyH = isOutsideRight and "LEFT" or "RIGHT"
        local widthComp = isOutsideRight and compHalfW or -compHalfW
        offsetX = halfW - posX + widthComp
    end

    if isAuraContainer and anchorY ~= "CENTER" then
        local compHalfH = (compHeight or 0) / 2
        local isOutsideTop = posY > halfH
        local isOutsideBottom = posY < -halfH
        if anchorY == "TOP" then
            local heightComp = isOutsideTop and compHalfH or -compHalfH
            offsetY = halfH - posY + heightComp
        elseif anchorY == "BOTTOM" then
            local heightComp = isOutsideBottom and compHalfH or -compHalfH
            offsetY = posY + halfH + heightComp
        end
    end

    return anchorX, anchorY, offsetX, offsetY, justifyH
end

-- [ APPLY TEXT POSITION ]--------------------------------------------------------------------------

-- Apply saved position data to a text element (FontString or Frame)
-- Handles anchor-based positioning with justifyH support for text alignment
-- @param element: The FontString or Frame to position
-- @param parent: The parent frame to anchor to
-- @param pos: Position data table { anchorX, anchorY, offsetX, offsetY, justifyH, posX, posY }
-- @param defaultAnchor: (optional) Default anchor point string if no pos data
-- @param defaultOffsetX: (optional) Default X offset if no pos data
-- @param defaultOffsetY: (optional) Default Y offset if no pos data
-- @return true if position was applied, false otherwise
function PositionUtils.ApplyTextPosition(element, parent, pos, defaultAnchor, defaultOffsetX, defaultOffsetY, isAuraContainer)
    if not element or not parent then
        return false
    end

    pos = pos or {}

    -- Apply justifyH if element supports it
    if pos.justifyH and element.SetJustifyH then
        element:SetJustifyH(pos.justifyH)
    end

    element:ClearAllPoints()

    -- Anchor-based positioning (preferred)
    if pos.anchorX then
        local anchorPoint = PositionUtils.BuildAnchorPoint(pos.anchorX, pos.anchorY or "CENTER")

        -- Calculate offset signs (positive = inward)
        local offsetX = pos.offsetX or 0
        local offsetY = pos.offsetY or 0
        if pos.anchorX == "RIGHT" then
            offsetX = -offsetX
        end
        if pos.anchorY == "TOP" then
            offsetY = -offsetY
        end

        local selfAnchor
        if isAuraContainer then
            selfAnchor = PositionUtils.BuildComponentSelfAnchor(false, true, pos.anchorY, pos.justifyH)
        elseif pos.justifyH and pos.justifyH ~= "CENTER" and element.SetJustifyH then
            selfAnchor = pos.justifyH
        else
            selfAnchor = "CENTER"
        end
        element:SetPoint(selfAnchor, parent, anchorPoint, offsetX, offsetY)
        return true
    end

    -- Center-relative fallback (posX/posY)
    if pos.posX ~= nil and pos.posY ~= nil then
        local scale = parent:GetEffectiveScale()
        element:SetPoint("CENTER", parent, "CENTER", Orbit.Engine.Pixel:Snap(pos.posX, scale), Orbit.Engine.Pixel:Snap(pos.posY, scale))
        return true
    end

    -- Default positioning
    if defaultAnchor then
        element:SetPoint(defaultAnchor, parent, defaultAnchor, defaultOffsetX or 0, defaultOffsetY or 0)
        return true
    end

    return false
end

-- [ ANCHOR TO POSITION ]----------------------------------------------------------------------------

function PositionUtils.AnchorToPosition(posX, posY, halfW, halfH, defaultPosition)
    if posX and posY and halfW and halfH then
        local beyondX = math.max(0, math.abs(posX) - halfW)
        local beyondY = math.max(0, math.abs(posY) - halfH)
        if beyondY > beyondX then return posY > 0 and "Above" or "Below"
        elseif beyondX > beyondY then return posX > 0 and "Right" or "Left" end
        if math.abs(posX) / math.max(halfW, 1) > math.abs(posY) / math.max(halfH, 1) then return posX > 0 and "Right" or "Left"
        else return posY > 0 and "Above" or "Below" end
    end
    return defaultPosition or "Right"
end

-- [ APPLY ICON POSITION ]---------------------------------------------------------------------------

function PositionUtils.ApplyIconPosition(icon, parentFrame, pos)
    if not pos or not pos.anchorX then return end
    local anchorPoint = PositionUtils.BuildAnchorPoint(pos.anchorX, pos.anchorY or "CENTER")
    local finalX = pos.offsetX or 0
    local finalY = pos.offsetY or 0
    if pos.anchorX == "RIGHT" then finalX = -finalX end
    if pos.anchorY == "TOP" then finalY = -finalY end
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", parentFrame, anchorPoint, finalX, finalY)
end
