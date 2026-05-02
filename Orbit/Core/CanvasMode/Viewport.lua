-- [ CANVAS MODE - VIEWPORT ] ------------------------------------------------------------------------
-- Viewport with zoom/pan controls for Canvas Mode
-- Row layout: Title > Viewport (Dock | Preview) > Override > Footer

local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local C = CanvasMode.Constants
local L = Orbit.L
local Pixel = OrbitEngine.Pixel
local Levels = Orbit.Constants.Levels

-- [ FILTER CONSTANTS ] ------------------------------------------------------------------------------
local FILTER_TABS = { "All", "Text", "Icons", "Auras" }
local FILTER_TAB_LABELS = {
    All   = L.CFG_CM_FILTER_ALL,
    Text  = L.CFG_CM_FILTER_TEXT,
    Icons = L.CFG_CM_FILTER_ICONS,
    Auras = L.CFG_CM_FILTER_AURAS,
}
local FILTER_TAB_ACTIVE_COLOR = { r = 1.0, g = 0.82, b = 0.0 }
local FILTER_TAB_INACTIVE_COLOR = { r = 0.6, g = 0.6, b = 0.6 }
local SYNC_LABEL_COLOR = { r = 0.9, g = 0.9, b = 0.9, a = 1 }
local TOOLTIP_LINE_COLOR = { r = 0.7, g = 0.7, b = 0.7 }
local ZOOM_INDICATOR_COLOR = { r = 0.6, g = 0.6, b = 0.6, a = 1 }
local DRAG_BUTTONS = { "MiddleButton", "LeftButton" }

local function ApplyFilterTabState(btn, isActive)
    local c = isActive and FILTER_TAB_ACTIVE_COLOR or FILTER_TAB_INACTIVE_COLOR
    btn:SetTextColor(c.r, c.g, c.b)
end

-- [ VIEWPORT AREA ] ---------------------------------------------------------------------------------
-- Architecture: PreviewContainer > Viewport (clips) > TransformLayer > PreviewFrame

Dialog.PreviewContainer = CreateFrame("Frame", nil, Dialog)
Dialog.PreviewContainer:SetPoint("TOPLEFT", Dialog, "TOPLEFT", C.VIEWPORT_INSET_LEFT, -C.VIEWPORT_INSET_TOP)
Dialog.PreviewContainer:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", -C.VIEWPORT_INSET_RIGHT, -C.VIEWPORT_INSET_TOP)
Dialog.PreviewContainer:SetHeight(C.VIEWPORT_HEIGHT)

-- Recessed NineSlice behind the viewport (slightly larger for depth)
Dialog.Inset = CreateFrame("Frame", nil, Dialog, "InsetFrameTemplate")
Dialog.Inset:SetPoint("TOPLEFT", Dialog, "TOPLEFT", C.BG_INSET_LEFT, -(C.BG_INSET_TOP + C.INSET_RECESS_TOP))
Dialog.Inset:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -C.BG_INSET_RIGHT, C.BG_INSET_BOTTOM + C.INSET_RECESS_BOTTOM)
Dialog.Inset:SetFrameLevel(Dialog:GetFrameLevel() + 1)
Dialog.Inset.NineSlice.layoutType = "InsetFrameTemplate"
NineSliceUtil.ApplyLayoutByName(Dialog.Inset.NineSlice, "InsetFrameTemplate")
if Dialog.Inset.Bg then Dialog.Inset.Bg:Hide() end

-- QuestLogBorderFrame: covers entire content area above the Inset
Dialog.BorderFrame = CreateFrame("Frame", nil, Dialog)
Dialog.BorderFrame:SetPoint("TOPLEFT", Dialog.Inset, "TOPLEFT", C.BORDER_FRAME_OFFSET_LEFT, C.BORDER_FRAME_OFFSET_TOP)
Dialog.BorderFrame:SetPoint("BOTTOMRIGHT", Dialog.Inset, "BOTTOMRIGHT", C.BORDER_FRAME_OFFSET_RIGHT, C.BORDER_FRAME_OFFSET_BOTTOM)
Dialog.BorderFrame:SetFrameLevel(Dialog.Inset:GetFrameLevel() + 5)
Dialog.BorderFrame.Border = Dialog.BorderFrame:CreateTexture(nil, "BORDER")
Dialog.BorderFrame.Border:SetAtlas("questlog-frame")
Dialog.BorderFrame.Border:SetAllPoints()
Dialog.BorderFrame.TopDetail = Dialog.BorderFrame:CreateTexture(nil, "ARTWORK")
Dialog.BorderFrame.TopDetail:SetAtlas("questlog-frame-filigree", true)
Dialog.BorderFrame.TopDetail:SetPoint("TOP", 0, 1)

