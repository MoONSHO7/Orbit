-- [ CANVAS MODE - COMPONENT SETTINGS WIDGETS ] ------------------------------------------------------
-- Widget creation helpers for component override settings.
local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local CanvasMode = OrbitEngine.CanvasMode

local WIDGET_HEIGHT = 28

local Widgets = {}
CanvasMode.SettingsWidgets = Widgets

local function SnapHeight(widget, height)
    widget:SetHeight(OrbitEngine.Pixel:Snap(height, widget:GetEffectiveScale()))
end

function Widgets.CreateSlider(parent, control, currentValue, callback)
    if not Layout or not Layout.CreateSlider then return nil end
    local widget = Layout:CreateSlider(parent, control.label, control.min, control.max, control.step or 1,
        control.formatter, currentValue or control.min, function(value) if callback then callback(control.key, value) end end)
    if widget then SnapHeight(widget, 32) end
    return widget
end

function Widgets.CreateCheckbox(parent, control, currentValue, callback)
    if not Layout or not Layout.CreateCheckbox then return nil end
    local widget = Layout:CreateCheckbox(parent, control.label, nil, currentValue or false,
        function(checked) if callback then callback(control.key, checked) end end)
    if widget then SnapHeight(widget, 30) end
    return widget
end

function Widgets.CreateFontPicker(parent, control, currentValue, callback)
    if Layout and Layout.CreateFontPicker then
        local widget = Layout:CreateFontPicker(parent, control.label, currentValue,
            function(fontName) if callback then callback(control.key, fontName) end end)
        if widget then SnapHeight(widget, 32) end
        return widget
    end
    local frame = CreateFrame("Frame", nil, parent)
    SnapHeight(frame, WIDGET_HEIGHT)
    frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Label:SetText(control.label .. ": " .. (currentValue or "Default"))
    return frame
end

function Widgets.CreateColorPicker(parent, control, currentValue, callback)
    if Layout and Layout.CreateColorCurvePicker then
        local widget = Layout:CreateColorCurvePicker(parent, control.label, currentValue,
            function(curveData) if callback then callback(control.key, curveData) end end)
        if widget then SnapHeight(widget, 32); widget.singleColorMode = true end
        return widget
    end
    local frame = CreateFrame("Frame", nil, parent)
    SnapHeight(frame, WIDGET_HEIGHT)
    frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Label:SetText(control.label .. ": (unavailable)")
    return frame
end
