-- [ CANVAS MODE COMPONENT SETTINGS ]------------------------------------------------------------
-- Popout settings dialog for customizing component appearance in Canvas Mode
-- Similar to FontPicker pattern: FULLSCREEN_DIALOG strata, click-outside-to-close
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local DIALOG_WIDTH = 300 -- Compact width
local DIALOG_MIN_HEIGHT = 120
local WIDGET_HEIGHT = 28
local WIDGET_SPACING = 4
local PADDING = 20 -- More padding on left/right

-- [ COMPONENT TYPE SCHEMAS ]-------------------------------------------------------------------------

-- Define settings based on component family/type, not individual names

-- Family-based schemas (auto-detected from visual element type)
local TYPE_SCHEMAS = {
    -- FontString elements (Name, HealthText, LevelText, etc.)
    FontString = {
        controls = {
            { type = "font", key = "Font", label = "Font" },
            { type = "slider", key = "FontSize", label = "Size", min = 8, max = 24, step = 1 },
            { type = "checkbox", key = "CustomColor", label = "Custom Color" },
            { type = "colorcurve", key = "CustomColorCurve", label = "Color", showIf = "CustomColor" },
        },
    },
    -- Texture/Icon elements (CombatIcon, RareEliteIcon, etc.)
    Texture = {
        controls = {
            { type = "slider", key = "Scale", label = "Scale", min = 0.5, max = 2.0, step = 0.1,
                formatter = function(v) return math.floor(v * 100 + 0.5) .. "%" end },
        },
    },
}

-- Display names for components (just for the title)
local COMPONENT_TITLES = {
    Name = "Name Text",
    HealthText = "Health Text",
    LevelText = "Level Text",
    CombatIcon = "Combat Icon",
    RareEliteIcon = "Classification Icon",
    RestingIcon = "Resting Icon",
}

-- Detect component family from visual element
local function GetComponentFamily(container)
    if not container or not container.visual then
        return nil
    end
    local visual = container.visual
    local objType = visual.GetObjectType and visual:GetObjectType()

    if objType == "FontString" then
        return "FontString"
    elseif objType == "Texture" then
        return "Texture"
    end

    return nil
end

-- [ CREATE DIALOG FRAME ]---------------------------------------------------------------------------

local Dialog = CreateFrame("Frame", "OrbitCanvasComponentSettings", UIParent)
Dialog:SetSize(DIALOG_WIDTH, DIALOG_MIN_HEIGHT)
Dialog:SetFrameStrata("FULLSCREEN_DIALOG")
Dialog:SetFrameLevel(500) -- Above Canvas Mode dialog
Dialog:SetClampedToScreen(true)
Dialog:EnableMouse(true)
Dialog:Hide()

-- Border using Blizzard's high-quality template
Dialog.Border = CreateFrame("Frame", nil, Dialog, "DialogBorderTranslucentTemplate")
Dialog.Border:SetAllPoints(Dialog)
Dialog.Border:SetFrameLevel(Dialog:GetFrameLevel())

-- Title
Dialog.Title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
Dialog.Title:SetPoint("TOP", Dialog, "TOP", 0, -PADDING)

-- Content container for widgets
Dialog.Content = CreateFrame("Frame", nil, Dialog)
Dialog.Content:SetPoint("TOPLEFT", Dialog, "TOPLEFT", PADDING, -PADDING - 24)
Dialog.Content:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -PADDING, PADDING)

-- Widget pool
Dialog.widgets = {}

-- [ CLOSE BEHAVIOR ]-------------------------------------------------------------------------------

-- ESC key
Dialog:SetPropagateKeyboardInput(true)
Dialog:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        self:SetPropagateKeyboardInput(false)
        self:Hide()
        C_Timer.After(0.05, function()
            if not InCombatLockdown() then
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end
end)

-- Click outside to close (via OnUpdate check)
Dialog:SetScript("OnUpdate", function(self)
    -- Don't close while ColorPickerFrame is open (user may be dragging colors)
    if ColorPickerFrame and ColorPickerFrame:IsShown() then
        return
    end

    if not self:IsMouseOver() and IsMouseButtonDown("LeftButton") then
        -- Check if clicking on the parent Canvas Mode dialog
        local canvasDialog = Orbit.CanvasModeDialog
        if canvasDialog and canvasDialog:IsMouseOver() then
            -- Clicked on canvas dialog, close this popout
            self:Hide()
        end
    end
end)

Dialog:SetScript("OnHide", function(self)
    -- Clear references
    self.componentKey = nil
    self.container = nil
    self.plugin = nil
    self.systemIndex = nil
    self.currentOverrides = nil
    self.widgetsByKey = nil

    -- Hide all widgets
    for _, widget in ipairs(self.widgets) do
        widget:Hide()
    end
end)

