local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout
local LSM = LibStub("LibSharedMedia-3.0")
local tinsert = table.insert

local ROW_HEIGHT = 24
local MAX_HEIGHT = 300
local ROW_PREVIEW = 13
local CONTROL_PREVIEW = 12

local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"

-- FontPicker Widget
-- 3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right]
-- Control is a preview button (the name drawn in the selected font); clicking opens a MediaMenu.
-- Optional valueColorCfg fills the value column with a color swatch (used for the global font color).
function Layout:CreateFontPicker(parent, label, initialFont, callback, valueColorCfg)
    if not self.fontPool then self.fontPool = {} end
    local frame = table.remove(self.fontPool)

    if not frame then
        frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        frame.OrbitType = "Font"
        frame.Label = frame:CreateFontString(nil, "ARTWORK", Constants.UI.LabelFont)

        local control = CreateFrame("Button", nil, frame, "BackdropTemplate")
        control:SetBackdrop({ bgFile = WHITE8x8, edgeFile = WHITE8x8, edgeSize = 1 })
        control:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        control:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        control:SetHeight(22)

        control.Text = control:CreateFontString(nil, "OVERLAY")
        control.Text:SetPoint("LEFT", 6, 0)
        control.Text:SetPoint("RIGHT", -18, 0)
        control.Text:SetJustifyH("LEFT")
        control.Text:SetWordWrap(false)
        control.Text:SetTextColor(1, 1, 1, 1)

        control.Arrow = control:CreateTexture(nil, "OVERLAY")
        control.Arrow:SetSize(12, 12)
        control.Arrow:SetPoint("RIGHT", -4, 0)
        control.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown")

        control:SetScript("OnClick", function() frame:ShowDropdown() end)
        control:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            self.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown-hover")
        end)
        control:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            self.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown")
        end)
        frame.Control = control
    end

    frame:SetParent(parent)
    frame.selectedFont = initialFont or Constants.Settings.Font.Default
    frame.fontCallback = callback

    local function UpdatePreview()
        local path = LSM:Fetch("font", frame.selectedFont)
        frame.Control.Text:SetFont(path or Constants.Settings.Font.FallbackPath, CONTROL_PREVIEW, "")
        frame.Control.Text:SetText(frame.selectedFont)
    end

    function frame:ShowDropdown()
        if not frame.Dropdown then
            frame.Dropdown = Engine.MediaMenu:Create(frame.Control, {
                rowHeight = ROW_HEIGHT,
                maxHeight = MAX_HEIGHT,
                createRow = function(rowParent)
                    local row = CreateFrame("Button", nil, rowParent)
                    row.Text = row:CreateFontString(nil, "OVERLAY")
                    row.Text:SetPoint("LEFT", 10, 0)
                    row.Text:SetPoint("RIGHT", -8, 0)
                    row.Text:SetJustifyH("LEFT")
                    row.Text:SetWordWrap(false)
                    row.Sel = row:CreateTexture(nil, "ARTWORK")
                    row.Sel:SetPoint("LEFT", 0, 0)
                    row.Sel:SetSize(3, ROW_HEIGHT - 8)
                    row.Sel:SetColorTexture(0.3, 0.7, 1, 1)
                    return row
                end,
                renderRow = function(row, name, isSelected)
                    local path = LSM:Fetch("font", name)
                    if path then
                        row.Text:SetFont(path, ROW_PREVIEW, "")
                        row.Text:SetText(name)
                        row.Text:SetTextColor(0.9, 0.9, 0.9, 1)
                    else
                        row.Text:SetFont(Constants.Settings.Font.FallbackPath, ROW_PREVIEW, "")
                        row.Text:SetText(name .. " (!)")
                        row.Text:SetTextColor(1, 0.5, 0.5, 1)
                    end
                    row.Sel:SetShown(isSelected)
                end,
                onSelect = function(name)
                    frame.selectedFont = name
                    UpdatePreview()
                    if frame.fontCallback then frame.fontCallback(name) end
                end,
            })
        end
        local list = {}
        for name in pairs(LSM:HashTable("font")) do tinsert(list, name) end
        frame.Dropdown:Populate(list, frame.selectedFont)
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

    -- Value column: optional inline color swatch
    if valueColorCfg then
        self:ApplyValueColorSwatch(frame, valueColorCfg)
    elseif frame.ValueColorSwatch then
        frame.ValueColorSwatch:Hide()
    end

    frame:SetSize(C.Widget.Width, C.Widget.Height)
    return frame
end
