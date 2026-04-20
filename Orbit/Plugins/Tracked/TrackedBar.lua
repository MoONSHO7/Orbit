-- [ TRACKED BAR ] -----------------------------------------------------------------------------------
-- Single-payload bar: charges (segmented), active+cd (drain/fill), or cd-only (fill). H or V layout.
local _, Orbit = ...

local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local DragDrop = Orbit.CooldownDragDrop
local CooldownUtils = OrbitEngine.CooldownUtils
local TickMixin = OrbitEngine.TickMixin

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DROP_ZONE_BACKDROP_ATLAS = "cdm-empty"
local DROP_ZONE_BG_ATLAS = "talents-node-choiceflyout-square-yellow"
local DROP_ZONE_PLUS_ATLAS = "bags-icon-addslots"
local DROP_ZONE_SIZE = 34
local DROP_ZONE_ALPHA_IDLE = 0.4
local DROP_ZONE_ALPHA_HOVER = 1.0
local DROP_ZONE_PLUS_INSET_RATIO = 0.28
-- Plus glyph vertex-tinted golden yellow for legibility on yellow background.
local DROP_ZONE_PLUS_TINT_R, DROP_ZONE_PLUS_TINT_G, DROP_ZONE_PLUS_TINT_B = 1.0, 0.82, 0.0
local DROP_ZONE_GLOW_R, DROP_ZONE_GLOW_G, DROP_ZONE_GLOW_B = 1.0, 0.82, 0.0
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
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local ICON_TEXCOORD_MIN = 0.07
local ICON_TEXCOORD_MAX = 0.93

-- [ CURVES ] ----------------------------------------------------------------------------------------
-- IDENTITY_CURVE: remaining-percent (secret) → numeric; used only for time text.
local IDENTITY_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0.0)
    c:AddPoint(1.0, 1.0)
    return c
end)()

-- INVERSE_CURVE: remaining-percent → bar fill (1 - pct) for cd-only mode.
local INVERSE_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 1.0)
    c:AddPoint(1.0, 0.0)
    return c
end)()

-- ONCD_CURVE: remaining-percent → 0/1 "is on cooldown" flag; 0.001 step stabilizes exact-zero.
local ONCD_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0)
    c:AddPoint(0.001, 1)
    c:AddPoint(1.0, 1)
    return c
end)()

-- [ TOOLTIP PARSER ALIASES ] ------------------------------------------------------------------------
local Parser = Orbit.TooltipParser
local BuildPhaseCurve = function(a, cd) return Parser:BuildPhaseCurve(a, cd) end

-- [ ACTIVE+CD FILL CURVE CACHE ] --------------------------------------------------------------------
-- V-shaped curve: remaining% → bar value. Active phase drains 1→0, cd phase fills 0→1.
-- Cached per (activeDuration, cooldownDuration) pair.
local _barFillCurveCache = setmetatable({}, { __mode = "v" })
local function BuildBarFillCurve(activeDuration, cooldownDuration)
    if not activeDuration or not cooldownDuration or cooldownDuration <= 0 or activeDuration >= cooldownDuration then
        return INVERSE_CURVE
    end
    local key = activeDuration .. ":" .. cooldownDuration
    if _barFillCurveCache[key] then return _barFillCurveCache[key] end
    local breakpoint = 1.0 - (activeDuration / cooldownDuration)
    local curve = C_CurveUtil.CreateCurve()
    curve:AddPoint(0.0, 1.0)
    curve:AddPoint(math.max(breakpoint, 0.001), 0.0)
    curve:AddPoint(1.0, 1.0)
    _barFillCurveCache[key] = curve
    return curve
end

-- RECHARGE_PROGRESS_CURVE: recharge remainingPercent → segment fill (inverted).
local RECHARGE_PROGRESS_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 1.0)
    c:AddPoint(1.0, 0.0)
    return c
end)()

-- RECHARGE_ALPHA_CURVE: instant show/hide for recharge segment; 0.001 step prevents linear fade-in.
local RECHARGE_ALPHA_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0.0)
    c:AddPoint(0.001, 1.0)
    c:AddPoint(1.0, 1.0)
    return c
end)()

-- [ MODULE ] ----------------------------------------------------------------------------------------
Orbit.TrackedBar = {}
local Bar = Orbit.TrackedBar

