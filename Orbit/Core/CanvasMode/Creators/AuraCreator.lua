-- [ CANVAS MODE - AURA CREATOR ]---------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Pixel = OrbitEngine.Pixel

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local AURA_SPACING_RAW = Orbit.Constants.GroupFrames.AuraSpacing
local AURA_MIN_ICON_SIZE = 10
local DEFAULT_MAX_ICONS = 3
local DEFAULT_MAX_ROWS = 2
local DEFAULT_PARENT_WIDTH = 200
local DEFAULT_PARENT_HEIGHT = 40
local SKIN_SETTINGS = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = false }
local GetSpellbookIcon = function(auraType) return Orbit.AuraPreview.GetSpellbookIcon(auraType) end

-- [ REFRESH LOGIC ]----------------------------------------------------------------------------------
local function RefreshAuraIcons(self)
    local AURA_BASE_ICON_SIZE = (Orbit.Constants.GroupFrames and Orbit.Constants.GroupFrames.AuraBaseIconSize) or AURA_MIN_ICON_SIZE
    local overrides = self.pendingOverrides or self.existingOverrides or {}
    local maxIcons = overrides.MaxIcons or DEFAULT_MAX_ICONS
    local maxRows = overrides.MaxRows or DEFAULT_MAX_ROWS
    local rawSize = math.max(AURA_MIN_ICON_SIZE, overrides.IconSize or AURA_BASE_ICON_SIZE)
    local scale = UIParent:GetEffectiveScale() or 1
    local iconSize = Pixel:Multiple(rawSize, scale)
    local spacing = Pixel:Multiple(AURA_SPACING_RAW, scale)

    local preview = self:GetParent()
    local parentWidth = preview and (preview.sourceWidth or preview:GetWidth()) or DEFAULT_PARENT_WIDTH
    local parentHeight = preview and (preview.sourceHeight or preview:GetHeight()) or DEFAULT_PARENT_HEIGHT
    local position = OrbitEngine.PositionUtils.AnchorToPosition(self.posX, self.posY, parentWidth / 2, parentHeight / 2, "Right")
    local isHorizontal = (position == "Above" or position == "Below")

    local rows, iconsPerRow, containerWidth, containerHeight, iconsPerCol
    if isHorizontal then
        iconsPerRow = math.min(math.max(1, math.floor((parentWidth + spacing) / (iconSize + spacing))), maxIcons)
        if maxRows > 1 then iconsPerRow = math.min(iconsPerRow, math.ceil(maxIcons / maxRows)) end
        rows = math.min(maxRows, math.ceil(maxIcons / iconsPerRow))
        local displayCols = math.min(math.min(maxIcons, iconsPerRow * rows), iconsPerRow)
        containerWidth = (displayCols * iconSize) + ((displayCols - 1) * spacing)
        containerHeight = (rows * iconSize) + ((rows - 1) * spacing)
    else
        iconsPerCol = maxRows
        iconsPerRow = math.ceil(maxIcons / iconsPerCol)
        local actualCols = math.min(iconsPerRow, math.ceil(maxIcons / iconsPerCol))
        rows = math.min(iconsPerCol, maxIcons)
        containerWidth = math.max(iconSize, (actualCols * iconSize) + ((actualCols - 1) * spacing))
        containerHeight = math.max(iconSize, (rows * iconSize) + ((rows - 1) * spacing))
    end
    self:SetSize(Pixel:Snap(containerWidth, scale), Pixel:Snap(containerHeight, scale))

    for _, btn in ipairs(self.auraIconPool) do btn:Hide() end

    local iconIndex = 0
    local col, row = 0, 0
    for i = 1, maxIcons do
        if row >= rows then break end
        iconIndex = iconIndex + 1

        local btn = self.auraIconPool[iconIndex]
        if not btn then
            btn = CreateFrame("Button", nil, self, "BackdropTemplate")
            btn:EnableMouse(false)
            btn.Icon = btn:CreateTexture(nil, "ARTWORK")
            btn.Icon:SetAllPoints()
            btn.icon = btn.Icon
            self.auraIconPool[iconIndex] = btn
        end

        btn:SetSize(iconSize, iconSize)
        if not btn.Icon:GetTexture() then btn.Icon:SetTexture(GetSpellbookIcon(self.auraType)) end

        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons:ApplyCustom(btn, SKIN_SETTINGS)
        end

        btn:ClearAllPoints()
        local xOffset = col * (iconSize + spacing)
        local yOffset = row * (iconSize + spacing)
        local selfAY = self.selfAnchorY or self.anchorY
        local growDown = (selfAY ~= "BOTTOM")
        if iconsPerCol and selfAY ~= "TOP" and selfAY ~= "BOTTOM" then
            local iconsInCol = math.min(iconsPerCol, maxIcons - (col * iconsPerCol))
            local colHeight = (iconsInCol * iconSize) + ((iconsInCol - 1) * spacing)
            yOffset = Pixel:Snap(yOffset + (self:GetHeight() - colHeight) / 2, scale)
        end

        if self.justifyH == "CENTER" then
            local iconsInRow = math.min(iconsPerRow, maxIcons - (row * iconsPerRow))
            local rowWidth = (iconsInRow * iconSize) + ((iconsInRow - 1) * spacing)
            local containerW = self:GetWidth()
            local centerOff = Pixel:Snap((containerW - rowWidth) / 2, scale)
            local anchor = growDown and "TOPLEFT" or "BOTTOMLEFT"
            btn:SetPoint(anchor, self, anchor, centerOff + xOffset, growDown and -yOffset or yOffset)
        elseif self.justifyH == "RIGHT" then
            local anchor = growDown and "TOPRIGHT" or "BOTTOMRIGHT"
            btn:SetPoint(anchor, self, anchor, -xOffset, growDown and -yOffset or yOffset)
        else
            local anchor = growDown and "TOPLEFT" or "BOTTOMLEFT"
            btn:SetPoint(anchor, self, anchor, xOffset, growDown and -yOffset or yOffset)
        end
        btn:Show()
        if iconsPerCol then
            row = row + 1
            if row >= iconsPerCol then row = 0; col = col + 1 end
        else
            col = col + 1
            if col >= iconsPerRow then col = 0; row = row + 1 end
        end
    end
end

-- [ CREATOR ]----------------------------------------------------------------------------------------
local function Create(container, preview, key, source, data)
    container.auraIconPool = {}
    container.RefreshAuraIcons = RefreshAuraIcons

    container.auraType = (key == "Debuffs") and "debuff" or "buff"
    container.posX = (data and data.posX) or 0
    container.posY = (data and data.posY) or 0
    container.anchorX = data and data.anchorX
    container.anchorY = data and data.anchorY
    container.selfAnchorY = data and data.selfAnchorY
    container.justifyH = data and data.justifyH
    container.existingOverrides = data and data.overrides
    container:RefreshAuraIcons()

    return container.auraIconPool[1]
end

CanvasMode:RegisterCreator("Aura", Create)
