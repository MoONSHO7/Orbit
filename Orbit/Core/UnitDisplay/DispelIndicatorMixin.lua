-- [ DISPEL INDICATOR MIXIN ]-------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable

Orbit.DispelIndicatorMixin = {}

-- [ DISPEL COLORS ] ---------------------------------------------------------------------------------
local DEFAULT_COLORS = {
    Magic = { r = 0.0, g = 0.4, b = 1.0, a = 1 },
    Curse = { r = 0.6, g = 0.0, b = 0.8, a = 1 },
    Disease = { r = 0.8, g = 0.4, b = 0.0, a = 1 },
    Poison = { r = 0.0, g = 0.7, b = 0.2, a = 1 },
    Bleed = { r = 0.9, g = 0.0, b = 0.0, a = 1 },
}

local DISPEL_TYPE_NAMES = { [1] = "Magic", [2] = "Curse", [3] = "Disease", [4] = "Poison", [9] = "Bleed", [11] = "Bleed" }
local DISPEL_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE"
local IsAuraFilteredOut = C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID

local DISPEL_ATLASES = {
    Magic = "icons_64x64_magic",
    Curse = "icons_64x64_curse",
    Disease = "icons_64x64_disease",
    Poison = "icons_64x64_poison",
    Bleed = "icons_64x64_bleed",
}
Orbit.DispelIconAtlases = DISPEL_ATLASES

-- GetAuraDispelTypeColor is SecretWhenUnitAuraRestricted, so its result is
-- a secret color in M+/raid encounters even with a non-secret curve. We
-- cannot do Lua-side arithmetic or comparisons on the channels. Instead we
-- stack one sub-texture per dispel type and drive each one's alpha through
-- a per-type curve that returns 1 only at that type's x value and 0 elsewhere.
-- SetAlpha accepts secret values, so the right icon "wins" via the C++ sink.
Orbit.DispelTypeOrder = {
    { typeNum = 1, name = "Magic",   atlas = DISPEL_ATLASES.Magic   },
    { typeNum = 2, name = "Curse",   atlas = DISPEL_ATLASES.Curse   },
    { typeNum = 3, name = "Disease", atlas = DISPEL_ATLASES.Disease },
    { typeNum = 4, name = "Poison",  atlas = DISPEL_ATLASES.Poison  },
    { typeNum = 9, name = "Bleed",   atlas = DISPEL_ATLASES.Bleed, altTypeNum = 11 },
}
local DISPEL_TYPE_ORDER = Orbit.DispelTypeOrder

local dispelTypeAlphaCurves
local function GetDispelTypeAlphaCurves()
    if dispelTypeAlphaCurves then return dispelTypeAlphaCurves end
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return nil end
    dispelTypeAlphaCurves = {}
    for _, entry in ipairs(DISPEL_TYPE_ORDER) do
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        for typeNum in pairs(DISPEL_TYPE_NAMES) do
            local match = typeNum == entry.typeNum or typeNum == entry.altTypeNum
            curve:AddPoint(typeNum, CreateColor(0, 0, 0, match and 1 or 0))
        end
        dispelTypeAlphaCurves[entry.name] = curve
    end
    return dispelTypeAlphaCurves
end

-- [ CACHED CURVE ]-----------------------------------------------------------------------------------
local function BuildDispelCurve(plugin)
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return nil end
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    for typeNum, typeName in pairs(DISPEL_TYPE_NAMES) do
        local c = plugin:GetSetting(1, "DispelColor" .. typeName) or DEFAULT_COLORS[typeName]
        if c then curve:AddPoint(typeNum, CreateColor(c.r, c.g, c.b, c.a or 1)) end
    end
    return curve
end

local function GetDispelCurve(plugin)
    if plugin._dispelCurveCache then return plugin._dispelCurveCache end
    local curve = BuildDispelCurve(plugin)
    plugin._dispelCurveCache = curve
    return curve
end

function Orbit.DispelIndicatorMixin:InvalidateDispelCurve(plugin)
    plugin._dispelCurveCache = nil
    plugin._dispelSettingsCache = nil
    if plugin.frames then
        for _, frame in ipairs(plugin.frames) do frame.orbitActiveDispelAura = nil end
    end
end

local function GetDispelSettings(plugin)
    local cache = plugin._dispelSettingsCache
    if cache then return cache end
    local get = plugin.GetTierSetting and function(k) return plugin:GetTierSetting(k) end or function(k) return plugin:GetSetting(1, k) end
    cache = {
        enabled = get("DispelIndicatorEnabled"),
        onlyByMe = get("DispelOnlyByMe"),
        glowType = get("DispelGlowType"),
        thickness = get("DispelThickness") or 2,
        frequency = get("DispelFrequency") or 0.25,
        numLines = get("DispelNumLines") or 8,
        length = get("DispelLength") or 15,
        border = get("DispelBorder")
    }
    if cache.border == nil then cache.border = true end
    plugin._dispelSettingsCache = cache
    return cache
