-- [ ORBIT PREVIEW FRAME ]--------------------------------------------------------------------------
-- Factory for creating scaled preview frames from source frames.
-- Used by Canvas Mode to create editable replicas of plugin frames.

local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

Engine.Preview = Engine.Preview or {}
local Preview = Engine.Preview

local PreviewFrame = {}
Preview.Frame = PreviewFrame

-- [ CONFIGURATION ]-----------------------------------------------------------------------------

local DEFAULT_SCALE = 1.0
local DEFAULT_BORDER_SIZE = 2
local DEFAULT_BAR_COLOR = { r = 0.2, g = 0.6, b = 0.2 }

-- [ CREATE PREVIEW ]----------------------------------------------------------------------------

-- Create a scaled preview frame that replicates the source frame's appearance
-- @param sourceFrame: The frame to replicate
-- @param options: {
--     scale: preview scale factor (default 1.0)
--     parent: parent frame (default UIParent)
--     borderSize: border size in pixels (default 2)
--     textureName: LibSharedMedia texture name for health bar
--     useClassColor: if true, use player class color for bar
--     barColor: fallback bar color {r, g, b}
-- }
-- @return preview frame with metadata
function PreviewFrame:Create(sourceFrame, options)
    if not sourceFrame then return nil end
    
    options = options or {}
    local scale = options.scale or DEFAULT_SCALE
    local parent = options.parent or UIParent
    local borderSize = options.borderSize or DEFAULT_BORDER_SIZE
    
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
    
    -- Apply backdrop (Orbit style - dark background with solid border)
    local bgColor = Orbit.Constants and Orbit.Constants.Colors and Orbit.Constants.Colors.Background
        or { r = 0.1, g = 0.1, b = 0.1, a = 0.95 }
    
    preview:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeSize = borderSize * scale,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    preview:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.95)
    preview:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- Create health bar visual
    local bar = CreateFrame("StatusBar", nil, preview)
    local inset = borderSize * scale
    bar:SetPoint("TOPLEFT", preview, "TOPLEFT", inset, -inset)
    bar:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -inset, inset)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    
    -- Apply texture
    local texturePath = "Interface\\Buttons\\WHITE8x8"
    if options.textureName and LSM then
        texturePath = LSM:Fetch("statusbar", options.textureName) or texturePath
    end
    bar:SetStatusBarTexture(texturePath)
    
    -- Apply color
    local barColor = options.barColor or DEFAULT_BAR_COLOR
    if options.useClassColor then
        local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        if classColor then
            bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
        else
            bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 1)
        end
    else
        bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 0.8)
    end
    
    preview.Health = bar
    
    return preview
end

-- [ DESTROY PREVIEW ]---------------------------------------------------------------------------

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

-- [ ADD COMPONENT ]-----------------------------------------------------------------------------

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
    container:EnableMouse(true)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")
    
    -- Store metadata
    container.key = key
    container.isFontString = options.isFontString or false
    container.preview = preview
    
    -- Position data (will be set by caller)
    container.anchorX = options.anchorX or "CENTER"
    container.anchorY = options.anchorY or "CENTER"
    container.offsetX = options.offsetX or 0
    container.offsetY = options.offsetY or 0
    container.posX = options.posX or 0
    container.posY = options.posY or 0
    container.justifyH = options.justifyH or "CENTER"
    
    -- Default size (caller typically overrides)
    local width = (options.width or 60) * scale
    local height = (options.height or 20) * scale
    container:SetSize(width, height)
    
    -- Border (subtle, visible on hover/drag)
    container.border = container:CreateTexture(nil, "BACKGROUND")
    container.border:SetAllPoints()
    container.border:SetColorTexture(0.3, 0.8, 0.3, 0)  -- Invisible by default
    
    -- Register with preview
    preview.components[key] = container
    
    return container
end

-- [ POSITION COMPONENT ]------------------------------------------------------------------------

-- Update component position based on anchor data
-- @param container: Component container
-- @param scale: Preview scale (optional, uses container.preview.previewScale if not provided)
function PreviewFrame:PositionComponent(container, scale)
    if not container or not container.preview then return end
    
    local preview = container.preview
    scale = scale or preview.previewScale
    local anchorX = container.anchorX
    local anchorY = container.anchorY
    local justifyH = container.justifyH
    
    -- Build anchor point using shared utility
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
end
