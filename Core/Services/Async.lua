local _, addonTable = ...
local Orbit = addonTable

---@class OrbitAsync
Orbit.Async = {}
local Async = Orbit.Async

-- Storage for active timers
local timers = {}
local lastRun = {}

--- Debounce: Delays execution until 'delay' seconds have passed since the last call.
-- Useful for events that fire rapidly (like bag updates) where you only want the final result.
-- @param key (string): Unique identifier for this task
-- @param func (function): The function to execute
-- @param delay (number): Seconds to wait (default 0.1)
function Async:Debounce(key, func, delay)
    delay = delay or 0.1

    -- Cancel existing timer for this key
    if timers[key] then
        timers[key]:Cancel()
    end

    -- Create new timer
    timers[key] = C_Timer.NewTimer(delay, function()
        timers[key] = nil
        if func then
            func()
        end
    end)
end

--- Throttle: Ensures execution happens at most once every 'interval' seconds.
-- Immediate execution on first call, subsequent calls dropped until cooldown resets.
-- @param key (string): Unique identifier
-- @param func (function): The function to execute
-- @param interval (number): Check interval
function Async:Throttle(key, func, interval)
    interval = interval or 0.1
    local now = GetTime()

    if not lastRun[key] or (now - lastRun[key] > interval) then
        lastRun[key] = now
        if func then
            func()
        end
    end
end

--- Clear a debounce timer (cancel pending execution)
-- @param key (string): Unique identifier to clear
function Async:ClearDebounce(key)
    if timers[key] then
        timers[key]:Cancel()
        timers[key] = nil
    end
end

--- Clear a throttle entry (allows immediate re-execution)
-- @param key (string): Unique identifier to clear
function Async:ClearThrottle(key)
    lastRun[key] = nil
end

--- Clear all async state (for cleanup on reload)
function Async:ClearAll()
    for key, timer in pairs(timers) do
        if timer then
            timer:Cancel()
        end
    end
    timers = {}
    lastRun = {}
end
