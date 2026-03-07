-- [ WHATS NEW ]--------------------------------------------------------------------
-- Shows a changelog popup once per account after each Orbit update.
-- Update WHATS_NEW_ENTRIES each release.

local _, addonTable = ...
local Orbit = addonTable
local Constants = Orbit.Constants

-- [ CONSTANTS ]--------------------------------------------------------------------

local WHATS_NEW_ENABLED = true -- set false for backend-only releases (skips auto-show)

local WHATS_NEW_ENTRIES = {
    { title = "Note",
      body = "Made some updates to the anchoring logic inside Canvas mode, you may need to update some positions for your components" 
    },
    { title = "Update",
      body = "• Canvas Mode overhaul: new layout, dock, and component settings\n"
        .. "• Added PlayerBuffs and Debuffs to Orbit\n"
        .. "• Animated Party/Raid/Boss Preview Frames\n"
        .. "• PVP Icon on Player Frame\n"
        .. "• Role Icon: Hide DPS Role option in Canvas Mode\n"
        .. "• Vehicle Exit button visible in Edit Mode with settings\n"
    },
    { title = "Bugfixes",
      body = "• Frames no longer jump when dragging chain-anchored frames\n"
        .. "• Queue Status no longer errors during combat\n"
        .. "• Pet Frame now refreshes properly on pet changes\n"
        .. "• Various other minor bugfixes\n"
    },
    { title = "Previous Updates",
      body = "• CDM Performance Parse. 50% better performance. (half the CPU+Ram)\n"
        .. "• CDM Better Left/Right anchoring against vertical stacked frames\n"
        .. "• Chaining CDM frames left and right will maintain the position of the CDM in the center now\n"
        .. "• bugfixes: Party/Raid frames names showing while mounted, combat timer bugfix, groups not updating properly if raidleader changes player position\n"
    },
}

local DISCORD_URL = "https://discord.gg/2sZj63kBqy"
local WINDOW_WIDTH = 420
local MAX_HEIGHT = 400
local CONTENT_PADDING = 10
local ENTRY_TITLE_FONT = "GameFontNormalLarge"
local ENTRY_BODY_FONT = "GameFontHighlight"
local ENTRY_SPACING = 16
local ENTRY_TITLE_BODY_GAP = 4
local CLOSE_BUTTON_OFFSET = -2
local FRAME_STRATA = "FULLSCREEN_DIALOG"
local FRAME_LEVEL = 500
local ESC_RESTORE_DELAY = 0.05
local SHOW_DELAY = 1.0
local SCROLLBAR_WIDTH = 26
local FOOTER_TOP_PADDING = 12
local FOOTER_BOTTOM_PADDING = 12
local FOOTER_BUTTON_HEIGHT = 20
local FOOTER_SIDE_PADDING = CONTENT_PADDING
local FOOTER_BUTTON_SPACING = 8
local FOOTER_DIVIDER_OFFSET = 6
local FOOTER_TEXT_HEIGHT = 16
local FOOTER_HEIGHT = FOOTER_TOP_PADDING + FOOTER_BUTTON_HEIGHT + FOOTER_BOTTOM_PADDING
local FOOTER_TOTAL = FOOTER_HEIGHT + FOOTER_TEXT_HEIGHT

-- [ FRAME ]------------------------------------------------------------------------

local Window = CreateFrame("Frame", "OrbitWhatsNewWindow", UIParent, "DefaultPanelTemplate")
Window:SetSize(WINDOW_WIDTH, MAX_HEIGHT)
Window:SetPoint("CENTER")
Window:SetFrameStrata(FRAME_STRATA)
Window:SetFrameLevel(FRAME_LEVEL)
Window:SetMovable(true)
Window:SetClampedToScreen(true)
Window:EnableMouse(true)
Window:RegisterForDrag("LeftButton")
Window:Hide()

Window:SetScript("OnDragStart", function(self) self:StartMoving() end)
Window:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local top, left = self:GetTop(), self:GetLeft()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end)

-- [ TITLE ]------------------------------------------------------------------------

Window.TitleContainer.TitleText:SetText("|cFFFFD100Orbit: What's New|r")

-- [ CLOSE BUTTON ]-----------------------------------------------------------------

Window.CloseButton = CreateFrame("Button", nil, Window.NineSlice, "UIPanelCloseButton")
Window.CloseButton:SetPoint("TOPRIGHT", Window, "TOPRIGHT", CLOSE_BUTTON_OFFSET, CLOSE_BUTTON_OFFSET)
Window.CloseButton:SetFrameLevel(520)
Window.CloseButton:SetScript("OnClick", function() Window:Hide() end)

-- [ FOOTER ]-----------------------------------------------------------------------

local Footer = CreateFrame("Frame", nil, Window)
Footer:SetHeight(FOOTER_HEIGHT)
Footer:SetPoint("BOTTOMLEFT", Window, "BOTTOMLEFT", 0, 0)
Footer:SetPoint("BOTTOMRIGHT", Window, "BOTTOMRIGHT", 0, 0)

