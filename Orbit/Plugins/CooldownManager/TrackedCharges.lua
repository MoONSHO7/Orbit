---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils
local ChargeBarLayout = Orbit.ChargeBarLayout
local ChargeBarCanvasPreview = Orbit.ChargeBarCanvasPreview

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local CHARGE_BAR_INDEX = Constants.Cooldown.SystemIndex.ChargeBar
local CHARGE_CHILD_START = Constants.Cooldown.SystemIndex.ChargeBar_ChildStart
local MAX_CHARGE_CHILDREN = Constants.Cooldown.MaxChargeBarChildren
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
local SEED_GLOW_ALPHA = 0.6
local SEED_PLUS_RATIO = 0.4
local TICK_SIZE_DEFAULT = OrbitEngine.TickMixin.TICK_SIZE_DEFAULT
local TICK_SIZE_MAX = OrbitEngine.TickMixin.TICK_SIZE_MAX
local TICK_OVERSHOOT = OrbitEngine.TickMixin.TICK_OVERSHOOT
local TICK_LEVEL_BOOST = 10

-- [ REFERENCES ]------------------------------------------------------------------------------------
local Plugin = Orbit:GetPlugin("Orbit_CooldownViewer")
if not Plugin then
    return
end
Plugin.chargeBarAnchor = nil
Plugin.activeChargeChildren = Plugin.activeChargeChildren or {}
Plugin.chargeChildPool = Plugin.chargeChildPool or {}

-- [ HELPERS ]---------------------------------------------------------------------------------------
local function SnapToPixel(value, scale)
    return OrbitEngine.Pixel:Snap(value, scale)
end

local function PixelMultiple(count, scale)
    return OrbitEngine.Pixel:Multiple(count, scale)
end

local function IsChargeSpell(spellId)
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

local function GetChargeBarLabel(frame)
    if frame.chargeSpellId then
        local name = C_Spell.GetSpellName(frame.chargeSpellId)
        if name then
            return name
        end
    end
    return frame.isChildChargeBar and ("Charge Bar " .. (frame.childSlot + 1)) or "Charge Bar 1"
end

local function UpdateChargeBarLabel(frame)
    local label = GetChargeBarLabel(frame)
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

