-- [ TRACKED BAR ] -------------------------------------------------------------
-- Single-payload bar (horizontal or vertical). Each bar holds one ability or
-- item and renders it in one of three modes determined by what was dropped:
--
--   * charges    — spell with maxCharges > 1. Bar split into N segments by
--                  dividers; main StatusBar value = currentCharges (sink-style,
--                  passes secret values straight to SetValue/SetText). A
--                  RechargePositioner (invisible StatusBar) drives a visible
--                  RechargeSegment that fills the next segment as the
--                  cooldown progresses. CountText centered shows charges.
--                  Charges mode is spell-only (per product decision — items
--                  always render as continuous bars).
--
--   * active+cd  — spell or item with both an active duration AND a cooldown
--                  duration (e.g. trinkets, Avenging Wrath). Bar drains
--                  full→empty during the active phase, then refills empty→full
--                  during the cooldown phase. The active/cd boundary is
--                  derived from the payload's tooltip-parsed durations and
--                  stored as `_phaseBreakpoint` (a remainingPercent value;
--                  pct >= breakpoint = active phase, pct < breakpoint = cd
--                  phase).
--
--   * cd-only    — spell or item with no active duration. Bar fills empty→full
--                  as the cooldown progresses.
--
-- Layout: per-bar setting "Horizontal" (default) or "Vertical". Width and
-- Height stored as long-axis / short-axis (Width = long, Height = short),
-- so the slider ranges (80-400 long, 12-40 short) are valid in both
-- orientations and the same record can flip orientations without resizing.
-- Vertical bars use StatusBar:SetOrientation("VERTICAL") which fills bottom
-- → top, naturally giving "active drains downward" (value decreases) and
-- "cd fills upward" (value increases) — the active+cd math doesn't change.
--
-- Spells use `C_Spell.GetSpellCooldownDuration` (DurationObject) +
-- `EvaluateRemainingPercent(IDENTITY_CURVE)` to get a numeric remainingPercent
-- without crossing a secret-value boundary. Items use `C_Container.GetItemCooldown`
-- which returns numeric (start, duration) directly — no curve needed.
--
-- Two-step replacement: bars hold ONE payload only. Replacement requires the
-- user to explicitly clear the existing payload first (shift-right-click)
-- before dropping a new one. Shift-right-click on an empty bar deletes the
-- bar entirely.
--
-- Visuals:
--   * empty bars collapse to a single drop-hint square (height x height) so
--     they read as a dropzone, not a bar. BarBg + border stay hidden until a
--     payload is dropped, mirroring the icon container's empty state.
--   * drop hint backdrop: cdm-empty (deepest, matches cooldown viewer slots)
--   * drop hint square: talents-node-choiceflyout-square-yellow, native color
--   * drop hint plus: bags-icon-addslots (natively green), desaturated and
--     vertex-tinted golden yellow so it pops against the yellow square
--   * whole hint alpha 0.4 idle / 1.0 hover (per-texture; bar StatusBar stays full)
--   * shift-right-click with payload → clear payload (bar stays, becomes empty)
--   * shift-right-click without payload → delete bar
local _, Orbit = ...

local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local DragDrop = Orbit.CooldownDragDrop
local CooldownUtils = OrbitEngine.CooldownUtils
local TickMixin = OrbitEngine.TickMixin

-- [ CONSTANTS ] ---------------------------------------------------------------
local DROP_ZONE_BACKDROP_ATLAS = "cdm-empty"
local DROP_ZONE_BG_ATLAS = "talents-node-choiceflyout-square-yellow"
local DROP_ZONE_PLUS_ATLAS = "bags-icon-addslots"
local DROP_ZONE_SIZE = 34
local DROP_ZONE_ALPHA_IDLE = 0.4
local DROP_ZONE_ALPHA_HOVER = 1.0
local DROP_ZONE_PLUS_INSET_RATIO = 0.28
-- Plus glyph is vertex-tinted golden yellow so it stays legible against the
-- native yellow square background.
local DROP_ZONE_PLUS_TINT_R, DROP_ZONE_PLUS_TINT_G, DROP_ZONE_PLUS_TINT_B = 1.0, 0.82, 0.0
local DEFAULT_WIDTH = 200
local DEFAULT_HEIGHT = 20
local UPDATE_INTERVAL = 0.05
local FONT_SIZE_DEFAULT = 12
local TEXT_PADDING = 5
local MAX_DIVIDERS = 10
local DIVIDER_SIZE = 2
local RECHARGE_DIM = 0.35
local DEFAULT_BAR_COLOR_R, DEFAULT_BAR_COLOR_G, DEFAULT_BAR_COLOR_B = 0.3, 0.7, 1
local TICK_SIZE_DEFAULT = TickMixin.TICK_SIZE_DEFAULT
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"

-- [ CURVES ] ------------------------------------------------------------------
-- IDENTITY_CURVE maps remaining-percent (secret) to itself (numeric). Required
-- because EvaluateRemainingPercent without a curve returns a secret value, but
-- WITH a numeric curve it returns a numeric result that can be used for
-- arithmetic / SetValue without throwing in combat.
local IDENTITY_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0.0)
    c:AddPoint(1.0, 1.0)
    return c
end)()

-- INVERSE_CURVE maps remaining-percent → bar fill (1 - pct). cd-only mode bars
-- fill from 0→1 as the cooldown elapses, so we use this directly with SetValue
-- and avoid the Lua-side `1 - pct` arithmetic.
local INVERSE_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 1.0)
    c:AddPoint(1.0, 0.0)
    return c
end)()

-- RECHARGE_PROGRESS_CURVE: charges-mode recharge segment fill. Input is the
-- recharge cooldown's remainingPercent (1 = just started, 0 = done). Output is
-- the segment fill (0 = empty, 1 = full). Matches the original tracked bar.
local RECHARGE_PROGRESS_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 1.0)
    c:AddPoint(1.0, 0.0)
    return c
end)()

