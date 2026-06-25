-- [ FIRST-LOGIN WELCOME ] ---------------------------------------------------------------------------
-- strings live in Orbit/Localization/Domains/Tours.lua under TOUR_WELCOME_*.
local _, Orbit = ...
local L = Orbit.L
local Engine = Orbit.Engine
local Layout = Engine.Layout

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local WELCOME_WIDTH = 360
local KEYBIND_WIDTH = 380
local PAD = 16
local BG_INSET_LEFT = 6
local BG_INSET_TOP = 21
local BG_INSET_RIGHT = 2
local BG_INSET_BOTTOM = 2
local STREAKS_OVERSHOOT_X = 2
local STREAKS_OVERSHOOT_Y = 7
local TITLE_OFFSET = 6
local BTN_HEIGHT = 24
local BTN_GAP = 8
local PROMPT_GAP = 6
local ROW_HEIGHT = 22
local ROW_SPACING = 32
local ROW_LABEL_WIDTH = 150
local BIND_BTN_WIDTH = 160
local WELCOME_LEVEL = 1000
local KEYBIND_LEVEL = 1100
local NINESLICE_LEVEL_OFFSET = 1
local CONTENT_LEVEL_OFFSET = 10
local SHOW_DELAY = 1.2

-- [ BINDING DEFAULTS ] ------------------------------------------------------------------------------
-- primary = numpad keys; fallback used only when the primary is already taken (no numpad-presence API).
local BIND_DEFS = {
    { action = "ORBIT_SPOTLIGHT_TOGGLE",   primary = "NUMPADMINUS", fallback = "SHIFT-=" },
    { action = "ORBIT_MINIMAP_TOGGLEVIEW", primary = "NUMPADPLUS",  fallback = "SHIFT--" },
}

local function KeyIsFree(key, action)
    local bound = GetBindingAction(key)
    return bound == nil or bound == "" or bound == action
end

local function ApplyDefaultBinds()
    local changed = false
    for _, def in ipairs(BIND_DEFS) do
        if not GetBindingKey(def.action) then
            if KeyIsFree(def.primary, def.action) then
                SetBinding(def.primary, def.action); changed = true
            elseif KeyIsFree(def.fallback, def.action) then
                SetBinding(def.fallback, def.action); changed = true
            end
        end
    end
    if changed then SaveBindings(GetCurrentBindingSet()) end
end

-- [ CHROME ] ----------------------------------------------------------------------------------------
-- Canvas Mode frame skin: NineSlice metal panel + tiled rock background + title streaks.
local function BuildChrome(frame, titleText)
    frame.NineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
    frame.NineSlice.layoutType = "ButtonFrameTemplateNoPortrait"
    NineSliceUtil.ApplyLayoutByName(frame.NineSlice, "ButtonFrameTemplateNoPortrait")
    frame.NineSlice:SetFrameLevel(frame:GetFrameLevel() + NINESLICE_LEVEL_OFFSET)

    frame.Bg = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    frame.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
    frame.Bg:SetHorizTile(true)
    frame.Bg:SetVertTile(true)
    frame.Bg:SetPoint("TOPLEFT", BG_INSET_LEFT, -BG_INSET_TOP)
    frame.Bg:SetPoint("BOTTOMRIGHT", -BG_INSET_RIGHT, BG_INSET_BOTTOM)

    frame.Streaks = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    frame.Streaks:SetAtlas("_UI-Frame-TopTileStreaks", true)
    frame.Streaks:SetPoint("TOPLEFT", frame.Bg, "TOPLEFT", -STREAKS_OVERSHOOT_X, STREAKS_OVERSHOOT_Y)
    frame.Streaks:SetPoint("TOPRIGHT", frame.Bg, "TOPRIGHT", STREAKS_OVERSHOOT_X, STREAKS_OVERSHOOT_Y)

    -- Title above the NineSlice so the metal top bar never overdraws it.
    frame.contentLevel = frame.NineSlice:GetFrameLevel() + CONTENT_LEVEL_OFFSET
    local tc = CreateFrame("Frame", nil, frame)
    tc:SetFrameLevel(frame.contentLevel)
    tc:SetPoint("TOPLEFT", BG_INSET_LEFT, -TITLE_OFFSET)
    tc:SetPoint("TOPRIGHT", -BG_INSET_LEFT, -TITLE_OFFSET)
    tc:SetHeight(BG_INSET_TOP)
    frame.title = tc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", tc, "TOP")
    frame.title:SetText(titleText)
