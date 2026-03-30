---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils
local TrackedBarLayout = Orbit.TrackedBarLayout
local TrackedBarCanvasPreview = Orbit.TrackedBarCanvasPreview

-- [ CONSTANTS ] ---------------------------------------------------------------
local TRACKED_BAR_INDEX = Constants.Tracked.SystemIndex.TrackedBar
local TRACKED_BAR_CHILD_START = Constants.Tracked.SystemIndex.TrackedBar_ChildStart
local MAX_TRACKED_BAR_CHILDREN = Constants.Tracked.MaxBarChildren
local UPDATE_INTERVAL = 0.05
local SMOOTH_ANIM = Enum.StatusBarInterpolation.ExponentialEaseOut
local DEFAULT_WIDTH = 120
local DEFAULT_HEIGHT = 12
local EMPTY_SEED_SIZE = 40
local DROP_HIGHLIGHT_COLOR = { r = 0.3, g = 0.8, b = 0.3, a = 0.3 }
local COLOR_BABY_BLUE = { r = 0.4, g = 0.7, b = 1.0 }
local ControlButtons = OrbitEngine.ControlButtonFactory

local RECHARGE_PROGRESS_CURVE = C_CurveUtil.CreateCurve()
RECHARGE_PROGRESS_CURVE:AddPoint(0.0, 1)
RECHARGE_PROGRESS_CURVE:AddPoint(1.0, 0)

local RECHARGE_ALPHA_CURVE = C_CurveUtil.CreateCurve()
RECHARGE_ALPHA_CURVE:AddPoint(0.0, 0)
RECHARGE_ALPHA_CURVE:AddPoint(0.001, 1)
RECHARGE_ALPHA_CURVE:AddPoint(1.0, 1)
local CHARGE_ADD_ICON = "Interface\\PaperDollInfoFrame\\Character-Plus"
local CHARGE_REMOVE_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local RECHARGE_DIM = 0.35
local DEFAULT_SPACING = 0
local DEFAULT_CHARGE_OFFSET_X = 30
local SEED_GLOW_ALPHA = 0.6
local SEED_PLUS_RATIO = 0.4
local TICK_SIZE_DEFAULT = OrbitEngine.TickMixin.TICK_SIZE_DEFAULT
local TICK_SIZE_MAX = OrbitEngine.TickMixin.TICK_SIZE_MAX
local TICK_OVERSHOOT = OrbitEngine.TickMixin.TICK_OVERSHOOT
local TICK_LEVEL_BOOST = 10

-- [ REFERENCES ] --------------------------------------------------------------
local Plugin = Orbit:GetPlugin("Orbit_Tracked")
if not Plugin then return end

Plugin.indexDefaults = Plugin.indexDefaults or {}
Plugin.indexDefaults[TRACKED_BAR_INDEX] = {
    Width = 120,
    Height = 12,
    DividerSize = 2,
    TickSize = 6,
    BarColorCurve = { pins = { { position = 0, color = { r = 0.4, g = 0.7, b = 1.0, a = 1 } } } },
    SmoothAnimation = false,
    FrequentUpdates = true,
    AlwaysShow = false,
    HideBorders = false,
    InactiveAlpha = 60,
    OutOfCombatFade = false,
    ShowOnMouseover = true,
}

Plugin.TrackedBarAnchor = nil
Plugin.activeTrackedBarChildren = Plugin.activeTrackedBarChildren or {}
Plugin.TrackedBarChildPool = Plugin.TrackedBarChildPool or {}

-- [ SCRUB ] -------------------------------------------------------------------
local function ScrubTrackedBarFrame(frame)
    frame.TrackedBarSpellId = nil
    frame.cachedMaxCharges = nil
    frame._maxCharges = nil
    frame._charges = nil
    frame._knownRechargeDuration = nil
    if frame.CountText then frame.CountText:SetText(""); frame.CountText:Hide() end
    if frame.Dividers then for _, div in ipairs(frame.Dividers) do div:Hide() end end
    if frame.StatusBar then frame.StatusBar:SetValue(0); frame.StatusBar:Hide() end
    if frame.RechargeSegment then frame.RechargeSegment:SetValue(0); frame.RechargeSegment:Hide() end
    if frame.TickBar then frame.TickBar:SetValue(0); frame.TickBar:Hide() end
    if frame.bg then frame.bg:Hide() end
    if frame.SetBorderHidden then frame:SetBorderHidden(true) end
