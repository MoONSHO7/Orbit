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
-- @return width number, height number
function Helpers:CalculateContainerSize(numFrames, frameWidth, frameHeight, spacing, orientation)
    spacing = spacing or self.LAYOUT.Spacing
    orientation = orientation or 0
    
    if numFrames < 1 then
        numFrames = 1
    end
    
    if orientation == 0 then
        -- Vertical layout
        local totalHeight = (numFrames * frameHeight) + ((numFrames - 1) * spacing)
        return frameWidth, totalHeight
    else
        -- Horizontal layout
        local totalWidth = (numFrames * frameWidth) + ((numFrames - 1) * spacing)
        return totalWidth, frameHeight
    end
end

-- [ FRAME LAYOUT ]----------------------------------------------------------------------------------

--- Calculate frame position within container
-- @param index number - 1-based frame index
-- @param frameWidth number - width of each frame
-- @param frameHeight number - height of each frame
-- @param spacing number - spacing between frames
-- @param orientation number - 0 = vertical, 1 = horizontal
-- @return xOffset number, yOffset number
function Helpers:CalculateFramePosition(index, frameWidth, frameHeight, spacing, orientation)
    spacing = spacing or self.LAYOUT.Spacing
    orientation = orientation or 0
    
    local offset = (index - 1) * (orientation == 0 and (frameHeight + spacing) or (frameWidth + spacing))
    
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
-- @param frame Frame - the party frame
-- @param borderSize number - current border size
-- @param showPowerBar boolean - whether power bar is shown (default true)
function Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar)
    local height = frame:GetHeight()
    if height < 1 then
        return
    end

    -- Default to showing power bar if not specified
    if showPowerBar == nil then
        showPowerBar = true
    end

    local powerHeight = showPowerBar and (height * self.LAYOUT.PowerBarRatio) or 0
    -- Use the actual pixel-scaled border size if available, otherwise the passed borderSize
    local inset = frame.borderPixelSize or borderSize or 0

    if frame.Power then
        if showPowerBar then
            frame.Power:ClearAllPoints()
            frame.Power:SetPoint("BOTTOMLEFT", inset, inset)
            frame.Power:SetPoint("BOTTOMRIGHT", -inset, inset)
            frame.Power:SetHeight(powerHeight)
            frame.Power:SetFrameLevel(frame:GetFrameLevel() + 3)
            frame.Power:Show()
        else
            frame.Power:Hide()
        end
    end

    if frame.Health then
        frame.Health:ClearAllPoints()
        frame.Health:SetPoint("TOPLEFT", inset, -inset)
        if showPowerBar then
            frame.Health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, powerHeight + inset)
        else
            -- Health bar fills entire frame when power bar hidden
            frame.Health:SetPoint("BOTTOMRIGHT", -inset, inset)
        end
        frame.Health:SetFrameLevel(frame:GetFrameLevel() + 2)

        if frame.HealthDamageBar then
            frame.HealthDamageBar:ClearAllPoints()
            frame.HealthDamageBar:SetAllPoints(frame.Health)
            frame.HealthDamageBar:SetFrameLevel(frame:GetFrameLevel() + 1)
        end
    end
end
