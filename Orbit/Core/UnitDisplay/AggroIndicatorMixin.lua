-- [ AGGRO INDICATOR MIXIN ]--------------------------------------------------------------------------
-- Shows tinted border overlay when unit has threat/aggro (PlayerFrame, PartyFrames, etc.)

local _, Orbit = ...

Orbit.AggroIndicatorMixin = {}

local AGGRO_STORAGE_KEY = "_aggroBorderOverlay"
local DEFAULT_AGGRO_COLOR = { r = 1.0, g = 0.0, b = 0.0, a = 1.0 }

local function GetAggroSettings(plugin)
    local cache = plugin._aggroSettingsCache
    if cache then return cache end
    local get = plugin.GetTierSetting and function(k) return plugin:GetTierSetting(k) end or function(k) return plugin:GetSetting(1, k) end
    local raw = get("AggroColor")
    local resolved = raw and Orbit.Engine.ColorCurve and Orbit.Engine.ColorCurve:GetFirstColorFromCurve(raw) or raw
    cache = {
        enabled = get("AggroIndicatorEnabled"),
        color = resolved or DEFAULT_AGGRO_COLOR,
    }
    plugin._aggroSettingsCache = cache
    return cache
end

function Orbit.AggroIndicatorMixin:UpdateAggroIndicator(frame, plugin)
    if not frame or not frame.unit then return end
    local settings = GetAggroSettings(plugin)
    if not settings.enabled then
        Orbit.Skin:ClearHighlightBorder(frame, AGGRO_STORAGE_KEY)
        return
    end
    if not UnitExists(frame.unit) then
        Orbit.Skin:ClearHighlightBorder(frame, AGGRO_STORAGE_KEY)
        return
    end
    if UnitThreatSituation(frame.unit) == 3 then
        Orbit.Skin:ApplyHighlightBorder(frame, AGGRO_STORAGE_KEY, settings.color)
    else
        Orbit.Skin:ClearHighlightBorder(frame, AGGRO_STORAGE_KEY)
    end
end

function Orbit.AggroIndicatorMixin:InvalidateAggroSettings(plugin)
    plugin._aggroSettingsCache = nil
end

function Orbit.AggroIndicatorMixin:UpdateAllAggroIndicators(plugin)
    if not plugin or not plugin.frames then return end
    for _, frame in ipairs(plugin.frames) do
        if frame and frame.unit then
            self:UpdateAggroIndicator(frame, plugin)
        end
    end
end

