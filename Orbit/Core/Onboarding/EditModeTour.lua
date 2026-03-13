-- [ EDIT MODE - GUIDED TOUR (PLAYGROUND) ]-------------------------------------------
-- First-login-only anchoring playground with dark overlay and guided steps
---@type Orbit
local Orbit = Orbit
local Engine = Orbit.Engine

-- [ CONSTANTS ]----------------------------------------------------------------------
local OVERLAY_ALPHA = 0.40
local OVERLAY_STRATA = "FULLSCREEN_DIALOG"
local OVERLAY_LEVEL = 900
local FRAME_STRATA = "FULLSCREEN_DIALOG"
local FRAME_LEVEL = 910
local FRAME_W = 150
local FRAME_H = 50
local FRAME_OFFSET_X = 150
local TOOLTIP_PAD = 10
local TOOLTIP_MAX_WIDTH = 260
local TOOLTIP_BORDER = 1
local NEXT_BTN_HEIGHT = 20
local NEXT_BTN_WIDTH = 70
local NEXT_BTN_GAP = 6
local CHECK_INTERVAL = 0.1
local AUTO_ADVANCE_DELAY = 1.5
local FADE_DURATION = 0.3
local DIALOG_STRATA = FRAME_STRATA
local DIALOG_LEVEL = FRAME_LEVEL + 20
local ACCENT = { r = 0.3, g = 0.8, b = 0.3 }
local BG = { r = 0.08, g = 0.08, b = 0.08, a = 0.95 }
local BORDER_CLR = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 }
local TEXT_CLR = { r = 0.85, g = 0.85, b = 0.85 }
local TITLE_CLR = { r = ACCENT.r, g = ACCENT.g, b = ACCENT.b }
local ACCENT_WIDTH = 2
local FONT = "GameFontNormalSmall"

-- [ LOCALIZATION ]-------------------------------------------------------------------
local L = {
    NEXT = "Next", DONE = "Done",
    STEP1_TITLE = "Your Frames",
    STEP1_TEXT = "These are two Orbit frames.\nClick one to select it, then drag\nto reposition.",
    STEP2_TITLE = "Frame Settings",
    STEP2_TEXT = "A settings dialog opened!\nTry adjusting the width and height\nof the selected frame.",
    STEP3_TITLE = "Anchoring",
    STEP3_TEXT = "Drag the frames together around\nthe edges. Notice the tooltip and\ncolored lines \u2014 how you anchor\ndictates how the frame will grow\nand change. Drop to anchor, or\nhold Shift for a precision drop\nwithout anchoring.",
    STEP4_TITLE = "Parent & Child",
    STEP4_TEXT = "When frames are anchored, one\nbecomes the parent (highlighted\nin green) and the other the child.\nDrag the parent \u2014 the child follows!\nThe parent controls position for\nboth frames.",
    STEP5_TITLE = "Adjust Distance",
    STEP5_TEXT = "Select the child frame, then scroll\nthe mouse wheel to change the gap\nbetween it and its parent.\nHold Shift for larger steps.",
    STEP6_TITLE = "Arrow Nudge",
    STEP6_TEXT = "Select the parent frame and use\narrow keys to nudge it 1 pixel\nat a time. Both frames move\ntogether. Shift for 10px jumps.",
    STEP7_TITLE = "Drag Resize",
    STEP7_TEXT = "Grab the resize handle in the\nbottom-right corner of a selected\nframe. Drag to resize it within\nthe min/max bounds.",
    STEP8_TITLE = "Plugin Manager",
    STEP8_TEXT = "This is the Orbit Options button.\nLeft-click to toggle plugins on/off\nand configure each frame.\nRight-click for color and texture\nsettings.",
    STEP9_TITLE = "Explore!",
    STEP9_TEXT = "To get the most out of Orbit,\njust play around! Drag, drop,\nanchor and resize frames in\nEdit Mode. Every frame is yours\nto customize.",
}

-- [ MODULE ]-------------------------------------------------------------------------
Engine.EditModeTour = Engine.EditModeTour or {}
local Tour = Engine.EditModeTour
Tour.active = false
Tour.index = 0

-- [ PLUGIN REFERENCE ]---------------------------------------------------------------
local function GetPlugin() return Orbit:GetPlugin("Orbit_Tour") end
local function GetFrameA() local p = GetPlugin(); return p and p.frameA end
local function GetFrameB() local p = GetPlugin(); return p and p.frameB end

