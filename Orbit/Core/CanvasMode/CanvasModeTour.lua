-- [ CANVAS MODE - TOUR ] ----------------------------------------------------------------------------
-- Sequential tour that cycles through help points with Next/Done.
-- Strings live in Orbit/Localization/Domains/Tours.lua under the TOUR_CM_* prefix.
-- When adding or renaming tour stops here, update the matching keys there.
local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local BUTTON_SIZE = 36
local PULSE_LEVEL = 512
local TOOLTIP_PAD = 8
local TOOLTIP_MAX_WIDTH = 220
local TOOLTIP_BORDER = 1
local NEXT_BTN_HEIGHT = 18
local NEXT_BTN_WIDTH = 60
local NEXT_BTN_GAP = 6
local ACCENT = { r = 0.3, g = 0.8, b = 0.3 }
local BG = { r = 0.08, g = 0.08, b = 0.08, a = 0.95 }
local BORDER_CLR = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 }
local TEXT_CLR = { r = 0.85, g = 0.85, b = 0.85 }
local TITLE_CLR = { r = ACCENT.r, g = ACCENT.g, b = ACCENT.b }
local FONT = "GameFontNormalSmall"

-- [ LOCALIZATION ] ----------------------------------------------------------------------------------
-- Strings live in Localization/Domains/Tours.lua (TOUR_CM_* keys) and Common.lua
-- (CMN_NEXT / CMN_DONE).
local L = Orbit.L

-- CJK needs wider tooltips for multi-byte glyphs
local isCJK = ({ koKR = true, zhCN = true, zhTW = true })[GetLocale()]
if isCJK then TOOLTIP_MAX_WIDTH = 240 end

