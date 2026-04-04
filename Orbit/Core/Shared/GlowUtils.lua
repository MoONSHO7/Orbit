-- [ GLOW UTILS ]--------------------------------------------------------------------------------------
-- Utility for dynamically constructing LibOrbitGlow option tables from DB settings
local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants

Engine.GlowUtils = {}

--- Combines the active glow type with its dynamic parameters to produce a ready-to-use LibOrbitGlow arguments payload.
-- @param optionsLookup A table or function(key) that returns the requested setting value
-- @param prefix The settings string prefix (e.g. "PandemicGlow")
-- @param defaultColor Fallback color table if one is not configured (e.g. { r=1, g=1, b=1, a=1 })
-- @param key The rendering key that LCG will use to group/identify the glow
-- @return typeName (string|nil), optionsTable (table|nil)
function Engine.GlowUtils:BuildOptionsFromLookup(optionsLookup, prefix, defaultColor, key)
    local function GetValue(k)
        if type(optionsLookup) == "function" then return optionsLookup(k) end
        return optionsLookup[k]
    end

    local GlowType = Constants.Glow.Type
    local activeType = GetValue(prefix .. "Type")
    if activeType == nil then activeType = Constants.Glow.DefaultType end
    
    if activeType == GlowType.None or activeType == GlowType.Blizzard then return nil, nil end

    local color = GetValue(prefix .. "Color") or defaultColor
    if not color then color = Constants.Glow.DefaultColor end
    
    -- Ensure color uses standard r,g,b,a fields or unpacks RGBA cleanly for the library
    local colorArr = { color.r, color.g, color.b, color.a or 1 }
    
    local options = { color = colorArr, key = key }
    local typeName = ""

    local function Get(suffix, defVal)
        local v = GetValue(prefix .. suffix)
        if v == nil then return defVal end
        return v
    end

    if activeType == GlowType.Pixel then
        typeName = "Pixel"
        local def = Constants.Glow.Defaults.Pixel
        options.lines = Get("PixelLines", def.Lines)
        options.frequency = Get("PixelFrequency", def.Frequency)
        options.length = Get("PixelLength", def.Length)
        options.thickness = Get("PixelThickness", def.Thickness)
        options.xOffset = Get("PixelXOffset", def.XOffset)
        options.yOffset = Get("PixelYOffset", def.YOffset)
        options.border = Get("PixelBorder", def.Border)
    elseif activeType == GlowType.Medium then
        typeName = "Medium"
        local def = Constants.Glow.Defaults.Medium
        options.speed = Get("MediumSpeed", def.Speed)
    elseif activeType == GlowType.Autocast then
        typeName = "Autocast"
        local def = Constants.Glow.Defaults.Autocast
        options.particles = Get("AutocastParticles", def.Particles)
        options.frequency = Get("AutocastFrequency", def.Frequency)
    elseif activeType == GlowType.Classic then
        typeName = "Classic"
        local def = Constants.Glow.Defaults.Classic
        options.frequency = Get("ClassicFrequency", def.Frequency)
    elseif activeType == GlowType.Thin or activeType == GlowType.Thick then
        local defKey = (activeType == GlowType.Thin and "Thin") or "Thick"
        typeName = defKey
        local def = Constants.Glow.Defaults[defKey]
        options.speed = Get(defKey .. "Speed", def.Speed)
    elseif activeType == GlowType.Static then
        typeName = "Static"
    end

    -- Pixel padding: 0 = glow matches icon exactly, positive = extend outward
    options.padding = 0

    -- Preserve the raw active enum to be evaluated later (for blizzard check)
    options._glowTypeEnum = activeType

    return typeName, options
end

function Engine.GlowUtils:BuildOptions(plugin, systemIndex, prefix, defaultColor, key)
    return self:BuildOptionsFromLookup(function(k) return plugin:GetSetting(systemIndex, k) end, prefix, defaultColor, key)
end
