local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout
local LSM = LibStub("LibSharedMedia-3.0")
local tinsert, tsort = table.insert, table.sort

local MAX_DROPDOWN_HEIGHT = 250
local BUTTON_HEIGHT = 22

-- TexturePicker Widget
-- 3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]
function Layout:CreateTexturePicker(parent, label, initialTexture, callback, previewColor)
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
        frame.Control.Arrow:SetSize(10, 10)
        frame.Control.Arrow:SetPoint("RIGHT", -4, 0)
        frame.Control.Arrow:SetAtlas("NPE_ArrowDown")

        frame.Control:SetScript("OnClick", function()
            if frame.ShowDropdown then frame:ShowDropdown() end
        end)
        frame.Control:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end)
        frame.Control:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0, 0, 0, 1)
        end)
    end

    -- Set parent
    frame:SetParent(parent)

    -- Configure control logic
    frame.selectedTexture = initialTexture or Engine.Constants.Settings.Texture.Default
    frame.previewColor = previewColor or { r = 0.8, g = 0.8, b = 0.8 }

    local function UpdatePreview()
        local path = LSM:Fetch("statusbar", frame.selectedTexture)
        local color = frame.previewColor
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
        local list = {}
        for name in pairs(LSM:HashTable("statusbar")) do
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
                    local path = LSM:Fetch("statusbar", textureName)
                    if path then
                        btn.Texture:SetTexture(path)
                        btn.Texture:SetVertexColor(0.6, 0.6, 0.6, 1)
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
    local C = Engine.Constants

    frame.Label:SetText(label)
    frame.Label:SetWidth(C.Widget.LabelWidth)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:ClearAllPoints()
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)

    frame.Control:ClearAllPoints()
    frame.Control:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
    frame.Control:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
    frame.Control:SetHeight(20)

    -- Value column reserved

    frame:SetSize(C.Widget.Width, C.Widget.Height)
    return frame
end
