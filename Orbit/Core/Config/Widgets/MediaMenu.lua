-- [ MEDIA MENU ]-------------------------------------------------------------------------------------
-- Custom dropdown popup for LSM media pickers (Font, Texture). Fully self-owned layout: a search bar
-- pinned at the top, a virtualized row list below it, Orbit-* entries sorted first. Because the
-- layout is ours, the search bar genuinely stays fixed and rows never render behind it.
--
-- The consuming picker supplies createRow / renderRow / onSelect; MediaMenu owns search, sorting,
-- virtualization, scrolling and the open/close lifecycle.

local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout
local strfind, strlower = string.find, string.lower
local tinsert, tsort = table.insert, table.sort
local math_floor, math_max, math_min = math.floor, math.max, math.min

local POPUP_WIDTH = 230
local PAD = 5
local SEARCH_HEIGHT = 26
local AUTO_CLOSE_DELAY = 0.2
local MAX_VISIBLE_ROWS = 10   -- hard cap on rows shown at once; beyond this the list scrolls
local DIVIDER = {}            -- sentinel list entry: a section line between Orbit and Shared Media

local MediaMenu = {}
Engine.MediaMenu = MediaMenu

local function IsOrbitName(name)
    return strfind(name, "^Orbit") ~= nil
end

local function SortNames(items)
    tsort(items, function(a, b) return strlower(a) < strlower(b) end)
end

