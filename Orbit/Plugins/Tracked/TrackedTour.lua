-- [ TRACKED - COOLDOWN SETTINGS HINT ] --------------------------------------------------------------
-- Single-shot tooltip pinned alongside the Tracked Icons / Tracked Bars side
-- tabs the first time the user opens Blizzard's CooldownViewerSettings frame.
local _, Orbit = ...

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local TOOLTIP_PAD = 10
local TOOLTIP_MAX_WIDTH = 260
local TOOLTIP_BORDER = 1
local TOOLTIP_LEVEL = 9500
local OFFSET_X = 8
local OFFSET_Y = 0
local ACCENT_WIDTH = 2
local ACCENT = { r = 0.3, g = 0.8, b = 0.3 }
local BG = { r = 0.08, g = 0.08, b = 0.08, a = 0.95 }
local BORDER_CLR = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 }
local TEXT_CLR = { r = 0.85, g = 0.85, b = 0.85 }
local FONT = "GameFontNormalSmall"
local TAB_ID_ICONS = "Orbit_Tracked.Icons"

-- [ LOCALIZATION ] ----------------------------------------------------------------------------------
local L = Orbit.L

-- [ MODULE ] ----------------------------------------------------------------------------------------
local Tour = {}
Orbit.TrackedTour = Tour

-- [ TOOLTIP CONSTRUCTION ] --------------------------------------------------------------------------
local function MakeBorderEdge(parent, horiz, p1, r1, p2, r2)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(BORDER_CLR.r, BORDER_CLR.g, BORDER_CLR.b, BORDER_CLR.a)
    t:SetPoint(p1, parent, r1)
    t:SetPoint(p2, parent, r2)
    if horiz then t:SetHeight(TOOLTIP_BORDER) else t:SetWidth(TOOLTIP_BORDER) end
end

local tip = CreateFrame("Frame", nil, UIParent)
tip:SetFrameStrata(Orbit.Constants.Strata.Topmost)
tip:SetFrameLevel(TOOLTIP_LEVEL)
tip:Hide()
tip.bg = tip:CreateTexture(nil, "BACKGROUND")
tip.bg:SetAllPoints()
tip.bg:SetColorTexture(BG.r, BG.g, BG.b, BG.a)
MakeBorderEdge(tip, true,  "TOPLEFT",    "TOPLEFT",    "TOPRIGHT",    "TOPRIGHT")
MakeBorderEdge(tip, true,  "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
MakeBorderEdge(tip, false, "TOPLEFT",    "TOPLEFT",    "BOTTOMLEFT",  "BOTTOMLEFT")
MakeBorderEdge(tip, false, "TOPRIGHT",   "TOPRIGHT",   "BOTTOMRIGHT", "BOTTOMRIGHT")

-- Left accent bar points back toward the side tabs (which sit to our left).
local leftAccent = tip:CreateTexture(nil, "ARTWORK")
leftAccent:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
leftAccent:SetWidth(ACCENT_WIDTH)
leftAccent:SetPoint("TOPLEFT", TOOLTIP_BORDER, -TOOLTIP_BORDER)
leftAccent:SetPoint("BOTTOMLEFT", TOOLTIP_BORDER, TOOLTIP_BORDER)

tip.title = tip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tip.title:SetPoint("TOPLEFT", TOOLTIP_PAD + 4, -TOOLTIP_PAD)
tip.title:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
tip.title:SetJustifyH("LEFT")
tip.title:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)

tip.text = tip:CreateFontString(nil, "OVERLAY", FONT)
tip.text:SetPoint("TOPLEFT", tip.title, "BOTTOMLEFT", 0, -3)
tip.text:SetTextColor(TEXT_CLR.r, TEXT_CLR.g, TEXT_CLR.b)
tip.text:SetJustifyH("LEFT")
tip.text:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)
tip.text:SetSpacing(2)

-- [ TOUR LIFECYCLE ] --------------------------------------------------------------------------------
local function GetIconsTab()
    local CVE = Orbit:GetPlugin("Orbit_CooldownViewerExtensions")
    return CVE and CVE:GetTab(TAB_ID_ICONS)
end

function Tour:Show()
    local as = Orbit.db and Orbit.db.AccountSettings
    if not as or as.TrackedTabsHintComplete then return end
    if as.TrackedTabsHintComplete == nil then as.TrackedTabsHintComplete = false end
    local tab = GetIconsTab()
    if not tab then return end
    tip.title:SetText(L.TOUR_CDM_TRACKED_TABS_TITLE)
    tip.text:SetText(L.TOUR_CDM_TRACKED_TABS_TEXT)
    local textH = tip.title:GetStringHeight() + 3 + tip.text:GetStringHeight()
    tip:SetSize(TOOLTIP_MAX_WIDTH, textH + TOOLTIP_PAD * 2)
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", tab, "TOPRIGHT", OFFSET_X, OFFSET_Y)
    tip:Show()
    self.active = true
end

function Tour:Hide(markComplete)
    tip:Hide()
    self.active = false
    if markComplete and Orbit.db and Orbit.db.AccountSettings then
        Orbit.db.AccountSettings.TrackedTabsHintComplete = true
    end
end

-- [ EVENT WIRING ] ----------------------------------------------------------------------------------
EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function() Tour:Show() end, Tour)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", function()
    if Tour.active then Tour:Hide(true) end
end, Tour)
