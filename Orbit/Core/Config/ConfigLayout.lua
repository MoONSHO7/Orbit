local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants

---@class OrbitLayout
Engine.Layout = {}
local Layout = Engine.Layout

-- [ CONTROL POOLING ]-------------------------------------------------------------------------------

Layout.pool = Layout.pool or {}
Layout.sliderPool = Layout.sliderPool or {}
Layout.dropdownPool = Layout.dropdownPool or {}
Layout.buttonPool = Layout.buttonPool or {}
Layout.colorPool = Layout.colorPool or {}
Layout.colorCurvePool = Layout.colorCurvePool or {}
Layout.fontPool = Layout.fontPool or {}
Layout.texturePool = Layout.texturePool or {}
Layout.containerControls = Layout.containerControls or {} -- Container -> List of controls

-- [ SHARED BACKDROP ]-------------------------------------------------------------------------------
Layout.ORBIT_INPUT_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- [ ADVANCED PANEL CONSTANTS ]----------------------------------------------------------------------
Layout.Advanced = {
    PADDING = 16,
    HEADER_HEIGHT = 40,
    TITLE_Y = -70,
    CONTENT_START_Y = -120,
    SECTION_SPACING = 2,
    MUTED = { r = 0.53, g = 0.53, b = 0.53 },
    TAB_EXTRA_WIDTH = 16,
}

function Layout:Reset(container)
    -- Reset specific container
    local controls = self.containerControls[container]
    if controls then
        self:RecycleControls(controls)
        self.containerControls[container] = nil
    end

    -- Restore native UI if container is dialog
    if container and container.OrbitPanel then
        container.OrbitPanel:Hide()
    end

    if container and container.Buttons then
        container.Buttons:Show()
    end
    if container and container.Settings then
        container.Settings:Show()
    end

    if container and container.Layout and container.Settings and container.Settings:IsShown() then
        container:Layout()
    end
end

function Layout:RecycleControls(controls)
    if not controls then
        return
    end
    for _, control in ipairs(controls) do
        control:Hide()
        control:SetParent(nil)
        control:ClearAllPoints()

        if control.OrbitType == "Checkbox" then
            table.insert(self.pool, control)
        elseif control.OrbitType == "Slider" then
            if control.Slider and control.Slider.UnregisterCallback then
                control.Slider:UnregisterCallback("OnValueChanged", control)
            end
            control.OnOrbitChange = nil

            -- MEMORY LEAK FIX: Clean up slider scripts to prevent stale callbacks
            if control.Slider then
                -- Clear innerSlider OnMouseUp
                local innerSlider = control.Slider.Slider
                if innerSlider then
                    innerSlider:SetScript("OnMouseUp", nil)
                end

                -- NOTE: Stepper buttons (Back/Forward) use flag-guarded HookScript
                -- They are hooked once permanently, so we don't clear their scripts.
                -- The hook checks frame.OnOrbitChange which we nil above, so stale
                -- callbacks become no-ops.
            end

            -- Cancel any pending stepper timer
            if control._stepperTimer then
                control._stepperTimer:Cancel()
                control._stepperTimer = nil
            end

            table.insert(self.sliderPool, control)
        elseif control.OrbitType == "Dropdown" then
            table.insert(self.dropdownPool, control)
        elseif control.OrbitType == "Button" then
            table.insert(self.buttonPool, control)
        elseif control.OrbitType == "Color" then
            table.insert(self.colorPool, control)
        elseif control.OrbitType == "ColorCurve" then
            table.insert(self.colorCurvePool, control)
        elseif control.Label and control.Swatch then
            table.insert(self.colorPool, control)
        elseif control.OrbitType == "Font" then
            if control.DropdownFrame then control.DropdownFrame:Hide(); control.DropdownFrame = nil end
            table.insert(self.fontPool, control)
        elseif control.OrbitType == "Texture" then
            if control.DropdownFrame then control.DropdownFrame:Hide(); control.DropdownFrame = nil end
            table.insert(self.texturePool, control)
        end
    end
end

function Layout:AddControl(container, frame)
    frame:SetParent(container)
    frame:ClearAllPoints()
    frame:Show()

    -- Add to scoped list
    self.containerControls[container] = self.containerControls[container] or {}
    table.insert(self.containerControls[container], frame)