-- [ DARK OVERLAY ]-------------------------------------------------------------------
local overlay = CreateFrame("Frame", "OrbitEditModeTourOverlay", UIParent)
overlay:SetFrameStrata(OVERLAY_STRATA)
overlay:SetFrameLevel(OVERLAY_LEVEL)
overlay:SetAllPoints(UIParent)
overlay:EnableMouse(true)
overlay:Hide()

overlay.bg = overlay:CreateTexture(nil, "BACKGROUND")
overlay.bg:SetAllPoints()
overlay.bg:SetColorTexture(0, 0, 0, OVERLAY_ALPHA)

-- [ TASK COMPLETION STATE ]----------------------------------------------------------
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
    taskState.initialPadding = nil
end

-- [ TOUR STOPS ]---------------------------------------------------------------------
local TOUR_STOPS -- forward declaration, initialized after tooltip

-- [ CUSTOM TOOLTIP ]-----------------------------------------------------------------
local function MakeBorderEdge(parent, horiz, p1, r1, p2, r2)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(BORDER_CLR.r, BORDER_CLR.g, BORDER_CLR.b, BORDER_CLR.a)
    t:SetPoint(p1, parent, r1)
    t:SetPoint(p2, parent, r2)
    if horiz then t:SetHeight(TOOLTIP_BORDER) else t:SetWidth(TOOLTIP_BORDER) end
    return t
end

local tip = CreateFrame("Frame", nil, UIParent)
tip:SetFrameStrata("TOOLTIP")
tip:SetFrameLevel(999)
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
    end
end)

-- [ SETTINGS CHANGE TRACKING ]------------------------------------------------------
local originalSetSetting = nil

local function TrackingSetSetting(self, systemIndex, key, value)
    originalSetSetting(self, systemIndex, key, value)
    if Tour.active then
        taskState.settingsChanged = true
        if key == "Width" or key == "Height" then taskState.resized = true end
    end
end

-- [ PARENT / CHILD HELPERS ]---------------------------------------------------------
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

-- [ COMPLETION CHECKER ]-------------------------------------------------------------
local checkElapsed = 0
tip:SetScript("OnUpdate", function(self, elapsed)
    if not Tour.active then return end
    checkElapsed = checkElapsed + elapsed
    if checkElapsed < CHECK_INTERVAL then return end
    checkElapsed = 0
    local stop = TOUR_STOPS[Tour.index]
    if not stop then return end
    local frameA, frameB = GetFrameA(), GetFrameB()
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
        -- Re-elevate tour frame selections (DeselectAll/UpdateVisuals reset strata)
        for _, tf in ipairs({ frameA, frameB }) do
            local s = Selection.selections[tf]
            if s then
                s:SetFrameStrata(FRAME_STRATA)
                s:SetFrameLevel(FRAME_LEVEL + 5)
                s:EnableMouse(true)
            end
        end
    end
    -- Keep settings dialog elevated above overlay
    local dialog = Orbit.SettingsDialog
    if dialog and dialog:IsShown() then
        dialog:SetFrameStrata(DIALOG_STRATA)
        dialog:SetFrameLevel(DIALOG_LEVEL)
    end
    -- Auto-advance to next stop after 1s debounce when task complete
    if stop.check and stop.check() then
        if not Tour._advanceTimer then
            Tour._advanceTimer = C_Timer.NewTimer(AUTO_ADVANCE_DELAY, function()
                Tour._advanceTimer = nil
                if not Tour.active then return end
                if Tour.index < #TOUR_STOPS then
                    Tour:ShowTourStop(Tour.index + 1)
                end
            end)
        end
    end
end)

-- [ LAYOUT TOOLTIP ]-----------------------------------------------------------------
local TOOLTIP_OFFSET = 8

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
    tip.nextBtn:SetText(L.DONE)
    if isLast then tip.nextBtn:Show() else tip.nextBtn:Hide() end
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

-- [ SNAP ISOLATION ]------------------------------------------------------------------
local originalGetSnapTargets = nil

