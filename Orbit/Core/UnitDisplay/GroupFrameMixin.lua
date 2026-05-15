-- [ GROUP FRAME MIXIN ]------------------------------------------------------------------------------
-- Shared utilities for group frame domains (Party, Raid, Boss)

local _, Orbit = ...
local GF = Orbit.Constants.GroupFrames

Orbit.GroupFrameMixin = {}
local Mixin = Orbit.GroupFrameMixin

-- [ SAFE UNIT WATCH ]--------------------------------------------------------------------------------
function Mixin.SafeRegisterUnitWatch(frame)
    if not frame then return end
    Orbit:SafeAction(function() RegisterUnitWatch(frame) end)
end

function Mixin.SafeUnregisterUnitWatch(frame)
    if not frame then return end
    Orbit:SafeAction(function() UnregisterUnitWatch(frame) end)
end

-- [ STATUS DISPATCH ]--------------------------------------------------------------------------------
function Mixin.StatusDispatch(frame, plugin, method)
    plugin[method](plugin, frame, plugin)
end

-- [ RANGE CHECKING ]---------------------------------------------------------------------------------
function Mixin.SetBackgroundAlpha(frame, alpha)
    if frame.bg then frame.bg:SetAlpha(alpha) end
    if frame._gradientSegments then
        for _, seg in ipairs(frame._gradientSegments) do seg:SetAlpha(alpha) end
    end
end

-- Resolves the out-of-range alpha from the plugin's tier setting (Group Frames) and falls back to the global constant for plugins without tiers (Boss Frames).
local function ResolveOutOfRangeAlpha(frame)
    local plugin = frame.orbitPlugin
    if plugin and plugin.GetTierSetting then
        local opacity = plugin:GetTierSetting("OutOfRangeOpacity")
        if opacity then return opacity / 100 end
    end
    return GF.OutOfRangeAlpha
end

function Mixin.UpdateInRange(frame)
    if not frame or not frame.unit then return end
    if not UnitExists(frame.unit) then frame:SetAlpha(0); return end
    if frame.isPlayerFrame or frame.preview then
        frame:SetAlpha(1)
        Mixin.SetBackgroundAlpha(frame, 1)
    elseif not UnitIsConnected(frame.unit) then
        frame:SetAlpha(GF.OfflineAlpha)
        Mixin.SetBackgroundAlpha(frame, 1)
    elseif UnitPhaseReason(frame.unit) then
        frame:SetAlpha(ResolveOutOfRangeAlpha(frame))
        Mixin.SetBackgroundAlpha(frame, 1)
    else
        local inRangeValue = UnitInRange(frame.unit)
        local oorAlpha = ResolveOutOfRangeAlpha(frame)
        frame:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(inRangeValue, 1, oorAlpha))
        Mixin.SetBackgroundAlpha(frame, C_CurveUtil.EvaluateColorValueFromBoolean(inRangeValue, 1, 0))
    end
    frame:ApplyHealthColor()
end
