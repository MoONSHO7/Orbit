-- [ CANVAS MODE COMPONENT SETTINGS ] ----------------------------------------------------------------
-- Core module: Open/Close, value routing, layout. Schema/widgets/renderers loaded via CanvasMode.xml.
local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local C = OrbitEngine.CanvasMode.Constants
local L = Orbit.L
local LSM = LibStub("LibSharedMedia-3.0")

-- [ IMPORTS ] ---------------------------------------------------------------------------------------
local Schema = OrbitEngine.CanvasMode.SettingsSchema
local Widgets = OrbitEngine.CanvasMode.SettingsWidgets
local KEY_SCHEMAS = Schema.KEY_SCHEMAS
local TYPE_SCHEMAS = Schema.TYPE_SCHEMAS

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local WIDGET_SPACING = 4
local PADDING = 12
local COMPACT_LABEL_MIN_WIDTH = 50
local COMPACT_LABEL_PAD = 4
local COMPACT_VALUE_WIDTH = 36
local COMPACT_LABEL_GAP = 4
local TITLE_HEIGHT = 20
local CJK_LOCALES = { koKR = true, zhCN = true, zhTW = true }
local CJK_FONT_SIZE_OFFSET = CJK_LOCALES[GetLocale()] and -1 or 0

-- [ MODULE ] ----------------------------------------------------------------------------------------
local Settings = {}
Settings.widgets = {}
Settings.componentKey = nil
Settings.container = nil
Settings.plugin = nil
Settings.systemIndex = nil
Settings.currentOverrides = nil
Settings.widgetsByKey = nil

function Settings:GetColumnCount()
    local canvasDialog = OrbitEngine.CanvasModeDialog
    local w = canvasDialog and canvasDialog:GetWidth() or C.DIALOG_WIDTH
    return w >= C.THREE_COL_THRESHOLD and 3 or 2
end

