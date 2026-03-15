-- [ ORBIT PANDEMIC GLOW ]--------------------------------------------------------------------------
-- Hook-driven pandemic glow for UnitDisplay aura icons.
-- Piggybacks on Blizzard's CooldownViewer PandemicIcon state.
-- No curves, no OnUpdate, no duration objects.
local _, Orbit = ...
Orbit.PandemicGlow = {}
local PG = Orbit.PandemicGlow
local LibCustomGlow = LibStub and LibStub("LibCustomGlow-1.0", true)
local GLOW_KEY = "orbitPandemic"

local GlowType = { Pixel = 1, Proc = 2, AutoCast = 3, Button = 4, Blizzard = 5 }
local GlowConfig = {
    Pixel    = { Lines = 8, Frequency = 0.25, Length = 4, Thickness = 2, XOffset = 0, YOffset = 0, Border = false },
    Proc     = { StartAnim = false, FrameLevel = nil },
    AutoCast = { NumParticles = 4, Size = 2, Frequency = 0.12 },
    Button   = { Frequency = 0.3, FrameLevel = nil },
}

-- [ QUERY COOLDOWN VIEWER PANDEMIC STATE ]---------------------------------------------------------
-- Iterates Blizzard CooldownViewer items. Returns true if the given spellId is currently
-- in pandemic (Blizzard's PandemicIcon is shown for that item).
local function IsSpellInPandemic(spellId)
    if not spellId then return false end
    local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
    if not CDM or not CDM.viewerMap then return false end
    for _, data in pairs(CDM.viewerMap) do
        local viewer = data.viewer
        if viewer and viewer.GetItemFrames then
            for _, item in ipairs(viewer:GetItemFrames()) do
                local itemSpellId = item.auraSpellID or (item.cooldownInfo and item.cooldownInfo.spellID)
                if itemSpellId == spellId then
                    local pi = item.PandemicIcon
                    if pi and pi.IsShown then
                        local ok, shown = pcall(pi.IsShown, pi)
                        return ok and shown == true
                    end
                    return false
                end
            end
        end
    end
    return false
end

-- [ START GLOW ]-----------------------------------------------------------------------------------
local function StartGlow(icon, glowType, colorTable)
    if glowType == GlowType.Pixel then
        local cfg = GlowConfig.Pixel
        LibCustomGlow.PixelGlow_Start(icon, colorTable, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, GLOW_KEY)
    elseif glowType == GlowType.Proc then
        local cfg = GlowConfig.Proc
        LibCustomGlow.ProcGlow_Start(icon, { color = colorTable, startAnim = cfg.StartAnim, frameLevel = cfg.FrameLevel, key = GLOW_KEY })
    elseif glowType == GlowType.AutoCast then
        local cfg = GlowConfig.AutoCast
        LibCustomGlow.AutoCastGlow_Start(icon, colorTable, cfg.NumParticles, cfg.Frequency, cfg.Size, cfg.Size, GLOW_KEY)
    elseif glowType == GlowType.Button then
        local cfg = GlowConfig.Button
        LibCustomGlow.ButtonGlow_Start(icon, colorTable, cfg.Frequency, cfg.FrameLevel)
    end
end

-- [ STOP GLOW ]------------------------------------------------------------------------------------
function PG:Stop(icon)
    if not icon or not LibCustomGlow then return end
    local active = icon.orbitPandemicGlowActive
    if not active then return end
    if active == GlowType.Pixel then LibCustomGlow.PixelGlow_Stop(icon, GLOW_KEY)
    elseif active == GlowType.Proc then LibCustomGlow.ProcGlow_Stop(icon, GLOW_KEY)
    elseif active == GlowType.AutoCast then LibCustomGlow.AutoCastGlow_Stop(icon, GLOW_KEY)
    elseif active == GlowType.Button then LibCustomGlow.ButtonGlow_Stop(icon) end
    icon.orbitPandemicGlowActive = nil
end

-- [ APPLY ]----------------------------------------------------------------------------------------
-- Called from AuraMixin:SetupAuraIcon on every UNIT_AURA rebuild.
-- Binary: create glow if in pandemic, stop if not. No alpha fighting.
function PG:Apply(icon, aura, unit, skinSettings)
    if not icon or not aura or not LibCustomGlow then return end
    local glowType = (skinSettings and skinSettings.pandemicGlowType) or GlowType.Pixel
    if glowType == GlowType.Blizzard then
        if icon.orbitPandemicGlowActive then self:Stop(icon) end
        return
    end
    -- Check Blizzard's CooldownViewer pandemic state for this spell
    if not IsSpellInPandemic(aura.spellId) then
        if icon.orbitPandemicGlowActive then self:Stop(icon) end
        return
    end
    -- In pandemic — start glow if not already active with same type
    if icon.orbitPandemicGlowActive == glowType then return end
    if icon.orbitPandemicGlowActive then self:Stop(icon) end
    local pandemicColor = (skinSettings and skinSettings.pandemicColor) or { r = 1, g = 0.8, b = 0 }
    local colorTable = { pandemicColor.r, pandemicColor.g, pandemicColor.b, 1 }
    StartGlow(icon, glowType, colorTable)
    icon.orbitPandemicGlowActive = glowType
end