end

-- [ HELPERS ] -----------------------------------------------------------------
local function SnapToPixel(value, scale)
    return OrbitEngine.Pixel:Snap(value, scale)
end

local function PixelMultiple(count, scale)
    return OrbitEngine.Pixel:Multiple(count, scale)
end

local function IsTrackedBarSpell(spellId)
    if not spellId then
        return false, nil
    end
    local ci = C_Spell.GetSpellCharges(spellId)
    return ci and ci.maxCharges and ci.maxCharges > 1, ci
end

local function ResolveSpellFromCursor()
    local cursorType, id, subType, spellID = GetCursorInfo()
    if cursorType ~= "spell" then
        return nil
    end
    local actualId = spellID or id
    if subType and subType ~= "" then
        local bookInfo = C_SpellBook.GetSpellBookItemInfo(id, Enum.SpellBookSpellBank[subType] or Enum.SpellBookSpellBank.Player)
        if bookInfo and bookInfo.spellID then
            actualId = bookInfo.spellID
        end
    end
    return actualId
end

local function GetTrackedBarLabel(frame)
    if frame.TrackedBarSpellId then
        local name = C_Spell.GetSpellName(frame.TrackedBarSpellId)
        if name then
            return name
        end
    end
    return frame.isChildTrackedBar and ("Tracked Bar " .. (frame.childSlot + 1)) or "Tracked Bar 1"
end

local function UpdateTrackedBarLabel(frame)
    local label = GetTrackedBarLabel(frame)
    frame.editModeName = label
    local selection = OrbitEngine.FrameSelection and OrbitEngine.FrameSelection.selections and OrbitEngine.FrameSelection.selections[frame]
    if not selection then
        return
    end
    if selection.Label then
        selection.Label:SetText(label)
    end
    if selection.system then
        selection.system.GetSystemName = function()
            return label
        end
    end
end

