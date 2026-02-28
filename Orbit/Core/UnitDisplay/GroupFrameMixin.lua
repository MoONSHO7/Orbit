-- [ GROUP FRAME MIXIN ]-----------------------------------------------------------------------------
-- Shared utilities for group frame domains (Party, Raid, Boss)

local _, Orbit = ...
local GF = Orbit.Constants.GroupFrames

Orbit.GroupFrameMixin = {}
local Mixin = Orbit.GroupFrameMixin

-- [ SAFE UNIT WATCH ]-------------------------------------------------------------------------------
function Mixin.SafeRegisterUnitWatch(frame)
    if not frame then return end
    Orbit:SafeAction(function() RegisterUnitWatch(frame) end)
end

function Mixin.SafeUnregisterUnitWatch(frame)
    if not frame then return end
    Orbit:SafeAction(function() UnregisterUnitWatch(frame) end)
end

-- [ STATUS DISPATCH ]-------------------------------------------------------------------------------
function Mixin.StatusDispatch(frame, plugin, method)
    plugin[method](plugin, frame, plugin)
end

-- [ RANGE CHECKING ]--------------------------------------------------------------------------------
function Mixin.UpdateInRange(frame)
    if not frame or not frame.unit then return end
    if frame.isPlayerFrame or frame.preview then frame:SetAlpha(1); return end
    if not UnitIsConnected(frame.unit) then frame:SetAlpha(GF.OfflineAlpha); return end
    if UnitPhaseReason(frame.unit) then frame:SetAlpha(GF.OutOfRangeAlpha); return end
    frame:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(UnitInRange(frame.unit), 1, GF.OutOfRangeAlpha))
end