-- [ TOUR STOPS ] ------------------------------------------------------------------------------------
local TOUR_STOPS = {
    { anchor = function() return Dialog.DisabledDock end,
      tooltipPoint = "BOTTOM", tooltipRel = "TOP", tpX = 0, tpY = 8,
      title = L.TOUR_CM_DOCK_TITLE, text = L.TOUR_CM_DOCK_TEXT },
    { anchor = function() return Dialog.FilterTabBar end,
      tooltipPoint = "TOP", tooltipRel = "BOTTOM", tpX = 0, tpY = -8,
      title = L.TOUR_CM_FILTER_TITLE, text = L.TOUR_CM_FILTER_TEXT },
    { anchor = function()
          if not Dialog.previewComponents then return nil end
          for _, comp in pairs(Dialog.previewComponents) do
              if comp:IsShown() then return comp end
          end
          return nil
      end,
      tooltipPoint = "TOPLEFT", tooltipRel = "TOPRIGHT", tpX = 8, tpY = 4,
      title = L.TOUR_CM_COMP_TITLE, text = L.TOUR_CM_COMP_TEXT,
      allAnchors = function()
          local list = {}
          if Dialog.previewComponents then
              for _, comp in pairs(Dialog.previewComponents) do
                  if comp:IsShown() then list[#list + 1] = comp end
              end
          end
          return list
      end },
    { anchor = function() return Dialog.Viewport end,
      tooltipPoint = "CENTER", tooltipRel = "CENTER", tpX = 0, tpY = 0,
      title = L.TOUR_CM_VIEW_TITLE, text = L.TOUR_CM_VIEW_TEXT },
    { anchor = function() return Dialog.OverrideContainer end,
      tooltipPoint = "BOTTOM", tooltipRel = "TOP", tpX = 0, tpY = 8,
      title = L.TOUR_CM_OVER_TITLE, text = L.TOUR_CM_OVER_TEXT,
      onEnter = function()
          Dialog._tourOpenedComp = nil
          if not Dialog.previewComponents then return end
          for key, comp in pairs(Dialog.previewComponents) do
              if comp:IsShown() and comp.key then
                  Dialog._tourOpenedComp = comp
                  OrbitEngine.CanvasComponentSettings:Open(comp.key, comp, Dialog.targetPlugin, Dialog.targetSystemIndex)
                  return
              end
          end
      end,
      onLeave = function()
          Dialog._tourOpenedComp = nil
          if OrbitEngine.CanvasComponentSettings and OrbitEngine.CanvasComponentSettings.componentKey then
              OrbitEngine.CanvasComponentSettings:Close()
          end
      end,
      allAnchors = function()
          local list = {}
          if Dialog.OverrideContainer and Dialog.OverrideContainer:IsShown() then
              list[#list + 1] = Dialog.OverrideContainer
          end
          if Dialog._tourOpenedComp and Dialog._tourOpenedComp:IsShown() then
              list[#list + 1] = Dialog._tourOpenedComp
          end
          return list
      end },
    { anchor = function() return Dialog.ResizeHandle end,
      tooltipPoint = "RIGHT", tooltipRel = "LEFT", tpX = -8, tpY = 0,
      title = L.TOUR_CM_RESIZE_TITLE, text = L.TOUR_CM_RESIZE_TEXT },
}

-- [ STATE ] -----------------------------------------------------------------------------------------
Dialog.tourActive = false
Dialog.tourIndex = 0

-- [ CUSTOM TOOLTIP ] --------------------------------------------------------------------------------
local function MakeBorderEdge(parent, horiz, p1, r1, p2, r2)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(BORDER_CLR.r, BORDER_CLR.g, BORDER_CLR.b, BORDER_CLR.a)
    t:SetPoint(p1, parent, r1)
    t:SetPoint(p2, parent, r2)
    if horiz then t:SetHeight(TOOLTIP_BORDER) else t:SetWidth(TOOLTIP_BORDER) end
    return t
end

local tip = CreateFrame("Frame", nil, UIParent)
tip:SetFrameStrata(Orbit.Constants.Strata.Topmost)
tip:SetFrameLevel(999)
tip:Hide()

tip.bg = tip:CreateTexture(nil, "BACKGROUND")
tip.bg:SetAllPoints()
tip.bg:SetColorTexture(BG.r, BG.g, BG.b, BG.a)
MakeBorderEdge(tip, true, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT")
MakeBorderEdge(tip, true, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
MakeBorderEdge(tip, false, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT")
MakeBorderEdge(tip, false, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT")

-- Directional accent bars (point toward the pulse highlight)
local ACCENT_WIDTH = 2
local B = TOOLTIP_BORDER
tip.accentBars = {}
tip.accentBars.top = tip:CreateTexture(nil, "ARTWORK")
tip.accentBars.top:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
tip.accentBars.top:SetHeight(ACCENT_WIDTH)
tip.accentBars.top:SetPoint("TOPLEFT", B, -B)
tip.accentBars.top:SetPoint("TOPRIGHT", -B, -B)
tip.accentBars.bottom = tip:CreateTexture(nil, "ARTWORK")
tip.accentBars.bottom:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
tip.accentBars.bottom:SetHeight(ACCENT_WIDTH)
tip.accentBars.bottom:SetPoint("BOTTOMLEFT", B, B)
tip.accentBars.bottom:SetPoint("BOTTOMRIGHT", -B, B)
tip.accentBars.left = tip:CreateTexture(nil, "ARTWORK")
tip.accentBars.left:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
tip.accentBars.left:SetWidth(ACCENT_WIDTH)
tip.accentBars.left:SetPoint("TOPLEFT", B, -B)
tip.accentBars.left:SetPoint("BOTTOMLEFT", B, B)
tip.accentBars.right = tip:CreateTexture(nil, "ARTWORK")
tip.accentBars.right:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
tip.accentBars.right:SetWidth(ACCENT_WIDTH)
tip.accentBars.right:SetPoint("TOPRIGHT", -B, -B)
tip.accentBars.right:SetPoint("BOTTOMRIGHT", -B, B)

-- Show accent bars pointing toward the highlight based on tooltipPoint
local function ApplyAccentDirection(tooltipPoint)
    for _, bar in pairs(tip.accentBars) do bar:Hide() end
    local pt = tooltipPoint:upper()
    -- CENTER = all sides
    if pt == "CENTER" then
        for _, bar in pairs(tip.accentBars) do bar:Show() end
        return
    end
    -- The tooltip's anchor point tells us which edge faces the highlight
    if pt:find("TOP") then tip.accentBars.top:Show() end
    if pt:find("BOTTOM") then tip.accentBars.bottom:Show() end
    if pt:find("LEFT") then tip.accentBars.left:Show() end
    if pt:find("RIGHT") then tip.accentBars.right:Show() end
end

-- Step counter (e.g. "1 / 3")
tip.counter = tip:CreateFontString(nil, "OVERLAY", FONT)
tip.counter:SetPoint("TOPLEFT", TOOLTIP_PAD + 4, -TOOLTIP_PAD)
tip.counter:SetTextColor(0.5, 0.5, 0.5)
tip.counter:SetJustifyH("LEFT")

tip.title = tip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tip.title:SetPoint("TOPLEFT", tip.counter, "BOTTOMLEFT", 0, -2)
tip.title:SetTextColor(TITLE_CLR.r, TITLE_CLR.g, TITLE_CLR.b)
tip.title:SetJustifyH("LEFT")
tip.title:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)

tip.text = tip:CreateFontString(nil, "OVERLAY", FONT)
tip.text:SetPoint("TOPLEFT", tip.title, "BOTTOMLEFT", 0, -3)
tip.text:SetTextColor(TEXT_CLR.r, TEXT_CLR.g, TEXT_CLR.b)
tip.text:SetJustifyH("LEFT")
tip.text:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)
tip.text:SetSpacing(2)

-- Next / Done button
tip.nextBtn = CreateFrame("Button", nil, tip, "UIPanelButtonTemplate")
tip.nextBtn:SetSize(NEXT_BTN_WIDTH, NEXT_BTN_HEIGHT)
tip.nextBtn:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -TOOLTIP_PAD, TOOLTIP_PAD)
tip.nextBtn:SetScript("OnClick", function()
    if Dialog.tourIndex < #TOUR_STOPS then
        Dialog:ShowTourStop(Dialog.tourIndex + 1)
    else
        Dialog:EndTour()
    end
end)

-- Pulse overlay pool (green glow covering anchors)
local pulsePool = {}
local activePulses = {}

local function CreatePulse()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata(Orbit.Constants.Strata.Topmost)
    f:SetFrameLevel(PULSE_LEVEL)
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.3)
    f.ag = f:CreateAnimationGroup()
    f.ag:SetLooping("BOUNCE")
    local a = f.ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.2)
    a:SetDuration(0.6)
    a:SetSmoothing("IN_OUT")
    f:Hide()
    return f
end

local function AcquirePulse()
    local p = table.remove(pulsePool) or CreatePulse()
    activePulses[#activePulses + 1] = p
    return p
end

local function ReleaseAllPulses()
    for i = #activePulses, 1, -1 do
        local p = activePulses[i]
        p.ag:Stop()
        p:Hide()
        pulsePool[#pulsePool + 1] = p
        activePulses[i] = nil
    end
end

local function ShowPulseOn(anchor)
    local p = AcquirePulse()
    p:ClearAllPoints()
    p:SetAllPoints(anchor)
    p:SetParent(anchor:GetParent() or UIParent)
    p:SetFrameLevel(anchor:GetFrameLevel() + 5)
    p:Show()
    p.ag:Play()
end

local function LayoutTooltip(anchor, stop, idx, total)
    tip.counter:SetText(idx .. " / " .. total)
    tip.title:SetText(stop.title)
    tip.text:SetText(stop.text)
    local isLast = idx == total
    tip.nextBtn:SetText(isLast and L.CMN_DONE or L.CMN_NEXT)
    -- Size to fit
    local textH = tip.counter:GetStringHeight() + 2 + tip.title:GetStringHeight() + 3 + tip.text:GetStringHeight()
    local h = textH + TOOLTIP_PAD * 2 + NEXT_BTN_GAP + NEXT_BTN_HEIGHT + TOOLTIP_PAD
    tip:SetSize(TOOLTIP_MAX_WIDTH, h)
    tip:ClearAllPoints()
    tip:SetPoint(stop.tooltipPoint, anchor, stop.tooltipRel, stop.tpX, stop.tpY)
    ApplyAccentDirection(stop.tooltipPoint)
    tip:Show()
    -- Pulse all anchors
    ReleaseAllPulses()
    if stop.allAnchors then
        for _, a in ipairs(stop.allAnchors()) do ShowPulseOn(a) end
    else
        ShowPulseOn(anchor)
    end
end

-- [ TOUR CONTROL ] ----------------------------------------------------------------------------------
function Dialog:ShowTourStop(idx)
    -- Clean up previous stop
    if self.tourIndex > 0 then
        local prevStop = TOUR_STOPS[self.tourIndex]
        if prevStop and prevStop.onLeave then prevStop.onLeave() end
    end
    local stop = TOUR_STOPS[idx]
    if not stop then self:EndTour(); return end
    -- Run onEnter before anchoring (may create/show the anchor)
    if stop.onEnter then stop.onEnter() end
    local anchor = stop.anchor()
    if not anchor or not anchor:IsShown() then
        -- Skip stops with missing anchors
        if idx < #TOUR_STOPS then self:ShowTourStop(idx + 1) else self:EndTour() end
        return
    end
    self.tourIndex = idx
    LayoutTooltip(anchor, stop, idx, #TOUR_STOPS)
end

function Dialog:StartTour()
    self.tourActive = true
    self.tourIndex = 0
    self:ShowTourStop(1)
end

function Dialog:EndTour()
    if self.tourIndex > 0 then
        local prevStop = TOUR_STOPS[self.tourIndex]
        if prevStop and prevStop.onLeave then prevStop.onLeave() end
    end
    self.tourActive = false
    self.tourIndex = 0
    tip:Hide()
    ReleaseAllPulses()
end

function Dialog:EndTourCleanup()
    self:EndTour()
end

function Dialog:ToggleTour()
    if not self.tourActive then
        self:StartTour()
    elseif self.tourIndex < #TOUR_STOPS then
        self:ShowTourStop(self.tourIndex + 1)
    else
        self:EndTour()
    end
end

-- [ TOUR BUTTON (in dialog header, hard left) ] -----------------------------------------------------
local btn = CreateFrame("Button", nil, Dialog.TitleContainer)
btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
btn:SetPoint("TOPLEFT", Dialog, "TOPLEFT", 0, 5)
btn:SetFrameLevel(Dialog.TitleContainer:GetFrameLevel() + 1)
btn.Icon = btn:CreateTexture(nil, "ARTWORK")
btn.Icon:SetTexture("Interface\\common\\help-i")
btn.Icon:SetSize(BUTTON_SIZE, BUTTON_SIZE)
btn.Icon:SetPoint("CENTER")
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.TOUR_CM_TOOLTIP, 1, 1, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
btn:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    Dialog:ToggleTour()
end)
Dialog.TourButton = btn
