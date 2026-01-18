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
    
    -- X axis: anchor to nearest horizontal edge
    if posX > 0 then
        anchorX = "RIGHT"
        offsetX = halfW - posX  -- distance from right edge (negative if outside)
        -- Inside: text grows LEFT (toward center), Outside: text grows RIGHT (away)
        justifyH = isOutsideRight and "LEFT" or "RIGHT"
    elseif posX < 0 then
        anchorX = "LEFT"
        offsetX = halfW + posX  -- distance from left edge (negative if outside)
        -- Inside: text grows RIGHT (toward center), Outside: text grows LEFT (away)
        justifyH = isOutsideLeft and "RIGHT" or "LEFT"
    else
        anchorX = "CENTER"
        offsetX = 0
        justifyH = "CENTER"
    end
    
    -- Y axis: anchor to nearest vertical edge
    if posY > 0 then
        anchorY = "TOP"
        offsetY = halfH - posY  -- distance from top edge
    elseif posY < 0 then
        anchorY = "BOTTOM"
        offsetY = halfH + posY  -- distance from bottom edge
    else
        anchorY = "CENTER"
        offsetY = 0
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
        return anchorY .. anchorX  -- e.g., "TOPLEFT", "BOTTOMRIGHT"
    end
end
