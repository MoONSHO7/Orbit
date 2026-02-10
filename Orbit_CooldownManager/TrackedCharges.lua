---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local CHARGE_BAR_INDEX = Constants.Cooldown.SystemIndex.ChargeBar
local CHARGE_CHILD_START = Constants.Cooldown.SystemIndex.ChargeBar_ChildStart
local MAX_CHARGE_CHILDREN = Constants.Cooldown.MaxChargeBarChildren
local UPDATE_INTERVAL = 0.016
local DEFAULT_WIDTH = 120
local DEFAULT_HEIGHT = 12
local DEFAULT_Y_OFFSET = -280
local EMPTY_SEED_SIZE = 40
local DROP_HIGHLIGHT_COLOR = { r = 0.3, g = 0.8, b = 0.3, a = 0.3 }
local COLOR_GREEN = { r = 0.2, g = 0.9, b = 0.2 }
local COLOR_RED = { r = 0.9, g = 0.2, b = 0.2 }
local COLOR_BABY_BLUE = { r = 0.4, g = 0.7, b = 1.0 }
local CHARGE_ADD_ICON = "Interface\\PaperDollInfoFrame\\Character-Plus"
local CHARGE_REMOVE_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local CONTROL_BTN_SIZE = 10
local CONTROL_BTN_SPACING = 1
local RECHARGE_DIM = 0.35
local DEFAULT_SPACING = 0
local SEED_PLUS_RATIO = 0.4

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
    if OrbitEngine.Pixel then
        return OrbitEngine.Pixel:Snap(value, scale)
    end
    return math.floor(value * scale + 0.5) / scale
end

local function IsChargeSpell(spellId)
    if not spellId or not C_Spell.GetSpellCharges then
        return false, nil
    end
    local ci = C_Spell.GetSpellCharges(spellId)
    return ci and ci.maxCharges and ci.maxCharges > 1, ci
end

local function GetBarColor(plugin, sysIndex, index, maxCharges)
    local curveData = plugin:GetSetting(sysIndex, "BarColorCurve")
    if curveData and OrbitEngine.WidgetLogic then
        if index and maxCharges and maxCharges > 1 and #curveData.pins > 1 then
            return OrbitEngine.WidgetLogic:SampleColorCurve(curveData, (index - 1) / (maxCharges - 1))
        end
        local c = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData)
        if c then
            return c
        end
    end
    local _, class = UnitClass("player")
    return (Orbit.Colors.PlayerResources and Orbit.Colors.PlayerResources[class]) or { r = 1, g = 0.8, b = 0 }
end

