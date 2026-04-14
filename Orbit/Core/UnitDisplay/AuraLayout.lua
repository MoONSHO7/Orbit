-- [ ORBIT AURA LAYOUT ]-----------------------------------------------------------------------------
local _, Orbit = ...
Orbit.AuraLayout = {}
local AL = Orbit.AuraLayout

local Pixel = Orbit.Engine.Pixel
local math_max = math.max

local SMART_AURA_SPACING = Orbit.Constants.GroupFrames.AuraSpacing
local SMART_MIN_ICON_SIZE = 10
local SMART_DEFAULT_ICON_SIZE = 10

function AL:LayoutGrid(frame, icons, config)
    config = config or {}
    local size = config.size or 20
    local sizeW = config.sizeW or size
    local spacing = config.spacing or 2
    local maxPerRow = config.maxPerRow or 8
    local anchor = config.anchor or "BOTTOMLEFT"
    local xOffset = config.xOffset or 0
    local yOffset = config.yOffset or 0
    local growthX = config.growthX or "RIGHT"
    local growthY = config.growthY or "DOWN"
    local numIcons = #icons
    local col = 0
    local currentY = yOffset
    local scale = frame:GetEffectiveScale()
    size = Pixel:Snap(size, scale)
    sizeW = Pixel:Snap(sizeW, scale)
    spacing = Pixel:Snap(spacing, scale)
    xOffset = Pixel:Snap(xOffset, scale)
    currentY = Pixel:Snap(currentY, scale)
    local isCenter = (growthX == "CENTER")
    local yAnchor = (growthY == "UP") and "BOTTOM" or "TOP"
    local xAnchor = isCenter and "" or ((growthX == "LEFT") and "RIGHT" or "LEFT")
    local iconPoint = yAnchor .. xAnchor
    local yStep = (growthY == "UP") and (size + spacing) or -(size + spacing)
    local xStep = isCenter and (sizeW + spacing) or ((growthX == "LEFT") and -(sizeW + spacing) or (sizeW + spacing))
    if growthY == "DOWN" and not config.yOffset then currentY = -4 end
    local function rowStartX(rowIdx)
        if not isCenter then return xOffset end
        local remaining = numIcons - (rowIdx * maxPerRow)
        local count = math.min(maxPerRow, math.max(0, remaining))
        return -((count - 1) * (sizeW + spacing)) / 2
    end
    local currentX = rowStartX(0)
    local rowIdx = 0
    for i, icon in ipairs(icons) do
        icon:ClearAllPoints()
        if col >= maxPerRow then col = 0; rowIdx = rowIdx + 1; currentY = currentY + yStep; currentX = rowStartX(rowIdx) end
        icon:SetPoint(iconPoint, frame, anchor, currentX, currentY)
        currentX = currentX + xStep
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
    container:SetSize(math_max(xOffset, 1), size)
end

function AL:CalculateSmartLayout(frameW, frameH, position, maxIcons, numIcons, overrides, scale)
    local isHorizontal = (position == "Above" or position == "Below")
    local maxRows = (overrides and overrides.MaxRows) or 2
    local rawSize = math_max(SMART_MIN_ICON_SIZE, (overrides and overrides.IconSize) or SMART_DEFAULT_ICON_SIZE)
    local iconSize = scale and Pixel:Multiple(rawSize, scale) or rawSize
    local spacing = scale and Pixel:Multiple(SMART_AURA_SPACING, scale) or SMART_AURA_SPACING
    local rows, iconsPerRow, containerWidth, containerHeight
    if isHorizontal then
        iconsPerRow = math_max(1, math.floor((frameW + spacing) / (iconSize + spacing)))
        if maxRows > 1 then iconsPerRow = math.min(iconsPerRow, math.ceil(maxIcons / maxRows)) end
        rows = math.min(maxRows, math.ceil(math_max(1, numIcons) / iconsPerRow))
        local displayCols = math.min(math.min(numIcons, iconsPerRow * rows), iconsPerRow)
        containerWidth = (displayCols * iconSize) + ((displayCols - 1) * spacing)
        containerHeight = (rows * iconSize) + ((rows - 1) * spacing)
    else
        local iconsPerCol = maxRows
        iconsPerRow = math.ceil(math_max(1, maxIcons) / iconsPerCol)
        local actualCols = math.ceil(math_max(1, numIcons) / iconsPerCol)
        local actualRows = math.min(iconsPerCol, numIcons)
        containerWidth = math_max(iconSize, (actualCols * iconSize) + ((actualCols - 1) * spacing))
        containerHeight = math_max(iconSize, (actualRows * iconSize) + ((actualRows - 1) * spacing))
        rows = actualRows
    end
    return iconSize, rows, iconsPerRow, containerWidth, containerHeight, not isHorizontal and maxRows or nil
end

function AL:PositionIcon(icon, container, justifyH, anchorY, col, row, iconSize, iconsPerRow, totalIcons, iconsPerCol)
    local scale = container:GetEffectiveScale() or 1
    local spacing = Pixel:Multiple(SMART_AURA_SPACING, scale)
    local xOff = Pixel:Snap(col * (iconSize + spacing), scale)
    local yOff = Pixel:Snap(row * (iconSize + spacing), scale)
    -- Vertical centering for partial columns on side positions
    if iconsPerCol and anchorY ~= "TOP" and anchorY ~= "BOTTOM" and totalIcons then
        local iconsInCol = math.min(iconsPerCol, totalIcons - (col * iconsPerCol))
        local colHeight = (iconsInCol * iconSize) + ((iconsInCol - 1) * spacing)
        local containerH = container:GetHeight()
        yOff = Pixel:Snap(yOff + (containerH - colHeight) / 2, scale)
    end
    icon:ClearAllPoints()
    local growDown = (anchorY ~= "BOTTOM")
    if justifyH == "CENTER" then
        local iconsInRow = totalIcons and math.min(iconsPerRow, totalIcons - (row * iconsPerRow)) or iconsPerRow
        local rowWidth = (iconsInRow * iconSize) + ((iconsInRow - 1) * spacing)
        local containerW = container:GetWidth()
        local centerOff = Pixel:Snap((containerW - rowWidth) / 2, scale)
        if growDown then icon:SetPoint("TOPLEFT", container, "TOPLEFT", centerOff + xOff, -yOff)
        else icon:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", centerOff + xOff, yOff) end
    elseif justifyH == "RIGHT" then
        if growDown then icon:SetPoint("TOPRIGHT", container, "TOPRIGHT", -xOff, -yOff)
        else icon:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -xOff, yOff) end
    else
        if growDown then icon:SetPoint("TOPLEFT", container, "TOPLEFT", xOff, -yOff)
        else icon:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOff, yOff) end
    end
    if iconsPerCol then
        local nextRow = row + 1
        local nextCol = col
        if nextRow >= iconsPerCol then nextRow = 0; nextCol = col + 1 end
        return nextCol, nextRow
    end
    local nextCol = col + 1
    local nextRow = row
    if nextCol >= iconsPerRow then nextCol = 0; nextRow = row + 1 end
    return nextCol, nextRow
end
