local _, addonTable = ...
local Orbit = addonTable

---@class OrbitAsync
Orbit.Async = {}
local Async = Orbit.Async

-- Storage for active timers
local timers = {}
local lastRun = {}

-- Cleanup configuration
local CLEANUP_INTERVAL = 60    -- Run cleanup every 60 seconds
local STALE_THRESHOLD = 60     -- Remove entries older than 60 seconds
local MIN_ENTRIES_FOR_CLEANUP = 10  -- Only cleanup if table has this many entries

-- Periodic cleanup to prevent unbounded lastRun growth
local function CleanupStaleEntries()
    local count = 0
    for _ in pairs(lastRun) do
        count = count + 1
        if count >= MIN_ENTRIES_FOR_CLEANUP then break end
    end
    
    -- Only run full cleanup if we have enough entries
    if count >= MIN_ENTRIES_FOR_CLEANUP then
        local now = GetTime()
        local threshold = now - STALE_THRESHOLD
        for key, timestamp in pairs(lastRun) do
            if timestamp < threshold then
                lastRun[key] = nil
            end
        end
    end
end

-- Start cleanup ticker (runs once table is first used)
local cleanupTicker
local function EnsureCleanupRunning()
    if not cleanupTicker then
        cleanupTicker = C_Timer.NewTicker(CLEANUP_INTERVAL, CleanupStaleEntries)
    end
end

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

    -- Ensure cleanup is running (lazy start)
    EnsureCleanupRunning()

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
    
    -- Stop cleanup ticker if running
    if cleanupTicker then
        cleanupTicker:Cancel()
        cleanupTicker = nil
    end
end

