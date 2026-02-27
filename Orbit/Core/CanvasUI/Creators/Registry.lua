-- [ CANVAS MODE - CREATOR REGISTRY ]----------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode

-- [ REGISTRY ]--------------------------------------------------------------------------------------

CanvasMode.ComponentCreators = {}

function CanvasMode:RegisterCreator(creatorType, createFn)
    self.ComponentCreators[creatorType] = createFn
end

-- [ SHARED CONSTANTS ]------------------------------------------------------------------------------

local BORDER_COLOR_IDLE = { 0.3, 0.8, 0.3, 0 }
local BORDER_COLOR_HOVER = { 0.3, 0.8, 0.3, 0.2 }
local BORDER_COLOR_DRAG = { 0.3, 0.8, 0.3, 0.3 }
local DEFAULT_TEXTURE_SIZE = 20
local DEFAULT_ICON_SIZE = 24
local DEFAULT_PORTRAIT_SIZE = 32
local FALLBACK_CONTAINER_WIDTH = 60
local FALLBACK_CONTAINER_HEIGHT = 20
local FALLBACK_GRAY = { 0.5, 0.5, 0.5, 0.5 }

CanvasMode.CreatorConstants = {
    BORDER_COLOR_IDLE = BORDER_COLOR_IDLE,
    BORDER_COLOR_HOVER = BORDER_COLOR_HOVER,
    BORDER_COLOR_DRAG = BORDER_COLOR_DRAG,
    DEFAULT_TEXTURE_SIZE = DEFAULT_TEXTURE_SIZE,
    DEFAULT_ICON_SIZE = DEFAULT_ICON_SIZE,
    DEFAULT_PORTRAIT_SIZE = DEFAULT_PORTRAIT_SIZE,
    FALLBACK_CONTAINER_WIDTH = FALLBACK_CONTAINER_WIDTH,
    FALLBACK_CONTAINER_HEIGHT = FALLBACK_CONTAINER_HEIGHT,
    FALLBACK_GRAY = FALLBACK_GRAY,
}

-- [ SHARED HELPERS ]--------------------------------------------------------------------------------

local function GetSourceSize(source, defaultW, defaultH)
    local w, h = defaultW, defaultH
    if source.orbitOriginalWidth and source.orbitOriginalWidth > 0 then
        w = source.orbitOriginalWidth
    else
        local ok, val = pcall(function() return source:GetWidth() end)
        if ok and val and type(val) == "number" and val > 0 then w = val end
    end
    if source.orbitOriginalHeight and source.orbitOriginalHeight > 0 then
        h = source.orbitOriginalHeight
    else
        local ok, val = pcall(function() return source:GetHeight() end)
        if ok and val and type(val) == "number" and val > 0 then h = val end
    end
    return w, h
end

CanvasMode.GetSourceSize = GetSourceSize

local function SetBorderColor(border, colorTable)
    border:SetColorTexture(colorTable[1], colorTable[2], colorTable[3], colorTable[4])
end

CanvasMode.SetBorderColor = SetBorderColor

-- [ TEXT ALIGNMENT ]--------------------------------------------------------------------------------

local function ApplyTextAlignment(container, visual, justifyH)
    visual:ClearAllPoints()
    visual:SetPoint(justifyH, container, justifyH, 0, 0)
    visual:SetJustifyH(justifyH)
end

CanvasMode.ApplyTextAlignment = ApplyTextAlignment
