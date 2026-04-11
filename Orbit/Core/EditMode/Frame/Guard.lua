-- [ FRAME GUARD ]-----------------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine
local Guard = {}
Engine.FrameGuard = Guard

-- [ PROTECT ]---------------------------------------------------------------------------------------

function Guard:Protect(frame, parent)
    if not frame or not parent then return end
    frame._orbitGuardParent = parent

    if not frame._orbitGuardHooked then
        hooksecurefunc(frame, "SetParent", function(s, p)
            if s._orbitRestoring or s._orbitGuardSuspended then return end
            local intended = s._orbitGuardParent
            if intended and p ~= intended then
                s._orbitRestoring = true
                s:SetParent(intended)
                if s._orbitGuardOnRestore then s._orbitGuardOnRestore(s, intended) end
                s._orbitRestoring = false
            end
        end)

        frame:HookScript("OnHide", function(s)
            if s._orbitRestoring or s._orbitGuardSuspended then return end
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

-- [ SUSPEND / RESUME ]------------------------------------------------------------------------------
-- Temporarily disables guard enforcement (SetParent snap-back and enforce-show)
-- without removing the hooks. Used when a cooperating addon (e.g. FarmHud) needs
-- to reparent the minimap surface for its own overlay.

function Guard:Suspend(frame)
    if not frame then return end
    frame._orbitGuardSuspended = true
end

function Guard:Resume(frame)
    if not frame then return end
    frame._orbitGuardSuspended = nil
end

-- [ UPDATE ]----------------------------------------------------------------------------------------

function Guard:UpdateProtection(frame, parent, onRestoreFunc, options)
    if not frame then return end
    frame._orbitGuardParent = parent
    frame._orbitGuardOnRestore = onRestoreFunc
    if options then frame._orbitGuardEnforceShow = options.enforceShow end
end