-- [ Tracked Bar FRAME CREATION ] ----------------------------------------------
function Plugin:CreateTrackedBarFrame(name, systemIndex, label)
    local plugin = self
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    OrbitEngine.Pixel:Enforce(frame)
    frame:SetSize(EMPTY_SEED_SIZE, EMPTY_SEED_SIZE)
    frame:SetClampedToScreen(true)

    frame.systemIndex = systemIndex
    frame.editModeName = label
    frame.isTrackedBarFrame = true
    frame.editModeTooltipLines = { "Drag and drop spells that have multiple charges here." }
    frame.orbitPlugin = self
    frame.orbitName = "Orbit_Tracked"
    frame:EnableMouse(false)
    frame.orbitClickThrough = true
    frame.anchorOptions = { horizontal = true, vertical = true, mergeBorders = true }
    frame.orbitChainSync = true
    frame.orbitCursorReveal = true
    frame.orbitResizeBounds = { minW = 50, maxW = 400, minH = 6, maxH = 40 }

    frame.defaultPosition = { point = "CENTER", relativeTo = UIParent, relativePoint = "CENTER", x = DEFAULT_CHARGE_OFFSET_X, y = 0 }
    frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_CHARGE_OFFSET_X, 0)

    OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)
    frame.Dividers = {}

    -- Single continuous StatusBar
    frame.StatusBar = CreateFrame("StatusBar", nil, frame)
    frame.StatusBar:SetAllPoints()
    frame.StatusBar:SetMinMaxValues(0, 2)
    frame.StatusBar:SetValue(0)
    frame.StatusBar:SetFrameLevel(frame:GetFrameLevel() + Constants.Levels.StatusBar)

    if not frame.bg then
        frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers.BackdropDeep)
        frame.bg:SetAllPoints()
    end

    frame.SetBorderHidden = function(self, hidden)
        Orbit.Skin.DefaultSetBorderHidden(self, hidden)
    end

    frame:HookScript("OnSizeChanged", function()
        if frame._layoutInProgress then
            return
        end
        if frame.TrackedBarSpellId then
            TrackedBarLayout:LayoutTrackedBar(plugin, frame)
        end
    end)

    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()

    frame.DropHighlight = frame:CreateTexture(nil, "BORDER")
    frame.DropHighlight:SetAllPoints()
    frame.DropHighlight:SetColorTexture(DROP_HIGHLIGHT_COLOR.r, DROP_HIGHLIGHT_COLOR.g, DROP_HIGHLIGHT_COLOR.b, DROP_HIGHLIGHT_COLOR.a)
    frame.DropHighlight:Hide()

    local seed = CreateFrame("Frame", nil, UIParent)
    seed:SetPoint("TOPLEFT", frame, "TOPLEFT")
    seed:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    seed.Backdrop = seed:CreateTexture(nil, "BACKGROUND")
    seed.Backdrop:SetAllPoints()
    seed.Backdrop:SetColorTexture(0, 0, 0, 0.2)
    seed.Glow = seed:CreateTexture(nil, "OVERLAY")
    seed.Glow:SetAtlas("cyphersetupgrade-leftitem-slotinnerglow")
    seed.Glow:SetBlendMode("ADD")
    seed.Glow:SetAllPoints()
    seed.Glow:SetDesaturated(true)
    seed.Glow:SetVertexColor(COLOR_BABY_BLUE.r, COLOR_BABY_BLUE.g, COLOR_BABY_BLUE.b)
    seed.Plus = seed:CreateTexture(nil, "OVERLAY", nil, 2)
    seed.Plus:SetPoint("CENTER")
    seed.Plus:SetSize(12, 12)
    seed.Plus:SetTexture(CHARGE_ADD_ICON)
    seed.Plus:SetDesaturated(true)
    seed.Plus:SetVertexColor(COLOR_BABY_BLUE.r, COLOR_BABY_BLUE.g, COLOR_BABY_BLUE.b)
    seed.PulseAnim = seed:CreateAnimationGroup()
    seed.PulseAnim:SetLooping("BOUNCE")
    local pulse = seed.PulseAnim:CreateAnimation("Alpha")
    pulse:SetTarget(seed.Glow)
    pulse:SetDuration(1)
    pulse:SetFromAlpha(0.4)
    pulse:SetToAlpha(1)
    seed:Hide()
    frame.SeedButton = seed

    frame.TextOverlay = CreateFrame("Frame", nil, frame)
    frame.TextOverlay:SetAllPoints()
    frame.TextOverlay:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.IconOverlay)
    frame.CountText = frame.TextOverlay:CreateFontString(nil, "OVERLAY")
    frame.CountText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    frame.CountText:SetPoint("CENTER", frame, "CENTER", 0, 0)

    frame.RechargePositioner = CreateFrame("StatusBar", nil, frame)
    frame.RechargePositioner:SetFrameLevel(0)
    frame.RechargePositioner:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    frame.RechargePositioner:GetStatusBarTexture():SetAlpha(0)

    frame.RechargeSegment = CreateFrame("StatusBar", nil, frame)
    frame.RechargeSegment:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
    frame.RechargeSegment:SetPoint("LEFT", frame.RechargePositioner:GetStatusBarTexture(), "RIGHT", 0, 0)
    frame.RechargeSegment:SetMinMaxValues(0, 1)

    OrbitEngine.TickMixin:Create(frame, frame.RechargeSegment, frame.RechargePositioner:GetStatusBarTexture())

    frame:SetScript("OnReceiveDrag", function()
        plugin:OnTrackedBarFrameDrop(frame)
    end)
    frame:SetScript("OnMouseDown", function(_, button)
        if InCombatLockdown() then
            return
        end
        if button == "RightButton" and IsShiftKeyDown() then
            plugin:ClearTrackedBarFrame(frame)
        elseif GetCursorInfo() then
            plugin:OnTrackedBarFrameDrop(frame)
        end
    end)

    return frame
end

-- [ FRAME CONTROL BUTTONS ] ---------------------------------------------------
function Plugin:CreateTrackedBarControlButtons(anchor)
    local plugin = self
    ControlButtons:Create(anchor, {
        addIcon = CHARGE_ADD_ICON, removeIcon = CHARGE_REMOVE_ICON,
        childFlag = "isChildTrackedBar",
        onAdd = function() plugin:SpawnTrackedBarChild() end,
        onRemove = function(a) plugin:DespawnTrackedBarChild(a) end,
    })
    self:UpdateTrackedBarControlVisibility(anchor)
    self:UpdateAllTrackedBarControlColors()