local function GetBgColor()
    local gc = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BackdropColourCurve
    local c = gc and OrbitEngine.WidgetLogic and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(gc)
    return c or { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }
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
    if OrbitEngine.Pixel then
        OrbitEngine.Pixel:Enforce(frame)
    end
    frame:SetSize(EMPTY_SEED_SIZE, EMPTY_SEED_SIZE)
    frame:SetClampedToScreen(true)

    -- Orbit metadata (matches FrameFactory pattern)
    frame.systemIndex = systemIndex
    frame.editModeName = label
    frame.isChargeBar = true
    frame.orbitPlugin = self
    frame.orbitName = "Orbit_CooldownViewer"
    frame:EnableMouse(true)
    frame.anchorOptions = { horizontal = false, vertical = true, mergeBorders = true }

    -- Default position for restoration waterfall fallback
    frame.defaultPosition = { point = "CENTER", relativeTo = UIParent, relativePoint = "CENTER", x = 30, y = 0 }
    frame:SetPoint("CENTER", UIParent, "CENTER", 30, 0)

    OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)
    frame.buttons = {}

    -- Border hiding support for mergeBorders (propagate to child button backdrops)
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
            plugin:LayoutChargeBar(frame)
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

    -- Seed button (baby blue glow + plus icon for empty state)
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

    -- Overlay frame for count text (renders above button borders)
    frame.TextOverlay = CreateFrame("Frame", nil, frame)
    frame.TextOverlay:SetAllPoints()
    frame.TextOverlay:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.CountText = frame.TextOverlay:CreateFontString(nil, "OVERLAY")
    frame.CountText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    frame.CountText:SetPoint("CENTER", frame, "CENTER", 0, 0)

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
    local controlContainer = CreateFrame("Frame", nil, anchor)
    controlContainer:SetSize(CONTROL_BTN_SIZE, (CONTROL_BTN_SIZE * 2) + CONTROL_BTN_SPACING)
    controlContainer:SetPoint("LEFT", anchor, "TOPRIGHT", 2, -((CONTROL_BTN_SIZE * 2 + CONTROL_BTN_SPACING) / 2))
    anchor.controlContainer = controlContainer

    local plusBtn = CreateFrame("Button", nil, controlContainer)
    plusBtn:SetSize(CONTROL_BTN_SIZE, CONTROL_BTN_SIZE)
    plusBtn:SetPoint("TOP", controlContainer, "TOP", 0, 0)
    plusBtn.Icon = plusBtn:CreateTexture(nil, "ARTWORK")
    plusBtn.Icon:SetAllPoints()
    plusBtn.Icon:SetTexture(CHARGE_ADD_ICON)
    plusBtn.Icon:SetVertexColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
    plusBtn.Icon:SetAlpha(0.8)
    plusBtn:SetScript("OnClick", function()
        if not InCombatLockdown() then
            plugin:SpawnChargeChild()
        end
    end)
    plusBtn:SetScript("OnEnter", function(self)
        self.Icon:SetAlpha(1)
    end)
    plusBtn:SetScript("OnLeave", function(self)
        self.Icon:SetAlpha(0.8)
    end)
    anchor.plusBtn = plusBtn

    local minusBtn = CreateFrame("Button", nil, controlContainer)
    minusBtn:SetSize(CONTROL_BTN_SIZE, CONTROL_BTN_SIZE)
    minusBtn:SetPoint("TOP", plusBtn, "BOTTOM", 0, -CONTROL_BTN_SPACING)
    minusBtn.Icon = minusBtn:CreateTexture(nil, "ARTWORK")
    minusBtn.Icon:SetAllPoints()
    minusBtn.Icon:SetTexture(CHARGE_REMOVE_ICON)
    minusBtn.Icon:SetVertexColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
    minusBtn.Icon:SetAlpha(0.8)
    minusBtn:SetScript("OnClick", function()
        if InCombatLockdown() then
            return
        end
        if anchor.isChildChargeBar then
            plugin:DespawnChargeChild(anchor)
        end
    end)
    minusBtn:SetScript("OnEnter", function(self)
        self.Icon:SetAlpha(1)
    end)
    minusBtn:SetScript("OnLeave", function(self)
        self.Icon:SetAlpha(0.8)
    end)
    anchor.minusBtn = minusBtn

    self:UpdateChargeControlVisibility(anchor)
    self:UpdateAllChargeControlColors()
end

function Plugin:UpdateChargeControlVisibility(anchor)
    if not anchor or not anchor.controlContainer then
        return
    end
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    if isEditMode then
        anchor.controlContainer:Show()
        anchor.minusBtn:SetShown(anchor.isChildChargeBar == true)
    else
        anchor.controlContainer:Hide()
    end
end

function Plugin:RefreshAllChargeControlVisibility()
    self:UpdateChargeControlVisibility(self.chargeBarAnchor)
    for _, childData in pairs(self.activeChargeChildren) do
        if childData.frame then
            self:UpdateChargeControlVisibility(childData.frame)
        end
    end
end

function Plugin:UpdateAllChargeControlColors()
    local count = 0
    for _ in pairs(self.activeChargeChildren) do
        count = count + 1
    end
    local atMax = count >= MAX_CHARGE_CHILDREN
    local c = atMax and COLOR_RED or COLOR_GREEN

    local anchor = self.chargeBarAnchor
    if anchor and anchor.plusBtn then
        anchor.plusBtn.Icon:SetVertexColor(c.r, c.g, c.b)
        anchor.plusBtn:SetEnabled(not atMax)
    end
    for _, childData in pairs(self.activeChargeChildren) do
        if childData.frame and childData.frame.plusBtn then
            childData.frame.plusBtn.Icon:SetVertexColor(c.r, c.g, c.b)
            childData.frame.plusBtn:SetEnabled(not atMax)
        end
    end
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
    self:LayoutChargeBar(frame)
    self:SetupChargeBarCanvasPreview(frame, systemIndex)
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
    for _, btn in ipairs(frame.buttons) do
        btn:Hide()
    end

    -- Clear persisted spatial data to prevent stale anchors/positions on restore
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