end

local LAYOUT_PADDING = 10
local HEADER_WIDGET_HEIGHT = 30
local SPACER_DEFAULT_HEIGHT = 20
local LABEL_FALLBACK_WIDTH = 300
local LABEL_WIDTH_INSET = 20
local LABEL_MIN_HEIGHT = 20
local LABEL_HEIGHT_PAD = 4

function Layout:Stack(container, startY, spacing)
    local y = startY or -LAYOUT_PADDING
    local gap = spacing or LAYOUT_PADDING

    local controls = self.containerControls[container]
    if not controls then
        return 0
    end

    for _, child in ipairs(controls) do
        if child:IsShown() and child:GetParent() == container then
            child:SetPoint("TOPLEFT", container, "TOPLEFT", LAYOUT_PADDING, y)
            child:SetPoint("TOPRIGHT", container, "TOPRIGHT", -LAYOUT_PADDING, y)
            y = y - child:GetHeight() - gap
        end
    end

    return math.abs(y)
end

function Layout:ComputeGridPosition(index, limitPerLine, orientation, width, height, padding)
    -- index: 1-based index of item
    -- limitPerLine: number of items before wrapping (columns for Horizontal, rows for Vertical)
    -- orientation: 0 = Horizontal (Row-major), 1 = Vertical (Column-major)

    local row, col
    if orientation == 0 then
        -- Horizontal: Fill rows left-to-right, wrap to next row
        row = math.floor((index - 1) / limitPerLine)
        col = (index - 1) % limitPerLine
    else
        -- Vertical: Fill columns top-to-bottom, wrap to next column
        col = math.floor((index - 1) / limitPerLine)
        row = (index - 1) % limitPerLine
    end

    local x = col * (width + padding)
    local y = -row * (height + padding)

    return x, y
end

function Layout:ComputeGridContainerSize(numItems, limitPerLine, orientation, width, height, padding)
    -- numItems: Total number of items
    -- limitPerLine: number of items before wrapping (columns for Horizontal, rows for Vertical)
    -- orientation: 0 = Horizontal (Row-major), 1 = Vertical (Column-major)

    local numRows, numCols

    if orientation == 0 then
        -- Horizontal: limitPerLine is COLUMNS
        numCols = limitPerLine
        numRows = math.ceil(numItems / limitPerLine)
        -- Clamp columns to actual items if less in the last row?
        -- No, grid is strictly defined by limitPerLine cols usually, unless items < limit.
        if numItems < limitPerLine then
            numCols = numItems
        end
    else
        -- Vertical: limitPerLine is ROWS
        numRows = limitPerLine
        numCols = math.ceil(numItems / limitPerLine)
        if numItems < limitPerLine then
            numRows = numItems
        end
    end

    local finalW = (numCols * width) + ((math.max(0, numCols - 1)) * padding)
    local finalH = (numRows * height) + ((math.max(0, numRows - 1)) * padding)

    if finalW < 1 then
        finalW = width
    end
    if finalH < 1 then
        finalH = height
    end

    return finalW, finalH
end

