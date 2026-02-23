-- [ CANVAS MODE - VIEWPORT ]--------------------------------------------------------
-- Viewport with zoom/pan controls for Canvas Mode
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local C = CanvasMode.Constants

-- [ PREVIEW CONTAINER ]-------------------------------------------------------------------------
-- Architecture: PreviewContainer > Viewport (clips) > TransformLayer (zoom/pan) > PreviewFrame

-- Calculate viewport bottom offset: Footer(44) + DIALOG_INSET(12) + 2px + Dock(60) + 10px
local FC = Orbit.Constants.Footer
local VIEWPORT_BOTTOM_OFFSET = C.DIALOG_INSET + FC.TopPadding + FC.ButtonHeight + FC.BottomPadding + 2 + C.DOCK_HEIGHT + 10

Dialog.PreviewContainer = CreateFrame("Frame", nil, Dialog)
Dialog.PreviewContainer:SetPoint("TOPLEFT", Dialog, "TOPLEFT", C.VIEWPORT_PADDING, -C.TITLE_HEIGHT)
Dialog.PreviewContainer:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -C.VIEWPORT_PADDING, VIEWPORT_BOTTOM_OFFSET)

-- Transmog-style background
Dialog.PreviewContainer.Background = Dialog.PreviewContainer:CreateTexture(nil, "BACKGROUND")
Dialog.PreviewContainer.Background:SetAtlas("transmog-tabs-frame-bg")
Dialog.PreviewContainer.Background:SetPoint("TOPLEFT", 4, -4)
Dialog.PreviewContainer.Background:SetPoint("BOTTOMRIGHT", -4, 4)

-- Transmog-style golden border (on high-level overlay to render above preview content)
Dialog.BorderOverlay = CreateFrame("Frame", nil, Dialog.PreviewContainer)
Dialog.BorderOverlay:SetAllPoints()
Dialog.BorderOverlay:SetFrameLevel(Dialog.PreviewContainer:GetFrameLevel() + 100)
Dialog.PreviewContainer.Border = Dialog.BorderOverlay:CreateTexture(nil, "OVERLAY")
Dialog.PreviewContainer.Border:SetAtlas("transmog-tabs-frame")
Dialog.PreviewContainer.Border:SetPoint("TOPLEFT", Dialog.PreviewContainer, "TOPLEFT", -11, 12)
Dialog.PreviewContainer.Border:SetPoint("BOTTOMRIGHT", Dialog.PreviewContainer, "BOTTOMRIGHT", 11, -12)

-- [ FILTER TAB BAR ]------------------------------------------------------------------------

local FILTER_TABS = { "All", "Text", "Icons", "Auras" }
local FILTER_TAB_ACTIVE_COLOR = { r = 1.0, g = 0.82, b = 0.0 }
local FILTER_TAB_INACTIVE_COLOR = { r = 0.8, g = 0.8, b = 0.8 }
local FILTER_TAB_TEXT_PADDING = 20
local FILTER_TAB_HIGHLIGHT_ATLAS = "transmog-tab-hl"

local function ApplyFilterTabState(btn, isActive)
    local c = isActive and FILTER_TAB_ACTIVE_COLOR or FILTER_TAB_INACTIVE_COLOR
    btn.Text:SetTextColor(c.r, c.g, c.b)
    if btn.highlight then btn.highlight:SetShown(isActive) end
end

Dialog.FilterTabBar = CreateFrame("Frame", nil, Dialog)
Dialog.FilterTabBar:SetPoint("TOPLEFT", Dialog, "TOPLEFT", C.VIEWPORT_PADDING + 30, C.FILTER_TAB_TOP_OFFSET)
Dialog.FilterTabBar:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", -C.VIEWPORT_PADDING, C.FILTER_TAB_TOP_OFFSET)
Dialog.FilterTabBar:SetHeight(C.FILTER_TAB_HEIGHT)
Dialog.FilterTabBar:SetFrameLevel(Dialog:GetFrameLevel() + 200)
Dialog.FilterTabBar:Hide()