end

function Plugin:UpdateTrackedBarControlVisibility(anchor)
    ControlButtons:UpdateVisibility(anchor, "isChildTrackedBar")
end

function Plugin:RefreshAllTrackedBarControlVisibility()
    ControlButtons:RefreshAll(self.TrackedBarAnchor, self.activeTrackedBarChildren, "isChildTrackedBar")
end

function Plugin:UpdateAllTrackedBarControlColors()
    ControlButtons:UpdateColors(self.activeTrackedBarChildren, self.TrackedBarAnchor, MAX_TRACKED_BAR_CHILDREN)
end

function Plugin:SaveTrackedBarChildren()
    local saved = {}
    for _, childData in pairs(self.activeTrackedBarChildren) do
        saved[childData.slot] = childData.systemIndex
    end
    self:SetSetting(TRACKED_BAR_INDEX, "TrackedBarChildren", saved)
end

-- [ SPAWN / DESPAWN CHILDREN ] ------------------------------------------------
function Plugin:SpawnTrackedBarChild()
    local count = 0
    for _ in pairs(self.activeTrackedBarChildren) do
        count = count + 1
    end
    if count >= MAX_TRACKED_BAR_CHILDREN then
        return nil
    end

    local slot = nil
    for s = 1, MAX_TRACKED_BAR_CHILDREN do
        if not self.activeTrackedBarChildren["charge:" .. s] then
            slot = s
            break
        end
    end
    if not slot then
        return nil
    end

    local key = "charge:" .. slot
    local systemIndex = TRACKED_BAR_CHILD_START + slot - 1
    local label = "Tracked Bar " .. (slot + 1)

    local frame = table.remove(self.TrackedBarChildPool)
    if not frame then
        frame = self:CreateTrackedBarFrame("OrbitTrackedBarChild_" .. slot, systemIndex, label)
    else
        frame.systemIndex = systemIndex
        frame.editModeName = label
        OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)
        ScrubTrackedBarFrame(frame)
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:Show()
    frame.isChildTrackedBar = true
    frame.childSlot = slot

    self.activeTrackedBarChildren[key] = { frame = frame, systemIndex = systemIndex, slot = slot }
    local viewerMap = self.viewerMap
    if viewerMap then
        viewerMap[systemIndex] = { anchor = frame, isTrackedBarFrame = true }
    end
    self:SetSetting(systemIndex, "Enabled", true)

    self:CreateTrackedBarControlButtons(frame)
    TrackedBarLayout:LayoutTrackedBar(self, frame)
    TrackedBarCanvasPreview:Setup(self, frame, systemIndex)
    self:UpdateAllTrackedBarControlColors()
    self:UpdateSeedVisibility(frame)
    self:SaveTrackedBarChildren()
    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)

    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        OrbitEngine.FrameSelection:OnEditModeEnter()
    end
    return frame
end

function Plugin:DespawnTrackedBarChild(frame)
    if not frame or not frame.isChildTrackedBar then
        return
    end
    local key = "charge:" .. frame.childSlot
    local systemIndex = frame.systemIndex

    OrbitEngine.FrameAnchor:BreakAnchor(frame, true)
    OrbitEngine.FrameAnchor:RepairAllChains()
    ScrubTrackedBarFrame(frame)
    frame:Hide()
    frame:ClearAllPoints()

    self:SetSetting(systemIndex, "Position", nil)
    self:SetSetting(systemIndex, "Anchor", nil)
    self:SetSetting(systemIndex, "Enabled", nil)

    self.activeTrackedBarChildren[key] = nil
    if self.viewerMap then
        self.viewerMap[systemIndex] = nil
    end

    table.insert(self.TrackedBarChildPool, frame)
    self:UpdateAllTrackedBarControlColors()
    self:RefreshAllTrackedBarControlVisibility()
    self:SaveTrackedBarChildren()

    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        OrbitEngine.FrameSelection:OnEditModeEnter()
    end
end


-- [ DRAG AND DROP ] -----------------------------------------------------------
function Plugin:OnTrackedBarFrameDrop(frame)
    local actualId = ResolveSpellFromCursor()
    if not actualId then
        return
    end
    local isCharge, chargeInfo = IsTrackedBarSpell(actualId)
    if not isCharge then
        return
    end

    ClearCursor()
    self:AssignTrackedBarSpell(frame, actualId, chargeInfo.maxCharges)
