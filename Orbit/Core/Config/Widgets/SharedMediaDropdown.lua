-- [ SHARED MEDIA DROPDOWN ]-------------------------------------------------------------------------
-- Reusable dropdown infrastructure for LSM media pickers (Texture, Font, etc.)
-- Handles: frame creation, virtualized scroll, search filter, ESC key, auto-close, button pooling.
-- Each consumer provides createItem/renderItem callbacks for domain-specific visuals.

local _, Orbit = ...
local Engine = Orbit.Engine
local math_max, math_min, math_floor = math.max, math.min, math.floor
local strfind, strlower = string.find, string.lower

local AUTO_CLOSE_DELAY = 0.2
local DROPDOWN_WIDTH = 200
local CONTENT_WIDTH = 192
local CONTENT_PADDING = 4
local SEARCH_HEIGHT = 22
local SEARCH_INSET = 6

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

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, dropdown, "InputBoxTemplate")
    searchBox:SetSize(CONTENT_WIDTH - 4, SEARCH_HEIGHT)
    searchBox:SetPoint("TOPLEFT", SEARCH_INSET, -CONTENT_PADDING)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(ChatFontNormal)
    searchBox:SetTextInsets(4, 4, 0, 0)
    dropdown.SearchBox = searchBox

    -- Content area (below search)
    local contentTop = CONTENT_PADDING + SEARCH_HEIGHT + 2
    dropdown.Content = CreateFrame("Frame", nil, dropdown)
    dropdown.Content:SetPoint("TOPLEFT", CONTENT_PADDING, -contentTop)
    dropdown.Content:SetSize(CONTENT_WIDTH, 1)
    dropdown.contentTop = contentTop
    dropdown.scrollOffset = 0
    dropdown.buttons = {}
    dropdown.filteredItems = {}
    dropdown.allItems = {}
    dropdown.selectedValue = nil

    -- Calculate visible slot count from maxHeight
    local listAreaHeight = maxHeight - contentTop - CONTENT_PADDING
    local visibleSlots = math_floor(listAreaHeight / buttonHeight)
    dropdown.visibleSlots = visibleSlots

    -- [ VIRTUAL SCROLL RENDER ]----------------------------------------------------------------
    local function RenderVisible(self)
        local items = self.filteredItems
        local offset = self.scrollOffset
        local selected = self.selectedValue
        for slot = 1, self.visibleSlots do
            local btn = self.buttons[slot]
            if not btn then
                btn = createItem(self.Content, slot)
                btn.Highlight = btn:CreateTexture(nil, "ARTWORK")
                btn.Highlight:SetAllPoints()
                btn.Highlight:SetColorTexture(0.4, 0.6, 1, 0.3)
                btn.Highlight:Hide()
                btn:SetScript("OnEnter", function(b) b.Highlight:Show() end)
                btn:SetScript("OnLeave", function(b) b.Highlight:Hide() end)
                self.buttons[slot] = btn
            end
            local dataIndex = offset + slot
            if dataIndex <= #items then
                local item = items[dataIndex]
                btn:ClearAllPoints()
                local scale = self.Content:GetEffectiveScale()
                btn:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, Engine.Pixel:Snap(-(slot - 1) * buttonHeight, scale))
                renderItem(btn, item, item == selected)
                btn:SetScript("OnClick", function()
                    onSelect(item)
                    self:Hide()
                end)
                btn:Show()
            else
                btn:Hide()
            end
        end
    end

    -- [ FILTER ]-------------------------------------------------------------------------------
    local function ApplyFilter(self)
        local query = strlower(searchBox:GetText() or "")
        local items = self.allItems
        local filtered = {}
        if query == "" then
            for i = 1, #items do filtered[i] = items[i] end
        else
            for i = 1, #items do
                if strfind(strlower(items[i]), query, 1, true) then
                    filtered[#filtered + 1] = items[i]
                end
            end
        end
        self.filteredItems = filtered
        self.scrollOffset = 0
        local contentHeight = #filtered * buttonHeight
        self.Content:SetHeight(math_max(1, contentHeight))
        self.contentHeight = contentHeight
        local listH = math_min(contentHeight, self.visibleSlots * buttonHeight)
        self:SetSize(DROPDOWN_WIDTH, self.contentTop + listH + CONTENT_PADDING)
        RenderVisible(self)
    end

    searchBox:SetScript("OnTextChanged", function() ApplyFilter(dropdown) end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); dropdown:Hide() end)

    -- [ MOUSE WHEEL ]--------------------------------------------------------------------------
    dropdown:EnableMouseWheel(true)
    dropdown:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math_max(0, #self.filteredItems - self.visibleSlots)
        self.scrollOffset = math_max(0, math_min(maxOffset, self.scrollOffset - delta))
        RenderVisible(self)
    end)

    -- [ POPULATE ]-----------------------------------------------------------------------------
    dropdown.Populate = function(self, items, selectedValue)
        self.allItems = items
        self.selectedValue = selectedValue
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", owner.Control, "BOTTOMLEFT", 0, -2)
        searchBox:SetText("")
        ApplyFilter(self)
        self:Show()
        searchBox:SetFocus()
    end

    -- [ ESC KEY ]------------------------------------------------------------------------------
    dropdown:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- [ AUTO-CLOSE ]--------------------------------------------------------------------------
    dropdown:SetScript("OnShow", function(self)
        self:SetPropagateKeyboardInput(true)
        self.closeTimer = 0
        self:SetScript("OnUpdate", function(d, elapsed)
            if not owner:IsVisible() then d:Hide() return end
            local mouseOver = MouseIsOver(d) or MouseIsOver(owner.Control)
            if not mouseOver and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
                d:Hide()
                return
            end
            if searchBox:HasFocus() then d.closeTimer = 0 return end
            if not mouseOver then
                d.closeTimer = (d.closeTimer or 0) + elapsed
                if d.closeTimer > AUTO_CLOSE_DELAY then d:Hide() end
            else
                d.closeTimer = 0
            end
        end)
    end)

    dropdown:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        searchBox:ClearFocus()
    end)

    -- Parent hide guard
    owner:HookScript("OnHide", function()
        dropdown:Hide()
    end)

    return dropdown
end
