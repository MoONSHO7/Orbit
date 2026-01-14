local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

function Layout:CreateEditBox(parent, label, value, callback, width, height, isMultiLine)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame.OrbitType = "EditBox"

    -- Default Size
    local w = width or 200
    local h = height or (isMultiLine and 100 or 30)
    frame:SetSize(w, h)

    -- Label
    if label then
        frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        frame.Label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame.Label:SetText(label)
    end

    -- Input Container (Backdrop)
    local inputContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    inputContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
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

    if isMultiLine then
        -- ScrollFrame Wrapper for MultiLine
        local scrollFrame = CreateFrame("ScrollFrame", nil, inputContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 5, -5)
        scrollFrame:SetPoint("BOTTOMRIGHT", -26, 5) -- Room for scrollbar

        scrollFrame:SetScrollChild(editBox)
        editBox:SetWidth(scrollFrame:GetWidth()) -- Initial width
        editBox:SetHeight(scrollFrame:GetHeight()) -- Initial height? No, it grows.

        -- Hook Text Changed to resize editbox height
        editBox:SetScript("OnTextChanged", function(self)
            local scrollingEditBox = self
            local height = scrollingEditBox:GetHeight()
            -- Auto-resize height to fit text?
            -- Actually, for scrolling, we just want it to be at least the scrollframe height
            -- CSS-like 'height: max-content' isn't direct.
            -- But standard InputScrollFrameTemplate usually handles this if we use it.
            -- For manual:
            -- self:SetHeight(self:GetNumLines() * 14 + 10)
            if callback then
                callback(self:GetText())
            end
        end)

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
