---@type Orbit
local Orbit = Orbit

Orbit.PartyFrameHelpers = {}
local Helpers = Orbit.PartyFrameHelpers

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
Helpers.LAYOUT = {
    MaxPartyFrames = 4,
    Spacing = 0,
    PowerBarRatio = 0.1,
    DefaultWidth = 160,
    DefaultHeight = 40,
    ElementGap = 4,
    AuraBaseIconSize = 25,
}

Helpers.GROWTH_DIRECTION = { Down = "Down", Up = "Up", Left = "Left", Right = "Right" }

-- Derive aura display position from canvas mode position data
-- Uses center-relative posX/posY + frame half-dimensions to determine
-- which edge the container is beyond (above/below takes priority over left/right
-- when the container is further outside vertically, and vice versa)
function Helpers:AnchorToPosition(posX, posY, halfW, halfH)
    if posX and posY and halfW and halfH then
        -- How far beyond each frame edge is the container center?
        local beyondX = math.max(0, math.abs(posX) - halfW)
        local beyondY = math.max(0, math.abs(posY) - halfH)

        if beyondY > beyondX then
            return posY > 0 and "Above" or "Below"
        elseif beyondX > beyondY then
            return posX > 0 and "Right" or "Left"
        end
        -- Neither is outside: use whichever axis is closer to edge
        if math.abs(posX) / math.max(halfW, 1) > math.abs(posY) / math.max(halfH, 1) then
            return posX > 0 and "Right" or "Left"
        else
            return posY > 0 and "Above" or "Below"
        end
    end
    -- Fallback: default right
    return "Right"
end

local CONTAINER_ANCHOR = { Down = "TOPLEFT", Up = "BOTTOMLEFT", Right = "TOPLEFT", Left = "TOPRIGHT" }

function Helpers:GetContainerAnchor(growthDirection) return CONTAINER_ANCHOR[growthDirection] or "TOPLEFT" end

-- [ CONTAINER SIZING ]------------------------------------------------------------------------------
function Helpers:CalculateContainerSize(numFrames, frameWidth, frameHeight, spacing, orientation, auraSpacing)
    spacing = spacing or self.LAYOUT.Spacing
    orientation = orientation or 0
    auraSpacing = auraSpacing or 0
    if numFrames < 1 then
        numFrames = 1
    end
    local effectiveSpacing = spacing + auraSpacing
    if orientation == 0 then
        return frameWidth, (numFrames * frameHeight) + ((numFrames - 1) * effectiveSpacing)
    else
        return (numFrames * frameWidth) + ((numFrames - 1) * effectiveSpacing), frameHeight
    end
end

-- [ FRAME POSITIONING ]-----------------------------------------------------------------------------
function Helpers:CalculateFramePosition(index, frameWidth, frameHeight, spacing, orientation, growthDirection)
    spacing = spacing or self.LAYOUT.Spacing
    orientation = orientation or 0
    growthDirection = growthDirection or (orientation == 0 and "Down" or "Right")
    local step = orientation == 0 and (frameHeight + spacing) or (frameWidth + spacing)
    local offset = (index - 1) * step

    if growthDirection == "Down" then
        return 0, -offset, "TOPLEFT", "TOPLEFT"
    elseif growthDirection == "Up" then
        return 0, offset, "BOTTOMLEFT", "BOTTOMLEFT"
    elseif growthDirection == "Right" then
        return offset, 0, "TOPLEFT", "TOPLEFT"
    else -- Left
        return -offset, 0, "TOPRIGHT", "TOPRIGHT"
    end
end

-- [ POWER BAR LAYOUT ]------------------------------------------------------------------------------
function Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar)
    Orbit.UnitFrameMixin:UpdateFrameLayout(frame, borderSize, { showPowerBar = showPowerBar, powerBarRatio = self.LAYOUT.PowerBarRatio })
end
