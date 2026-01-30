---@type Orbit
local Orbit = Orbit

-- Shared helpers for PartyFrame and PartyFramePreview
-- Centralizes layout calculations to avoid DRY violations

Orbit.PartyFrameHelpers = {}
local Helpers = Orbit.PartyFrameHelpers

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
-- Shared constants for party frame layout (exported for use by other modules)
Helpers.LAYOUT = {
    MaxPartyFrames = 4,     -- party1-4 (party5 = player in 5-man)
    Spacing = 0,            -- Vertical spacing between frames (0 for merged borders)
    PowerBarRatio = 0.2,    -- 20% of frame height for power bar
    DefaultWidth = 160,
    DefaultHeight = 40,
    ElementGap = 4,         -- Gap between frame and attached elements
}

-- [ CONTAINER SIZING ]------------------------------------------------------------------------------

--- Calculate container size based on visible frames
-- @param numFrames number - number of visible frames
-- @param frameWidth number - width of each frame
-- @param frameHeight number - height of each frame
-- @param spacing number - spacing between frames
-- @param orientation number - 0 = vertical, 1 = horizontal
-- @param auraSpacing number - extra spacing for above/below aura containers (optional)
-- @return width number, height number
function Helpers:CalculateContainerSize(numFrames, frameWidth, frameHeight, spacing, orientation, auraSpacing)
    spacing = spacing or self.LAYOUT.Spacing
    orientation = orientation or 0
    auraSpacing = auraSpacing or 0
    
    if numFrames < 1 then
        numFrames = 1
    end
    
    -- Total effective spacing includes base spacing + aura container height
    local effectiveSpacing = spacing + auraSpacing
    
    if orientation == 0 then
        -- Vertical layout
        local totalHeight = (numFrames * frameHeight) + ((numFrames - 1) * effectiveSpacing)
        return frameWidth, totalHeight
    else
        -- Horizontal layout
        local totalWidth = (numFrames * frameWidth) + ((numFrames - 1) * effectiveSpacing)
        return totalWidth, frameHeight
    end
end

--- Calculate frame position within container
-- @param index number - 1-based frame index
-- @param frameWidth number - width of each frame
-- @param frameHeight number - height of each frame
-- @param spacing number - spacing between frames
-- @param orientation number - 0 = vertical, 1 = horizontal
-- @param auraSpacing number - extra spacing for above/below aura containers (optional)
-- @return xOffset number, yOffset number
function Helpers:CalculateFramePosition(index, frameWidth, frameHeight, spacing, orientation, auraSpacing)
    spacing = spacing or self.LAYOUT.Spacing
    orientation = orientation or 0
    auraSpacing = auraSpacing or 0
    
    -- Total effective spacing includes base spacing + aura container height
    local effectiveSpacing = spacing + auraSpacing
    local offset = (index - 1) * (orientation == 0 and (frameHeight + effectiveSpacing) or (frameWidth + effectiveSpacing))
    
    if orientation == 0 then
        -- Vertical: Stack downward
        return 0, -offset
    else
        -- Horizontal: Stack rightward
        return offset, 0
    end
end

-- [ POWER BAR LAYOUT ]------------------------------------------------------------------------------

--- Update frame layout to account for power bar visibility
-- Uses UnitFrameMixin:UpdateFrameLayout for consistent logic across all unit frames
-- @param frame Frame - the party frame
-- @param borderSize number - current border size
-- @param showPowerBar boolean - whether power bar is shown (default true)
function Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar)
    Orbit.UnitFrameMixin:UpdateFrameLayout(frame, borderSize, {
        showPowerBar = showPowerBar,
        powerBarRatio = self.LAYOUT.PowerBarRatio,
    })
end
