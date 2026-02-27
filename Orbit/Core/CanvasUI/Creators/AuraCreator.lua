-- [ CANVAS MODE - AURA CREATOR ]--------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local AURA_SPACING = 2
local AURA_MIN_ICON_SIZE = 10
local DEFAULT_MAX_ICONS = 3
local DEFAULT_MAX_ROWS = 2
local DEFAULT_PARENT_WIDTH = 200
local DEFAULT_PARENT_HEIGHT = 40

local SAMPLE_BUFF_ICONS = { 135936, 136051, 135994 }
local SAMPLE_DEBUFF_ICONS = { 132122, 136207, 135824 }

-- [ REFRESH LOGIC ]---------------------------------------------------------------------------------

local function RefreshAuraIcons(self)
    local AURA_BASE_ICON_SIZE = Orbit.PartyFrameHelpers and Orbit.PartyFrameHelpers.LAYOUT.AuraBaseIconSize or AURA_MIN_ICON_SIZE
    local overrides = self.pendingOverrides or self.existingOverrides or {}
    local maxIcons = overrides.MaxIcons or DEFAULT_MAX_ICONS
    local maxRows = overrides.MaxRows or DEFAULT_MAX_ROWS
    local iconSize = math.max(AURA_MIN_ICON_SIZE, overrides.IconSize or AURA_BASE_ICON_SIZE)

    local preview = self:GetParent()
    local parentWidth = preview and (preview.sourceWidth or preview:GetWidth()) or DEFAULT_PARENT_WIDTH
    local parentHeight = preview and (preview.sourceHeight or preview:GetHeight()) or DEFAULT_PARENT_HEIGHT
    local Helpers = Orbit.PartyFrameHelpers
    local position = Helpers and Helpers.AnchorToPosition and Helpers:AnchorToPosition(self.posX, self.posY, parentWidth / 2, parentHeight / 2) or "Right"
    local isHorizontal = (position == "Above" or position == "Below")

    local rows, iconsPerRow, containerWidth, containerHeight
    if isHorizontal then
        iconsPerRow = math.min(math.max(1, math.floor((parentWidth + AURA_SPACING) / (iconSize + AURA_SPACING))), maxIcons)
        rows = math.min(maxRows, math.ceil(maxIcons / iconsPerRow))
        local displayCols = math.min(math.min(maxIcons, iconsPerRow * rows), iconsPerRow)
        containerWidth = (displayCols * iconSize) + ((displayCols - 1) * AURA_SPACING)
        containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
    else
        rows = math.min(maxRows, math.max(1, maxIcons))
        iconsPerRow = math.ceil(maxIcons / rows)
        containerWidth = math.max(iconSize, (iconsPerRow * iconSize) + ((iconsPerRow - 1) * AURA_SPACING))
        containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
    end
    self:SetSize(containerWidth, containerHeight)

    for _, btn in ipairs(self.auraIconPool) do btn:Hide() end

    local scale = self:GetEffectiveScale() or 1
    local globalBorder = Orbit.db.GlobalSettings.BorderSize or Orbit.Engine.Pixel:Multiple(1, scale)
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false }
    local sampleIcons = self.sampleIcons

    local iconIndex = 0
    for i = 1, maxIcons do
        local col = (i - 1) % iconsPerRow
        local row = math.floor((i - 1) / iconsPerRow)
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
        btn.Icon:SetTexture(sampleIcons[((i - 1) % #sampleIcons) + 1])

        if Orbit.Skin and Orbit.Skin.Icons then Orbit.Skin.Icons:ApplyCustom(btn, skinSettings) end

        btn:ClearAllPoints()
        local xOffset = col * (iconSize + AURA_SPACING)
        local yOffset = row * (iconSize + AURA_SPACING)
        local growDown = (self.anchorY ~= "BOTTOM")

        if self.justifyH == "RIGHT" then
            local anchor = growDown and "TOPRIGHT" or "BOTTOMRIGHT"
            btn:SetPoint(anchor, self, anchor, -xOffset, growDown and -yOffset or yOffset)
        else
            local anchor = growDown and "TOPLEFT" or "BOTTOMLEFT"
            btn:SetPoint(anchor, self, anchor, xOffset, growDown and -yOffset or yOffset)
        end
        btn:Show()
    end
end

-- [ CREATOR ]---------------------------------------------------------------------------------------

local function Create(container, preview, key, source, data)
    container.auraIconPool = {}
    container.isAuraContainer = true
    container.sampleIcons = (key == "Buffs") and SAMPLE_BUFF_ICONS or SAMPLE_DEBUFF_ICONS
    container.RefreshAuraIcons = RefreshAuraIcons

    container.posX = (data and data.posX) or 0
    container.posY = (data and data.posY) or 0
    container.anchorX = data and data.anchorX
    container.anchorY = data and data.anchorY
    container.justifyH = data and data.justifyH
    container.existingOverrides = data and data.overrides
    container:RefreshAuraIcons()

    return container.auraIconPool[1]
end

CanvasMode:RegisterCreator("Aura", Create)