-- RECHARGE_ALPHA_CURVE: charges-mode recharge segment visibility. Hides the
-- segment instantly when a recharge completes (remainingPct 0 → alpha 0) and
-- shows it the moment one starts. The 0.001 step is so the curve doesn't
-- linearly fade in over the first 0.1% of the recharge.
local RECHARGE_ALPHA_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0.0)
    c:AddPoint(0.001, 1.0)
    c:AddPoint(1.0, 1.0)
    return c
end)()

-- [ MODULE ] ------------------------------------------------------------------
Orbit.TrackedBar = {}
local Bar = Orbit.TrackedBar

-- [ DROP HINT ALPHA ] ---------------------------------------------------------
-- DropHintFrame hosts all drop hint textures, so a single SetAlpha cascades
-- to every child texture without touching the StatusBar.
local function SetDropHintAlpha(frame, a)
    frame.DropHintFrame:SetAlpha(a)
end

-- [ MODE DETERMINATION ] ------------------------------------------------------
-- Charges mode is spell-only (items always render as continuous). active+cd
-- requires both durations from the tooltip parser (positive). Everything else
-- is cd-only.
local function DetermineMode(payload)
    if not payload or not payload.id then return nil end
    if payload.type == "spell" and payload.maxCharges and payload.maxCharges > 1 then
        return "charges"
    end
    if payload.activeDuration and payload.activeDuration > 0 and payload.cooldownDuration and payload.cooldownDuration > 0 then
        return "active_cd"
    end
    return "cd_only"
end

