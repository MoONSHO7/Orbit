---@type Orbit
local Orbit = Orbit
local Plugin = Orbit:GetPlugin("Status Bar v2")

-- [ ANIMATION ]--------------------------------------------------------------------------------------
-- Hover/event reveal for the orb (Off / Slide / Rotate Slide / Fade), modelled on Orbit-Dock-Portal's
-- reveal. While an animation is on, the orb is CONCEALED at rest and reveals on mouseover or a toast,
-- then reverses (conceals) on mouse-leave / event end. It animates frame.Content, never the frame, so the
-- EditMode / RestorePosition-owned anchor is untouched. The slide direction is screen-edge aware.
local ANIM_NONE, ANIM_SLIDE, ANIM_ROTATE, ANIM_FADE = 0, 1, 2, 3
local ANIM_DURATION = 0.3
local MAX_SPIN = math.rad(150)   -- rotate-slide spins this far while concealed, unwinding to 0 at rest
local EDGE_FRAC = 1 / 3          -- centre within this fraction of a screen edge => slide in from it
local EPSILON = 0.01
local math_min, math_max, math_abs = math.min, math.max, math.abs

-- Which way the orb slides off when concealed: toward its nearest screen edge/corner (y is up in WoW, so
-- "near the top" hides upward). Dead-centre hides downward.
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

-- progress 1 = revealed (at rest, fully shown), 0 = concealed (slid off / rotated / alpha 0). Re-anchors
-- the content each frame so a mode switch never strands a stale offset/rotation.
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

-- True while the Rotate-Slide reveal owns the ring textures' rotation, so other effects (the impact shake)
-- must not also write SetRotation on them or the two drivers fight over the same five textures.
function Plugin:_RotateRevealOwnsRing()
    return self._animMode == ANIM_ROTATE
end

-- Where the orb should rest right now: revealed (1) while Off, in Edit Mode, hovered, or showing a toast;
-- concealed (0) otherwise.
local function RestingTarget(plugin)
    local mode = plugin:GetSetting(plugin.system, "Animation") or ANIM_NONE
    if mode == ANIM_NONE or Orbit:IsEditMode() then return 1 end
    if plugin._hovered or plugin._event ~= nil then return 1 end
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

-- Snap (no tween) to the resting state — called from ApplySettings so the orb starts concealed when an
-- animation is active, and is shown again the instant it's set back to Off.
function Plugin:ApplyAnimationState()
    if not self.frame then return end
    self._animMode = self:GetSetting(self.system, "Animation") or ANIM_NONE
    self._animOX, self._animOY = HiddenOffset(self.frame)
    self._animProgress = RestingTarget(self)
    self._animTarget = self._animProgress
    if self._animDriver then self._animDriver:Hide() end
    self:_AnimApply(self._animProgress)
end
