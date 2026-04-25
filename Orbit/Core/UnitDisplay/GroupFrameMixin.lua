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
        frame:SetAlpha(GF.OutOfRangeAlpha)
        Mixin.SetBackgroundAlpha(frame, 1)
    else
        local inRangeValue = UnitInRange(frame.unit)
        frame:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(inRangeValue, 1, GF.OutOfRangeAlpha))
        Mixin.SetBackgroundAlpha(frame, C_CurveUtil.EvaluateColorValueFromBoolean(inRangeValue, 1, 0))
    end
    if frame.ApplyHealthColor then frame:ApplyHealthColor() end
end
