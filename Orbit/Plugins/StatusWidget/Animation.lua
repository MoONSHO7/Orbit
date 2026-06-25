---@type Orbit
local Orbit = Orbit
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ ANIMATION ]--------------------------------------------------------------------------------------
local ANIM_NONE, ANIM_SLIDE, ANIM_ROTATE, ANIM_FADE = 0, 1, 2, 3
local ANIM_DURATION = 0.3
local MAX_SPIN = math.rad(150)   -- rotate-slide spins this far while concealed, unwinding to 0 at rest
local EDGE_FRAC = 1 / 3          -- centre within this fraction of a screen edge => slide in from it
local EPSILON = 0.01
local math_min, math_max, math_abs = math.min, math.max, math.abs

-- Slides off toward the nearest screen edge/corner; y is up in WoW so near-top hides upward, dead-centre hides downward.
local function HiddenOffset(frame)
    local cx, cy = frame:GetCenter()
    if not cx then return 0, -frame:GetHeight() end
    local fs = frame:GetEffectiveScale()
    local px, py = cx * fs, cy * fs
    local sw = UIParent:GetWidth() * UIParent:GetEffectiveScale()
    local sh = UIParent:GetHeight() * UIParent:GetEffectiveScale()
    local w, h = frame:GetWidth(), frame:GetHeight()
    local ox, oy = 0, 0
    if px < sw * EDGE_FRAC then ox = -w
    elseif px > sw * (1 - EDGE_FRAC) then ox = w end
    if py > sh * (1 - EDGE_FRAC) then oy = h
    elseif py < sh * EDGE_FRAC then oy = -h end
    if ox == 0 and oy == 0 then oy = -h end
    return ox, oy
end

function Plugin:_AnimApply(progress)
    local frame = self.frame
    local content = frame.Content
    content:ClearAllPoints()
    if self._animMode == ANIM_NONE then
        content:SetAllPoints(frame)
        content:SetAlpha(1)
        return
    end
    if self._animMode == ANIM_FADE then
        content:SetAllPoints(frame)
        content:SetAlpha(progress)
        return
    end
    local concealed = 1 - progress
    local ox, oy = self._animOX * concealed, self._animOY * concealed
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", ox, oy)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", ox, oy)
    content:SetAlpha(progress)
    if self._animMode == ANIM_ROTATE then
        local a = concealed * MAX_SPIN
        frame.Track:SetRotation(a)
        frame.BackdropRing:SetRotation(a)
        frame.Border:SetRotation(a)
        frame.Fill:SetRotation(frame._fillRotation + a)
        frame.RestedFill:SetRotation(frame._fillRotation + a)
    end
end

-- True while Rotate-Slide owns the ring rotation, so the impact shake doesn't also SetRotation and fight over the same textures.
function Plugin:_RotateRevealOwnsRing()
    return self._animMode == ANIM_ROTATE
end

local function RestingTarget(plugin)
    local mode = plugin:GetSetting(plugin.system, "Animation") or ANIM_NONE
    if mode == ANIM_NONE or Orbit:IsEditMode() then return 1 end
    if plugin._hovered or plugin._event ~= nil or plugin._mplusActive or plugin._mplusResults then return 1 end
    return 0
end

local function EnsureDriver(plugin)
    if plugin._animDriver then return plugin._animDriver end
    local d = CreateFrame("Frame", nil, UIParent)
    d:Hide()
    d:SetScript("OnUpdate", function(self, elapsed)
        local step, t = elapsed / ANIM_DURATION, plugin._animTarget
        local p = plugin._animProgress
        p = (p < t) and math_min(t, p + step) or math_max(t, p - step)
        plugin._animProgress = p
        plugin:_AnimApply(p)
        if math_abs(p - t) < EPSILON then
            plugin._animProgress = t
            plugin:_AnimApply(t)
            self:Hide()
        end
    end)
    plugin._animDriver = d
    return d
end

local function Tween(plugin, target)
    if not plugin.frame then return end
    plugin._animMode = plugin:GetSetting(plugin.system, "Animation") or ANIM_NONE
    plugin._animOX, plugin._animOY = HiddenOffset(plugin.frame)   -- recompute: the orb may have moved
    plugin._animProgress = plugin._animProgress or 1
    plugin._animTarget = target
    if math_abs(plugin._animProgress - target) < EPSILON then
        plugin._animProgress = target
        plugin:_AnimApply(target)
        if plugin._animDriver then plugin._animDriver:Hide() end
        return
    end
    EnsureDriver(plugin):Show()
end

-- OnEnter / a toast: animate in.
function Plugin:RevealOrb()
    Tween(self, 1)
end

-- OnLeave / event end: animate back to the resting state (concealed unless still hovered / in a toast).
function Plugin:ConcealOrb()
    Tween(self, RestingTarget(self))
end

function Plugin:ApplyAnimationState()
    if not self.frame then return end
    self._animMode = self:GetSetting(self.system, "Animation") or ANIM_NONE
    self._animOX, self._animOY = HiddenOffset(self.frame)
    self._animProgress = RestingTarget(self)
    self._animTarget = self._animProgress
    if self._animDriver then self._animDriver:Hide() end
    self:_AnimApply(self._animProgress)
end
