-- [ CANVAS MODE - INIT ] ----------------------------------------------------------------------------
-- Initialize Canvas Mode module with constants and shared state
-- This is loaded first, other modules extend the Dialog and CanvasMode namespace
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-- [ MODULE NAMESPACE ] ------------------------------------------------------------------------------
OrbitEngine.CanvasMode = OrbitEngine.CanvasMode or {}
local CanvasMode = OrbitEngine.CanvasMode

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
CanvasMode.Constants = {
    -- Dialog dimensions
    DIALOG_CENTER_OFFSET_Y = 50,
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

    -- NineSlice chrome offsets
    BG_INSET_LEFT = 6,
    BG_INSET_TOP = 21,
    BG_INSET_RIGHT = 2,
    BG_INSET_BOTTOM = 2,
    TITLE_INSET_LEFT = 30,
    TITLE_INSET_RIGHT = 24,
    TITLE_OFFSET_TOP = 1,
    TITLE_TEXT_OFFSET = 5,
    CLOSE_BTN_OFFSET_TOP = 1,
    STREAKS_OVERSHOOT_X = 2,
    STREAKS_OVERSHOOT_Y = 7,
    RESIZE_OFFSET_X = 5,
    RESIZE_OFFSET_Y = 4,

    VIEWPORT_INSET_LEFT = 10,
    VIEWPORT_INSET_RIGHT = 6,
    VIEWPORT_INSET_TOP = 27,
    VIEWPORT_CLIP_INSET = 4,

    INSET_RECESS_TOP = 1,
    INSET_RECESS_BOTTOM = 2,
    BORDER_FRAME_OFFSET_LEFT = -1,
    BORDER_FRAME_OFFSET_TOP = 4,
    BORDER_FRAME_OFFSET_RIGHT = 2,
    BORDER_FRAME_OFFSET_BOTTOM = -3,

    FILTER_TAB_INSET = 8,
    FILTER_TAB_SPACING = 12,
    FILTER_TAB_BAR_PAD = 12,

    SYNC_TOGGLE_SIZE = 26,
    SYNC_TOGGLE_OFFSET_X = -8,
    SYNC_TOGGLE_OFFSET_Y = -4,
    ZOOM_INDICATOR_OFFSET_X = -10,
    ZOOM_INDICATOR_OFFSET_Y = 8,

    -- Dock (horizontal bar at bottom of viewport)
    DOCK_HEIGHT = 40,
    DOCK_ICON_SIZE = 28,
    DOCK_ICON_SPACING = 6,
    DOCK_PADDING = 8,
    DOCK_Y_OFFSET = 10,

    DEFAULT_ZOOM = 2.5,
    MIN_ZOOM = 0.5,
    MAX_ZOOM = 5.0,
    ZOOM_STEP = 0.25,

    -- Pan clamping
    PAN_CLAMP_PADDING = 50,
    MIN_PAN_RANGE = 80,
}

local C = CanvasMode.Constants

-- [ CREATE DIALOG FRAME ] ---------------------------------------------------------------------------
local Dialog = CreateFrame("Frame", "OrbitCanvasModeDialog", UIParent)
Dialog:SetSize(C.DIALOG_WIDTH, C.DIALOG_MIN_HEIGHT)
Dialog:SetPoint("CENTER", UIParent, "CENTER", 0, C.DIALOG_CENTER_OFFSET_Y)
Dialog:SetFrameStrata(Orbit.Constants.Strata.FullscreenDialog)
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
Dialog.Bg:SetPoint("TOPLEFT", C.BG_INSET_LEFT, -C.BG_INSET_TOP)
Dialog.Bg:SetPoint("BOTTOMRIGHT", -C.BG_INSET_RIGHT, C.BG_INSET_BOTTOM)

-- Gradient streaks under title bar
Dialog.TopTileStreaks = Dialog:CreateTexture(nil, "BACKGROUND", nil, -5)
Dialog.TopTileStreaks:SetAtlas("_UI-Frame-TopTileStreaks", true)
Dialog.TopTileStreaks:SetPoint("TOPLEFT", Dialog.Bg, "TOPLEFT", -C.STREAKS_OVERSHOOT_X, C.STREAKS_OVERSHOOT_Y)
Dialog.TopTileStreaks:SetPoint("TOPRIGHT", Dialog.Bg, "TOPRIGHT", C.STREAKS_OVERSHOOT_X, C.STREAKS_OVERSHOOT_Y)

-- Drag handlers
Dialog:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

Dialog:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- [ RESIZE HANDLE ] ---------------------------------------------------------------------------------
Dialog.ResizeHandle = CreateFrame("Button", nil, Dialog)
Dialog.ResizeHandle:SetSize(C.RESIZE_HANDLE_SIZE, C.RESIZE_HANDLE_SIZE)
Dialog.ResizeHandle:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", C.RESIZE_OFFSET_X, -C.RESIZE_OFFSET_Y)
Dialog.ResizeHandle:SetFrameStrata(Orbit.Constants.Strata.Topmost)
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
        self.PreviewContainer:SetHeight(OrbitEngine.Pixel:Snap(newVpH, self.PreviewContainer:GetEffectiveScale()))
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

-- [ TITLE ] -----------------------------------------------------------------------------------------
Dialog.TitleContainer = CreateFrame("Frame", nil, Dialog)
Dialog.TitleContainer:SetFrameLevel(510)
Dialog.TitleContainer:SetPoint("TOPLEFT", C.TITLE_INSET_LEFT, -C.TITLE_OFFSET_TOP)
Dialog.TitleContainer:SetPoint("TOPRIGHT", -C.TITLE_INSET_RIGHT, -C.TITLE_OFFSET_TOP)
Dialog.TitleContainer:SetHeight(20)
Dialog.Title = Dialog.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
Dialog.Title:SetPoint("TOP", Dialog.TitleContainer, "TOP", 0, -C.TITLE_TEXT_OFFSET)

-- [ CLOSE BUTTON ] ----------------------------------------------------------------------------------
Dialog.CloseButton = CreateFrame("Button", nil, Dialog, "UIPanelCloseButton")
Dialog.CloseButton:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", 0, -C.CLOSE_BTN_OFFSET_TOP)
Dialog.CloseButton:SetFrameLevel(510)
Dialog.CloseButton:SetScript("OnClick", function()
    Dialog:Cancel()
end)

-- [ STATE ] -----------------------------------------------------------------------------------------
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

-- [ EXPORT ] ----------------------------------------------------------------------------------------
CanvasMode.Dialog = Dialog
