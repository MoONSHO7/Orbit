local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout
local LSM = LibStub("LibSharedMedia-3.0")
local tinsert, tsort = table.insert, table.sort

local MAX_DROPDOWN_HEIGHT = 250
local BUTTON_HEIGHT = 22
local NONE_LABEL = "None"

-- TexturePicker Widget
-- 3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]
function Layout:CreateTexturePicker(parent, label, initialTexture, callback, previewColor, valueCheckboxCfg)
    -- Pool retrieval
    if not self.texturePool then self.texturePool = {} end
    local frame = table.remove(self.texturePool)

    -- Frame creation
    if not frame then
        frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        frame.OrbitType = "Texture"

        -- Label
        frame.Label = frame:CreateFontString(nil, "ARTWORK", Orbit.Constants.UI.LabelFont)

        -- Control: Preview button with texture display
        frame.Control = CreateFrame("Button", nil, frame, "BackdropTemplate")
        frame.Control:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame.Control:SetBackdropBorderColor(0, 0, 0, 1)

        -- Texture display
        frame.Control.Texture = frame.Control:CreateTexture(nil, "BACKGROUND")
        frame.Control.Texture:SetPoint("TOPLEFT", 1, -1)
        frame.Control.Texture:SetPoint("BOTTOMRIGHT", -1, 1)

        -- Text overlay (centered)
        frame.Control.Text = frame.Control:CreateFontString(nil, "OVERLAY", Orbit.Constants.UI.LabelFont)
        frame.Control.Text:SetPoint("LEFT", 4, 0)
        frame.Control.Text:SetPoint("RIGHT", -18, 0)
        frame.Control.Text:SetJustifyH("CENTER")
        frame.Control.Text:SetWordWrap(false)
        frame.Control.Text:SetShadowOffset(1, -1)
        frame.Control.Text:SetShadowColor(0, 0, 0, 1)

        -- Dropdown arrow
        frame.Control.Arrow = frame.Control:CreateTexture(nil, "OVERLAY")
        frame.Control.Arrow:SetSize(12, 12)
        frame.Control.Arrow:SetPoint("RIGHT", -4, 0)
        frame.Control.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown")

        frame.Control:SetScript("OnClick", function()
            if frame.ShowDropdown then frame:ShowDropdown() end
        end)
        frame.Control:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            self.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown-hover")
        end)
        frame.Control:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0, 0, 0, 1)
            self.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown")
        end)
        frame.Control:SetScript("OnMouseDown", function(self)
            self.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown-pressed-hover")
        end)
        frame.Control:SetScript("OnMouseUp", function(self)
            if MouseIsOver(self) then
                self.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown-hover")
            else
                self.Arrow:SetAtlas("glues-characterSelect-icon-arrowDown")
            end
        end)
    end

    -- Set parent
    frame:SetParent(parent)

    -- Configure control logic
    frame.selectedTexture = initialTexture or Constants.Settings.Texture.Default
    frame.previewColor = previewColor or { r = 0.8, g = 0.8, b = 0.8 }

    local function UpdatePreview()
        local color = frame.previewColor
        if frame.selectedTexture == NONE_LABEL then
            frame.Control.Texture:SetColorTexture(color.r or 0.3, color.g or 0.3, color.b or 0.3, 1)
            frame.Control.Text:SetText(NONE_LABEL)
            return
        end
        local path = LSM:Fetch("statusbar", frame.selectedTexture)
        if path and path ~= "" then
            frame.Control.Texture:SetColorTexture(1, 1, 1, 1)
            frame.Control.Texture:SetTexture(path)
            frame.Control.Texture:SetVertexColor(color.r or 0.8, color.g or 0.8, color.b or 0.8, 1)
            frame.Control.Texture:SetTexCoord(0, 1, 0, 1)
        else
            frame.Control.Texture:SetColorTexture(color.r or 0.3, color.g or 0.3, color.b or 0.3, 1)
        end
        local text = frame.selectedTexture
        if #text > 22 then text = string.sub(text, 1, 20) .. ".." end
        frame.Control.Text:SetText(text)
    end

    local function GetTextureList()
        local list = { NONE_LABEL }
        for name in pairs(LSM:HashTable("statusbar")) do
            tinsert(list, name)
        end
        tsort(list, function(a, b)
            if a == NONE_LABEL then return true end
            if b == NONE_LABEL then return false end
            return a < b
        end)
        return list
    end

    frame.ShowDropdown = function()
        if not frame.DropdownFrame then
            frame.DropdownFrame = Engine.SharedMediaDropdown:Create(
                frame, BUTTON_HEIGHT, MAX_DROPDOWN_HEIGHT,
                function(contentFrame, index)
                    local btn = CreateFrame("Button", nil, contentFrame, "BackdropTemplate")
                    btn:SetSize(Engine.SharedMediaDropdown.CONTENT_WIDTH, BUTTON_HEIGHT)
                    btn.Texture = btn:CreateTexture(nil, "BACKGROUND")
                    btn.Texture:SetAllPoints()
                    btn.Name = btn:CreateFontString(nil, "OVERLAY", Orbit.Constants.UI.LabelFont)
                    btn.Name:SetPoint("CENTER")
                    btn.Name:SetShadowOffset(1, -1)
                    btn.Name:SetShadowColor(0, 0, 0, 1)
                    return btn
                end,
                function(btn, textureName)
                    btn.Name:SetText(textureName)
                    if textureName == NONE_LABEL then
                        btn.Texture:SetColorTexture(0.15, 0.15, 0.15, 1)
                        return
                    end
                    local path = LSM:Fetch("statusbar", textureName)
                    if path then
                        btn.Texture:SetVertexColor(0.6, 0.6, 0.6, 1)
                        btn.Texture:SetTexture(path)
                        btn.Texture:SetTexCoord(0, 1, 0, 1)
                    else
                        btn.Texture:SetColorTexture(0.3, 0.3, 0.3, 1)
                    end
                end,
                function(textureName)
                    frame.selectedTexture = textureName
                    UpdatePreview()
                    if callback then callback(textureName) end
                end
            )
        end
        frame.DropdownFrame:Populate(GetTextureList(), frame.selectedTexture)
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
    frame.Control:SetHeight(20)

    -- Value column: optional inline checkbox
    if valueCheckboxCfg then
        if not frame.ValueCheckbox then
            frame.ValueCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            frame.ValueCheckbox:SetSize(22, 22)
        end
        local vcb = frame.ValueCheckbox
        vcb:ClearAllPoints()
        vcb:SetPoint("CENTER", frame, "RIGHT", -C.Widget.ValueWidth / 2, 0)
        vcb:SetChecked(valueCheckboxCfg.initialValue or false)
        vcb:SetScript("OnClick", function(self)
            if valueCheckboxCfg.callback then valueCheckboxCfg.callback(self:GetChecked()) end
        end)
        if valueCheckboxCfg.tooltip then
            vcb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(valueCheckboxCfg.tooltip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            vcb:SetScript("OnLeave", GameTooltip_Hide)
        end
        vcb:Show()
    elseif frame.ValueCheckbox then
        frame.ValueCheckbox:Hide()
    end

    frame:SetSize(C.Widget.Width, C.Widget.Height)
    return frame
end
