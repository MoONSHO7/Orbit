-- [ CANVAS MODE - COMPONENT SETTINGS WIDGETS ] ------------------------------------------------------
-- Widget creation helpers for component override settings.
local _, Orbit = ...
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local CanvasMode = OrbitEngine.CanvasMode
local Constants = Orbit.Constants

local WIDGET_HEIGHT = 28
local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"
local INPUT_BORDER = { 0.3, 0.3, 0.3, 1 }
local INVALID_BORDER = { 0.9, 0.2, 0.2, 1 }

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
    frame.Label:SetText(control.label .. ": " .. (currentValue or L.CMN_DEFAULT))
    return frame
end

-- A label + a text input where the user types the format string (keys like % / CurrentK / & + literal text).
-- Hovering shows a tooltip of the keys; `validate(text)` drives a red border and blocks committing invalid input.
function Widgets.CreateFormatInput(parent, control, currentValue, callback, tooltipLines, validate)
    local frame = CreateFrame("Frame", nil, parent)
    SnapHeight(frame, 32)
    frame:EnableMouse(true)
    frame.Label = frame:CreateFontString(nil, "ARTWORK", Constants.UI.LabelFont)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Label:SetText(control.label)

    local input = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    input:SetHeight(22)
    input:SetBackdrop({ bgFile = WHITE8x8, edgeFile = WHITE8x8, edgeSize = 1 })
    input:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame.Control = input

    local editBox = CreateFrame("EditBox", nil, input)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetAutoFocus(false)
    editBox:SetTextInsets(5, 5, 0, 0)
    editBox:SetAllPoints(input)
    editBox:SetText(currentValue or "")
    editBox:SetCursorPosition(0)
    frame.EditBox = editBox

    local function isValid() return (not validate) or validate(editBox:GetText()) end
    local function refreshBorder() input:SetBackdropBorderColor(unpack(isValid() and INPUT_BORDER or INVALID_BORDER)) end
    local function commit()
        if not isValid() then return end
        local text = strtrim(editBox:GetText())
        if text ~= editBox:GetText() then editBox:SetText(text) end
        if callback then callback(control.key, text) end
    end
    editBox:SetScript("OnTextChanged", refreshBorder)
    editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", commit)
    editBox:SetScript("OnEscapePressed", function(self) self:SetText(currentValue or ""); refreshBorder(); self:ClearFocus() end)
    input:EnableMouse(true)
    input:SetScript("OnMouseDown", function() editBox:SetFocus() end)
    refreshBorder()

    if tooltipLines and #tooltipLines > 0 then
        local function showTip(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            for _, line in ipairs(tooltipLines) do
                if line.title then
                    GameTooltip:AddLine(line.title, 1, 0.82, 0)
                elseif line.hint then
                    GameTooltip:AddLine(line.hint, 0.6, 0.6, 0.6)
                else
                    GameTooltip:AddDoubleLine(line.key, line.value, 1, 0.82, 0, 1, 1, 1)
                end
            end
            GameTooltip:Show()
        end
        local function hideTip() GameTooltip:Hide() end
        frame:SetScript("OnEnter", function(self) showTip(self) end)
        frame:SetScript("OnLeave", hideTip)
        editBox:SetScript("OnEnter", function(self) showTip(self) end)
        editBox:SetScript("OnLeave", hideTip)
    end
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