-- [ BUTTON BUILDING ]------------------------------------------------------------------------------
function Plugin:BuildChargeButtons(frame, maxCharges)
    for i = 1, maxCharges do
        if not frame.buttons[i] then
            local btn = CreateFrame("Frame", nil, frame)
            if OrbitEngine.Pixel then
                OrbitEngine.Pixel:Enforce(btn)
            end
            btn.RechargeBar = CreateFrame("StatusBar", nil, btn)
            btn.RechargeBar:SetAllPoints()
            btn.RechargeBar:SetMinMaxValues(0, 1)
            btn.RechargeBar:SetValue(0)
            btn.RechargeBar:SetFrameLevel(btn:GetFrameLevel() + 1)
            btn.Bar = CreateFrame("StatusBar", nil, btn)
            btn.Bar:SetAllPoints()
            btn.Bar:SetMinMaxValues(i - 1, i)
            btn.Bar:SetValue(0)
            btn.Bar:SetFrameLevel(btn:GetFrameLevel() + 2)
            frame.buttons[i] = btn
        end
        frame.buttons[i].Bar:SetMinMaxValues(i - 1, i)
        frame.buttons[i]:Show()
    end
    for i = maxCharges + 1, #frame.buttons do
        frame.buttons[i]:Hide()
    end
end

-- [ LAYOUT ]----------------------------------------------------------------------------------------
function Plugin:LayoutChargeBar(frame)
    if not frame then
        return
    end
    if frame._layoutInProgress then
        return
    end
    frame._layoutInProgress = true

    local sysIndex = frame.systemIndex
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(frame) ~= nil

    if frame.chargeSpellId then
        local width = self:GetSetting(sysIndex, "Width") or DEFAULT_WIDTH
        local height = self:GetSetting(sysIndex, "Height") or DEFAULT_HEIGHT
        if not isAnchored then
            frame:SetWidth(width)
        end
        width = frame:GetWidth()
        frame:SetHeight(height)

        local borderSize = self:GetSetting(sysIndex, "BorderSize") or 1
        local spacing = self:GetSetting(sysIndex, "Spacing") or DEFAULT_SPACING
        local texture = self:GetSetting(sysIndex, "Texture")
        local scale = frame:GetEffectiveScale() or 1
        local maxCharges = frame.cachedMaxCharges or 2
        local bgColor = GetBgColor()

        self:SkinChargeButtons(frame, maxCharges, width, height, borderSize, spacing, texture, sysIndex, bgColor, scale)
        if frame.SeedButton then
            frame.SeedButton:Hide()
        end
    else
        frame:SetSize(EMPTY_SEED_SIZE, EMPTY_SEED_SIZE)
    end

    frame._layoutInProgress = false
    if OrbitEngine.Frame.ForceUpdateSelection then
        OrbitEngine.Frame:ForceUpdateSelection(frame)
    end
    frame:Show()
end

function Plugin:LayoutChargeBars()
    self:LayoutChargeBar(self.chargeBarAnchor)
    for _, childData in pairs(self.activeChargeChildren) do
        if childData.frame then
            self:LayoutChargeBar(childData.frame)
        end
    end
end