-- [ OPEN (INLINE) ]----------------------------------------------------------------------------------
function Settings:Open(componentKey, container, plugin, systemIndex)
    if InCombatLockdown() then return end

    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.OverrideContainer then return end

    self.componentKey = componentKey
    self.container = container
    self.plugin = plugin
    self.systemIndex = systemIndex or 1

    local family = Schema.GetComponentFamily(container)
    local schema = KEY_SCHEMAS[componentKey] or (family and TYPE_SCHEMAS[family])

    local overrideContainer = canvasDialog.OverrideContainer

    self:HideWidgets()

    -- Show container early so children have valid parent dimensions
    overrideContainer:SetHeight(TITLE_HEIGHT + PADDING)
    overrideContainer:Show()
    if canvasDialog.ViewportDivider then canvasDialog.ViewportDivider:Show() end

    if not schema then
        overrideContainer.Title:SetText(Schema.ResolveTitle(componentKey) .. " (no settings)")
        canvasDialog:RecalculateHeight()
        return
    end

    overrideContainer.Title:SetText(Schema.ResolveTitle(componentKey))

    -- StatusIcons: static group description to the right of the title
    if componentKey == "StatusIcons" then
        if not overrideContainer.StatusSubtitle then
            local sub = overrideContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sub:SetPoint("LEFT", overrideContainer.Title, "RIGHT", OrbitEngine.Pixel:Multiple(6, overrideContainer:GetEffectiveScale()), 0)
            sub:SetJustifyH("LEFT")
            sub:SetTextColor(1, 1, 1, 0.8)
            overrideContainer.StatusSubtitle = sub
        end
        overrideContainer.StatusSubtitle:SetText(L.CFG_CM_STATUS_ICONS_DESC)
        overrideContainer.StatusSubtitle:Show()
    elseif overrideContainer.StatusSubtitle then
        overrideContainer.StatusSubtitle:Hide()
    end

    -- Unified override loading: overrides first, then plugin-level settings, then pending
    self.currentOverrides = {}
    local savedPositions = plugin and plugin.GetComponentPositions and plugin:GetComponentPositions(systemIndex) or plugin and plugin:GetSetting(systemIndex, "ComponentPositions") or {}
    local savedOverrides = (savedPositions[componentKey] or {}).overrides or {}
    for k, v in pairs(savedOverrides) do
        self.currentOverrides[k] = v
    end
    if container.existingOverrides then
        for k, v in pairs(container.existingOverrides) do
            if self.currentOverrides[k] == nil then
                self.currentOverrides[k] = v
            end
        end
    end
    if plugin then
        for _, control in ipairs(schema.controls) do
            if control.plugin then
                local val = plugin:GetSetting(systemIndex, control.key)
                if val ~= nil then self.currentOverrides[control.key] = val end
            end
        end
    end
    if container.pendingOverrides then
        for k, v in pairs(container.pendingOverrides) do
            self.currentOverrides[k] = v
        end
    end
    if (componentKey == "DifficultyIcon" or componentKey == "DifficultyText") and self.currentOverrides.DifficultyDisplay == nil then
        self.currentOverrides.DifficultyDisplay = plugin and plugin.GetDifficultyDisplay and plugin:GetDifficultyDisplay() or "icon"
    end

    local function GetValueFromVisual(cont, key)
        if not cont or not cont.visual then
            return nil
        end
        local visual = cont.visual
        if key == "Font" and visual.GetFont then
            local fontPath = visual:GetFont()
            if fontPath then
                for name, path in pairs(LSM:HashTable("font")) do
                    if path == fontPath then
                        return name
                    end
                end
            end
        elseif key == "FontSize" and visual.GetFont then
            local _, size = visual:GetFont()
            return size and math.floor(size + 0.5)
        elseif key == "CustomColorValue" and visual.GetTextColor then
            local r, g, b, a = visual:GetTextColor()
            return { r = r, g = g, b = b, a = a or 1 }
        elseif key == "IconSize" and cont.GetWidth then
            return math.floor(cont:GetWidth() + 0.5)
        elseif key == "Scale" then
            return 1.0
        end
        return nil
    end

    local widgetIndex = 0

    for _, control in ipairs(schema.controls) do
        widgetIndex = widgetIndex + 1
        local currentValue = self.currentOverrides[control.key]

        if currentValue == nil and plugin and plugin.defaults then
            local compDefaults = plugin.defaults.ComponentSettings and plugin.defaults.ComponentSettings[componentKey]
            if compDefaults then
                currentValue = compDefaults[control.key]
            end
        end

        if currentValue == nil then
            currentValue = GetValueFromVisual(container, control.key)
        end

        if currentValue == nil and control.key == "CustomColorCurve" then
            local g = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.FontColorCurve
            currentValue = g or { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } }
        end

        local callback = function(key, value) self:OnValueChanged(key, value) end
        local widget

        if control.type == "slider" then
            widget = Widgets.CreateSlider(overrideContainer, control, currentValue or control.min, callback)
        elseif control.type == "checkbox" then
            widget = Widgets.CreateCheckbox(overrideContainer, control, currentValue, callback)
        elseif control.type == "dropdown" then
            if Layout and Layout.CreateDropdown then
                widget = Layout:CreateDropdown(overrideContainer, control.label, control.options, currentValue or control.default, function(value)
                    if callback then
                        callback(control.key, value)
                    end
                end)
                if widget then
                    widget:SetHeight(OrbitEngine.Pixel:Snap(32, widget:GetEffectiveScale()))
                end
            end
        elseif control.type == "font" then
            widget = Widgets.CreateFontPicker(overrideContainer, control, currentValue, callback)
        elseif control.type == "color" then
            widget = Widgets.CreateColorPicker(overrideContainer, control, currentValue, callback)
        elseif control.type == "colorcurve" then
            if Layout and Layout.CreateColorCurvePicker then
                widget = Layout:CreateColorCurvePicker(overrideContainer, control.label, currentValue, function(curveData)
                    if callback then
                        callback(control.key, curveData)
                    end
                end)
                if widget then
                    widget:SetHeight(OrbitEngine.Pixel:Snap(32, widget:GetEffectiveScale()))
                    widget.singleColorMode = control.singleColor ~= false
                    if self.componentKey == "Timer" and self.systemIndex ~= 3 then
                        widget.singleColorMode = true
                    end
                end
            else
                widget = Widgets.CreateColorPicker(
                    overrideContainer,
                    control,
                    currentValue and OrbitEngine.ColorCurve:GetFirstColorFromCurve(currentValue),
                    callback
                )
            end
        end

        if widget then
            if widget.Label and CJK_FONT_SIZE_OFFSET ~= 0 then
                local f, s, flags = widget.Label:GetFont()
                widget.Label:SetFont(f, s + CJK_FONT_SIZE_OFFSET, flags)
            end
            local labelWidth = COMPACT_LABEL_MIN_WIDTH
            if widget.Label and control.type ~= "checkbox" then
                local measured = math.ceil(widget.Label:GetStringWidth()) + COMPACT_LABEL_PAD
                if measured > labelWidth then labelWidth = measured end
                widget.Label:SetWidth(OrbitEngine.Pixel:Snap(labelWidth, widget.Label:GetEffectiveScale()))
            end
            local controlChild = widget.Slider or widget.Control or widget.GradientBar
            if controlChild then
                controlChild:ClearAllPoints()
                controlChild:SetPoint("LEFT", widget.Label, "RIGHT", COMPACT_LABEL_GAP, 0)
                controlChild:SetPoint("RIGHT", widget, "RIGHT", -COMPACT_VALUE_WIDTH, 0)
            end
            if widget.Value then widget.Value:SetWidth(COMPACT_VALUE_WIDTH) end
            if control.type == "checkbox" and widget.Label then
                widget.Label:ClearAllPoints()
                widget.Label:SetPoint("LEFT", widget, "LEFT", COMPACT_LABEL_MIN_WIDTH + COMPACT_LABEL_GAP, 0)
                widget.Label:SetPoint("RIGHT", widget, "RIGHT", 0, 0)
            end
        end

        if widget then
            widget.controlKey = control.key
            widget.hideIf = control.hideIf
            widget.showIf = control.showIf
            widget.showIfValue = control.showIfValue

            local shouldShow = true
            if control.capability and not (self.plugin and self.plugin[control.capability]) then
                shouldShow = false
            end
            if shouldShow and control.hideIf then
                shouldShow = not self.currentOverrides[control.hideIf]
            elseif shouldShow and control.showIf then
                shouldShow = self.currentOverrides[control.showIf] == true
            end
            if shouldShow and control.showIfValue then
                local curVal = self.currentOverrides[control.showIfValue.key]
                if control.showIfValue.values then
                    shouldShow = false
                    for _, v in ipairs(control.showIfValue.values) do if curVal == v then shouldShow = true; break end end
                else
                    shouldShow = curVal == control.showIfValue.value
                end
            end

            self.widgets[widgetIndex] = widget
            self.widgetsByKey = self.widgetsByKey or {}
            self.widgetsByKey[control.key] = widget
            widget:SetShown(shouldShow)
        end
    end

    self:RelayoutWidgets()

    if self.currentOverrides and next(self.currentOverrides) then
        self:ApplyAll(container, self.currentOverrides)
    end
