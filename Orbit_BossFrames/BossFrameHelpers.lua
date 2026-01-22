---@type Orbit
local Orbit = Orbit

-- Shared helpers for BossFrame and BossFramePreview
-- Centralizes layout calculations to avoid DRY violations

Orbit.BossFrameHelpers = {}
local Helpers = Orbit.BossFrameHelpers

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
-- Shared constants for boss frame layout (exported for use by other modules)
Helpers.LAYOUT = {
    Spacing = 2,            -- Space between debuff icons
    ElementGap = 4,         -- Gap between frame and attached elements (cast bar, debuffs)
    ContainerGap = 4,       -- Gap between frame edge and debuff container (left/right positions)
}

-- [ DEBUFF LAYOUT ]---------------------------------------------------------------------------------

--- Calculate icon size and step offset for debuff layout
-- @param isHorizontal boolean - true if debuffs are positioned Above/Below (horizontal layout)
-- @param frameWidth number - parent frame width
-- @param frameHeight number - parent frame height
-- @param maxDebuffs number - maximum number of debuff icons
-- @param spacing number - spacing between icons (optional, defaults to LAYOUT.Spacing)
-- @return iconSize number, xOffsetStep number
function Helpers:CalculateDebuffLayout(isHorizontal, frameWidth, frameHeight, maxDebuffs, spacing)
    spacing = spacing or self.LAYOUT.Spacing
    
    local iconSize, xOffsetStep
    
    if isHorizontal then
        -- Dynamic sizing: Fit columns within Frame Width
        -- Width = (N * Size) + ((N-1) * Spacing)
        -- Size = (Width - ((N-1) * Spacing)) / N
        local totalSpacing = (maxDebuffs - 1) * spacing
        iconSize = (frameWidth - totalSpacing) / maxDebuffs
        xOffsetStep = iconSize + spacing
    else
        -- Side positioning: Match Frame Height (legacy behavior)
        iconSize = frameHeight
        xOffsetStep = 0
    end
    
    return iconSize, xOffsetStep
end

--- Position a debuff container relative to its parent frame
-- @param container Frame - the debuff container frame
-- @param parent Frame - the parent unit frame
-- @param position string - "Left", "Right", "Above", or "Below"
-- @param numDebuffs number - number of debuffs to display
-- @param iconSize number - size of each icon
-- @param spacing number - spacing between icons
-- @param castBarPos string - position of cast bar ("Above" or "Below")
-- @param castBarHeight number - height of cast bar
function Helpers:PositionDebuffContainer(container, parent, position, numDebuffs, iconSize, spacing, castBarPos, castBarHeight)
    spacing = spacing or self.LAYOUT.Spacing
    local frameWidth = parent:GetWidth()
    local castBarGap = self.LAYOUT.ElementGap
    local elementGap = self.LAYOUT.ElementGap
    local containerGap = self.LAYOUT.ContainerGap
    
    container:ClearAllPoints()
    
    if position == "Left" then
        container:SetPoint("RIGHT", parent, "LEFT", -containerGap, 0)
        container:SetSize((numDebuffs * iconSize) + ((numDebuffs - 1) * spacing), iconSize)
    elseif position == "Right" then
        container:SetPoint("LEFT", parent, "RIGHT", containerGap, 0)
        container:SetSize((numDebuffs * iconSize) + ((numDebuffs - 1) * spacing), iconSize)
    elseif position == "Above" then
        local yOffset = elementGap
        if castBarPos == "Above" then
            yOffset = yOffset + castBarHeight + castBarGap
        end
        container:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, yOffset)
        container:SetSize(frameWidth, iconSize)
    elseif position == "Below" then
        local yOffset = -elementGap
        if castBarPos == "Below" then
            yOffset = yOffset - castBarHeight - castBarGap
        end
        container:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, yOffset)
        container:SetSize(frameWidth, iconSize)
    end
end

--- Position an individual icon within a debuff container
-- @param icon Frame - the icon frame to position
-- @param container Frame - the debuff container
-- @param isHorizontal boolean - true if horizontal layout
-- @param position string - "Left", "Right", "Above", or "Below"
-- @param currentX number - current X offset
-- @param iconSize number - size of the icon
-- @param xOffsetStep number - step for next icon (horizontal)
-- @param spacing number - spacing between icons
-- @return nextX number - next X offset for the following icon
function Helpers:PositionDebuffIcon(icon, container, isHorizontal, position, currentX, iconSize, xOffsetStep, spacing)
    spacing = spacing or self.LAYOUT.Spacing
    
    icon:ClearAllPoints()
    
    if isHorizontal then
        -- Grow Right
        icon:SetPoint("TOPLEFT", container, "TOPLEFT", currentX, 0)
        return currentX + xOffsetStep
    elseif position == "Left" then
        -- Grow Left: First icon at Right edge
        icon:SetPoint("TOPRIGHT", container, "TOPRIGHT", -currentX, 0)
        return currentX + iconSize + spacing
    else -- Right
        -- Grow Right: First icon at Left edge
        icon:SetPoint("TOPLEFT", container, "TOPLEFT", currentX, 0)
        return currentX + iconSize + spacing
    end
end
