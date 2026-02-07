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
}

Helpers.GROWTH_DIRECTION = { Down = "Down", Up = "Up", Left = "Left", Right = "Right", Center = "Center" }

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
function Helpers:CalculateFramePosition(index, frameWidth, frameHeight, spacing, orientation, growthDirection, numFrames, auraSpacing)
    spacing = spacing or self.LAYOUT.Spacing
    orientation = orientation or 0
    growthDirection = growthDirection or (orientation == 0 and "Down" or "Right")
    auraSpacing = auraSpacing or 0
    local effectiveSpacing = spacing + auraSpacing
    local step = orientation == 0 and (frameHeight + effectiveSpacing) or (frameWidth + effectiveSpacing)
    local offset = (index - 1) * step

    if growthDirection == "Down" then
        return 0, -offset, "TOPLEFT", "TOPLEFT"
    elseif growthDirection == "Up" then
        return 0, offset, "BOTTOMLEFT", "BOTTOMLEFT"
    elseif growthDirection == "Right" then
        return offset, 0, "TOPLEFT", "TOPLEFT"
    elseif growthDirection == "Left" then
        return -offset, 0, "TOPRIGHT", "TOPRIGHT"
    else -- Center
        local totalSize = ((numFrames or 1) - 1) * step
        if orientation == 0 then
            local startY = totalSize / 2
            return 0, startY - offset, "LEFT", "LEFT"
        else
            local startX = -totalSize / 2
            return startX + offset, 0, "TOP", "TOP"
        end
    end
end

-- [ POWER BAR LAYOUT ]------------------------------------------------------------------------------
function Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar)
    Orbit.UnitFrameMixin:UpdateFrameLayout(frame, borderSize, { showPowerBar = showPowerBar, powerBarRatio = self.LAYOUT.PowerBarRatio })
end