-- [ TIME FORMATTER ] --------------------------------------------------------------------------------
local function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "" end
    if seconds < SECONDS_PER_MINUTE then return string.format("%d", math.floor(seconds)) end
    if seconds < SECONDS_PER_HOUR then return string.format("%d:%02d", math.floor(seconds / SECONDS_PER_MINUTE), math.floor(seconds % SECONDS_PER_MINUTE)) end
    return string.format("%d:%02d:%02d", math.floor(seconds / SECONDS_PER_HOUR), math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE), math.floor(seconds % SECONDS_PER_MINUTE))
end

-- [ DROP HINT ALPHA ] -------------------------------------------------------------------------------
local function SetDropHintAlpha(frame, a)
    frame.DropHintFrame:SetAlpha(a)
end

-- [ MODE DETERMINATION ] ----------------------------------------------------------------------------
-- Charges = spell with maxCharges > 1; active+cd = both durations positive; else cd-only.
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

-- [ FRAME FACTORY ] ---------------------------------------------------------------------------------
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
    frame.Icon:SetTexCoord(ICON_TEXCOORD_MIN, ICON_TEXCOORD_MAX, ICON_TEXCOORD_MIN, ICON_TEXCOORD_MAX)

    frame.StatusBar = CreateFrame("StatusBar", nil, frame)
    frame.StatusBar:SetMinMaxValues(0, 1)
    frame.StatusBar:SetValue(0)

    frame.BarBg = frame.StatusBar:CreateTexture(nil, "BACKGROUND")
    frame.BarBg:SetAllPoints(frame.StatusBar)
    frame.BarBg:SetColorTexture(0, 0, 0, 0.5)

    -- Invisible positioner whose fill edge tracks currentCharges; RechargeSegment anchors to it.
    frame.RechargePositioner = CreateFrame("StatusBar", nil, frame)
    frame.RechargePositioner:SetStatusBarTexture(WHITE_TEXTURE)
    frame.RechargePositioner:GetStatusBarTexture():SetAlpha(0)
    frame.RechargePositioner:SetMinMaxValues(0, 1)
    frame.RechargePositioner:SetValue(0)

    -- Visible segment filling as a charge recharges; sized to one charge-width.
    frame.RechargeSegment = CreateFrame("StatusBar", nil, frame)
    frame.RechargeSegment:SetMinMaxValues(0, 1)
    frame.RechargeSegment:SetValue(0)
    frame.RechargeSegment:Hide()

    -- Charges-mode segment separators; pre-allocated, only first (maxCharges - 1) shown.
    frame.Dividers = {}
    for i = 1, MAX_DIVIDERS do
        local div = frame.StatusBar:CreateTexture(nil, "OVERLAY", nil, 7)
        div:SetColorTexture(0, 0, 0, 1)
        div:Hide()
        frame.Dividers[i] = div
    end

    -- TickMixin: re-anchored to recharge positioner in charges mode, main StatusBar otherwise.
    TickMixin:Create(frame, frame.StatusBar, nil)
    TickMixin:Hide(frame)

    -- Text overlay at Overlay level so NameText/CountText render above the border.
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

    frame.TimeText = frame.TextFrame:CreateFontString(nil, "OVERLAY")
    frame.TimeText:SetFont(STANDARD_TEXT_FONT, FONT_SIZE_DEFAULT, "OUTLINE")
    frame.TimeText:SetPoint("RIGHT", frame.StatusBar, "RIGHT", -TEXT_PADDING, 0)
    frame.TimeText:Hide()

    -- Canvas Mode: register text components as draggable with per-bar systemIndex.
    if OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:Attach(frame.NameText, frame, {
            key = "NameText",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(plugin, record.id, "NameText"),
        })
        OrbitEngine.ComponentDrag:Attach(frame.CountText, frame, {
            key = "CountText",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(plugin, record.id, "CountText"),
        })
        OrbitEngine.ComponentDrag:Attach(frame.TimeText, frame, {
            key = "TimeText",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(plugin, record.id, "TimeText"),
        })
    end

    -- Canvas Mode: preview sized to inner StatusBar area (excludes icon) for correct drag offsets.
    function frame:CreateCanvasPreview(options)
        local scale = options.scale or 1
        local borderSize = options.borderSize or OrbitEngine.Pixel:DefaultBorderSize(scale)
        local rec = plugin:GetContainerRecord(self.recordId)
        local hasPayload = rec and rec.payload and rec.payload.id
        local iconPos = plugin:GetSetting(self.recordId, "IconPosition") or 1
        if type(iconPos) ~= "number" then iconPos = ({ Left = 1, Off = 2, Right = 3 })[iconPos] or 1 end
        local showIcon = iconPos ~= 2
        local iconAtEnd = iconPos == 3
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
                if iconAtEnd then iconTex:SetPoint("TOP", preview, "BOTTOM", 0, 0)
                else iconTex:SetPoint("BOTTOM", preview, "TOP", 0, 0) end
            else
                if iconAtEnd then iconTex:SetPoint("LEFT", preview, "RIGHT", 0, 0)
                else iconTex:SetPoint("RIGHT", preview, "LEFT", 0, 0) end
            end
            iconTex:SetTexCoord(ICON_TEXCOORD_MIN, ICON_TEXCOORD_MAX, ICON_TEXCOORD_MIN, ICON_TEXCOORD_MAX)
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

    -- Drop hint at Overlay level so it draws above StatusBar/BarBg; mouse disabled for passthrough.
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
    -- Desaturate then vertex-tint to recolor natively-green atlas golden yellow.
    frame.DropHintPlus:SetDesaturated(true)
    frame.DropHintPlus:SetVertexColor(DROP_ZONE_PLUS_TINT_R, DROP_ZONE_PLUS_TINT_G, DROP_ZONE_PLUS_TINT_B)
    frame.DropHintPlus:SetPoint("CENTER", frame.DropHintBg, "CENTER")
    Orbit.DropZoneGlow:Attach(frame.DropHintFrame, DROP_ZONE_GLOW_R, DROP_ZONE_GLOW_G, DROP_ZONE_GLOW_B)

    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnReceiveDrag", function(self) Bar:OnReceiveDrag(plugin, self) end)
    frame.OnCooldownSettingsDrop = function(self, spellID) Bar:OnCooldownSettingsDrop(plugin, self, spellID) end
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            if not InCombatLockdown() then Bar:HandleShiftRightClick(plugin, self) end
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

    frame.OnAnchorChanged = function(self, parent, edge, padding)
        Bar:Apply(plugin, self, plugin:GetContainerRecord(self.recordId))
    end
    frame.SetBorderHidden = Orbit.Skin.DefaultSetBorderHidden

    -- Resize hook: re-derive charges-mode geometry when StatusBar resizes externally.
    frame.StatusBar:HookScript("OnSizeChanged", function() Bar:LayoutChargesGeometry(frame) end)

    Bar:StartCursorWatcher(plugin, frame)
    Bar:StartUpdateTicker(plugin, frame)
    Bar:StartChargeEventWatcher(plugin, frame)
    Bar:StartCastWatcher(plugin, frame)
    return frame