function Plugin:SkinChargeButtons(frame, maxCharges, totalWidth, height, borderSize, spacing, texture, sysIndex, bgColor, scale)
    local snappedGap = SnapToPixel(spacing - 1, scale)
    local totalSpacing = (maxCharges - 1) * snappedGap
    local usableWidth = totalWidth - totalSpacing
    local btnWidth = SnapToPixel(usableWidth / maxCharges, scale)
    local globalSettings = Orbit.db.GlobalSettings or {}

    for i = 1, maxCharges do
        local btn = frame.buttons[i]
        if not btn then
            break
        end

        local leftPos = SnapToPixel((i - 1) * (btnWidth + snappedGap), scale)
        local actualWidth = (i == maxCharges) and (totalWidth - leftPos) or btnWidth

        btn:SetSize(actualWidth, height)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", frame, "LEFT", leftPos, 0)

        if not btn.bg then
            btn.bg = btn:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers and Constants.Layers.BackdropDeep or -8)
            btn.bg:SetAllPoints()
        end
        Orbit.Skin:ApplyGradientBackground(btn, globalSettings.BackdropColourCurve, bgColor)

        local barColor = GetBarColor(self, sysIndex, i, maxCharges)
        if Orbit.Skin then
            Orbit.Skin:SkinStatusBar(btn.Bar, texture, barColor)
            if btn.Bar.Overlay then
                btn.Bar.Overlay:Hide()
            end
            local rechargeColor = { r = barColor.r * RECHARGE_DIM, g = barColor.g * RECHARGE_DIM, b = barColor.b * RECHARGE_DIM }
            Orbit.Skin:SkinStatusBar(btn.RechargeBar, texture, rechargeColor)
            if btn.RechargeBar.Overlay then
                btn.RechargeBar.Overlay:Hide()
            end
        end

        if not btn.orbitBackdrop then
            btn.orbitBackdrop = Orbit.Skin:CreateBackdrop(btn, nil)
            btn.orbitBackdrop:SetFrameLevel(btn:GetFrameLevel() + (Constants.Levels and Constants.Levels.Highlight or 5))
            if btn.orbitBackdrop.SetBackdrop then
                btn.orbitBackdrop:SetBackdrop(nil)
            end
        end
        Orbit.Skin:SkinBorder(btn, btn.orbitBackdrop, borderSize, { r = 0, g = 0, b = 0, a = 1 })

        if OrbitEngine.Pixel then
            OrbitEngine.Pixel:Enforce(btn)
        end
    end

    -- Apply ChargeCount position and font overrides
    local sysIndex = frame.systemIndex
    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
    local positions = self:GetSetting(sysIndex, "ComponentPositions") or {}
    local pos = positions["ChargeCount"] or {}
    local overrides = pos.overrides or {}
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local fontName = self:GetSetting(sysIndex, "Font")
    local fontPath = LSM and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)
    OrbitEngine.OverrideUtils.ApplyOverrides(frame.CountText, overrides, { fontSize = textSize, fontPath = fontPath })
    if ApplyTextPosition then
        ApplyTextPosition(frame.CountText, frame, pos)
    end
end

