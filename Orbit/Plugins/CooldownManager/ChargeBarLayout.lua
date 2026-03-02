---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local DEFAULT_WIDTH = 120
local DEFAULT_HEIGHT = 12
local EMPTY_SEED_SIZE = 40
local DEFAULT_SPACING = 0
local RECHARGE_DIM = 0.35
local TICK_SIZE_DEFAULT = OrbitEngine.TickMixin.TICK_SIZE_DEFAULT

-- [ HELPERS ]---------------------------------------------------------------------------------------
local function SnapToPixel(value, scale) return OrbitEngine.Pixel:Snap(value, scale) end
local function PixelMultiple(count, scale) return OrbitEngine.Pixel:Multiple(count, scale) end

local function GetBarColor(plugin, sysIndex, index, maxCharges)
    local curveData = plugin:GetSetting(sysIndex, "BarColorCurve")
    if curveData then
        if index and maxCharges and maxCharges > 1 and #curveData.pins > 1 then
            return OrbitEngine.ColorCurve:SampleColorCurve(curveData, (index - 1) / (maxCharges - 1))
        end
        local c = OrbitEngine.ColorCurve:GetFirstColorFromCurve(curveData)
        if c then return c end
    end
    local _, class = UnitClass("player")
    return (Orbit.Colors.PlayerResources and Orbit.Colors.PlayerResources[class]) or { r = 1, g = 0.8, b = 0 }
end

local function GetBgColor()
    local gc = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BackdropColourCurve
    local c = gc and OrbitEngine.ColorCurve:GetFirstColorFromCurve(gc)
    return c or { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }
end

-- [ MODULE ]----------------------------------------------------------------------------------------
Orbit.ChargeBarLayout = {}
local Layout = Orbit.ChargeBarLayout

-- [ BUTTON BUILDING ]------------------------------------------------------------------------------
function Layout:BuildChargeButtons(frame, maxCharges)
    for i = 1, maxCharges do
        if not frame.buttons[i] then
            local btn = CreateFrame("Frame", nil, frame)
            OrbitEngine.Pixel:Enforce(btn)
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
function Layout:LayoutChargeBar(plugin, frame)
    if not frame then return end
    if frame._layoutInProgress then return end
    frame._layoutInProgress = true

    local sysIndex = frame.systemIndex
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(frame) ~= nil

    if frame.chargeSpellId then
        local width = plugin:GetSetting(sysIndex, "Width") or DEFAULT_WIDTH
        local height = plugin:GetSetting(sysIndex, "Height") or DEFAULT_HEIGHT
        if not isAnchored then frame:SetWidth(width) end
        width = frame:GetWidth()
        frame:SetHeight(height)

        local borderSize = plugin:GetSetting(sysIndex, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(frame:GetEffectiveScale() or 1)
        local spacing = plugin:GetSetting(sysIndex, "Spacing") or DEFAULT_SPACING
        local texture = plugin:GetSetting(sysIndex, "Texture")
        local scale = frame:GetEffectiveScale()
        local maxCharges = frame.cachedMaxCharges or 2
        local bgColor = GetBgColor()

        self:SkinChargeButtons(plugin, frame, maxCharges, width, height, borderSize, spacing, texture, sysIndex, bgColor, scale)
        frame.SeedButton:Hide()
    else
        frame:SetSize(EMPTY_SEED_SIZE, EMPTY_SEED_SIZE)
    end

    frame._layoutInProgress = false
    OrbitEngine.Frame:ForceUpdateSelection(frame)
    if not frame.orbitMountedSuppressed then frame:Show() end
end

function Layout:LayoutChargeBars(plugin)
    self:LayoutChargeBar(plugin, plugin.chargeBarAnchor)
    for _, childData in pairs(plugin.activeChargeChildren) do
        if childData.frame then
            self:LayoutChargeBar(plugin, childData.frame)
        end
    end
end

-- [ SKINNING ]--------------------------------------------------------------------------------------
function Layout:SkinChargeButtons(plugin, frame, maxCharges, totalWidth, height, borderSize, spacing, texture, sysIndex, bgColor, scale)
    local snappedGap = PixelMultiple(math.max(spacing - 1, spacing > 0 and 1 or 0), scale)
    local snappedWidth = SnapToPixel(totalWidth, scale)
    local globalSettings = Orbit.db.GlobalSettings

    local logicalGap = PixelMultiple(spacing, scale)
    if spacing <= 1 then logicalGap = 0 end
    local exactWidth = (totalWidth - (logicalGap * (maxCharges - 1))) / maxCharges
    local segmentWidth = SnapToPixel(exactWidth, scale)

    local barColor1 = GetBarColor(plugin, sysIndex, 1, maxCharges)
    local rechargeColor = { r = barColor1.r * RECHARGE_DIM, g = barColor1.g * RECHARGE_DIM, b = barColor1.b * RECHARGE_DIM }
    Orbit.Skin:SkinStatusBar(frame.RechargeSegment, texture, rechargeColor)
    if frame.RechargeSegment.Overlay then frame.RechargeSegment.Overlay:Hide() end

    local stepWidth = segmentWidth + logicalGap
    local positionerWidth = math.max(1, stepWidth * maxCharges)
    frame.RechargePositioner:SetSize(positionerWidth, height)
    frame.RechargePositioner:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.RechargeSegment:SetSize(math.max(1, segmentWidth), height)
    frame.TickBar:SetSize(math.max(1, segmentWidth), height)

    local currentLeft = 0

    for i = 1, maxCharges do
        local btn = frame.buttons[i]
        if not btn then break end

        local logicalLeft = SnapToPixel(currentLeft, scale)

        btn:SetSize(segmentWidth, height)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", frame, "LEFT", logicalLeft, 0)

        currentLeft = currentLeft + segmentWidth + logicalGap

        if not btn.bg then
            btn.bg = btn:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers.BackdropDeep)
            btn.bg:SetAllPoints()
        end
        Orbit.Skin:ApplyGradientBackground(btn, globalSettings.BackdropColourCurve, bgColor)

        local barColor = GetBarColor(plugin, sysIndex, i, maxCharges)
        Orbit.Skin:SkinStatusBar(btn.Bar, texture, barColor)
        if btn.Bar.Overlay then btn.Bar.Overlay:Hide() end

        if not btn.orbitBackdrop then
            btn.orbitBackdrop = Orbit.Skin:CreateBackdrop(btn, nil)
            btn.orbitBackdrop:SetFrameLevel(btn:GetFrameLevel() + Constants.Levels.Highlight)
            btn.orbitBackdrop:SetBackdrop(nil)
        end
        Orbit.Skin:SkinBorder(btn, btn.orbitBackdrop, borderSize, { r = 0, g = 0, b = 0, a = 1 })

        OrbitEngine.Pixel:Enforce(btn)
    end

    local tickSize = plugin:GetSetting(frame.systemIndex, "TickSize") or TICK_SIZE_DEFAULT
    OrbitEngine.TickMixin:Apply(frame, tickSize, height, frame.RechargeSegment)

    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
    local positions = plugin:GetSetting(sysIndex, "ComponentPositions") or {}
    local pos = positions["ChargeCount"] or {}
    local overrides = pos.overrides or {}
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local fontName = plugin:GetSetting(sysIndex, "Font")
    local fontPath = LSM and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)
    OrbitEngine.OverrideUtils.ApplyOverrides(frame.CountText, overrides, { fontSize = textSize, fontPath = fontPath })
    if ApplyTextPosition then
        ApplyTextPosition(frame.CountText, frame, pos)
    end
end