end

-- [ CAST WATCHER ] ----------------------------------------------------------------------------------
-- API cooldown often covers only the cd-phase portion; stamp cast time for reliable active-phase timing.
function Bar:StartCastWatcher(plugin, frame)
    if frame._castEventFrame then return end
    local evtFrame = CreateFrame("Frame")
    evtFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    evtFrame:SetScript("OnEvent", function(_, _, _, _, spellId)
        local record = plugin:GetContainerRecord(frame.recordId)
        if not record or not record.payload or record.payload.type ~= "spell" then return end
        local trackedId = record.payload.id
        if spellId ~= trackedId and spellId ~= FindSpellOverrideByID(trackedId) then return end
        frame._castTime = GetTime()
    end)
    frame._castEventFrame = evtFrame
end

-- [ APPLY / LAYOUT ] --------------------------------------------------------------------------------
function Bar:Apply(plugin, frame, record)
    if not frame or not record then return end
    plugin:RefreshContainerVirtualState(frame)
    -- Visibility Engine: all bars share sentinel index 2 for OOCFade.
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, plugin, 2, "OutOfCombatFade", false) end

    local payload = record.payload
    local hasPayload = payload and payload.id

    -- Width = long axis, Height = short axis; same record can flip orientation.
    local longDim = plugin:GetSetting(record.id, "Width") or DEFAULT_WIDTH
    local shortDim = plugin:GetSetting(record.id, "Height") or DEFAULT_HEIGHT
    local Pixel = OrbitEngine.Pixel
    if Pixel then longDim = Pixel:Snap(longDim); shortDim = Pixel:Snap(shortDim) end
    local isVertical = plugin:GetSetting(record.id, "Layout") == "Vertical"
    frame._isVertical = isVertical
    -- Resize bounds map long/short axis to W/H; vertical swaps key mapping.
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

    -- Empty bars collapse to drop-hint square; docked bars defer width to SyncChild.
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

    frame._hideOnCooldown = plugin:GetSetting(record.id, "HideOnCooldown") or false
    frame._hideOnAvailable = plugin:GetSetting(record.id, "HideOnAvailable") or false

    -- IconPosition: 1=Left/Top (start), 2=Off, 3=Right/Bottom (end of long axis).
    local iconPos = plugin:GetSetting(record.id, "IconPosition") or 1
    if type(iconPos) ~= "number" then iconPos = ({ Left = 1, Off = 2, Right = 3 })[iconPos] or 1 end
    local showIcon = iconPos ~= 2
    local iconAtEnd = iconPos == 3
    -- Icon is a square sized to the bar's perpendicular dimension.
    local iconSize = (showIcon and hasPayload) and (isVertical and frameW or frameH) or 0

    if iconSize > 0 then
        frame.IconBg:Show()
        frame.Icon:Show()
        frame.IconBg:ClearAllPoints()
        if isVertical then
            frame.IconBg:SetPoint(iconAtEnd and "BOTTOMLEFT" or "TOPLEFT")
        else
            frame.IconBg:SetPoint(iconAtEnd and "TOPRIGHT" or "TOPLEFT")
        end
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
            if iconAtEnd then
                frame.StatusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                frame.StatusBar:SetPoint("BOTTOMRIGHT", frame.IconBg, "TOPRIGHT", 0, 0)
            else
                frame.StatusBar:SetPoint("TOPLEFT", frame.IconBg, "BOTTOMLEFT", 0, 0)
                frame.StatusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            end
        else
            frame.StatusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.StatusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        end
    else
        frame.StatusBar:SetOrientation("HORIZONTAL")
        frame.RechargePositioner:SetOrientation("HORIZONTAL")
        frame.RechargeSegment:SetOrientation("HORIZONTAL")
        if iconSize > 0 then
            if iconAtEnd then
                frame.StatusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                frame.StatusBar:SetPoint("BOTTOMRIGHT", frame.IconBg, "BOTTOMLEFT", 0, 0)
            else
                frame.StatusBar:SetPoint("TOPLEFT", frame.IconBg, "TOPRIGHT", 0, 0)
                frame.StatusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            end
        else
            frame.StatusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.StatusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        end
    end

    -- Drop hint fills the collapsed empty-bar frame.
    frame.DropHintBackdrop:ClearAllPoints()
    frame.DropHintBackdrop:SetPoint("TOPLEFT", frame, "TOPLEFT")
    frame.DropHintBackdrop:SetSize(DROP_ZONE_SIZE, DROP_ZONE_SIZE)
    frame.DropHintBg:ClearAllPoints()
    frame.DropHintBg:SetPoint("TOPLEFT", frame, "TOPLEFT")
    frame.DropHintBg:SetSize(DROP_ZONE_SIZE, DROP_ZONE_SIZE)
    local plusSize = DROP_ZONE_SIZE * (1 - DROP_ZONE_PLUS_INSET_RATIO * 2)
    frame.DropHintPlus:SetSize(plusSize, plusSize)

    -- Bar texture / color from global Texture and per-bar phase color curves.
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local texPath = LSM and LSM:Fetch("statusbar", Orbit.db.GlobalSettings.Texture or "Solid") or nil
    if texPath then
        frame.StatusBar:SetStatusBarTexture(texPath)
        frame.RechargeSegment:SetStatusBarTexture(texPath)
    end
    local CC = OrbitEngine.ColorCurve
    local function readColor(key, dr, dg, db)
        local c = CC and CC:GetFirstColorFromCurve(plugin:GetSetting(record.id, key))
        return { r = (c and c.r) or dr, g = (c and c.g) or dg, b = (c and c.b) or db, a = (c and c.a) or 1 }
    end
    frame._readyColor  = readColor("ReadyColor",    DEFAULT_BAR_COLOR_R, DEFAULT_BAR_COLOR_G, DEFAULT_BAR_COLOR_B)
    frame._activeColor = readColor("ActiveColor",   0.4, 1.0, 0.4)
    frame._cdColor     = readColor("CooldownColor", 0.5, 0.5, 0.5)
    frame._barColorState = nil
    self:SetBarColor(frame, "ready")
    local cc = frame._cdColor
    frame.RechargeSegment:GetStatusBarTexture():SetVertexColor(cc.r, cc.g, cc.b, cc.a)

    -- Mode-specific layout; perpDim = bar's perpendicular dimension for tick sizing.
    local mode = DetermineMode(payload)
    frame._barMode = mode
    local perpDim = isVertical and frameW or frameH
    self:LayoutForMode(plugin, frame, record, payload, perpDim, mode)

    self:ApplyFont(plugin, frame)
    self:ApplyCanvasComponents(plugin, frame, record)
    self:RefreshSpellState(plugin, frame, record)
