local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout
local LSM = LibStub("LibSharedMedia-3.0")

local MAX_DROPDOWN_HEIGHT = 250
local BUTTON_HEIGHT = 22

-- TexturePicker Widget
-- 3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]
function Layout:CreateTexturePicker(parent, label, initialTexture, callback, previewColor)
    -- Pool retrieval
    if not self.texturePool then
        self.texturePool = {}
    end
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
            if frame.ShowDropdown then
                frame:ShowDropdown()
            end
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
        if #text > 22 then
            text = string.sub(text, 1, 20) .. ".."
        end
        frame.Control.Text:SetText(text)
    end

    local function GetTextureList()
        local list = {}
        for name in pairs(LSM:HashTable("statusbar")) do
            table.insert(list, name)
        end
        table.sort(list)
        return list
    end

    frame.ShowDropdown = function()
        if not frame.DropdownFrame then
            local dropdown = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            dropdown:SetFrameStrata("FULLSCREEN_DIALOG")
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
        local textures = GetTextureList()

        local contentHeight = #textures * BUTTON_HEIGHT
        local dropdownHeight = math.min(contentHeight + 8, MAX_DROPDOWN_HEIGHT)

        dropdown:SetSize(200, dropdownHeight)
        dropdown.Content:SetHeight(contentHeight)
        dropdown.contentHeight = contentHeight
        dropdown.scrollOffset = 0
        dropdown.Content:SetPoint("TOPLEFT", 4, -4)
        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOPLEFT", frame.Control, "BOTTOMLEFT", 0, -2)

        for i, textureName in ipairs(textures) do
            local btn = dropdown.buttons[i]
            if not btn then
                btn = CreateFrame("Button", nil, dropdown.Content, "BackdropTemplate")
                btn:SetSize(192, BUTTON_HEIGHT)

                btn.Texture = btn:CreateTexture(nil, "BACKGROUND")
                btn.Texture:SetAllPoints()

                btn.Name = btn:CreateFontString(nil, "OVERLAY", Orbit.Constants.UI.LabelFont)
                btn.Name:SetPoint("CENTER")
                btn.Name:SetShadowOffset(1, -1)
                btn.Name:SetShadowColor(0, 0, 0, 1)

                btn.Highlight = btn:CreateTexture(nil, "ARTWORK")
                btn.Highlight:SetAllPoints()
                btn.Highlight:SetColorTexture(0.4, 0.6, 1, 0.3)
                btn.Highlight:Hide()

                btn:SetScript("OnEnter", function(self)
                    self.Highlight:Show()
                end)
                btn:SetScript("OnLeave", function(self)
                    self.Highlight:Hide()
                end)

                dropdown.buttons[i] = btn
            end

            btn:SetPoint("TOPLEFT", dropdown.Content, "TOPLEFT", 0, -(i - 1) * BUTTON_HEIGHT)
            btn.Name:SetText(textureName)

            local path = LSM:Fetch("statusbar", textureName)
            if path then
                btn.Texture:SetTexture(path)
                btn.Texture:SetVertexColor(0.6, 0.6, 0.6, 1)
            else
                btn.Texture:SetColorTexture(0.3, 0.3, 0.3, 1)
            end

            btn:SetScript("OnClick", function()
                frame.selectedTexture = textureName
                UpdatePreview()
                dropdown:Hide()
                if callback then
                    callback(textureName)
                end
            end)

            btn:Show()
        end

        for i = #textures + 1, #dropdown.buttons do
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
    frame.Control:SetHeight(20)

    -- Value column reserved

    frame:SetSize(260, 32)
    return frame
end
