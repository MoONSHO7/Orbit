local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout
local LCG = LibStub("LibOrbitGlow-1.0", true)

local ROW_HEIGHT = 24
local MAX_HEIGHT = 300
local LIB_SOURCE = "LibOrbitGlow"
local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"

-- Display list + value maps: engine options keep their numeric Type value; registered pack glows use their string name.
local function BuildChoices(engineOptions)
    local items, valueByName, nameByValue, firstItem = {}, {}, {}, nil
    for i, opt in ipairs(engineOptions or {}) do
        items[#items + 1] = opt.text
        valueByName[opt.text] = opt.value
        nameByValue[opt.value] = opt.text
        if i == 1 then firstItem = opt.text end
    end
    if LCG and LCG.GetGlowList then
        for _, glow in ipairs(LCG:GetGlowList()) do
            local info = LCG.GetGlowInfo and LCG:GetGlowInfo(glow)
            if info and info.source and info.source ~= LIB_SOURCE then
                items[#items + 1] = glow
                valueByName[glow] = glow
                nameByValue[glow] = glow
            end
        end
    end
    return items, valueByName, nameByValue, firstItem
end

function Layout:CreateGlowPicker(parent, label, initialValue, callback, valueColorCfg, engineOptions)
    if not self.glowPool then self.glowPool = {} end
    local frame = table.remove(self.glowPool)

    if not frame then
        frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        frame.OrbitType = "Glow"
        frame.Label = frame:CreateFontString(nil, "ARTWORK", Constants.UI.LabelFont)

        local control = CreateFrame("Button", nil, frame, "BackdropTemplate")
        control:SetBackdrop({ bgFile = WHITE8x8, edgeFile = WHITE8x8, edgeSize = 1 })
        control:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        control:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        control:SetHeight(22)

        control.Text = control:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        control.Text:SetPoint("LEFT", 6, 0)
        control.Text:SetPoint("RIGHT", -18, 0)
        control.Text:SetJustifyH("LEFT")
        control.Text:SetWordWrap(false)

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
    local items, valueByName, nameByValue, firstItem = BuildChoices(engineOptions)
    frame.glowItems, frame.glowValueByName, frame.glowNameByValue, frame.glowFirst = items, valueByName, nameByValue, firstItem
    frame.selectedValue = initialValue
    if frame.selectedValue == nil and firstItem then frame.selectedValue = valueByName[firstItem] end
    frame.glowCallback = callback

    local function CurrentName()
        return frame.glowNameByValue[frame.selectedValue] or tostring(frame.selectedValue)
    end
    local function UpdatePreview()
        frame.Control.Text:SetText(CurrentName())
    end

    function frame:ShowDropdown()
        if not frame.Dropdown then
            frame.Dropdown = Engine.MediaMenu:Create(frame.Control, {
                rowHeight = ROW_HEIGHT,
                maxHeight = MAX_HEIGHT,
                firstItem = frame.glowFirst,
                createRow = function(rowParent)
                    local row = CreateFrame("Button", nil, rowParent)
                    row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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
                    row.Text:SetText(name)
                    row.Text:SetTextColor(0.9, 0.9, 0.9, 1)
                    row.Sel:SetShown(isSelected)
                end,
                onSelect = function(name)
                    frame.selectedValue = frame.glowValueByName[name]
                    UpdatePreview()
                    if frame.glowCallback then frame.glowCallback(frame.selectedValue) end
                end,
            })
        end
        frame.Dropdown:Populate(frame.glowItems, CurrentName())
    end

    UpdatePreview()

    local C = Constants
    frame.Label:SetText(label)
    frame.Label:SetWidth(C.Widget.LabelWidth)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:ClearAllPoints()
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)

    frame.Control:ClearAllPoints()
    frame.Control:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
    frame.Control:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)

    if valueColorCfg then
        self:ApplyValueColorSwatch(frame, valueColorCfg)
    elseif frame.ValueColorSwatch then
        frame.ValueColorSwatch:Hide()
    end

    frame:SetSize(C.Widget.Width, C.Widget.Height)
    return frame
end
