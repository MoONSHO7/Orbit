-- [ CANVAS MODE COMPONENT SETTINGS ]------------------------------------------------------------
-- Inline override settings rendered inside Canvas Mode's OverrideContainer
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local C = OrbitEngine.CanvasMode.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local WIDGET_HEIGHT = 28
local WIDGET_SPACING = 4
local PADDING = 12
local COMPACT_LABEL_WIDTH = 50
local COMPACT_VALUE_WIDTH = 36
local COMPACT_LABEL_GAP = 4
local TITLE_HEIGHT = 20
local PORTRAIT_RING_OVERSHOOT = OrbitEngine.PORTRAIT_RING_OVERSHOOT
local PORTRAIT_RING_DATA = OrbitEngine.PortraitRingData
local PORTRAIT_RING_OPTIONS = OrbitEngine.PortraitRingOptions

-- [ COMPONENT TYPE SCHEMAS ]-------------------------------------------------------------------------

local SCALE_CONTROL = {
    type = "slider", key = "Scale", label = "Scale",
    min = 0.5, max = 2.0, step = 0.1,
    formatter = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
}

local TYPE_SCHEMAS = {
    FontString = {
        controls = {
            { type = "font", key = "Font", label = "Font" },
            { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = "Color", singleColor = false },
        },
    },
    Texture = { controls = { SCALE_CONTROL } },
    IconFrame = { controls = { SCALE_CONTROL } },
}

