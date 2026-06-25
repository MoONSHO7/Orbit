-- [ ORBIT HEALER AURA TICKER ]-----------------------------------------------------------------------
-- Singleton OnUpdate ticker driving healer-aura curve-based swipe/timer visuals. Extracted from AuraMixin so the mixin owns icon/container display, not animation.
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local math_max = math.max

Orbit.HealerAuraTicker = {}
local Ticker = Orbit.HealerAuraTicker

local CURVE_TICK_INTERVAL = 0.05
local _activeCurveIcons = {}
local _curveTicker

-- IDENTITY_CURVE: remaining-percent (secret) → numeric for safe Lua-side reads.
local IDENTITY_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0.0)
    c:AddPoint(1.0, 1.0)
    return c
end)()

-- Samples remaining-percent via IDENTITY_CURVE for curve-driven swipe/timer color.
function Ticker:Update(icon)
    if not icon:IsShown() then return end
    local d = icon._orbitCurveData
    if not d then return end
    local remainingPercent = 1
    if d.auraInstanceID and d.unit and IDENTITY_CURVE then
        local durObj = C_UnitAuras.GetAuraDuration(d.unit, d.auraInstanceID)
        if durObj then
            local p = durObj:EvaluateRemainingPercent(IDENTITY_CURVE)
            if issecretvalue(p) then return end
            if p then remainingPercent = math_max(0, p) end
        end
    end
    local CCE = OrbitEngine.ColorCurve
    if d.swipeCurve and icon.Cooldown then
        local r, g, b, a = CCE:SampleColorCurveUnpacked(d.swipeCurve, remainingPercent)
        if r then
            local cd = icon.Cooldown
            local swipeTex = Orbit.Skin:GetRoundedSwipeTexture(true) or Orbit.Constants.Assets.SwipeCustom
            cd.orbitUpdating = true
            cd:SetSwipeTexture(swipeTex)
            cd:SetSwipeColor(r, g, b, a or 0.8)
            cd.orbitUpdating = false
            cd.orbitDesiredSwipe = cd.orbitDesiredSwipe or {}
            cd.orbitDesiredSwipe.texture = swipeTex
            cd.orbitDesiredSwipe.r = r
            cd.orbitDesiredSwipe.g = g
            cd.orbitDesiredSwipe.b = b
            cd.orbitDesiredSwipe.a = a or 0.8
        end
    end
    if d.timerCurve and icon.Cooldown then
        local text = icon.Cooldown.Text
        if text and text.SetTextColor then
            local cr, cg, cb = CCE:SampleColorCurveUnpacked(d.timerCurve, remainingPercent)
            if cr then text:SetTextColor(cr or 1, cg or 1, cb or 1) end
        end
    end
end

local function CurveTickerLoop()
    local n = #_activeCurveIcons
    local i = 1
    while i <= n do
        local icon = _activeCurveIcons[i]
        if not icon._orbitCurveData or not icon:IsShown() then
            icon._orbitCurveRegistered = nil
            _activeCurveIcons[i] = _activeCurveIcons[n]
            _activeCurveIcons[n] = nil
            n = n - 1
        else
            Ticker:Update(icon)
            i = i + 1
        end
    end
    if n == 0 and _curveTicker then
        _curveTicker:Cancel()
        _curveTicker = nil
    end
end

function Ticker:Register(icon)
    if icon._orbitCurveRegistered then return end
    icon._orbitCurveRegistered = true
    _activeCurveIcons[#_activeCurveIcons + 1] = icon
    if not _curveTicker then _curveTicker = C_Timer.NewTicker(CURVE_TICK_INTERVAL, CurveTickerLoop) end
end