end

-- [ CANVAS COMPONENTS ] -----------------------------------------------------------------------------
-- Applies per-bar ComponentPositions/DisabledComponents; reads record.id directly to avoid fallback.
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

    frame._timeTextDisabled = disabledSet.TimeText or false
    if disabledSet.TimeText then
        frame.TimeText:Hide()
    elseif OverrideUtils then
        local overrides = savedPositions.TimeText and savedPositions.TimeText.overrides or {}
        OverrideUtils.ApplyOverrides(frame.TimeText, overrides, { fontSize = FONT_SIZE_DEFAULT, fontPath = fontPath })
    end

    OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
end

-- [ BAR COLOR STATE ] -------------------------------------------------------------------------------
-- state ∈ "ready" | "active" | "cooldown". Cached to avoid redundant SetVertexColor.
function Bar:SetBarColor(frame, state)
    if frame._barColorState == state then return end
    frame._barColorState = state
    local c = state == "active" and frame._activeColor
        or state == "cooldown" and frame._cdColor
        or frame._readyColor
    frame.StatusBar:GetStatusBarTexture():SetVertexColor(c.r, c.g, c.b, c.a)
end

-- [ LAYOUT FOR MODE ] -------------------------------------------------------------------------------
-- Charges: delegates sizing to LayoutChargesGeometry. Continuous: tick on main bar + phase breakpoint.
function Bar:LayoutForMode(plugin, frame, record, payload, perpDim, mode)
    local tickSize = plugin:GetSetting(record.id, "TickSize") or TICK_SIZE_DEFAULT
    local orientation = frame._isVertical and "VERTICAL" or "HORIZONTAL"

    if mode == "charges" then
        local maxCharges = payload.maxCharges
        frame._chargesMax = maxCharges
        frame._chargesTickSize = tickSize

        -- Recharge positioner spans full StatusBar; leading edge maps to currentCharges/maxCharges.
        frame.RechargePositioner:ClearAllPoints()
        frame.RechargePositioner:SetAllPoints(frame.StatusBar)
        frame.RechargePositioner:SetMinMaxValues(0, maxCharges)
        frame.RechargePositioner:SetValue(0)

        frame.RechargeSegment:Show()
        self:LayoutChargesGeometry(frame)
        if not frame._countTextDisabled then frame.CountText:Show() end
    else
        -- Continuous mode: hide charges-only regions, clear cached charges inputs.
        frame._chargesMax = nil
        frame._chargesTickSize = nil
        frame.RechargeSegment:Hide()
        frame.CountText:Hide()
        for _, div in ipairs(frame.Dividers) do div:Hide() end

        -- TickBar overlays main StatusBar; value tracks the leading fill edge.
        frame.TickBar:ClearAllPoints()
        frame.TickBar:SetAllPoints(frame.StatusBar)
        TickMixin:Apply(frame, tickSize, perpDim, frame.StatusBar, orientation)

        if mode == "active_cd" then
            frame._phaseBreakpoint = 1 - (payload.activeDuration / payload.cooldownDuration)
            frame._barFillCurve = BuildBarFillCurve(payload.activeDuration, payload.cooldownDuration)
            frame._phaseCurve = BuildPhaseCurve(payload.activeDuration, payload.cooldownDuration)
        else
            frame._phaseBreakpoint = nil
            frame._barFillCurve = nil
            frame._phaseCurve = nil
        end
    end