end

-- [ BINDING BUTTON ] --------------------------------------------------------------------------------
-- In-game Keybinds menu button (UIMenuButtonStretchTemplate + select highlight) with the KeybindListener capture flow.
local activeBindButton

local function RefreshBindText(btn)
    local key = GetBindingKey(btn.action)
    local text = key and GetBindingText(key)
    if text and text ~= "" then
        btn:SetText(text)
    else
        btn:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(NOT_BOUND))
    end
end

local function StopListening(btn)
    btn.listening = false
    if activeBindButton == btn then activeBindButton = nil end
    local box = btn:GetParent()
    if box.Prompt then box.Prompt:Hide() end
    btn.SelectedHighlight:Hide()
    btn:EnableKeyboard(false)
    btn:EnableMouseWheel(false)
    btn:SetPropagateKeyboardInput(true)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnKeyDown", nil)
    btn:SetScript("OnKeyUp", nil)
    btn:SetScript("OnMouseWheel", nil)
    RefreshBindText(btn)
end

local function ProcessBindInput(btn, input)
    -- Screenshot binding is sacrosanct: run it and bail without rebinding, matching KeybindListener.
    if GetBindingFromClick(input) == "SCREENSHOT" then RunBinding("SCREENSHOT"); return end
    local key = GetConvertedKeyOrButton(input)
    if key == "ESCAPE" then StopListening(btn); return end
    if IsKeyPressIgnoredForBinding(key) then return end
    local newKey = CreateKeyChordStringUsingMetaKeyState(key)
    -- Clear the action's existing keys first so a single action never holds two binds.
    local key1, key2 = GetBindingKey(btn.action)
    if key1 then SetBinding(key1, nil) end
    if key2 then SetBinding(key2, nil) end
    SetBinding(newKey, btn.action)
    SaveBindings(GetCurrentBindingSet())
    StopListening(btn)
end

