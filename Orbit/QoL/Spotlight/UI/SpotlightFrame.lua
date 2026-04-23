-- [ SPOTLIGHT FRAME ]-------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L
local Constants = Orbit.Constants
local Async = Orbit.Async
local Skin = Orbit.Skin
local Matcher = Orbit.Spotlight.Search.Matcher
local IndexManager = Orbit.Spotlight.Index.IndexManager
local KeyNav = Orbit.Spotlight.UI.KeyNav
local RowPool = Orbit.Spotlight.UI.RowPool
local Catcher = Orbit.Spotlight.UI.ClickOutsideCatcher

local SpotlightFrame = {}
Orbit.Spotlight.UI.SpotlightFrame = SpotlightFrame

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local INPUT_WIDTH = 260
local INPUT_HEIGHT = 28
local CENTER_Y_OFFSET = 120
local LIST_MAX_VISIBLE = 7
local LIST_GAP_Y = -2
local LIST_INSET = 4
local ROW_HEIGHT = 32
local BORDER_SIZE = 2
local INPUT_FONT_SIZE = 14
local EMPTY_FONT_SIZE = 12
local DEBOUNCE_KEY = "Spotlight.Matcher"
local DEBOUNCE_DELAY = 0.05
local DEFAULT_MAX_RESULTS = 25
local INPUT_TEXT_PAD_LEFT = 8
local INPUT_TEXT_PAD_RIGHT = 8
local EMPTY_LABEL_PAD = 10

-- Creates a background texture + Orbit border on an otherwise plain frame, pulling colour from
-- Constants.Colors.Background and border style/colour from the global skin system.
local function ApplyOrbitFrame(frame)
    if not frame._orbitBg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(frame)
        frame._orbitBg = bg
    end
    local c = Constants.Colors.Background
    frame._orbitBg:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    Skin:SkinBorder(frame, frame, BORDER_SIZE)
end

local function GetGlobalFontName() return Orbit.db.GlobalSettings.Font end

-- [ STATE ]-----------------------------------------------------------------------------------------
SpotlightFrame._frame = nil
SpotlightFrame._input = nil
SpotlightFrame._list = nil
SpotlightFrame._scroll = nil
SpotlightFrame._scrollChild = nil
SpotlightFrame._catcher = nil
SpotlightFrame._results = {}
SpotlightFrame._selectedIndex = 0

-- [ SETTINGS ACCESS ]-------------------------------------------------------------------------------
local function GetAcct() return Orbit.db.AccountSettings end

local function GetEnabledKinds()
    local acct = GetAcct()
    local kinds = {}
    for _, k in ipairs(Orbit.Spotlight.Kinds) do
        kinds[k.kind] = acct["Spotlight_Src_" .. k.settingKey] ~= false
    end
    return kinds
end

local function GetMaxResults() return GetAcct().Spotlight_MaxResults or DEFAULT_MAX_RESULTS end
local function GetFuzzy() return GetAcct().Spotlight_Fuzzy ~= false end
local function GetHidePassives() return GetAcct().Spotlight_HidePassives ~= false end

-- [ FRAME BUILD ]-----------------------------------------------------------------------------------
local function BuildFrame(self)
    local root = CreateFrame("Frame", "OrbitSpotlightFrame", UIParent)
    root:SetFrameStrata(Constants.Strata.Dialog)
    root:SetFrameLevel(10)
    root:SetSize(INPUT_WIDTH, INPUT_HEIGHT)
    root:Hide()
    ApplyOrbitFrame(root)

    -- Auto-close on combat start or spec change. Combat: Spotlight can't SetAttribute during lockdown.
    -- Spec change: stale spellbook results would still carry the previous spec's secure attributes and
    -- activate the wrong spell if the user clicked them before the index rebuild propagated.
    root:RegisterEvent("PLAYER_REGEN_DISABLED")
    root:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    root:SetScript("OnEvent", function(_, event)
        if root:IsShown() and (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_SPECIALIZATION_CHANGED") then
            self:Close()
        end
    end)

    local input = CreateFrame("EditBox", nil, root)
    input:SetPoint("TOPLEFT", root, "TOPLEFT", INPUT_TEXT_PAD_LEFT, 0)
    input:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -INPUT_TEXT_PAD_RIGHT, 0)
    Skin:SkinText(input, { font = GetGlobalFontName(), textSize = INPUT_FONT_SIZE })
    input:SetAutoFocus(false)
    input:SetMaxLetters(80)
    input:SetTextColor(1, 1, 1, 1)

    -- Outer container holds the backdrop plus either the scroll or the empty label; swapping visibility
    -- is cheaper than rebuilding, and keeping the border on the container means scroll insets are simple.
    local list = CreateFrame("Frame", nil, root)
    list:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 0, LIST_GAP_Y)
    list:SetPoint("TOPRIGHT", root, "BOTTOMRIGHT", 0, LIST_GAP_Y)
    list:Hide()
    ApplyOrbitFrame(list)

    local scroll = CreateFrame("ScrollFrame", nil, list, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_INSET, -LIST_INSET)
    scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -LIST_INSET, LIST_INSET)
    if scroll.ScrollBar then scroll.ScrollBar:SetAlpha(0) end

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetWidth(scroll:GetWidth())
    scroll:SetScrollChild(scrollChild)
    scroll:SetScript("OnSizeChanged", function(_, w) scrollChild:SetWidth(w) end)

    local empty = list:CreateFontString(nil, "OVERLAY")
    Skin:SkinText(empty, { font = GetGlobalFontName(), textSize = EMPTY_FONT_SIZE, textColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 } })
    empty:SetPoint("LEFT", list, "LEFT", EMPTY_LABEL_PAD, 0)
    empty:SetText(L.PLU_SPT_NO_RESULTS)
    empty:Hide()

    RowPool:Init(scrollChild, scrollChild:GetWidth())

    self._frame = root
    self._input = input
    self._list = list
    self._scroll = scroll
    self._scrollChild = scrollChild
    self._empty = empty
    self._catcher = Catcher:Create(function() self:Close() end)

    input:SetScript("OnTextChanged", function() self:OnQueryChanged() end)
    input:SetScript("OnEscapePressed", function() self:Close() end)
    KeyNav:Attach(input, {
        OnMovePrev = function() self:MoveSelection(-1) end,
        OnMoveNext = function() self:MoveSelection(1) end,
        OnActivate = function() self:ActivateSelection() end,
        OnClose    = function() self:Close() end,
    })
