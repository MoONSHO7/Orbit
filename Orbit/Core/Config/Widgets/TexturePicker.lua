local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout
local LSM = LibStub("LibSharedMedia-3.0")
local tinsert = table.insert

local ROW_HEIGHT = 22
local MAX_HEIGHT = 300
local NONE_LABEL = "None"

local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"

-- TexturePicker Widget
-- 3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]
-- Control is a preview swatch; clicking opens a MediaMenu whose rows preview each statusbar texture.
-- allowOverlays partitions the statusbar media list by whether a name contains "overlay"
-- (case-insensitive): bar-fill pickers list only non-overlay textures, the Overlay Texture
-- control (allowOverlays = true) lists only overlay textures.
function Layout:CreateTexturePicker(parent, label, initialTexture, callback, previewColor, valueCheckboxCfg, valueColorCfg, allowOverlays)
    if not self.texturePool then self.texturePool = {} end
    local frame = table.remove(self.texturePool)

    if not frame then
        frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        frame.OrbitType = "Texture"
        frame.Label = frame:CreateFontString(nil, "ARTWORK", Constants.UI.LabelFont)

        local control = CreateFrame("Button", nil, frame, "BackdropTemplate")
        control:SetBackdrop({ bgFile = WHITE8x8, edgeFile = WHITE8x8, edgeSize = 1 })
        control:SetBackdropBorderColor(0, 0, 0, 1)
        control:SetHeight(20)

        control.Texture = control:CreateTexture(nil, "BACKGROUND")
        control.Texture:SetPoint("TOPLEFT", 1, -1)
        control.Texture:SetPoint("BOTTOMRIGHT", -1, 1)

        control.Text = control:CreateFontString(nil, "OVERLAY", Constants.UI.LabelFont)
        control.Text:SetPoint("LEFT", 4, 0)
        control.Text:SetPoint("RIGHT", -18, 0)
        control.Text:SetJustifyH("CENTER")
        control.Text:SetWordWrap(false)
        control.Text:SetShadowOffset(1, -1)
        control.Text:SetShadowColor(0, 0, 0, 1)

        control.Arrow = control:CreateTexture(nil, "OVERLAY")
        control.Arrow:SetSize(12, 12)
        control.Arrow:SetPoint("RIGHT", -4, 0)
        control.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown")

        control:SetScript("OnClick", function() frame:ShowDropdown() end)
        control:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            self.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown-hover")
        end)
        control:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0, 0, 0, 1)
            self.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown")
        end)
        frame.Control = control
    end

    frame:SetParent(parent)
    frame.selectedTexture = initialTexture or Constants.Settings.Texture.Default
    frame.previewColor = previewColor or { r = 0.8, g = 0.8, b = 0.8 }
    frame.textureCallback = callback
    frame.allowOverlays = allowOverlays

    local function UpdatePreview()
        local color = frame.previewColor
        local tex = frame.Control.Texture
        if frame.selectedTexture == NONE_LABEL then
            tex:SetColorTexture(color.r or 0.3, color.g or 0.3, color.b or 0.3, 1)
        else
            local path = LSM:Fetch("statusbar", frame.selectedTexture)
            if path and path ~= "" then
                tex:SetTexture(path)
                tex:SetVertexColor(color.r or 0.8, color.g or 0.8, color.b or 0.8, 1)
                tex:SetTexCoord(0, 1, 0, 1)
            else
                tex:SetColorTexture(0.3, 0.3, 0.3, 1)
            end
        end
        frame.Control.Text:SetText(frame.selectedTexture)
    end

    function frame:ShowDropdown()
        if not frame.Dropdown then
            frame.Dropdown = Engine.MediaMenu:Create(frame.Control, {
                rowHeight = ROW_HEIGHT,
                maxHeight = MAX_HEIGHT,
                firstItem = NONE_LABEL,
                createRow = function(rowParent)
                    local row = CreateFrame("Button", nil, rowParent)
                    row.Texture = row:CreateTexture(nil, "BACKGROUND")
                    row.Texture:SetPoint("TOPLEFT", 2, -1)
                    row.Texture:SetPoint("BOTTOMRIGHT", -2, 1)
                    row.Text = row:CreateFontString(nil, "OVERLAY", Constants.UI.LabelFont)
                    row.Text:SetPoint("CENTER")
                    row.Text:SetShadowOffset(1, -1)
                    row.Text:SetShadowColor(0, 0, 0, 1)
                    row.Sel = row:CreateTexture(nil, "OVERLAY")
                    row.Sel:SetPoint("LEFT", 0, 0)
                    row.Sel:SetSize(3, ROW_HEIGHT - 6)
                    row.Sel:SetColorTexture(0.3, 0.7, 1, 1)
                    return row
                end,
                renderRow = function(row, name, isSelected)
                    row.Text:SetText(name)
                    if name == NONE_LABEL then
                        row.Texture:SetColorTexture(0.15, 0.15, 0.15, 1)
                    else
                        local path = LSM:Fetch("statusbar", name)
                        if path and path ~= "" then
                            row.Texture:SetTexture(path)
                            row.Texture:SetVertexColor(0.7, 0.7, 0.7, 1)
                            row.Texture:SetTexCoord(0, 1, 0, 1)
                        else
                            row.Texture:SetColorTexture(0.3, 0.3, 0.3, 1)
                        end
                    end
                    row.Sel:SetShown(isSelected)
                end,
                onSelect = function(name)
                    frame.selectedTexture = name
                    UpdatePreview()
                    if frame.textureCallback then frame.textureCallback(name) end
                end,
            })
        end
        local list = {}
        local wantOverlays = frame.allowOverlays == true
        for name in pairs(LSM:HashTable("statusbar")) do
            -- Overlay media (name contains "overlay") and bar fills are mutually exclusive lists;
            -- the current selection is always kept so the user can still see/change it.
            local isOverlay = name:lower():find("overlay", 1, true) ~= nil
            if isOverlay == wantOverlays or name == frame.selectedTexture then
                tinsert(list, name)
            end
        end
        frame.Dropdown:Populate(list, frame.selectedTexture)
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

    -- Value column: a right-aligned [swatch][checkbox] cluster. The checkbox flushes right;
    -- when both are present the swatch takes the slot to its left.
    if valueCheckboxCfg then
        self:ApplyValueCheckbox(frame, valueCheckboxCfg)
    elseif frame.ValueCheckbox then
        frame.ValueCheckbox:Hide()
    end

    if valueColorCfg then
        local swatchX = valueCheckboxCfg
            and (C.Widget.ValueInset + C.Widget.ValueSwatchSize * 1.5 + 1) or nil
        self:ApplyValueColorSwatch(frame, valueColorCfg, swatchX)
    elseif frame.ValueColorSwatch then
        frame.ValueColorSwatch:Hide()
    end

    frame:SetSize(C.Widget.Width, C.Widget.Height)
    return frame
end