-- [ FRAME FACTORY ] -----------------------------------------------------------
function Bar:Build(plugin, record)
    local frame = CreateFrame("Frame", "OrbitTrackedBar" .. record.id, UIParent)
    OrbitEngine.Pixel:Enforce(frame)
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame:SetClampedToScreen(true)
    frame.systemIndex = record.id
    frame.editModeName = "Tracked Bar"
    frame.orbitPlugin = plugin
    frame.recordId = record.id
    frame.anchorOptions = { horizontal = false, vertical = true, syncScale = false, syncDimensions = true, mergeBorders = true }
    frame.orbitChainSync = true
    frame.orbitAnchorTargetPerSpec = true
    frame.orbitResizeBounds = { minW = 80, maxW = 400, minH = 12, maxH = 40 }

    OrbitEngine.Frame:AttachSettingsListener(frame, plugin, record.id)

    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()

    frame.IconBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.IconBg:SetColorTexture(0, 0, 0, 0.5)

    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    frame.StatusBar = CreateFrame("StatusBar", nil, frame)
    frame.StatusBar:SetMinMaxValues(0, 1)
    frame.StatusBar:SetValue(0)

    frame.BarBg = frame.StatusBar:CreateTexture(nil, "BACKGROUND")
    frame.BarBg:SetAllPoints(frame.StatusBar)
    frame.BarBg:SetColorTexture(0, 0, 0, 0.5)

    -- RechargePositioner: invisible StatusBar whose texture's RIGHT edge tracks
    -- currentCharges. The visible RechargeSegment anchors LEFT to the
    -- positioner's texture RIGHT, so it always sits at the next-charge slot
    -- without any Lua arithmetic on secret currentCharges. Used in charges
    -- mode only; left in place but its value is never set in other modes.
    frame.RechargePositioner = CreateFrame("StatusBar", nil, frame)
    frame.RechargePositioner:SetStatusBarTexture(WHITE_TEXTURE)
    frame.RechargePositioner:GetStatusBarTexture():SetAlpha(0)
    frame.RechargePositioner:SetMinMaxValues(0, 1)
    frame.RechargePositioner:SetValue(0)

    -- RechargeSegment: the visible segment that fills as a charge recharges.
    -- Sized to one charge-width, anchored LEFT to the positioner texture RIGHT.
    frame.RechargeSegment = CreateFrame("StatusBar", nil, frame)
    frame.RechargeSegment:SetMinMaxValues(0, 1)
    frame.RechargeSegment:SetValue(0)
    frame.RechargeSegment:Hide()

    -- Dividers: charges-mode segment separators. Pre-allocated up to MAX_DIVIDERS;
    -- only the first (maxCharges - 1) are shown when in charges mode.
    frame.Dividers = {}
    for i = 1, MAX_DIVIDERS do
        local div = frame.StatusBar:CreateTexture(nil, "OVERLAY", nil, 7)
        div:SetColorTexture(0, 0, 0, 1)
        div:Hide()
        frame.Dividers[i] = div
    end

    -- TickMixin: created against the main StatusBar by default. In charges
    -- mode, the TickBar is re-anchored to the recharge positioner's texture
    -- RIGHT (and resized to one charge width) so the tick floats with the
    -- recharging segment. In other modes the tick stays anchored to the main
    -- StatusBar and tracks its leading edge as the bar fills.
    TickMixin:Create(frame, frame.StatusBar, nil)
    TickMixin:Hide(frame)

    -- Text overlay frame: parent for NameText/CountText. Sits at frame level
    -- StatusBar + Overlay so the text renders above the border (which lives at
    -- frame level Border = 5). Mirrors the CastBar.TextFrame pattern.
    frame.TextFrame = CreateFrame("Frame", nil, frame)
    frame.TextFrame:SetAllPoints(frame.StatusBar)
    frame.TextFrame:SetFrameLevel(frame.StatusBar:GetFrameLevel() + Constants.Levels.Overlay)

    frame.NameText = frame.TextFrame:CreateFontString(nil, "OVERLAY")
    frame.NameText:SetFont(STANDARD_TEXT_FONT, FONT_SIZE_DEFAULT, "OUTLINE")
    frame.NameText:SetPoint("LEFT", frame.StatusBar, "LEFT", TEXT_PADDING, 0)

    frame.CountText = frame.TextFrame:CreateFontString(nil, "OVERLAY")
    frame.CountText:SetFont(STANDARD_TEXT_FONT, FONT_SIZE_DEFAULT, "OUTLINE")
    frame.CountText:SetPoint("CENTER", frame.StatusBar, "CENTER")
    frame.CountText:Hide()

    -- Canvas Mode: register text components as draggable. Each bar uses its
    -- own record.id as the systemIndex so the position callback persists into
    -- record.settings via the GetSetting redirect (one ComponentPositions per
    -- bar, not one shared across all bars).
    if OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:Attach(frame.NameText, frame, {
            key = "NameText",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(plugin, record.id, "NameText"),
        })
        OrbitEngine.ComponentDrag:Attach(frame.CountText, frame, {
            key = "CountText",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(plugin, record.id, "CountText"),
        })
    end

    -- Canvas Mode: preview renderer. The bar's text FontStrings are children
    -- of the inner StatusBar, so the preview must be sized to the StatusBar's
    -- inner area (frame minus icon), NOT the full frame — otherwise drag
    -- offsets calibrated against a too-large preview map back to the wrong
    -- live coordinates. The decorative icon is parented OUTSIDE the preview
    -- (LEFT in horizontal, TOP in vertical) so it visually represents the
    -- iconBg without inflating the draggable canvas area.
    function frame:CreateCanvasPreview(options)
        local scale = options.scale or 1
        local borderSize = options.borderSize or OrbitEngine.Pixel:DefaultBorderSize(scale)
        local rec = plugin:GetContainerRecord(self.recordId)
        local hasPayload = rec and rec.payload and rec.payload.id
        local showIcon = plugin:GetSetting(self.recordId, "ShowIcon") ~= false
        local isVertical = self._isVertical
        local fW, fH = self:GetWidth(), self:GetHeight()
        local iconSize = (showIcon and hasPayload) and (isVertical and fW or fH) or 0
        local innerW = isVertical and fW or (fW - iconSize)
        local innerH = isVertical and (fH - iconSize) or fH
        local preview = OrbitEngine.Preview.Frame:CreateBasePreview(self, scale, options.parent, borderSize)
        local previewScale = preview:GetEffectiveScale()
        preview:SetSize(
            OrbitEngine.Pixel:Snap(innerW * scale, previewScale),
            OrbitEngine.Pixel:Snap(innerH * scale, previewScale)
        )
        preview.sourceWidth = innerW
        preview.sourceHeight = innerH
        if iconSize > 0 then
            local iconTex = preview:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(iconSize * scale, iconSize * scale)
            if isVertical then
                iconTex:SetPoint("BOTTOM", preview, "TOP", 0, 0)
            else
                iconTex:SetPoint("RIGHT", preview, "LEFT", 0, 0)
            end
            iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local liveTex = self.Icon and self.Icon:GetTexture()
            if liveTex then iconTex:SetTexture(liveTex) end
        end
        local bar = CreateFrame("StatusBar", nil, preview)
        bar:SetAllPoints()
        bar:SetOrientation(isVertical and "VERTICAL" or "HORIZONTAL")
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0.6)
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local texPath = LSM and LSM:Fetch("statusbar", Orbit.db.GlobalSettings.Texture or "Solid")
        if texPath then bar:SetStatusBarTexture(texPath) end
        bar:SetStatusBarColor(frame._barColorR or DEFAULT_BAR_COLOR_R, frame._barColorG or DEFAULT_BAR_COLOR_G, frame._barColorB or DEFAULT_BAR_COLOR_B)
        preview.StatusBar = bar
        return preview
    end

    -- Drop hint shown only when the bar is empty AND ShouldShowDropHints is true
    -- (cursor dragging a cooldown OR cooldown viewer settings panel is open).
    -- Hosted on its own child frame at Overlay level so the textures draw
    -- ABOVE the StatusBar / BarBg / border, mirroring the TextFrame pattern
    -- below. Without this, BarBg (a child texture of StatusBar) would cover
    -- the drop hint square. Mouse stays disabled so the bar's own click
    -- handlers still receive drag/drop events.
    frame.DropHintFrame = CreateFrame("Frame", nil, frame)
    frame.DropHintFrame:SetAllPoints(frame)
    frame.DropHintFrame:SetFrameLevel(frame:GetFrameLevel() + Constants.Levels.Overlay)
    frame.DropHintFrame:Hide()

    frame.DropHintBackdrop = frame.DropHintFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.DropHintBackdrop:SetAtlas(DROP_ZONE_BACKDROP_ATLAS)
    frame.DropHintBg = frame.DropHintFrame:CreateTexture(nil, "BACKGROUND")
    frame.DropHintBg:SetAtlas(DROP_ZONE_BG_ATLAS)
    frame.DropHintPlus = frame.DropHintFrame:CreateTexture(nil, "OVERLAY")
    frame.DropHintPlus:SetAtlas(DROP_ZONE_PLUS_ATLAS)
    -- bags-icon-addslots is natively green; desaturate flattens it to grayscale
    -- so the vertex tint can recolor it golden yellow.
    frame.DropHintPlus:SetDesaturated(true)
    frame.DropHintPlus:SetVertexColor(DROP_ZONE_PLUS_TINT_R, DROP_ZONE_PLUS_TINT_G, DROP_ZONE_PLUS_TINT_B)
    frame.DropHintPlus:SetPoint("CENTER", frame.DropHintBg, "CENTER")

    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnReceiveDrag", function(self) Bar:OnReceiveDrag(plugin, self) end)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            Bar:HandleShiftRightClick(plugin, self)
            return
        end
        if GetCursorInfo() then
            Bar:OnReceiveDrag(plugin, self)
        end
    end)
    frame:SetScript("OnEnter", function(self)
        if self.DropHintFrame:IsShown() then
            SetDropHintAlpha(self, DROP_ZONE_ALPHA_HOVER)
        end
    end)
    frame:SetScript("OnLeave", function(self)
        if self.DropHintFrame:IsShown() then
            SetDropHintAlpha(self, DROP_ZONE_ALPHA_IDLE)
        end
    end)

    frame.OnAnchorChanged = function(self) Bar:Apply(plugin, self, plugin:GetContainerRecord(self.recordId)) end
    frame.SetBorderHidden = Orbit.Skin.DefaultSetBorderHidden

    -- StatusBar resize hook: charges-mode geometry (RechargeSegment width,
    -- TickBar width, divider boundaries) is derived from the StatusBar's
    -- resolved width. That width changes for reasons OUTSIDE of Apply: anchor
    -- chain SyncChild resizes the bar when the docked parent grows/shrinks,
    -- and edit-mode SyncChildren skips ApplySettings entirely. Hook
    -- OnSizeChanged so the geometry tracks the bar regardless of how the
    -- resize was triggered. No-op when not in charges mode (frame._chargesMax
    -- is nil).
    frame.StatusBar:HookScript("OnSizeChanged", function() Bar:LayoutChargesGeometry(frame) end)

    Bar:StartCursorWatcher(plugin, frame)
    Bar:StartUpdateTicker(plugin, frame)
    return frame