-- Divider (created in Dock.lua after DisabledDock is available)

Dialog.BorderOverlay = CreateFrame("Frame", nil, Dialog.PreviewContainer)
Dialog.BorderOverlay:SetAllPoints()
Dialog.BorderOverlay:SetFrameLevel(Dialog.PreviewContainer:GetFrameLevel() + Levels.CanvasOverlay)

-- [ FILTER TAB LABELS (inside viewport overlay) ] ---------------------------------------------------
Dialog.FilterTabBar = CreateFrame("Frame", nil, Dialog.BorderOverlay)
Dialog.FilterTabBar:SetPoint("TOPLEFT", Dialog.BorderOverlay, "TOPLEFT", 0, 0)
Dialog.FilterTabBar:SetPoint("RIGHT", Dialog.BorderOverlay, "RIGHT", 0, 0)
Dialog.FilterTabBar:SetHeight(C.FILTER_TAB_INSET * 2 + C.FILTER_TAB_BAR_PAD)
Dialog.FilterTabBar:SetFrameLevel(Dialog.BorderOverlay:GetFrameLevel() + 1)
Dialog.filterTabButtons = {}
local lastFilterBtn = nil
for _, tabName in ipairs(FILTER_TABS) do
    local label = Dialog.FilterTabBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if lastFilterBtn then
        label:SetPoint("LEFT", lastFilterBtn, "RIGHT", C.FILTER_TAB_SPACING, 0)
    else
        label:SetPoint("TOPLEFT", Dialog.FilterTabBar, "TOPLEFT", C.FILTER_TAB_INSET, -C.FILTER_TAB_INSET)
    end
    label:SetText(FILTER_TAB_LABELS[tabName])
    label.filterName = tabName
    ApplyFilterTabState(label, tabName == Dialog.activeFilter)

    local hitBtn = CreateFrame("Button", nil, Dialog.FilterTabBar)
    hitBtn:SetAllPoints(label)
    hitBtn:SetScript("OnClick", function()
        for _, b in ipairs(Dialog.filterTabButtons) do ApplyFilterTabState(b, b.filterName == tabName) end
        Dialog:ApplyFilter(tabName)
    end)

    label.hitButton = hitBtn
    Dialog.filterTabButtons[#Dialog.filterTabButtons + 1] = label
    lastFilterBtn = label
end

-- Viewport: clips children to create the viewable area (inset from dock column)
Dialog.Viewport = CreateFrame("Frame", nil, Dialog.PreviewContainer)
Dialog.Viewport:SetPoint("TOPLEFT", C.VIEWPORT_CLIP_INSET, -C.VIEWPORT_CLIP_INSET)
Dialog.Viewport:SetPoint("BOTTOMRIGHT", -C.VIEWPORT_CLIP_INSET, C.VIEWPORT_CLIP_INSET)
Dialog.Viewport:SetClipsChildren(true)
Dialog.Viewport:EnableMouse(true)
Dialog.Viewport:EnableMouseWheel(true)
Dialog.Viewport:RegisterForDrag(unpack(DRAG_BUTTONS))

-- TransformLayer: receives zoom (SetScale) and pan (position offset)
Dialog.TransformLayer = CreateFrame("Frame", nil, Dialog.Viewport)
Dialog.TransformLayer:SetSize(1, 1)
Dialog.TransformLayer:SetPoint("CENTER", Dialog.Viewport, "CENTER", 0, C.DOCK_Y_OFFSET)

-- [ ROW 4: OVERRIDE SETTINGS CONTAINER ] ------------------------------------------------------------
-- (Created in Dock.lua after DisabledDock is available)

-- [ DYNAMIC HEIGHT ] --------------------------------------------------------------------------------
function Dialog:GetChromeHeight()
    local FC = Orbit.Constants.Footer
    local topOffset = C.VIEWPORT_INSET_TOP
    local overrideShown = self.OverrideContainer and self.OverrideContainer:IsShown()
    local overrideHeight = overrideShown and self.OverrideContainer:GetHeight() or 0
    local overridePad = overrideHeight > 0 and C.OVERRIDE_SECTION_PADDING or 0
    local footerHeight = FC.TopPadding + FC.ButtonHeight + FC.BottomPadding
    local dividerHeight = (self.ViewportDivider and self.ViewportDivider:IsShown()) and select(2, self.ViewportDivider:GetSize()) or 0
    local dockHeight = C.DOCK_HEIGHT + 2
    return topOffset + dividerHeight + dockHeight + overridePad + overrideHeight + footerHeight + C.DIALOG_INSET
end

function Dialog:RecalculateHeight()
    local vpH = self.viewportHeight or C.VIEWPORT_HEIGHT
    local pcScale = self.PreviewContainer:GetEffectiveScale()
    self.PreviewContainer:SetHeight(Pixel:Snap(vpH, pcScale))

    local chromeH = self:GetChromeHeight()
    local totalHeight = chromeH + vpH

    local top = self:GetTop()
    local left = self:GetLeft()
    if top and left then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    else
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, C.DIALOG_CENTER_OFFSET_Y)
    end

    local selfScale = self:GetEffectiveScale()
    self:SetHeight(math.max(C.DIALOG_MIN_HEIGHT, Pixel:Snap(totalHeight, selfScale)))
    self:LayoutFooterButtons()