end

function Plugin:AssignTrackedBarSpell(frame, spellId, maxCharges)
    frame:Show()
    frame.TrackedBarSpellId = spellId
    frame.cachedMaxCharges = maxCharges
    frame._maxCharges = maxCharges

    local ci = C_Spell.GetSpellCharges(spellId)
    frame._charges = ci and ci.currentCharges or maxCharges
    frame._knownRechargeDuration = ci and ci.cooldownDuration or nil

    self:SetSetting(frame.systemIndex, "TrackedBarSpell", { id = spellId, maxCharges = maxCharges })

    TrackedBarLayout:BuildDividers(frame, maxCharges)
    TrackedBarLayout:LayoutTrackedBar(self, frame)
    self:UpdateTrackedBarFrame(frame)
    self:UpdateSeedVisibility(frame)
    self:UpdateAllTrackedBarControlColors()
    UpdateTrackedBarLabel(frame)
end

function Plugin:ClearTrackedBarFrame(frame)
    ScrubTrackedBarFrame(frame)
    self:SetSetting(frame.systemIndex, "TrackedBarSpell", nil)
    self:ApplyTrackedBarSettings(frame)
    self:UpdateSeedVisibility(frame)
    self:UpdateAllTrackedBarControlColors()
    UpdateTrackedBarLabel(frame)
    if OrbitEngine.FrameAnchor then OrbitEngine.FrameAnchor:RepairAllChains() end
end

-- [ CLICK-THROUGH TOGGLE ] ----------------------------------------------------
function Plugin:SetTrackedBarClickEnabled(enabled)
    if self.TrackedBarAnchor then
        self.TrackedBarAnchor.orbitClickThrough = not enabled
        self.TrackedBarAnchor:EnableMouse(enabled)
    end
    for _, childData in pairs(self.activeTrackedBarChildren or {}) do
        if childData.frame then
            childData.frame.orbitClickThrough = not enabled
            childData.frame:EnableMouse(enabled)
        end
    end
end

-- [ ANCHOR STATE ] ------------------------------------------------------------
function Plugin:RefreshTrackedBarAnchorState(frame)
    if not frame then return end
    OrbitEngine.FrameAnchor:SetFrameDisabled(frame, not frame.TrackedBarSpellId)
end

-- [ SETTINGS APPLICATION ] ----------------------------------------------------
function Plugin:ApplyTrackedBarSettings(frame)
    if not frame then return end
    local sysIndex = frame.systemIndex
    -- Self-heal: if the DB says no spell for this index, scrub the frame
    local dbSpell = self:GetSetting(sysIndex, "TrackedBarSpell")
    if frame.TrackedBarSpellId and (not dbSpell or not dbSpell.id) then
        ScrubTrackedBarFrame(frame)
        frame.orbitDisabled = nil
    end
    if not frame.TrackedBarSpellId then
        self:RefreshTrackedBarAnchorState(frame)
        ScrubTrackedBarFrame(frame)
        frame:SetSize(EMPTY_SEED_SIZE, EMPTY_SEED_SIZE)
        frame:Show()
        frame:SetAlpha(Orbit:IsEditMode() and 1 or 0)
        return
    end
    self:RefreshTrackedBarAnchorState(frame)
    frame:Show()
    if frame.StatusBar then frame.StatusBar:Show() end
    if frame.RechargeSegment then frame.RechargeSegment:Show() end
    if frame.TickBar then frame.TickBar:Show() end
    if frame.bg then frame.bg:Show() end
    if frame.SetBorderHidden then frame:SetBorderHidden(false) end
    TrackedBarLayout:LayoutTrackedBar(self, frame)
    OrbitEngine.Frame:RestorePosition(frame, self, sysIndex)

    local veKey = Orbit.VisibilityEngine and Orbit.VisibilityEngine:GetKeyForPlugin(self.name, sysIndex)
    local isMountedHidden = Orbit.MountedVisibility:IsCachedHidden() and veKey and Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted")
    local alpha = isMountedHidden and 0 or ((self:GetSetting(sysIndex, "Opacity") or 100) / 100)
    frame:SetAlpha(alpha)

    local enableHover = self:GetSetting(sysIndex, "ShowOnMouseover") ~= false
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, sysIndex, "OutOfCombatFade", enableHover) end
end

