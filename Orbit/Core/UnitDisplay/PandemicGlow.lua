-- [ ORBIT PANDEMIC GLOW ]--------------------------------------------------------------------------
-- Curve-driven pandemic glow for UnitDisplay aura icons.
local _, Orbit = ...
Orbit.PandemicGlow = {}
local PG = Orbit.PandemicGlow
local LibCustomGlow = LibStub and LibStub("LibOrbitGlow-1.0", true)
local GLOW_KEY = "orbitPandemic"
local PANDEMIC_THRESHOLD = 0.3

-- Step curve: 1 when remaining <= 30% (pandemic), 0 otherwise. Binary, no fade.
local pandemicCurve = C_CurveUtil.CreateCurve()
pandemicCurve:SetType(Enum.LuaCurveType.Step)
pandemicCurve:AddPoint(0, 1)
pandemicCurve:AddPoint(PANDEMIC_THRESHOLD, 0)

-- [ WRAPPER FRAME ]--------------------------------------------------------------------------------
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
    w:SetFrameLevel(icon:GetFrameLevel() + (Orbit.Constants.Levels.IconGlow or 5))
    w:SetAlpha(0)
    icon.orbitPandemicWrapper = w
    return w
end

-- [ STOP GLOW ]------------------------------------------------------------------------------------
local function StopGlow(wrapper, typeName)
    if not typeName then return end
    LibCustomGlow.Hide(wrapper, typeName, GLOW_KEY)
end

function PG:Stop(icon)
    if not icon or not LibCustomGlow then return end
    local w = icon.orbitPandemicWrapper
    if not w then return end
    local active = icon.orbitPandemicGlowType
    if active then StopGlow(w, active) end
    w:SetAlpha(0)
    icon.orbitPandemicGlowType = nil
    icon.orbitPandemicGlowEnum = nil
end

-- [ APPLY ]----------------------------------------------------------------------------------------
function PG:Apply(icon, aura, unit, skinSettings)
    if not icon or not aura or not LibCustomGlow then return end
    
    local overrides = skinSettings and skinSettings.overrides or {}
    local glowType = (skinSettings and skinSettings.pandemicGlowType) or Orbit.Constants.Glow.Type.Pixel

    -- Get DurationObject for this aura
    local durObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
    if not durObj then
        self:Stop(icon)
        return
    end
    
    local alpha = C_CurveUtil.EvaluateColorValueFromBoolean(durObj:IsZero(), 0, durObj:EvaluateRemainingPercent(pandemicCurve))
    local wrapper = GetOrCreateWrapper(icon)
    wrapper:SetAlpha(alpha)
    
    -- Fast path: already active
    if icon.orbitPandemicGlowEnum == glowType then return end

    if icon.orbitPandemicGlowType then StopGlow(wrapper, icon.orbitPandemicGlowType) end
    icon.orbitPandemicGlowEnum = nil
    
    local c = (skinSettings and skinSettings.pandemicColor) or Orbit.Constants.Glow.DefaultColor
    
    -- Create dummy function if overrides isn't bound, since we just map it into BuildOptionsFromLookup
    local typeName, options = Orbit.Engine.GlowUtils:BuildOptionsFromLookup(overrides, "PandemicGlow", c, GLOW_KEY)
    
    -- If BuildOptionsFromLookup fails due to no 'PandemicGlowType' key inside `overrides`, manually construct default options based on glowType
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

    if typeName and options then
        LibCustomGlow.Show(wrapper, typeName, options)
        icon.orbitPandemicGlowType = typeName
        icon.orbitPandemicGlowEnum = glowType
    end
end

