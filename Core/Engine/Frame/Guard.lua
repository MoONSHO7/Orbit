local _, Orbit = ...
local Engine = Orbit.Engine
local Guard = {}
Engine.FrameGuard = Guard

-- [ FRAME GUARD ]---------------------------------------------------------------------------------------
-- Protects frames from being "stolen" (reparented) or hidden by external UI logic (e.g. Blizzard PRD)
-- This is critical for frames that occupy the same "slot" as native elements but must remain static.

function Guard:Protect(frame, parent)
    if not frame or not parent then
        return
    end

    -- Store the intended parent
    frame._orbitGuardParent = parent

    -- 1. Hook SetParent to prevent stealing
    -- Secure hook allows us to react immediately after the parent changes
    -- We use a re-entrancy guard (_orbitRestoring) to call SetParent again without looping
    if not frame._orbitGuardHooked then
        hooksecurefunc(frame, "SetParent", function(s, p)
            if s._orbitRestoring then
                return
            end

            local intended = s._orbitGuardParent
            if intended and p ~= intended then
                -- Check if we are "in guard mode" (Orbit controlling)
                -- We assume if Protect() was called, we want to enforce it always
                -- Logic: If parent changed to something ELSE, revert it.

                s._orbitRestoring = true
                s:SetParent(intended)

                if s._orbitGuardOnRestore then
                    s._orbitGuardOnRestore(s, intended)
                end

                s._orbitRestoring = false
            end
        end)

        -- 2. Hook OnHide to prevent hiding
        frame:HookScript("OnHide", function(s)
            if s._orbitRestoring then
                return
            end

            if s._orbitGuardEnforceShow then
                s._orbitRestoring = true
                s:Show()
                s:SetAlpha(1)
                s._orbitRestoring = false
            end
        end)

        frame._orbitGuardHooked = true
    end
end

-- Update protection settings (parent, callback, options)
function Guard:UpdateProtection(frame, parent, onRestoreFunc, options)
    if not frame then
        return
    end
    frame._orbitGuardParent = parent
    frame._orbitGuardOnRestore = onRestoreFunc
    if options then
        frame._orbitGuardEnforceShow = options.enforceShow
    end
end
