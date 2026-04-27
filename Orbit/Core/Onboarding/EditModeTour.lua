-- [ EDIT MODE - GUIDED TOUR (PLAYGROUND) ] ----------------------------------------------------------
-- Strings live in Orbit/Localization/Domains/Tours.lua under the TOUR_EM_* prefix.
-- When adding or renaming tour steps here, update the matching keys there.
---@type Orbit
local Orbit = Orbit
local Engine = Orbit.Engine

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local OVERLAY_ALPHA = 0.90
local OVERLAY_STRATA = "TOOLTIP"
local OVERLAY_LEVEL = 100
local FRAME_STRATA = "TOOLTIP"
local FRAME_LEVEL = 300
local FRAME_W = 150
local FRAME_H = 50
local FRAME_OFFSET_X = 150
local TOOLTIP_PAD = 10
local TOOLTIP_MAX_WIDTH = 260
local TOOLTIP_BORDER = 1
local NEXT_BTN_HEIGHT = 20
local NEXT_BTN_WIDTH = 70
local NEXT_BTN_GAP = 6
local FADE_DURATION = 0.3
local NEXT_ENABLE_TIMER = 10
local STAR_COUNT = 150
local STAR_SIZE = 2
local STAR_SPEED_MIN = 0.10
local STAR_SPEED_MAX = 0.40
local STAR_HOLD_MIN = 2.0
local STAR_HOLD_MAX = 7.0
local STAR_ALPHA_MIN = 0.08
local STAR_ALPHA_MAX = 0.60
local DIALOG_STRATA = "TOOLTIP"
local DIALOG_LEVEL = 500
local BLOCKER_FRAME_LEVEL = 700
local ACCENT = { r = 0.3, g = 0.8, b = 0.3 }
local BG = { r = 0.08, g = 0.08, b = 0.08, a = 0.95 }
local BORDER_CLR = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 }
local TEXT_CLR = { r = 0.85, g = 0.85, b = 0.85 }
local TITLE_CLR = ACCENT
local ACCENT_WIDTH = 2
local TOOLTIP_LEVEL = 9500
local FONT = "GameFontNormalSmall"

-- [ LOCALIZATION ] ----------------------------------------------------------------------------------
-- Strings live in Localization/Domains/Tours.lua (TOUR_EM_* keys) and Common.lua
-- (CMN_NEXT / CMN_DONE). Everything below this block up to `local isCJK = ...` was
-- removed in the central localization migration.
local L = Orbit.L
local isCJK = ({ koKR = true, zhCN = true, zhTW = true })[GetLocale()]
if isCJK then TOOLTIP_MAX_WIDTH = 280 end

-- [ MODULE ] ----------------------------------------------------------------------------------------
Engine.EditModeTour = Engine.EditModeTour or {}
local Tour = Engine.EditModeTour
Tour.active = false
Tour.index = 0

-- [ PLUGIN REFERENCE ] ------------------------------------------------------------------------------
local function GetPlugin() return Orbit:GetPlugin("Orbit_Tour") end
local function GetFrameA() local p = GetPlugin(); return p and p.frameA end
local function GetFrameB() local p = GetPlugin(); return p and p.frameB end

-- [ DARK OVERLAY ] ----------------------------------------------------------------------------------
local overlay = CreateFrame("Frame", "OrbitEditModeTourOverlay", UIParent)
overlay:SetFrameStrata(OVERLAY_STRATA)
overlay:SetFrameLevel(OVERLAY_LEVEL)
overlay:SetAllPoints(UIParent)
overlay:EnableMouse(true)
overlay:Hide()

overlay.bg = overlay:CreateTexture(nil, "BACKGROUND")
overlay.bg:SetAllPoints()
overlay.bg:SetColorTexture(0, 0, 0, OVERLAY_ALPHA)

-- [ STAR FIELD ] ------------------------------------------------------------------------------------
local stars = {}
local function BuildStars()
    if #stars > 0 then return end
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    for i = 1, STAR_COUNT do
        local tex = overlay:CreateTexture(nil, "ARTWORK")
        tex:SetSize(STAR_SIZE, STAR_SIZE)
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetPoint("TOPLEFT", overlay, "TOPLEFT", math.random(0, math.floor(sw)), -math.random(0, math.floor(sh)))
        tex:SetAlpha(0)
        tex:Hide()
        stars[i] = {
            tex = tex,
            alpha = 0,
            maxAlpha = STAR_ALPHA_MIN + math.random() * (STAR_ALPHA_MAX - STAR_ALPHA_MIN),
            dir = 1,
            speed = STAR_SPEED_MIN + math.random() * (STAR_SPEED_MAX - STAR_SPEED_MIN),
            hold = math.random() * STAR_HOLD_MAX, -- staggered initial delay
        }
    end
end
local function ShowStars() BuildStars(); for _, s in ipairs(stars) do s.tex:Show() end end
local function HideStars() for _, s in ipairs(stars) do s.tex:Hide() end end

-- [ OPTIONS BLOCKER ] -------------------------------------------------------------------------------
local optionsBlocker = CreateFrame("Frame", nil, UIParent)
optionsBlocker:SetFrameStrata(Orbit.Constants.Strata.Topmost)
optionsBlocker:SetFrameLevel(BLOCKER_FRAME_LEVEL)
optionsBlocker:EnableMouse(true)
optionsBlocker:Hide()

local function ShowOptionsBlocker()
    optionsBlocker:ClearAllPoints()
    optionsBlocker:SetAllPoints(Orbit.SettingsDialog)
    optionsBlocker:Show()
end
local function HideOptionsBlocker() optionsBlocker:Hide() end