end

-- [ CHARGES GEOMETRY ] ------------------------------------------------------------------------------
-- Re-derives RechargeSegment, TickBar, and dividers from StatusBar's resolved size; also called on resize.
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

    -- Tick floats with the recharging segment, clipped within it.
    local tickSize = frame._chargesTickSize or TICK_SIZE_DEFAULT
    local orientation = isVertical and "VERTICAL" or "HORIZONTAL"
    TickMixin:Apply(frame, tickSize, perpDim, frame.RechargeSegment, orientation)

    self:LayoutDividers(frame, maxCharges, perpDim, longAxis)
end

-- [ DIVIDER POSITIONING ] ---------------------------------------------------------------------------
-- Centered on proportional charge boundaries; H = vertical lines, V = horizontal lines.
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

-- [ FONT APPLIER ] ----------------------------------------------------------------------------------
-- Applies global font/outline to NameText/CountText/TimeText.
function Bar:ApplyFont(plugin, frame)
    local font = plugin:GetGlobalFont() or STANDARD_TEXT_FONT
    local outline = Orbit.Skin and Orbit.Skin:GetFontOutline() or "OUTLINE"
    frame.NameText:SetFont(font, FONT_SIZE_DEFAULT, outline)
    frame.CountText:SetFont(font, FONT_SIZE_DEFAULT, outline)
    frame.TimeText:SetFont(font, FONT_SIZE_DEFAULT, outline)
