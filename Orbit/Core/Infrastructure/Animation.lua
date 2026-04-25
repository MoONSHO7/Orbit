local _, addonTable = ...
local Orbit = addonTable
local math_abs = math.abs
local InCombatLockdown = InCombatLockdown

Orbit.Animation = {}

local ALPHA_EPSILON = 0.01
local FADE_IN_DURATION = 0.1
local FADE_OUT_DURATION = 0.2
local HOVER_CHECK_INTERVAL = 0.1

-- [ HOVER FADE ]-------------------------------------------------------------------------------------
local faders = setmetatable({}, { __mode = "k" })

-- Combat-safe fade helper
local function SafeFade(frame, targetAlpha, duration)
    -- During combat, just snap to target (UIFrameFadeIn/Out call Show() which is protected)
    if InCombatLockdown() then
        frame:SetAlpha(targetAlpha)
        return
    end

    local currentAlpha = frame:GetAlpha()
    if math_abs(currentAlpha - targetAlpha) < ALPHA_EPSILON then
        frame:SetAlpha(targetAlpha)
        return
    end

    if targetAlpha > currentAlpha then
        UIFrameFadeIn(frame, duration or FADE_IN_DURATION, currentAlpha, targetAlpha)
    else
        UIFrameFadeOut(frame, duration or FADE_OUT_DURATION, currentAlpha, targetAlpha)
    end
end

function Orbit.Animation:ApplyHoverFade(frame, minAlpha, maxAlpha, editModeActive)
    -- Validate frame is a real frame object with required methods
    if not frame or not frame.SetAlpha then
        return
    end

    -- Defaults
    minAlpha = minAlpha or 1
    maxAlpha = maxAlpha or 1

    local fader = faders[frame]

    -- Edit Mode Override: Always show full (or max)
    if editModeActive then
        if fader then
            fader:Hide()
        end
        if not InCombatLockdown() then
            UIFrameFadeRemoveFrame(frame)
        end
        frame:SetAlpha(1)
        return
    end

    -- Optimization: If min == max, disable fader and set static
    if math_abs(minAlpha - maxAlpha) < ALPHA_EPSILON then
        if fader then
            fader:Hide()
        end
        if not InCombatLockdown() then
            UIFrameFadeRemoveFrame(frame)
        end
        frame:SetAlpha(maxAlpha)
        return
    end

    -- Create Fader if needed (parented to UIParent to avoid corrupting LayoutFrame sizing)
    if not fader then
        fader = CreateFrame("Frame", nil, UIParent)
        fader.orbitTarget = frame
        faders[frame] = fader

        fader:SetScript("OnUpdate", function(self, elapsed)
            self.timer = (self.timer or 0) + elapsed
            if self.timer < HOVER_CHECK_INTERVAL then
                return
            end
            self.timer = 0

            local target = self.orbitTarget
            if not target:IsShown() or target.orbitMountedSuppressed then
                return
            end

            -- Check Mouse (Geometry Check)
            local isOver = MouseIsOver(target)

            -- State Transition Logic
            if isOver and not self.isHovering then
                self.isHovering = true
                -- Fade In (combat-safe)
                SafeFade(target, self.maxAlpha, FADE_IN_DURATION)
            elseif not isOver and self.isHovering then
                self.isHovering = false
                -- Fade Out (combat-safe)
                SafeFade(target, self.minAlpha, FADE_OUT_DURATION)
            end
        end)
    end

    -- Update targets on the fader for dynamic updates
    fader.minAlpha = minAlpha
    fader.maxAlpha = maxAlpha
    fader:Show()

    -- Initial State Check
    local isOver = MouseIsOver(frame)
    fader.isHovering = isOver

    if isOver then
        SafeFade(frame, maxAlpha, FADE_IN_DURATION)
    else
        -- Always apply minAlpha when not hovering (Opacity slider enforcement)
        frame:SetAlpha(minAlpha)
    end
end

function Orbit.Animation:StopHoverFade(frame)
    if not frame then return end
    local fader = faders[frame]
    if fader then
        fader:Hide()
        fader.isHovering = false
        fader.timer = 0
    end
    if not InCombatLockdown() then UIFrameFadeRemoveFrame(frame) end
end
