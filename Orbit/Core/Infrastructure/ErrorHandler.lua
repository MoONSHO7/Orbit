-- [ ORBIT ERROR HANDLER ]----------------------------------------------------------------------------
-- Trust-boundary error catcher: wraps plugin lifecycle / event callbacks so a single misbehaving
-- module can't take down the addon. Failures are printed to chat and ring-buffered in
-- `Orbit.db.ErrorLog` (viewable in-game).

local _, Orbit = ...

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local MAX_ERRORS = 50

-- [ ERROR HANDLER ]----------------------------------------------------------------------------------
Orbit.ErrorHandler = {}
local ErrorHandler = Orbit.ErrorHandler

function ErrorHandler:Wrap(func, context)
    return function(...)
        local success, result = pcall(func, ...)
        if not success then
            local contextStr = context or "Unknown"
            Orbit:Print("|cFFFF0000ERROR:|r", contextStr, "-", tostring(result))
            self:LogError(contextStr, "wrapped_call", result)
        end
        return result
    end
end

function ErrorHandler:LogError(source, method, err)
    if not Orbit.db then return end
    if not Orbit.db.ErrorLog then
        Orbit.db.ErrorLog = {}
        Orbit.db.ErrorLogIndex = 0
    end

    local index = (Orbit.db.ErrorLogIndex % MAX_ERRORS) + 1
    Orbit.db.ErrorLogIndex = index
    Orbit.db.ErrorLog[index] = {
        time = time(),
        date = date("%Y-%m-%d %H:%M:%S"),
        source = tostring(source),
        method = tostring(method),
        error = tostring(err),
    }
end