end

-- [ SPELL STATE ] -----------------------------------------------------------------------------------
function Bar:RefreshSpellState(plugin, frame, record)
    local payload = record.payload
    local isEmpty = not payload or not payload.id
    local showHints = plugin:ShouldShowDropHints(isEmpty)

    if isEmpty then
        if frame._visShown == false then frame._visShown = true; frame:Show() end
        frame.Icon:SetTexture(nil)
        frame.NameText:SetText("")
        frame.CountText:SetText("")
        frame.TimeText:Hide()
        frame.StatusBar:SetValue(0)
        frame.RechargeSegment:Hide()
        TickMixin:Hide(frame)
        for _, div in ipairs(frame.Dividers) do div:Hide() end
        frame.BarBg:Hide()
        frame:SetBorderHidden(true)
        if showHints then
            -- Seed IDLE alpha only on hidden → shown transition to avoid clobbering hover.
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

-- [ CHARGES MODE UPDATE ] ---------------------------------------------------------------------------
-- Pure sink: currentCharges (secret) piped directly into SetValue/SetText.
function Bar:UpdateChargesMode(frame, payload)
    local ci = C_Spell.GetSpellCharges(payload.id)
    if not ci then return end

    self:SetBarColor(frame, "ready")
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
    frame.TimeText:Hide()
    self:ApplyBarVisibilityAlpha(frame, chargeDurObj and "cooldown" or "ready")
end

-- [ CD-ONLY MODE UPDATE ] ---------------------------------------------------------------------------
-- Bar fills 0→1 as cooldown elapses. Spell path uses curves piped to C++ sinks;
-- item path uses C_Container.GetItemCooldown (already numeric).
function Bar:UpdateCdOnlyMode(frame, payload)
    if payload.type == "spell" then
        local activeId = FindSpellOverrideByID(payload.id) or payload.id
        local cdInfo = C_Spell.GetSpellCooldown(activeId)
        -- All three checks needed; GetSpellCooldownDuration otherwise returns the GCD durObj and flashes "cooldown".
        if not cdInfo or not cdInfo.isActive or cdInfo.isOnGCD or not payload.cooldownDuration then
            self:SetBarFull(frame)
            self:ApplyBarVisibilityAlpha(frame, "ready")
            return
        end
        local durObj = C_Spell.GetSpellCooldownDuration(activeId)
        if not durObj then
            self:SetBarFull(frame)
            self:ApplyBarVisibilityAlpha(frame, "ready")
            return
        end
        -- Bar fill via INVERSE_CURVE → SetValue (C++ sink, secret-safe).
        local barFill = durObj:EvaluateRemainingPercent(INVERSE_CURVE)
        frame.StatusBar:SetMinMaxValues(0, 1)
        frame.StatusBar:SetValue(barFill)
        frame.TickBar:SetValue(barFill)
        -- Phase detection via ONCD_CURVE → numeric 0/1 for color state + tick alpha.
        local onCd = durObj:EvaluateRemainingPercent(ONCD_CURVE)
        if not issecretvalue(onCd) then
            self:SetBarColor(frame, onCd > 0.5 and "cooldown" or "ready")
        end
        if frame.TickMark then frame.TickMark:SetAlpha(1) end
        -- Time text: IDENTITY_CURVE for numeric pct; hide if secret.
        if not frame._timeTextDisabled and payload.cooldownDuration then
            local pct = durObj:EvaluateRemainingPercent(IDENTITY_CURVE)
            if not issecretvalue(pct) and pct > 0 then
                frame.TimeText:SetText(FormatTime(pct * payload.cooldownDuration))
                frame.TimeText:Show()
            else
                frame.TimeText:Hide()
            end
        else
            frame.TimeText:Hide()
        end
        self:ApplyBarVisibilityAlpha(frame, "cooldown")
    else
        local start, duration = C_Container.GetItemCooldown(payload.id)
        if not start or not duration or duration == 0 then
            self:SetBarFull(frame)
            self:ApplyBarVisibilityAlpha(frame, "ready")
            return
        end
        local elapsed = GetTime() - start
        if elapsed >= duration then
            self:SetBarFull(frame)
            self:ApplyBarVisibilityAlpha(frame, "ready")
            return
        end
        local barValue = elapsed / duration
        self:SetBarColor(frame, "cooldown")
        frame.StatusBar:SetMinMaxValues(0, 1)
        frame.StatusBar:SetValue(barValue)
        frame.TickBar:SetValue(barValue)
        if frame.TickMark then frame.TickMark:SetAlpha(1) end
        if not frame._timeTextDisabled then
            local remaining = duration - elapsed
            frame.TimeText:SetText(FormatTime(remaining))
            frame.TimeText:Show()
        else
            frame.TimeText:Hide()
        end
        self:ApplyBarVisibilityAlpha(frame, "cooldown")
    end
