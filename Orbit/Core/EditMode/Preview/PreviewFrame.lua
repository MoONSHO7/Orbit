-- [ ORBIT PREVIEW FRAME ] ---------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.Preview = Engine.Preview or {}
local Preview = Engine.Preview
local PreviewFrame = {}
Preview.Frame = PreviewFrame

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local DEFAULT_SCALE = 1.0
local DEFAULT_BORDER_SIZE = 2
local DEFAULT_BAR_COLOR = { r = 0.2, g = 0.6, b = 0.2 }
local DEFAULT_COMPONENT_WIDTH = 60
local DEFAULT_COMPONENT_HEIGHT = 20

-- [ CREATE BASE PREVIEW ]----------------------------------------------------------------------------
function PreviewFrame:CreateBasePreview(sourceFrame, scale, parent, borderSize)
    if not sourceFrame then return nil end

    scale = scale or DEFAULT_SCALE
    parent = parent or UIParent
    borderSize = borderSize or DEFAULT_BORDER_SIZE

    local sourceWidth = sourceFrame:GetWidth()
    local sourceHeight = sourceFrame:GetHeight()

    local effScale = sourceFrame:GetEffectiveScale()
    local globalBorder = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderSize or 0
    local borderInset = Engine.Pixel:Multiple(globalBorder, effScale)

    local preview = CreateFrame("Frame", nil, parent)
    local previewScale = preview:GetEffectiveScale()
    preview:SetSize(Engine.Pixel:Snap(sourceWidth * scale, previewScale), Engine.Pixel:Snap(sourceHeight * scale, previewScale))

    preview.sourceFrame = sourceFrame
    preview.sourceWidth = sourceWidth
    preview.sourceHeight = sourceHeight
    preview.borderInset = borderInset
    preview.previewScale = scale
    preview.components = {}

    local bgColor = Orbit.Constants and Orbit.Constants.Colors and Orbit.Constants.Colors.Background or { r = 0.1, g = 0.1, b = 0.1, a = 0.95 }
    preview.bg = preview:CreateTexture(nil, "BACKGROUND", nil, Orbit.Constants.Layers and Orbit.Constants.Layers.BackdropDeep or -8)
    preview.bg:SetAllPoints()
    preview.bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.95)
    Orbit.Skin:RegisterMaskedSurface(preview, preview.bg)

    Orbit.Skin:SkinBorder(preview, preview, borderSize)

    return preview
end

-- [ CREATE PREVIEW ]---------------------------------------------------------------------------------
function PreviewFrame:Create(sourceFrame, options)
    if not sourceFrame then return nil end
    options = options or {}

    local scale = options.scale or DEFAULT_SCALE
    local parent = options.parent or UIParent

    if sourceFrame.CreateCanvasPreview then
        local preview = sourceFrame:CreateCanvasPreview(options)
        if preview then
            if not preview.sourceFrame then
                preview.sourceFrame = sourceFrame
                preview.sourceWidth = sourceFrame:GetWidth()
                preview.sourceHeight = sourceFrame:GetHeight()
                local globalBorder = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderSize or 0
                preview.borderInset = Engine.Pixel:Multiple(globalBorder, sourceFrame:GetEffectiveScale())
                preview.previewScale = scale
                preview.components = preview.components or {}
            end
            if preview:GetParent() ~= parent then preview:SetParent(parent) end
            return preview
        end
    end

    return self:CreateBasePreview(sourceFrame, scale, parent, options.borderSize or DEFAULT_BORDER_SIZE)
end

