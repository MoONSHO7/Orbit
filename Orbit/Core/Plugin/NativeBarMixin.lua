-- [ ORBIT NATIVE BAR MIXIN ]-------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local math_max = math.max

Orbit.NativeBarMixin = {}
local Mixin = Orbit.NativeBarMixin

-- [ MOUSE-OVER FADE ]--------------------------------------------------------------------------------
function Mixin:ApplyMouseOver(frame, systemIndex)
    if not frame then return end
    local baseAlpha = 1
    local VE = Orbit.VisibilityEngine
    if VE then
        local veKey = VE:GetKeyForPlugin(self.name, systemIndex)
        if veKey then baseAlpha = (VE:GetFrameSetting(veKey, "opacity") or 100) / 100 end
    else
        baseAlpha = (self:GetSetting(systemIndex, "Opacity") or 100) / 100
    end
    Orbit.Animation:ApplyHoverFade(frame, baseAlpha, 1, Orbit:IsEditMode())
end

-- [ ORIENTATION ]------------------------------------------------------------------------------------
function Mixin:ApplyOrientation(frame, orientation, horizontalValue)
    if not frame then
        return
    end
    frame.isHorizontal = (orientation == (horizontalValue or 0))
end

-- [ LAYOUT TRIGGER ]---------------------------------------------------------------------------------
function Mixin:TriggerLayout(frame)
    if frame and frame.Layout then
        frame:Layout()
    end
end

-- [ NATIVE-PARENT CAPTURE ] -------------------------------------------------------------------------
-- Consolidates the BagBar / MicroMenu / QueueStatus capture pattern: only reparent the button when
-- it's currently parented to a native Blizzard container (or already to us); set `self.conflicted`
-- and bail when another addon has claimed it. Combat-lockdown guard stays at the caller (this helper
-- is pure parent-juggling).
function Mixin:CaptureFromNativeParent(button, allowedParents)
    if not button or not self.frame then return false end
    local parent = button:GetParent()
    if parent == self.frame then return true end
    for _, allowed in ipairs(allowedParents) do
        if parent == allowed then
            button:SetParent(self.frame)
            return true
        end
    end
    self.conflicted = true
    return false
end