-- [ UPDATE LOGIC ] ------------------------------------------------------------
function Plugin:UpdateTrackedBarFrame(frame)
    if not frame or not frame.TrackedBarSpellId then
        return
    end
    local chargeInfo = C_Spell.GetSpellCharges(frame.TrackedBarSpellId)
    if not chargeInfo then
        return
    end

    local smoothing = self:GetSetting(frame.systemIndex, "SmoothAnimation") and SMOOTH_ANIM or nil

    frame.StatusBar:SetMinMaxValues(0, chargeInfo.maxCharges)
    frame.StatusBar:SetValue(chargeInfo.currentCharges, smoothing)
    frame.CountText:SetText(chargeInfo.currentCharges)
    frame.CountText:Show()

    frame.RechargePositioner:SetMinMaxValues(0, chargeInfo.maxCharges)
    frame.RechargePositioner:SetValue(chargeInfo.currentCharges, smoothing)

    local progress = 0
    local alphaVal = 0
    local chargeDurObj = C_Spell.GetSpellChargeDuration(frame.TrackedBarSpellId)
    if chargeDurObj then
        progress = chargeDurObj:EvaluateRemainingPercent(RECHARGE_PROGRESS_CURVE)
        alphaVal = chargeDurObj:EvaluateRemainingPercent(RECHARGE_ALPHA_CURVE)
    end

    frame.RechargeSegment:SetValue(progress)
    frame.TickBar:SetValue(progress)
    frame.RechargeSegment:SetAlpha(alphaVal)
    frame.TickBar:SetAlpha(alphaVal)
end

-- [ EVENT-DRIVEN CHARGE UPDATES ] ---------------------------------------------
function Plugin:UpdateAllTrackedBars()
    local anchor = self.TrackedBarAnchor
    if anchor and anchor:IsShown() and anchor.TrackedBarSpellId then
        self:UpdateTrackedBarFrame(anchor)
    end
    for _, childData in pairs(self.activeTrackedBarChildren) do
        local f = childData.frame
        if f and f:IsShown() and f.TrackedBarSpellId then
            self:UpdateTrackedBarFrame(f)
        end
    end
end

function Plugin:IsAnyChargeRecharging()
    local anchor = self.TrackedBarAnchor
    if anchor and anchor.TrackedBarSpellId and anchor._charges and anchor._maxCharges then
        if anchor._charges < anchor._maxCharges then return true end
    end
    for _, childData in pairs(self.activeTrackedBarChildren) do
        local f = childData.frame
        if f and f.TrackedBarSpellId and f._charges and f._maxCharges then
            if f._charges < f._maxCharges then return true end
        end
    end
    return false
end

function Plugin:StartRechargeAnimationTicker()
    if self.TrackedBarUpdateTicker then return end
    local useFrequent = self:GetSetting(TRACKED_BAR_INDEX, "FrequentUpdates") ~= false
    local interval = useFrequent and UPDATE_INTERVAL or (UPDATE_INTERVAL * 2)
    self.TrackedBarUpdateTicker = C_Timer.NewTicker(interval, function()
        self:UpdateAllTrackedBars()
        if not self:IsAnyChargeRecharging() then
            self.TrackedBarUpdateTicker:Cancel()
            self.TrackedBarUpdateTicker = nil
        end
    end)
end

function Plugin:StartChargeUpdateTicker()
    if self._TrackedBarEventSetup then return end
    self._TrackedBarEventSetup = true
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("SPELL_UPDATE_CHARGES")
    frame:SetScript("OnEvent", function()
        self:UpdateAllTrackedBars()
        if self:IsAnyChargeRecharging() then
            self:StartRechargeAnimationTicker()
        end
    end)
    self._TrackedBarEventFrame = frame
end

function Plugin:RefreshChargeUpdateMethod()
    if self:IsAnyChargeRecharging() then
        self:StartRechargeAnimationTicker()
    end
end

