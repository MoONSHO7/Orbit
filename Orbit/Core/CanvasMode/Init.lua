-- [ CANVAS MODE - INIT ]------------------------------------------------------------
-- Initialize Canvas Mode module with constants and shared state
-- This is loaded first, other modules extend the Dialog and CanvasMode namespace
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-- [ MODULE NAMESPACE ]-------------------------------------------------------------------

OrbitEngine.CanvasMode = OrbitEngine.CanvasMode or {}
local CanvasMode = OrbitEngine.CanvasMode

-- [ CONSTANTS ]--------------------------------------------------------------------------------

CanvasMode.Constants = {
    -- Dialog dimensions
    DIALOG_WIDTH = 600,
    DIALOG_MIN_HEIGHT = 200,
    DIALOG_INSET = 12,

    -- Row heights (stacked top-to-bottom)
    TITLE_ROW_HEIGHT = 40,
    PANELS_ROW_HEIGHT = 28,
    VIEWPORT_HEIGHT = 260,
    OVERRIDE_SECTION_PADDING = 8,

    -- Viewport
    VIEWPORT_PADDING = 20,

    -- Filter tabs
    FILTER_TAB_HEIGHT = 24,
    FILTER_TAB_SPACING = 4,

    -- Dock (horizontal bar at bottom of viewport)
    DOCK_HEIGHT = 40,
    DOCK_ICON_SIZE = 28,
    DOCK_ICON_SPACING = 6,
    DOCK_PADDING = 8,
    DOCK_Y_OFFSET = 10,

    -- Zoom
    DEFAULT_ZOOM = 2.0,
    MIN_ZOOM = 0.5,
    MAX_ZOOM = 5.0,
    ZOOM_STEP = 0.25,

    -- Pan clamping
    PAN_CLAMP_PADDING = 50,
    MIN_PAN_RANGE = 80,
}

local C = CanvasMode.Constants

-- [ CREATE DIALOG FRAME ]------------------------------------------------------------------------

local Dialog = CreateFrame("Frame", "OrbitCanvasModeDialog", UIParent)
Dialog:SetSize(C.DIALOG_WIDTH, C.DIALOG_MIN_HEIGHT)
Dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
Dialog:SetFrameStrata("FULLSCREEN_DIALOG")
Dialog:SetFrameLevel(100)
Dialog:SetMovable(true)
Dialog:SetClampedToScreen(true)
Dialog:EnableMouse(true)
Dialog:RegisterForDrag("LeftButton")
Dialog:Hide()

-- Backdrop: Use Blizzard's high-quality DialogBorderTranslucentTemplate
Dialog.Border = CreateFrame("Frame", nil, Dialog, "DialogBorderTranslucentTemplate")
Dialog.Border:SetAllPoints(Dialog)
Dialog.Border:SetFrameLevel(Dialog:GetFrameLevel())

-- Drag handlers
Dialog:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

Dialog:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Close on combat
Dialog:RegisterEvent("PLAYER_REGEN_DISABLED")
Dialog:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then
        self:Cancel()
    end
end)

-- [ TITLE ]--------------------------------------------------------------------------------------
Dialog.Title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
Dialog.Title:SetPoint("TOP", Dialog, "TOP", 0, -15)
Dialog.Title:SetText("Canvas Mode")

-- [ CLOSE BUTTON ]------------------------------------------------------------------------------
Dialog.CloseButton = CreateFrame("Button", nil, Dialog, "UIPanelCloseButton")
Dialog.CloseButton:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", -2, -2)
Dialog.CloseButton:SetScript("OnClick", function()
    Dialog:Cancel()
end)

-- [ STATE ]--------------------------------------------------------------------------------------
-- Zoom/Pan state
Dialog.zoomLevel = C.DEFAULT_ZOOM
Dialog.panOffsetX = 0
Dialog.panOffsetY = 0

-- Store dock component references
Dialog.dockComponents = {}
Dialog.disabledComponentKeys = {}

-- Preview components reference
Dialog.previewComponents = {}

-- Filter tab state
Dialog.activeFilter = "All"

-- [ EXPORT ]-------------------------------------------------------------------------------------

CanvasMode.Dialog = Dialog
