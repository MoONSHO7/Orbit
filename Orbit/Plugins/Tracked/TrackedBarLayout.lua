---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ] ---------------------------------------------------------------
local DEFAULT_WIDTH = 120
local DEFAULT_HEIGHT = 12
local EMPTY_SEED_SIZE = 40
local RECHARGE_DIM = 0.35
local MAX_DIVIDERS = 10
local TICK_SIZE_DEFAULT = OrbitEngine.TickMixin.TICK_SIZE_DEFAULT

-- [ HELPERS ] -----------------------------------------------------------------
local function SnapToPixel(value, scale) return OrbitEngine.Pixel:Snap(value, scale) end
local function PixelMultiple(count, scale) return OrbitEngine.Pixel:Multiple(count, scale) end

local function GetBarColor(plugin, sysIndex)
    local curveData = plugin:GetSetting(sysIndex, "BarColorCurve")
    if curveData then
        local c = OrbitEngine.ColorCurve:GetFirstColorFromCurve(curveData)
        if c then return c end
    end
    local _, class = UnitClass("player")
    return (Orbit.Colors.PlayerResources and Orbit.Colors.PlayerResources[class]) or { r = 1, g = 0.8, b = 0 }
end

local function GetBgColor()
    local gc = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.UnitFrameBackdropColourCurve
    local c = gc and OrbitEngine.ColorCurve:GetFirstColorFromCurve(gc)
    return c or { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }
end

-- [ MODULE ] ------------------------------------------------------------------
Orbit.TrackedBarLayout = {}
local Layout = Orbit.TrackedBarLayout

-- [ DIVIDER BUILDING ] --------------------------------------------------------
function Layout:BuildDividers(frame, maxCharges)
    frame.Dividers = frame.Dividers or {}
    for i = 1, MAX_DIVIDERS do
        if not frame.Dividers[i] then
            frame.Dividers[i] = frame.StatusBar:CreateTexture(nil, "OVERLAY", nil, 7)
            frame.Dividers[i]:SetColorTexture(0, 0, 0, 1)
            frame.Dividers[i]:Hide()
        end
    end
    frame.StatusBar:SetMinMaxValues(0, maxCharges)
end

