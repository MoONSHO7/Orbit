local _, addonTable = ...
local Orbit = addonTable

Orbit.Animation = {}

-------------------------------------------------
-- ApplyHoverFade (Centralized Fading Logic)
-------------------------------------------------
-- Handles Alpha transitions based on Mouse Over.
-- @param frame: The frame to control.
-- @param minAlpha: number (0-1). Resting alpha.
-- @param maxAlpha: number (0-1). Hover alpha.
-- @param editModeActive: boolean.
-- Internal storage for faders (Weak keys)
local faders = setmetatable({}, { __mode = "k" })

-- Combat-safe fade helper (uses SetAlpha directly instead of UIFrameFade which calls Show())
local function SafeFade(frame, targetAlpha, duration)
    -- During combat, just snap to target (UIFrameFadeIn/Out call Show() which is protected)
    if InCombatLockdown() then
        frame:SetAlpha(targetAlpha)
        return
    end

    -- Outside combat, use smooth fade
    local currentAlpha = frame:GetAlpha()
    if math.abs(currentAlpha - targetAlpha) < 0.01 then
        frame:SetAlpha(targetAlpha)
        return
    end

    if targetAlpha > currentAlpha then
        UIFrameFadeIn(frame, duration or 0.1, currentAlpha, targetAlpha)
    else
        UIFrameFadeOut(frame, duration or 0.2, currentAlpha, targetAlpha)
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
    if math.abs(minAlpha - maxAlpha) < 0.01 then
        if fader then
            fader:Hide()
        end
        if not InCombatLockdown() then
            UIFrameFadeRemoveFrame(frame)
        end
        frame:SetAlpha(maxAlpha)
        return
    end

    -- Create Fader if needed
    if not fader then
        fader = CreateFrame("Frame", nil, frame)
        faders[frame] = fader

        fader:SetScript("OnUpdate", function(self, elapsed)
            self.timer = (self.timer or 0) + elapsed
            if self.timer < 0.1 then
                return
            end
            self.timer = 0

            local parent = self:GetParent()
            if not parent:IsShown() then
                return
            end

            -- Check Mouse (Geometry Check)
            local isOver = MouseIsOver(parent)

            -- State Transition Logic
            if isOver and not self.isHovering then
                self.isHovering = true
                -- Fade In (combat-safe)
                SafeFade(parent, self.maxAlpha, 0.1)
            elseif not isOver and self.isHovering then
                self.isHovering = false
                -- Fade Out (combat-safe)
                SafeFade(parent, self.minAlpha, 0.2)
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
        SafeFade(frame, maxAlpha, 0.1)
    else
        -- Always apply minAlpha when not hovering (Opacity slider enforcement)
        frame:SetAlpha(minAlpha)
    end
end