overlay:SetScript("OnUpdate", function(self, elapsed)
    if not Tour.active then return end
    for _, s in ipairs(stars) do
        if s.hold and s.hold > 0 then
            s.hold = s.hold - elapsed
        else
            s.hold = nil
            s.alpha = s.alpha + s.dir * s.speed * elapsed
            if s.alpha >= s.maxAlpha then
                s.alpha = s.maxAlpha; s.dir = -1
            elseif s.alpha <= 0 then
                s.alpha = 0; s.dir = 1
                s.hold = STAR_HOLD_MIN + math.random() * (STAR_HOLD_MAX - STAR_HOLD_MIN)
            end
            s.tex:SetAlpha(s.alpha)
        end
    end
end)

-- [ WELCOME TITLE ] ---------------------------------------------------------------------------------
local BARLOW_BLACK = "Interface\\AddOns\\Orbit\\Core\\assets\\Fonts\\BarlowCondensed-Black.ttf"
overlay.welcomeTitle = overlay:CreateFontString(nil, "OVERLAY")
overlay.welcomeTitle:SetFont(BARLOW_BLACK, 42, "OUTLINE")
overlay.welcomeTitle:SetPoint("CENTER", overlay, "TOP", 0, -UIParent:GetHeight() * 0.25)
overlay.welcomeTitle:SetText(L.TOUR_EM_WELCOME)
overlay.welcomeTitle:SetAlpha(0)
local BARLOW_BOLD = "Interface\\AddOns\\Orbit\\Core\\assets\\Fonts\\BarlowCondensed-Bold.ttf"
overlay.welcomeSub = overlay:CreateFontString(nil, "OVERLAY")
overlay.welcomeSub:SetFont(BARLOW_BOLD, 16)
overlay.welcomeSub:SetPoint("TOP", overlay.welcomeTitle, "BOTTOM", 0, -6)
overlay.welcomeSub:SetTextColor(0.75, 0.75, 0.75)
overlay.welcomeSub:SetText(L.TOUR_EM_WELCOME_SUBTITLE)
overlay.welcomeSub:SetAlpha(0)

-- [ TASK COMPLETION STATE ] -------------------------------------------------------------------------
local taskState = {}
local savedDialogStrata = nil
local savedDialogLevel = nil

local function ResetTaskState()
    taskState.dragged = false
    taskState.settingsOpened = false
    taskState.settingsChanged = false
    taskState.anchored = false
    taskState.distanceChanged = false
    taskState.nudged = false
    taskState.resized = false
    taskState.parentDragged = false
    taskState.anchorBroken = false
    taskState.initialPadding = nil
end

-- [ TOUR STOPS ] ------------------------------------------------------------------------------------
local TOUR_STOPS -- forward declaration, initialized after tooltip
local UpdateHierarchyLabels, ResetHierarchyLabels
local ShowResizePulse, HideResizePulse

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
tip:SetFrameLevel(TOOLTIP_LEVEL)
tip:Hide()

