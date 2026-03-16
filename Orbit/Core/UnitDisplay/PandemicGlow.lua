-- [ ORBIT PANDEMIC GLOW ]--------------------------------------------------------------------------
-- Curve-driven pandemic glow for UnitDisplay aura icons.
-- Uses C_CurveUtil Step curve + wrapper frame + SetAlpha(secretNumber).
-- Pattern from Platynator: compute pandemic from the aura's own duration, no CDM dependency.
local _, Orbit = ...
Orbit.PandemicGlow = {}
local PG = Orbit.PandemicGlow
local LibCustomGlow = LibStub and LibStub("LibCustomGlow-1.0", true)
local GLOW_KEY = "orbitPandemic"
local PANDEMIC_THRESHOLD = 0.3

-- Step curve: 1 when remaining <= 30% (pandemic), 0 otherwise. Binary, no fade.
local pandemicCurve = C_CurveUtil.CreateCurve()
pandemicCurve:SetType(Enum.LuaCurveType.Step)
pandemicCurve:AddPoint(0, 1)
pandemicCurve:AddPoint(PANDEMIC_THRESHOLD, 0)

local GlowType = { Pixel = 1, Proc = 2, AutoCast = 3, Button = 4, Blizzard = 5 }
local GlowConfig = {
    Pixel    = { Lines = 8, Frequency = 0.25, Length = 4, Thickness = 2, XOffset = 0, YOffset = 0, Border = false },
    Proc     = { StartAnim = false, FrameLevel = nil },
    AutoCast = { NumParticles = 4, Size = 2, Frequency = 0.12 },
    Button   = { Frequency = 0.3, FrameLevel = nil },
}

-- [ WRAPPER FRAME ]--------------------------------------------------------------------------------
-- Glow runs inside a wrapper. Wrapper alpha is driven by the curve (secret number).
-- LibCustomGlow animations only affect the glow frame's alpha, not the wrapper's.
local function GetOrCreateWrapper(icon)
    local w = icon.orbitPandemicWrapper
    local iw, ih = icon:GetSize()
    if w then
        local ww, wh = w:GetSize()
        -- Force glow recreation if icon resized
        if ww ~= iw or wh ~= ih then
            w:SetSize(iw, ih)
            icon.orbitPandemicGlowType = nil
        end
        return w
    end
    w = CreateFrame("Frame", nil, icon)
    w:SetPoint("CENTER", icon, "CENTER")
    w:SetSize(iw, ih)
    w:SetFrameLevel(icon:GetFrameLevel() + 3)
    w:SetAlpha(0)
    icon.orbitPandemicWrapper = w
    return w
end

-- [ START GLOW ]-----------------------------------------------------------------------------------
local function StartGlow(wrapper, glowType, colorTable)
    if glowType == GlowType.Pixel then
        local cfg = GlowConfig.Pixel
        LibCustomGlow.PixelGlow_Start(wrapper, colorTable, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, GLOW_KEY)
    elseif glowType == GlowType.Proc then
        LibCustomGlow.ProcGlow_Start(wrapper, { color = colorTable, startAnim = GlowConfig.Proc.StartAnim, frameLevel = GlowConfig.Proc.FrameLevel, key = GLOW_KEY })
    elseif glowType == GlowType.AutoCast then
        local cfg = GlowConfig.AutoCast
        LibCustomGlow.AutoCastGlow_Start(wrapper, colorTable, cfg.NumParticles, cfg.Frequency, cfg.Size, cfg.Size, GLOW_KEY)
    elseif glowType == GlowType.Button then
        LibCustomGlow.ButtonGlow_Start(wrapper, colorTable, GlowConfig.Button.Frequency, GlowConfig.Button.FrameLevel)
    end
end

-- [ STOP GLOW ]------------------------------------------------------------------------------------
local function StopGlow(wrapper, glowType)
    if glowType == GlowType.Pixel then LibCustomGlow.PixelGlow_Stop(wrapper, GLOW_KEY)
    elseif glowType == GlowType.Proc then LibCustomGlow.ProcGlow_Stop(wrapper, GLOW_KEY)
    elseif glowType == GlowType.AutoCast then LibCustomGlow.AutoCastGlow_Stop(wrapper, GLOW_KEY)
    elseif glowType == GlowType.Button then LibCustomGlow.ButtonGlow_Stop(wrapper) end
end

function PG:Stop(icon)
    if not icon or not LibCustomGlow then return end
    local w = icon.orbitPandemicWrapper
    if not w then return end
    local active = icon.orbitPandemicGlowType
    if active then StopGlow(w, active) end
    w:SetAlpha(0)
    icon.orbitPandemicGlowType = nil
end

-- [ APPLY ]----------------------------------------------------------------------------------------
-- Called from AuraMixin on every UNIT_AURA rebuild.
-- Gets the aura's DurationObject, evaluates the pandemic curve, and sets wrapper alpha.
-- The glow runs continuously inside the wrapper; only the wrapper alpha controls visibility.
function PG:Apply(icon, aura, unit, skinSettings)
    if not icon or not aura or not LibCustomGlow then return end
    local glowType = (skinSettings and skinSettings.pandemicGlowType) or GlowType.Pixel
    if glowType == GlowType.Blizzard then
        self:Stop(icon)
        return
    end
    -- Get DurationObject for this aura
    local durObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
    if not durObj then
        self:Stop(icon)
        return
    end
    -- Evaluate pandemic curve — returns secret number (0 or 1 from Step curve)
    -- EvaluateColorValueFromBoolean: if duration is zero (permanent aura), return 0. Otherwise return curve result.
    local alpha = C_CurveUtil.EvaluateColorValueFromBoolean(durObj:IsZero(), 0, durObj:EvaluateRemainingPercent(pandemicCurve))
    -- Get or create wrapper, drive its alpha (also checks for size changes)
    local wrapper = GetOrCreateWrapper(icon)
    wrapper:SetAlpha(alpha)
    -- Ensure glow is running inside wrapper (create once, alpha controls visibility)
    if icon.orbitPandemicGlowType == glowType then return end
    -- Glow type changed or first time — recreate
    if icon.orbitPandemicGlowType then StopGlow(wrapper, icon.orbitPandemicGlowType) end
    local c = (skinSettings and skinSettings.pandemicGlowColor) or { r = 1, g = 0.8, b = 0 }
    StartGlow(wrapper, glowType, { c.r, c.g, c.b, 1 })
    icon.orbitPandemicGlowType = glowType
end

