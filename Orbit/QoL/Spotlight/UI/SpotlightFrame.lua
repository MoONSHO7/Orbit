-- [ SPOTLIGHT FRAME ]--------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L
local Constants = Orbit.Constants
local Async = Orbit.Async
local Skin = Orbit.Skin
local Matcher = Orbit.Spotlight.Search.Matcher
local IndexManager = Orbit.Spotlight.Index.IndexManager
local RowPool = Orbit.Spotlight.UI.RowPool
local Catcher = Orbit.Spotlight.UI.ClickOutsideCatcher
local Pixel = Orbit.Engine.Pixel

local SpotlightFrame = {}
Orbit.Spotlight.UI.SpotlightFrame = SpotlightFrame

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
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
local HINT_COLOR = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
local HINT_SAMPLE_COUNT = 3

local function ApplyOrbitFrame(frame)
    if not frame._orbitBg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(frame)
        frame._orbitBg = bg
        -- Register so SkinBorder's rounded nineslice path clips the backdrop to the corners.
        Skin:RegisterMaskedSurface(frame, bg)
    end
    local c = Constants.Colors.Background
    frame._orbitBg:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    Skin:SkinBorder(frame, frame, BORDER_SIZE)
end

local function GetGlobalFontName() return Orbit.db.GlobalSettings.Font end

-- [ STATE ]------------------------------------------------------------------------------------------
SpotlightFrame._frame = nil
SpotlightFrame._input = nil
SpotlightFrame._list = nil
SpotlightFrame._scroll = nil
SpotlightFrame._scrollChild = nil
SpotlightFrame._catcher = nil
SpotlightFrame._results = {}

-- [ SETTINGS ACCESS ]--------------------------------------------------------------------------------
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
local function GetScale() return GetAcct().Spotlight_Scale or 1.0 end

