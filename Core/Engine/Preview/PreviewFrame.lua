-- [ ORBIT PREVIEW FRAME ]--------------------------------------------------------------------------
-- Factory for creating scaled preview frames from source frames.
-- Used by Canvas Mode to create editable replicas of plugin frames.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.Preview = Engine.Preview or {}
local Preview = Engine.Preview

local PreviewFrame = {}
Preview.Frame = PreviewFrame

-------------------------------------------------
-- CONFIGURATION
-------------------------------------------------

local DEFAULT_SCALE = 1.0
local DEFAULT_BORDER_SIZE = 2
local PREVIEW_BAR_COLOR = { r = 0.2, g = 0.6, b = 0.2 }  -- Green health bar

-------------------------------------------------
-- CREATE PREVIEW
-------------------------------------------------

-- Create a scaled preview frame that replicates the source frame's appearance
-- @param sourceFrame: The frame to replicate
-- @param options: { scale, parent, showBorder, barColor }
-- @return preview frame with metadata
function PreviewFrame:Create(sourceFrame, options)
    if not sourceFrame then return nil end
    
    options = options or {}
    local scale = options.scale or DEFAULT_SCALE
    local parent = options.parent or UIParent
    local showBorder = options.showBorder ~= false
    local barColor = options.barColor or PREVIEW_BAR_COLOR
    
    -- Get source dimensions
    local sourceWidth = sourceFrame:GetWidth()
    local sourceHeight = sourceFrame:GetHeight()
    
    -- Create container frame
    local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    preview:SetSize(sourceWidth * scale, sourceHeight * scale)
    
    -- Store metadata
    preview.sourceFrame = sourceFrame
    preview.sourceWidth = sourceWidth
    preview.sourceHeight = sourceHeight
    preview.previewScale = scale
    preview.components = {}  -- { key = container }
    
    -- Apply backdrop matching source style
    local backdropColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.95 }
    local borderColor = { r = 0.3, g = 0.3, b = 0.3 }
    
    if showBorder then
        preview:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = DEFAULT_BORDER_SIZE * scale,
        })
        preview:SetBackdropColor(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a)
        preview:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, 1)
    else
        preview:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
        })
        preview:SetBackdropColor(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a)
    end
    
    -- Create health bar visual
    local bar = CreateFrame("StatusBar", nil, preview)
    local inset = DEFAULT_BORDER_SIZE * scale
    bar:SetPoint("TOPLEFT", inset, -inset)
    bar:SetPoint("BOTTOMRIGHT", -inset, inset)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 0.8)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    preview.bar = bar
    
    return preview
end

-------------------------------------------------
-- DESTROY PREVIEW
-------------------------------------------------

function PreviewFrame:Destroy(preview)
    if not preview then return end
    
    -- Clear components
    for key, container in pairs(preview.components) do
        if container.handle then
            container.handle:Hide()
            container.handle:SetParent(nil)
        end
        container:Hide()
        container:SetParent(nil)
    end
    wipe(preview.components)
    
    -- Hide and release
    preview:Hide()
    preview:SetParent(nil)
    preview.sourceFrame = nil
end

-------------------------------------------------
-- ADD COMPONENT
-------------------------------------------------

-- Add a component container to the preview
-- @param preview: The preview frame
-- @param key: Component identifier
-- @param options: { position, visual, isFontString }
-- @return container frame
function PreviewFrame:AddComponent(preview, key, options)
    if not preview or not key then return nil end
    
    options = options or {}
    local scale = preview.previewScale
    
    -- Create container
    local container = CreateFrame("Frame", nil, preview)
    container:SetFrameLevel(preview:GetFrameLevel() + 10)
    
    -- Store metadata
    container.key = key
    container.isFontString = options.isFontString or false
    container.preview = preview
    
    -- Position data (will be set by controller)
    container.anchorX = options.anchorX or "CENTER"
    container.anchorY = options.anchorY or "CENTER"
    container.offsetX = options.offsetX or 0
    container.offsetY = options.offsetY or 0
    container.posX = options.posX or 0
    container.posY = options.posY or 0
    container.justifyH = options.justifyH or "CENTER"
    
    -- Size container
    local width = (options.width or 50) * scale
    local height = (options.height or 20) * scale
    container:SetSize(width, height)
    
    -- Create visual element
    if options.isFontString then
        local visual = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        visual:SetText(options.text or key)
        visual:SetTextScale(scale)
        container.visual = visual
    else
        -- Texture-based component
        local visual = container:CreateTexture(nil, "OVERLAY")
        visual:SetAllPoints()
        if options.texture then
            visual:SetTexture(options.texture)
        else
            visual:SetColorTexture(0.8, 0.8, 0.8, 0.9)
        end
        container.visual = visual
    end
    
    -- Register with preview
    preview.components[key] = container
    
    return container
end

-------------------------------------------------
-- POSITION COMPONENT
-------------------------------------------------

-- Update component position based on anchor data
-- @param container: Component container
function PreviewFrame:PositionComponent(container)
    if not container or not container.preview then return end
    
    local preview = container.preview
    local scale = preview.previewScale
    local anchorX = container.anchorX
    local anchorY = container.anchorY
    local justifyH = container.justifyH
    
    -- Build anchor point
    local anchorPoint
    if anchorY == "CENTER" and anchorX == "CENTER" then
        anchorPoint = "CENTER"
    elseif anchorY == "CENTER" then
        anchorPoint = anchorX
    elseif anchorX == "CENTER" then
        anchorPoint = anchorY
    else
        anchorPoint = anchorY .. anchorX
    end
    
    -- Calculate final position
    local finalX, finalY
    
    if anchorX == "CENTER" then
        finalX = container.posX * scale
    else
        finalX = container.offsetX * scale
        if anchorX == "RIGHT" then finalX = -finalX end
    end
    
    if anchorY == "CENTER" then
        finalY = container.posY * scale
    else
        finalY = container.offsetY * scale
        if anchorY == "TOP" then finalY = -finalY end
    end
    
    -- Apply position
    container:ClearAllPoints()
    if container.isFontString and justifyH ~= "CENTER" then
        container:SetPoint(justifyH, preview, anchorPoint, finalX, finalY)
    else
        container:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
    end
    
    -- Update text alignment if FontString
    if container.isFontString and container.visual then
        container.visual:ClearAllPoints()
        container.visual:SetPoint(justifyH, container, justifyH, 0, 0)
        container.visual:SetJustifyH(justifyH)
    end
end
