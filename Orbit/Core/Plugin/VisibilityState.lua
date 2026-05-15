-- [ ORBIT VISIBILITY STATE ]-------------------------------------------------------------------------
-- RegisterStateDriver, UnregisterStateDriver, and frame:Show are combat-locked, so the entire
-- ApplyState body is deferred via CombatManager when combat is active to keep the driver cache in
-- sync with the actual secure state.

local _, Orbit = ...

Orbit.Visibility = {}

function Orbit.Visibility:ApplyState(frame, visibilityMode)
    if InCombatLockdown() then
        if Orbit.CombatManager then
            Orbit.CombatManager:QueueUpdate(function()
                Orbit.Visibility:ApplyState(frame, visibilityMode)
            end)
        end
        return
    end

    if frame.isOrbitUpdating then return end
    frame.isOrbitUpdating = true

    local driver
    if Orbit:IsEditMode() then
        driver = "show"
        frame:SetAlpha(1)
        frame.orbitLastVisibilityDriver = nil
    else
        local vis = visibilityMode or 0
        if vis == 3 then
            driver = "hide"
        elseif vis == 1 then
            driver = "[combat] show; hide"
        elseif vis == 2 then
            driver = "[combat] hide; show"
        else
            driver = "show"
        end
    end

    if frame.orbitLastVisibilityDriver == driver then
        frame.isOrbitUpdating = false
        return
    end
    frame.orbitLastVisibilityDriver = driver

    if driver then
        RegisterStateDriver(frame, "visibility", driver)
    else
        UnregisterStateDriver(frame, "visibility")
        frame:Show()
    end

    frame.isOrbitUpdating = false
end
