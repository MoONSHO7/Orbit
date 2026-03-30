---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ] ---------------------------------------------------------------
local DEFAULT_WIDTH = 120
local DEFAULT_HEIGHT = 12
local RECHARGE_DIM = 0.35

-- [ HELPERS ] -----------------------------------------------------------------
local function GetBarColor(plugin, sysIndex)
    local curveData = plugin:GetSetting(sysIndex, "BarColorCurve")
    if curveData then
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

-- [ MODULE ] ------------------------------------------------------------------
Orbit.TrackedBarCanvasPreview = {}
local Preview = Orbit.TrackedBarCanvasPreview

function Preview:Setup(plugin, frame, sysIndex)
    local LSM = LibStub("LibSharedMedia-3.0", true)

    frame.CreateCanvasPreview = function(self, options)
        local width = plugin:GetSetting(sysIndex, "Width") or DEFAULT_WIDTH
        local height = plugin:GetSetting(sysIndex, "Height") or DEFAULT_HEIGHT
        local borderSize = plugin:GetSetting(sysIndex, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(self:GetEffectiveScale() or 1)
        local dividerSize = plugin:GetSetting(sysIndex, "DividerSize") or plugin:GetSetting(sysIndex, "Spacing") or 2
        local texture = plugin:GetSetting(sysIndex, "Texture")
        local bgColor = GetBgColor()
        local maxCharges = self.cachedMaxCharges or 3
        local previewCharges = maxCharges - 1
        local scale = self:GetEffectiveScale()

        local parent = options.parent
        local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        preview:SetSize(width, height)
        preview.sourceFrame = self
        preview.sourceWidth = width
        preview.sourceHeight = height
        preview.previewScale = 1
        preview.systemIndex = sysIndex
        preview.isTrackedBarFrame = true
        preview.components = {}

        -- Background
        preview.bg = preview:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers.BackdropDeep)
        preview.bg:SetAllPoints()
        Orbit.Skin:ApplyGradientBackground(preview, Orbit.db.GlobalSettings.BackdropColourCurve, bgColor)

        -- Single continuous StatusBar
        local bar = CreateFrame("StatusBar", nil, preview)
        bar:SetAllPoints()
        bar:SetMinMaxValues(0, maxCharges)
        bar:SetValue(previewCharges)
        local barColor = GetBarColor(plugin, sysIndex)
        Orbit.Skin:SkinStatusBar(bar, texture, barColor)
        if bar.Overlay then bar.Overlay:Hide() end

        -- Border around entire bar
        local barBackdrop = Orbit.Skin:CreateBackdrop(preview, nil)
        barBackdrop:SetFrameLevel(preview:GetFrameLevel() + Constants.Levels.Border)
        barBackdrop:SetBackdrop(nil)
        Orbit.Skin:SkinBorder(preview, barBackdrop, borderSize)

        -- Dividers
        local logicalGap = OrbitEngine.Pixel:Multiple(dividerSize, scale)
        local exactSegWidth = (width - (logicalGap * (maxCharges - 1))) / maxCharges
        local snappedWidth = OrbitEngine.Pixel:Snap(exactSegWidth, scale)

        local currentLeft = 0
        for i = 1, maxCharges - 1 do
            currentLeft = currentLeft + snappedWidth
            local logicalLeft = OrbitEngine.Pixel:Snap(currentLeft, scale)
            local div = bar:CreateTexture(nil, "OVERLAY", nil, 7)
            div:SetColorTexture(0, 0, 0, 1)
            div:SetSize(logicalGap, height)
            div:SetPoint("LEFT", preview, "LEFT", logicalLeft, 0)
            OrbitEngine.Pixel:Enforce(div)
            currentLeft = currentLeft + logicalGap
        end

        -- Count text
        local savedPositions = plugin:GetSetting(sysIndex, "ComponentPositions") or {}
        local fontName = plugin:GetSetting(sysIndex, "Font")
        local fontPath = LSM and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
        local fontSize = 18
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
                comp:SetFrameLevel(preview:GetFrameLevel() + Constants.Levels.Overlay)
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