end

-- [ CLOSE (INLINE) ]---------------------------------------------------------------------------------
function Settings:Close()
    self:HideWidgets()
    self.componentKey = nil
    self.container = nil
    self.plugin = nil
    self.systemIndex = nil
    self.currentOverrides = nil
    self.widgetsByKey = nil

    local canvasDialog = OrbitEngine.CanvasModeDialog
    if canvasDialog and canvasDialog.OverrideContainer then
        canvasDialog.OverrideContainer:Hide()
        if canvasDialog.ViewportDivider then canvasDialog.ViewportDivider:Hide() end
        canvasDialog:RecalculateHeight()
    end
end

function Settings:HideWidgets()
    for _, widget in ipairs(self.widgets) do
        widget:Hide()
    end
end

-- [ CONTROL LOOKUP ]---------------------------------------------------------------------------------
function Settings:GetControlDef(key)
    local schema = KEY_SCHEMAS[self.componentKey]
    if not schema then return nil end
    for _, ctrl in ipairs(schema.controls) do
        if ctrl.key == key then
            return ctrl
        end
    end
    return nil
end

function Settings:ApplyPluginPreview()
    local key = self.componentKey
    if key == "CastBar" then
        self:ApplyCastBarPreview()
    elseif key == "Portrait" then
        self:ApplyPortraitPreview()
    elseif key == "HealthText" then
        self:ApplyHealthTextPreview()
    elseif key == "ZoneText" then
        self:ApplyZoneTextPreview()
    end
