-- [ GLOW UTILS ] ------------------------------------------------------------------------------------
-- Utility for dynamically constructing LibOrbitGlow option tables from DB settings
local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local LCG = LibStub("LibOrbitGlow-1.0", true)

-- Speed setting is a 0.5-1.5 multiplier (100% = natural). Flipbook duration = natural / multiplier, so higher % = faster.
local function ClampSpeed(m) return math.min(1.5, math.max(0.5, m or 1.0)) end

Engine.GlowUtils = {}

function Engine.GlowUtils:GetOptionsHash(options)
    if not options then return "" end
    local h = tostring(options.key or "")
    h = h .. "_" .. tostring(options.lines or "") .. "_" .. tostring(options.frequency or "")
    h = h .. "_" .. tostring(options.length or "") .. "_" .. tostring(options.thickness or "")
    h = h .. "_" .. tostring(options.speed or "") .. "_" .. tostring(options.particles or "")
    h = h .. "_" .. tostring(options.padding)
    h = h .. "_" .. tostring(options.pixelScale)
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

    -- A string Type is a registered pack glow -> play via lib.Proc (typeName = glow name). No glow if its pack isn't loaded.
    if type(activeType) == "string" then
        if not (LCG and LCG.IsGlowRegistered and LCG:IsGlowRegistered(activeType)) then return nil, nil, nil, true end
        local color = GetValue(prefix .. "Color") or defaultColor or Constants.Glow.DefaultColor
        local cr, cg, cb, ca = Engine.ClassColor:ResolveValueUnpacked(color)
        local options = { color = { cr, cg, cb, ca }, key = key, frameLevel = Constants.Levels.IconGlow, speed = 1.0 / ClampSpeed(GetValue(prefix .. "PackSpeed")) }
        return activeType, options, self:GetOptionsHash(options), true
    end

    local suppressNative = (activeType ~= GlowType.Blizzard)
    
    if activeType == GlowType.None then return nil, nil, nil, suppressNative end

    local color = GetValue(prefix .. "Color") or defaultColor
    if not color then color = Constants.Glow.DefaultColor end

    local cr, cg, cb, ca = Engine.ClassColor:ResolveValueUnpacked(color)
    local colorArr = { cr, cg, cb, ca }
    
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
        options.speed = def.Speed / ClampSpeed(Get("MediumSpeed", 1.0))
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
        options.speed = def.Speed / ClampSpeed(Get(defKey .. "Speed", 1.0))
    end

    -- Pixel padding: 0 = glow matches icon exactly, positive = extend outward
    options.padding = 0

    return typeName, options, self:GetOptionsHash(options), suppressNative
end

function Engine.GlowUtils:BuildOptions(plugin, systemIndex, prefix, defaultColor, key)
    return self:BuildOptionsFromLookup(function(k) return plugin:GetSetting(systemIndex, k) end, prefix, defaultColor, key)
end

