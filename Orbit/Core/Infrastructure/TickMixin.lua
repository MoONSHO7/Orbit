-- [ TICK MIXIN ]------------------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine
Engine.TickMixin = {}
local TickMixin = Engine.TickMixin

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local TICK_SIZE_DEFAULT = 2
local TICK_SIZE_MAX = 6
local TICK_OVERSHOOT = 2

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"

TickMixin.TICK_SIZE_DEFAULT = TICK_SIZE_DEFAULT
TickMixin.TICK_SIZE_MAX = TICK_SIZE_MAX
TickMixin.TICK_OVERSHOOT = TICK_OVERSHOOT

local TICK_ALPHA_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0)
    c:AddPoint(0.001, 1)
    c:AddPoint(0.999, 1)
    c:AddPoint(1.0, 0)
    return c
end)()
TickMixin.TICK_ALPHA_CURVE = TICK_ALPHA_CURVE

-- [ CREATE ]----------------------------------------------------------------------------------------

function TickMixin:Create(parent, statusBar, anchorRegion)
    local tickBar = CreateFrame("StatusBar", nil, parent)
    if anchorRegion then tickBar:SetPoint("LEFT", anchorRegion, "RIGHT", 0, 0)
    else tickBar:SetAllPoints(statusBar) end
    tickBar:SetFrameLevel(statusBar:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
    tickBar:SetMinMaxValues(0, 1)
    tickBar:SetValue(0)
    tickBar:SetStatusBarTexture(WHITE_TEXTURE)
    tickBar:GetStatusBarTexture():SetAlpha(0)
    tickBar:GetStatusBarTexture():SetSnapToPixelGrid(true)
    tickBar:GetStatusBarTexture():SetTexelSnappingBias(0)

    local tickClip = CreateFrame("Frame", nil, parent)
    if anchorRegion then tickClip:SetPoint("LEFT", anchorRegion, "RIGHT", 0, 0)
    else tickClip:SetAllPoints(statusBar) end
    tickClip:SetClipsChildren(true)
    tickClip:SetFrameLevel(tickBar:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)

    local tickMark = CreateFrame("Frame", nil, tickClip)
    tickMark:SetPoint("RIGHT", tickBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    local scale = parent:GetEffectiveScale()
    tickMark:SetSize(Engine.Pixel:Multiple(TICK_SIZE_DEFAULT, scale), 1)
    local tickTex = tickMark:CreateTexture(nil, "OVERLAY")
    tickTex:SetColorTexture(1, 1, 1, 1)
    tickTex:SetAllPoints()
    tickTex:SetSnapToPixelGrid(true)
    tickTex:SetTexelSnappingBias(0)

    parent.TickBar = tickBar
    parent.TickClip = tickClip
    parent.TickMark = tickMark
end

-- [ APPLY ]-----------------------------------------------------------------------------------------
-- `perpDim` is the dimension perpendicular to the bar's fill axis (the bar's
-- height for HORIZONTAL, the bar's width for VERTICAL). The tick mark is a
-- thin line that crosses the bar perpendicular to fill direction; tickSize is
-- its thickness along the fill axis. orientation defaults to HORIZONTAL so
-- existing horizontal callers (PlayerPower, PlayerResources) need no changes.
function TickMixin:Apply(frame, tickSize, perpDim, anchorBar, orientation)
    local rounded = 2 * math.floor((tickSize + 1) / 2)
    if rounded > 0 and frame.TickBar then
        frame.TickBar:SetOrientation(orientation or "HORIZONTAL")
        local scale = frame:GetEffectiveScale()
        local overshoot = Engine.Pixel:Multiple(TICK_OVERSHOOT, scale)
        local tickThickness = math.max(Engine.Pixel:Multiple(rounded, scale), Engine.Pixel:DefaultBorderSize(scale))
        local crossSize = Engine.Pixel:Snap(perpDim + overshoot * 2, scale)
        local ref = anchorBar or frame.TickBar
        frame.TickClip:ClearAllPoints()
        frame.TickMark:ClearAllPoints()
        if orientation == "VERTICAL" then
            frame.TickMark:SetSize(crossSize, tickThickness)
            frame.TickMark:SetPoint("TOP", frame.TickBar:GetStatusBarTexture(), "TOP", 0, 0)
            frame.TickClip:SetPoint("TOPLEFT", ref, "TOPLEFT", overshoot, -tickThickness)
            frame.TickClip:SetPoint("BOTTOMRIGHT", ref, "BOTTOMRIGHT", -overshoot, tickThickness)
        else
            frame.TickMark:SetSize(tickThickness, crossSize)
            frame.TickMark:SetPoint("RIGHT", frame.TickBar:GetStatusBarTexture(), "RIGHT", 0, 0)
            frame.TickClip:SetPoint("TOPLEFT", ref, "TOPLEFT", tickThickness, -overshoot)
            frame.TickClip:SetPoint("BOTTOMRIGHT", ref, "BOTTOMRIGHT", -tickThickness, overshoot)
        end
        frame.TickBar:Show()
        frame.TickClip:Show()
    elseif frame.TickBar then
        frame.TickBar:Hide()
        frame.TickClip:Hide()
    end
end

-- [ SHOW / HIDE ]-----------------------------------------------------------------------------------

function TickMixin:Show(frame)
    if frame.TickBar then frame.TickBar:Show() end
    if frame.TickClip then frame.TickClip:Show() end
end

function TickMixin:Hide(frame)
    if frame.TickBar then frame.TickBar:Hide() end
    if frame.TickClip then frame.TickClip:Hide() end
end

-- [ UPDATE ]----------------------------------------------------------------------------------------

function TickMixin:Update(frame, current, max, smoothing)
    if not frame.TickBar then return end
    frame.TickBar:SetMinMaxValues(0, max)
    frame.TickBar:SetValue(current, smoothing)
end
