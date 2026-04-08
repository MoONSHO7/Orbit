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
-- @return typeName (string|nil), optionsTable (table|nil), optionsHash (string|nil), suppressNative (boolean)
function Engine.GlowUtils:GetOptionsHash(options)
    if not options then return "" end
    local h = tostring(options.key or "")
    h = h .. "_" .. tostring(options.lines or "") .. "_" .. tostring(options.frequency or "")
    h = h .. "_" .. tostring(options.length or "") .. "_" .. tostring(options.thickness or "")
    h = h .. "_" .. tostring(options.speed or "") .. "_" .. tostring(options.particles or "")
    h = h .. "_" .. tostring(options.reverse) .. "_" .. tostring(options.padding)
    if options.color then
        local c1, c2, c3, c4 = options.color[1] or 1, options.color[2] or 1, options.color[3] or 1, options.color[4] or 1
        if issecretvalue(c1) then h = h .. "_secret" else h = h .. string.format("_%.2f_%.2f_%.2f_%.2f", c1, c2, c3, c4) end
    end
    return h
end

function Engine.GlowUtils:BuildOptionsFromLookup(optionsLookup, prefix, defaultColor, key)
    local function GetValue(k)
        if type(optionsLookup) == "function" then return optionsLookup(k) end
        return optionsLookup[k]
    end

    local GlowType = Constants.Glow.Type
    local activeType = GetValue(prefix .. "Type")
    if activeType == nil then activeType = Constants.Glow.DefaultType end
    
    local suppressNative = (activeType ~= GlowType.Blizzard)
    
    if activeType == GlowType.None then return nil, nil, nil, suppressNative end

    local color = GetValue(prefix .. "Color") or defaultColor
    if not color then color = Constants.Glow.DefaultColor end
    
    -- Ensure color uses standard r,g,b,a fields or unpacks RGBA cleanly for the library
    local colorArr = { color.r, color.g, color.b, color.a or 1 }
    
    local options = { color = colorArr, key = key, frameLevel = Constants.Levels.IconGlow }
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
        options.frequency = math.min(Get("PixelFrequency", def.Frequency), 0.20)
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
    end

    -- Reverse: user setting inverts the default rotation direction
    options.reverse = Get(prefix .. "Reverse", false) or false

    -- Pixel padding: 0 = glow matches icon exactly, positive = extend outward
    options.padding = 0

    return typeName, options, self:GetOptionsHash(options), suppressNative
end

function Engine.GlowUtils:BuildOptions(plugin, systemIndex, prefix, defaultColor, key)
    return self:BuildOptionsFromLookup(function(k) return plugin:GetSetting(systemIndex, k) end, prefix, defaultColor, key)
end