-- [ CHARGE BAR FRAME CREATION ]--------------------------------------------------------------------
function Plugin:CreateChargeBarFrame(name, systemIndex, label)
    local plugin = self
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    OrbitEngine.Pixel:Enforce(frame)
    frame:SetSize(EMPTY_SEED_SIZE, EMPTY_SEED_SIZE)
    frame:SetClampedToScreen(true)

    frame.systemIndex = systemIndex
    frame.editModeName = label
    frame.isChargeBar = true
    frame.editModeTooltipLines = { "Drag and drop spells that have multiple charges here." }
    frame.orbitPlugin = self
    frame.orbitName = "Orbit_CooldownViewer"
    frame:EnableMouse(false)
    frame.orbitClickThrough = true
    frame.anchorOptions = { horizontal = false, vertical = true, mergeBorders = true }
    frame.orbitChainSync = true

    frame.defaultPosition = { point = "CENTER", relativeTo = UIParent, relativePoint = "CENTER", x = 30, y = 0 }
    frame:SetPoint("CENTER", UIParent, "CENTER", 30, 0)

    OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)
    frame.buttons = {}

    frame.SetBorderHidden = function(self, edge, hidden)
        for _, btn in ipairs(self.buttons) do
            if btn.orbitBackdrop and btn.orbitBackdrop.Borders then
                local border = btn.orbitBackdrop.Borders[edge]
                if border then
                    border:SetShown(not hidden)
                end
            end
        end
    end

    frame:HookScript("OnSizeChanged", function()
        if frame._layoutInProgress then
            return
        end
        if frame.chargeSpellId then
            ChargeBarLayout:LayoutChargeBar(plugin, frame)
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

    local seed = CreateFrame("Frame", nil, frame)
    seed:SetAllPoints()
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
    frame.TextOverlay:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.CountText = frame.TextOverlay:CreateFontString(nil, "OVERLAY")
    frame.CountText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    frame.CountText:SetPoint("CENTER", frame, "CENTER", 0, 0)

    frame.RechargePositioner = CreateFrame("StatusBar", nil, frame)
    frame.RechargePositioner:SetFrameLevel(0)
    frame.RechargePositioner:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    frame.RechargePositioner:GetStatusBarTexture():SetAlpha(0)

    frame.RechargeSegment = CreateFrame("StatusBar", nil, frame)
    frame.RechargeSegment:SetFrameLevel(frame:GetFrameLevel() + 1)
    frame.RechargeSegment:SetPoint("LEFT", frame.RechargePositioner:GetStatusBarTexture(), "RIGHT", 0, 0)
    frame.RechargeSegment:SetMinMaxValues(0, 1)

    OrbitEngine.TickMixin:Create(frame, frame.RechargeSegment, frame.RechargePositioner:GetStatusBarTexture())

    frame:SetScript("OnReceiveDrag", function()
        plugin:OnChargeFrameDrop(frame)
    end)
    frame:SetScript("OnMouseDown", function(_, button)
        if InCombatLockdown() then
            return
        end
        if button == "RightButton" and IsShiftKeyDown() then
            plugin:ClearChargeFrame(frame)
        elseif GetCursorInfo() then
            plugin:OnChargeFrameDrop(frame)
        end
    end)

    return frame
end

-- [ FRAME CONTROL BUTTONS ]-------------------------------------------------------------------------
function Plugin:CreateChargeControlButtons(anchor)
    local plugin = self
    ControlButtons:Create(anchor, {
        addIcon = CHARGE_ADD_ICON, removeIcon = CHARGE_REMOVE_ICON,
        childFlag = "isChildChargeBar",
        onAdd = function() plugin:SpawnChargeChild() end,
        onRemove = function(a) plugin:DespawnChargeChild(a) end,
    })
    self:UpdateChargeControlVisibility(anchor)
    self:UpdateAllChargeControlColors()
end

function Plugin:UpdateChargeControlVisibility(anchor)
    ControlButtons:UpdateVisibility(anchor, "isChildChargeBar")
end

function Plugin:RefreshAllChargeControlVisibility()
    ControlButtons:RefreshAll(self.chargeBarAnchor, self.activeChargeChildren, "isChildChargeBar")
end

function Plugin:UpdateAllChargeControlColors()
    ControlButtons:UpdateColors(self.activeChargeChildren, self.chargeBarAnchor, MAX_CHARGE_CHILDREN)
end

function Plugin:SaveChargeChildren()
    local saved = {}
    for _, childData in pairs(self.activeChargeChildren) do
        saved[childData.slot] = childData.systemIndex
    end
    self:SetSetting(CHARGE_BAR_INDEX, self:GetSpecKey("ChargeChildren"), saved)
end

-- [ SPAWN / DESPAWN CHILDREN ]---------------------------------------------------------------------
function Plugin:SpawnChargeChild()
    local count = 0
    for _ in pairs(self.activeChargeChildren) do
        count = count + 1
    end
    if count >= MAX_CHARGE_CHILDREN then
        return nil
    end

    local slot = nil
    for s = 1, MAX_CHARGE_CHILDREN do
        if not self.activeChargeChildren["charge:" .. s] then
            slot = s
            break
        end
    end
    if not slot then
        return nil
    end

    local key = "charge:" .. slot
    local systemIndex = CHARGE_CHILD_START + slot - 1
    local label = "Charge Bar " .. (slot + 1)

    local frame = table.remove(self.chargeChildPool)
    if not frame then
        frame = self:CreateChargeBarFrame("OrbitChargeChild_" .. slot, systemIndex, label)
    else
        frame.systemIndex = systemIndex
        frame.editModeName = label
        OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)
        frame.chargeSpellId = nil
        frame.cachedMaxCharges = nil
        frame._maxCharges = nil
        for _, btn in ipairs(frame.buttons) do
            btn:Hide()
        end
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:Show()
    frame.isChildChargeBar = true
    frame.childSlot = slot

    self.activeChargeChildren[key] = { frame = frame, systemIndex = systemIndex, slot = slot }
    local viewerMap = self.viewerMap
    if viewerMap then
        viewerMap[systemIndex] = { anchor = frame, isChargeBar = true }
    end
    self:SetSetting(systemIndex, "Enabled", true)

    self:CreateChargeControlButtons(frame)
    ChargeBarLayout:LayoutChargeBar(self, frame)
    ChargeBarCanvasPreview:Setup(self, frame, systemIndex)
    self:UpdateAllChargeControlColors()
    self:UpdateSeedVisibility(frame)
    self:SaveChargeChildren()
    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)

    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        OrbitEngine.FrameSelection:OnEditModeEnter()
    end
    return frame