-- [ HINT SAMPLE ]------------------------------------------------------------------------------------
local function PickHintSamples()
    local enabled = GetEnabledKinds()
    local labels = {}
    for _, k in ipairs(Orbit.Spotlight.Kinds) do
        local label = L[k.labelKey]
        if label and enabled[k.kind] then labels[#labels + 1] = label:lower() end
    end
    for i = #labels, 2, -1 do
        local j = math.random(i)
        labels[i], labels[j] = labels[j], labels[i]
    end
    local take = math.min(HINT_SAMPLE_COUNT, #labels)
    if take == 0 then return "" end
    local out = {}
    for i = 1, take do out[i] = labels[i] end
    return table.concat(out, ", ") .. "..."
end

-- [ FRAME BUILD ]------------------------------------------------------------------------------------
local function BuildFrame(self)
    local root = CreateFrame("Frame", "OrbitSpotlightFrame", UIParent)
    root:SetFrameStrata(Constants.Strata.Dialog)
    root:SetFrameLevel(10)
    root:SetSize(INPUT_WIDTH, INPUT_HEIGHT)
    root:Hide()
    ApplyOrbitFrame(root)

    -- Spec change auto-closes to drop stale spellbook attributes before they dispatch the old spec's spells.
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

    local hint = input:CreateFontString(nil, "OVERLAY")
    Skin:SkinText(hint, { font = GetGlobalFontName(), textSize = INPUT_FONT_SIZE, textColor = HINT_COLOR })
    hint:SetPoint("LEFT", input, "LEFT", 0, 0)
    hint:SetJustifyH("LEFT")

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
    scrollChild:SetWidth(Pixel:Snap(scroll:GetWidth(), scrollChild:GetEffectiveScale()))
    scroll:SetScrollChild(scrollChild)
    scroll:SetScript("OnSizeChanged", function(_, w) scrollChild:SetWidth(Pixel:Snap(w, scrollChild:GetEffectiveScale())) end)

    local empty = list:CreateFontString(nil, "OVERLAY")
    Skin:SkinText(empty, { font = GetGlobalFontName(), textSize = EMPTY_FONT_SIZE, textColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 } })
    empty:SetPoint("LEFT", list, "LEFT", EMPTY_LABEL_PAD, 0)
    empty:SetText(L.PLU_SPT_NO_RESULTS)
    empty:Hide()

    RowPool:Init(scrollChild, scrollChild:GetWidth())

    self._frame = root
    self._input = input
    self._hint = hint
    self._list = list
    self._scroll = scroll
    self._scrollChild = scrollChild
    self._empty = empty
    self._catcher = Catcher:Create(function() self:Close() end)

    input:SetScript("OnTextChanged", function()
        hint:SetShown((input:GetText() or "") == "")
        self:OnQueryChanged()
    end)
    input:SetScript("OnEscapePressed", function() self:Close() end)
    -- Propagate non-typing keys so global bindings still fire while the EditBox has focus.
    local EDIT_KEYS = { BACKSPACE = true, DELETE = true, LEFT = true, RIGHT = true, HOME = true, END = true, INSERT = true }
    input:SetScript("OnKeyDown", function(self, key)
        if key == "SPACE" or EDIT_KEYS[key] or (#key == 1 and key:match("[%a%d]")) then
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    input:SetScript("OnChar", function(self, char)
        if char and not char:match("[%a%d ]") then
            local pos = self:GetCursorPosition()
            local text = self:GetText()
            if pos >= 1 then
                self:SetText(text:sub(1, pos - 1) .. text:sub(pos + 1))
                self:SetCursorPosition(pos - 1)
            end
        end
    end)
end

-- [ ANCHORING ]--------------------------------------------------------------------------------------
local function AnchorCenter(root)
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "CENTER", 0, CENTER_Y_OFFSET)
end

-- [ RESULTS RENDER ]---------------------------------------------------------------------------------
local function LayoutList(self)
    local count = #self._results
    RowPool:HideAll()

    if count == 0 then
        -- "No Results" only shows for queries that ran and returned nothing; empty input shows neither label nor list.
        local hasQuery = (self._input:GetText() or "") ~= ""
        self._scroll:Hide()
        if not hasQuery then
            self._empty:Hide()
            self._list:Hide()
            return
        end
        self._empty:Show()
        self._list:SetHeight(ROW_HEIGHT)
        self._list:Show()
        return
    end
    self._empty:Hide()

    local childWidth = self._scrollChild:GetWidth()
    local childScale = self._scrollChild:GetEffectiveScale()
    local rowStride = Pixel:Snap(ROW_HEIGHT, childScale)
    for i = 1, count do
        local row = RowPool:Acquire(i)
        row:SetSize(childWidth, rowStride)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 0, -(i - 1) * rowStride)
        Orbit.Spotlight.UI.ResultRow:Bind(row, self._results[i])
        row:Show()
    end

    local visible = math.min(count, LIST_MAX_VISIBLE)
    self._scrollChild:SetHeight(count * rowStride)
    self._list:SetHeight(visible * rowStride + Pixel:Snap(LIST_INSET * 2, self._list:GetEffectiveScale()))
    self._scroll:SetVerticalScroll(0)
    self._scroll:Show()
    self._list:Show()
end

-- [ EVENTS ]-----------------------------------------------------------------------------------------
function SpotlightFrame:OnQueryChanged()
    local text = self._input:GetText() or ""
    Async:Debounce(DEBOUNCE_KEY, function()
        if not self._frame:IsShown() then return end
        local kinds = GetEnabledKinds()
        IndexManager:EnsureBuilt(kinds)
        local query = Orbit.Spotlight.Search.Tokenize:Fold(text)
        self._results = Matcher:Query(IndexManager:GetMaster(), query, kinds, GetMaxResults(), GetFuzzy(), GetHidePassives())
        LayoutList(self)
    end, DEBOUNCE_DELAY)
end

-- [ OPEN / CLOSE ]-----------------------------------------------------------------------------------
function SpotlightFrame:Toggle()
    if self._frame and self._frame:IsShown() then self:Close() else self:Open() end
end

function SpotlightFrame:Open()
    if InCombatLockdown() then
        Orbit:Print(L.PLU_SPT_MSG_COMBAT)
        return
    end
    if not self._frame then BuildFrame(self) end
    self._frame:SetScale(GetScale())
    ApplyOrbitFrame(self._frame)
    ApplyOrbitFrame(self._list)
    AnchorCenter(self._frame)
    self._input:SetText("")
    self._hint:SetText(PickHintSamples())
    self._hint:Show()
    self._results = {}
    LayoutList(self)
    self._catcher:Show()
    self._frame:Show()
    -- Defer focus one frame so the triggering hotkey keypress releases before the EditBox captures.
    C_Timer.After(0, function() if self._frame:IsShown() then self._input:SetFocus() end end)
end

function SpotlightFrame:Close()
    Async:ClearDebounce(DEBOUNCE_KEY)
    if self._input then self._input:ClearFocus(); self._input:SetText("") end
    if self._catcher then self._catcher:Hide() end
    if self._frame then self._frame:Hide() end
    self._results = {}
end
