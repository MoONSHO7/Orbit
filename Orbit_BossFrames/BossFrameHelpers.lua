---@type Orbit
local Orbit = Orbit

-- Shared helpers for BossFrame and BossFramePreview
Orbit.BossFrameHelpers = {}
local Helpers = Orbit.BossFrameHelpers
Helpers.LAYOUT = {
    Spacing = 2, -- Space between debuff icons
    ElementGap = 2, -- Gap between frame and attached elements (cast bar, debuffs)
    ContainerGap = 2, -- Gap between frame edge and debuff container (left/right positions)
}

-- [ DEBUFF LAYOUT ]

-- Calculate icon size and step offset for debuff layout
function Helpers:CalculateDebuffLayout(isHorizontal, frameWidth, frameHeight, maxDebuffs, spacing)
    spacing = spacing or self.LAYOUT.Spacing
    local iconSize, xOffsetStep
    if isHorizontal then
        local totalSpacing = (maxDebuffs - 1) * spacing
        iconSize = (frameWidth - totalSpacing) / maxDebuffs
        xOffsetStep = iconSize + spacing
    else
        iconSize, xOffsetStep = frameHeight, 0
    end
    return iconSize, xOffsetStep
end

-- Position a debuff container relative to its parent frame
function Helpers:PositionDebuffContainer(container, parent, position, numDebuffs, iconSize, spacing, castBarPos, castBarHeight)
    spacing = spacing or self.LAYOUT.Spacing
    local frameWidth, castBarGap = parent:GetWidth(), self.LAYOUT.ElementGap
    local elementGap, containerGap = self.LAYOUT.ElementGap, self.LAYOUT.ContainerGap
    container:ClearAllPoints()

    if position == "Left" then
        container:SetPoint("RIGHT", parent, "LEFT", -containerGap, 0)
        container:SetSize(Orbit.Engine.Pixel:Snap((numDebuffs * iconSize) + ((numDebuffs - 1) * spacing), parent:GetEffectiveScale()), Orbit.Engine.Pixel:Snap(iconSize, parent:GetEffectiveScale()))
    elseif position == "Right" then
        container:SetPoint("LEFT", parent, "RIGHT", containerGap, 0)
        container:SetSize(Orbit.Engine.Pixel:Snap((numDebuffs * iconSize) + ((numDebuffs - 1) * spacing), parent:GetEffectiveScale()), Orbit.Engine.Pixel:Snap(iconSize, parent:GetEffectiveScale()))
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

-- Position an individual icon within a debuff container
function Helpers:PositionDebuffIcon(icon, container, isHorizontal, position, currentX, iconSize, xOffsetStep, spacing)
    spacing = spacing or self.LAYOUT.Spacing
    icon:ClearAllPoints()
    if isHorizontal then
        icon:SetPoint("TOPLEFT", container, "TOPLEFT", currentX, 0)
        return currentX + xOffsetStep
    elseif position == "Left" then
        icon:SetPoint("TOPRIGHT", container, "TOPRIGHT", -currentX, 0)
        return currentX + iconSize + spacing
    else
        icon:SetPoint("TOPLEFT", container, "TOPLEFT", currentX, 0)
        return currentX + iconSize + spacing
    end
end