Dialog.filterTabButtons = {}
local lastFilterBtn = nil
for _, tabName in ipairs(FILTER_TABS) do
    local btn = CreateFrame("Button", nil, Dialog.FilterTabBar, "MinimalTabTemplate")
    btn:SetHeight(C.FILTER_TAB_HEIGHT)
    btn.Text:SetText(tabName)
    btn:SetWidth(btn.Text:GetStringWidth() + FILTER_TAB_TEXT_PADDING)

    if lastFilterBtn then
        btn:SetPoint("LEFT", lastFilterBtn, "RIGHT", C.FILTER_TAB_SPACING, 0)
    else
        btn:SetPoint("TOPLEFT", Dialog.FilterTabBar, "TOPLEFT", 0, 0)
    end

    local hlFrame = CreateFrame("Frame", nil, btn)
    hlFrame:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, -1)
    hlFrame:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, -1)
    hlFrame:SetHeight(1)
    hlFrame:SetFrameLevel(btn:GetFrameLevel() + 10)
    local hlTex = hlFrame:CreateTexture(nil, "ARTWORK")
    hlTex:SetAtlas(FILTER_TAB_HIGHLIGHT_ATLAS)
    hlTex:SetAllPoints(hlFrame)
    btn.highlight = hlFrame

    ApplyFilterTabState(btn, tabName == "All")

    btn:SetScript("OnClick", function()
        Dialog.activeFilter = tabName
        for _, b in ipairs(Dialog.filterTabButtons) do
            ApplyFilterTabState(b, b.filterName == tabName)
        end
        if Dialog.ApplyFilter then Dialog:ApplyFilter(tabName) end
    end)

    btn.filterName = tabName
    Dialog.filterTabButtons[#Dialog.filterTabButtons + 1] = btn
    lastFilterBtn = btn
end


-- Viewport: Clips children to create the viewable area (inset to clip before border)
Dialog.Viewport = CreateFrame("Frame", nil, Dialog.PreviewContainer)
Dialog.Viewport:SetPoint("TOPLEFT", 4, -4)
Dialog.Viewport:SetPoint("BOTTOMRIGHT", -4, 4)
Dialog.Viewport:SetClipsChildren(true)
Dialog.Viewport:EnableMouse(true)
Dialog.Viewport:EnableMouseWheel(true)
Dialog.Viewport:RegisterForDrag("MiddleButton", "LeftButton")

-- TransformLayer: Receives zoom (SetScale) and pan (position offset)
Dialog.TransformLayer = CreateFrame("Frame", nil, Dialog.Viewport)
Dialog.TransformLayer:SetSize(1, 1) -- Size managed dynamically
Dialog.TransformLayer:SetPoint("CENTER", Dialog.Viewport, "CENTER", 0, 0)

-- [ ZOOM/PAN HELPERS ]-----------------------------------------------------------------------

-- Calculate pan clamping bounds
local function GetPanBounds(transformLayer, viewport, zoomLevel)
    local baseWidth = transformLayer.baseWidth or 200
    local baseHeight = transformLayer.baseHeight or 60
    local scaledW = baseWidth * zoomLevel
    local scaledH = baseHeight * zoomLevel
    local viewW = viewport:GetWidth()
    local viewH = viewport:GetHeight()

    -- Allow panning up to the point where preview edge reaches viewport center
    local scale = viewport:GetEffectiveScale()
    local maxX = OrbitEngine.Pixel:Snap(math.max(0, (scaledW / 2) - (viewW / 2) + C.PAN_CLAMP_PADDING), scale)
    local maxY = OrbitEngine.Pixel:Snap(math.max(0, (scaledH / 2) - (viewH / 2) + C.PAN_CLAMP_PADDING), scale)

    return maxX, maxY
end

-- Apply pan with clamping
local function ApplyPanOffset(dialog, offsetX, offsetY)
    local maxX, maxY = GetPanBounds(dialog.TransformLayer, dialog.Viewport, dialog.zoomLevel)

    dialog.panOffsetX = math.max(-maxX, math.min(maxX, offsetX))
    dialog.panOffsetY = math.max(-maxY, math.min(maxY, offsetY))

    dialog.TransformLayer:ClearAllPoints()
    dialog.TransformLayer:SetPoint("CENTER", dialog.Viewport, "CENTER", dialog.panOffsetX, dialog.panOffsetY)
end

-- Apply zoom level
local function ApplyZoom(dialog, newZoom)
    newZoom = math.max(C.MIN_ZOOM, math.min(C.MAX_ZOOM, newZoom))
    -- Round to 2 decimal places
    newZoom = math.floor(newZoom * 100 + 0.5) / 100

    dialog.zoomLevel = newZoom
    dialog.TransformLayer:SetScale(newZoom)

    -- Re-clamp pan after zoom change (visible area may have changed)
    ApplyPanOffset(dialog, dialog.panOffsetX, dialog.panOffsetY)

    -- Update zoom indicator in dock
    if dialog.DisabledDock and dialog.DisabledDock.ZoomIndicator then
        dialog.DisabledDock.ZoomIndicator:SetText(string.format("%.0f%%", newZoom * 100))
    end
end

-- Export helpers for use by other modules
CanvasMode.ApplyZoom = ApplyZoom
CanvasMode.ApplyPanOffset = ApplyPanOffset

-- [ ZOOM HANDLER ]--------------------------------------------------------------------------

Dialog.Viewport:SetScript("OnMouseWheel", function(self, delta)
    local newZoom = Dialog.zoomLevel + (delta * C.ZOOM_STEP)
    ApplyZoom(Dialog, newZoom)
end)

-- [ PAN HANDLERS ]--------------------------------------------------------------------------

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

-- [ SYNC TOGGLE ]--------------------------------------------------------------------------
-- Checkbox for syncing component positions across all action bars

Dialog.SyncToggle = CreateFrame("CheckButton", nil, Dialog.BorderOverlay, "UICheckButtonTemplate")
Dialog.SyncToggle:SetSize(26, 26)
Dialog.SyncToggle:SetPoint("TOPRIGHT", Dialog.PreviewContainer, "TOPRIGHT", -8, -4)
Dialog.SyncToggle:SetFrameLevel(Dialog.BorderOverlay:GetFrameLevel() + 1)
Dialog.SyncToggle:Hide() -- Hidden by default, shown only for plugins that support sync

-- Label to the left of checkbox
Dialog.SyncToggle.label = Dialog.SyncToggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.SyncToggle.label:SetPoint("RIGHT", Dialog.SyncToggle, "LEFT", -2, 0)
Dialog.SyncToggle.label:SetText("Sync")
Dialog.SyncToggle.label:SetTextColor(0.9, 0.9, 0.9, 1)

-- State tracking
Dialog.SyncToggle.isSynced = true

function Dialog.SyncToggle:UpdateVisual()
    self:SetChecked(self.isSynced)
end

Dialog.SyncToggle:SetScript("OnClick", function(self)
    local wasLocal = not self.isSynced
    self.isSynced = self:GetChecked()

    -- Save to plugin setting
    local plugin = Dialog.targetPlugin
    local systemIndex = Dialog.targetSystemIndex
    if plugin and plugin.SetSetting then
        plugin:SetSetting(systemIndex, "UseGlobalTextStyle", self.isSynced)
    end

    -- When switching from Local to Synced, reload canvas with global positions
    if wasLocal and self.isSynced then
        local frame = Dialog.targetFrame
        if frame and plugin then
            -- Re-open to reload with global positions
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