-- [ SECTION HEADER ]--------------------------------------------------------------------------------
function Layout:CreateSectionHeader(parent, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(20)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.text:SetPoint("TOPLEFT")
    frame.text:SetPoint("TOPRIGHT")
    frame.text:SetJustifyH("LEFT")
    frame.text:SetText(text)
    frame.OrbitType = "Header"
    return frame
end

-- [ DESCRIPTION ]-----------------------------------------------------------------------------------
function Layout:CreateDescription(parent, text, color)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(20)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOPLEFT")
    frame.text:SetPoint("TOPRIGHT")
    frame.text:SetJustifyH("LEFT")
    frame.text:SetWordWrap(true)
    frame.text:SetNonSpaceWrap(true)
    frame.text:SetText(text)
    if color then
        frame.text:SetTextColor(color.r, color.g, color.b, color.a or 1)
    else
        frame.text:SetTextColor(0.53, 0.53, 0.53, 1)
    end
    -- Defer text width until the frame resolves its anchor-based size
    frame:SetScript("OnSizeChanged", function(self, w)
        if w > 1 then
            self.text:SetWidth(w)
            self:SetHeight(math.max(16, self.text:GetStringHeight() + 4))
        end
    end)
    frame.OrbitType = "Description"
    return frame
end

-- [ ACCORDION ]-------------------------------------------------------------------------------------
local ACCORDION_BAR_HEIGHT = 30
function Layout:CreateAccordion(parent, name)
    local section = CreateFrame("Frame", nil, parent)
    section:SetHeight(ACCORDION_BAR_HEIGHT)
    section._expanded = false
    section._contentHeight = 1
    -- Bar button
    local bar = CreateFrame("Button", nil, section)
    bar:SetHeight(ACCORDION_BAR_HEIGHT)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT", -20, 0)
    -- 3-piece atlas background
    local left = bar:CreateTexture(nil, "BACKGROUND")
    left:SetAtlas("Options_ListExpand_Left", true)
    left:SetPoint("TOPLEFT")
    local right = bar:CreateTexture(nil, "BACKGROUND")
    right:SetAtlas("Options_ListExpand_Right", true)
    right:SetPoint("TOPRIGHT")
    local mid = bar:CreateTexture(nil, "BACKGROUND")
    mid:SetAtlas("_Options_ListExpand_Middle", true)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("TOPRIGHT", right, "TOPLEFT")
    -- Label
    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 21, 2)
    label:SetText(name)
    -- Content container
    local body = CreateFrame("Frame", nil, section)
    body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
    body:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -4)
    body:SetHeight(1)
    body:Hide()
    -- Internal updater
    local function UpdateVisual()
        right:SetAtlas(section._expanded and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right", true)
        body:SetShown(section._expanded)
        section:SetHeight(section._expanded and (ACCORDION_BAR_HEIGHT + section._contentHeight + 4) or ACCORDION_BAR_HEIGHT)
    end
    -- Toggle
    bar:SetScript("OnClick", function()
        section._expanded = not section._expanded
        UpdateVisual()
        if section._onToggle then section._onToggle() end
    end)
    -- Public API
    function section:GetBody() return body end
    function section:SetContentHeight(h)
        self._contentHeight = h
        body:SetHeight(h)
        UpdateVisual()
    end
    function section:IsExpanded() return self._expanded end
    function section:SetExpanded(state)
        self._expanded = state
        UpdateVisual()
        if self._onToggle then self._onToggle() end
    end
    section.OrbitType = "Accordion"
    return section
end

-- [ SCROLL AREA ]-----------------------------------------------------------------------------------
function Layout:CreateScrollArea(parent, topY, bottomPad)
    local A = self.Advanced
    topY = topY or A.CONTENT_START_Y
    bottomPad = bottomPad or A.PADDING
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", A.PADDING, topY)
    scrollFrame:SetPoint("BOTTOMRIGHT", -A.PADDING - 14, bottomPad)
    if scrollFrame.ScrollBar then scrollFrame.ScrollBar:SetAlpha(0) end
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:SetScript("OnSizeChanged", function(self, w) scrollChild:SetWidth(w) end)
    -- Helper: update child height and toggle scrollbar
    function scrollFrame:UpdateContentHeight(h)
        scrollChild:SetHeight(h)
        if self.ScrollBar then
            self.ScrollBar:SetAlpha(h > self:GetHeight() and 1 or 0)
        end
    end
    return scrollFrame, scrollChild
end

-- [ WIDGET FACTORY ]--------------------------------------------------------------------------------

Layout.creators = {}

function Layout:RegisterWidgetType(typeName, creator)
    local normalizedType = string.lower(typeName)
    self.creators[normalizedType] = creator
end

function Layout:HasWidgetType(typeName)
    local normalizedType = string.lower(typeName)
    return self.creators[normalizedType] ~= nil
end

function Layout:CreateWidget(container, def, getValue, callback)
    if not def or not def.type then
        return nil
    end

    local normalizedType = string.lower(def.type)
    local creator = self.creators[normalizedType]

    if not creator then
        error("Orbit Layout: Unknown widget type: " .. tostring(def.type))
    end

    return creator(container, def, getValue, callback)
end

function Layout:GetRegisteredTypes()
    local types = {}
    for typeName in pairs(self.creators) do
        table.insert(types, typeName)
    end
    return types
end

-- Initialize default widget creators
function Layout:InitializeWidgetTypes()
    self:RegisterWidgetType("checkbox", function(container, def, getValue, callback)
        return self:CreateCheckbox(container, def.label, def.tooltip, getValue(), callback)
    end)

    self:RegisterWidgetType("slider", function(container, def, getValue, callback)
        local slider = self:CreateSlider(container, def.label, def.min, def.max, def.step, def.formatter, getValue(), callback, def)
        if slider then slider.SettingKey = def.key end
        return slider
    end)

    self:RegisterWidgetType("dropdown", function(container, def, getValue, callback)
        local options = def.options
        if type(options) == "function" then
            options = options()
        end
        return self:CreateDropdown(container, def.label, options, getValue(), callback)
    end)

    self:RegisterWidgetType("color", function(container, def, getValue, callback)
        local widget = self:CreateColorCurvePicker(container, def.label, getValue(), callback)
        if widget then widget.singleColorMode = true; widget.hasDesaturation = def.hasDesaturation end
        return widget
    end)

    self:RegisterWidgetType("colorcurve", function(container, def, getValue, callback)
        local widget = self:CreateColorCurvePicker(container, def.label, getValue(), callback)
        if widget then
            widget.singleColorMode = def.singleColor
            widget.hasDesaturation = def.hasDesaturation
        end
        return widget
    end)

    self:RegisterWidgetType("solidcolor", function(container, def, getValue, callback)
        local opts = { compact = def.compact, allowClear = def.allowClear }
        return self:CreateColorPicker(container, def.label, getValue(), callback, opts)
    end)

    self:RegisterWidgetType("button", function(container, def, getValue, callback)
        return self:CreateButton(container, def.text, callback, def.width)
    end)

    self:RegisterWidgetType("texture", function(container, def, getValue, callback)
        return self:CreateTexturePicker(container, def.label, getValue(), callback, def.previewColor)
    end)

    self:RegisterWidgetType("font", function(container, def, getValue, callback)
        return self:CreateFontPicker(container, def.label, getValue(), callback)
    end)

    self:RegisterWidgetType("editbox", function(container, def, getValue, callback)
        return self:CreateEditBox(container, def.label, getValue(), callback, def.width, def.height, def.multiline, def)
    end)

    self:RegisterWidgetType("header", function(container, def)
        local frame = CreateFrame("Frame", nil, container)
        frame:SetHeight(HEADER_WIDGET_HEIGHT)
        frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
        frame.text:SetPoint("LEFT", 0, 0)
        frame.text:SetText(def.text or def.label)
        frame.OrbitType = "Header"
        return frame
    end)

    self:RegisterWidgetType("spacer", function(container, def)
        local frame = CreateFrame("Frame", nil, container)
        frame:SetHeight(def.height or SPACER_DEFAULT_HEIGHT)
        frame.OrbitType = "Spacer"
        return frame
    end)

    self:RegisterWidgetType("label", function(container, def)
        local frame = CreateFrame("Frame", nil, container)
        frame.text = frame:CreateFontString(nil, "ARTWORK", Constants.UI.LabelFont)
        frame.text:SetPoint("TOPLEFT", 0, 0)
        frame.text:SetJustifyH("LEFT")
        frame.text:SetWordWrap(true)
        frame.text:SetNonSpaceWrap(true)
        local containerWidth = container:GetWidth() or LABEL_FALLBACK_WIDTH
        frame.text:SetWidth(containerWidth - LABEL_WIDTH_INSET)
        frame.text:SetText(def.text or "")
        local textHeight = frame.text:GetStringHeight()
        frame:SetHeight(math.max(LABEL_MIN_HEIGHT, textHeight + LABEL_HEIGHT_PAD))
        frame.OrbitType = "Label"
        return frame
    end)

    -- [ TABS WIDGET ]-----------------------------------------------------------------------------------
    local TAB_HEIGHT = 24
    local TAB_SPACING = 4
    local TAB_TEXT_PADDING = 30
    local TAB_ACTIVE_COLOR = { r = 1, g = 0.82, b = 0 }
    local TAB_INACTIVE_COLOR = { r = 1, g = 1, b = 1 }
    local TAB_DIVIDER_COLOR = { r = 0.3, g = 0.3, b = 0.3 }
    local TAB_DIVIDER_HEIGHT = 1
    local TAB_BOTTOM_PADDING = 4
    local TAB_HIGHLIGHT_ATLAS = "transmog-tab-hl"

    local function ApplyTabState(btn, isActive)
        if isActive then
            btn.Text:SetTextColor(TAB_ACTIVE_COLOR.r, TAB_ACTIVE_COLOR.g, TAB_ACTIVE_COLOR.b)
            btn:Disable()
            btn.highlight:Show()
        else
            btn.Text:SetTextColor(TAB_INACTIVE_COLOR.r, TAB_INACTIVE_COLOR.g, TAB_INACTIVE_COLOR.b)
            btn:Enable()
            btn.highlight:Hide()
        end
    end

    function Layout:CreateTabBar(parent, dividerParent, tabNames, activeTab, onTabSelected)
        local buttons = {}
        local lastBtn = nil
        for _, tabName in ipairs(tabNames) do
            local btn = CreateFrame("Button", nil, parent, "MinimalTabTemplate")
            btn:SetHeight(TAB_HEIGHT)
            btn.Text:SetText(tabName)
            btn:SetWidth(btn.Text:GetStringWidth() + TAB_TEXT_PADDING)

            if lastBtn then
                btn:SetPoint("LEFT", lastBtn, "RIGHT", TAB_SPACING, 0)
            else
                btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            end

            local hlFrame = CreateFrame("Frame", nil, btn)
            hlFrame:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, -1)
            hlFrame:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, -1)
            hlFrame:SetHeight(TAB_DIVIDER_HEIGHT)
            hlFrame:SetFrameLevel(btn:GetFrameLevel() + 10)
            local hlTex = hlFrame:CreateTexture(nil, "ARTWORK")
            hlTex:SetAtlas(TAB_HIGHLIGHT_ATLAS)
            hlTex:SetAllPoints(hlFrame)
            btn.highlight = hlFrame

            ApplyTabState(btn, tabName == activeTab)

            btn:SetScript("OnClick", function()
                if onTabSelected then onTabSelected(tabName) end
            end)

            buttons[#buttons + 1] = btn
            lastBtn = btn
        end

        local divider = parent:CreateTexture(nil, "OVERLAY")
        divider:SetColorTexture(TAB_DIVIDER_COLOR.r, TAB_DIVIDER_COLOR.g, TAB_DIVIDER_COLOR.b, 1)
        divider:SetHeight(TAB_DIVIDER_HEIGHT)
        divider:SetPoint("TOP", parent, "TOP", 0, -TAB_HEIGHT)
        divider:SetPoint("LEFT", dividerParent, "LEFT", 0, 0)
        divider:SetPoint("RIGHT", dividerParent, "RIGHT", 0, 0)

        return buttons, divider
    end

    function Layout:UpdateTabBar(buttons, activeTab)
        for _, btn in ipairs(buttons) do
            ApplyTabState(btn, btn.Text:GetText() == activeTab)
        end
    end

    -- [ EYE TOGGLE CONSTANTS ]--------------------------------------------------------------------------
    local EYE_SIZE = TAB_HEIGHT
    local FLIPBOOK_ATLAS = "groupfinder-eye-flipbook-found-initial"
    -- From Blizzard QueueStatusFrame.xml: flipBookRows=7, flipBookColumns=11, flipBookFrames=70, duration=2
    local FLIPBOOK_COLS = 11
    local FLIPBOOK_ROWS = 7
    local FLIPBOOK_TOTAL = 70
    local FLIPBOOK_FPS = 35
    local FRAME_W = 1 / FLIPBOOK_COLS
    local FRAME_H = 1 / FLIPBOOK_ROWS

    local function EyeSetFrame(eye, idx)
        local col = idx % FLIPBOOK_COLS
        local row = math.floor(idx / FLIPBOOK_COLS)
        eye.tex:SetTexCoord(col * FRAME_W, (col + 1) * FRAME_W, row * FRAME_H, (row + 1) * FRAME_H)
    end

    local function EyeSetClosed(eye) EyeSetFrame(eye, 0) end
    local function EyeSetOpen(eye) EyeSetFrame(eye, FLIPBOOK_TOTAL - 1) end

    local function EyePlayFlipbook(eye)
        if eye.animating then return end
        eye.animating = true
        local idx = 0
        eye.flipTicker = C_Timer.NewTicker(1 / FLIPBOOK_FPS, function()
            idx = idx + 1
            if idx >= FLIPBOOK_TOTAL then
                eye.flipTicker:Cancel(); eye.flipTicker = nil; eye.animating = false
                EyeSetOpen(eye)
                return
            end
            EyeSetFrame(eye, idx)
        end)
    end

    self:RegisterWidgetType("tabs", function(container, def)
        local frame = CreateFrame("Frame", nil, container)
        frame:SetHeight(TAB_HEIGHT + TAB_DIVIDER_HEIGHT + TAB_BOTTOM_PADDING)
        frame.OrbitType = "Tabs"
        Layout:CreateTabBar(frame, container, def.tabs, def.activeTab, def.onTabSelected)

        -- Eye toggle: preview animator on/off
        local plugin = def.plugin
        if plugin and plugin.StartPreviewAnimation then
            local PA = Orbit.PreviewAnimator
            local dialog = container:GetParent() and container:GetParent():GetParent()
            -- Reuse existing eye button across tab re-renders
            local eye = dialog and dialog.orbitEyeToggle
            if not eye then
                eye = CreateFrame("Button", nil, frame)
                eye:SetSize(EYE_SIZE, EYE_SIZE)
                eye.tex = eye:CreateTexture(nil, "ARTWORK")
                eye.tex:SetAllPoints()
                eye.tex:SetAtlas(FLIPBOOK_ATLAS)
                EyeSetClosed(eye)
                eye.animating = false
                eye.active = false
                eye:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.active and "Stop Preview Animation" or "Start Preview Animation")
                    GameTooltip:Show()
                end)
                eye:SetScript("OnLeave", function() GameTooltip:Hide() end)
                if dialog then dialog.orbitEyeToggle = eye end
            end
            eye:SetParent(frame)
            eye:ClearAllPoints()
            eye:SetPoint("RIGHT", frame, "RIGHT", 0, -2)
            eye:Show()
            -- Sync visual state with PA
            if PA:IsEnabled(plugin) then EyeSetOpen(eye); eye.active = true
            else EyeSetClosed(eye); eye.active = false end
            eye:SetScript("OnClick", function(btn)
                if btn.active then
                    if btn.flipTicker then btn.flipTicker:Cancel(); btn.flipTicker = nil end
                    btn.animating = false; btn.active = false
                    EyeSetClosed(btn)
                    PA:ExitAll(plugin)
                else
                    btn.active = true
                    PA:SetEnabled(plugin, true)
                    EyePlayFlipbook(btn)
                    plugin:StartPreviewAnimation()
                end
            end)
        end

        return frame
    end)

    self:RegisterWidgetType("description", function(container, def)
        local frame = CreateFrame("Frame", nil, container)
        frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        frame.text:SetPoint("TOPLEFT", 0, 0)
        frame.text:SetJustifyH("LEFT")
        frame.text:SetWordWrap(true)
        frame.text:SetNonSpaceWrap(true)

        -- Calculate accurate width based on Constants to avoid layout race conditions
        local C = Orbit.Constants
        local width = C.Panel.Width - (C.Panel.ContentPadding * 2) - C.Panel.ScrollbarWidth - 10

        frame.text:SetWidth(width)
        frame.text:SetText(def.text or "")

        -- Color support
        if def.color then
            frame.text:SetTextColor(def.color.r, def.color.g, def.color.b, def.color.a or 1)
        else
            frame.text:SetTextColor(0.8, 0.8, 0.8, 1)
        end

        local textHeight = frame.text:GetStringHeight()
        frame:SetHeight(math.max(20, textHeight + 8))
        frame.OrbitType = "Description"
        return frame
    end)
end

-- Initialize on load
Layout:InitializeWidgetTypes()
