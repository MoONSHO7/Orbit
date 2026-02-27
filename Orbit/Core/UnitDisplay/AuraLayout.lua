-- [ ORBIT AURA LAYOUT ]-----------------------------------------------------------------------------
local _, Orbit = ...
Orbit.AuraLayout = {}
local AL = Orbit.AuraLayout

local Pixel = Orbit.Engine.Pixel
local math_max = math.max

local SMART_AURA_SPACING = 1
local SMART_MIN_ICON_SIZE = 10
local SMART_DEFAULT_ICON_SIZE = 10

function AL:LayoutGrid(frame, icons, config)
    config = config or {}
    local size = config.size or 20
    local spacing = config.spacing or 2
    local maxPerRow = config.maxPerRow or 8
    local anchor = config.anchor or "BOTTOMLEFT"
    local xOffset = config.xOffset or 0
    local yOffset = config.yOffset or 0
    local growthY = config.growthY or "DOWN"
    local col = 0
    local currentX = xOffset
    local currentY = yOffset
    local scale = frame:GetEffectiveScale()
    size = Pixel:Snap(size, scale)
    spacing = Pixel:Snap(spacing, scale)
    currentX = Pixel:Snap(currentX, scale)
    currentY = Pixel:Snap(currentY, scale)
    local iconPoint, yStep
    if growthY == "UP" then iconPoint = "BOTTOMLEFT"; yStep = size + spacing
    else
        iconPoint = "TOPLEFT"; yStep = -(size + spacing)
        if not config.yOffset then currentY = -4 end
    end
    for i, icon in ipairs(icons) do
        icon:ClearAllPoints()
        if col >= maxPerRow then col = 0; currentY = currentY + yStep; currentX = xOffset end
        icon:SetPoint(iconPoint, frame, anchor, currentX, currentY)
        currentX = currentX + size + spacing
        col = col + 1
    end
end

function AL:LayoutLinear(container, icons, config)
    config = config or {}
    local size = config.size or 20
    local spacing = config.spacing or 2
    local growDirection = config.growDirection or "RIGHT"
    local xOffset = 0
    local scale = container:GetEffectiveScale()
    size = Pixel:Snap(size, scale)
    spacing = Pixel:Snap(spacing, scale)
    for i, icon in ipairs(icons) do
        icon:ClearAllPoints()
        if growDirection == "LEFT" then icon:SetPoint("TOPRIGHT", container, "TOPRIGHT", -xOffset, 0)
        else icon:SetPoint("TOPLEFT", container, "TOPLEFT", xOffset, 0) end
        xOffset = xOffset + size + spacing
    end
    container:SetSize(xOffset > 0 and xOffset or 1, size)
end

function AL:CalculateSmartLayout(frameW, frameH, position, maxIcons, numIcons, overrides)
    local isHorizontal = (position == "Above" or position == "Below")
    local maxRows = (overrides and overrides.MaxRows) or 2
    local iconSize = math_max(SMART_MIN_ICON_SIZE, (overrides and overrides.IconSize) or SMART_DEFAULT_ICON_SIZE)
    local rows, iconsPerRow, containerWidth, containerHeight
    if isHorizontal then
        iconsPerRow = math_max(1, math.floor((frameW + SMART_AURA_SPACING) / (iconSize + SMART_AURA_SPACING)))
        rows = math.min(maxRows, math.ceil(numIcons / iconsPerRow))
        local displayCols = math.min(math.min(numIcons, iconsPerRow * rows), iconsPerRow)
        containerWidth = (displayCols * iconSize) + ((displayCols - 1) * SMART_AURA_SPACING)
        containerHeight = (rows * iconSize) + ((rows - 1) * SMART_AURA_SPACING)
    else
        rows = math.min(maxRows, math_max(1, numIcons))
        iconsPerRow = math.ceil(numIcons / rows)
        containerWidth = math_max(iconSize, (iconsPerRow * iconSize) + ((iconsPerRow - 1) * SMART_AURA_SPACING))
        containerHeight = (rows * iconSize) + ((rows - 1) * SMART_AURA_SPACING)
    end
    return iconSize, rows, iconsPerRow, containerWidth, containerHeight
end

function AL:PositionIcon(icon, container, justifyH, anchorY, col, row, iconSize, iconsPerRow)
    local xOff = col * (iconSize + SMART_AURA_SPACING)
    local yOff = row * (iconSize + SMART_AURA_SPACING)
    icon:ClearAllPoints()
    local growDown = (anchorY ~= "BOTTOM")
    if justifyH == "RIGHT" then
        if growDown then icon:SetPoint("TOPRIGHT", container, "TOPRIGHT", -xOff, -yOff)
        else icon:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -xOff, yOff) end
    else
        if growDown then icon:SetPoint("TOPLEFT", container, "TOPLEFT", xOff, -yOff)
        else icon:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOff, yOff) end
    end
    local nextCol = col + 1
    local nextRow = row
    if nextCol >= iconsPerRow then nextCol = 0; nextRow = row + 1 end
    return nextCol, nextRow
end