end

-- [ APPLY / LAYOUT ] ----------------------------------------------------------
function Bar:Apply(plugin, frame, record)
    if not frame or not record then return end
    plugin:RefreshContainerVirtualState(frame)
    -- Visibility Engine: every bar shares the "TrackedBars" entry (sentinel
    -- index 2). Real record IDs are >= 1000 so the sentinel can't collide.
    -- ApplyOOCFade is idempotent — safe to call from the layout pass.
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, plugin, 2, "OutOfCombatFade", false) end

    local payload = record.payload
    local hasPayload = payload and payload.id

    -- Width = long axis, Height = short axis. Slider ranges (80-400 / 12-40)
    -- are interpreted as long/short rather than X/Y so the same record can
    -- flip orientation without resizing.
    local longDim = plugin:GetSetting(record.id, "Width") or DEFAULT_WIDTH
    local shortDim = plugin:GetSetting(record.id, "Height") or DEFAULT_HEIGHT
    local Pixel = OrbitEngine.Pixel
    if Pixel then longDim = Pixel:Snap(longDim); shortDim = Pixel:Snap(shortDim) end
    local isVertical = plugin:GetSetting(record.id, "Layout") == "Vertical"
    frame._isVertical = isVertical
    -- Resize bounds map long/short axis to W/H. In vertical, drag-W writes
    -- the short-axis "Height" setting and drag-H writes the long-axis "Width"
    -- setting, so the resize handle's pixel deltas land on the slider that
    -- controls that screen axis in either orientation.
    if isVertical then
        frame.orbitResizeBounds = {
            minW = 12, maxW = 40, minH = 80, maxH = 400,
            widthKey = "Height", heightKey = "Width",
        }
    else
        frame.orbitResizeBounds = { minW = 80, maxW = 400, minH = 12, maxH = 40 }
    end
    local frameW = isVertical and shortDim or longDim
    local frameH = isVertical and longDim or shortDim

    -- Empty bars collapse to a single drop-hint square. The frame is already
    -- _isVirtual via RefreshContainerVirtualState, so chain reconciliation
    -- skips it and the saved Width/Height are restored on payload drop.
    -- When docked, anchor width is authoritative — SyncChild sets us to the
    -- parent's width via syncDimensions. Setting our own width here would
    -- clobber the synced value and leave dividers / charge geometry stuck at
    -- the saved size while the bar visually grows. Mirrors BuffBar.
    local FrameAnchor = OrbitEngine.FrameAnchor
    local isDocked = FrameAnchor and FrameAnchor.anchors[frame] ~= nil
    if not hasPayload then
        frame:SetSize(DROP_ZONE_SIZE, DROP_ZONE_SIZE)
        frameW, frameH = DROP_ZONE_SIZE, DROP_ZONE_SIZE
    elseif isDocked then
        frame:SetHeight(frameH)
        frameW = frame:GetWidth()
    else
        frame:SetSize(frameW, frameH)
    end

    Orbit.Skin:SkinBorder(frame, frame, Orbit.db.GlobalSettings.BorderSize or 1)

    local showIcon = plugin:GetSetting(record.id, "ShowIcon") ~= false
    -- Icon is always a square sized to the bar's perpendicular dimension —
    -- the bar's height in horizontal, the bar's width in vertical — so it
    -- mirrors the bar across orientation flips without an aspect-ratio shift.
    local iconSize = (showIcon and hasPayload) and (isVertical and frameW or frameH) or 0

    if iconSize > 0 then
        frame.IconBg:Show()
        frame.Icon:Show()
        frame.IconBg:ClearAllPoints()
        frame.IconBg:SetPoint("TOPLEFT")
        frame.IconBg:SetSize(iconSize, iconSize)
        frame.Icon:ClearAllPoints()
        frame.Icon:SetPoint("TOPLEFT", frame.IconBg, "TOPLEFT")
        frame.Icon:SetPoint("BOTTOMRIGHT", frame.IconBg, "BOTTOMRIGHT")
    else
        frame.IconBg:Hide()
        frame.Icon:Hide()
    end

    frame.StatusBar:ClearAllPoints()
    if isVertical then
        frame.StatusBar:SetOrientation("VERTICAL")
        frame.RechargePositioner:SetOrientation("VERTICAL")
        frame.RechargeSegment:SetOrientation("VERTICAL")
        if iconSize > 0 then
            frame.StatusBar:SetPoint("TOPLEFT", frame.IconBg, "BOTTOMLEFT", 0, 0)
        else
            frame.StatusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        end
        frame.StatusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    else
        frame.StatusBar:SetOrientation("HORIZONTAL")
        frame.RechargePositioner:SetOrientation("HORIZONTAL")
        frame.RechargeSegment:SetOrientation("HORIZONTAL")
        if iconSize > 0 then
            frame.StatusBar:SetPoint("TOPLEFT", frame.IconBg, "TOPRIGHT", 0, 0)
        else
            frame.StatusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        end
        frame.StatusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end

    -- Drop hint fills the collapsed empty-bar frame (DROP_ZONE_SIZE x DROP_ZONE_SIZE).
    -- Anchored TOPLEFT for consistency with the bar's icon position; with the
    -- frame collapsed to a square, TOPLEFT and CENTER are equivalent.
    frame.DropHintBackdrop:ClearAllPoints()
    frame.DropHintBackdrop:SetPoint("TOPLEFT", frame, "TOPLEFT")
    frame.DropHintBackdrop:SetSize(DROP_ZONE_SIZE, DROP_ZONE_SIZE)
    frame.DropHintBg:ClearAllPoints()
    frame.DropHintBg:SetPoint("TOPLEFT", frame, "TOPLEFT")
    frame.DropHintBg:SetSize(DROP_ZONE_SIZE, DROP_ZONE_SIZE)
    local plusSize = DROP_ZONE_SIZE * (1 - DROP_ZONE_PLUS_INSET_RATIO * 2)
    frame.DropHintPlus:SetSize(plusSize, plusSize)

    -- Bar texture / color (read on every Apply pass so global Texture and the
    -- per-bar BarColor curve propagate without rebuilding the frame).
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local texPath = LSM and LSM:Fetch("statusbar", Orbit.db.GlobalSettings.Texture or "Solid") or nil
    if texPath then
        frame.StatusBar:SetStatusBarTexture(texPath)
        frame.RechargeSegment:SetStatusBarTexture(texPath)
    end
    local barColor = OrbitEngine.ColorCurve and OrbitEngine.ColorCurve:GetFirstColorFromCurve(plugin:GetSetting(record.id, "BarColor"))
    local r = (barColor and barColor.r) or DEFAULT_BAR_COLOR_R
    local g = (barColor and barColor.g) or DEFAULT_BAR_COLOR_G
    local b = (barColor and barColor.b) or DEFAULT_BAR_COLOR_B
    local a = (barColor and barColor.a) or 1
    frame._barColorR, frame._barColorG, frame._barColorB, frame._barColorA = r, g, b, a
    frame._barColorIsDim = nil
    self:SetBarColorState(frame, false)
    frame.RechargeSegment:GetStatusBarTexture():SetVertexColor(r * RECHARGE_DIM, g * RECHARGE_DIM, b * RECHARGE_DIM, a)

    -- Mode-specific layout. The mode is recomputed on every Apply (cheap) and
    -- cached on the frame so the update ticker can branch without re-reading
    -- the payload structure. perpDim is the bar's perpendicular dimension —
    -- frameH for horizontal, frameW for vertical — and TickMixin uses it to
    -- size the cross-axis of the tick mark.
    local mode = DetermineMode(payload)
    frame._barMode = mode
    local perpDim = isVertical and frameW or frameH
    self:LayoutForMode(plugin, frame, record, payload, perpDim, mode)

    self:ApplyFont(plugin, frame)
    self:ApplyCanvasComponents(plugin, frame, record)
    self:RefreshSpellState(plugin, frame, record)