end

-- [ VALUE CHANGE HANDLER ]---------------------------------------------------------------------------
function Settings:OnValueChanged(key, value)
    if not self.componentKey then return end

    self.currentOverrides = self.currentOverrides or {}
    self.currentOverrides[key] = value

    local schema = KEY_SCHEMAS[self.componentKey]
    local rebuildsPanel = false
    if schema then
        for _, ctrl in ipairs(schema.controls) do
            if ctrl.key == key and ctrl.rebuildsPanel then
                rebuildsPanel = true
                break
            end
        end
    end

    if rebuildsPanel then
        local savedOverrides = {}
        for k, v in pairs(self.currentOverrides) do
            savedOverrides[k] = v
        end
        if self.container then
            self.container.pendingOverrides = savedOverrides
        end
        local control = self:GetControlDef(key)
        if control and control.plugin then
            self.pendingPluginSettings = self.pendingPluginSettings or {}
            self.pendingPluginSettings[key] = value
            if OrbitEngine.CanvasMode.Transaction and OrbitEngine.CanvasMode.Transaction:IsActive() then
                OrbitEngine.CanvasMode.Transaction:Set(key, value)
            end
        elseif OrbitEngine.CanvasMode.Transaction and OrbitEngine.CanvasMode.Transaction:IsActive() and self.componentKey then
            OrbitEngine.CanvasMode.Transaction:SetPositionOverride(self.componentKey, key, value)
        end
        if key == "DifficultyDisplay" and (self.componentKey == "DifficultyIcon" or self.componentKey == "DifficultyText") then
            local plugin = self.plugin
            local systemIndex = self.systemIndex
            local canvasDialog = OrbitEngine.CanvasModeDialog
            -- Persist display choice before canvasDialog:Open() restarts the Transaction.
            plugin:SetSetting(systemIndex, "DifficultyDisplay", value)
            C_Timer.After(0, function()
                if not (canvasDialog and plugin and canvasDialog.targetFrame and canvasDialog:IsShown()) then return end
                canvasDialog:Open(canvasDialog.targetFrame, canvasDialog.targetPlugin, canvasDialog.targetSystemIndex)
                local activeKey = plugin.GetActiveDifficultyCanvasKey and plugin:GetActiveDifficultyCanvasKey()
                local comp = activeKey and canvasDialog.previewComponents and canvasDialog.previewComponents[activeKey]
                if comp then
                    self:Open(activeKey, comp, plugin, systemIndex)
                end
            end)
            return
        end
        self:Open(self.componentKey, self.container, self.plugin, self.systemIndex)
        if self.pendingPluginSettings then
            for k, v in pairs(self.pendingPluginSettings) do
                self.currentOverrides[k] = v
            end
        end
        self:ApplyPluginPreview()
        return
    end

    if self.widgetsByKey then
        local needsHeightRecalc = false
        for _, widget in pairs(self.widgetsByKey) do
            if widget.hideIf and widget.hideIf == key then
                widget:SetShown(not value)
                needsHeightRecalc = true
            elseif widget.showIf and widget.showIf == key then
                widget:SetShown(value == true)
                needsHeightRecalc = true
            elseif widget.showIfValue and widget.showIfValue.key == key then
                if widget.showIfValue.values then
                    local match = false
                    for _, v in ipairs(widget.showIfValue.values) do if value == v then match = true; break end end
                    widget:SetShown(match)
                else
                    widget:SetShown(value == widget.showIfValue.value)
                end
                needsHeightRecalc = true
            end
        end

        if needsHeightRecalc then
            self:RelayoutWidgets()
        end
    end

    if self.container then
        self.container.pendingOverrides = self.currentOverrides

        local control = self:GetControlDef(key)
        if control and control.plugin then
            self.pendingPluginSettings = self.pendingPluginSettings or {}
            self.pendingPluginSettings[key] = value
            -- Stage into transaction for live preview updates
            if OrbitEngine.CanvasMode.Transaction and OrbitEngine.CanvasMode.Transaction:IsActive() then
                OrbitEngine.CanvasMode.Transaction:Set(key, value)
            end
            self:ApplyPluginPreview()
            return
        end

        self:ApplyStyle(self.container, key, value)

        -- Stage overrides into transaction for live preview updates
        local Txn = OrbitEngine.CanvasMode.Transaction
        if Txn and Txn:IsActive() and self.componentKey then
            Txn:SetPositionOverride(self.componentKey, key, value)
        end
    end
