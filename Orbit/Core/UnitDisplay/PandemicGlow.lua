-- [ ORBIT PANDEMIC GLOW ]--------------------------------------------------------------------------
local _, Orbit = ...
Orbit.PandemicGlow = {}
local PG = Orbit.PandemicGlow

local pcall = pcall
local LibCustomGlow = LibStub and LibStub("LibCustomGlow-1.0", true)
local GLOW_KEY = "orbitPandemic"

local PANDEMIC_CURVE
if C_CurveUtil and C_CurveUtil.CreateCurve then
    PANDEMIC_CURVE = C_CurveUtil.CreateCurve()
    PANDEMIC_CURVE:AddPoint(0.00, 0)
    PANDEMIC_CURVE:AddPoint(0.01, 1)
    PANDEMIC_CURVE:AddPoint(0.30, 1)
    PANDEMIC_CURVE:AddPoint(0.301, 0)
    PANDEMIC_CURVE:AddPoint(1.0, 0)
end

local GlowType = { Pixel = 1, Proc = 2, AutoCast = 3, Button = 4 }
local GlowConfig = {
    Pixel    = { Lines = 8, Frequency = 0.25, Length = 4, Thickness = 2, XOffset = 0, YOffset = 0, Border = false },
    Proc     = { StartAnim = false, FrameLevel = nil },
    AutoCast = { NumParticles = 4, Size = 2, Frequency = 0.12 },
    Button   = { Frequency = 0.3, FrameLevel = nil },
}

function PG:Apply(icon, aura, unit, skinSettings)
    if not icon or not aura or not LibCustomGlow then return end
    if not PANDEMIC_CURVE or not C_UnitAuras or not C_UnitAuras.GetAuraDuration or not aura.auraInstanceID then return end
    local durObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
    if not durObj then return end
    local ok, hasRemaining = pcall(durObj.HasRemainingTime, durObj)
    if not ok or not hasRemaining then return end
    local glowType = (skinSettings and skinSettings.pandemicGlowType) or GlowType.Pixel
    local pandemicColor = (skinSettings and skinSettings.pandemicColor) or { r = 1, g = 0.8, b = 0 }
    local colorTable = { pandemicColor.r, pandemicColor.g, pandemicColor.b, 1 }
    if icon.orbitPandemicGlowActive then self:Stop(icon) end
    icon.orbitAura, icon.orbitUnit, icon.orbitPandemicAuraID = aura, unit, aura.auraInstanceID

    if glowType == GlowType.Pixel then
        local cfg = GlowConfig.Pixel
        LibCustomGlow.PixelGlow_Start(icon, colorTable, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, GLOW_KEY)
        icon.orbitPandemicGlowActive = GlowType.Pixel
    elseif glowType == GlowType.Proc then
        local cfg = GlowConfig.Proc
        LibCustomGlow.ProcGlow_Start(icon, { color = colorTable, startAnim = cfg.StartAnim, frameLevel = cfg.FrameLevel, key = GLOW_KEY })
        icon.orbitPandemicGlowActive = GlowType.Proc
    elseif glowType == GlowType.AutoCast then
        local cfg = GlowConfig.AutoCast
        LibCustomGlow.AutoCastGlow_Start(icon, colorTable, cfg.NumParticles, cfg.Frequency, cfg.Size, cfg.Size, GLOW_KEY)
        icon.orbitPandemicGlowActive = GlowType.AutoCast
    elseif glowType == GlowType.Button then
        local cfg = GlowConfig.Button
        LibCustomGlow.ButtonGlow_Start(icon, colorTable, cfg.Frequency, cfg.FrameLevel)
        icon.orbitPandemicGlowActive = GlowType.Button
    end

    local glowFrame = icon["_PixelGlow" .. GLOW_KEY] or icon["_ProcGlow" .. GLOW_KEY] or icon["_AutoCastGlow" .. GLOW_KEY] or icon["__ButtonGlow"]
    if glowFrame then glowFrame:SetAlpha(0) end

    if not icon.PandemicController then
        icon.PandemicController = CreateFrame("Frame", nil, icon)
        local updateInterval = 0.1
        local elapsed = 0
        icon.PandemicController:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed < updateInterval then return end
            elapsed = 0
            local parent = self:GetParent()
            if not parent or not parent.orbitPandemicGlowActive then self:Hide(); return end
            local pUnit = parent.orbitUnit
            local auraID = parent.orbitPandemicAuraID
            if not pUnit or not auraID then self:Hide(); return end
            local dur = C_UnitAuras.GetAuraDuration(pUnit, auraID)
            if not dur then PG:Stop(parent); self:Hide(); return end
            local ok1, stillHas = pcall(dur.HasRemainingTime, dur)
            if not ok1 or not stillHas then PG:Stop(parent); self:Hide(); return end
            local glow = parent["_PixelGlow" .. GLOW_KEY] or parent["_ProcGlow" .. GLOW_KEY] or parent["_AutoCastGlow" .. GLOW_KEY] or parent["__ButtonGlow"]
            if not glow then self:Hide(); return end
            local ok2, pandemicAlpha = pcall(dur.EvaluateRemainingPercent, dur, PANDEMIC_CURVE)
            if ok2 and pandemicAlpha then glow:SetAlpha(pandemicAlpha) end
        end)
    end
    icon.PandemicController:Show()
end

function PG:Stop(icon)
    if not icon or not LibCustomGlow then return end
    LibCustomGlow.PixelGlow_Stop(icon, GLOW_KEY)
    LibCustomGlow.ProcGlow_Stop(icon, GLOW_KEY)
    LibCustomGlow.AutoCastGlow_Stop(icon, GLOW_KEY)
    LibCustomGlow.ButtonGlow_Stop(icon)
    icon.orbitPandemicGlowActive = nil
    icon.orbitAura = nil
    icon.orbitUnit = nil
    icon.orbitPandemicAuraID = nil
    if icon.PandemicController then icon.PandemicController:Hide() end
end