tip.bg = tip:CreateTexture(nil, "BACKGROUND")
tip.bg:SetAllPoints()
tip.bg:SetColorTexture(BG.r, BG.g, BG.b, BG.a)
MakeBorderEdge(tip, true, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT")
MakeBorderEdge(tip, true, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
MakeBorderEdge(tip, false, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT")
MakeBorderEdge(tip, false, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT")

-- Directional accent bars
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

local function ApplyAccentDirection(tooltipPoint)
    for _, bar in pairs(tip.accentBars) do bar:Hide() end
    local pt = tooltipPoint:upper()
    if pt:find("TOP") then tip.accentBars.top:Show() end
    if pt:find("BOTTOM") then tip.accentBars.bottom:Show() end
    if pt:find("LEFT") then tip.accentBars.left:Show() end
    if pt:find("RIGHT") then tip.accentBars.right:Show() end
end

-- Step counter
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

-- Next / Done button (hidden until task complete)
tip.nextBtn = CreateFrame("Button", nil, tip, "UIPanelButtonTemplate")
tip.nextBtn:SetSize(NEXT_BTN_WIDTH, NEXT_BTN_HEIGHT)
tip.nextBtn:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -TOOLTIP_PAD, TOOLTIP_PAD)
tip.nextBtn:SetScript("OnClick", function()
    if Tour.index < #TOUR_STOPS then
        Tour:ShowTourStop(Tour.index + 1)
    else
        Tour:EndTour()
        Tour:ShowCanvasHint()
        Tour:ShowDrawerHint()
    end
end)

-- [ SETTINGS CHANGE TRACKING ] ----------------------------------------------------------------------
local originalSetSetting = nil

local function TrackingSetSetting(self, systemIndex, key, value)
    originalSetSetting(self, systemIndex, key, value)
    if Tour.active then
        taskState.settingsChanged = true
        if key == "Width" or key == "Height" then taskState.resized = true end
    end
end

-- [ PARENT / CHILD HELPERS ] ------------------------------------------------------------------------
local function GetParentFrame()
    local frameA, frameB = GetFrameA(), GetFrameB()
    local Anchor = Engine.FrameAnchor
    if not Anchor or not frameA or not frameB then return frameA end
    if Anchor.anchors[frameB] then return frameA end
    if Anchor.anchors[frameA] then return frameB end
    return frameA
end

local function GetChildFrame()
    local frameA, frameB = GetFrameA(), GetFrameB()
    local Anchor = Engine.FrameAnchor
    if not Anchor or not frameA or not frameB then return frameB end
    if Anchor.anchors[frameB] then return frameB end
    if Anchor.anchors[frameA] then return frameA end
    return frameB
end

-- [ TASK STATE POLLER ] -----------------------------------------------------------------------------
local CHECK_INTERVAL = 0.1
local checkElapsed = 0
local stopElapsed = 0
tip:SetScript("OnUpdate", function(self, elapsed)
    if not Tour.active then return end
    
    local frameA, frameB = GetFrameA(), GetFrameB()
    
    -- Continuously enforce strata per visual frame to prevent flickering
    if frameA and frameB then
        for _, tf in ipairs({ frameA, frameB }) do
            tf:SetFrameStrata(FRAME_STRATA)
            tf:SetFrameLevel(FRAME_LEVEL)
        end
        local Selection = Engine.FrameSelection
        if Selection then
            for _, tf in ipairs({ frameA, frameB }) do
                local s = Selection.selections[tf]
                if s then
                    s:SetFrameStrata(FRAME_STRATA)
                    s:SetFrameLevel(FRAME_LEVEL + 5)
                    if s.resizeHandle then
                        s.resizeHandle:SetFrameStrata(FRAME_STRATA)
                        s.resizeHandle:SetFrameLevel(FRAME_LEVEL + 10)
                    end
                end
            end
        end
    end
    local dialog = Orbit.SettingsDialog
    if dialog and dialog:IsShown() then
        dialog:SetFrameStrata(DIALOG_STRATA)
        dialog:SetFrameLevel(DIALOG_LEVEL)
    end
    self:SetFrameStrata("TOOLTIP")
    self:SetFrameLevel(TOOLTIP_LEVEL)

    checkElapsed = checkElapsed + elapsed
    stopElapsed = stopElapsed + elapsed
    if checkElapsed < CHECK_INTERVAL then return end
    checkElapsed = 0

    local stop = TOUR_STOPS[Tour.index]
    if not stop then return end
    if not frameA or not frameB then return end

    -- Poll anchor state
    local Anchor = Engine.FrameAnchor
    if Anchor then
        taskState.anchored = (Anchor.anchors[frameA] ~= nil) or (Anchor.anchors[frameB] ~= nil)
        if taskState.anchored and taskState.initialPadding == nil then
            local a = Anchor.anchors[frameA] or Anchor.anchors[frameB]
            taskState.initialPadding = a and a.padding or 0
        end
        if taskState.initialPadding ~= nil then
            local a = Anchor.anchors[frameA] or Anchor.anchors[frameB]
            local curPadding = a and a.padding or 0
            if curPadding ~= taskState.initialPadding then taskState.distanceChanged = true end
        end
    end
    -- Poll drag state
    local Selection = Engine.FrameSelection
    if Selection then
        local sel = Selection:GetSelectedFrame()
        if sel and (sel == frameA or sel == frameB) and sel.orbitIsDragging then
            taskState.dragged = true
            if sel == GetParentFrame() then taskState.parentDragged = true end
        end
        -- Hide non-tour selections that may reappear (e.g. shift release)
        for frame, s in pairs(Selection.selections) do
            if frame ~= frameA and frame ~= frameB then
                s:SetAlpha(0)
                s:EnableMouse(false)
            end
        end
    end
    
    -- Enable Next button when check passes or fallback timer expires
    if (stop.check and stop.check()) or stopElapsed >= NEXT_ENABLE_TIMER then tip.nextBtn:Enable() end
end)

-- [ LAYOUT TOOLTIP ] --------------------------------------------------------------------------------
local TOOLTIP_OFFSET = 50

local function ComputeFrameAnchor(anchorFrame)
    local cx = anchorFrame:GetCenter()
    local screenW = UIParent:GetWidth()
    if cx and cx > screenW / 2 then
        return "LEFT", "RIGHT", TOOLTIP_OFFSET, 0
    end
    return "RIGHT", "LEFT", -TOOLTIP_OFFSET, 0
end

local function LayoutTooltip(anchorFrame, stop, idx, total)
    tip.counter:SetText(idx .. " / " .. total)
    tip.title:SetText(stop.title)
    tip.text:SetText(stop.text)
    local isLast = idx == total
    tip.nextBtn:SetText(isLast and L.CMN_DONE or L.CMN_NEXT)
    tip.nextBtn:Show()
    if stop.check and stop.check() then tip.nextBtn:Enable() else tip.nextBtn:Disable() end
    local textH = tip.counter:GetStringHeight() + 2 + tip.title:GetStringHeight() + 3 + tip.text:GetStringHeight()
    local h = textH + TOOLTIP_PAD * 2 + NEXT_BTN_GAP + NEXT_BTN_HEIGHT + TOOLTIP_PAD
    tip:SetSize(TOOLTIP_MAX_WIDTH, h)
    tip:ClearAllPoints()
    local tpPoint, tpRel, tpX, tpY
    if stop.tooltipPoint then
        tpPoint, tpRel, tpX, tpY = stop.tooltipPoint, stop.tooltipRel, stop.tpX, stop.tpY
    else
        tpPoint, tpRel, tpX, tpY = ComputeFrameAnchor(anchorFrame)
    end
    tip:SetPoint(tpPoint, anchorFrame, tpRel, tpX, tpY)
    ApplyAccentDirection(tpPoint)
    tip:Show()
end

-- [ SNAP ISOLATION ] --------------------------------------------------------------------------------
local originalGetSnapTargets = nil

local function IsolatedGetSnapTargets(self, excludeFrame)
    local frameA, frameB = GetFrameA(), GetFrameB()
    local targets = {}
    if frameA and excludeFrame ~= frameA and frameA:IsVisible() then targets[#targets + 1] = frameA end
    if frameB and excludeFrame ~= frameB and frameB:IsVisible() then targets[#targets + 1] = frameB end
    return targets
end

-- [ NUDGE TRACKING ] --------------------------------------------------------------------------------
local originalNudgeFrame = nil

local function TrackingNudgeFrame(self, frame, direction, ...)
    local frameA, frameB = GetFrameA(), GetFrameB()
    if frame == frameA or frame == frameB then taskState.nudged = true end
    return originalNudgeFrame(self, frame, direction, ...)
end

-- [ RESIZE PULSE ] ----------------------------------------------------------------------------------
local resizePulses = {}

local function CreateResizePulse()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata(Orbit.Constants.Strata.Topmost)
    f:SetFrameLevel(TOOLTIP_LEVEL)
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

HideResizePulse = function()
    for i = #resizePulses, 1, -1 do
        resizePulses[i].ag:Stop()
        resizePulses[i]:Hide()
        resizePulses[i] = nil
    end
end

ShowResizePulse = function()
    HideResizePulse()
    local Selection = Engine.FrameSelection
    if not Selection then return end
    for _, tf in ipairs({ GetFrameA(), GetFrameB() }) do
        if tf then
            local sel = Selection.selections[tf]
            if sel and sel.resizeHandle then
                sel.resizeHandle:Show()
                local p = CreateResizePulse()
                p:SetParent(sel.resizeHandle)
                p:ClearAllPoints()
                p:SetAllPoints(sel.resizeHandle)
                p:SetFrameLevel(sel.resizeHandle:GetFrameLevel() + 5)
                p:Show()
                p.ag:Play()
                resizePulses[#resizePulses + 1] = p
            end
        end
    end
end

-- [ TOUR STOPS (deferred init — needs frame refs) ] -------------------------------------------------
TOUR_STOPS = {
    { anchorKey = "A",
      title = L.TOUR_EM_STEP1_TITLE, text = L.TOUR_EM_STEP1_TEXT,
      check = function() return taskState.dragged end,
      onLeave = function()
          -- Ensure frameA is selected so the settings dialog is open for step 2
          local frameA = GetFrameA()
          local Selection = Engine.FrameSelection
          if not frameA or not Selection then return end
          local sel = Selection.selections[frameA]
          if sel and not sel.isSelected then
              Selection:DeselectAll()
              sel.isSelected = true
              Selection:SetSelectedFrame(frameA, false)
              Selection:UpdateVisuals(nil, sel)
              if Selection.selectionCallbacks[frameA] then
                  Selection.selectionCallbacks[frameA](frameA)
              end
          end
      end },
    { anchorKey = "dialog", tooltipPoint = "LEFT", tooltipRel = "RIGHT", tpX = 8, tpY = 0,
      title = L.TOUR_EM_STEP2_TITLE, text = L.TOUR_EM_STEP2_TEXT,
      check = function() return taskState.settingsChanged end },
    { anchorKey = "B",
      title = L.TOUR_EM_STEP3_TITLE, text = L.TOUR_EM_STEP3_TEXT,
      check = function() return taskState.anchored end },
    { anchorKey = "parent",
      title = L.TOUR_EM_STEP4_TITLE, text = L.TOUR_EM_STEP4_TEXT,
      check = function() return taskState.parentDragged or taskState.anchorBroken end,
      onEnter = function()
          taskState.parentDragged = false
          taskState.anchorBroken = false
          local Anchor = Engine.FrameAnchor
          if not Anchor then return end
          local frameA, frameB = GetFrameA(), GetFrameB()
          for _, child in ipairs({ frameA, frameB }) do
              local a = child and Anchor.anchors[child]
              if a then
                  taskState.savedAnchor = { child = child, parent = a.parent, edge = a.edge, padding = a.padding, align = a.align }
                  return
              end
          end
      end,
      onLeave = function()
          local saved = taskState.savedAnchor
          if not saved then return end
          local Anchor = Engine.FrameAnchor
          if not Anchor then return end
          if not Anchor.anchors[saved.child] then
              Anchor:CreateAnchor(saved.child, saved.parent, saved.edge, saved.padding, nil, saved.align, true)
              UpdateHierarchyLabels()
          end
          taskState.savedAnchor = nil
      end },
    { anchorKey = "child",
      title = L.TOUR_EM_STEP5_TITLE, text = L.TOUR_EM_STEP5_TEXT,
      check = function() return taskState.distanceChanged end },
    { anchorKey = "parent",
      title = L.TOUR_EM_STEP6_TITLE, text = L.TOUR_EM_STEP6_TEXT,
      check = function() return taskState.nudged end },
    { anchorKey = "A",
      title = L.TOUR_EM_STEP7_TITLE, text = L.TOUR_EM_STEP7_TEXT,
      check = function() return taskState.resized end,
      onEnter = function() taskState.resized = false; ShowResizePulse() end,
      onLeave = function() HideResizePulse() end },
    { anchorKey = "options", tooltipPoint = "LEFT", tooltipRel = "RIGHT", tpX = 8, tpY = 0,
      title = L.TOUR_EM_STEP8_TITLE, text = L.TOUR_EM_STEP8_TEXT,
      check = function() return true end,
      onEnter = function()
          if Orbit.OptionsPanel then
              Orbit.OptionsPanel:Open("Global")
              C_Timer.After(0.05, ShowOptionsBlocker)
          end
      end,
      onLeave = function()
          HideOptionsBlocker()
          if Orbit.OptionsPanel then Orbit.OptionsPanel:Hide() end
      end },
    { anchorKey = "center", tooltipPoint = "CENTER", tooltipRel = "CENTER", tpX = 0, tpY = 0,
      title = L.TOUR_EM_STEP9_TITLE, text = L.TOUR_EM_STEP9_TEXT,
      check = function() return true end,
      onEnter = function()
          if Orbit.OptionsPanel then
              Orbit.OptionsPanel:Open("Global")
              C_Timer.After(0.05, ShowOptionsBlocker)
          end
      end,
      onLeave = function()
          HideOptionsBlocker()
          if Orbit.OptionsPanel then Orbit.OptionsPanel:Hide() end
      end },
}


local function ResolveAnchor(stop)
    if stop.anchorKey == "center" then return UIParent
    elseif stop.anchorKey == "A" then return GetFrameA()
    elseif stop.anchorKey == "B" then return GetFrameB()
    elseif stop.anchorKey == "parent" then return GetParentFrame()
    elseif stop.anchorKey == "child" then return GetChildFrame()
    elseif stop.anchorKey == "dialog" then return Orbit.SettingsDialog
    elseif stop.anchorKey == "options" then return Orbit.SettingsDialog end
end

-- [ HIERARCHY LABELS ] ------------------------------------------------------------------------------
UpdateHierarchyLabels = function()
    local frameA, frameB = GetFrameA(), GetFrameB()
    if not frameA or not frameB then return end
    local parent = GetParentFrame()
    if parent == frameA then
        frameA.label:SetText("A (Parent)")
        frameB.label:SetText("B (Child)")
    elseif parent == frameB then
        frameB.label:SetText("B (Parent)")
        frameA.label:SetText("A (Child)")
    end
end

ResetHierarchyLabels = function()
    local frameA, frameB = GetFrameA(), GetFrameB()
    if frameA then frameA.label:SetText("A") end
    if frameB then frameB.label:SetText("B") end
end

-- [ ANCHOR TRACKING ] -------------------------------------------------------------------------------
local originalBreakAnchor = nil

local function TrackingBreakAnchor(self, child, ...)
    local result = originalBreakAnchor(self, child, ...)
    if Tour.active then
        local frameA, frameB = GetFrameA(), GetFrameB()
        if child == frameA or child == frameB then
            taskState.anchorBroken = true
            local Anchor = Engine.FrameAnchor
            local hasAnchor = Anchor and ((Anchor.anchors[frameA] ~= nil) or (Anchor.anchors[frameB] ~= nil))
            if hasAnchor then UpdateHierarchyLabels() else ResetHierarchyLabels() end
        end
    end
    return result
end

-- [ TOOLTIP ANIMATION ] -----------------------------------------------------------------------------
local SHRINK_SCALE = 0.7
local GROW_START = 0.85
local animFrame = CreateFrame("Frame")

local function AnimateTooltip(fromScale, toScale, fromAlpha, toAlpha, duration, onComplete)
    local elapsed = 0
    animFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        local ease = 1 - (1 - t) * (1 - t)
        tip:SetScale(fromScale + (toScale - fromScale) * ease)
        tip:SetAlpha(fromAlpha + (toAlpha - fromAlpha) * ease)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            if onComplete then onComplete() end
        end
    end)
end

-- [ TOUR CONTROL ] ----------------------------------------------------------------------------------
function Tour:ShowTourStop(idx)
    -- Clean up previous stop
    if self.index > 0 then
        local prevStop = TOUR_STOPS[self.index]
        if prevStop and prevStop.onLeave then prevStop.onLeave() end
    end
    local stop = TOUR_STOPS[idx]
    if not stop then self:EndTour(); return end
    self.index = idx
    checkElapsed = 0
    stopElapsed = 0
    taskCompleteAt = nil

    local anchor = ResolveAnchor(stop)
    if not anchor then self:EndTour(); return end

    -- Update hierarchy labels based on actual anchor state
    local Anchor = Engine.FrameAnchor
    local hasAnchor = Anchor and ((Anchor.anchors[GetFrameA()] ~= nil) or (Anchor.anchors[GetFrameB()] ~= nil))
    if hasAnchor then UpdateHierarchyLabels() else ResetHierarchyLabels() end
    local isFirst = (idx == 1 and not tip:IsShown())
    if isFirst then
        if stop.onEnter then stop.onEnter() end
        LayoutTooltip(anchor, stop, idx, #TOUR_STOPS)
        tip:SetScale(GROW_START)
        tip:SetAlpha(0)
        AnimateTooltip(GROW_START, 1, 0, 1, FADE_DURATION)
    else
        AnimateTooltip(1, SHRINK_SCALE, 1, 0, FADE_DURATION, function()
            if not Tour.active then return end
            if stop.onEnter then stop.onEnter() end
            LayoutTooltip(anchor, stop, idx, #TOUR_STOPS)
            tip:SetScale(GROW_START)
            AnimateTooltip(GROW_START, 1, 0, 1, FADE_DURATION)
        end)
    end
end

function Tour:StartTour(force)
    if self.active then return end
    if not force and Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.TourComplete then return end
    local plugin = GetPlugin()
    if not plugin or not plugin.frameA or not plugin.frameB then return end
    if not force and Orbit.db and Orbit.db.AccountSettings then
        Orbit.db.AccountSettings.TourComplete = true
    end

    local ok, err = xpcall(function()
        local frameA, frameB = plugin.frameA, plugin.frameB
        self.active = true
        self.index = 0
        ResetTaskState()
        local dialog = Orbit.SettingsDialog
        if dialog then
            savedDialogStrata = dialog:GetFrameStrata()
            savedDialogLevel = dialog:GetFrameLevel()
            dialog:SetFrameStrata(DIALOG_STRATA)
            dialog:SetFrameLevel(DIALOG_LEVEL)
        end
        if not originalSetSetting then
            originalSetSetting = plugin.SetSetting
            plugin.SetSetting = TrackingSetSetting
        end
        local Selection = Engine.FrameSelection
        if Selection then
            for _, sel in pairs(Selection.selections) do
                sel:SetAlpha(0)
                sel:EnableMouse(false)
            end
        end
        if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
            for _, sysFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
                if sysFrame.Selection then
                    sysFrame.Selection:SetAlpha(0)
                    sysFrame.Selection:EnableMouse(false)
                end
            end
        end
        if Selection and not originalGetSnapTargets then
            originalGetSnapTargets = Selection.GetSnapTargets
            Selection.GetSnapTargets = IsolatedGetSnapTargets
        end
        local Nudge = Engine.SelectionNudge
        if Nudge and not originalNudgeFrame then
            originalNudgeFrame = Nudge.NudgeFrame
            Nudge.NudgeFrame = TrackingNudgeFrame
        end
        local AnchorMod = Engine.FrameAnchor
        if AnchorMod and not originalBreakAnchor then
            originalBreakAnchor = AnchorMod.BreakAnchor
            AnchorMod.BreakAnchor = TrackingBreakAnchor
        end
        if Selection then
            for _, tf in ipairs({ frameA, frameB }) do
                local origCb = Selection.dragCallbacks[tf]
                if origCb then
                    Selection.dragCallbacks[tf] = function(...)
                        origCb(...)
                        C_Timer.After(0, function()
                            if not Tour.active then return end
                            local Anc = Engine.FrameAnchor
                            local hasAnchor = Anc and ((Anc.anchors[frameA] ~= nil) or (Anc.anchors[frameB] ~= nil))
                            if hasAnchor then UpdateHierarchyLabels() else ResetHierarchyLabels() end
                        end)
                    end
                end
            end
        end
        plugin:SetSetting("A", "Width", FRAME_W); plugin:SetSetting("A", "Height", FRAME_H)
        plugin:SetSetting("B", "Width", FRAME_W); plugin:SetSetting("B", "Height", FRAME_H)
        taskState.settingsChanged = false
        overlay:Show()
        ShowStars()
        overlay.welcomeTitle:SetAlpha(1)
        overlay.welcomeSub:SetAlpha(1)
        frameA:SetSize(FRAME_W, FRAME_H)
        frameB:SetSize(FRAME_W, FRAME_H)
        frameA:ClearAllPoints()
        frameA:SetPoint("CENTER", UIParent, "CENTER", -FRAME_OFFSET_X, 0)
        frameB:ClearAllPoints()
        frameB:SetPoint("CENTER", UIParent, "CENTER", FRAME_OFFSET_X, 0)
        frameA:SetFrameStrata(FRAME_STRATA)
        frameA:SetFrameLevel(FRAME_LEVEL)
        frameB:SetFrameStrata(FRAME_STRATA)
        frameB:SetFrameLevel(FRAME_LEVEL)
        frameA:Show()
        frameB:Show()
        if Selection then
            for _, tf in ipairs({ frameA, frameB }) do
                local s = Selection.selections[tf]
                if s then
                    s:SetAlpha(1)
                    s:Show()
                    s:ShowHighlighted()
                    s:EnableMouse(true)
                    tf:SetMovable(true)
                end
            end
        end
        self._hiddenFrames = {}
        for _, sys in ipairs(Engine.systems) do
            if sys ~= plugin then
                local frames = sys.frames or (sys.Frame and { sys.Frame }) or (sys.frame and { sys.frame }) or {}
                for _, f in ipairs(frames) do
                    if f and f:IsShown() then
                        f:Hide()
                        self._hiddenFrames[#self._hiddenFrames + 1] = f
                    end
                end
                if sys.containers then
                    for _, c in pairs(sys.containers) do
                        if c and c:IsShown() then
                            c:Hide()
                            self._hiddenFrames[#self._hiddenFrames + 1] = c
                        end
                    end
                end
            end
        end
        if EditModeManagerFrame then
            self._editModeWasShown = EditModeManagerFrame:IsShown()
            EditModeManagerFrame:SetAlpha(0)
            EditModeManagerFrame:EnableMouse(false)
        end
        self:ShowTourStop(1)
    end, function(e)
        self:EndTour()
        return e
    end)
    if not ok then error(err) end
end

function Tour:EndTour()
    -- Clean up current step
    if self.index > 0 then
        local curStop = TOUR_STOPS[self.index]
        if curStop and curStop.onLeave then curStop.onLeave() end
    end
    self.active = false
    self.index = 0
    tip:Hide()
    overlay.welcomeTitle:SetAlpha(0)
    overlay.welcomeSub:SetAlpha(0)
    overlay:Hide()
    HideStars()
    HideResizePulse()
    ResetHierarchyLabels()
    -- Restore settings dialog strata
    local dialog = Orbit.SettingsDialog
    if dialog then
        if savedDialogStrata then dialog:SetFrameStrata(savedDialogStrata) end
        if savedDialogLevel then dialog:SetFrameLevel(savedDialogLevel) end
        savedDialogStrata = nil
        savedDialogLevel = nil
    end

    -- Stop any running animation
    animFrame:SetScript("OnUpdate", nil)
    local frameA, frameB = GetFrameA(), GetFrameB()
    -- Restore SetSetting
    local plugin = GetPlugin()
    if plugin and originalSetSetting then
        plugin.SetSetting = originalSetSetting
        originalSetSetting = nil
    end
    -- Restore GetSnapTargets
    local Selection = Engine.FrameSelection
    if Selection and originalGetSnapTargets then
        Selection.GetSnapTargets = originalGetSnapTargets
        originalGetSnapTargets = nil
    end
    -- Restore NudgeFrame
    local Nudge = Engine.SelectionNudge
    if Nudge and originalNudgeFrame then
        Nudge.NudgeFrame = originalNudgeFrame
        originalNudgeFrame = nil
    end
    -- Restore BreakAnchor
    local AnchorMod = Engine.FrameAnchor
    if AnchorMod and originalBreakAnchor then
        AnchorMod.BreakAnchor = originalBreakAnchor
        originalBreakAnchor = nil
    end
    -- Break any anchors on playground frames
    if frameA and frameB and Engine.FrameAnchor then
        Engine.FrameAnchor:BreakAnchor(frameA, true)
        Engine.FrameAnchor:BreakAnchor(frameB, true)
    end
    -- Hide playground frame selection overlays (don't destroy — factory owns them)
    if Selection and frameA and frameB then
        Selection:DeselectAll()
        for _, tf in ipairs({ frameA, frameB }) do
            local s = Selection.selections[tf]
            if s then s:Hide() end
        end
    end
    if frameA then frameA:Hide() end
    if frameB then frameB:Hide() end
    -- Restore all hidden frames
    if self._hiddenFrames then
        for _, f in ipairs(self._hiddenFrames) do
            f:Show()
        end
        self._hiddenFrames = nil
    end
    if EditModeManagerFrame then
        EditModeManagerFrame:SetAlpha(1)
        EditModeManagerFrame:EnableMouse(true)
    end
    -- Restore Orbit and Blizzard selection overlays
    if Selection then Selection:RefreshVisuals() end
end

-- [ CANVAS MODE HINT ] ------------------------------------------------------------------------------
local canvasTip = CreateFrame("Frame", nil, UIParent)
canvasTip:SetFrameStrata(Orbit.Constants.Strata.Topmost)
canvasTip:SetFrameLevel(TOOLTIP_LEVEL)
canvasTip:Hide()
canvasTip.bg = canvasTip:CreateTexture(nil, "BACKGROUND")
canvasTip.bg:SetAllPoints()
canvasTip.bg:SetColorTexture(BG.r, BG.g, BG.b, BG.a)
MakeBorderEdge(canvasTip, true, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT")
MakeBorderEdge(canvasTip, true, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
MakeBorderEdge(canvasTip, false, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT")
MakeBorderEdge(canvasTip, false, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT")
do
    local B = 1
    for _, side in ipairs({
        { "top", true, "TOPLEFT", "TOPRIGHT", -1 },
        { "bottom", true, "BOTTOMLEFT", "BOTTOMRIGHT", 1 },
        { "left", false, "TOPLEFT", "BOTTOMLEFT", 1 },
        { "right", false, "TOPRIGHT", "BOTTOMRIGHT", -1 },
    }) do
        local t = canvasTip:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
        if side[2] then
            t:SetHeight(2)
            t:SetPoint(side[3], B, side[5] * B)
            t:SetPoint(side[4], -B, side[5] * B)
        else
            t:SetWidth(2)
            t:SetPoint(side[3], side[5] * B, -B)
            t:SetPoint(side[4], side[5] * B, B)
        end
    end
end
canvasTip.title = canvasTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
canvasTip.title:SetPoint("TOPLEFT", TOOLTIP_PAD + 4, -TOOLTIP_PAD)
canvasTip.title:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
canvasTip.title:SetJustifyH("LEFT")
canvasTip.title:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)
canvasTip.text = canvasTip:CreateFontString(nil, "OVERLAY", FONT)
canvasTip.text:SetPoint("TOPLEFT", canvasTip.title, "BOTTOMLEFT", 0, -3)
canvasTip.text:SetTextColor(TEXT_CLR.r, TEXT_CLR.g, TEXT_CLR.b)
canvasTip.text:SetJustifyH("LEFT")
canvasTip.text:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)
canvasTip.text:SetSpacing(2)

local originalCanvasToggle = nil

local function GetPlayerFrame()
    for _, sys in ipairs(Engine.systems) do
        if sys.system == "Orbit_PlayerFrame" then
            return sys.frames and sys.frames[1] or sys.Frame or sys.frame
        end
    end
    return nil
end

function Tour:ShowCanvasHint()
    local as = Orbit.db and Orbit.db.AccountSettings
    if as and as.CanvasHintComplete then return end
    local playerFrame = GetPlayerFrame()
    if not playerFrame then return end
    if as and as.CanvasHintComplete == nil then as.CanvasHintComplete = false end
    canvasTip.title:SetText(L.TOUR_EM_CANVAS_TITLE)
    canvasTip.text:SetText(L.TOUR_EM_CANVAS_TEXT)
    local textH = canvasTip.title:GetStringHeight() + 3 + canvasTip.text:GetStringHeight()
    canvasTip:SetSize(TOOLTIP_MAX_WIDTH, textH + TOOLTIP_PAD * 2)
    canvasTip:ClearAllPoints()
    canvasTip:SetPoint("BOTTOM", playerFrame, "TOP", 0, 8)
    canvasTip:Show()
    Tour.canvasHintActive = true
    -- Pulse player frame selection color
    local Selection = Engine.FrameSelection
    local sel = Selection and Selection.selections[playerFrame]
    if sel then
        sel:Show()
        sel:ShowHighlighted()
        local defaultClr = { 0.0, 0.44, 1.0 }
        local curveData = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.EditModeColorCurve
        local custom = curveData and Engine.ColorCurve:GetFirstColorFromCurve(curveData)
        if custom then defaultClr = { custom.r, custom.g, custom.b } end
        local pulseElapsed = 0
        canvasTip:SetScript("OnUpdate", function(_, dt)
            pulseElapsed = pulseElapsed + dt
            local t = (math.sin(pulseElapsed * 3) + 1) / 2
            local r = defaultClr[1] + (ACCENT.r - defaultClr[1]) * t
            local g = defaultClr[2] + (ACCENT.g - defaultClr[2]) * t
            local b = defaultClr[3] + (ACCENT.b - defaultClr[3]) * t
            for i = 1, select("#", sel:GetRegions()) do
                local region = select(i, sel:GetRegions())
                if region:IsObjectType("Texture") and not region.isAnchorLine then
                    region:SetVertexColor(r, g, b, 1)
                end
            end
        end)
    end
    local CM = Engine.CanvasMode
    if CM and not originalCanvasToggle then
        originalCanvasToggle = CM.Toggle
        CM.Toggle = function(self, ...)
            originalCanvasToggle(self, ...)
            Tour:HideCanvasHint(true)
        end
    end
end

function Tour:HideCanvasHint(markComplete)
    canvasTip:SetScript("OnUpdate", nil)
    canvasTip:Hide()
    Tour.canvasHintActive = false
    if markComplete and Orbit.db and Orbit.db.AccountSettings then
        Orbit.db.AccountSettings.CanvasHintComplete = true
    end
    -- Restore selection color
    local Selection = Engine.FrameSelection
    if Selection then Selection:RefreshVisuals() end
    local CM = Engine.CanvasMode
    if CM and originalCanvasToggle then
        CM.Toggle = originalCanvasToggle
        originalCanvasToggle = nil
    end
end

-- [ DATATEXT DRAWER HINT ] --------------------------------------------------------------------------
local DRAWER_TIP_OFFSET_X = 12
local DRAWER_TIP_OFFSET_Y = -12
local drawerTip = CreateFrame("Frame", nil, UIParent)
drawerTip:SetFrameStrata(Orbit.Constants.Strata.Topmost)
drawerTip:SetFrameLevel(TOOLTIP_LEVEL)
drawerTip:Hide()
drawerTip.bg = drawerTip:CreateTexture(nil, "BACKGROUND")
drawerTip.bg:SetAllPoints()
drawerTip.bg:SetColorTexture(BG.r, BG.g, BG.b, BG.a)
MakeBorderEdge(drawerTip, true, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT")
MakeBorderEdge(drawerTip, true, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
MakeBorderEdge(drawerTip, false, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT")
MakeBorderEdge(drawerTip, false, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT")
do
    local B = 1
    for _, side in ipairs({
        { "top", true, "TOPLEFT", "TOPRIGHT", -1 },
        { "bottom", true, "BOTTOMLEFT", "BOTTOMRIGHT", 1 },
        { "left", false, "TOPLEFT", "BOTTOMLEFT", 1 },
        { "right", false, "TOPRIGHT", "BOTTOMRIGHT", -1 },
    }) do
        local t = drawerTip:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
        if side[2] then
            t:SetHeight(2)
            t:SetPoint(side[3], B, side[5] * B)
            t:SetPoint(side[4], -B, side[5] * B)
        else
            t:SetWidth(2)
            t:SetPoint(side[3], side[5] * B, -B)
            t:SetPoint(side[4], side[5] * B, B)
        end
    end
end
drawerTip.title = drawerTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
drawerTip.title:SetPoint("TOPLEFT", TOOLTIP_PAD + 4, -TOOLTIP_PAD)
drawerTip.title:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
drawerTip.title:SetJustifyH("LEFT")
drawerTip.title:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)
drawerTip.text = drawerTip:CreateFontString(nil, "OVERLAY", FONT)
drawerTip.text:SetPoint("TOPLEFT", drawerTip.title, "BOTTOMLEFT", 0, -3)
drawerTip.text:SetTextColor(TEXT_CLR.r, TEXT_CLR.g, TEXT_CLR.b)
drawerTip.text:SetJustifyH("LEFT")
drawerTip.text:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)
drawerTip.text:SetSpacing(2)

local originalDrawerToggle = nil

function Tour:ShowDrawerHint()
    local as = Orbit.db and Orbit.db.AccountSettings
    if as and as.DrawerHintComplete then return end
    if as and as.DrawerHintComplete == nil then as.DrawerHintComplete = false end
    drawerTip.title:SetText(L.TOUR_EM_DRAWER_TITLE)
    drawerTip.text:SetText(L.TOUR_EM_DRAWER_TEXT)
    local textH = drawerTip.title:GetStringHeight() + 3 + drawerTip.text:GetStringHeight()
    drawerTip:SetSize(TOOLTIP_MAX_WIDTH, textH + TOOLTIP_PAD * 2)
    drawerTip:ClearAllPoints()
    drawerTip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DRAWER_TIP_OFFSET_X, DRAWER_TIP_OFFSET_Y)
    drawerTip:Show()
    Tour.drawerHintActive = true
    local DrawerUI = Orbit.Datatexts and Orbit.Datatexts.DrawerUI
    if DrawerUI and not originalDrawerToggle then
        originalDrawerToggle = DrawerUI.Toggle
        DrawerUI.Toggle = function(self, ...)
            originalDrawerToggle(self, ...)
            Tour:HideDrawerHint(true)
        end
    end
end

function Tour:HideDrawerHint(markComplete)
    drawerTip:Hide()
    Tour.drawerHintActive = false
    if markComplete and Orbit.db and Orbit.db.AccountSettings then
        Orbit.db.AccountSettings.DrawerHintComplete = true
    end
    local DrawerUI = Orbit.Datatexts and Orbit.Datatexts.DrawerUI
    if DrawerUI and originalDrawerToggle then
        DrawerUI.Toggle = originalDrawerToggle
        originalDrawerToggle = nil
    end
end

-- [ EDIT MODE LIFECYCLE ] ---------------------------------------------------------------------------
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function()
        if Tour.active then return end
        local as = Orbit.db and Orbit.db.AccountSettings
        if not as then return end
        if as.CanvasHintComplete == false then Tour:ShowCanvasHint() end
        if as.DrawerHintComplete == false then Tour:ShowDrawerHint() end
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        if Tour.canvasHintActive then Tour:HideCanvasHint(false) end
        if Tour.drawerHintActive then Tour:HideDrawerHint(false) end
    end)
end

-- [ SLASH COMMAND (testing) ] -----------------------------------------------------------------------
SLASH_ORBITTOUR1 = "/orbittour"
SlashCmdList["ORBITTOUR"] = function()
    if not EditModeManagerFrame or not EditModeManagerFrame:IsShown() then
        print("|cFF66DD66Orbit:|r Enter Edit Mode first (Escape > Edit Mode)")
        return
    end
    if Tour.active then Tour:EndTour() end
    Tour:StartTour(true)
end
