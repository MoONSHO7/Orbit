-- [ TICK MIXIN ]------------------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine
Engine.TickMixin = {}
local TickMixin = Engine.TickMixin

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local TICK_SIZE_DEFAULT = 2
local TICK_SIZE_MAX = 6
local TICK_OVERSHOOT = 2
local TICK_LEVEL_BOOST = 10
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
    tickBar:SetFrameLevel(statusBar:GetFrameLevel() + TICK_LEVEL_BOOST)
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
    tickClip:SetFrameLevel(tickBar:GetFrameLevel() + 1)

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

function TickMixin:Apply(frame, tickSize, height, anchorBar)
    local rounded = 2 * math.floor((tickSize + 1) / 2)
    if rounded > 0 and frame.TickBar then
        local scale = frame:GetEffectiveScale()
        local overshoot = Engine.Pixel:Multiple(TICK_OVERSHOOT, scale)
        local tickWidth = math.max(Engine.Pixel:Multiple(rounded, scale), Engine.Pixel:DefaultBorderSize(scale))
        frame.TickMark:SetSize(tickWidth, Engine.Pixel:Snap(height + overshoot * 2, scale))
        frame.TickClip:ClearAllPoints()
        local ref = anchorBar or frame.TickBar
        frame.TickClip:SetPoint("TOPLEFT", ref, "TOPLEFT", tickWidth, -overshoot)
        frame.TickClip:SetPoint("BOTTOMRIGHT", ref, "BOTTOMRIGHT", -tickWidth, overshoot)
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
