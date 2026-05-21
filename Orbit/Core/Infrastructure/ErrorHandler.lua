-- [ ORBIT ERROR HANDLER ]----------------------------------------------------------------------------
-- Trust-boundary error catcher: wraps plugin lifecycle / event callbacks so a single misbehaving
-- module can't take down the addon. Failures are printed to chat and ring-buffered in
-- the `OrbitErrorLogDB` SavedVariable so a corrupt log can't take down user settings.

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
        return success and result or nil
    end
end

function ErrorHandler:LogError(source, method, err)
    OrbitErrorLogDB = OrbitErrorLogDB or { entries = {}, index = 0 }
    OrbitErrorLogDB.entries = OrbitErrorLogDB.entries or {}
    OrbitErrorLogDB.index = OrbitErrorLogDB.index or 0

    local index = (OrbitErrorLogDB.index % MAX_ERRORS) + 1
    OrbitErrorLogDB.index = index
    OrbitErrorLogDB.entries[index] = {
        time = time(),
        date = date("%Y-%m-%d %H:%M:%S"),
        source = tostring(source),
        method = tostring(method),
        error = tostring(err),
    }
end
