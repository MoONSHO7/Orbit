-- [ CANVAS MODE - VIEWPORT ]--------------------------------------------------------
-- Viewport with zoom/pan controls for Canvas Mode
-- Row layout: Title > Viewport (Dock | Preview) > Override > Footer
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local C = CanvasMode.Constants
local OVERLAY_LEVEL_BOOST = 100
local INSET_LEFT = 10
local INSET_RIGHT = -6
local INSET_TOP = -27
local INSET_BOTTOM = 3
local FILTER_TAB_INSET = 8
local FILTER_TAB_SPACING = 12

-- [ FILTER CONSTANTS ]------------------------------------------------------------------
local FILTER_TABS = { "All", "Text", "Icons", "Auras" }
local FILTER_TAB_ACTIVE_COLOR = { r = 1.0, g = 0.82, b = 0.0 }
local FILTER_TAB_INACTIVE_COLOR = { r = 0.6, g = 0.6, b = 0.6 }

local function ApplyFilterTabState(btn, isActive)
    local c = isActive and FILTER_TAB_ACTIVE_COLOR or FILTER_TAB_INACTIVE_COLOR
    btn:SetTextColor(c.r, c.g, c.b)
end

-- [ VIEWPORT AREA ]---------------------------------------------------------------------
-- Architecture: PreviewContainer > Viewport (clips) > TransformLayer > PreviewFrame

Dialog.PreviewContainer = CreateFrame("Frame", nil, Dialog)
Dialog.PreviewContainer:SetPoint("TOPLEFT", Dialog, "TOPLEFT", INSET_LEFT, INSET_TOP)
Dialog.PreviewContainer:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", INSET_RIGHT, INSET_TOP)
Dialog.PreviewContainer:SetHeight(C.VIEWPORT_HEIGHT)
-- Recessed NineSlice behind the viewport (slightly larger for depth)
Dialog.Inset = CreateFrame("Frame", nil, Dialog, "InsetFrameTemplate")
Dialog.Inset:SetPoint("TOPLEFT", Dialog, "TOPLEFT", C.BG_INSET_LEFT, -(C.BG_INSET_TOP + 1))
Dialog.Inset:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -C.BG_INSET_RIGHT, C.BG_INSET_BOTTOM + 2)
Dialog.Inset:SetFrameLevel(Dialog:GetFrameLevel() + 1)
Dialog.Inset.NineSlice.layoutType = "InsetFrameTemplate"
NineSliceUtil.ApplyLayoutByName(Dialog.Inset.NineSlice, "InsetFrameTemplate")
if Dialog.Inset.Bg then Dialog.Inset.Bg:Hide() end

-- QuestLogBorderFrame: covers entire content area above the Inset
Dialog.BorderFrame = CreateFrame("Frame", nil, Dialog)
Dialog.BorderFrame:SetPoint("TOPLEFT", Dialog.Inset, "TOPLEFT", -1, 4)
Dialog.BorderFrame:SetPoint("BOTTOMRIGHT", Dialog.Inset, "BOTTOMRIGHT", 2, -3)
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
Dialog.BorderOverlay:SetFrameLevel(Dialog.PreviewContainer:GetFrameLevel() + OVERLAY_LEVEL_BOOST)