end

local DISPEL_GLOW_KEY = "orbitDispel"

local function HideDispelIcon(frame)
    local icon = frame.DispelIcon
    if not icon then return end
    for _, t in pairs(icon._typeTextures) do t:SetAlpha(0) end
    icon:Hide()
end

local function ShowDispelIconForAura(frame, unit, auraInstanceID)
    local icon = frame.DispelIcon
    if not icon then return end
    local curves = GetDispelTypeAlphaCurves()
    if not curves or not C_UnitAuras.GetAuraDispelTypeColor then icon:Hide(); return end
    for _, entry in ipairs(DISPEL_TYPE_ORDER) do
        local color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, curves[entry.name])
        local _, _, _, a = color:GetRGBA()
        icon._typeTextures[entry.name]:SetAlpha(a)
    end
    icon:Show()
end

function Orbit.DispelIndicatorMixin:SetPreviewDispelType(frame, typeName)
    local icon = frame and frame.DispelIcon
    if not icon then return end
    if not typeName then
        for _, t in pairs(icon._typeTextures) do t:SetAlpha(0) end
        icon:Hide()
        return
    end
    for _, entry in ipairs(DISPEL_TYPE_ORDER) do
        icon._typeTextures[entry.name]:SetAlpha(entry.name == typeName and 1 or 0)
    end
    icon:Show()
end

local function IsDispelIconDisabled(plugin)
    return plugin.IsComponentDisabled and plugin:IsComponentDisabled("DispelIcon")
end

function Orbit.DispelIndicatorMixin:UpdateDispelIndicator(frame, plugin, harmfulAuras)
    if not frame or not frame.unit then return end
    local GC = Orbit.Engine.GlowController
    local settings = GetDispelSettings(plugin)
    local iconDisabled = IsDispelIconDisabled(plugin)
    if not settings.enabled then GC:Hide(frame, DISPEL_GLOW_KEY); HideDispelIcon(frame); return end
    local unit = frame.unit
    if not UnitExists(unit) then GC:Hide(frame, DISPEL_GLOW_KEY); HideDispelIcon(frame); return end
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuras then return end
    local auras = harmfulAuras or C_UnitAuras.GetUnitAuras(unit, "HARMFUL")
    if not auras or #auras == 0 then GC:Hide(frame, DISPEL_GLOW_KEY); HideDispelIcon(frame); return end
    local bestAuraInstanceID = nil
    for _, aura in ipairs(auras) do
        if aura.dispelName then
            if not settings.onlyByMe or (IsAuraFilteredOut and not IsAuraFilteredOut(unit, aura.auraInstanceID, DISPEL_FILTER)) then
                bestAuraInstanceID = aura.auraInstanceID
                break
            end
        end
    end
    if bestAuraInstanceID then
        local curve = GetDispelCurve(plugin)
        local color = curve and C_UnitAuras.GetAuraDispelTypeColor and C_UnitAuras.GetAuraDispelTypeColor(unit, bestAuraInstanceID, curve)
        if color then
            if frame.orbitActiveDispelAura ~= bestAuraInstanceID then
                local glowType = settings.glowType or Orbit.Constants.Glow.Type.Pixel
                local typeString = glowType == Orbit.Constants.Glow.Type.Autocast and "Autocast" or "Pixel"
                GC:Show(frame, DISPEL_GLOW_KEY, typeString, { key = DISPEL_GLOW_KEY, color = { color:GetRGBA() }, lines = settings.numLines, particles = settings.numLines, frequency = settings.frequency, length = settings.length, thickness = settings.thickness, border = settings.border, frameLevel = Orbit.Constants.Levels.DispelGlow })
                frame.orbitActiveDispelAura = bestAuraInstanceID
            end
            if iconDisabled then HideDispelIcon(frame) else ShowDispelIconForAura(frame, unit, bestAuraInstanceID) end
        else
            if frame.orbitActiveDispelAura then GC:Hide(frame, DISPEL_GLOW_KEY); frame.orbitActiveDispelAura = nil end
            HideDispelIcon(frame)
        end
    else
        if frame.orbitActiveDispelAura or frame.orbitActiveDispelAura == nil then
            GC:Hide(frame, DISPEL_GLOW_KEY)
            frame.orbitActiveDispelAura = false
        end
        HideDispelIcon(frame)
    end
end

-- [ UPDATE ALL FRAMES ] -----------------------------------------------------------------------------
function Orbit.DispelIndicatorMixin:UpdateAllDispelIndicators(plugin)
    if not plugin or not plugin.frames then return end
    for _, frame in ipairs(plugin.frames) do
        if frame and frame.unit then self:UpdateDispelIndicator(frame, plugin) end
    end
end