end

function Plugin:DespawnChargeChild(frame)
    if not frame or not frame.isChildChargeBar then
        return
    end
    local key = "charge:" .. frame.childSlot
    local systemIndex = frame.systemIndex

    OrbitEngine.FrameAnchor:DestroyAnchor(frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame.chargeSpellId = nil
    frame.cachedMaxCharges = nil
    frame._maxCharges = nil
    for _, btn in ipairs(frame.buttons) do
        btn:Hide()
    end

    self:SetSetting(systemIndex, "Position", nil)
    self:SetSetting(systemIndex, "Anchor", nil)
    self:SetSetting(systemIndex, "Enabled", nil)

    self.activeChargeChildren[key] = nil
    if self.viewerMap then
        self.viewerMap[systemIndex] = nil
    end

    table.insert(self.chargeChildPool, frame)
    self:UpdateAllChargeControlColors()
    self:RefreshAllChargeControlVisibility()
    self:SaveChargeChildren()

    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        OrbitEngine.FrameSelection:OnEditModeEnter()
    end
end


-- [ DRAG AND DROP ]---------------------------------------------------------------------------------
function Plugin:OnChargeFrameDrop(frame)
    local actualId = ResolveSpellFromCursor()
    if not actualId then
        return
    end
    local isCharge, chargeInfo = IsChargeSpell(actualId)
    if not isCharge then
        return
    end

    ClearCursor()
    self:AssignChargeSpell(frame, actualId, chargeInfo.maxCharges)
end

function Plugin:AssignChargeSpell(frame, spellId, maxCharges)
    frame.chargeSpellId = spellId
    frame.cachedMaxCharges = maxCharges
    frame._maxCharges = maxCharges

    local ci = C_Spell.GetSpellCharges(spellId)
    frame._trackedCharges = ci and ci.currentCharges or maxCharges
    frame._knownRechargeDuration = ci and ci.cooldownDuration or nil

    self:SetSetting(frame.systemIndex, self:GetSpecKey("ChargeSpell"), { id = spellId, maxCharges = maxCharges })

    ChargeBarLayout:BuildChargeButtons(frame, maxCharges)
    ChargeBarLayout:LayoutChargeBar(self, frame)
    self:UpdateChargeFrame(frame)
    self:UpdateSeedVisibility(frame)
    self:UpdateAllChargeControlColors()
    UpdateChargeBarLabel(frame)
end

function Plugin:ClearChargeFrame(frame)
    frame.chargeSpellId = nil
    frame.cachedMaxCharges = nil
    frame._maxCharges = nil
    frame._trackedCharges = nil
    for _, btn in ipairs(frame.buttons) do
        btn:Hide()
    end
    if frame.RechargeSegment then frame.RechargeSegment:SetValue(0) end
    if frame.TickBar then frame.TickBar:SetValue(0) end
    frame.CountText:SetText("")
    frame.CountText:Hide()

    self:SetSetting(frame.systemIndex, self:GetSpecKey("ChargeSpell"), nil)
    ChargeBarLayout:LayoutChargeBar(self, frame)
    self:ClearStaleChargeBarSpatial(frame, frame.systemIndex)
    self:UpdateSeedVisibility(frame)
    self:UpdateAllChargeControlColors()
    UpdateChargeBarLabel(frame)
end

-- [ CLICK-THROUGH TOGGLE ]-------------------------------------------------------------------------
function Plugin:SetChargeClickEnabled(enabled)
    if self.chargeBarAnchor then
        self.chargeBarAnchor.orbitClickThrough = not enabled
        self.chargeBarAnchor:EnableMouse(enabled)
    end
    for _, childData in pairs(self.activeChargeChildren or {}) do
        if childData.frame then
            childData.frame.orbitClickThrough = not enabled
            childData.frame:EnableMouse(enabled)
        end
    end
end

-- [ SETTINGS APPLICATION ]-------------------------------------------------------------------------
function Plugin:ApplyChargeBarSettings(frame)
    if not frame then
        return
    end
    local sysIndex = frame.systemIndex
    ChargeBarLayout:LayoutChargeBar(self, frame)
    OrbitEngine.Frame:RestorePosition(frame, self, sysIndex)

    local isMountedHidden = Orbit.MountedVisibility:ShouldHide()
    local alpha = isMountedHidden and 0 or ((self:GetSetting(sysIndex, "Opacity") or 100) / 100)
    frame:SetAlpha(alpha)

    local enableHover = self:GetSetting(sysIndex, "ShowOnMouseover") ~= false
    Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, sysIndex, "OutOfCombatFade", enableHover)