-- [ FACTORY ]----------------------------------------------------------------------------------------
-- owner = the picker's preview control (popup anchors below it; closes when it hides)
-- opts  = { rowHeight, maxHeight, firstItem?, createRow(parent), renderRow(row, name, sel), onSelect(name) }
function MediaMenu:Create(owner, opts)
    local rowHeight = opts.rowHeight

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata(Orbit.Constants.Strata.FullscreenDialog)
    popup:SetFrameLevel(1000)
    popup:SetWidth(POPUP_WIDTH)
    popup:SetClipsChildren(true)
    popup:EnableMouse(true)
    popup:Hide()
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
    popup:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- [ SEARCH BAR ]-- pinned: a direct child of the popup, never part of the scrolled list
    local searchStrip = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    searchStrip:SetHeight(SEARCH_HEIGHT)
    searchStrip:SetPoint("TOPLEFT", PAD, -PAD)
    searchStrip:SetPoint("TOPRIGHT", -PAD, -PAD)
    searchStrip:SetBackdrop(Layout.ORBIT_INPUT_BACKDROP)
    searchStrip:SetBackdropColor(0, 0, 0, 0.6)
    searchStrip:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local search = CreateFrame("EditBox", nil, searchStrip, "SearchBoxTemplate")
    search:SetPoint("TOPLEFT", 8, -1)
    search:SetPoint("BOTTOMRIGHT", -6, 1)
    search:SetFontObject(ChatFontNormal)
    search:SetAutoFocus(false)
    if search.Left then search.Left:Hide() end
    if search.Middle then search.Middle:Hide() end
    if search.Right then search.Right:Hide() end
    popup.Search = search

    -- [ CONTENT ]-- the scrolled list lives entirely below the search bar
    local content = CreateFrame("Frame", nil, popup)
    content:SetPoint("TOPLEFT", searchStrip, "BOTTOMLEFT", 0, -PAD)
    content:SetPoint("TOPRIGHT", searchStrip, "BOTTOMRIGHT", 0, -PAD)

    -- visibleSlots caps how many rows render at once (and how many row frames are pooled): the
    -- lesser of what maxHeight allows and the MAX_VISIBLE_ROWS hard cap. The popup itself is sized
    -- to the filtered entry count by ResizeToContent, so a short list never shows an empty box.
    local fitByHeight = math_max(1, math_floor((opts.maxHeight - SEARCH_HEIGHT - PAD * 3) / rowHeight))
    local visibleSlots = math_min(MAX_VISIBLE_ROWS, fitByHeight)

    popup.rows = {}
    popup.dividers = {}
    popup.filtered = {}
    popup.allItems = {}
    popup.scrollOffset = 0
    popup.selected = nil

    -- [ VIRTUALIZED RENDER ]-- only `visibleSlots` row frames ever exist; they are repositioned
    -- and re-rendered as the offset changes, so a 200-entry list still costs ~10 frames.
    local function RenderVisible()
        local items = popup.filtered
        local scale = content:GetEffectiveScale()
        for slot = 1, visibleSlots do
            local row = popup.rows[slot]
            if not row then
                row = opts.createRow(content)
                row:SetHeight(rowHeight)
                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(0.4, 0.6, 1, 0.22)
                popup.rows[slot] = row
            end
            local divider = popup.dividers[slot]
            if not divider then
                divider = content:CreateTexture(nil, "ARTWORK")
                divider:SetHeight(1)
                divider:SetColorTexture(0.35, 0.35, 0.35, 1)
                popup.dividers[slot] = divider
            end
            local item = items[popup.scrollOffset + slot]
            local y = Engine.Pixel:Snap(-(slot - 1) * rowHeight, scale)
            if item == DIVIDER then
                local dy = Engine.Pixel:Snap(y - rowHeight / 2, scale)
                divider:ClearAllPoints()
                divider:SetPoint("LEFT", content, "TOPLEFT", 12, dy)
                divider:SetPoint("RIGHT", content, "TOPRIGHT", -12, dy)
                divider:Show()
                row:Hide()
            elseif item then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
                row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
                opts.renderRow(row, item, item == popup.selected)
                row:SetScript("OnClick", function()
                    opts.onSelect(item)
                    popup:Hide()
                end)
                row:Show()
                divider:Hide()
            else
                row:Hide()
                divider:Hide()
            end
        end
    end

    -- Size the popup to the filtered entry count, clamped to visibleSlots -- a 3-item list
    -- yields a 3-row popup, not an empty maxHeight box.
    local function ResizeToContent()
        local rows = math_max(1, math_min(#popup.filtered, visibleSlots))
        content:SetHeight(rows * rowHeight)
        popup:SetHeight(SEARCH_HEIGHT + rows * rowHeight + PAD * 3)
    end

    -- [ FILTER + SORT ]
    local function ApplyFilter()
        local query = strlower(search:GetText() or "")
        local filtered = {}
        if opts.firstItem and (query == "" or strfind(strlower(opts.firstItem), query, 1, true)) then
            tinsert(filtered, opts.firstItem)
        end
        local orbit, other = {}, {}
        for _, name in ipairs(popup.allItems) do
            if query == "" or strfind(strlower(name), query, 1, true) then
                tinsert(IsOrbitName(name) and orbit or other, name)
            end
        end
        SortNames(orbit)
        SortNames(other)
        for _, name in ipairs(orbit) do tinsert(filtered, name) end
        if #orbit > 0 and #other > 0 then tinsert(filtered, DIVIDER) end
        for _, name in ipairs(other) do tinsert(filtered, name) end
        popup.filtered = filtered
        popup.scrollOffset = 0
        ResizeToContent()
        RenderVisible()
    end

    search:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        ApplyFilter()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        popup:Hide()
    end)

    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math_max(0, #popup.filtered - visibleSlots)
        popup.scrollOffset = math_max(0, math_min(maxOffset, popup.scrollOffset - delta))
        RenderVisible()
    end)

    function popup:Populate(items, selected)
        self.allItems = items
        self.selected = selected
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
        search:SetText("")
        ApplyFilter()
        self:Show()
        search:SetFocus()
    end

    -- [ CLOSE LIFECYCLE ]
    popup:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    popup:SetScript("OnShow", function(self)
        self:SetPropagateKeyboardInput(true)
        self.closeTimer = 0
        self:SetScript("OnUpdate", function(d, elapsed)
            if not owner:IsVisible() then d:Hide() return end
            local over = MouseIsOver(d) or MouseIsOver(owner)
            if not over and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
                d:Hide()
                return
            end
            if search:HasFocus() then
                d.closeTimer = 0
            elseif not over then
                d.closeTimer = d.closeTimer + elapsed
                if d.closeTimer > AUTO_CLOSE_DELAY then d:Hide() end
            else
                d.closeTimer = 0
            end
        end)
    end)
    popup:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        search:ClearFocus()
    end)

    return popup
end