end

-- [ RELAYOUT ]---------------------------------------------------------------------------------------
function Settings:RelayoutWidgets()
    if not self.componentKey or not self.widgets then return end
    local canvasDialog = OrbitEngine.CanvasModeDialog
    local oc = canvasDialog and canvasDialog.OverrideContainer
    if not oc then return end
    local COLUMNS = self:GetColumnCount()
    local COLUMN_GAP = 24
    local containerWidth = oc:GetWidth()
    local availableWidth = containerWidth - (2 * C.DIALOG_INSET)
    local totalGap = COLUMN_GAP * (COLUMNS - 1)
    local colWidth = (availableWidth - totalGap) / COLUMNS
    local col = 0
    local rowY = 0
    local rowHeight = 0
    local ocScale = oc:GetEffectiveScale()
    for _, widget in ipairs(self.widgets) do
        if widget:IsShown() then
            local leftX = C.DIALOG_INSET + col * (colWidth + COLUMN_GAP)
            local y = -(rowY + TITLE_HEIGHT)
            local snappedLeftX = OrbitEngine.Pixel:Snap(leftX, ocScale)
            local snappedRightX = OrbitEngine.Pixel:Snap(leftX + colWidth, ocScale)
            local snappedY = OrbitEngine.Pixel:Snap(y, ocScale)
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", oc, "TOPLEFT", snappedLeftX, snappedY)
            widget:SetPoint("TOPRIGHT", oc, "TOPLEFT", snappedRightX, snappedY)
            rowHeight = math.max(rowHeight, widget:GetHeight())
            col = col + 1
            if col >= COLUMNS then
                col = 0
                rowY = rowY + rowHeight + WIDGET_SPACING
                rowHeight = 0
            end
        end
    end
    if col > 0 then
        rowY = rowY + rowHeight + WIDGET_SPACING
    end
    local containerHeight = rowY + TITLE_HEIGHT + PADDING
    oc:SetHeight(OrbitEngine.Pixel:Snap(containerHeight, ocScale))
    if canvasDialog.RecalculateHeight then canvasDialog:RecalculateHeight() end
end

-- [ EXPORT ]-----------------------------------------------------------------------------------------
Orbit.CanvasComponentSettings = Settings
OrbitEngine.CanvasComponentSettings = Settings