-- [ CANVAS PREVIEW ]--------------------------------------------------------------------------------
function Plugin:SetupChargeBarCanvasPreview(frame, sysIndex)
    local plugin = self
    local LSM = LibStub("LibSharedMedia-3.0", true)

    frame.CreateCanvasPreview = function(self, options)
        local width = plugin:GetSetting(sysIndex, "Width") or DEFAULT_WIDTH
        local height = plugin:GetSetting(sysIndex, "Height") or DEFAULT_HEIGHT
        local borderSize = plugin:GetSetting(sysIndex, "BorderSize") or 1
        local spacing = plugin:GetSetting(sysIndex, "Spacing") or DEFAULT_SPACING
        local texture = plugin:GetSetting(sysIndex, "Texture")
        local bgColor = GetBgColor()
        local maxCharges = self.cachedMaxCharges or 3
        local previewCharges = maxCharges - 1
        local scale = self:GetEffectiveScale() or 1

        local parent = options.parent or UIParent
        local preview = CreateFrame("Frame", nil, parent)
        preview:SetSize(width, height)
        preview.sourceFrame = self
        preview.sourceWidth = width
        preview.sourceHeight = height
        preview.previewScale = 1
        preview.components = {}

        local snappedGap = SnapToPixel(spacing - 1, scale)
        local totalSpacing = (maxCharges - 1) * snappedGap
        local usableWidth = width - totalSpacing
        local btnWidth = SnapToPixel(usableWidth / maxCharges, scale)

        for i = 1, maxCharges do
            local leftPos = SnapToPixel((i - 1) * (btnWidth + snappedGap), scale)
            local actualWidth = (i == maxCharges) and (width - leftPos) or btnWidth

            local seg = CreateFrame("StatusBar", nil, preview)
            seg:SetSize(actualWidth, height)
            seg:SetPoint("LEFT", preview, "LEFT", leftPos, 0)
            seg:SetMinMaxValues(0, 1)
            seg:SetValue(1)

            seg.bg = seg:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers and Constants.Layers.BackdropDeep or -8)
            seg.bg:SetAllPoints()
            local gs = Orbit.db.GlobalSettings or {}
            Orbit.Skin:ApplyGradientBackground(seg, gs.BackdropColourCurve, bgColor)

            local barColor = GetBarColor(plugin, sysIndex, i, maxCharges)
            local segColor = (i <= previewCharges) and barColor
                or { r = barColor.r * RECHARGE_DIM, g = barColor.g * RECHARGE_DIM, b = barColor.b * RECHARGE_DIM }
            if Orbit.Skin then
                Orbit.Skin:SkinStatusBar(seg, texture, segColor)
                if seg.Overlay then
                    seg.Overlay:Hide()
                end
            end

            local segBackdrop = Orbit.Skin:CreateBackdrop(seg, nil)
            segBackdrop:SetFrameLevel(seg:GetFrameLevel() + (Constants.Levels and Constants.Levels.Highlight or 5))
            if segBackdrop.SetBackdrop then
                segBackdrop:SetBackdrop(nil)
            end
            Orbit.Skin:SkinBorder(seg, segBackdrop, borderSize, { r = 0, g = 0, b = 0, a = 1 })
        end

        local savedPositions = plugin:GetSetting(sysIndex, "ComponentPositions") or {}
        local fontName = plugin:GetSetting(sysIndex, "Font")
        local fontPath = LSM and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
        local fontSize = Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)
        local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7)
        fs:SetFont(fontPath, fontSize, Orbit.Skin:GetFontOutline())
        fs:SetText(tostring(previewCharges))
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

        local saved = savedPositions["ChargeCount"] or {}
        local data = {
            anchorX = saved.anchorX or "CENTER",
            anchorY = saved.anchorY or "CENTER",
            offsetX = saved.offsetX or 0,
            offsetY = saved.offsetY or 0,
            justifyH = saved.justifyH or "CENTER",
            overrides = saved.overrides,
        }

        local startX = saved.posX or 0
        local startY = saved.posY or 0

        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
        if CreateDraggableComponent then
            local comp = CreateDraggableComponent(preview, "ChargeCount", fs, startX, startY, data)
            if comp then
                comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                preview.components["ChargeCount"] = comp
                fs:Hide()
            end
        else
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
        end

        return preview
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

    -- Cache recharge state from non-secret chargeInfo (assignment happens out of combat)
    local ci = C_Spell.GetSpellCharges(spellId)
    frame._rechargeDuration = ci and ci.cooldownDuration or nil
    frame._rechargeStart = nil
    frame._trackedCharges = ci and ci.currentCharges or maxCharges

    self:SetSetting(frame.systemIndex, self:GetSpecKey("ChargeSpell"), { id = spellId, maxCharges = maxCharges })

    self:BuildChargeButtons(frame, maxCharges)
    self:LayoutChargeBar(frame)
    self:UpdateChargeFrame(frame)
    self:UpdateSeedVisibility(frame)
    self:UpdateAllChargeControlColors()
    UpdateChargeBarLabel(frame)
end

function Plugin:ClearChargeFrame(frame)
    frame.chargeSpellId = nil
    frame.cachedMaxCharges = nil
    frame._rechargeDuration = nil
    frame._rechargeStart = nil
    frame._trackedCharges = nil
    for _, btn in ipairs(frame.buttons) do
        btn:Hide()
    end
    frame.CountText:SetText("")
    frame.CountText:Hide()

    self:SetSetting(frame.systemIndex, self:GetSpecKey("ChargeSpell"), nil)
    self:LayoutChargeBar(frame)
    self:ClearStaleChargeBarSpatial(frame, frame.systemIndex)
    self:UpdateSeedVisibility(frame)
    self:UpdateAllChargeControlColors()
    UpdateChargeBarLabel(frame)