local FooterDivider = Footer:CreateTexture(nil, "ARTWORK")
FooterDivider:SetSize(Constants.Panel.DividerWidth, Constants.Panel.DividerHeight)
FooterDivider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
FooterDivider:SetPoint("TOP", Footer, "TOP", 0, FOOTER_DIVIDER_OFFSET)

local FooterText = Footer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
FooterText:SetPoint("TOP", Footer, "TOP", 0, FOOTER_TEXT_HEIGHT)
FooterText:SetText("Thanks for your support! - MoONSHO7")

local btnTop = -FOOTER_TOP_PADDING

local DiscordButton = CreateFrame("Button", nil, Footer, "UIPanelButtonTemplate")
DiscordButton:SetText("Discord")
DiscordButton:SetHeight(FOOTER_BUTTON_HEIGHT)
DiscordButton:SetPoint("TOPLEFT", Footer, "TOPLEFT", FOOTER_SIDE_PADDING, btnTop)
DiscordButton:SetPoint("RIGHT", Footer, "CENTER", -FOOTER_BUTTON_SPACING / 2, 0)
-- [ DISCORD DIALOG ]---------------------------------------------------------------

local DISCORD_DIALOG_WIDTH = 380
local DISCORD_DIALOG_HEIGHT = 155
local DISCORD_EDITBOX_HEIGHT = 24

local DiscordDialog = CreateFrame("Frame", "OrbitDiscordDialog", UIParent, "DefaultPanelTemplate")
DiscordDialog:SetSize(DISCORD_DIALOG_WIDTH, DISCORD_DIALOG_HEIGHT)
DiscordDialog:SetPoint("CENTER", Window, "CENTER", 0, 0)
DiscordDialog:SetFrameStrata("TOOLTIP")
DiscordDialog:SetFrameLevel(FRAME_LEVEL + 200)
DiscordDialog:SetMovable(true)
DiscordDialog:SetClampedToScreen(true)
DiscordDialog:EnableMouse(true)
DiscordDialog:RegisterForDrag("LeftButton")
DiscordDialog:Hide()

DiscordDialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
DiscordDialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

table.insert(UISpecialFrames, "OrbitDiscordDialog")

DiscordDialog.TitleContainer.TitleText:SetText("|cFFFFD100Discord|r")

local ddDesc = DiscordDialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
ddDesc:SetPoint("TOP", DiscordDialog, "TOP", 0, -38)
ddDesc:SetWidth(DISCORD_DIALOG_WIDTH - 40)
ddDesc:SetJustifyH("CENTER")
ddDesc:SetText("Join the discord to request features, report bugs\nor ask for help from the community.")

local ddEditBox = CreateFrame("EditBox", nil, DiscordDialog, "InputBoxTemplate")
ddEditBox:SetHeight(DISCORD_EDITBOX_HEIGHT)
ddEditBox:SetPoint("LEFT", DiscordDialog, "LEFT", 20, 0)
ddEditBox:SetPoint("RIGHT", DiscordDialog, "RIGHT", -20, 0)
ddEditBox:SetPoint("TOP", ddDesc, "BOTTOM", 0, -10)
ddEditBox:SetAutoFocus(false)
ddEditBox:SetScript("OnChar", function(self) self:SetText(DISCORD_URL); self:HighlightText() end)
ddEditBox:SetScript("OnEscapePressed", function(self) DiscordDialog:Hide() end)
ddEditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

local ddFooter = CreateFrame("Frame", nil, DiscordDialog)
ddFooter:SetHeight(FOOTER_HEIGHT)
ddFooter:SetPoint("BOTTOMLEFT", DiscordDialog, "BOTTOMLEFT", 0, 0)
ddFooter:SetPoint("BOTTOMRIGHT", DiscordDialog, "BOTTOMRIGHT", 0, 0)

local ddDivider = ddFooter:CreateTexture(nil, "ARTWORK")
ddDivider:SetSize(Constants.Panel.DividerWidth, Constants.Panel.DividerHeight)
ddDivider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
ddDivider:SetPoint("TOP", ddFooter, "TOP", 0, FOOTER_DIVIDER_OFFSET)

local ddCloseBtn = CreateFrame("Button", nil, ddFooter, "UIPanelButtonTemplate")
ddCloseBtn:SetText("Close")
ddCloseBtn:SetHeight(FOOTER_BUTTON_HEIGHT)
ddCloseBtn:SetPoint("TOPLEFT", ddFooter, "TOPLEFT", FOOTER_SIDE_PADDING, -FOOTER_TOP_PADDING)
ddCloseBtn:SetPoint("TOPRIGHT", ddFooter, "TOPRIGHT", -FOOTER_SIDE_PADDING, -FOOTER_TOP_PADDING)
ddCloseBtn:SetScript("OnClick", function() DiscordDialog:Hide() end)

DiscordDialog:SetScript("OnShow", function()
    ddEditBox:SetText(DISCORD_URL)
    ddEditBox:HighlightText()
    ddEditBox:SetFocus()
end)

DiscordButton:SetScript("OnClick", function() DiscordDialog:Show() end)