end

-- [ UPDATE LOGIC ]---------------------------------------------------------------------------------
function Plugin:UpdateChargeFrame(frame)
    if not frame or not frame.chargeSpellId then
        return
    end
    local chargeInfo = C_Spell.GetSpellCharges(frame.chargeSpellId)
    if not chargeInfo then
        return
    end

    local smoothing = self:GetSetting(frame.systemIndex, "SmoothAnimation") and SMOOTH_ANIM or nil

    for _, btn in ipairs(frame.buttons) do
        btn.Bar:SetValue(chargeInfo.currentCharges, smoothing)
    end
    frame.CountText:SetText(chargeInfo.currentCharges)
    frame.CountText:Show()

    frame.RechargePositioner:SetMinMaxValues(0, chargeInfo.maxCharges)
    frame.RechargePositioner:SetValue(chargeInfo.currentCharges, smoothing)

    local progress = 0
    local alphaVal = 0
    local chargeDurObj = C_Spell.GetSpellChargeDuration(frame.chargeSpellId)
    if chargeDurObj then
        progress = chargeDurObj:EvaluateRemainingPercent(RECHARGE_PROGRESS_CURVE)
        alphaVal = chargeDurObj:EvaluateRemainingPercent(RECHARGE_ALPHA_CURVE)
    end

    frame.RechargeSegment:SetValue(progress)
    frame.TickBar:SetValue(progress)
    frame.RechargeSegment:SetAlpha(alphaVal)
    frame.TickBar:SetAlpha(alphaVal)
end

-- [ TICKER ]----------------------------------------------------------------------------------------
function Plugin:StartChargeUpdateTicker()
    local function DoUpdate()
        local anchor = self.chargeBarAnchor
        if anchor and anchor:IsShown() and anchor.chargeSpellId then
            self:UpdateChargeFrame(anchor)
        end
        for _, childData in pairs(self.activeChargeChildren) do
            local f = childData.frame
            if f and f:IsShown() and f.chargeSpellId then
                self:UpdateChargeFrame(f)
            end
        end
    end

    if not self.chargeUpdateFrame then
        self.chargeUpdateFrame = CreateFrame("Frame")
    end

    local useFrequent = self:GetSetting(CHARGE_BAR_INDEX, "FrequentUpdates") ~= false
    
    if useFrequent then
        if self.chargeUpdateTicker then
            self.chargeUpdateTicker:Cancel()
            self.chargeUpdateTicker = nil
        end
        self.chargeUpdateFrame:SetScript("OnUpdate", DoUpdate)
    else
        self.chargeUpdateFrame:SetScript("OnUpdate", nil)
        if not self.chargeUpdateTicker then
            self.chargeUpdateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, DoUpdate)
        end
    end
end
    
function Plugin:RefreshChargeUpdateMethod()
    self:StartChargeUpdateTicker()
end

