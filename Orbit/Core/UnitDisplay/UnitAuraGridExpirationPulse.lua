-- [ UNIT AURA GRID EXPIRATION PULSE ]----------------------------------------------------------------
-- lives outside the mixin file so the pulse list isn't module-level state on a stateless mixin. lazy ticker — starts on first register, cancels on drain.

local _, Orbit = ...
local Mixin = Orbit.UnitAuraGridMixin

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local EXPIRATION_THRESHOLD = 0.30
local EXPIRATION_ALPHA_MIN = 0.10
local EXPIRATION_PULSE_SPEED = 3
local EXPIRATION_TICK_INTERVAL = 0.065

local math_sin = math.sin
local math_abs = math.abs
local GetTime = GetTime

-- [ CURVES ]-----------------------------------------------------------------------------------------
local swipeCurve = C_CurveUtil.CreateCurve()
swipeCurve:SetType(Enum.LuaCurveType.Linear)
swipeCurve:AddPoint(0, 1) -- At 0% remaining (end), 100% alpha
swipeCurve:AddPoint(1, 0) -- At 100% remaining (start), 0% alpha

-- Shared mutating curve — ExpirationPulseTick fires ~15Hz per icon, so ClearPoints + AddPoint avoids per-tick userdata allocation.
local _expirationCurve = C_CurveUtil.CreateCurve()
_expirationCurve:SetType(Enum.LuaCurveType.Step)

-- [ TICKER ]-----------------------------------------------------------------------------------------
local _pulseIcons = {}
local _pulseTicker

local function ExpirationPulseTick()
    local n = #_pulseIcons
    if n == 0 then
        if _pulseTicker then _pulseTicker:Cancel(); _pulseTicker = nil end
        return
    end

    local wave = 1 - (1 - EXPIRATION_ALPHA_MIN) * math_abs(math_sin(GetTime() * EXPIRATION_PULSE_SPEED))
    _expirationCurve:ClearPoints()
    _expirationCurve:AddPoint(0, wave)
    _expirationCurve:AddPoint(EXPIRATION_THRESHOLD, 1)
    local expirationCurve = _expirationCurve

    local i = 1
    while i <= n do
        local icon = _pulseIcons[i]
        local durObj = icon._orbitExpireDurObj
        if not durObj or not icon:IsShown() then
            icon._orbitPulseRegistered = nil
            icon:SetAlpha(1)
            _pulseIcons[i] = _pulseIcons[n]
            _pulseIcons[n] = nil
            n = n - 1
        else
            local alpha = C_CurveUtil.EvaluateColorValueFromBoolean(durObj:IsZero(), 1, durObj:EvaluateRemainingPercent(expirationCurve))
            icon:SetAlpha(alpha)
            if icon.Cooldown then
                local cdAlpha = C_CurveUtil.EvaluateColorValueFromBoolean(durObj:IsZero(), 1, durObj:EvaluateRemainingPercent(swipeCurve))
                icon.Cooldown:SetAlpha(cdAlpha)
            end
            i = i + 1
        end
    end
end

-- [ REGISTRATION ]-----------------------------------------------------------------------------------
function Mixin._RegisterExpirationPulse(icon, durObj)
    icon._orbitExpireDurObj = durObj
    if icon._orbitPulseRegistered then return end
    icon._orbitPulseRegistered = true
    _pulseIcons[#_pulseIcons + 1] = icon
    if not _pulseTicker then _pulseTicker = C_Timer.NewTicker(EXPIRATION_TICK_INTERVAL, ExpirationPulseTick) end
end
