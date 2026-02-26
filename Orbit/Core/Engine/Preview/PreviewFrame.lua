-- [ ORBIT PREVIEW FRAME ]--------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

Engine.Preview = Engine.Preview or {}
local Preview = Engine.Preview
local PreviewFrame = {}
Preview.Frame = PreviewFrame

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local DEFAULT_SCALE = 1.0
local DEFAULT_BORDER_SIZE = 2
local DEFAULT_BAR_COLOR = { r = 0.2, g = 0.6, b = 0.2 }
local DEFAULT_COMPONENT_WIDTH = 60
local DEFAULT_COMPONENT_HEIGHT = 20

-- [ CREATE BASE PREVIEW ]---------------------------------------------------------------------------

function PreviewFrame:CreateBasePreview(sourceFrame, scale, parent, borderSize)
    if not sourceFrame then return nil end

    scale = scale or DEFAULT_SCALE
    parent = parent or UIParent
    borderSize = borderSize or DEFAULT_BORDER_SIZE

    local sourceWidth = sourceFrame:GetWidth()
    local sourceHeight = sourceFrame:GetHeight()

    local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local effScale = preview:GetEffectiveScale()
    preview:SetSize(Engine.Pixel:Snap(sourceWidth * scale, effScale), Engine.Pixel:Snap(sourceHeight * scale, effScale))

    preview.sourceFrame = sourceFrame
    preview.sourceWidth = sourceWidth
    preview.sourceHeight = sourceHeight
    preview.previewScale = scale
    preview.components = {}

    local bgColor = Orbit.Constants and Orbit.Constants.Colors and Orbit.Constants.Colors.Background or { r = 0.1, g = 0.1, b = 0.1, a = 0.95 }
    local scaledBorder = Engine.Pixel:Multiple(borderSize, preview:GetEffectiveScale() or 1)
    local backdrop = { bgFile = "Interface\\BUTTONS\\WHITE8x8", insets = { left = 0, right = 0, top = 0, bottom = 0 } }
    if scaledBorder > 0 then
        backdrop.edgeFile = "Interface\\BUTTONS\\WHITE8x8"
        backdrop.edgeSize = scaledBorder
    end
    preview:SetBackdrop(backdrop)
    preview:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.95)
    if scaledBorder > 0 then preview:SetBackdropBorderColor(0, 0, 0, 1) end

    return preview
end

-- [ CREATE PREVIEW ]--------------------------------------------------------------------------------

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
                preview.previewScale = scale
                preview.components = preview.components or {}
            end
            if preview:GetParent() ~= parent then preview:SetParent(parent) end
            return preview
        end
    end

    return self:CreateBasePreview(sourceFrame, scale, parent, options.borderSize or DEFAULT_BORDER_SIZE)
end

-- [ DESTROY PREVIEW ]-------------------------------------------------------------------------------

function PreviewFrame:Destroy(preview)
    if not preview then return end

    for key, container in pairs(preview.components) do
        if container.handle then
            container.handle:Hide()
            container.handle:SetParent(nil)
        end
        container:Hide()
        container:SetParent(nil)
    end
    wipe(preview.components)

    preview:Hide()
    preview:SetParent(nil)
    preview.sourceFrame = nil
end

-- [ ADD COMPONENT ]---------------------------------------------------------------------------------

function PreviewFrame:AddComponent(preview, key, options)
    if not preview or not key then return nil end
    options = options or {}
    local scale = preview.previewScale

    local container = CreateFrame("Frame", nil, preview)
    container:SetFrameLevel(preview:GetFrameLevel() + Orbit.Constants.Levels.Glow)
    container:EnableMouse(true)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")

    container.key = key
    container.isFontString = options.isFontString or false
    container.preview = preview
    container.anchorX = options.anchorX or "CENTER"
    container.anchorY = options.anchorY or "CENTER"
    container.offsetX = options.offsetX or 0
    container.offsetY = options.offsetY or 0
    container.posX = options.posX or 0
    container.posY = options.posY or 0
    container.justifyH = options.justifyH or "CENTER"

    local effScale = container:GetEffectiveScale()
    container:SetSize(
        Engine.Pixel:Snap((options.width or DEFAULT_COMPONENT_WIDTH) * scale, effScale),
        Engine.Pixel:Snap((options.height or DEFAULT_COMPONENT_HEIGHT) * scale, effScale)
    )

    container.border = container:CreateTexture(nil, "BACKGROUND")
    container.border:SetAllPoints()
    container.border:SetColorTexture(0.3, 0.8, 0.3, 0)

    preview.components[key] = container
    return container
end

-- [ POSITION COMPONENT ]----------------------------------------------------------------------------

function PreviewFrame:PositionComponent(container, scale)
    if not container or not container.preview then return end

    local preview = container.preview
    scale = scale or preview.previewScale
    local anchorX = container.anchorX
    local anchorY = container.anchorY
    local justifyH = container.justifyH

    local anchorPoint
    if anchorY == "CENTER" and anchorX == "CENTER" then anchorPoint = "CENTER"
    elseif anchorY == "CENTER" then anchorPoint = anchorX
    elseif anchorX == "CENTER" then anchorPoint = anchorY
    else anchorPoint = anchorY .. anchorX end

    local effScale = container:GetEffectiveScale()
    local finalX, finalY

    if anchorX == "CENTER" then finalX = Engine.Pixel:Snap(container.posX * scale, effScale)
    else
        finalX = Engine.Pixel:Snap(container.offsetX * scale, effScale)
        if anchorX == "RIGHT" then finalX = -finalX end
    end

    if anchorY == "CENTER" then finalY = Engine.Pixel:Snap(container.posY * scale, effScale)
    else
        finalY = Engine.Pixel:Snap(container.offsetY * scale, effScale)
        if anchorY == "TOP" then finalY = -finalY end
    end

    container:ClearAllPoints()
    if container.isFontString and justifyH ~= "CENTER" then
        container:SetPoint(justifyH, preview, anchorPoint, finalX, finalY)
    else
        container:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
    end
end