-- [ SEED VISIBILITY ] ---------------------------------------------------------
function Plugin:UpdateSeedVisibility(frame)
    if not frame or not frame.SeedButton then
        return
    end

    local hasSpell = frame.TrackedBarSpellId ~= nil
    local cursorSpell = ResolveSpellFromCursor()
    local isDraggingCharge = cursorSpell and IsTrackedBarSpell(cursorSpell) or false

    frame.DropHighlight:SetShown(hasSpell and isDraggingCharge)

    if hasSpell then
        frame.SeedButton:Hide()
        return
    end

    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    if isDraggingCharge or isEditMode then
        frame:SetAlpha(1)
        local plusSize = OrbitEngine.Pixel:Snap(math.min(frame:GetWidth(), frame:GetHeight()) * SEED_PLUS_RATIO)
        frame.SeedButton.Plus:SetSize(plusSize, plusSize)
        frame.SeedButton:Show()
        if isDraggingCharge then frame.SeedButton.PulseAnim:Play() else frame.SeedButton.PulseAnim:Stop(); frame.SeedButton.Glow:SetAlpha(SEED_GLOW_ALPHA) end
    else
        frame:SetAlpha(0)
        frame.SeedButton:Hide()
    end
end

function Plugin:UpdateAllSeedVisibility()
    self:UpdateSeedVisibility(self.TrackedBarAnchor)
    for _, childData in pairs(self.activeTrackedBarChildren) do
        if childData.frame then
            self:UpdateSeedVisibility(childData.frame)
        end
    end
end

-- Charge cursor watcher merged into TrackedUpdater:RegisterCursorWatcher
function Plugin:RegisterChargeCursorWatcher() end

-- [ SPEC CHANGE ] -------------------------------------------------------------
function Plugin:ReloadTrackedBarsForSpec()
    local anchor = self.TrackedBarAnchor
    if not anchor then return end

    -- Pool all active children
    for _, childData in pairs(self.activeTrackedBarChildren) do
        if childData.frame then
            if self.viewerMap then self.viewerMap[childData.systemIndex] = nil end
            if OrbitEngine.FrameAnchor then OrbitEngine.FrameAnchor:BreakAnchor(childData.frame, true) end
            OrbitEngine.FrameAnchor:SetFrameDisabled(childData.frame, true)
            ScrubTrackedBarFrame(childData.frame)
            childData.frame:Hide()
            childData.frame:ClearAllPoints()
            table.insert(self.TrackedBarChildPool, childData.frame)
        end
    end
    self.activeTrackedBarChildren = {}
    if self.TrackedBarUpdateTicker then self.TrackedBarUpdateTicker:Cancel(); self.TrackedBarUpdateTicker = nil end

    -- Reload the anchor from current spec data
    anchor:ClearAllPoints()
    if OrbitEngine.PositionManager then OrbitEngine.PositionManager:ClearFrame(anchor) end
    self:RestoreTrackedBarSpell(anchor, TRACKED_BAR_INDEX)
    UpdateTrackedBarLabel(anchor)
    self:ApplyTrackedBarSettings(anchor)

    -- Restore children from current spec data
    local savedChildren = self:GetSetting(TRACKED_BAR_INDEX, "TrackedBarChildren") or {}
    for slot, sysIndex in pairs(savedChildren) do
        local frame = self:SpawnTrackedBarChild()
        if frame then
            self:RestoreTrackedBarSpell(frame, sysIndex)
            self:ApplyTrackedBarSettings(frame)
        end
    end

    TrackedBarLayout:LayoutTrackedBars(self)
    self:UpdateAllTrackedBars()
    if self:IsAnyChargeRecharging() then
        self:StartRechargeAnimationTicker()
    end
end

function Plugin:RestoreTrackedBarSpell(frame, sysIndex)
    if not frame then
        return
    end
    local data = self:GetSetting(sysIndex, "TrackedBarSpell")
    if not data or not data.id then
        return
    end
    if not IsPlayerSpell(data.id) and not IsSpellKnown(data.id) then
        return
    end

    local isCharge, ci = IsTrackedBarSpell(data.id)
    if not isCharge then
        return
    end
    data.maxCharges = math.max(data.maxCharges or 0, ci.maxCharges)

    frame:Show()
    frame.TrackedBarSpellId = data.id
    frame.cachedMaxCharges = data.maxCharges or 2
    frame._maxCharges = data.maxCharges or 2
    frame._charges = ci and ci.currentCharges or frame.cachedMaxCharges
    frame._knownRechargeDuration = ci and ci.cooldownDuration or nil
    TrackedBarLayout:BuildDividers(frame, frame.cachedMaxCharges)
    UpdateTrackedBarLabel(frame)
