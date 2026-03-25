-- [ DISPEL INDICATOR MIXIN ]------------------------------------------------------------------------
-- Shared dispel glow indicator for group frames (Party, Raid)

local _, addonTable = ...
local Orbit = addonTable
local LCG = LibStub("LibCustomGlow-1.0")

Orbit.DispelIndicatorMixin = {}

-- [ DISPEL COLORS ]--------------------------------------------------------------------------------
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

-- [ CACHED CURVE ]----------------------------------------------------------------------------------
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
end

local function GetDispelSettings(plugin)
    local cache = plugin._dispelSettingsCache
    if cache then return cache end
    local get = plugin.GetTierSetting and function(k) return plugin:GetTierSetting(k) end or function(k) return plugin:GetSetting(1, k) end
    cache = {
        enabled = get("DispelIndicatorEnabled"),
        onlyByMe = get("DispelOnlyByMe"),
        thickness = get("DispelThickness") or 2,
        frequency = get("DispelFrequency") or 0.25,
        numLines = get("DispelNumLines") or 8,
    }
    plugin._dispelSettingsCache = cache
    return cache
end

-- [ UPDATE DISPEL INDICATOR ]----------------------------------------------------------------------
-- harmfulAuras: optional pre-fetched table from snapshot to avoid duplicate GetUnitAuras call
function Orbit.DispelIndicatorMixin:UpdateDispelIndicator(frame, plugin, harmfulAuras)
    if not frame or not frame.unit then return end
    local settings = GetDispelSettings(plugin)
    if not settings.enabled then LCG.PixelGlow_Stop(frame); return end
    local unit = frame.unit
    if not UnitExists(unit) then LCG.PixelGlow_Stop(frame); return end
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuras then return end
    local auras = harmfulAuras or C_UnitAuras.GetUnitAuras(unit, "HARMFUL")
    if not auras or #auras == 0 then LCG.PixelGlow_Stop(frame); return end

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
            LCG.PixelGlow_Start(frame, color, settings.numLines, settings.frequency, nil, settings.thickness, 0, 0, true, nil, Orbit.Constants.Levels.Border)
        else
            LCG.PixelGlow_Stop(frame)
        end
    else
        LCG.PixelGlow_Stop(frame)
    end
end

-- [ UPDATE ALL FRAMES ]----------------------------------------------------------------------------
function Orbit.DispelIndicatorMixin:UpdateAllDispelIndicators(plugin)
    if not plugin or not plugin.frames then return end
    for _, frame in ipairs(plugin.frames) do
        if frame and frame.unit then self:UpdateDispelIndicator(frame, plugin) end
    end
end

