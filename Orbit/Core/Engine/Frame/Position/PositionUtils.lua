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

-- [ FONT STRING ANCHOR COMPENSATION ]---------------------------------------------------------------
function PositionUtils.CalculateAnchorWithWidthCompensation(posX, posY, halfW, halfH, needsWidthComp, compWidth)
    local anchorX, anchorY, offsetX, offsetY, justifyH = PositionUtils.CalculateAnchor(posX, posY, halfW, halfH)

    if not needsWidthComp or anchorX == "CENTER" then
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
function PositionUtils.ApplyTextPosition(element, parent, pos, defaultAnchor, defaultOffsetX, defaultOffsetY)
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

        -- Text anchor: use justifyH for horizontal alignment
        if pos.justifyH and pos.justifyH ~= "CENTER" and element.SetJustifyH then
            element:SetPoint(pos.justifyH, parent, anchorPoint, offsetX, offsetY)
        else
            element:SetPoint("CENTER", parent, anchorPoint, offsetX, offsetY)
        end
        return true
    end

    -- Center-relative fallback (posX/posY)
    if pos.posX ~= nil and pos.posY ~= nil then
        element:SetPoint("CENTER", parent, "CENTER", pos.posX, pos.posY)
        return true
    end

    -- Default positioning
    if defaultAnchor then
        element:SetPoint(defaultAnchor, parent, defaultAnchor, defaultOffsetX or 0, defaultOffsetY or 0)
        return true
    end

    return false
end