-- [ WIDGET CREATION HELPERS ]-----------------------------------------------------------------------

local function CreateSliderWidget(parent, control, currentValue, callback)
    if not Layout or not Layout.CreateSlider then
        return nil
    end

    local widget = Layout:CreateSlider(
        parent,
        control.label,
        control.min,
        control.max,
        control.step or 1,
        control.formatter,
        currentValue or control.min,
        function(value)
            if callback then
                callback(control.key, value)
            end
        end
    )

    if widget then
        widget:SetHeight(32)
    end

    return widget
end

local function CreateCheckboxWidget(parent, control, currentValue, callback)
    if not Layout or not Layout.CreateCheckbox then
        return nil
    end

    local widget = Layout:CreateCheckbox(
        parent,
        control.label,
        nil, -- tooltip
        currentValue or false,
        function(checked)
            if callback then
                callback(control.key, checked)
            end
        end
    )

    if widget then
        widget:SetHeight(30)
    end

    return widget
end

local function CreateFontPickerWidget(parent, control, currentValue, callback)
    if Layout and Layout.CreateFontPicker then
        local widget = Layout:CreateFontPicker(parent, control.label, currentValue, function(fontName)
            if callback then
                callback(control.key, fontName)
            end
        end)
        if widget then
            widget:SetHeight(32)
        end
        return widget
    end

    -- Fallback: simple label if FontPicker not available
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(WIDGET_HEIGHT)
    frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Label:SetText(control.label .. ": " .. (currentValue or "Default"))
    return frame
end

local function CreateColorPickerWidget(parent, control, currentValue, callback)
    if Layout and Layout.CreateColorPicker then
        -- Ensure initialColor is a proper table
        local initialColor = currentValue
        if type(currentValue) ~= "table" then
            initialColor = { r = 1, g = 1, b = 1, a = 1 }
        end

        local widget = Layout:CreateColorPicker(parent, control.label, initialColor, function(color)
            if callback then
                callback(control.key, color)
            end
        end)
        if widget then
            widget:SetHeight(32)
        end
        return widget
    end

    -- Fallback: simple label if ColorPicker not available
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(WIDGET_HEIGHT)
    frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Label:SetText(control.label .. ": (unavailable)")
    return frame
end

-- [ OPEN DIALOG ]-----------------------------------------------------------------------------------

