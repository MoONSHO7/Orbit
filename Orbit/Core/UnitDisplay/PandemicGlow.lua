-- [ ORBIT PANDEMIC GLOW ]--------------------------------------------------------------------------
-- Curve-driven pandemic glow for UnitDisplay aura icons.
-- Thin adapter: curve evaluation → GlowController call.
local _, Orbit = ...
Orbit.PandemicGlow = {}
local PG = Orbit.PandemicGlow
local GC = Orbit.Engine.GlowController
local GU = Orbit.Engine.GlowUtils
local GLOW_KEY = "orbitPandemic"
local PANDEMIC_THRESHOLD = 0.3

-- Step curve: 1 when remaining <= 30% (pandemic), 0 otherwise. Binary, no fade.
local pandemicCurve = C_CurveUtil.CreateCurve()
pandemicCurve:SetType(Enum.LuaCurveType.Step)
pandemicCurve:AddPoint(0, 1)
pandemicCurve:AddPoint(PANDEMIC_THRESHOLD, 0)

-- [ STOP GLOW ]------------------------------------------------------------------------------------
function PG:Stop(icon)
    if not icon then return end
    GC:StopPandemic(icon)
end

-- [ APPLY ]----------------------------------------------------------------------------------------
function PG:Apply(icon, aura, unit, skinSettings)
    if not icon or not aura then return end

    local overrides = skinSettings and skinSettings.overrides or {}
    local glowType = (skinSettings and skinSettings.pandemicGlowType) or Orbit.Constants.Glow.Type.Pixel

    local durObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
    if not durObj then self:Stop(icon); return end

    local alpha = C_CurveUtil.EvaluateColorValueFromBoolean(durObj:IsZero(), 0, durObj:EvaluateRemainingPercent(pandemicCurve))
    local c = (skinSettings and skinSettings.pandemicColor) or Orbit.Constants.Glow.DefaultColor
    local typeName, options, hash = GU:BuildOptionsFromLookup(overrides, "PandemicGlow", c, GLOW_KEY)

    if not typeName and glowType then
        typeName = (glowType == 1 and "Pixel") or (glowType == 2 and "Medium") or (glowType == 3 and "Autocast") or (glowType == 4 and "Classic") or nil
        if typeName then
            options = { color = { c.r, c.g, c.b, c.a or 1 }, key = GLOW_KEY }
            local defs = Orbit.Constants.Glow.Defaults[typeName]
            if defs then
                for k, v in pairs(defs) do options[string.lower(string.sub(k,1,1))..string.sub(k,2)] = v end
            end
        end
    end

    if not typeName or not options then self:Stop(icon); return end
    GC:ShowPandemic(icon, typeName, options, alpha)
end