local CloseButton = CreateFrame("Button", nil, Footer, "UIPanelButtonTemplate")
CloseButton:SetText("Close")
CloseButton:SetHeight(FOOTER_BUTTON_HEIGHT)
CloseButton:SetPoint("LEFT", Footer, "CENTER", FOOTER_BUTTON_SPACING / 2, 0)
CloseButton:SetPoint("TOPRIGHT", Footer, "TOPRIGHT", -FOOTER_SIDE_PADDING, btnTop)
CloseButton:SetScript("OnClick", function() Window:Hide() end)

-- [ SCROLL FRAME ]-----------------------------------------------------------------
-- DefaultPanelTemplate Bg insets: left=6 right=2 top=21 | border | 10px | content | 10px | slider | 2px | border |

local BG_LEFT = 6
local BG_RIGHT = 2
local BG_TOP = 21

local ScrollFrame = CreateFrame("ScrollFrame", nil, Window, "ScrollFrameTemplate")
ScrollFrame:SetPoint("TOPLEFT", Window, "TOPLEFT", BG_LEFT + CONTENT_PADDING, -(BG_TOP + CONTENT_PADDING))
ScrollFrame:SetPoint("BOTTOMRIGHT", Window, "BOTTOMRIGHT", -(BG_RIGHT + SCROLLBAR_WIDTH), FOOTER_TOTAL + CONTENT_PADDING)

if ScrollFrame.ScrollBar then ScrollFrame.ScrollBar:SetAlpha(0) end

local Content = CreateFrame("Frame", nil, ScrollFrame)
ScrollFrame:SetScrollChild(Content)

-- [ RENDER ENTRIES ]----------------------------------------------------------------

local renderedFontStrings = {}

local function RenderEntries()
    for _, fs in ipairs(renderedFontStrings) do fs:Hide(); fs:SetText("") end
    wipe(renderedFontStrings)

    local contentWidth = ScrollFrame:GetWidth()
    Content:SetWidth(contentWidth)

    local yOffset = 0
    for _, entry in ipairs(WHATS_NEW_ENTRIES) do
        local titleText = Content:CreateFontString(nil, "ARTWORK", ENTRY_TITLE_FONT)
        titleText:SetPoint("TOPLEFT", Content, "TOPLEFT", 0, -yOffset)
        titleText:SetWidth(contentWidth)
        titleText:SetJustifyH("LEFT")
        titleText:SetText("|cFFFFD100" .. entry.title .. "|r")
        tinsert(renderedFontStrings, titleText)
        yOffset = yOffset + titleText:GetStringHeight() + ENTRY_TITLE_BODY_GAP

        local bodyText = Content:CreateFontString(nil, "ARTWORK", ENTRY_BODY_FONT)
        bodyText:SetPoint("TOPLEFT", Content, "TOPLEFT", 0, -yOffset)
        bodyText:SetWidth(contentWidth)
        bodyText:SetJustifyH("LEFT")
        bodyText:SetText(entry.body)
        tinsert(renderedFontStrings, bodyText)
        yOffset = yOffset + bodyText:GetStringHeight() + ENTRY_SPACING
    end
    Content:SetHeight(yOffset)

    local desiredHeight = BG_TOP + CONTENT_PADDING + yOffset + CONTENT_PADDING + FOOTER_TOTAL
    Window:SetHeight(math.min(desiredHeight, MAX_HEIGHT))
    if ScrollFrame.ScrollBar then
        ScrollFrame.ScrollBar:SetAlpha(desiredHeight > MAX_HEIGHT and 1 or 0)
    end
end

Window:SetScript("OnShow", function(self)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    RunNextFrame(function() RenderEntries() end)
end)

-- [ ESC KEY ]----------------------------------------------------------------------

table.insert(UISpecialFrames, "OrbitWhatsNewWindow")

Window:SetPropagateKeyboardInput(true)
Window:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        if InCombatLockdown() then return end
        self:SetPropagateKeyboardInput(false)
        self:Hide()
        C_Timer.After(ESC_RESTORE_DELAY, function()
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
    end
end)

-- [ COMBAT HIDE ]------------------------------------------------------------------

Window:RegisterEvent("PLAYER_REGEN_DISABLED")
Window:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then self:Hide() end
end)

-- [ HIDE HANDLER ]-----------------------------------------------------------------

Window:SetScript("OnHide", function()
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    if Orbit.db then Orbit.db.WhatsNewRead = Orbit.version end
end)

-- [ PUBLIC API ]-------------------------------------------------------------------

function Orbit:ShowWhatsNew()
    if InCombatLockdown() then return end
    Window:Show()
end

-- [ AUTO-SHOW ON LOGIN ]-----------------------------------------------------------

local trigger = CreateFrame("Frame")
trigger:RegisterEvent("PLAYER_LOGIN")
trigger:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(SHOW_DELAY, function()
        if not WHATS_NEW_ENABLED then return end
        if InCombatLockdown() then return end
        if not Orbit.db then return end
        if Orbit.db.WhatsNewRead == Orbit.version then return end
        Orbit:ShowWhatsNew()
    end)
end)
