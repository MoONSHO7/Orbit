-- [ SHARED MEDIA DROPDOWN ]-------------------------------------------------------------------------
-- Reusable dropdown infrastructure for LSM media pickers (Texture, Font, etc.)
-- Handles: frame creation, scroll, ESC key, auto-close timer, button pooling.
-- Each consumer provides createItem/renderItem callbacks for domain-specific visuals.

local _, Orbit = ...
local Engine = Orbit.Engine
local math_max, math_min = math.max, math.min

local AUTO_CLOSE_DELAY = 0.2
local DROPDOWN_WIDTH = 200
local CONTENT_WIDTH = 192
local CONTENT_PADDING = 4
local CONTENT_INSET = 8

-- [ FACTORY ]-----------------------------------------------------------------------------------

local SharedMediaDropdown = {}
SharedMediaDropdown.CONTENT_WIDTH = CONTENT_WIDTH
Engine.SharedMediaDropdown = SharedMediaDropdown

-- Create a reusable dropdown attached to a picker frame.
-- @param owner        The picker frame (must have .Control and :IsVisible())
-- @param buttonHeight Per-item height in pixels
-- @param maxHeight    Maximum dropdown height
-- @param createItem   function(parent, index) → creates a new button frame for an item
-- @param renderItem   function(btn, itemData, isSelected) → configures button visuals
-- @param onSelect     function(itemData) → called when user picks an item
-- @return dropdown    The created dropdown frame
function SharedMediaDropdown:Create(owner, buttonHeight, maxHeight, createItem, renderItem, onSelect)
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
    dropdown.Content:SetPoint("TOPLEFT", CONTENT_PADDING, -CONTENT_PADDING)
    dropdown.Content:SetSize(CONTENT_WIDTH, 1)
    dropdown.scrollOffset = 0
    dropdown.buttons = {}

    dropdown:EnableMouseWheel(true)
    dropdown:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math_max(0, self.contentHeight - (self:GetHeight() - CONTENT_INSET))
        self.scrollOffset = math_max(0, math_min(maxOffset, self.scrollOffset - delta * buttonHeight))
        self.Content:SetPoint("TOPLEFT", CONTENT_PADDING, -CONTENT_PADDING + self.scrollOffset)
    end)

    -- Populate and show the dropdown with a list of items
    dropdown.Populate = function(self, items, selectedValue)
        local contentHeight = #items * buttonHeight
        local dropdownHeight = math_min(contentHeight + CONTENT_INSET, maxHeight)

        self:SetSize(DROPDOWN_WIDTH, dropdownHeight)
        self.Content:SetHeight(contentHeight)
        self.contentHeight = contentHeight
        self.scrollOffset = 0
        self.Content:SetPoint("TOPLEFT", CONTENT_PADDING, -CONTENT_PADDING)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", owner.Control, "BOTTOMLEFT", 0, -2)

        for i, item in ipairs(items) do
            local btn = self.buttons[i]
            if not btn then
                btn = createItem(self.Content, i)
                btn.Highlight = btn:CreateTexture(nil, "ARTWORK")
                btn.Highlight:SetAllPoints()
                btn.Highlight:SetColorTexture(0.4, 0.6, 1, 0.3)
                btn.Highlight:Hide()
                btn:SetScript("OnEnter", function(b) b.Highlight:Show() end)
                btn:SetScript("OnLeave", function(b) b.Highlight:Hide() end)
                self.buttons[i] = btn
            end

            btn:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -(i - 1) * buttonHeight)
            renderItem(btn, item, item == selectedValue)
            btn:SetScript("OnClick", function()
                onSelect(item)
                self:Hide()
            end)
            btn:Show()
        end

        for i = #items + 1, #self.buttons do
            self.buttons[i]:Hide()
        end

        self:Show()
    end

    -- ESC key handler
    dropdown:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Auto-close timer
    dropdown:SetScript("OnShow", function(self)
        self:SetPropagateKeyboardInput(true)
        self.closeTimer = 0
        self:SetScript("OnUpdate", function(d, elapsed)
            if not owner:IsVisible() then d:Hide() return end
            if not MouseIsOver(d) and not MouseIsOver(owner.Control) then
                d.closeTimer = (d.closeTimer or 0) + elapsed
                if d.closeTimer > AUTO_CLOSE_DELAY or IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                    d:Hide()
                end
            else
                d.closeTimer = 0
            end
        end)
    end)

    dropdown:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    -- Parent hide guard
    owner:HookScript("OnHide", function()
        dropdown:Hide()
    end)

    return dropdown
end
