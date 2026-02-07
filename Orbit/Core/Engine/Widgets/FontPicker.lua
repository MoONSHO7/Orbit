local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout
local LSM = LibStub("LibSharedMedia-3.0")

local MAX_DROPDOWN_HEIGHT = 250
local BUTTON_HEIGHT = 24

-- FontPicker Widget
-- 3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]
function Layout:CreateFontPicker(parent, label, initialFont, callback)
    -- Pool retrieval
    if not self.fontPool then
        self.fontPool = {}
    end
    local frame = table.remove(self.fontPool)

    -- Frame creation
    if not frame then
        frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        frame.OrbitType = "Font"

        -- Label
        frame.Label = frame:CreateFontString(nil, "ARTWORK", Orbit.Constants.UI.LabelFont)

        -- Control: Preview button
        frame.Control = CreateFrame("Button", nil, frame, "BackdropTemplate")
        frame.Control:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame.Control:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        frame.Control:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        -- Text preview (renders in selected font)
        frame.Control.Text = frame.Control:CreateFontString(nil, "OVERLAY")
        frame.Control.Text:SetPoint("LEFT", 4, 0)
        frame.Control.Text:SetPoint("RIGHT", -18, 0)
        frame.Control.Text:SetJustifyH("LEFT")
        frame.Control.Text:SetWordWrap(false)
        frame.Control.Text:SetTextColor(1, 1, 1, 1)

        -- Dropdown arrow
        frame.Control.Arrow = frame.Control:CreateTexture(nil, "OVERLAY")
        frame.Control.Arrow:SetSize(10, 10)
        frame.Control.Arrow:SetPoint("RIGHT", -4, 0)
        frame.Control.Arrow:SetAtlas("NPE_ArrowDown")

        frame.Control:SetScript("OnClick", function()
            if frame.ShowDropdown then
                frame:ShowDropdown()
            end
        end)
        frame.Control:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end)
        frame.Control:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end)
    end

    -- Set parent
    frame:SetParent(parent)

    -- Configure control logic
    frame.selectedFont = initialFont or Engine.Constants.Settings.Font.Default

    local function UpdatePreview()
        local text = frame.selectedFont
        if #text > 22 then
            text = string.sub(text, 1, 20) .. ".."
        end

        local fontPath = LSM:Fetch("font", frame.selectedFont)
        if fontPath then
            frame.Control.Text:SetFont(fontPath, 12, "")
            frame.Control.Text:SetText(text)
        else
            frame.Control.Text:SetFont(Engine.Constants.Settings.Font.FallbackPath, 12, "")
            frame.Control.Text:SetText(text .. " (missing)")
        end
    end

    local function GetFontList()
        local list = {}
        for name in pairs(LSM:HashTable("font")) do
            table.insert(list, name)
        end
        table.sort(list)
        return list
    end

    frame.ShowDropdown = function()
        if not frame.DropdownFrame then
            local dropdown = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            dropdown:SetFrameStrata("FULLSCREEN_DIALOG")
            dropdown:SetFrameLevel(1000) -- Very high to appear above other dialogs
            dropdown:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            dropdown:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
            dropdown:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            dropdown:SetClipsChildren(true)

            dropdown.Content = CreateFrame("Frame", nil, dropdown)
            dropdown.Content:SetPoint("TOPLEFT", 4, -4)
            dropdown.Content:SetSize(192, 1)
            dropdown.scrollOffset = 0
            dropdown.buttons = {}

            dropdown:EnableMouseWheel(true)
            dropdown:SetScript("OnMouseWheel", function(self, delta)
                local maxOffset = math.max(0, self.contentHeight - (self:GetHeight() - 8))
                self.scrollOffset = math.max(0, math.min(maxOffset, self.scrollOffset - delta * BUTTON_HEIGHT))
                self.Content:SetPoint("TOPLEFT", 4, -4 + self.scrollOffset)
            end)

            frame.DropdownFrame = dropdown
        end

        local dropdown = frame.DropdownFrame
        local fonts = GetFontList()

        local contentHeight = #fonts * BUTTON_HEIGHT
        local dropdownHeight = math.min(contentHeight + 8, MAX_DROPDOWN_HEIGHT)

        dropdown:SetSize(200, dropdownHeight)
        dropdown.Content:SetHeight(contentHeight)
        dropdown.contentHeight = contentHeight
        dropdown.scrollOffset = 0
        dropdown.Content:SetPoint("TOPLEFT", 4, -4)
        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOPLEFT", frame.Control, "BOTTOMLEFT", 0, -2)

        for i, fontName in ipairs(fonts) do
            local btn = dropdown.buttons[i]
            if not btn then
                btn = CreateFrame("Button", nil, dropdown.Content, "BackdropTemplate")
                btn:SetSize(192, BUTTON_HEIGHT)
                btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                btn:SetBackdropColor(0, 0, 0, 0)

                btn.Name = btn:CreateFontString(nil, "OVERLAY")
                btn.Name:SetPoint("LEFT", 8, 0)
                btn.Name:SetPoint("RIGHT", -8, 0)
                btn.Name:SetJustifyH("LEFT")
                btn.Name:SetTextColor(0.9, 0.9, 0.9, 1)

                btn.Highlight = btn:CreateTexture(nil, "ARTWORK")
                btn.Highlight:SetAllPoints()
                btn.Highlight:SetColorTexture(0.4, 0.6, 1, 0.3)
                btn.Highlight:Hide()

                btn.Selected = btn:CreateTexture(nil, "ARTWORK")
                btn.Selected:SetSize(4, BUTTON_HEIGHT - 4)
                btn.Selected:SetPoint("LEFT", 0, 0)
                btn.Selected:SetColorTexture(0.3, 0.7, 1, 1)
                btn.Selected:Hide()

                btn:SetScript("OnEnter", function(self)
                    self.Highlight:Show()
                end)
                btn:SetScript("OnLeave", function(self)
                    self.Highlight:Hide()
                end)

                dropdown.buttons[i] = btn
            end

            btn:SetPoint("TOPLEFT", dropdown.Content, "TOPLEFT", 0, -(i - 1) * BUTTON_HEIGHT)

            local fontPath = LSM:Fetch("font", fontName)
            if fontPath then
                btn.Name:SetFont(fontPath, 13, "")
                btn.Name:SetText(fontName)
            else
                btn.Name:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
                btn.Name:SetText(fontName .. " (!)")
            end

            if fontName == frame.selectedFont then
                btn.Selected:Show()
            else
                btn.Selected:Hide()
            end

            btn:SetScript("OnClick", function()
                frame.selectedFont = fontName
                UpdatePreview()
                dropdown:Hide()
                if callback then
                    callback(fontName)
                end
            end)

            btn:Show()
        end

        for i = #fonts + 1, #dropdown.buttons do
            dropdown.buttons[i]:Hide()
        end

        dropdown:Show()

        dropdown:SetPropagateKeyboardInput(true)
        dropdown:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)

        dropdown:SetScript("OnShow", function(self)
            self.closeTimer = 0
            self:SetScript("OnUpdate", function(d, elapsed)
                if not frame:IsVisible() then
                    d:Hide()
                    return
                end
                if not MouseIsOver(d) and not MouseIsOver(frame.Control) then
                    d.closeTimer = (d.closeTimer or 0) + elapsed
                    if d.closeTimer > 0.2 or IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                        d:Hide()
                    end
                else
                    d.closeTimer = 0
                end
            end)
        end)
        dropdown:SetScript("OnHide", function(self)
            self:SetScript("OnUpdate", nil)
            self:SetScript("OnKeyDown", nil)
        end)
    end

    -- Ensure dropdown is hidden if parent is hidden/recycled
    frame:SetScript("OnHide", function()
        if frame.DropdownFrame then
            frame.DropdownFrame:Hide()
        end
    end)

    UpdatePreview()

    -- Apply 3-column layout
    local C = Engine.Constants

    frame.Label:SetText(label)
    frame.Label:SetWidth(C.Widget.LabelWidth)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:ClearAllPoints()
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)

    frame.Control:ClearAllPoints()
    frame.Control:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
    frame.Control:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
    frame.Control:SetHeight(22)

    -- Value column reserved

    frame:SetSize(C.Widget.Width, C.Widget.Height)
    return frame
end