end

-- [ ANCHORING ]-------------------------------------------------------------------------------------
-- Centered slightly above screen midpoint so the result list has room to drop down without crossing the centre.
local function AnchorCenter(root)
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "CENTER", 0, CENTER_Y_OFFSET)
end

-- [ RESULTS RENDER ]--------------------------------------------------------------------------------
-- All matched results are laid out into the scrollChild; only LIST_MAX_VISIBLE rows worth of height is
-- visible through the ScrollFrame, and the wheel scrolls the rest. Keyboard nav auto-scrolls below.
local function LayoutList(self)
    local count = #self._results
    RowPool:HideAll()

    if count == 0 then
        self._scroll:Hide()
        self._empty:Show()
        self._list:SetHeight(ROW_HEIGHT)
        self._list:Show()
        return
    end
    self._empty:Hide()

    local childWidth = self._scrollChild:GetWidth()
    for i = 1, count do
        local row = RowPool:Acquire(i)
        row:SetWidth(childWidth)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        Orbit.Spotlight.UI.ResultRow:Bind(row, self._results[i])
        -- Visual selection only follows explicit keyboard nav, not the implicit index used by Enter.
        Orbit.Spotlight.UI.ResultRow:SetSelected(row, self._keyboardNavUsed and i == self._selectedIndex)
        row:Show()
    end

    local visible = math.min(count, LIST_MAX_VISIBLE)
    self._scrollChild:SetHeight(count * ROW_HEIGHT)
    self._list:SetHeight(visible * ROW_HEIGHT + LIST_INSET * 2)
    self._scroll:SetVerticalScroll(0)
    self._scroll:Show()
    self._list:Show()
end

-- Keep the selected row in view when the user arrow-keys past the visible window.
local function ScrollToSelection(self)
    local idx = self._selectedIndex
    if idx < 1 then return end
    local yOffset = (idx - 1) * ROW_HEIGHT
    local visibleHeight = self._scroll:GetHeight()
    local current = self._scroll:GetVerticalScroll()
    if yOffset < current then
        self._scroll:SetVerticalScroll(yOffset)
    elseif yOffset + ROW_HEIGHT > current + visibleHeight then
        self._scroll:SetVerticalScroll(yOffset + ROW_HEIGHT - visibleHeight)
    end
end

-- [ EVENTS ]----------------------------------------------------------------------------------------
function SpotlightFrame:OnQueryChanged()
    local text = self._input:GetText() or ""
    Async:Debounce(DEBOUNCE_KEY, function()
        if not self._frame:IsShown() then return end
        local kinds = GetEnabledKinds()
        IndexManager:EnsureBuilt(kinds)
        local query = Orbit.Spotlight.Search.Tokenize:Fold(text)
        self._results = Matcher:Query(IndexManager:GetMaster(), query, kinds, GetMaxResults(), GetFuzzy(), GetHidePassives())
        self._selectedIndex = (#self._results > 0) and 1 or 0
        LayoutList(self)
    end, DEBOUNCE_DELAY)
end

function SpotlightFrame:MoveSelection(delta)
    local count = #self._results
    if count == 0 then return end
    self._keyboardNavUsed = true
    self._selectedIndex = ((self._selectedIndex - 1 + delta) % count) + 1
    RowPool:ForEach(function(row, i)
        Orbit.Spotlight.UI.ResultRow:SetSelected(row, i == self._selectedIndex)
    end)
    ScrollToSelection(self)
end

function SpotlightFrame:ActivateSelection()
    local idx = self._selectedIndex
    if idx < 1 then return end
    local row = RowPool:Acquire(idx)
    if not row:IsShown() then return end
    -- Programmatic :Click() runs through the secure dispatch for the bound attributes.
    row:Click("LeftButton")
    self:Close()
end

-- [ OPEN / CLOSE ]----------------------------------------------------------------------------------
function SpotlightFrame:Toggle()
    if self._frame and self._frame:IsShown() then self:Close() else self:Open() end
end

function SpotlightFrame:Open()
    if InCombatLockdown() then
        Orbit:Print(L.PLU_SPT_MSG_COMBAT)
        return
    end
    if not self._frame then BuildFrame(self) end
    AnchorCenter(self._frame)
    self._input:SetText("")
    self._results = {}
    self._selectedIndex = 0
    self._keyboardNavUsed = false
    LayoutList(self)
    self._catcher:Show()
    self._frame:Show()
    -- Defer focus by one frame so the hotkey keypress that triggered the binding has fully released before the EditBox starts capturing.
    C_Timer.After(0, function() if self._frame:IsShown() then self._input:SetFocus() end end)
end

function SpotlightFrame:Close()
    Async:ClearDebounce(DEBOUNCE_KEY)
    if self._input then self._input:ClearFocus(); self._input:SetText("") end
    if self._catcher then self._catcher:Hide() end
    if self._frame then self._frame:Hide() end
    self._results = {}
    self._selectedIndex = 0
end