-- [ LAYOUT ] ------------------------------------------------------------------
function Layout:LayoutTrackedBar(plugin, frame)
    if not frame then return end
    if frame._layoutInProgress then return end
    frame._layoutInProgress = true

    local sysIndex = frame.systemIndex
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(frame) ~= nil

    if frame.TrackedBarSpellId then
        local width = plugin:GetSetting(sysIndex, "Width") or DEFAULT_WIDTH
        local height = plugin:GetSetting(sysIndex, "Height") or DEFAULT_HEIGHT
        if not isAnchored then frame:SetWidth(width) end
        width = frame:GetWidth()
        frame:SetHeight(height)

        local borderSize = plugin:GetSetting(sysIndex, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(frame:GetEffectiveScale() or 1)
        local dividerSize = plugin:GetSetting(sysIndex, "DividerSize") or plugin:GetSetting(sysIndex, "Spacing") or 2
        local texture = plugin:GetSetting(sysIndex, "Texture") or (Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Texture)
        local scale = frame:GetEffectiveScale()
        local maxCharges = frame.cachedMaxCharges or 2

        self:SkinTrackedBar(plugin, frame, maxCharges, width, height, borderSize, dividerSize, texture, sysIndex, scale)
        if frame.SeedButton then frame.SeedButton:Hide() end
    else
        frame:SetSize(EMPTY_SEED_SIZE, EMPTY_SEED_SIZE)
    end

    frame._layoutInProgress = false
    OrbitEngine.Frame:ForceUpdateSelection(frame)
    if not frame.orbitMountedSuppressed then frame:Show() end
end

function Layout:LayoutTrackedBars(plugin)
    self:LayoutTrackedBar(plugin, plugin.TrackedBarAnchor)
    for _, childData in pairs(plugin.activeTrackedBarChildren) do
        if childData.frame then
            self:LayoutTrackedBar(plugin, childData.frame)
        end
    end
end

-- [ SKINNING ] ----------------------------------------------------------------
function Layout:SkinTrackedBar(plugin, frame, maxCharges, totalWidth, height, borderSize, dividerSize, texture, sysIndex, scale)
    local globalSettings = Orbit.db.GlobalSettings
    local bgColor = GetBgColor()
    local barColor = GetBarColor(plugin, sysIndex)
    local rechargeColor = { r = barColor.r * RECHARGE_DIM, g = barColor.g * RECHARGE_DIM, b = barColor.b * RECHARGE_DIM }

    -- Skin the main StatusBar
    Orbit.Skin:SkinStatusBar(frame.StatusBar, texture, barColor)
    if frame.StatusBar.Overlay then frame.StatusBar.Overlay:Hide() end

    -- Skin the recharge segment
    Orbit.Skin:SkinStatusBar(frame.RechargeSegment, texture, rechargeColor)
    if frame.RechargeSegment.Overlay then frame.RechargeSegment.Overlay:Hide() end

    -- Background
    Orbit.Skin:ApplyGradientBackground(frame, globalSettings.UnitFrameBackdropColourCurve, bgColor)

    -- Border (single border around entire bar)
    if frame.orbitBackdrop then frame.orbitBackdrop:Hide() end
    Orbit.Skin:SkinBorder(frame, frame, borderSize)

    -- Recharge positioner spans the full bar (must match main StatusBar width for proportional alignment)
    local segmentWidth = SnapToPixel(totalWidth / maxCharges, scale)
    frame.RechargePositioner:SetSize(totalWidth, height)
    frame.RechargePositioner:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.RechargeSegment:SetSize(math.max(1, segmentWidth), height)
    frame.TickBar:SetSize(math.max(1, segmentWidth), height)

    -- Position dividers
    self:RepositionDividers(frame, maxCharges, totalWidth, height, dividerSize, scale)

    -- Tick mark
    local tickSize = plugin:GetSetting(sysIndex, "TickSize") or TICK_SIZE_DEFAULT
    OrbitEngine.TickMixin:Apply(frame, tickSize, height, frame.RechargeSegment)

    -- Count text
    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
    local positions = plugin:GetComponentPositions(sysIndex)
    local pos = positions["ChargeCount"] or {}
    local overrides = pos.overrides or {}
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local fontName = plugin:GetSetting(sysIndex, "Font")
    local fontPath = LSM and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    local textSize = 18
    OrbitEngine.OverrideUtils.ApplyOverrides(frame.CountText, overrides, { fontSize = textSize, fontPath = fontPath })
    if ApplyTextPosition then
        ApplyTextPosition(frame.CountText, frame, pos)
    end

    OrbitEngine.Pixel:Enforce(frame)
end

-- [ DIVIDER POSITIONING ] -----------------------------------------------------
-- Dividers are centered on proportional charge boundaries ((i/maxCharges) * totalWidth)
-- so they align exactly with the StatusBar fill edge at each integer charge value.
function Layout:RepositionDividers(frame, maxCharges, totalWidth, height, dividerSize, scale)
    if not frame.Dividers then return end
    local logicalGap = PixelMultiple(dividerSize, scale)
    local halfGap = logicalGap / 2
    for i = 1, MAX_DIVIDERS do
        local div = frame.Dividers[i]
        if div then
            if i < maxCharges and dividerSize > 0 then
                local boundary = SnapToPixel((i / maxCharges) * totalWidth, scale)
                div:ClearAllPoints()
                div:SetSize(logicalGap, height)
                div:SetPoint("LEFT", frame, "LEFT", boundary - halfGap, 0)
                OrbitEngine.Pixel:Enforce(div)
                div:Show()
            else
                div:Hide()
            end
        end
    end
end