end

-- [ CANVAS COMPONENTS ] -------------------------------------------------------
-- Reads ComponentPositions and DisabledComponents for THIS bar's record,
-- applies font overrides via OverrideUtils, and restores saved drag positions
-- via ComponentDrag. Disabled components are force-hidden — for CountText this
-- layers ON TOP of the mode-dependent visibility (charges mode only).
-- frame._countTextDisabled is cached so LayoutForMode doesn't re-show it.
--
-- DisabledComponents is read directly via GetSetting(record.id, ...) instead
-- of ComponentDrag:IsDisabled because the latter calls plugin:IsComponentDisabled
-- with no systemIndex hint, and the plugin fallback (self.frame.systemIndex)
-- is wrong for Tracked: there's no single "current" systemIndex — each bar
-- has its own. Reading directly with the explicit record.id is correct.
function Bar:ApplyCanvasComponents(plugin, frame, record)
    if not OrbitEngine.ComponentDrag then return end
    local savedPositions = plugin:GetSetting(record.id, "ComponentPositions") or {}
    local disabledList = plugin:GetSetting(record.id, "DisabledComponents") or {}
    local disabledSet = {}
    for _, k in ipairs(disabledList) do disabledSet[k] = true end
    local OverrideUtils = OrbitEngine.OverrideUtils
    local fontPath = plugin:GetGlobalFont()

    if disabledSet.NameText then
        frame.NameText:Hide()
    else
        frame.NameText:Show()
        if OverrideUtils then
            local overrides = savedPositions.NameText and savedPositions.NameText.overrides or {}
            OverrideUtils.ApplyOverrides(frame.NameText, overrides, { fontSize = FONT_SIZE_DEFAULT, fontPath = fontPath })
        end
    end

    frame._countTextDisabled = disabledSet.CountText or false
    if disabledSet.CountText then
        frame.CountText:Hide()
    elseif OverrideUtils then
        local overrides = savedPositions.CountText and savedPositions.CountText.overrides or {}
        OverrideUtils.ApplyOverrides(frame.CountText, overrides, { fontSize = FONT_SIZE_DEFAULT, fontPath = fontPath })
    end

    OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
end