end

-- [ SETTINGS APPLICATION ]-------------------------------------------------------------------------
function Plugin:ApplyChargeBarSettings(frame)
    if not frame then
        return
    end
    local sysIndex = frame.systemIndex

    self:LayoutChargeBar(frame)
    OrbitEngine.Frame:RestorePosition(frame, self, sysIndex)

    -- Opacity
    local alpha = (self:GetSetting(sysIndex, "Opacity") or 100) / 100
    frame:SetAlpha(alpha)

    -- Out of Combat Fade
    if Orbit.OOCFadeMixin then
        local enableHover = self:GetSetting(sysIndex, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, sysIndex, "OutOfCombatFade", enableHover)
    end
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

    for _, btn in ipairs(frame.buttons) do
        btn.Bar:SetValue(chargeInfo.currentCharges)
    end
    frame.CountText:SetText(chargeInfo.currentCharges)
    frame.CountText:Show()

    -- Sync tracked charges from API when non-secret (out of combat)
    if not issecretvalue(chargeInfo.currentCharges) then
        frame._trackedCharges = chargeInfo.currentCharges
        if chargeInfo.cooldownStartTime == 0 then
            frame._rechargeStart = nil
        elseif not frame._rechargeStart then
            frame._rechargeStart = chargeInfo.cooldownStartTime
        end
    end

    -- Recharge fill: self-tracked timing, single segment only
    local progress = 0
    local rechargeIdx = (frame._trackedCharges or frame.cachedMaxCharges) + 1
    if frame._rechargeStart and frame._rechargeDuration and frame._rechargeDuration > 0 then
        local elapsed = GetTime() - frame._rechargeStart
        progress = math.min(1, elapsed / frame._rechargeDuration)
        if progress >= 1 then
            frame._trackedCharges = math.min((frame._trackedCharges or 0) + 1, frame.cachedMaxCharges)
            rechargeIdx = frame._trackedCharges + 1
            if frame._trackedCharges < frame.cachedMaxCharges then
                frame._rechargeStart = GetTime()
                progress = 0
            else
                frame._rechargeStart = nil
                progress = 0
            end
        end
    end
    for i, btn in ipairs(frame.buttons) do
        if btn.RechargeBar then
            btn.RechargeBar:SetValue((i == rechargeIdx) and progress or 0)
        end
    end
end

-- [ TICKER ]----------------------------------------------------------------------------------------
function Plugin:StartChargeUpdateTicker()
    if self.chargeUpdateTicker then
        return
    end
    self.chargeUpdateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
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
    end)
end