-- The bard's stat sheet: no gradient, just one solid ink color
local STATIC_TEXT_CONTROLS = {
    { type = "font", key = "Font", label = "Font" },
    { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
    { type = "colorcurve", key = "CustomColorCurve", label = "Color", singleColor = true },
}

local KEY_SCHEMAS = {
    Name = { controls = STATIC_TEXT_CONTROLS },
    Timer = { controls = STATIC_TEXT_CONTROLS },
    Stacks = { controls = STATIC_TEXT_CONTROLS },
    Keybind = { controls = STATIC_TEXT_CONTROLS },
    MacroText = { controls = STATIC_TEXT_CONTROLS },
    Charges = { controls = STATIC_TEXT_CONTROLS },
    ChargeCount = { controls = STATIC_TEXT_CONTROLS },
    Text = { controls = STATIC_TEXT_CONTROLS },
    ["CastBar.Text"] = { controls = STATIC_TEXT_CONTROLS },
    LevelText = {
        controls = {
            { type = "font", key = "Font", label = "Font" },
            { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
        },
    },
    Buffs = {
        controls = {
            { type = "slider", key = "MaxIcons", label = "Max Icons", min = 1, max = 10, step = 1 },
            { type = "slider", key = "IconSize", label = "Icon Size", min = 10, max = 50, step = 1,
              formatter = function(v) return v .. "px" end },
            { type = "slider", key = "MaxRows", label = "Max Rows", min = 1, max = 3, step = 1 },
        },
    },
    Debuffs = {
        controls = {
            { type = "slider", key = "MaxIcons", label = "Max Icons", min = 1, max = 10, step = 1 },
            { type = "slider", key = "IconSize", label = "Icon Size", min = 10, max = 50, step = 1,
              formatter = function(v) return v .. "px" end },
            { type = "slider", key = "MaxRows", label = "Max Rows", min = 1, max = 3, step = 1 },
        },
    },
    Portrait = {
        controls = {
            { type = "dropdown", key = "PortraitStyle", label = "Style", rebuildsPanel = true,
              options = { { text = "2D", value = "2d" }, { text = "3D", value = "3d" } }, default = "3d" },
            { type = "slider", key = "PortraitScale", label = "Scale", min = 50, max = 200, step = 1,
              formatter = function(v) return v .. "%" end, default = 120 },
            { type = "checkbox", key = "PortraitBorder", label = "Border", default = true, showIfValue = { key = "PortraitStyle", value = "3d" } },
            { type = "dropdown", key = "PortraitRing", label = "Ring", showIfValue = { key = "PortraitStyle", value = "2d" },
              options = PORTRAIT_RING_OPTIONS, default = "none" },
            { type = "checkbox", key = "PortraitMirror", label = "Mirror", default = false },
        },
        pluginSettings = true,
    },
    CastBar = {
        controls = {
            { type = "slider", key = "CastBarHeight", label = "Height", min = 8, max = 40, step = 1,
              formatter = function(v) return v .. "px" end },
            { type = "slider", key = "CastBarWidth", label = "Width", min = 50, max = 400, step = 1,
              formatter = function(v) return v .. "px" end },
            { type = "checkbox", key = "CastBarIcon", label = "Icon", default = true },
            { type = "colorcurve", key = "CastBarColorCurve", label = "Color", singleColor = true },
        },
        pluginSettings = true,
    },
    HealthText = {
        controls = {
            { type = "checkbox", key = "ShowHealthValue", label = "Show Health Value", default = true, capability = "supportsHealthText" },
            { type = "dropdown", key = "HealthTextMode", label = "Format", showIf = "ShowHealthValue", capability = "supportsHealthText",
              options = {
                { text = "Percentage", value = "percent" },
                { text = "Short Health", value = "short" },
                { text = "Raw Health", value = "raw" },
                { text = "Short - Percentage", value = "short_and_percent" },
                { text = "Percentage / Short", value = "percent_short" },
                { text = "Percentage / Raw", value = "percent_raw" },
                { text = "Short / Percentage", value = "short_percent" },
                { text = "Short / Raw", value = "short_raw" },
                { text = "Raw / Short", value = "raw_short" },
                { text = "Raw / Percentage", value = "raw_percent" },
              }, default = "percent_short" },
            { type = "font", key = "Font", label = "Font" },
            { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = "Color", singleColor = false },
        },
        pluginSettingKeys = { ShowHealthValue = true, HealthTextMode = true },
    },
}

local COMPONENT_TITLES = {
    Name = "Name Text", HealthText = "Health Text", LevelText = "Level Text",
    CombatIcon = "Combat Icon", RareEliteIcon = "Classification Icon",
    RestingIcon = "Resting Icon", DefensiveIcon = "Defensive Icon",
    CrowdControlIcon = "Crowd Control Icon", Buffs = "Buffs", Debuffs = "Debuffs",
    Portrait = "Portrait", CastBar = "Cast Bar", MarkerIcon = "Raid Marker",
    ["CastBar.Text"] = "Ability Text", ["CastBar.Timer"] = "Cast Timer",
}

local function GetComponentFamily(container)
    if not container or not container.visual then return nil end
    if container.isIconFrame then return "IconFrame" end
    local objType = container.visual.GetObjectType and container.visual:GetObjectType()
    if objType == "FontString" then return "FontString"
    elseif objType == "Texture" then return "Texture" end
    return nil
end

-- [ MODULE ]-------------------------------------------------------------------------------------

local Settings = {}
Settings.widgets = {}
Settings.componentKey = nil
Settings.container = nil
Settings.plugin = nil
Settings.systemIndex = nil
Settings.currentOverrides = nil
Settings.widgetsByKey = nil

-- [ WIDGET CREATION HELPERS ]-----------------------------------------------------------------------

local function CreateSliderWidget(parent, control, currentValue, callback)
    if not Layout or not Layout.CreateSlider then return nil end
    local widget = Layout:CreateSlider(parent, control.label, control.min, control.max, control.step or 1,
        control.formatter, currentValue or control.min, function(value) if callback then callback(control.key, value) end end)
    if widget then widget:SetHeight(32) end
    return widget
end

local function CreateCheckboxWidget(parent, control, currentValue, callback)
    if not Layout or not Layout.CreateCheckbox then return nil end
    local widget = Layout:CreateCheckbox(parent, control.label, nil, currentValue or false,
        function(checked) if callback then callback(control.key, checked) end end)
    if widget then widget:SetHeight(30) end
    return widget
end

local function CreateFontPickerWidget(parent, control, currentValue, callback)
    if Layout and Layout.CreateFontPicker then
        local widget = Layout:CreateFontPicker(parent, control.label, currentValue,
            function(fontName) if callback then callback(control.key, fontName) end end)
        if widget then widget:SetHeight(32) end
        return widget
    end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(WIDGET_HEIGHT)
    frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Label:SetText(control.label .. ": " .. (currentValue or "Default"))
    return frame
end

local function CreateColorPickerWidget(parent, control, currentValue, callback)
    if Layout and Layout.CreateColorPicker then
        local initialColor = type(currentValue) == "table" and currentValue or { r = 1, g = 1, b = 1, a = 1 }
        local widget = Layout:CreateColorPicker(parent, control.label, initialColor,
            function(color) if callback then callback(control.key, color) end end)
        if widget then widget:SetHeight(32) end
        return widget
    end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(WIDGET_HEIGHT)
    frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Label:SetText(control.label .. ": (unavailable)")
    return frame
end

-- [ OPEN (INLINE) ]---------------------------------------------------------------------------------

function Settings:Open(componentKey, container, plugin, systemIndex)
    if InCombatLockdown() then return end

    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.OverrideContainer then return end

    self.componentKey = componentKey
    self.container = container
    self.plugin = plugin
    self.systemIndex = systemIndex or 1

    local family = GetComponentFamily(container)
    local schema = KEY_SCHEMAS[componentKey] or (family and TYPE_SCHEMAS[family])

    local overrideContainer = canvasDialog.OverrideContainer

    self:HideWidgets()

    -- Show container early so children have valid parent dimensions
    overrideContainer:SetHeight(TITLE_HEIGHT + PADDING)
    overrideContainer:Show()

    if not schema then
        overrideContainer.Title:SetText((COMPONENT_TITLES[componentKey] or componentKey) .. " (no settings)")
        canvasDialog:RecalculateHeight()
        return
    end

    overrideContainer.Title:SetText(COMPONENT_TITLES[componentKey] or componentKey)

    local isPluginSettings = schema.pluginSettings
    local pluginSettingKeys = schema.pluginSettingKeys
    if isPluginSettings and plugin then
        self.currentOverrides = {}
        for _, control in ipairs(schema.controls) do
            local val = plugin:GetSetting(systemIndex, control.key)
            if val ~= nil then self.currentOverrides[control.key] = val end
        end
        if container.pendingOverrides then
            for k, v in pairs(container.pendingOverrides) do self.currentOverrides[k] = v end
        end
    elseif pluginSettingKeys and plugin then
        self.currentOverrides = {}
        for _, control in ipairs(schema.controls) do
            if pluginSettingKeys[control.key] then
                local val = plugin:GetSetting(systemIndex, control.key)
                if val ~= nil then self.currentOverrides[control.key] = val end
            end
        end
        local savedPositions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        local savedOverrides = (savedPositions[componentKey] or {}).overrides or {}
        for k, v in pairs(savedOverrides) do self.currentOverrides[k] = v end
        if container.pendingOverrides then
            for k, v in pairs(container.pendingOverrides) do self.currentOverrides[k] = v end
        end
    elseif container.pendingOverrides then
        self.currentOverrides = container.pendingOverrides
    elseif container.existingOverrides then
        self.currentOverrides = container.existingOverrides
    else
        local savedPositions = plugin and plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        self.currentOverrides = (savedPositions[componentKey] or {}).overrides or {}
    end

    local function GetValueFromVisual(cont, key)
        if not cont or not cont.visual then return nil end
        local visual = cont.visual
        if key == "Font" and visual.GetFont then
            local fontPath = visual:GetFont()
            if fontPath then
                for name, path in pairs(LSM:HashTable("font")) do
                    if path == fontPath then return name end
                end
            end
        elseif key == "FontSize" and visual.GetFont then
            local _, size = visual:GetFont()
            return size and math.floor(size + 0.5)
        elseif key == "CustomColorValue" and visual.GetTextColor then
            local r, g, b, a = visual:GetTextColor()
            return { r = r, g = g, b = b, a = a or 1 }
        elseif key == "Scale" then return 1.0 end
        return nil
    end

    -- 2-column grid layout
    local COLUMNS = 2
    local COLUMN_GAP = 24
    local widgetIndex = 0
    local col = 0
    local rowY = 0
    local rowHeight = 0

    for _, control in ipairs(schema.controls) do
        widgetIndex = widgetIndex + 1
        local currentValue = self.currentOverrides[control.key]

        if currentValue == nil and plugin and plugin.defaults then
            local compDefaults = plugin.defaults.ComponentSettings and plugin.defaults.ComponentSettings[componentKey]
            if compDefaults then currentValue = compDefaults[control.key] end
        end

        if currentValue == nil then currentValue = GetValueFromVisual(container, control.key) end

        local callback = function(key, value) self:OnValueChanged(key, value) end
        local widget = nil

        if control.type == "slider" then
            widget = CreateSliderWidget(overrideContainer, control, currentValue or control.min, callback)
        elseif control.type == "checkbox" then
            widget = CreateCheckboxWidget(overrideContainer, control, currentValue, callback)
        elseif control.type == "dropdown" then
            if Layout and Layout.CreateDropdown then
                widget = Layout:CreateDropdown(overrideContainer, control.label, control.options, currentValue or control.default,
                    function(value) if callback then callback(control.key, value) end end)
                if widget then widget:SetHeight(32) end
            end
        elseif control.type == "font" then
            widget = CreateFontPickerWidget(overrideContainer, control, currentValue, callback)
        elseif control.type == "color" then
            widget = CreateColorPickerWidget(overrideContainer, control, currentValue, callback)
        elseif control.type == "colorcurve" then
            if Layout and Layout.CreateColorCurvePicker then
                widget = Layout:CreateColorCurvePicker(overrideContainer, control.label, currentValue,
                    function(curveData) if callback then callback(control.key, curveData) end end)
                if widget then widget:SetHeight(32); widget.singleColorMode = control.singleColor ~= false end
            else
                widget = CreateColorPickerWidget(overrideContainer, control, currentValue and OrbitEngine.ColorCurve:GetFirstColorFromCurve(currentValue), callback)
            end
        end

        if widget then
            if widget.Label and control.type ~= "checkbox" then widget.Label:SetWidth(COMPACT_LABEL_WIDTH) end
            local controlChild = widget.Slider or widget.Control or widget.GradientBar
            if controlChild then
                controlChild:ClearAllPoints()
                controlChild:SetPoint("LEFT", widget.Label, "RIGHT", COMPACT_LABEL_GAP, 0)
                controlChild:SetPoint("RIGHT", widget, "RIGHT", -COMPACT_VALUE_WIDTH, 0)
            end
            if widget.Value then widget.Value:SetWidth(COMPACT_VALUE_WIDTH) end
            if control.type == "checkbox" and widget.Label then
                widget.Label:ClearAllPoints()
                widget.Label:SetPoint("LEFT", widget, "LEFT", COMPACT_LABEL_WIDTH + COMPACT_LABEL_GAP, 0)
                widget.Label:SetPoint("RIGHT", widget, "RIGHT", 0, 0)
            end
        end

        if widget then
            widget.controlKey = control.key
            widget.hideIf = control.hideIf
            widget.showIf = control.showIf

            local shouldShow = true
            if control.capability and not (self.plugin and self.plugin[control.capability]) then shouldShow = false end
            if shouldShow and control.hideIf then shouldShow = not self.currentOverrides[control.hideIf]
            elseif shouldShow and control.showIf then shouldShow = self.currentOverrides[control.showIf] == true end
            if shouldShow and control.showIfValue then shouldShow = self.currentOverrides[control.showIfValue.key] == control.showIfValue.value end

            self.widgets[widgetIndex] = widget
            self.widgetsByKey = self.widgetsByKey or {}
            self.widgetsByKey[control.key] = widget

            if shouldShow then
                widget.gridCol = col
                widget:ClearAllPoints()
                if col == 0 then
                    widget:SetPoint("TOPLEFT", overrideContainer, "TOPLEFT", C.DIALOG_INSET, -(rowY + TITLE_HEIGHT))
                    widget:SetPoint("TOPRIGHT", overrideContainer, "TOP", -(COLUMN_GAP / 2), -(rowY + TITLE_HEIGHT))
                else
                    widget:SetPoint("TOPLEFT", overrideContainer, "TOP", (COLUMN_GAP / 2), -(rowY + TITLE_HEIGHT))
                    widget:SetPoint("TOPRIGHT", overrideContainer, "TOPRIGHT", -C.DIALOG_INSET, -(rowY + TITLE_HEIGHT))
                end
                widget:Show()
                rowHeight = math.max(rowHeight, widget:GetHeight())
                col = col + 1
                if col >= COLUMNS then
                    col = 0
                    rowY = rowY + rowHeight + WIDGET_SPACING
                    rowHeight = 0
                end
            else
                widget:Hide()
            end
        end
    end

    -- Close final partial row
    if col > 0 then rowY = rowY + rowHeight + WIDGET_SPACING end

    local containerHeight = rowY + TITLE_HEIGHT + PADDING
    overrideContainer:SetHeight(containerHeight)
    canvasDialog:RecalculateHeight()

    if self.currentOverrides and next(self.currentOverrides) then
        self:ApplyAll(container, self.currentOverrides)
    end
end

-- [ CLOSE (INLINE) ]--------------------------------------------------------------------------------

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
        canvasDialog:RecalculateHeight()
    end
end

function Settings:HideWidgets()
    for _, widget in ipairs(self.widgets) do widget:Hide() end
end

-- [ VALUE CHANGE HANDLER ]--------------------------------------------------------------------------

function Settings:OnValueChanged(key, value)
    if not self.componentKey then return end

    self.currentOverrides = self.currentOverrides or {}
    self.currentOverrides[key] = value

    local schema = KEY_SCHEMAS[self.componentKey]
    local rebuildsPanel = false
    if schema then
        for _, ctrl in ipairs(schema.controls) do
            if ctrl.key == key and ctrl.rebuildsPanel then rebuildsPanel = true; break end
        end
    end

    if rebuildsPanel then
        local savedOverrides = {}
        for k, v in pairs(self.currentOverrides) do savedOverrides[k] = v end
        if self.container then self.container.pendingOverrides = savedOverrides end
        local isPluginSetting = schema and schema.pluginSettings
        if isPluginSetting then
            self.pendingPluginSettings = self.pendingPluginSettings or {}
            self.pendingPluginSettings[key] = value
        end
        self:Open(self.componentKey, self.container, self.plugin, self.systemIndex)
        if self.pendingPluginSettings then
            for k, v in pairs(self.pendingPluginSettings) do self.currentOverrides[k] = v end
        end
        self:ApplyPortraitPreview()
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
            end
        end

        if needsHeightRecalc then
            local COLUMNS = 2
            local COLUMN_GAP = 24
            local col = 0
            local rowY = 0
            local rowHeight = 0
            local canvasDialog = OrbitEngine.CanvasModeDialog
            local oc = canvasDialog and canvasDialog.OverrideContainer
            for _, widget in ipairs(self.widgets) do
                if widget:IsShown() and oc then
                    widget:ClearAllPoints()
                    if col == 0 then
                        widget:SetPoint("TOPLEFT", oc, "TOPLEFT", C.DIALOG_INSET, -(rowY + TITLE_HEIGHT))
                        widget:SetPoint("TOPRIGHT", oc, "TOP", -(COLUMN_GAP / 2), -(rowY + TITLE_HEIGHT))
                    else
                        widget:SetPoint("TOPLEFT", oc, "TOP", (COLUMN_GAP / 2), -(rowY + TITLE_HEIGHT))
                        widget:SetPoint("TOPRIGHT", oc, "TOPRIGHT", -C.DIALOG_INSET, -(rowY + TITLE_HEIGHT))
                    end
                    rowHeight = math.max(rowHeight, widget:GetHeight())
                    col = col + 1
                    if col >= COLUMNS then
                        col = 0
                        rowY = rowY + rowHeight + WIDGET_SPACING
                        rowHeight = 0
                    end
                end
            end
            if col > 0 then rowY = rowY + rowHeight + WIDGET_SPACING end
            local containerHeight = rowY + TITLE_HEIGHT + PADDING
            if canvasDialog and canvasDialog.OverrideContainer then
                canvasDialog.OverrideContainer:SetHeight(containerHeight)
                canvasDialog:RecalculateHeight()
            end
        end
    end

    if self.container then
        self.container.pendingOverrides = self.currentOverrides

        local isPluginSetting = schema and (schema.pluginSettings or (schema.pluginSettingKeys and schema.pluginSettingKeys[key]))
        if isPluginSetting then
            self.pendingPluginSettings = self.pendingPluginSettings or {}
            self.pendingPluginSettings[key] = value
            if self.componentKey == "CastBar" then
                self:ApplyCastBarPreview()
            elseif self.componentKey == "HealthText" then
                self:ApplyHealthTextPreview()
            else
                self:ApplyPortraitPreview()
            end
            return
        end

        self:ApplyStyle(self.container, key, value)
    end
end

function Settings:ApplyPortraitPreview()
    local ok, err = pcall(function()
    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.previewComponents then return end
    local comp = canvasDialog.previewComponents.Portrait
    if not comp or not comp.visual then return end

    local overrides = self.currentOverrides or {}
    local scale = (overrides.PortraitScale or 120) / 100
    local style = overrides.PortraitStyle or "3d"
    local mirror = overrides.PortraitMirror or false
    local ringAtlas = overrides.PortraitRing or "none"

    local size = 32 * scale
    local ringData = PORTRAIT_RING_DATA[ringAtlas]
    local ringOS = ((ringData and ringData.overshoot) or PORTRAIT_RING_OVERSHOOT) * scale
    comp:SetSize(size, size)

    if not comp._ring then
        comp._ring = comp:CreateTexture(nil, "OVERLAY")
    end
    comp._ring:ClearAllPoints()
    comp._ring:SetPoint("TOPLEFT", -ringOS, ringOS)
    comp._ring:SetPoint("BOTTOMRIGHT", ringOS, -ringOS)

    if style == "3d" then
        if not comp._model then
            comp._model = CreateFrame("PlayerModel", nil, comp)
            comp._model:SetAllPoints()
        end
        comp.visual:Hide()
        comp._model:Show()
        comp._model:SetUnit("player")
        comp._model:SetPortraitZoom(mirror and 0.85 or 1)
        comp._model:SetCamDistanceScale(0.8)
        comp._model:SetFacing(mirror and -1.05 or 0)
        comp._model:SetPosition(mirror and 0.3 or 0, 0, mirror and -0.05 or 0)
        comp._ring:Hide()
        if comp._flipDriver then comp._flipDriver:Hide() end
        local showBorder = overrides.PortraitBorder
        if showBorder == nil then showBorder = true end
        local borderSize = showBorder and (Orbit.db.GlobalSettings.BorderSize or 0) or 0
        Orbit.Skin:SkinBorder(comp, comp, borderSize)
    else
        if comp._model then comp._model:Hide() end
        comp.visual:Show()
        SetPortraitTexture(comp.visual, "player")
        comp.visual:SetTexCoord(mirror and 1 or 0, mirror and 0 or 1, 0, 1)
        Orbit.Skin:SkinBorder(comp, comp, 0)
        local ringData = PORTRAIT_RING_DATA[ringAtlas]
        if ringData and ringData.atlas then
            comp._ring:Show()
            if ringData.rows then
                local info = C_Texture.GetAtlasInfo(ringData.atlas)
                if not info then comp._ring:Hide(); return end
                comp._ring:SetTexture(info.file)
                local aL, aR = info.leftTexCoord, info.rightTexCoord
                local aT, aB = info.topTexCoord, info.bottomTexCoord
                local cellW, cellH = (aR - aL) / ringData.cols, (aB - aT) / ringData.rows
                local frameTime = ringData.duration / ringData.frames
                if not comp._flipDriver then
                    comp._flipDriver = CreateFrame("Frame", nil, comp)
                end
                comp._flipDriver._current = 0
                comp._flipDriver._elapsed = 0
                local function SetFrame(idx)
                    local c = idx % ringData.cols
                    local r = math.floor(idx / ringData.cols)
                    comp._ring:SetTexCoord(aL + c * cellW, aL + (c + 1) * cellW, aT + r * cellH, aT + (r + 1) * cellH)
                end
                SetFrame(0)
                comp._flipDriver:SetScript("OnUpdate", function(driver, elapsed)
                    driver._elapsed = driver._elapsed + elapsed
                    if driver._elapsed >= frameTime then
                        driver._elapsed = driver._elapsed - frameTime
                        driver._current = (driver._current + 1) % ringData.frames
                        SetFrame(driver._current)
                    end
                end)
                comp._flipDriver:Show()
            else
                comp._ring:SetTexCoord(0, 1, 0, 1)
                comp._ring:SetAtlas(ringData.atlas)
                if comp._flipDriver then comp._flipDriver:Hide() end
            end
        else
            comp._ring:Hide()
            if comp._flipDriver then comp._flipDriver:Hide() end
        end
    end
    end)
    if not ok then print("|cffff0000ORBIT_PORTRAIT_PREVIEW ERROR:|r", err) end
end

function Settings:ApplyCastBarPreview()
    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.previewComponents then return end
    local comp = canvasDialog.previewComponents.CastBar
    if not comp then return end

    local pending = self.pendingPluginSettings or {}
    local plugin = self.plugin
    local sysIdx = self.systemIndex or 1
    local w = pending.CastBarWidth or (plugin and plugin:GetSetting(sysIdx, "CastBarWidth")) or 120
    local h = pending.CastBarHeight or (plugin and plugin:GetSetting(sysIdx, "CastBarHeight")) or 18
    comp:SetSize(w, h)
    if comp.visual and comp.visual.SetAllPoints then comp.visual:SetAllPoints() end
end

function Settings:ApplyHealthTextPreview()
    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.previewComponents then return end
    local comp = canvasDialog.previewComponents.HealthText
    if not comp or not comp.visual then return end
    local visual = comp.visual

    local pending = self.pendingPluginSettings or {}
    local plugin = self.plugin
    local sysIdx = self.systemIndex or 1
    local showValue = pending.ShowHealthValue
    if showValue == nil then showValue = plugin and plugin:GetSetting(sysIdx, "ShowHealthValue") end
    if showValue == nil then showValue = true end
    local mode = pending.HealthTextMode or (plugin and plugin:GetSetting(sysIdx, "HealthTextMode")) or "percent_short"

    if showValue then
        local SAMPLE_TEXT = {
            percent = "100%", short = "106K", raw = "106000",
            short_and_percent = "106K - 100%",
            percent_short = "100%", percent_raw = "100%",
            short_percent = "106K", short_raw = "106K",
            raw_short = "106000", raw_percent = "106000",
        }
        visual:SetText(SAMPLE_TEXT[mode] or "100%")
    else
        visual:SetText("Offline")
    end
    visual:Show()
end

function Settings:FlushPendingPluginSettings()
    if not self.pendingPluginSettings or not self.plugin then return end
    for k, v in pairs(self.pendingPluginSettings) do
        self.plugin:SetSetting(self.systemIndex, k, v)
    end
    self.pendingPluginSettings = nil
end

-- [ APPLY STYLE ]-----------------------------------------------------------------------------------

function Settings:ApplyStyle(container, key, value)
    if key == "MaxIcons" or key == "IconSize" or key == "MaxRows" then
        if self.container and self.container.RefreshAuraIcons then self.container:RefreshAuraIcons() end
        return
    end

    if not container or not container.visual then return end
    local visual = container.visual

    if key == "FontSize" and visual.SetFont then
        local font, _, flags = visual:GetFont()
        flags = (flags and flags ~= "") and flags or Orbit.Skin:GetFontOutline()
        visual:SetFont(font, value, flags)
        C_Timer.After(0.01, function()
            if container and visual and visual.GetStringWidth then
                container:SetSize((visual:GetStringWidth() or (value * 3)) + 2, (visual:GetStringHeight() or value) + 2)
            end
        end)
    elseif key == "Font" and visual.SetFont then
        local fontPath = LSM:Fetch("font", value)
        if fontPath then
            local _, size, flags = visual:GetFont()
            flags = (flags and flags ~= "") and flags or Orbit.Skin:GetFontOutline()
            visual:SetFont(fontPath, size or 12, flags)
            C_Timer.After(0.01, function()
                if container and visual and visual.GetStringWidth then
                    container:SetSize((visual:GetStringWidth() or ((size or 12) * 3)) + 2, (visual:GetStringHeight() or (size or 12)) + 2)
                end
            end)
        end
    elseif key == "CustomColorCurve" and visual.SetTextColor then
        local color = OrbitEngine.ColorCurve:GetFirstColorFromCurve(value)
        if color then visual:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1) end
    elseif key == "Scale" then
        if container.isIconFrame then
            if not container.originalContainerWidth then
                container.originalContainerWidth = container:GetWidth()
                container.originalContainerHeight = container:GetHeight()
            end
            local baseW = container.originalContainerWidth or 24
            local baseH = container.originalContainerHeight or 24
            local scale = container:GetEffectiveScale()
            local w, h = Orbit.Engine.Pixel:Snap(baseW * value, scale), Orbit.Engine.Pixel:Snap(baseH * value, scale)
            container:SetSize(w, h)
            if visual.SetSize then visual:SetSize(w, h) end
            if Orbit.Skin and Orbit.Skin.Icons then
                local s = visual:GetEffectiveScale() or 1
                local globalBorder = Orbit.db.GlobalSettings.BorderSize or Orbit.Engine.Pixel:DefaultBorderSize(s)
                Orbit.Skin.Icons:ApplyCustom(visual, { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false })
            end
        elseif visual.GetObjectType and visual:GetObjectType() == "Texture" then
            if not container.originalVisualWidth then
                container.originalVisualWidth = visual:GetWidth()
                container.originalVisualHeight = visual:GetHeight()
            end
            visual:ClearAllPoints()
            visual:SetPoint("CENTER", container, "CENTER", 0, 0)
            visual:SetSize((container.originalVisualWidth or 18) * value, (container.originalVisualHeight or 18) * value)
        elseif visual.SetScale then
            visual:SetScale(value)
        end
    end
end

function Settings:ApplyAll(container, overrides)
    if not container or not overrides then return end
    local previousOverrides = self.currentOverrides
    self.currentOverrides = overrides
    for key, value in pairs(overrides) do self:ApplyStyle(container, key, value) end
    self.currentOverrides = previousOverrides
end

function Settings:ApplyInitialPluginPreviews(plugin, systemIndex)
    if not plugin then return end
    local sysIdx = systemIndex or 1
    self.plugin = plugin
    self.systemIndex = sysIdx

    local portraitStyle = plugin:GetSetting(sysIdx, "PortraitStyle") or "3d"
    self.currentOverrides = {
        PortraitStyle = portraitStyle,
        PortraitScale = plugin:GetSetting(sysIdx, "PortraitScale") or 120,
        PortraitBorder = plugin:GetSetting(sysIdx, "PortraitBorder"),
        PortraitMirror = plugin:GetSetting(sysIdx, "PortraitMirror") or false,
        PortraitRing = plugin:GetSetting(sysIdx, "PortraitRing") or "none",
    }
    if self.currentOverrides.PortraitBorder == nil then self.currentOverrides.PortraitBorder = true end
    self:ApplyPortraitPreview()

    self.currentOverrides = {
        CastBarWidth = plugin:GetSetting(sysIdx, "CastBarWidth") or 120,
        CastBarHeight = plugin:GetSetting(sysIdx, "CastBarHeight") or 18,
    }
    self.pendingPluginSettings = nil
    self:ApplyCastBarPreview()

    self.currentOverrides = nil

    self.currentOverrides = {
        ShowHealthValue = plugin:GetSetting(sysIdx, "ShowHealthValue"),
        HealthTextMode = plugin:GetSetting(sysIdx, "HealthTextMode") or "percent_short",
    }
    if self.currentOverrides.ShowHealthValue == nil then self.currentOverrides.ShowHealthValue = true end
    self:ApplyHealthTextPreview()

    self.currentOverrides = nil
end

-- [ EXPORT ]----------------------------------------------------------------------------------------

Orbit.CanvasComponentSettings = Settings
OrbitEngine.CanvasComponentSettings = Settings
