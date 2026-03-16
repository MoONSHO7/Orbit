-- [ AGGRO INDICATOR MIXIN ]-------------------------------------------------------------------------
-- Shows tinted border overlay when unit has threat/aggro (PlayerFrame, PartyFrames, etc.)

local _, Orbit = ...

Orbit.AggroIndicatorMixin = {}

local AGGRO_STORAGE_KEY = "_aggroBorderOverlay"

function Orbit.AggroIndicatorMixin:UpdateAggroIndicator(frame, plugin)
    if not frame or not frame.unit then return end
    local enabled = plugin:GetSetting(1, "AggroIndicatorEnabled")
    if not enabled then
        Orbit.Skin:ClearHighlightBorder(frame, AGGRO_STORAGE_KEY)
        return
    end
    if not UnitExists(frame.unit) then
        Orbit.Skin:ClearHighlightBorder(frame, AGGRO_STORAGE_KEY)
        return
    end
    local hasAggro = UnitThreatSituation(frame.unit) == 3
    if hasAggro then
        local color = plugin:GetSetting(1, "AggroColor") or { r = 1.0, g = 0.0, b = 0.0, a = 1.0 }
        Orbit.Skin:ApplyHighlightBorder(frame, AGGRO_STORAGE_KEY, color)
    else
        Orbit.Skin:ClearHighlightBorder(frame, AGGRO_STORAGE_KEY)
    end
end

function Orbit.AggroIndicatorMixin:UpdateAllAggroIndicators(plugin)
    if not plugin or not plugin.frames then return end
    for _, frame in ipairs(plugin.frames) do
        if frame and frame.unit then
            self:UpdateAggroIndicator(frame, plugin)
        end
    end
end