-- [ FILTER TAB LABELS (inside viewport overlay) ]---------------------------------------
Dialog.FilterTabBar = Dialog.BorderOverlay -- reuse overlay as logical container
Dialog.filterTabButtons = {}
local lastFilterBtn = nil
for _, tabName in ipairs(FILTER_TABS) do
    local label = Dialog.BorderOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if lastFilterBtn then
        label:SetPoint("LEFT", lastFilterBtn, "RIGHT", FILTER_TAB_SPACING, 0)
    else
        label:SetPoint("TOPLEFT", Dialog.BorderOverlay, "TOPLEFT", FILTER_TAB_INSET, -FILTER_TAB_INSET)
    end
    label:SetText(tabName)
    label.filterName = tabName
    ApplyFilterTabState(label, tabName == "All")

    local hitBtn = CreateFrame("Button", nil, Dialog.BorderOverlay)
    hitBtn:SetAllPoints(label)
    hitBtn:SetScript("OnClick", function()
        Dialog.activeFilter = tabName
        for _, b in ipairs(Dialog.filterTabButtons) do ApplyFilterTabState(b, b.filterName == tabName) end
        if Dialog.ApplyFilter then Dialog:ApplyFilter(tabName) end
    end)

    label.hitButton = hitBtn
    Dialog.filterTabButtons[#Dialog.filterTabButtons + 1] = label
    lastFilterBtn = label
end

-- Viewport: clips children to create the viewable area (inset from dock column)
Dialog.Viewport = CreateFrame("Frame", nil, Dialog.PreviewContainer)
Dialog.Viewport:SetPoint("TOPLEFT", 4, -4)
Dialog.Viewport:SetPoint("BOTTOMRIGHT", -4, 4)
Dialog.Viewport:SetClipsChildren(true)
Dialog.Viewport:EnableMouse(true)
Dialog.Viewport:EnableMouseWheel(true)
Dialog.Viewport:RegisterForDrag("MiddleButton", "LeftButton")

-- TransformLayer: receives zoom (SetScale) and pan (position offset)
Dialog.TransformLayer = CreateFrame("Frame", nil, Dialog.Viewport)
Dialog.TransformLayer:SetSize(1, 1)
Dialog.TransformLayer:SetPoint("CENTER", Dialog.Viewport, "CENTER", 0, C.DOCK_Y_OFFSET)

-- [ ROW 4: OVERRIDE SETTINGS CONTAINER ]-------------------------------------------------
-- (Created in Dock.lua after DisabledDock is available)

-- [ DYNAMIC HEIGHT ]---------------------------------------------------------------------

function Dialog:GetViewportTopOffset()
    return -INSET_TOP
end

function Dialog:GetChromeHeight()
    local FC = Orbit.Constants.Footer
    local topOffset = -INSET_TOP
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
    self.PreviewContainer:SetHeight(vpH)

    local chromeH = self:GetChromeHeight()
    local totalHeight = chromeH + vpH

    local top = self:GetTop()
    local left = self:GetLeft()
    if top and left then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end

    self:SetHeight(math.max(C.DIALOG_MIN_HEIGHT, totalHeight))
    self:LayoutFooterButtons()
end

-- [ ZOOM/PAN HELPERS ]-------------------------------------------------------------------

local function GetPanBounds(transformLayer, viewport, zoomLevel)
    local baseWidth = transformLayer.baseWidth or 200
    local baseHeight = transformLayer.baseHeight or 60
    local scaledW = baseWidth * zoomLevel
    local scaledH = baseHeight * zoomLevel
    local viewW = viewport:GetWidth()
    local viewH = viewport:GetHeight()

    local scale = viewport:GetEffectiveScale()
    local maxX = OrbitEngine.Pixel:Snap(math.max(C.MIN_PAN_RANGE, (scaledW / 2) - (viewW / 2) + C.PAN_CLAMP_PADDING), scale)
    local maxY = OrbitEngine.Pixel:Snap(math.max(C.MIN_PAN_RANGE, (scaledH / 2) - (viewH / 2) + C.PAN_CLAMP_PADDING), scale)

    return maxX, maxY
end

local function ApplyPanOffset(dialog, offsetX, offsetY)
    local maxX, maxY = GetPanBounds(dialog.TransformLayer, dialog.Viewport, dialog.zoomLevel)

    dialog.panOffsetX = math.max(-maxX, math.min(maxX, offsetX))
    dialog.panOffsetY = math.max(-maxY, math.min(maxY, offsetY))

    dialog.TransformLayer:ClearAllPoints()
    dialog.TransformLayer:SetPoint("CENTER", dialog.Viewport, "CENTER", dialog.panOffsetX, dialog.panOffsetY + C.DOCK_Y_OFFSET)
end

local function ApplyZoom(dialog, newZoom)
    newZoom = math.max(C.MIN_ZOOM, math.min(C.MAX_ZOOM, newZoom))
    newZoom = math.floor(newZoom * 100 + 0.5) / 100

    dialog.zoomLevel = newZoom
    dialog.TransformLayer:SetScale(newZoom)
    ApplyPanOffset(dialog, dialog.panOffsetX, dialog.panOffsetY)

    if dialog.ZoomIndicator then
        dialog.ZoomIndicator:SetText(string.format("%.0f%%", newZoom * 100))
    end
end

CanvasMode.ApplyZoom = ApplyZoom
CanvasMode.ApplyPanOffset = ApplyPanOffset

-- [ ZOOM HANDLER ]-----------------------------------------------------------------------

Dialog.Viewport:SetScript("OnMouseWheel", function(self, delta)
    local newZoom = Dialog.zoomLevel + (delta * C.ZOOM_STEP)
    ApplyZoom(Dialog, newZoom)
end)

-- [ PAN HANDLERS ]-----------------------------------------------------------------------

Dialog.Viewport:SetScript("OnDragStart", function(self)
    self.isPanning = true
    local mx, my = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self.panStartMouseX = Orbit.Engine.Pixel:Snap(mx / scale, scale)
    self.panStartMouseY = Orbit.Engine.Pixel:Snap(my / scale, scale)
    self.panStartOffsetX = Dialog.panOffsetX
    self.panStartOffsetY = Dialog.panOffsetY
end)

Dialog.Viewport:SetScript("OnDragStop", function(self)
    self.isPanning = false
    ResetCursor()
end)

Dialog.Viewport:SetScript("OnUpdate", function(self)
    if self.isPanning then
        local mx, my = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mx = Orbit.Engine.Pixel:Snap(mx / scale, scale)
        my = Orbit.Engine.Pixel:Snap(my / scale, scale)

        local deltaX = mx - self.panStartMouseX
        local deltaY = my - self.panStartMouseY

        ApplyPanOffset(Dialog, self.panStartOffsetX + deltaX, self.panStartOffsetY + deltaY)
    end
end)

-- [ SYNC TOGGLE ]------------------------------------------------------------------------

Dialog.SyncToggle = CreateFrame("CheckButton", nil, Dialog.BorderOverlay, "UICheckButtonTemplate")
Dialog.SyncToggle:SetSize(26, 26)
Dialog.SyncToggle:SetPoint("TOPRIGHT", Dialog.PreviewContainer, "TOPRIGHT", -8, -4)
Dialog.SyncToggle:SetFrameLevel(Dialog.BorderOverlay:GetFrameLevel() + 1)
Dialog.SyncToggle:Hide()

Dialog.SyncToggle.label = Dialog.SyncToggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.SyncToggle.label:SetPoint("RIGHT", Dialog.SyncToggle, "LEFT", -2, 0)
Dialog.SyncToggle.label:SetText("Sync")
Dialog.SyncToggle.label:SetTextColor(0.9, 0.9, 0.9, 1)

Dialog.SyncToggle.isSynced = true

function Dialog.SyncToggle:UpdateVisual()
    self:SetChecked(self.isSynced)
end

Dialog.SyncToggle:SetScript("OnClick", function(self)
    local wasLocal = not self.isSynced
    self.isSynced = self:GetChecked()

    if wasLocal and self.isSynced then
        local frame = Dialog.targetFrame
        local plugin = Dialog.targetPlugin
        local systemIndex = Dialog.targetSystemIndex
        if frame and plugin then
            Dialog:Open(frame, plugin, systemIndex)
        end
    end
end)

Dialog.SyncToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
    if self.isSynced then
        GameTooltip:SetText("Synced with all Action Bars")
        GameTooltip:AddLine("Changes apply to all synced bars", 0.7, 0.7, 0.7, true)
    else
        GameTooltip:SetText("Local style only")
        GameTooltip:AddLine("Changes apply only to this bar", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end)

Dialog.SyncToggle:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

Dialog.SyncToggle:UpdateVisual()

-- [ ZOOM INDICATOR ]---------------------------------------------------------------------

Dialog.ZoomIndicator = Dialog.BorderOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.ZoomIndicator:SetPoint("BOTTOMRIGHT", Dialog.PreviewContainer, "BOTTOMRIGHT", -10, 8)
Dialog.ZoomIndicator:SetText(string.format("%.0f%%", C.DEFAULT_ZOOM * 100))
Dialog.ZoomIndicator:SetTextColor(0.6, 0.6, 0.6, 1)