-- [ SEED VISIBILITY ]------------------------------------------------------------------------------
function Plugin:UpdateSeedVisibility(frame)
    if InCombatLockdown() or not frame or not frame.SeedButton then
        return
    end

    local hasSpell = frame.chargeSpellId ~= nil
    local cursorSpell = ResolveSpellFromCursor()
    local isDraggingCharge = cursorSpell and IsChargeSpell(cursorSpell) or false
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    frame.DropHighlight:SetShown(hasSpell and isDraggingCharge)

    if hasSpell then
        frame.SeedButton:Hide()
        return
    end

    if isEditMode or isDraggingCharge then
        local plusSize = OrbitEngine.Pixel:Snap(math.min(frame:GetWidth(), frame:GetHeight()) * SEED_PLUS_RATIO)
        frame.SeedButton.Plus:SetSize(plusSize, plusSize)
        frame.SeedButton:Show()
        if isDraggingCharge then
            frame.SeedButton.PulseAnim:Play()
        else
            frame.SeedButton.PulseAnim:Stop()
            frame.SeedButton.Glow:SetAlpha(SEED_GLOW_ALPHA)
        end
    else
        frame.SeedButton:Hide()
    end
end

function Plugin:UpdateAllSeedVisibility()
    self:UpdateSeedVisibility(self.chargeBarAnchor)
    for _, childData in pairs(self.activeChargeChildren) do
        if childData.frame then
            self:UpdateSeedVisibility(childData.frame)
        end
    end
end

-- [ CURSOR WATCHER ]-------------------------------------------------------------------------------
function Plugin:RegisterChargeCursorWatcher()
    local lastCursor, lastEditMode

    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function()
        local cursorType = GetCursorInfo()
        local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
        if cursorType == lastCursor and isEditMode == lastEditMode then
            return
        end
        lastCursor = cursorType
        lastEditMode = isEditMode
        self:UpdateAllSeedVisibility()
        self:RefreshAllChargeControlVisibility()
    end)
end

-- [ SPEC CHANGE ]----------------------------------------------------------------------------------
function Plugin:ReloadChargeBarsForSpec()
    local anchor = self.chargeBarAnchor
    if anchor then
        anchor.chargeSpellId = nil
        anchor.cachedMaxCharges = nil
        anchor._maxCharges = nil
        for _, btn in ipairs(anchor.buttons) do
            btn:Hide()
        end
        if anchor.RechargeSegment then anchor.RechargeSegment:SetValue(0) end
        if anchor.TickBar then anchor.TickBar:SetValue(0) end
    end

    for key, childData in pairs(self.activeChargeChildren) do
        if childData.frame then
            childData.frame:Hide()
            childData.frame:ClearAllPoints()
            childData.frame.chargeSpellId = nil
            childData.frame.cachedMaxCharges = nil
            childData.frame._maxCharges = nil
            for _, btn in ipairs(childData.frame.buttons) do
                btn:Hide()
            end
            if childData.frame.RechargeSegment then childData.frame.RechargeSegment:SetValue(0) end
            if childData.frame.TickBar then childData.frame.TickBar:SetValue(0) end
            table.insert(self.chargeChildPool, childData.frame)
        end
    end
    self.activeChargeChildren = {}

    self:RestoreChargeSpell(anchor, CHARGE_BAR_INDEX)
    self:ClearStaleChargeBarSpatial(anchor, CHARGE_BAR_INDEX)

    local savedChildren = self:GetSetting(CHARGE_BAR_INDEX, self:GetSpecKey("ChargeChildren")) or {}
    for slot, sysIndex in pairs(savedChildren) do
        local frame = self:SpawnChargeChild()
        if frame then
            self:RestoreChargeSpell(frame, sysIndex)
            self:ClearStaleChargeBarSpatial(frame, sysIndex)
        end
    end

    ChargeBarLayout:LayoutChargeBars(self)
end

function Plugin:RestoreChargeSpell(frame, sysIndex)
    if not frame then
        return
    end
    local data = self:GetSetting(sysIndex, self:GetSpecKey("ChargeSpell"))
    if not data or not data.id then
        return
    end

    local isCharge, ci = IsChargeSpell(data.id)
    if isCharge then
        data.maxCharges = math.max(data.maxCharges or 0, ci.maxCharges)
    end

    frame.chargeSpellId = data.id
    frame.cachedMaxCharges = data.maxCharges or 2
    frame._maxCharges = data.maxCharges or 2
    frame._trackedCharges = ci and ci.currentCharges or frame.cachedMaxCharges
    frame._knownRechargeDuration = ci and ci.cooldownDuration or nil
    ChargeBarLayout:BuildChargeButtons(frame, frame.cachedMaxCharges)
    UpdateChargeBarLabel(frame)