local function StartListening(btn)
    if activeBindButton and activeBindButton ~= btn then StopListening(activeBindButton) end
    activeBindButton = btn
    btn.listening = true
    local box = btn:GetParent()
    if box.Prompt then box.Prompt:Show() end
    btn.SelectedHighlight:Show()
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:EnableMouseWheel(true)
    -- Consume keyboard so ESCAPE cancels the capture instead of closing the box.
    btn:EnableKeyboard(true)
    btn:SetPropagateKeyboardInput(false)
    btn:SetScript("OnKeyDown", function(self, k) ProcessBindInput(self, k) end)
    btn:SetScript("OnKeyUp", function() end)
    btn:SetScript("OnMouseWheel", function(self, d) ProcessBindInput(self, d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
end

local function CreateBindButton(parent, action)
    local btn = CreateFrame("Button", nil, parent, "UIMenuButtonStretchTemplate")
    btn.action = action
    btn:SetSize(BIND_BTN_WIDTH, ROW_HEIGHT)
    btn:RegisterForClicks("LeftButtonUp")
    btn.SelectedHighlight = btn:CreateTexture(nil, "OVERLAY")
    btn.SelectedHighlight:SetTexture("Interface\\Buttons\\UI-Silver-Button-Select")
    btn.SelectedHighlight:SetBlendMode("ADD")
    btn.SelectedHighlight:SetPoint("CENTER", 0, -3)
    btn.SelectedHighlight:SetSize(BIND_BTN_WIDTH, ROW_HEIGHT)
    btn.SelectedHighlight:Hide()
    btn:SetScript("OnClick", function(self, mouseButton, isDown)
        if self.listening then
            if isDown then ProcessBindInput(self, mouseButton) end
        else
            StartListening(self)
        end
    end)
    RefreshBindText(btn)
    return btn
end

-- [ KEYBIND BOX ] -----------------------------------------------------------------------------------
local keybinds = CreateFrame("Frame", "OrbitWelcomeKeybinds", UIParent)
keybinds:SetFrameStrata(Orbit.Constants.Strata.Topmost)
keybinds:SetFrameLevel(KEYBIND_LEVEL)
keybinds:SetWidth(KEYBIND_WIDTH)
keybinds:SetClampedToScreen(true)
keybinds:EnableMouse(true)
keybinds:Hide()
BuildChrome(keybinds, L.TOUR_WELCOME_SET_KEYBINDS)

do
    local rowTop = BG_INSET_TOP + PAD
    for i, def in ipairs(BIND_DEFS) do
        local y = -(rowTop + (i - 1) * ROW_SPACING)
        local label = keybinds:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetWidth(ROW_LABEL_WIDTH)
        label:SetHeight(ROW_HEIGHT)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetPoint("TOPLEFT", keybinds, "TOPLEFT", PAD, y)
        local btn = CreateBindButton(keybinds, def.action)
        btn:SetFrameLevel(keybinds.contentLevel)
        btn:SetPoint("TOPRIGHT", keybinds, "TOPRIGHT", -PAD, y)
        keybinds["row" .. i] = btn
        keybinds["label" .. i] = label
    end
end

keybinds:SetHeight(BG_INSET_TOP + PAD + ROW_SPACING * #BIND_DEFS + PAD + BTN_HEIGHT + PAD)

-- Apply defaults + refresh labels on show (BINDING_NAME globals are set by sibling addons after load).
keybinds:SetScript("OnShow", function()
    ApplyDefaultBinds()
    for i, def in ipairs(BIND_DEFS) do
        keybinds["label" .. i]:SetText(GetBindingName(def.action))
        RefreshBindText(keybinds["row" .. i])
    end
end)

keybinds.DoneButton = Layout:CreateButton(keybinds, L.CMN_DONE, function() keybinds:Hide() end)
keybinds.DoneButton:SetHeight(BTN_HEIGHT)
keybinds.DoneButton:SetWidth(KEYBIND_WIDTH - PAD * 2)
keybinds.DoneButton:SetFrameLevel(keybinds.contentLevel)
keybinds.DoneButton:SetPoint("BOTTOM", keybinds, "BOTTOM", 0, PAD)

-- Capture-in-progress hint, shown only while a binding button is listening.
keybinds.Prompt = keybinds:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
keybinds.Prompt:SetWidth(KEYBIND_WIDTH - PAD * 2)
keybinds.Prompt:SetJustifyH("CENTER")
keybinds.Prompt:SetPoint("BOTTOM", keybinds.DoneButton, "TOP", 0, PROMPT_GAP)
keybinds.Prompt:SetText(L.TOUR_WELCOME_KEYBIND_PROMPT)
keybinds.Prompt:Hide()

-- [ WELCOME DIALOG ] --------------------------------------------------------------------------------
local welcome = CreateFrame("Frame", "OrbitWelcomeDialog", UIParent)
welcome:SetFrameStrata(Orbit.Constants.Strata.Topmost)
welcome:SetFrameLevel(WELCOME_LEVEL)
welcome:SetWidth(WELCOME_WIDTH)
welcome:SetPoint("CENTER")
welcome:SetClampedToScreen(true)
welcome:EnableMouse(true)
welcome:Hide()
BuildChrome(welcome, L.TOUR_WELCOME_TITLE)

keybinds:SetPoint("CENTER", welcome, "CENTER", 0, 0)

welcome.body = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
welcome.body:SetPoint("TOPLEFT", welcome, "TOPLEFT", PAD, -(BG_INSET_TOP + PAD))
welcome.body:SetWidth(WELCOME_WIDTH - PAD * 2)
welcome.body:SetJustifyH("CENTER")
welcome.body:SetSpacing(2)
welcome.body:SetText(L.TOUR_WELCOME_BODY)

welcome.CloseButton = CreateFrame("Button", nil, welcome, "UIPanelCloseButton")
welcome.CloseButton:SetFrameLevel(welcome.contentLevel)
welcome.CloseButton:SetPoint("TOPRIGHT", welcome, "TOPRIGHT", 0, -1)
welcome.CloseButton:SetScript("OnClick", function() welcome:Hide() end)

welcome.SetKeybindsButton = Layout:CreateButton(welcome, L.TOUR_WELCOME_SET_KEYBINDS, function()
    keybinds:Show()
    keybinds:Raise()
end)
welcome.SetKeybindsButton:SetHeight(BTN_HEIGHT)
welcome.SetKeybindsButton:SetFrameLevel(welcome.contentLevel)

welcome.StartTourButton = Layout:CreateButton(welcome, L.TOUR_WELCOME_START_TOUR, function()
    welcome:Hide()
    if Engine.EditModeTour then Engine.EditModeTour:OpenAndStart() end
end)
welcome.StartTourButton:SetHeight(BTN_HEIGHT)
welcome.StartTourButton:SetFrameLevel(welcome.contentLevel)
welcome.StartTourButton:Disable()
welcome.StartTourButton:SetMotionScriptsWhileDisabled(true)
welcome.StartTourButton:SetScript("OnEnter", function(self)
    if self:IsEnabled() then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.TOUR_WELCOME_TOUR_LOCKED_TIP, nil, nil, nil, nil, true)
    GameTooltip:Show()
end)
welcome.StartTourButton:SetScript("OnLeave", GameTooltip_Hide)

-- Closing the keybind box (Done or ESC) cancels any active capture and unlocks the tour.
keybinds:SetScript("OnHide", function()
    if activeBindButton then StopListening(activeBindButton) end
    welcome.StartTourButton:Enable()
end)

-- Any dismissal of the welcome dialog (Start Tour or close button) marks onboarding complete.
welcome:SetScript("OnHide", function()
    if keybinds:IsShown() then keybinds:Hide() end
    local as = Orbit.db and Orbit.db.AccountSettings
    if as then as.WelcomeComplete = true end
end)

-- ESC closes the keybind box (above the welcome dialog so it wins); a listening button eats ESC first to cancel.
keybinds:EnableKeyboard(true)
keybinds:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        self:SetPropagateKeyboardInput(false)
        self:Hide()
    else
        self:SetPropagateKeyboardInput(true)
    end
end)

-- Welcome must NOT close on ESC (only Start Tour or the X); swallow ESC so it can't reach the game menu either.
welcome:EnableKeyboard(true)
welcome:SetScript("OnKeyDown", function(self, key)
    self:SetPropagateKeyboardInput(key ~= "ESCAPE")
end)

-- [ MODULE ] ----------------------------------------------------------------------------------------
Engine.WelcomeDialog = Engine.WelcomeDialog or {}
local WelcomeDialog = Engine.WelcomeDialog

function WelcomeDialog:Show()
    keybinds:Hide()
    welcome.StartTourButton:Disable()
    local btnWidth = (WELCOME_WIDTH - PAD * 2 - BTN_GAP) / 2
    welcome.SetKeybindsButton:SetWidth(btnWidth)
    welcome.StartTourButton:SetWidth(btnWidth)
    welcome.SetKeybindsButton:ClearAllPoints()
    welcome.SetKeybindsButton:SetPoint("BOTTOMLEFT", welcome, "BOTTOM", -btnWidth - BTN_GAP / 2, PAD)
    welcome.StartTourButton:ClearAllPoints()
    welcome.StartTourButton:SetPoint("BOTTOMLEFT", welcome.SetKeybindsButton, "BOTTOMRIGHT", BTN_GAP, 0)
    welcome:SetHeight(BG_INSET_TOP + PAD + welcome.body:GetStringHeight() + PAD + BTN_HEIGHT + PAD)
    welcome:Show()
    welcome:Raise()
end

-- [ LOGIN TRIGGER ] ---------------------------------------------------------------------------------
local trigger = CreateFrame("Frame")
trigger:RegisterEvent("PLAYER_LOGIN")
trigger:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(SHOW_DELAY, function()
        local as = Orbit.db and Orbit.db.AccountSettings
        if not as or as.WelcomeComplete then return end
        WelcomeDialog:Show()
    end)
end)
