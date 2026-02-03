---@type Orbit
local Orbit = Orbit

Orbit.PartyFrameHelpers = {}
local Helpers = Orbit.PartyFrameHelpers

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
Helpers.LAYOUT = {
    MaxPartyFrames = 4,
    Spacing = 0,
    PowerBarRatio = 0.2,
    DefaultWidth = 160,
    DefaultHeight = 40,
    ElementGap = 4,
}

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

function Helpers:CalculateFramePosition(index, frameWidth, frameHeight, spacing, orientation, auraSpacing)
    spacing = spacing or self.LAYOUT.Spacing
    orientation = orientation or 0
    auraSpacing = auraSpacing or 0
    local effectiveSpacing = spacing + auraSpacing
    local offset = (index - 1) * (orientation == 0 and (frameHeight + effectiveSpacing) or (frameWidth + effectiveSpacing))
    return orientation == 0 and 0 or offset, orientation == 0 and -offset or 0
end

-- [ POWER BAR LAYOUT ]------------------------------------------------------------------------------
function Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar)
    Orbit.UnitFrameMixin:UpdateFrameLayout(frame, borderSize, { showPowerBar = showPowerBar, powerBarRatio = self.LAYOUT.PowerBarRatio })
end