end

function Plugin:RefreshChargeMaxCharges()
    local function Refresh(frame)
        if not frame or not frame.chargeSpellId then
            return
        end
        local ci = C_Spell.GetSpellCharges(frame.chargeSpellId)
        if not ci or not ci.maxCharges or issecretvalue(ci.maxCharges) or ci.maxCharges < 2 then
            return
        end
        if ci.maxCharges == frame.cachedMaxCharges then
            return
        end
        frame.cachedMaxCharges = ci.maxCharges
        frame._maxCharges = ci.maxCharges
        self:SetSetting(frame.systemIndex, self:GetSpecKey("ChargeSpell"), { id = frame.chargeSpellId, maxCharges = ci.maxCharges })
        ChargeBarLayout:BuildChargeButtons(frame, ci.maxCharges)
        ChargeBarLayout:LayoutChargeBar(self, frame)
    end
    Refresh(self.chargeBarAnchor)
    for _, childData in pairs(self.activeChargeChildren) do
        Refresh(childData.frame)
    end
end

function Plugin:ClearStaleChargeBarSpatial(frame, sysIndex)
    if not frame or frame.chargeSpellId then
        return
    end
    self:SetSetting(sysIndex, "Anchor", nil)
    self:SetSetting(sysIndex, "Position", nil)
    OrbitEngine.FrameAnchor:BreakAnchor(frame, true)
    for _, child in ipairs(OrbitEngine.FrameAnchor:GetAnchoredChildren(frame)) do
        OrbitEngine.FrameAnchor:BreakAnchor(child, true)
        if child.orbitPlugin and child.systemIndex then
            child.orbitPlugin:SetSetting(child.systemIndex, "Anchor", nil)
        end
    end
end

-- [ RESTORE / INIT ]-------------------------------------------------------------------------------
function Plugin:RestoreChargeBars()
    local anchor = self:CreateChargeBarFrame("OrbitChargeBarAnchor", CHARGE_BAR_INDEX, "Charge Bar 1")
    self.chargeBarAnchor = anchor

    local viewerMap = self.viewerMap
    if viewerMap then
        viewerMap[CHARGE_BAR_INDEX] = { anchor = anchor, isChargeBar = true }
    end

    self:RestoreChargeSpell(anchor, CHARGE_BAR_INDEX)
    self:ClearStaleChargeBarSpatial(anchor, CHARGE_BAR_INDEX)

    local savedChildren = self:GetSetting(CHARGE_BAR_INDEX, self:GetSpecKey("ChargeChildren")) or {}
    for slot, sysIndex in pairs(savedChildren) do
        local frame = self:SpawnChargeChild()
        if frame then
            self:RestoreChargeSpell(frame, sysIndex)
            self:ClearStaleChargeBarSpatial(frame, sysIndex)
        end
    end

    self:CreateChargeControlButtons(anchor)
    ChargeBarCanvasPreview:Setup(self, anchor, CHARGE_BAR_INDEX)
    ChargeBarLayout:LayoutChargeBars(self)
    OrbitEngine.Frame:RestorePosition(anchor, self, CHARGE_BAR_INDEX)
    self:RegisterChargeCursorWatcher()
    self:RegisterChargeRechargeWatcher()
    self:StartChargeUpdateTicker()
end

-- [ RECHARGE WATCHER ]------------------------------------------------------------------------------
function Plugin:RegisterChargeRechargeWatcher()
    if self._chargeRechargeWatcherSetup then
        return
    end
    self._chargeRechargeWatcherSetup = true
    local plugin = self
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:SetScript("OnEvent", function(_, event, unit, _, spellId)
        if event == "SPELLS_CHANGED" then
            plugin:RefreshChargeMaxCharges()
            plugin:LayoutChargeBars()
            return
        end
        if unit ~= "player" then
            return
        end
        local function HandleCast(chargeFrame)
            if not chargeFrame or chargeFrame.chargeSpellId ~= spellId then
                return
            end
            CooldownUtils:OnChargeCast(chargeFrame)
        end
        HandleCast(plugin.chargeBarAnchor)
        for _, childData in pairs(plugin.activeChargeChildren) do
            HandleCast(childData.frame)
        end
    end)
end