function Dialog:Open(componentKey, container, plugin, systemIndex)
    if InCombatLockdown() then
        return
    end

    -- Store references
    self.componentKey = componentKey
    self.container = container
    self.plugin = plugin
    self.systemIndex = systemIndex or 1

    -- Auto-detect component family from visual element
    local family = GetComponentFamily(container)
    local schema = family and TYPE_SCHEMAS[family]

    if not schema then
        -- Unknown component type, show generic message
        local title = COMPONENT_TITLES[componentKey] or componentKey
        self.Title:SetText(title .. " (no settings)")
        self:SetHeight(80)

        -- Position to the LEFT of the Canvas Mode dialog
        self:ClearAllPoints()
        local canvasDialog = Orbit.CanvasModeDialog
        if canvasDialog and canvasDialog:IsShown() then
            self:SetPoint("TOPRIGHT", canvasDialog, "TOPLEFT", -10, 0)
        else
            self:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
        end

        self:Show()
        return
    end

    -- Set title from component name lookup or use key
    local title = COMPONENT_TITLES[componentKey] or componentKey
    self.Title:SetText(title)

    -- Get current overrides: first check container's in-memory state, then fall back to saved
    if container.pendingOverrides then
        -- Overrides set during this session (not yet saved)
        self.currentOverrides = container.pendingOverrides
    elseif container.existingOverrides then
        -- Overrides loaded from saved data when container was created
        self.currentOverrides = container.existingOverrides
    else
        -- Fall back to plugin saved data
        local savedPositions = plugin and plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        local posData = savedPositions[componentKey] or {}
        self.currentOverrides = posData.overrides or {}
    end

    -- Hide all existing widgets
    for _, widget in ipairs(self.widgets) do
        widget:Hide()
    end

    -- Create widgets for each control
    local yOffset = 0
    local widgetIndex = 0

    -- Helper to get current value from visual if no override exists
    local function GetValueFromVisual(container, key)
        if not container or not container.visual then
            return nil
        end
        local visual = container.visual

        if key == "FontSize" and visual.GetFont then
            local _, size = visual:GetFont()
            return size and math.floor(size + 0.5)
        elseif key == "CustomColor" then
            return false -- Default to not using custom color (use global)
        elseif key == "CustomColorValue" and visual.GetTextColor then
            local r, g, b, a = visual:GetTextColor()
            return { r = r, g = g, b = b, a = a or 1 }
        elseif key == "Scale" then
            return 1.0 -- Default scale
        end
        return nil
    end

    for _, control in ipairs(schema.controls) do
        widgetIndex = widgetIndex + 1
        local widget = nil

        local currentValue = self.currentOverrides[control.key]

        -- Get default value from plugin defaults if no override
        if currentValue == nil and plugin and plugin.defaults then
            local compDefaults = plugin.defaults.ComponentSettings and plugin.defaults.ComponentSettings[componentKey]
            if compDefaults then
                currentValue = compDefaults[control.key]
            end
        end

        -- Fallback to reading from visual or sane defaults
        if currentValue == nil then
            currentValue = GetValueFromVisual(container, control.key)
        end

        local callback = function(key, value)
            self:OnValueChanged(key, value)
        end

        -- Use Orbit Layout widgets for consistent styling
        if control.type == "slider" then
            widget = CreateSliderWidget(self.Content, control, currentValue or control.min, callback)
        elseif control.type == "checkbox" then
            widget = CreateCheckboxWidget(self.Content, control, currentValue, callback)
        elseif control.type == "font" then
            widget = CreateFontPickerWidget(self.Content, control, currentValue, callback)
        elseif control.type == "color" then
            widget = CreateColorPickerWidget(self.Content, control, currentValue, callback)
        elseif control.type == "colorcurve" then
            if Layout and Layout.CreateColorCurvePicker then
                widget = Layout:CreateColorCurvePicker(self.Content, control.label, currentValue, function(curveData)
                    if callback then
                        callback(control.key, curveData)
                    end
                end)
                if widget then
                    widget:SetHeight(32)
                    widget.singleColorMode = control.singleColor or (componentKey ~= "Timer")
                end
            else
                widget = CreateColorPickerWidget(self.Content, control, currentValue and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(currentValue), callback)
            end
        end

        if widget then
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -yOffset)
            widget:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", 0, -yOffset)

            -- Track widget by key for conditional visibility
            widget.controlKey = control.key
            widget.hideIf = control.hideIf
            widget.showIf = control.showIf
            widget.yOffsetPosition = yOffset

            -- Check conditional visibility (hideIf or showIf)
            local shouldShow = true
            if control.hideIf then
                local hideIfValue = self.currentOverrides[control.hideIf]
                shouldShow = not hideIfValue
            elseif control.showIf then
                local showIfValue = self.currentOverrides[control.showIf]
                shouldShow = showIfValue == true
            end

            if shouldShow then
                widget:Show()
                yOffset = yOffset + widget:GetHeight() + WIDGET_SPACING
            else
                widget:Hide()
            end

            self.widgets[widgetIndex] = widget

            -- Track by key for later updating
            if not self.widgetsByKey then
                self.widgetsByKey = {}
            end
            self.widgetsByKey[control.key] = widget
        end
    end

    -- Size dialog to fit content
    local contentHeight = yOffset + PADDING * 2 + 24 -- padding + title
    self:SetHeight(math.max(DIALOG_MIN_HEIGHT, contentHeight + 20))

    -- Position to the LEFT of the Canvas Mode dialog
    self:ClearAllPoints()
    local canvasDialog = Orbit.CanvasModeDialog
    if canvasDialog and canvasDialog:IsShown() then
        self:SetPoint("TOPRIGHT", canvasDialog, "TOPLEFT", -10, 0)
    elseif container then
        self:SetPoint("TOPRIGHT", container, "TOPLEFT", -10, 0)
    else
        self:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    end

    -- Apply existing overrides to preview (e.g., show class color if already enabled)
    if self.currentOverrides and next(self.currentOverrides) then
        self:ApplyAll(container, self.currentOverrides)
    end

    self:Show()
end

-- [ VALUE CHANGE HANDLER ]--------------------------------------------------------------------------

function Dialog:OnValueChanged(key, value)
    if not self.componentKey then
        return
    end

    -- Update current overrides
    self.currentOverrides = self.currentOverrides or {}
    self.currentOverrides[key] = value

    -- Handle conditional visibility (hideIf or showIf) and recalculate height
    if self.widgetsByKey then
        local needsHeightRecalc = false
        for widgetKey, widget in pairs(self.widgetsByKey) do
            if widget.hideIf and widget.hideIf == key then
                if value then
                    widget:Hide()
                else
                    widget:Show()
                end
                needsHeightRecalc = true
            elseif widget.showIf and widget.showIf == key then
                if value then
                    widget:Show()
                else
                    widget:Hide()
                end
                needsHeightRecalc = true
            end
        end

        -- Recalculate dialog height if visibility changed
        if needsHeightRecalc then
            local yOffset = 0
            for _, widget in ipairs(self.widgets) do
                if widget:IsShown() then
                    widget:ClearAllPoints()
                    widget:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -yOffset)
                    widget:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", 0, -yOffset)
                    yOffset = yOffset + widget:GetHeight() + WIDGET_SPACING
                end
            end
            local contentHeight = yOffset + PADDING * 2 + 24
            self:SetHeight(math.max(DIALOG_MIN_HEIGHT, contentHeight + 20))
        end
    end

    -- Store on container for Apply to pick up
    if self.container then
        self.container.pendingOverrides = self.currentOverrides

        -- Apply preview immediately
        self:ApplyStyle(self.container, key, value)
    end
