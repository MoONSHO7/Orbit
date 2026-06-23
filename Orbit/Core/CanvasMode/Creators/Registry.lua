-- [ CANVAS MODE - CREATOR REGISTRY ]-----------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode

-- [ REGISTRY ]---------------------------------------------------------------------------------------
CanvasMode.ComponentCreators = {}

function CanvasMode:RegisterCreator(creatorType, createFn)
    self.ComponentCreators[creatorType] = createFn
end

-- [ SHARED CONSTANTS ]-------------------------------------------------------------------------------
local BORDER_COLOR_IDLE = { 0.3, 0.8, 0.3, 0 }
local BORDER_COLOR_HOVER = { 0.3, 0.8, 0.3, 0.2 }
local BORDER_COLOR_DRAG = { 0.3, 0.8, 0.3, 0.3 }
local DEFAULT_TEXTURE_SIZE = 20
local DEFAULT_ICON_SIZE = 24
local DEFAULT_PORTRAIT_SIZE = 32
local FALLBACK_CONTAINER_WIDTH = 60
local FALLBACK_CONTAINER_HEIGHT = 20
local FALLBACK_GRAY = { 0.5, 0.5, 0.5, 0.5 }
local TEXT_PADDING = 2
local HIT_OVERSHOOT = 4
-- Opaque selection-state colors, distinguished by brightness (drag brightest).
local MARKER_HOVER = { 0.35, 0.70, 0.40, 1.0 }
local MARKER_SELECTED = { 0.40, 1.0, 0.50, 1.0 }
local MARKER_DRAG = { 0.70, 1.0, 0.80, 1.0 }

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
    TEXT_PADDING = TEXT_PADDING,
    HIT_OVERSHOOT = HIT_OVERSHOOT,
}

-- [ SHARED HELPERS ]---------------------------------------------------------------------------------
local IsSecret = issecretvalue or function() return false end

local function GetSourceSize(source, defaultW, defaultH)
    local w, h = defaultW, defaultH
    if source.orbitOriginalWidth and source.orbitOriginalWidth > 0 then
        w = source.orbitOriginalWidth
    else
        local val = source:GetWidth()
        if val and not IsSecret(val) and type(val) == "number" and val > 0 then w = val end
    end
    if source.orbitOriginalHeight and source.orbitOriginalHeight > 0 then
        h = source.orbitOriginalHeight
    else
        local val = source:GetHeight()
        if val and not IsSecret(val) and type(val) == "number" and val > 0 then h = val end
    end
    return w, h
end

CanvasMode.GetSourceSize = GetSourceSize

local function SetBorderColor(border, colorTable)
    border:SetColorTexture(colorTable[1], colorTable[2], colorTable[3], colorTable[4])
end

CanvasMode.SetBorderColor = SetBorderColor

-- [ SELECTION MARKER ]-------------------------------------------------------------------------------
-- Priority: drag > selected > hover > idle. The flat outline is the shared Skin primitive (runtime ref; Skinning loads after CanvasMode).
local function RefreshComponentMarker(container)
    if not container then return end
    local color
    if container._markerDragging then color = MARKER_DRAG
    elseif container._markerSelected then color = MARKER_SELECTED
    elseif container._markerHovered then color = MARKER_HOVER end
    if color then
        Orbit.Skin:ApplySelectionOutline(container, "marker", color)
    else
        Orbit.Skin:ClearSelectionOutline(container, "marker")
    end
end

CanvasMode.RefreshComponentMarker = RefreshComponentMarker

function CanvasMode:SetSelectedComponent(container)
    local prev = self._selectedComponent
    if prev and prev ~= container then
        prev._markerSelected = false
        RefreshComponentMarker(prev)
    end
    self._selectedComponent = container
    if container then
        container._markerSelected = true
        RefreshComponentMarker(container)
    end
end

-- [ TEXT ALIGNMENT ]---------------------------------------------------------------------------------
local function ApplyTextAlignment(container, visual, justifyH)
    if container and (container.orbitKeepTextCentered or container.key == "DifficultyText") then
        justifyH = "CENTER"
    end
    visual:ClearAllPoints()
    if justifyH == "LEFT" then
        visual:SetPoint("LEFT", container, "LEFT", TEXT_PADDING, 0)
    elseif justifyH == "RIGHT" then
        visual:SetPoint("RIGHT", container, "RIGHT", -TEXT_PADDING, 0)
    else
        visual:SetPoint("CENTER", container, "CENTER", 0, 0)
    end
    visual:SetJustifyH(justifyH)
end

CanvasMode.ApplyTextAlignment = ApplyTextAlignment