end

-- [ ZOOM/PAN HELPERS ] ------------------------------------------------------------------------------
local function GetPanBounds(transformLayer, viewport, zoomLevel)
    local baseWidth = transformLayer.baseWidth or transformLayer:GetWidth()
    local baseHeight = transformLayer.baseHeight or transformLayer:GetHeight()
    local scaledW = baseWidth * zoomLevel
    local scaledH = baseHeight * zoomLevel
    local viewW = viewport:GetWidth()
    local viewH = viewport:GetHeight()

    local scale = viewport:GetEffectiveScale()
    local maxX = Pixel:Snap(math.max(C.MIN_PAN_RANGE, (scaledW / 2) - (viewW / 2) + C.PAN_CLAMP_PADDING), scale)
    local maxY = Pixel:Snap(math.max(C.MIN_PAN_RANGE, (scaledH / 2) - (viewH / 2) + C.PAN_CLAMP_PADDING), scale)

    return maxX, maxY
end

local function ApplyPanOffset(dialog, offsetX, offsetY)
    local maxX, maxY = GetPanBounds(dialog.TransformLayer, dialog.Viewport, dialog.zoomLevel)

    dialog.panOffsetX = math.max(-maxX, math.min(maxX, offsetX))
    dialog.panOffsetY = math.max(-maxY, math.min(maxY, offsetY))

    dialog.TransformLayer:ClearAllPoints()
    dialog.TransformLayer:SetPoint("CENTER", dialog.Viewport, "CENTER", dialog.panOffsetX, dialog.panOffsetY + C.DOCK_Y_OFFSET)
end

local function ApplyZoom(dialog, newZoom, focusVX, focusVY)
    newZoom = math.max(C.MIN_ZOOM, math.min(C.MAX_ZOOM, newZoom))
    newZoom = math.floor(newZoom * 100 + 0.5) / 100
    local oldZoom = dialog.zoomLevel or newZoom

    if focusVX and focusVY and oldZoom ~= 0 then
        local worldX = (focusVX - dialog.panOffsetX) / oldZoom
        local worldY = (focusVY - (dialog.panOffsetY + C.DOCK_Y_OFFSET)) / oldZoom
        dialog.panOffsetX = focusVX - worldX * newZoom
        dialog.panOffsetY = focusVY - worldY * newZoom - C.DOCK_Y_OFFSET
    end

    dialog.zoomLevel = newZoom
    dialog.TransformLayer:SetScale(newZoom)
    ApplyPanOffset(dialog, dialog.panOffsetX, dialog.panOffsetY)

    if dialog.ZoomIndicator then
        dialog.ZoomIndicator:SetText(string.format("%.0f%%", newZoom * 100))
    end
end

CanvasMode.ApplyZoom = ApplyZoom
CanvasMode.ApplyPanOffset = ApplyPanOffset

-- [ ZOOM HANDLER ] ----------------------------------------------------------------------------------
Dialog.Viewport:SetScript("OnMouseWheel", function(self, delta)
    local mx, my = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    local cx, cy = self:GetCenter()
    local focusVX = mx / scale - cx
    local focusVY = my / scale - cy
    ApplyZoom(Dialog, Dialog.zoomLevel + (delta * C.ZOOM_STEP), focusVX, focusVY)
end)

