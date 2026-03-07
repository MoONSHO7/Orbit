-- [ CANVAS MODE - AURA CREATOR ]--------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local AURA_SPACING = Orbit.Constants.GroupFrames.AuraSpacing
local AURA_MIN_ICON_SIZE = 10
local DEFAULT_MAX_ICONS = 3
local DEFAULT_MAX_ROWS = 2
local DEFAULT_PARENT_WIDTH = 200
local DEFAULT_PARENT_HEIGHT = 40
local GetSpellbookIcon = function() return Orbit.AuraPreview.GetSpellbookIcon() end

-- [ REFRESH LOGIC ]---------------------------------------------------------------------------------

local function RefreshAuraIcons(self)
    local AURA_BASE_ICON_SIZE = (Orbit.Constants.GroupFrames and Orbit.Constants.GroupFrames.AuraBaseIconSize) or AURA_MIN_ICON_SIZE
    local overrides = self.pendingOverrides or self.existingOverrides or {}
    local maxIcons = overrides.MaxIcons or DEFAULT_MAX_ICONS
    local maxRows = overrides.MaxRows or DEFAULT_MAX_ROWS
    local iconSize = math.max(AURA_MIN_ICON_SIZE, overrides.IconSize or AURA_BASE_ICON_SIZE)

    local preview = self:GetParent()
    local parentWidth = preview and (preview.sourceWidth or preview:GetWidth()) or DEFAULT_PARENT_WIDTH
    local parentHeight = preview and (preview.sourceHeight or preview:GetHeight()) or DEFAULT_PARENT_HEIGHT
    local position = OrbitEngine.PositionUtils.AnchorToPosition(self.posX, self.posY, parentWidth / 2, parentHeight / 2, "Right")
    local isHorizontal = (position == "Above" or position == "Below")

    local rows, iconsPerRow, containerWidth, containerHeight, iconsPerCol
    if isHorizontal then
        iconsPerRow = math.min(math.max(1, math.floor((parentWidth + AURA_SPACING) / (iconSize + AURA_SPACING))), maxIcons)
        if maxRows > 1 then iconsPerRow = math.min(iconsPerRow, math.ceil(maxIcons / maxRows)) end
        rows = math.min(maxRows, math.ceil(maxIcons / iconsPerRow))
        local displayCols = math.min(math.min(maxIcons, iconsPerRow * rows), iconsPerRow)
        containerWidth = (displayCols * iconSize) + ((displayCols - 1) * AURA_SPACING)
        containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
    else
        iconsPerCol = maxRows
        iconsPerRow = math.ceil(maxIcons / iconsPerCol)
        local actualCols = math.min(iconsPerRow, math.ceil(maxIcons / iconsPerCol))
        rows = math.min(iconsPerCol, maxIcons)
        containerWidth = math.max(iconSize, (actualCols * iconSize) + ((actualCols - 1) * AURA_SPACING))
        containerHeight = math.max(iconSize, (rows * iconSize) + ((rows - 1) * AURA_SPACING))
    end
    self:SetSize(containerWidth, containerHeight)

    for _, btn in ipairs(self.auraIconPool) do btn:Hide() end

    local scale = self:GetEffectiveScale() or 1
    local globalBorder = Orbit.db.GlobalSettings.BorderSize or Orbit.Engine.Pixel:DefaultBorderSize(scale)
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false }

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
        btn.Icon:SetTexture(GetSpellbookIcon())

        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons:ApplyCustom(btn, skinSettings)
            Orbit.Skin:SkinBorder(btn, btn, globalBorder)
        end

        btn:ClearAllPoints()
        local xOffset = col * (iconSize + AURA_SPACING)
        local yOffset = row * (iconSize + AURA_SPACING)
        local selfAY = self.selfAnchorY or self.anchorY
        local growDown = (selfAY ~= "BOTTOM")
        if iconsPerCol and selfAY ~= "TOP" and selfAY ~= "BOTTOM" then
            local iconsInCol = math.min(iconsPerCol, maxIcons - (col * iconsPerCol))
            local colHeight = (iconsInCol * iconSize) + ((iconsInCol - 1) * AURA_SPACING)
            yOffset = yOffset + (self:GetHeight() - colHeight) / 2
        end

        if self.justifyH == "CENTER" then
            local iconsInRow = math.min(iconsPerRow, maxIcons - (row * iconsPerRow))
            local rowWidth = (iconsInRow * iconSize) + ((iconsInRow - 1) * AURA_SPACING)
            local containerW = self:GetWidth()
            local centerOff = (containerW - rowWidth) / 2
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

-- [ CREATOR ]---------------------------------------------------------------------------------------

local function Create(container, preview, key, source, data)
    container.auraIconPool = {}
    container.RefreshAuraIcons = RefreshAuraIcons

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