end

function Plugin:RefreshTrackedBarMaxCharges()
    local function Refresh(frame)
        if not frame or not frame.TrackedBarSpellId then
            return
        end
        local ci = C_Spell.GetSpellCharges(frame.TrackedBarSpellId)
        if not ci or not ci.maxCharges or issecretvalue(ci.maxCharges) or ci.maxCharges < 2 then
            return
        end
        if ci.maxCharges == frame.cachedMaxCharges then
            return
        end
        frame.cachedMaxCharges = ci.maxCharges
        frame._maxCharges = ci.maxCharges
        self:SetSetting(frame.systemIndex, "TrackedBarSpell", { id = frame.TrackedBarSpellId, maxCharges = ci.maxCharges })
        TrackedBarLayout:BuildDividers(frame, ci.maxCharges)
        TrackedBarLayout:LayoutTrackedBar(self, frame)
    end
    Refresh(self.TrackedBarAnchor)
    for _, childData in pairs(self.activeTrackedBarChildren) do
        Refresh(childData.frame)
    end
end

function Plugin:ClearStaleTrackedBarSpatial(frame, sysIndex)
    if not frame or frame.TrackedBarSpellId then return end
    -- Intentionally left blank:
    -- Position clearing was removed so empty frames don't lose their user-positioned spots across reloads.
end

-- [ RESTORE / INIT ] ----------------------------------------------------------
function Plugin:SetupTrackedBarFrame()
    if self.TrackedBarAnchor then return end
    local anchor = self:CreateTrackedBarFrame("OrbitTrackedBarAnchor", TRACKED_BAR_INDEX, "Tracked Bar 1")
    self.TrackedBarAnchor = anchor

    local viewerMap = self.viewerMap
    if viewerMap then
        viewerMap[TRACKED_BAR_INDEX] = { anchor = anchor, isTrackedBarFrame = true }
    end

    self:RestoreTrackedBarSpell(anchor, TRACKED_BAR_INDEX)
    self:ClearStaleTrackedBarSpatial(anchor, TRACKED_BAR_INDEX)

    local savedChildren = self:GetSetting(TRACKED_BAR_INDEX, "TrackedBarChildren") or {}
    for slot, sysIndex in pairs(savedChildren) do
        local frame = self:SpawnTrackedBarChild()
        if frame then
            self:RestoreTrackedBarSpell(frame, sysIndex)
            self:ClearStaleTrackedBarSpatial(frame, sysIndex)
        end
    end

    self:CreateTrackedBarControlButtons(anchor)
    TrackedBarCanvasPreview:Setup(self, anchor, TRACKED_BAR_INDEX)
    TrackedBarLayout:LayoutTrackedBars(self)
    OrbitEngine.Frame:RestorePosition(anchor, self, TRACKED_BAR_INDEX)
    self:RegisterChargeCursorWatcher()
    self:RegisterChargeRechargeWatcher()
    self:StartChargeUpdateTicker()
    self:UpdateAllTrackedBars()
    if self:IsAnyChargeRecharging() then
        self:StartRechargeAnimationTicker()
    end
end

-- [ RECHARGE WATCHER ] --------------------------------------------------------
function Plugin:RegisterChargeRechargeWatcher()
    if self._TrackedBarRechargeWatcherSetup then
        return
    end
    self._TrackedBarRechargeWatcherSetup = true
    local plugin = self
    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:SetScript("OnEvent", function(_, event, unit, _, spellId)
        if event == "SPELLS_CHANGED" then
            plugin:RefreshTrackedBarMaxCharges()
            TrackedBarLayout:LayoutTrackedBars(plugin)
            return
        end
        if unit ~= "player" then
            return
        end
        local function HandleCast(TrackedBarFrame)
            if not TrackedBarFrame or TrackedBarFrame.TrackedBarSpellId ~= spellId then
                return
            end
            CooldownUtils:OnChargeCast(TrackedBarFrame)
        end
        HandleCast(plugin.TrackedBarAnchor)
        for _, childData in pairs(plugin.activeTrackedBarChildren) do
            HandleCast(childData.frame)
        end
    end)
end