local function IsolatedGetSnapTargets(self, excludeFrame)
    local frameA, frameB = GetFrameA(), GetFrameB()
    local targets = {}
    if frameA and excludeFrame ~= frameA and frameA:IsVisible() then targets[#targets + 1] = frameA end
    if frameB and excludeFrame ~= frameB and frameB:IsVisible() then targets[#targets + 1] = frameB end
    return targets
end

-- [ NUDGE TRACKING ]-----------------------------------------------------------------
local originalNudgeFrame = nil

local function TrackingNudgeFrame(self, frame, direction, ...)
    local frameA, frameB = GetFrameA(), GetFrameB()
    if frame == frameA or frame == frameB then taskState.nudged = true end
    return originalNudgeFrame(self, frame, direction, ...)
end

-- [ TOUR STOPS (deferred init — needs frame refs) ]----------------------------------
TOUR_STOPS = {
    { anchorKey = "A",
      title = L.STEP1_TITLE, text = L.STEP1_TEXT,
      check = function() return taskState.dragged end },
    { anchorKey = "dialog", tooltipPoint = "LEFT", tooltipRel = "RIGHT", tpX = 8, tpY = 0,
      title = L.STEP2_TITLE, text = L.STEP2_TEXT,
      check = function() return taskState.settingsChanged end },
    { anchorKey = "B",
      title = L.STEP3_TITLE, text = L.STEP3_TEXT,
      check = function() return taskState.anchored end },
    { anchorKey = "parent",
      title = L.STEP4_TITLE, text = L.STEP4_TEXT,
      check = function() return taskState.parentDragged end },
    { anchorKey = "child",
      title = L.STEP5_TITLE, text = L.STEP5_TEXT,
      check = function() return taskState.distanceChanged end },
    { anchorKey = "parent",
      title = L.STEP6_TITLE, text = L.STEP6_TEXT,
      check = function() return taskState.nudged end },
    { anchorKey = "A",
      title = L.STEP7_TITLE, text = L.STEP7_TEXT,
      check = function() return taskState.resized end },
    { anchorKey = "options", tooltipPoint = "TOPLEFT", tooltipRel = "BOTTOMLEFT", tpX = 0, tpY = -8,
      title = L.STEP8_TITLE, text = L.STEP8_TEXT,
      check = function() return true end },
    { anchorKey = "A",
      title = L.STEP9_TITLE, text = L.STEP9_TEXT,
      check = function() return true end },
}


local function ResolveAnchor(stop)
    if stop.anchorKey == "A" then return GetFrameA()
    elseif stop.anchorKey == "B" then return GetFrameB()
    elseif stop.anchorKey == "parent" then return GetParentFrame()
    elseif stop.anchorKey == "child" then return GetChildFrame()
    elseif stop.anchorKey == "dialog" then return Orbit.SettingsDialog
    elseif stop.anchorKey == "options" then return Orbit.OptionsButton end
end

-- [ PARENT HIGHLIGHT ]---------------------------------------------------------------
local parentGlow = CreateFrame("Frame", nil, UIParent)
parentGlow:SetFrameStrata(FRAME_STRATA)
parentGlow:SetFrameLevel(FRAME_LEVEL + 3)
parentGlow:Hide()
local GLOW_CLR = { r = 0.2, g = 0.9, b = 0.3, a = 0.7 }
local GLOW_W = 2
for _, edge in ipairs({
    { "TOPLEFT", "TOPRIGHT", true },
    { "BOTTOMLEFT", "BOTTOMRIGHT", true },
    { "TOPLEFT", "BOTTOMLEFT", false },
    { "TOPRIGHT", "BOTTOMRIGHT", false },
}) do
    local t = parentGlow:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(GLOW_CLR.r, GLOW_CLR.g, GLOW_CLR.b, GLOW_CLR.a)
    t:SetPoint(edge[1])
    t:SetPoint(edge[2])
    if edge[3] then t:SetHeight(GLOW_W) else t:SetWidth(GLOW_W) end
end

local function ShowParentHighlight(frame)
    if not frame then parentGlow:Hide(); return end
    parentGlow:SetParent(frame)
    parentGlow:SetAllPoints(frame)
    parentGlow:SetFrameStrata(FRAME_STRATA)
    parentGlow:SetFrameLevel(FRAME_LEVEL + 3)
    parentGlow:Show()
end

local function HideParentHighlight()
    parentGlow:Hide()
end

-- [ TOOLTIP ANIMATION ]--------------------------------------------------------------
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

-- [ TOUR CONTROL ]-------------------------------------------------------------------
function Tour:ShowTourStop(idx)
    if self._advanceTimer then self._advanceTimer:Cancel(); self._advanceTimer = nil end
    local stop = TOUR_STOPS[idx]
    if not stop then self:EndTour(); return end
    self.index = idx
    checkElapsed = 0
    local anchor = ResolveAnchor(stop)
    if not anchor then self:EndTour(); return end
    -- Elevate Options button when it's the anchor target
    if stop.anchorKey == "options" and Orbit.OptionsButton then
        Orbit.OptionsButton:SetFrameStrata(FRAME_STRATA)
        Orbit.OptionsButton:SetFrameLevel(FRAME_LEVEL)
        Orbit.OptionsButton:Show()
    end
    -- Show/hide parent highlight for parent/child steps
    if stop.anchorKey == "parent" or stop.anchorKey == "child" then
        ShowParentHighlight(GetParentFrame())
    else
        HideParentHighlight()
    end
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

function Tour:StartTour()
    if self.active then return end
    local plugin = GetPlugin()
    if not plugin or not plugin.frameA or not plugin.frameB then return end
    local frameA, frameB = plugin.frameA, plugin.frameB
    self.active = true
    self.index = 0
    ResetTaskState()
    -- Save and elevate settings dialog strata
    local dialog = Orbit.SettingsDialog
    if dialog then
        savedDialogStrata = dialog:GetFrameStrata()
        savedDialogLevel = dialog:GetFrameLevel()
    end
    -- Hook SetSetting to track settings changes
    if not originalSetSetting then
        originalSetSetting = plugin.SetSetting
        plugin.SetSetting = TrackingSetSetting
    end
    -- Hide all existing Orbit selection overlays
    local Selection = Engine.FrameSelection
    if Selection then
        for _, sel in pairs(Selection.selections) do
            sel:SetAlpha(0)
            sel:EnableMouse(false)
        end
    end
    -- Hide all Blizzard edit mode selection overlays
    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        for _, sysFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if sysFrame.Selection then
                sysFrame.Selection:SetAlpha(0)
                sysFrame.Selection:EnableMouse(false)
            end
        end
    end
    -- Override GetSnapTargets so playground frames only interact with each other
    if Selection and not originalGetSnapTargets then
        originalGetSnapTargets = Selection.GetSnapTargets
        Selection.GetSnapTargets = IsolatedGetSnapTargets
    end
    -- Hook NudgeFrame to track nudge completion
    local Nudge = Engine.SelectionNudge
    if Nudge and not originalNudgeFrame then
        originalNudgeFrame = Nudge.NudgeFrame
        Nudge.NudgeFrame = TrackingNudgeFrame
    end
    -- Reset frame sizes and positions
    plugin:SetSetting("A", "Width", FRAME_W); plugin:SetSetting("A", "Height", FRAME_H)
    plugin:SetSetting("B", "Width", FRAME_W); plugin:SetSetting("B", "Height", FRAME_H)
    taskState.settingsChanged = false
    overlay:Show()
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
    -- Elevate existing selection overlays (factory already attached via AttachSettingsListener)
    if Selection then
        for _, tf in ipairs({ frameA, frameB }) do
            local s = Selection.selections[tf]
            if s then
                s:SetFrameStrata(FRAME_STRATA)
                s:SetFrameLevel(FRAME_LEVEL + 5)
                s:Show()
                s:EnableMouse(true)
                tf:SetMovable(true)
            end
        end
    end
    -- Hide all other Orbit plugin frames and Blizzard Edit Mode chrome
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
end

function Tour:EndTour()
    self.active = false
    self.index = 0
    tip:Hide()
    overlay:Hide()
    HideParentHighlight()
    -- Restore settings dialog strata
    local dialog = Orbit.SettingsDialog
    if dialog then
        if savedDialogStrata then dialog:SetFrameStrata(savedDialogStrata) end
        if savedDialogLevel then dialog:SetFrameLevel(savedDialogLevel) end
        savedDialogStrata = nil
        savedDialogLevel = nil
    end
    -- Restore Options button
    if Orbit.OptionsButton then
        Orbit.OptionsButton:SetFrameStrata("TOOLTIP")
        Orbit.OptionsButton:SetFrameLevel(100)
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

-- [ SLASH COMMAND (testing) ]--------------------------------------------------------
SLASH_ORBITTOUR1 = "/orbittour"
SlashCmdList["ORBITTOUR"] = function()
    if not EditModeManagerFrame or not EditModeManagerFrame:IsShown() then
        print("|cFF66DD66Orbit:|r Enter Edit Mode first (Escape > Edit Mode)")
        return
    end
    if Tour.active then Tour:EndTour() end
    Tour:StartTour()
end
