local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout
local LSM = LibStub("LibSharedMedia-3.0")
local tinsert, tsort = table.insert, table.sort

local MAX_DROPDOWN_HEIGHT = 250
local BUTTON_HEIGHT = 24

-- FontPicker Widget
-- 3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]
function Layout:CreateFontPicker(parent, label, initialFont, callback)
    -- Pool retrieval
    if not self.fontPool then self.fontPool = {} end
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
            if frame.ShowDropdown then frame:ShowDropdown() end
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
    frame.selectedFont = initialFont or Constants.Settings.Font.Default

    local function UpdatePreview()
        local text = frame.selectedFont
        if #text > 22 then text = string.sub(text, 1, 20) .. ".." end

        local fontPath = LSM:Fetch("font", frame.selectedFont)
        if fontPath then
            frame.Control.Text:SetFont(fontPath, 12, "")
            frame.Control.Text:SetText(text)
        else
            frame.Control.Text:SetFont(Constants.Settings.Font.FallbackPath, 12, "")
            frame.Control.Text:SetText(text .. " (missing)")
        end
    end

    local function GetFontList()
        local list = {}
        for name in pairs(LSM:HashTable("font")) do
            tinsert(list, name)
        end
        tsort(list)
        return list
    end

    frame.ShowDropdown = function()
        if not frame.DropdownFrame then
            frame.DropdownFrame = Engine.SharedMediaDropdown:Create(
                frame, BUTTON_HEIGHT, MAX_DROPDOWN_HEIGHT,
                function(contentFrame, index)
                    local btn = CreateFrame("Button", nil, contentFrame, "BackdropTemplate")
                    btn:SetSize(192, BUTTON_HEIGHT)
                    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                    btn:SetBackdropColor(0, 0, 0, 0)
                    btn.Name = btn:CreateFontString(nil, "OVERLAY")
                    btn.Name:SetPoint("LEFT", 8, 0)
                    btn.Name:SetPoint("RIGHT", -8, 0)
                    btn.Name:SetJustifyH("LEFT")
                    btn.Name:SetTextColor(0.9, 0.9, 0.9, 1)
                    btn.Selected = btn:CreateTexture(nil, "ARTWORK")
                    btn.Selected:SetSize(4, BUTTON_HEIGHT - 4)
                    btn.Selected:SetPoint("LEFT", 0, 0)
                    btn.Selected:SetColorTexture(0.3, 0.7, 1, 1)
                    btn.Selected:Hide()
                    return btn
                end,
                function(btn, fontName, isSelected)
                    local fontPath = LSM:Fetch("font", fontName)
                    if fontPath then
                        btn.Name:SetFont(fontPath, 13, "")
                        btn.Name:SetText(fontName)
                    else
                        btn.Name:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
                        btn.Name:SetText(fontName .. " (!)")
                    end
                    if isSelected then btn.Selected:Show() else btn.Selected:Hide() end
                end,
                function(fontName)
                    frame.selectedFont = fontName
                    UpdatePreview()
                    if callback then callback(fontName) end
                end
            )
            frame.DropdownFrame:SetFrameLevel(1000)
        end
        frame.DropdownFrame:Populate(GetFontList(), frame.selectedFont)
    end

    UpdatePreview()

    -- Apply 3-column layout
    local C = Constants

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