end

-- [ ACTIVE+CD MODE UPDATE ] -------------------------------------------------------------------------
-- Active phase drains 1→0; cd phase fills 0→1. Spell path uses V-shaped fill
-- curve and phase curve piped to C++ sinks; item path uses numeric GetItemCooldown.
function Bar:UpdateActiveCdMode(frame, payload)
    local breakpoint = frame._phaseBreakpoint
    if not breakpoint then return end

    if payload.type == "spell" then
        local activeId = FindSpellOverrideByID(payload.id) or payload.id
        local cdInfo = C_Spell.GetSpellCooldown(activeId)
        -- Real cd for active+cd spells is longer than GCD, so isOnGCD stays false during the legitimate cycle.
        if not cdInfo or not cdInfo.isActive or cdInfo.isOnGCD then
            self:SetBarFull(frame)
            self:ApplyBarVisibilityAlpha(frame, "ready")
            return
        end
        local durObj = C_Spell.GetSpellCooldownDuration(activeId)
        if not durObj then
            self:SetBarFull(frame)
            self:ApplyBarVisibilityAlpha(frame, "ready")
            return
        end
        -- Bar fill via V-curve → SetValue (C++ sink, secret-safe).
        local fillCurve = frame._barFillCurve
        if not fillCurve then self:SetBarFull(frame); self:ApplyBarVisibilityAlpha(frame, "ready"); return end
        local barFill = durObj:EvaluateRemainingPercent(fillCurve)
        frame.StatusBar:SetMinMaxValues(0, 1)
        frame.StatusBar:SetValue(barFill)
        frame.TickBar:SetValue(barFill)
        if frame.TickMark then frame.TickMark:SetAlpha(1) end
        local castTime = frame._castTime
        local activeDur = payload.activeDuration
        local cdDur = payload.cooldownDuration
        local state = "cooldown"
        if castTime and activeDur and cdDur then
            local elapsed = GetTime() - castTime
            local phaseRem
            if elapsed < activeDur then
                phaseRem = activeDur - elapsed
                state = "active"
            elseif elapsed < cdDur then
                phaseRem = cdDur - elapsed
                state = "cooldown"
            else
                state = "ready"
                frame._castTime = nil
            end
            self:SetBarColor(frame, state)
            if not frame._timeTextDisabled and phaseRem and phaseRem > 0 then
                frame.TimeText:SetText(FormatTime(phaseRem))
                frame.TimeText:Show()
            else
                frame.TimeText:Hide()
            end
        else
            -- No cast tracked (e.g. post-/reload mid-cycle): use phase curve for color only.
            local phaseCurve = frame._phaseCurve
            if phaseCurve then
                local phaseVal = durObj:EvaluateRemainingPercent(phaseCurve)
                if not issecretvalue(phaseVal) then
                    state = phaseVal > 0.5 and "cooldown" or "active"
                    self:SetBarColor(frame, state)
                end
            end
            frame.TimeText:Hide()
        end
        self:ApplyBarVisibilityAlpha(frame, state)
    else
        local start, duration = C_Container.GetItemCooldown(payload.id)
        if not start or not duration or duration == 0 then
            self:SetBarFull(frame)
            self:ApplyBarVisibilityAlpha(frame, "ready")
            return
        end
        local elapsed = GetTime() - start
        if elapsed >= duration then
            self:SetBarFull(frame)
            self:ApplyBarVisibilityAlpha(frame, "ready")
            return
        end
        local active = payload.activeDuration
        local barValue, inCdPhase, phaseRem
        if elapsed < active then
            barValue = 1 - elapsed / active
            inCdPhase = false
            phaseRem = active - elapsed
        else
            barValue = (elapsed - active) / (duration - active)
            inCdPhase = true
            phaseRem = duration - elapsed
        end
        self:SetBarColor(frame, inCdPhase and "cooldown" or "active")
        frame.StatusBar:SetMinMaxValues(0, 1)
        frame.StatusBar:SetValue(barValue)
        frame.TickBar:SetValue(barValue)
        if frame.TickMark then frame.TickMark:SetAlpha(1) end
        if not frame._timeTextDisabled then
            frame.TimeText:SetText(FormatTime(phaseRem))
            frame.TimeText:Show()
        else
            frame.TimeText:Hide()
        end
        self:ApplyBarVisibilityAlpha(frame, inCdPhase and "cooldown" or "active")
    end