-- [ BAR COLOR STATE ] ---------------------------------------------------------
-- The main StatusBar fills two visual roles depending on mode/phase:
--   * "bright" — actively counted state (charges, active+cd's active phase, ready)
--   * "dim"    — recharging state (cd_only filling, active+cd's cd phase)
-- Mirrors the RechargeSegment dim used in charges mode so that whichever shape
-- of bar is on screen, "filling toward ready" reads with the same darker tint.
-- State is cached so the per-tick update path is a no-op when nothing changed.
function Bar:SetBarColorState(frame, dim)
    if frame._barColorIsDim == dim then return end
    frame._barColorIsDim = dim
    local r, g, b, a = frame._barColorR, frame._barColorG, frame._barColorB, frame._barColorA
    if dim then
        frame.StatusBar:GetStatusBarTexture():SetVertexColor(r * RECHARGE_DIM, g * RECHARGE_DIM, b * RECHARGE_DIM, a)
    else
        frame.StatusBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
    end
end

-- [ LAYOUT FOR MODE ] ---------------------------------------------------------
-- Sets up the mode-specific regions. Charges mode stores the size-dependent
-- inputs (maxCharges, tickSize) on the frame and delegates the actual sizing
-- to LayoutChargesGeometry — which is also the function the StatusBar's
-- OnSizeChanged hook calls when the bar gets resized externally (anchor
-- chain SyncChild, parent dock growth, edit mode width drag). Continuous
-- modes (active+cd / cd-only) anchor a single tick to the main bar and
-- compute the active+cd phase breakpoint.
function Bar:LayoutForMode(plugin, frame, record, payload, perpDim, mode)
    local tickSize = plugin:GetSetting(record.id, "TickSize") or TICK_SIZE_DEFAULT
    local orientation = frame._isVertical and "VERTICAL" or "HORIZONTAL"

    if mode == "charges" then
        local maxCharges = payload.maxCharges
        frame._chargesMax = maxCharges
        frame._chargesTickSize = tickSize

        -- Recharge positioner spans the full StatusBar so its texture's
        -- leading edge (RIGHT in horizontal, TOP in vertical) maps
        -- proportionally to currentCharges/maxCharges.
        frame.RechargePositioner:ClearAllPoints()
        frame.RechargePositioner:SetAllPoints(frame.StatusBar)
        frame.RechargePositioner:SetMinMaxValues(0, maxCharges)
        frame.RechargePositioner:SetValue(0)

        frame.RechargeSegment:Show()
        self:LayoutChargesGeometry(frame)
        if not frame._countTextDisabled then frame.CountText:Show() end
    else
        -- Continuous mode (active+cd or cd-only). Hide charges-only regions
        -- and clear the cached charges inputs so the OnSizeChanged hook
        -- becomes a no-op.
        frame._chargesMax = nil
        frame._chargesTickSize = nil
        frame.RechargeSegment:Hide()
        frame.CountText:Hide()
        for _, div in ipairs(frame.Dividers) do div:Hide() end

        -- TickBar overlays the main StatusBar; its value tracks the leading
        -- edge of the fill (driven in the update path).
        frame.TickBar:ClearAllPoints()
        frame.TickBar:SetAllPoints(frame.StatusBar)
        TickMixin:Apply(frame, tickSize, perpDim, frame.StatusBar, orientation)

        if mode == "active_cd" then
            -- Phase breakpoint = remainingPercent at which the active phase
            -- ends. Stored as a frame field so the update path doesn't have
            -- to recompute it on every tick.
            frame._phaseBreakpoint = 1 - (payload.activeDuration / payload.cooldownDuration)
        else
            frame._phaseBreakpoint = nil
        end
    end
end

-- [ CHARGES GEOMETRY ] --------------------------------------------------------
-- Re-derives every charges-mode element whose size depends on the StatusBar's
-- resolved size: the RechargeSegment, the TickBar, and the dividers. Reads
-- frame.StatusBar:GetWidth/GetHeight() as the single source of truth so the
-- values stay consistent. No-op when not in charges mode (frame._chargesMax
-- nil) or when the StatusBar hasn't been sized yet. Called from LayoutForMode
-- AND from the StatusBar OnSizeChanged hook so external resizes (anchor chain
-- SyncChild, edit-mode parent growth) keep the geometry in sync without an
-- Apply pass.
--
-- In horizontal: long axis = width, perpDim = height. RechargeSegment anchors
-- LEFT to RechargePositioner texture's RIGHT (next-charge slot is to the
-- right of the current fill). In vertical: long axis = height, perpDim =
-- width. The bar fills BOTTOM→TOP, so the next-charge slot is ABOVE the
-- current fill — RechargeSegment anchors BOTTOM to RechargePositioner
-- texture's TOP.
function Bar:LayoutChargesGeometry(frame)
    local maxCharges = frame._chargesMax
    if not maxCharges then return end
    local barWidth = frame.StatusBar:GetWidth()
    local barHeight = frame.StatusBar:GetHeight()
    if barWidth <= 1 or barHeight <= 0 then return end

    local isVertical = frame._isVertical
    local longAxis = isVertical and barHeight or barWidth
    local perpDim = isVertical and barWidth or barHeight

    local chargeLength = math.max(1, longAxis / maxCharges)
    local Pixel = OrbitEngine.Pixel
    if Pixel then chargeLength = Pixel:Snap(chargeLength) end

    frame.RechargeSegment:ClearAllPoints()
    frame.TickBar:ClearAllPoints()
    if isVertical then
        frame.RechargeSegment:SetPoint("BOTTOM", frame.RechargePositioner:GetStatusBarTexture(), "TOP", 0, 0)
        frame.RechargeSegment:SetSize(perpDim, chargeLength)
        frame.TickBar:SetPoint("BOTTOM", frame.RechargePositioner:GetStatusBarTexture(), "TOP", 0, 0)
        frame.TickBar:SetSize(perpDim, chargeLength)
    else
        frame.RechargeSegment:SetPoint("LEFT", frame.RechargePositioner:GetStatusBarTexture(), "RIGHT", 0, 0)
        frame.RechargeSegment:SetSize(chargeLength, perpDim)
        frame.TickBar:SetPoint("LEFT", frame.RechargePositioner:GetStatusBarTexture(), "RIGHT", 0, 0)
        frame.TickBar:SetSize(chargeLength, perpDim)
    end

    -- Tick floats with the recharging segment. TickClip is anchored to
    -- RechargeSegment so the tick mark is clipped within the recharging
    -- region (TickMixin:Apply handles the clip anchoring).
    local tickSize = frame._chargesTickSize or TICK_SIZE_DEFAULT
    local orientation = isVertical and "VERTICAL" or "HORIZONTAL"
    TickMixin:Apply(frame, tickSize, perpDim, frame.RechargeSegment, orientation)

    self:LayoutDividers(frame, maxCharges, perpDim, longAxis)
end

-- [ DIVIDER POSITIONING ] -----------------------------------------------------
-- Dividers are centered on proportional charge boundaries ((i/maxCharges) *
-- longAxis) so they align exactly with the StatusBar fill edge at each
-- integer charge value. longAxis and perpDim are passed in by
-- LayoutChargesGeometry so the divider boundaries and the RechargeSegment
-- size come from the same read. In horizontal each divider is a vertical
-- line; in vertical each divider is a horizontal line.
function Bar:LayoutDividers(frame, maxCharges, perpDim, longAxis)
    local Pixel = OrbitEngine.Pixel
    local halfGap = DIVIDER_SIZE / 2
    local isVertical = frame._isVertical
    for i = 1, MAX_DIVIDERS do
        local div = frame.Dividers[i]
        if i < maxCharges then
            local boundary = (i / maxCharges) * longAxis
            if Pixel then boundary = Pixel:Snap(boundary) end
            div:ClearAllPoints()
            if isVertical then
                div:SetSize(perpDim, DIVIDER_SIZE)
                div:SetPoint("BOTTOM", frame.StatusBar, "BOTTOM", 0, boundary - halfGap)
            else
                div:SetSize(DIVIDER_SIZE, perpDim)
                div:SetPoint("LEFT", frame.StatusBar, "LEFT", boundary - halfGap, 0)
            end
            div:Show()
        else
            div:Hide()
        end
    end
end

-- [ FONT APPLIER ] ------------------------------------------------------------
-- Reads GlobalSettings.Font (via plugin:GetGlobalFont) and FontOutline (via
-- Orbit.Skin:GetFontOutline) and applies to NameText/CountText. Called from
-- Apply on every layout pass so global font/outline changes propagate without
-- rebuilding the bar.
function Bar:ApplyFont(plugin, frame)
    local font = plugin:GetGlobalFont() or STANDARD_TEXT_FONT
    local outline = Orbit.Skin and Orbit.Skin:GetFontOutline() or "OUTLINE"
    frame.NameText:SetFont(font, FONT_SIZE_DEFAULT, outline)
    frame.CountText:SetFont(font, FONT_SIZE_DEFAULT, outline)
end

-- [ SPELL STATE ] -------------------------------------------------------------
function Bar:RefreshSpellState(plugin, frame, record)
    local payload = record.payload
    local isEmpty = not payload or not payload.id
    local showHints = plugin:ShouldShowDropHints(isEmpty)

    if isEmpty then
        frame.Icon:SetTexture(nil)
        frame.NameText:SetText("")
        frame.CountText:SetText("")
        frame.StatusBar:SetValue(0)
        frame.RechargeSegment:Hide()
        TickMixin:Hide(frame)
        for _, div in ipairs(frame.Dividers) do div:Hide() end
        frame.BarBg:Hide()
        frame:SetBorderHidden(true)
        if showHints then
            -- Seed IDLE alpha only on the hidden → shown transition; the per-tick
            -- update ticker also calls into RefreshSpellState, and resetting
            -- alpha on every tick would clobber the OnEnter hover state and
            -- cause the dropzone to flicker as the mouse stays over it.
            if not frame.DropHintFrame:IsShown() then
                frame.DropHintFrame:Show()
                SetDropHintAlpha(frame, DROP_ZONE_ALPHA_IDLE)
            end
        else
            frame.DropHintFrame:Hide()
        end
        return
    end

    frame.BarBg:Show()
    frame:SetBorderHidden(false)
    frame.DropHintFrame:Hide()

    -- Icon + name from spell info / item info.
    if payload.type == "spell" then
        local activeId = FindSpellOverrideByID(payload.id) or payload.id
        local spellInfo = C_Spell.GetSpellInfo(activeId)
        if spellInfo then
            frame.Icon:SetTexture(spellInfo.iconID)
            frame.NameText:SetText(spellInfo.name)
        end
    else
        local itemName = C_Item.GetItemNameByID(payload.id)
        local iconId = C_Item.GetItemIconByID(payload.id)
        if iconId then frame.Icon:SetTexture(iconId) end
        if itemName then frame.NameText:SetText(itemName) end
    end

    local mode = frame._barMode
    if mode == "charges" then
        self:UpdateChargesMode(frame, payload)
    elseif mode == "active_cd" then
        self:UpdateActiveCdMode(frame, payload)
    else
        self:UpdateCdOnlyMode(frame, payload)
    end
end

-- [ CHARGES MODE UPDATE ] -----------------------------------------------------
-- Pure sink pattern. payload.maxCharges is the cached non-secret value from
-- drop time so SetMinMaxValues never receives a secret. currentCharges is
-- secret in combat but pipes straight into SetValue / SetText.
function Bar:UpdateChargesMode(frame, payload)
    local ci = C_Spell.GetSpellCharges(payload.id)
    if not ci then return end

    self:SetBarColorState(frame, false)
    frame.StatusBar:SetMinMaxValues(0, payload.maxCharges)
    frame.StatusBar:SetValue(ci.currentCharges)
    frame.CountText:SetText(ci.currentCharges)

    frame.RechargePositioner:SetMinMaxValues(0, payload.maxCharges)
    frame.RechargePositioner:SetValue(ci.currentCharges)

    local chargeDurObj = C_Spell.GetSpellChargeDuration(payload.id)
    if chargeDurObj and RECHARGE_PROGRESS_CURVE then
        local progress = chargeDurObj:EvaluateRemainingPercent(RECHARGE_PROGRESS_CURVE)
        local alphaVal = chargeDurObj:EvaluateRemainingPercent(RECHARGE_ALPHA_CURVE)
        frame.RechargeSegment:SetValue(progress)
        frame.TickBar:SetValue(progress)
        frame.RechargeSegment:SetAlpha(alphaVal)
        if frame.TickMark then frame.TickMark:SetAlpha(alphaVal) end
    else
        frame.RechargeSegment:SetAlpha(0)
        if frame.TickMark then frame.TickMark:SetAlpha(0) end
    end
end

-- [ CD-ONLY MODE UPDATE ] -----------------------------------------------------
-- Bar fills 0→1 as the cooldown elapses. Tick is visible across the whole
-- cooldown. Spell path uses INVERSE_CURVE to get a numeric bar value directly;
-- item path uses C_Container.GetItemCooldown which is already numeric.
function Bar:UpdateCdOnlyMode(frame, payload)
    if payload.type == "spell" then
        local activeId = FindSpellOverrideByID(payload.id) or payload.id
        local durObj = C_Spell.GetSpellCooldownDuration(activeId)
        if not durObj or not INVERSE_CURVE then
            self:SetBarFull(frame)
            return
        end
        local barValue = durObj:EvaluateRemainingPercent(INVERSE_CURVE)
        if issecretvalue(barValue) then return end
        self:SetBarColorState(frame, barValue < 1)
        frame.StatusBar:SetMinMaxValues(0, 1)
        frame.StatusBar:SetValue(barValue)
        frame.TickBar:SetValue(barValue)
        if frame.TickMark then frame.TickMark:SetAlpha(barValue >= 1 and 0 or 1) end
    else
        local start, duration = C_Container.GetItemCooldown(payload.id)
        if not start or not duration or duration == 0 then
            self:SetBarFull(frame)
            return
        end
        local elapsed = GetTime() - start
        if elapsed >= duration then
            self:SetBarFull(frame)
            return
        end
        local barValue = elapsed / duration
        self:SetBarColorState(frame, true)
        frame.StatusBar:SetMinMaxValues(0, 1)
        frame.StatusBar:SetValue(barValue)
        frame.TickBar:SetValue(barValue)
        if frame.TickMark then frame.TickMark:SetAlpha(1) end
    end
end

-- [ ACTIVE+CD MODE UPDATE ] ---------------------------------------------------
-- Two phases driven off the same remainingPercent (or numeric elapsed for items):
--   * active phase: pct >= breakpoint, bar drains 1→0, tick hidden
--   * cd phase:     pct <  breakpoint, bar fills 0→1, tick visible on leading edge
-- Spell path uses IDENTITY_CURVE to get a numeric pct, then computes the bar
-- value with arithmetic (cheaper and cleaner than building per-payload curves).
function Bar:UpdateActiveCdMode(frame, payload)
    local breakpoint = frame._phaseBreakpoint
    if not breakpoint then return end

    if payload.type == "spell" then
        local activeId = FindSpellOverrideByID(payload.id) or payload.id
        local durObj = C_Spell.GetSpellCooldownDuration(activeId)
        if not durObj or not IDENTITY_CURVE then
            self:SetBarFull(frame)
            return
        end
        local pct = durObj:EvaluateRemainingPercent(IDENTITY_CURVE)
        if issecretvalue(pct) then return end
        local barValue, inCdPhase
        if pct >= breakpoint then
            local activeRange = 1 - breakpoint
            barValue = activeRange > 0 and ((pct - breakpoint) / activeRange) or 0
            inCdPhase = false
        else
            barValue = breakpoint > 0 and (1 - pct / breakpoint) or 1
            inCdPhase = true
        end
        self:SetBarColorState(frame, inCdPhase)
        frame.StatusBar:SetMinMaxValues(0, 1)
        frame.StatusBar:SetValue(barValue)
        frame.TickBar:SetValue(barValue)
        if frame.TickMark then frame.TickMark:SetAlpha(inCdPhase and 1 or 0) end
    else
        local start, duration = C_Container.GetItemCooldown(payload.id)
        if not start or not duration or duration == 0 then
            self:SetBarFull(frame)
            return
        end
        local elapsed = GetTime() - start
        if elapsed >= duration then
            self:SetBarFull(frame)
            return
        end
        local active = payload.activeDuration
        local barValue, inCdPhase
        if elapsed < active then
            barValue = 1 - elapsed / active
            inCdPhase = false
        else
            barValue = (elapsed - active) / (duration - active)
            inCdPhase = true
        end
        self:SetBarColorState(frame, inCdPhase)
        frame.StatusBar:SetMinMaxValues(0, 1)
        frame.StatusBar:SetValue(barValue)
        frame.TickBar:SetValue(barValue)
        if frame.TickMark then frame.TickMark:SetAlpha(inCdPhase and 1 or 0) end
    end
end

-- [ HELPERS ] -----------------------------------------------------------------
function Bar:SetBarFull(frame)
    self:SetBarColorState(frame, false)
    frame.StatusBar:SetMinMaxValues(0, 1)
    frame.StatusBar:SetValue(1)
    if frame.TickBar then frame.TickBar:SetValue(1) end
    if frame.TickMark then frame.TickMark:SetAlpha(0) end
end

-- [ DROP HANDLING ] -----------------------------------------------------------
function Bar:OnReceiveDrag(plugin, frame)
    if not DragDrop:IsDraggingCooldownAbility() then return end
    local record = plugin:GetContainerRecord(frame.recordId)
    if not record then return end

    -- Two-step gate: bars hold one payload only. The user must explicitly clear
    -- the existing payload with shift-right-click before assigning a new one.
    if record.payload and record.payload.id then
        Orbit:Print("Tracked: clear the current payload first (shift-right-click) before assigning a new one")
        return
    end

    local itemType, id = DragDrop:ResolveCursorInfo()
    if not itemType or not id then return end

    record.payload = DragDrop:BuildTrackedBarPayload(itemType, id)
    if not record.payload then return end

    ClearCursor()
    Bar:Apply(plugin, frame, record)
end

-- [ SHIFT-RIGHT-CLICK LADDER ] ------------------------------------------------
-- Empty bar → delete bar. Bar with payload → clear payload (bar stays, becomes
-- empty). Two clicks to remove a populated bar; one click for an empty one.
function Bar:HandleShiftRightClick(plugin, frame)
    local record = plugin:GetContainerRecord(frame.recordId)
    if not record then return end
    if record.payload and record.payload.id then
        record.payload = nil
        Bar:Apply(plugin, frame, record)
        return
    end
    plugin:DeleteContainer(frame.recordId)
end

-- [ CURSOR WATCHER ] ----------------------------------------------------------
-- Polls ShouldShowDropHints with the bar's current emptiness so the hint
-- appears/disappears as drag/settings/edit-mode signals flip. Emptiness is
-- recomputed each tick because the payload can be assigned/cleared without
-- going through Apply.
function Bar:StartCursorWatcher(plugin, frame)
    if frame._cursorWatcher then return end
    local watcher = CreateFrame("Frame")
    watcher._wasShowing = false
    watcher:SetScript("OnUpdate", function(self)
        local record = plugin:GetContainerRecord(frame.recordId)
        if not record then return end
        local isEmpty = not record.payload or not record.payload.id
        local now = plugin:ShouldShowDropHints(isEmpty)
        if now ~= self._wasShowing then
            self._wasShowing = now
            Bar:RefreshSpellState(plugin, frame, record)
        end
    end)
    frame._cursorWatcher = watcher
end

-- [ UPDATE TICKER ] -----------------------------------------------------------
function Bar:StartUpdateTicker(plugin, frame)
    if frame._updateTicker then return end
    frame._updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        if not frame:IsShown() then return end
        local record = plugin:GetContainerRecord(frame.recordId)
        if record then Bar:RefreshSpellState(plugin, frame, record) end
    end)
end