end

-- Apply a single style setting to a component container
function Dialog:ApplyStyle(container, key, value)
    if not container or not container.visual then
        return
    end

    local visual = container.visual

    -- Apply style based on key
    if key == "FontSize" and visual.SetFont then
        local font, _, flags = visual:GetFont()
        flags = (flags and flags ~= "") and flags or "OUTLINE"
        visual:SetFont(font, value, flags)

        -- Resize container to match new text dimensions
        C_Timer.After(0.01, function()
            if container and visual and visual.GetStringWidth then
                local textWidth = visual:GetStringWidth() or (value * 3)
                local textHeight = visual:GetStringHeight() or value
                container:SetSize(textWidth + 2, textHeight + 2)
            end
        end)
    elseif key == "Font" and visual.SetFont then
        local fontPath = LSM:Fetch("font", value)
        if fontPath then
            local _, size, flags = visual:GetFont()
            flags = (flags and flags ~= "") and flags or "OUTLINE"
            visual:SetFont(fontPath, size or 12, flags)

            -- Resize container to match new text dimensions
            C_Timer.After(0.01, function()
                if container and visual and visual.GetStringWidth then
                    local textWidth = visual:GetStringWidth() or ((size or 12) * 3)
                    local textHeight = visual:GetStringHeight() or (size or 12)
                    container:SetSize(textWidth + 2, textHeight + 2)
                end
            end)
        end
    elseif key == "CustomColor" and visual.SetTextColor then
        -- CustomColor checkbox toggled
        if value then
            -- Apply custom color value from curve
            local customColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(self.currentOverrides and self.currentOverrides.CustomColorCurve)
            if customColor then
                visual:SetTextColor(customColor.r or 1, customColor.g or 1, customColor.b or 1, customColor.a or 1)
            else
                visual:SetTextColor(1, 1, 1, 1)
            end
        else
            -- Revert to global font color setting
            local globalSettings = Orbit.db and Orbit.db.GlobalSettings or {}
            local fontColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(globalSettings.FontColorCurve) or { r = 1, g = 1, b = 1, a = 1 }
            visual:SetTextColor(fontColor.r, fontColor.g, fontColor.b, fontColor.a or 1)
        end
    elseif key == "CustomColorCurve" and visual.SetTextColor then
        -- Color curve changed - only apply if CustomColor is enabled
        local useCustom = self.currentOverrides and self.currentOverrides.CustomColor
        local color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(value)
        if useCustom and color then
            visual:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
        end
    elseif key == "Scale" then
        -- For textures, use SetSize (textures don't have SetScale)
        if visual.GetObjectType and visual:GetObjectType() == "Texture" then
            -- Store original size on first scale change
            if not container.originalVisualWidth then
                container.originalVisualWidth = visual:GetWidth()
                container.originalVisualHeight = visual:GetHeight()
            end
            local origW = container.originalVisualWidth or 18
            local origH = container.originalVisualHeight or 18

            -- Must clear all-points anchoring first (textures are set with SetAllPoints)
            visual:ClearAllPoints()
            visual:SetPoint("CENTER", container, "CENTER", 0, 0)
            visual:SetSize(origW * value, origH * value)
        elseif visual.SetScale then
            visual:SetScale(value)
        end
    end
end

-- Apply a table of overrides to a component container
function Dialog:ApplyAll(container, overrides)
    if not container or not overrides then
        return
    end

    -- Set context so ApplyStyle can access related values (e.g., CustomColorValue when CustomColor is enabled)
    local previousOverrides = self.currentOverrides
    self.currentOverrides = overrides

    for key, value in pairs(overrides) do
        self:ApplyStyle(container, key, value)
    end

    -- Restore previous context (in case this is called during dialog interaction)
    self.currentOverrides = previousOverrides
end

-- [ EXPORT ]----------------------------------------------------------------------------------------

Orbit.CanvasComponentSettings = Dialog
OrbitEngine.CanvasComponentSettings = Dialog
