---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local DEFAULT_WIDTH = 120
local DEFAULT_HEIGHT = 12
local DEFAULT_SPACING = 0
local RECHARGE_DIM = 0.35

-- [ HELPERS ]---------------------------------------------------------------------------------------
local function GetBarColor(plugin, sysIndex, index, maxCharges)
    local curveData = plugin:GetSetting(sysIndex, "BarColorCurve")
    if curveData then
        if index and maxCharges and maxCharges > 1 and #curveData.pins > 1 then
            return OrbitEngine.ColorCurve:SampleColorCurve(curveData, (index - 1) / (maxCharges - 1))
        end
        local c = OrbitEngine.ColorCurve:GetFirstColorFromCurve(curveData)
        if c then return c end
    end
    local _, class = UnitClass("player")
    return (Orbit.Colors.PlayerResources and Orbit.Colors.PlayerResources[class]) or { r = 1, g = 0.8, b = 0 }
end

local function GetBgColor()
    local gc = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BackdropColourCurve
    local c = gc and OrbitEngine.ColorCurve:GetFirstColorFromCurve(gc)
    return c or { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }
end

-- [ MODULE ]----------------------------------------------------------------------------------------
Orbit.ChargeBarCanvasPreview = {}
local Preview = Orbit.ChargeBarCanvasPreview

function Preview:Setup(plugin, frame, sysIndex)
    local LSM = LibStub("LibSharedMedia-3.0", true)

    frame.CreateCanvasPreview = function(self, options)
        local width = plugin:GetSetting(sysIndex, "Width") or DEFAULT_WIDTH
        local height = plugin:GetSetting(sysIndex, "Height") or DEFAULT_HEIGHT
        local borderSize = plugin:GetSetting(sysIndex, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(self:GetEffectiveScale() or 1)
        local spacing = plugin:GetSetting(sysIndex, "Spacing") or DEFAULT_SPACING
        local texture = plugin:GetSetting(sysIndex, "Texture")
        local bgColor = GetBgColor()
        local maxCharges = self.cachedMaxCharges or 3
        local previewCharges = maxCharges - 1
        local scale = self:GetEffectiveScale()

        local parent = options.parent
        local preview = CreateFrame("Frame", nil, parent)
        preview:SetSize(width, height)
        preview.sourceFrame = self
        preview.sourceWidth = width
        preview.sourceHeight = height
        preview.previewScale = 1
        preview.components = {}

        local logicalGap = OrbitEngine.Pixel:Multiple(spacing, scale)
        if spacing <= 1 then logicalGap = 0 end
        local exactWidth = (width - (logicalGap * (maxCharges - 1))) / maxCharges
        local snappedWidth = OrbitEngine.Pixel:Snap(exactWidth, scale)

        local currentLeft = 0

        for i = 1, maxCharges do
            local logicalLeft = OrbitEngine.Pixel:Snap(currentLeft, scale)

            local seg = CreateFrame("StatusBar", nil, preview)
            seg:SetSize(snappedWidth, height)
            seg:SetPoint("LEFT", preview, "LEFT", logicalLeft, 0)
            seg:SetMinMaxValues(0, 1)
            seg:SetValue(1)

            currentLeft = currentLeft + snappedWidth + logicalGap

            seg.bg = seg:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers.BackdropDeep)
            seg.bg:SetAllPoints()
            Orbit.Skin:ApplyGradientBackground(seg, Orbit.db.GlobalSettings.BackdropColourCurve, bgColor)

            local barColor = GetBarColor(plugin, sysIndex, i, maxCharges)
            local segColor = (i <= previewCharges) and barColor
                or { r = barColor.r * RECHARGE_DIM, g = barColor.g * RECHARGE_DIM, b = barColor.b * RECHARGE_DIM }
            Orbit.Skin:SkinStatusBar(seg, texture, segColor)
            if seg.Overlay then seg.Overlay:Hide() end

            local segBackdrop = Orbit.Skin:CreateBackdrop(seg, nil)
            segBackdrop:SetFrameLevel(seg:GetFrameLevel() + Constants.Levels.Highlight)
            segBackdrop:SetBackdrop(nil)
            Orbit.Skin:SkinBorder(seg, segBackdrop, borderSize, { r = 0, g = 0, b = 0, a = 1 })
        end

        local savedPositions = plugin:GetSetting(sysIndex, "ComponentPositions") or {}
        local fontName = plugin:GetSetting(sysIndex, "Font")
        local fontPath = LSM and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
        local fontSize = Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)
        local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7)
        fs:SetFont(fontPath, fontSize, Orbit.Skin:GetFontOutline())
        fs:SetText(tostring(previewCharges))
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

        local saved = savedPositions["ChargeCount"] or {}
        local data = {
            anchorX = saved.anchorX or "CENTER",
            anchorY = saved.anchorY or "CENTER",
            offsetX = saved.offsetX or 0,
            offsetY = saved.offsetY or 0,
            justifyH = saved.justifyH or "CENTER",
            overrides = saved.overrides,
        }

        local startX = saved.posX or 0
        local startY = saved.posY or 0

        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
        if CreateDraggableComponent then
            local comp = CreateDraggableComponent(preview, "ChargeCount", fs, startX, startY, data)
            if comp then
                comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                preview.components["ChargeCount"] = comp
                fs:Hide()
            end
        else
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
        end

        return preview
    end
end
