local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local DEFAULT_WIDTH = 200
local DEFAULT_HEIGHT_SINGLE = 30
local DEFAULT_HEIGHT_MULTI = 100
local SCROLL_SPEED = 20

-- [ EDITBOX WIDGET ]---------------------------------------------------------------------------------
-- Intentionally unpooled: inner structure varies by isMultiLine/hideScrollBar/readOnly, so cross-variant reuse is unsafe. RecycleControls drops it.
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

-- [ FORMAT INPUT WIDGET ]----------------------------------------------------------------------------
-- Single-line editbox with token validation (valid/invalid border) plus a token-list tooltip — the same UX as the Health Text input.
local FORMAT_VALID_BORDER = { 0.5, 0.5, 0.5, 1 }
local FORMAT_INVALID_BORDER = { 0.9, 0.2, 0.2, 1 }

function Layout:CreateFormatInput(parent, label, value, callback, tooltipLines, validate)
    local W = Orbit.Constants.Widget
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame.OrbitType = "EditBox"
    frame:SetSize(DEFAULT_WIDTH, 32)

    -- 3-column layout: fixed label column on the left, input fills the rest of the row (mirrors CreateDropdown).
    frame.Label = frame:CreateFontString(nil, "ARTWORK", Orbit.Constants.UI.LabelFont)
    frame.Label:SetWidth(W.LabelWidth)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Label:SetText(label or "")

    local inputContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    inputContainer:SetBackdrop(Layout.ORBIT_INPUT_BACKDROP)
    inputContainer:SetBackdropColor(0, 0, 0, 0.5)
    inputContainer:SetHeight(22)
    inputContainer:SetPoint("LEFT", frame.Label, "RIGHT", W.LabelGap, 0)
    inputContainer:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

    local editBox = CreateFrame("EditBox", nil, inputContainer)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetAutoFocus(false)
    editBox:SetTextInsets(5, 5, 5, 5)
    editBox:SetAllPoints(inputContainer)
    inputContainer:EnableMouse(true)
    inputContainer:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    local function isValid() return (not validate) or validate(editBox:GetText()) end
    local function refreshBorder()
        inputContainer:SetBackdropBorderColor(unpack(isValid() and FORMAT_VALID_BORDER or FORMAT_INVALID_BORDER))
    end
    local function commit()
        if not isValid() then return end
        local text = strtrim(editBox:GetText())
        if text ~= editBox:GetText() then editBox:SetText(text) end
        if callback then callback(text) end
    end
    editBox:SetScript("OnTextChanged", refreshBorder)
    editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEditFocusLost", commit)
    editBox:SetScript("OnEscapePressed", function(self) self:SetText(value or ""); refreshBorder(); self:ClearFocus() end)

    editBox:SetText(value or "")
    editBox:SetCursorPosition(0)
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
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", function(self) showTip(self) end)
        frame:SetScript("OnLeave", GameTooltip_Hide)
        editBox:SetScript("OnEnter", function(self) showTip(self) end)
        editBox:SetScript("OnLeave", GameTooltip_Hide)
    end

    frame.EditBox = editBox
    frame.InputContainer = inputContainer
    return frame
end