-- [ SEED VISIBILITY ]------------------------------------------------------------------------------
function Plugin:UpdateSeedVisibility(frame)
    if not frame or not frame.SeedButton then
        return
    end

    local hasSpell = frame.chargeSpellId ~= nil

    local isDraggingCharge = false
    local spellId = ResolveSpellFromCursor()
    if spellId then
        isDraggingCharge = IsChargeSpell(spellId)
    end

    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    if frame.DropHighlight then
        frame.DropHighlight:SetShown(hasSpell and isDraggingCharge)
    end

    if hasSpell then
        frame.SeedButton:Hide()
        return
    end

    if isEditMode or isDraggingCharge then
        local w, h = frame:GetWidth(), frame:GetHeight()
        local plusSize = math.min(w, h) * SEED_PLUS_RATIO
        if OrbitEngine.Pixel then
            plusSize = OrbitEngine.Pixel:Snap(plusSize)
        end
        frame.SeedButton.Plus:SetSize(plusSize, plusSize)
        frame.SeedButton:Show()
        if isDraggingCharge then
            frame.SeedButton.PulseAnim:Play()
        else
            frame.SeedButton.PulseAnim:Stop()
            frame.SeedButton.Glow:SetAlpha(0.6)
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
    local lastCursor = nil
    local lastEditMode = nil

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
    -- Clear parent
    local anchor = self.chargeBarAnchor
    if anchor then
        anchor.chargeSpellId = nil
        anchor.cachedMaxCharges = nil
        for _, btn in ipairs(anchor.buttons) do
            btn:Hide()
        end
    end

    -- Clear children
    for key, childData in pairs(self.activeChargeChildren) do
        if childData.frame then
            childData.frame:Hide()
            childData.frame:ClearAllPoints()
            childData.frame.chargeSpellId = nil
            childData.frame.cachedMaxCharges = nil
            for _, btn in ipairs(childData.frame.buttons) do
                btn:Hide()
            end
            table.insert(self.chargeChildPool, childData.frame)
        end
    end
    self.activeChargeChildren = {}

    -- Restore parent spell
    self:RestoreChargeSpell(anchor, CHARGE_BAR_INDEX)
    self:ClearStaleChargeBarSpatial(anchor, CHARGE_BAR_INDEX)

    -- Restore children
    local savedChildren = self:GetSetting(CHARGE_BAR_INDEX, self:GetSpecKey("ChargeChildren")) or {}
    for slot, sysIndex in pairs(savedChildren) do
        local frame = self:SpawnChargeChild()
        if frame then
            self:RestoreChargeSpell(frame, sysIndex)
            self:ClearStaleChargeBarSpatial(frame, sysIndex)
        end
    end

    self:LayoutChargeBars()
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
        data.maxCharges = ci.maxCharges
    end

    frame.chargeSpellId = data.id
    frame.cachedMaxCharges = data.maxCharges or 2
    frame._rechargeDuration = ci and ci.cooldownDuration or nil
    frame._rechargeStart = nil
    frame._trackedCharges = ci and ci.currentCharges or frame.cachedMaxCharges
    if ci and ci.cooldownStartTime and not issecretvalue(ci.cooldownStartTime) and ci.cooldownStartTime > 0 then
        frame._rechargeStart = ci.cooldownStartTime
    end
    self:BuildChargeButtons(frame, frame.cachedMaxCharges)
    UpdateChargeBarLabel(frame)
end

-- Clear stale anchor/position data from a charge bar with no spell assigned.
-- Handles both directions: outbound (this bar anchored to X) and inbound (X anchored to this bar).
function Plugin:ClearStaleChargeBarSpatial(frame, sysIndex)
    if not frame or frame.chargeSpellId then
        return
    end
    self:SetSetting(sysIndex, "Anchor", nil)
    self:SetSetting(sysIndex, "Position", nil)
    if OrbitEngine.FrameAnchor then
        OrbitEngine.FrameAnchor:BreakAnchor(frame, true)
        for _, child in ipairs(OrbitEngine.FrameAnchor:GetAnchoredChildren(frame)) do
            OrbitEngine.FrameAnchor:BreakAnchor(child, true)
            if child.orbitPlugin and child.systemIndex then
                child.orbitPlugin:SetSetting(child.systemIndex, "Anchor", nil)
            end
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

    -- Restore saved children
    local savedChildren = self:GetSetting(CHARGE_BAR_INDEX, self:GetSpecKey("ChargeChildren")) or {}
    for slot, sysIndex in pairs(savedChildren) do
        local frame = self:SpawnChargeChild()
        if frame then
            self:RestoreChargeSpell(frame, sysIndex)
            self:ClearStaleChargeBarSpatial(frame, sysIndex)
        end
    end

    self:CreateChargeControlButtons(anchor)
    self:SetupChargeBarCanvasPreview(anchor, CHARGE_BAR_INDEX)
    self:LayoutChargeBars()
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
    frame:SetScript("OnEvent", function(_, _, unit, _, spellId)
        if unit ~= "player" then
            return
        end
        local function HandleCast(chargeFrame)
            if not chargeFrame or chargeFrame.chargeSpellId ~= spellId then
                return
            end
            if not chargeFrame._trackedCharges or chargeFrame._trackedCharges <= 0 then
                return
            end
            chargeFrame._trackedCharges = chargeFrame._trackedCharges - 1
            if not chargeFrame._rechargeStart then
                chargeFrame._rechargeStart = GetTime()
            end
        end
        HandleCast(plugin.chargeBarAnchor)
        for _, childData in pairs(plugin.activeChargeChildren) do
            HandleCast(childData.frame)
        end
    end)
end