-- [ PAN HANDLERS ] ----------------------------------------------------------------------------------
local function PanUpdate(self)
    local mX, mY = GetCursorPosition()
    local scale = self._panScale or UIParent:GetEffectiveScale()
    local mx = mX / scale
    local my = mY / scale
    ApplyPanOffset(Dialog, self.panStartOffsetX + (mx - self.panStartMouseX), self.panStartOffsetY + (my - self.panStartMouseY))
end

Dialog.Viewport:SetScript("OnDragStart", function(self)
    self.isPanning = true
    local mX, mY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self._panScale = scale
    self.panStartMouseX = mX / scale
    self.panStartMouseY = mY / scale
    self.panStartOffsetX = Dialog.panOffsetX
    self.panStartOffsetY = Dialog.panOffsetY
    self:SetScript("OnUpdate", PanUpdate)
end)

Dialog.Viewport:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self.isPanning = false
    self._panScale = nil
end)

-- [ SYNC TOGGLE ] -----------------------------------------------------------------------------------
Dialog.SyncToggle = CreateFrame("CheckButton", nil, Dialog.BorderOverlay, "UICheckButtonTemplate")
Dialog.SyncToggle:SetSize(C.SYNC_TOGGLE_SIZE, C.SYNC_TOGGLE_SIZE)
Dialog.SyncToggle:SetPoint("TOPRIGHT", Dialog.PreviewContainer, "TOPRIGHT", C.SYNC_TOGGLE_OFFSET_X, C.SYNC_TOGGLE_OFFSET_Y)
Dialog.SyncToggle:SetFrameLevel(Dialog.BorderOverlay:GetFrameLevel() + 1)
Dialog.SyncToggle:Hide()

Dialog.SyncToggle.label = Dialog.SyncToggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.SyncToggle.label:SetPoint("RIGHT", Dialog.SyncToggle, "LEFT", -2, 0)
Dialog.SyncToggle.label:SetText(L.CFG_CM_SYNC)
Dialog.SyncToggle.label:SetTextColor(SYNC_LABEL_COLOR.r, SYNC_LABEL_COLOR.g, SYNC_LABEL_COLOR.b, SYNC_LABEL_COLOR.a)

Dialog.SyncToggle.isSynced = true

function Dialog.SyncToggle:UpdateVisual()
    self:SetChecked(self.isSynced)
end

Dialog.SyncToggle:SetScript("OnClick", function(self)
    self.isSynced = self:GetChecked()
    if CanvasMode.Transaction and CanvasMode.Transaction:IsActive() then
        CanvasMode.Transaction:Set("UseGlobalTextStyle", self.isSynced)
    end
end)

Dialog.SyncToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
    if self.isSynced then
        GameTooltip:SetText(L.CFG_CM_SYNC_ON_TITLE)
        GameTooltip:AddLine(L.CFG_CM_SYNC_ON_TT, TOOLTIP_LINE_COLOR.r, TOOLTIP_LINE_COLOR.g, TOOLTIP_LINE_COLOR.b, true)
    else
        GameTooltip:SetText(L.CFG_CM_SYNC_OFF_TITLE)
        GameTooltip:AddLine(L.CFG_CM_SYNC_OFF_TT, TOOLTIP_LINE_COLOR.r, TOOLTIP_LINE_COLOR.g, TOOLTIP_LINE_COLOR.b, true)
    end
    GameTooltip:Show()
end)

Dialog.SyncToggle:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

Dialog.SyncToggle:UpdateVisual()

-- [ ZOOM INDICATOR ] --------------------------------------------------------------------------------
Dialog.ZoomIndicator = Dialog.BorderOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.ZoomIndicator:SetPoint("BOTTOMRIGHT", Dialog.PreviewContainer, "BOTTOMRIGHT", C.ZOOM_INDICATOR_OFFSET_X, C.ZOOM_INDICATOR_OFFSET_Y)
Dialog.ZoomIndicator:SetText(string.format("%.0f%%", C.DEFAULT_ZOOM * 100))
Dialog.ZoomIndicator:SetTextColor(ZOOM_INDICATOR_COLOR.r, ZOOM_INDICATOR_COLOR.g, ZOOM_INDICATOR_COLOR.b, ZOOM_INDICATOR_COLOR.a)
