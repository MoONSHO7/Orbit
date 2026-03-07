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
    DIALOG_MIN_WIDTH = 600,
    DIALOG_MAX_WIDTH = 1000,
    DIALOG_MIN_HEIGHT = 200,
    DIALOG_INSET = 12,
    RESIZE_HANDLE_SIZE = 35,
    THREE_COL_THRESHOLD = 800,

    -- Row heights (stacked top-to-bottom)
    TITLE_ROW_HEIGHT = 40,
    PANELS_ROW_HEIGHT = 28,
    VIEWPORT_HEIGHT = 265,
    VIEWPORT_MAX_HEIGHT = 530,
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
Dialog:SetResizable(true)
Dialog:SetResizeBounds(C.DIALOG_MIN_WIDTH, C.DIALOG_MIN_HEIGHT, C.DIALOG_MAX_WIDTH, nil)
Dialog:SetClampedToScreen(true)
Dialog:EnableMouse(true)
Dialog:RegisterForDrag("LeftButton")
Dialog:Hide()

-- Outer NineSlice: Blizzard metal panel border (no portrait)
Dialog.NineSlice = CreateFrame("Frame", nil, Dialog, "NineSlicePanelTemplate")
Dialog.NineSlice.layoutType = "ButtonFrameTemplateNoPortrait"
NineSliceUtil.ApplyLayoutByName(Dialog.NineSlice, "ButtonFrameTemplateNoPortrait")
-- Panel background (tiled rock texture)
Dialog.Bg = Dialog:CreateTexture(nil, "BACKGROUND", nil, -6)
Dialog.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
Dialog.Bg:SetHorizTile(true)
Dialog.Bg:SetVertTile(true)
Dialog.Bg:SetPoint("TOPLEFT", 6, -21)
Dialog.Bg:SetPoint("BOTTOMRIGHT", -2, 2)

-- Gradient streaks under title bar
Dialog.TopTileStreaks = Dialog:CreateTexture(nil, "BACKGROUND", nil, -5)
Dialog.TopTileStreaks:SetAtlas("_UI-Frame-TopTileStreaks", true)
Dialog.TopTileStreaks:SetPoint("TOPLEFT", Dialog.Bg, "TOPLEFT", -2, 7)
Dialog.TopTileStreaks:SetPoint("TOPRIGHT", Dialog.Bg, "TOPRIGHT", 2, 7)

-- Drag handlers
Dialog:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

Dialog:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- [ RESIZE HANDLE ]--------------------------------------------------------------------------
Dialog.ResizeHandle = CreateFrame("Button", nil, Dialog)
Dialog.ResizeHandle:SetSize(C.RESIZE_HANDLE_SIZE, C.RESIZE_HANDLE_SIZE)
Dialog.ResizeHandle:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", 5, -4)
Dialog.ResizeHandle:SetFrameStrata("TOOLTIP")
Dialog.ResizeHandle:SetNormalAtlas("damagemeters-scalehandle")
Dialog.ResizeHandle:SetHighlightAtlas("damagemeters-scalehandle-hover")
Dialog.ResizeHandle:SetPushedAtlas("damagemeters-scalehandle-pressed")
Dialog.ResizeHandle:RegisterForDrag("LeftButton")
Dialog.ResizeHandle:SetScript("OnDragStart", function() Dialog:StartSizing("BOTTOMRIGHT") end)
Dialog.ResizeHandle:SetScript("OnDragStop", function() Dialog:StopMovingOrSizing() end)

Dialog:SetScript("OnSizeChanged", function(self, w, h)
    if not self:IsShown() or self._inSizeChanged then return end
    self._inSizeChanged = true
    -- Reverse-compute viewport height from total dialog height
    if self.GetChromeHeight then
        local chromeH = self:GetChromeHeight()
        local newVpH = math.max(C.VIEWPORT_HEIGHT, math.min(C.VIEWPORT_MAX_HEIGHT, h - chromeH))
        self.viewportHeight = newVpH
        self.PreviewContainer:SetHeight(newVpH)
    end
    if self.LayoutFooterButtons then self:LayoutFooterButtons() end
    if self.RecalculateHeight then self:RecalculateHeight() end
    if Orbit.CanvasComponentSettings and Orbit.CanvasComponentSettings.componentKey then
        Orbit.CanvasComponentSettings:RelayoutWidgets()
    end
    self._inSizeChanged = nil
end)

-- Close on combat
Dialog:RegisterEvent("PLAYER_REGEN_DISABLED")
Dialog:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then
        self:Cancel()
    end
end)

-- [ TITLE ]--------------------------------------------------------------------------------------
Dialog.TitleContainer = CreateFrame("Frame", nil, Dialog)
Dialog.TitleContainer:SetFrameLevel(510)
Dialog.TitleContainer:SetPoint("TOPLEFT", 30, -1)
Dialog.TitleContainer:SetPoint("TOPRIGHT", -24, -1)
Dialog.TitleContainer:SetHeight(20)
Dialog.Title = Dialog.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
Dialog.Title:SetPoint("TOP", Dialog.TitleContainer, "TOP", 0, -5)

-- [ CLOSE BUTTON ]------------------------------------------------------------------------------
Dialog.CloseButton = CreateFrame("Button", nil, Dialog, "UIPanelCloseButton")
Dialog.CloseButton:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", 0, -1)
Dialog.CloseButton:SetFrameLevel(510)
Dialog.CloseButton:SetScript("OnClick", function()
    Dialog:Cancel()
end)

-- [ STATE ]--------------------------------------------------------------------------------------
-- Zoom/Pan state
Dialog.zoomLevel = C.DEFAULT_ZOOM
Dialog.panOffsetX = 0
Dialog.panOffsetY = 0
Dialog.viewportHeight = C.VIEWPORT_HEIGHT

-- Store dock component references
Dialog.dockComponents = {}
Dialog.disabledComponentKeys = {}

-- Preview components reference
Dialog.previewComponents = {}

-- Filter tab state
Dialog.activeFilter = "All"

-- [ EXPORT ]-------------------------------------------------------------------------------------

CanvasMode.Dialog = Dialog