end

-- [ VISIBILITY ] ------------------------------------------------------------------------------------
-- SetShown not SetAlpha — alpha conflicts with OOCFadeMixin's mouseover reveal and flickers.
function Bar:ApplyBarVisibilityAlpha(frame, state)
    local hide = (frame._hideOnCooldown and state == "cooldown")
              or (frame._hideOnAvailable and state == "ready")
    if hide and (Orbit:IsEditMode() or GetCursorInfo()) then hide = false end
    local target = not hide
    if frame._visShown == target then return end
    frame._visShown = target
    frame:SetShown(target)
end

-- [ HELPERS ] ---------------------------------------------------------------------------------------
function Bar:SetBarFull(frame)
    self:SetBarColor(frame, "ready")
    frame.StatusBar:SetMinMaxValues(0, 1)
    frame.StatusBar:SetValue(1)
    if frame.TickBar then frame.TickBar:SetValue(1) end
    if frame.TickMark then frame.TickMark:SetAlpha(1) end
    frame.TimeText:Hide()
end

-- [ DROP HANDLING ] ---------------------------------------------------------------------------------
function Bar:OnReceiveDrag(plugin, frame)
    if not DragDrop:IsDraggingCooldownAbility() then return end
    local record = plugin:GetContainerRecord(frame.recordId)
    if not record then return end

    -- Two-step gate: clear existing payload first before assigning a new one.
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

function Bar:OnCooldownSettingsDrop(plugin, frame, spellID)
    if not spellID or not DragDrop:HasCooldown("spell", spellID) then return end
    local record = plugin:GetContainerRecord(frame.recordId)
    if not record then return end
    if record.payload and record.payload.id then
        Orbit:Print("Tracked: clear the current payload first (shift-right-click) before assigning a new one")
        return
    end
    record.payload = DragDrop:BuildTrackedBarPayload("spell", spellID)
    if not record.payload then return end
    Bar:Apply(plugin, frame, record)
end

-- [ SHIFT-RIGHT-CLICK LADDER ] ----------------------------------------------------------------------
-- With payload → clear; without → delete bar.
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

-- [ CURSOR WATCHER ] --------------------------------------------------------------------------------
-- Polls ShouldShowDropHints; triggers RefreshSpellState when hint visibility flips.
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

-- [ UPDATE TICKER ] ---------------------------------------------------------------------------------
function Bar:StartUpdateTicker(plugin, frame)
    if frame._updateTicker then return end
    frame._updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        local record = plugin:GetContainerRecord(frame.recordId)
        if record then Bar:RefreshSpellState(plugin, frame, record) end
    end)
end

-- [ CHARGE EVENT WATCHER ] --------------------------------------------------------------------------
-- Immediate update on SPELL_UPDATE_CHARGES for instant visual feedback on cast.
function Bar:StartChargeEventWatcher(plugin, frame)
    if frame._chargeEventFrame then return end
    local evtFrame = CreateFrame("Frame")
    evtFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    evtFrame:SetScript("OnEvent", function()
        local record = plugin:GetContainerRecord(frame.recordId)
        if record then Bar:RefreshSpellState(plugin, frame, record) end
    end)
    frame._chargeEventFrame = evtFrame
end
