local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local DEFAULT_WIDTH = 200
local DEFAULT_HEIGHT_SINGLE = 30
local DEFAULT_HEIGHT_MULTI = 100
local SCROLL_SPEED = 20

-- [ EDITBOX WIDGET ]--------------------------------------------------------------------------------
function Layout:CreateEditBox(parent, label, value, callback, width, height, isMultiLine, opts)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame.OrbitType = "EditBox"

    local w = width or DEFAULT_WIDTH
    local h = height or (isMultiLine and DEFAULT_HEIGHT_MULTI or DEFAULT_HEIGHT_SINGLE)
    frame:SetSize(w, h)

    -- Label
    if label then
        frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        frame.Label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame.Label:SetText(label)
    end

    -- Input Container (Backdrop)
    local inputContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    inputContainer:SetBackdrop(Layout.ORBIT_INPUT_BACKDROP)
    inputContainer:SetBackdropColor(0, 0, 0, 0.5)
    inputContainer:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    if label then
        inputContainer:SetPoint("TOPLEFT", frame.Label, "BOTTOMLEFT", 0, -5)
    else
        inputContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    end
    inputContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    -- EditBox
    local editBox = CreateFrame("EditBox", nil, inputContainer)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetMultiLine(isMultiLine)
    editBox:SetAutoFocus(false)
    editBox:SetTextInsets(5, 5, 5, 5)
    inputContainer:EnableMouse(true)
    inputContainer:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    if isMultiLine then
        local scrollFrame
        if opts and opts.hideScrollBar then
            scrollFrame = CreateFrame("ScrollFrame", nil, inputContainer)
            scrollFrame:SetPoint("TOPLEFT", 5, -5)
            scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
            scrollFrame:EnableMouseWheel(true)
            scrollFrame:SetScript("OnMouseWheel", function(self, delta)
                local cur = self:GetVerticalScroll()
                local max = self:GetVerticalScrollRange()
                self:SetVerticalScroll(math.max(0, math.min(max, cur - (delta * SCROLL_SPEED))))
            end)
        else
            scrollFrame = CreateFrame("ScrollFrame", nil, inputContainer, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", 5, -5)
            scrollFrame:SetPoint("BOTTOMRIGHT", -26, 5)
        end

        scrollFrame:SetScrollChild(editBox)
        editBox:SetWidth(scrollFrame:GetWidth())
        editBox:SetHeight(scrollFrame:GetHeight())

        -- Hook Text Changed to resize editbox height
        if opts and opts.readOnly then
            local frozenText = value or ""
            editBox:SetScript("OnTextChanged", function(self)
                if self:GetText() ~= frozenText then self:SetText(frozenText) end
            end)
            editBox:SetScript("OnChar", function() end)
            editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        else
            editBox:SetScript("OnTextChanged", function(self)
                if callback then callback(self:GetText()) end
            end)
        end

        -- Fix Scroll Child sizing
        scrollFrame:SetScript("OnSizeChanged", function(self, w, h)
            editBox:SetWidth(w)
        end)
    else
        -- Single Line
        editBox:SetAllPoints(inputContainer)

        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            if callback then
                callback(self:GetText())
            end
        end)

        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            -- Revert? Or just blur.
            if value then
                self:SetText(value)
            end
        end)

        editBox:SetScript("OnEditFocusLost", function(self)
            if callback then
                callback(self:GetText())
            end
        end)
    end

    editBox:SetText(value or "")
    editBox:SetCursorPosition(0)

    frame.EditBox = editBox
    frame.InputContainer = inputContainer

    return frame
end
