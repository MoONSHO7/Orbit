local _, addonTable = ...
local Orbit = addonTable

---@class OrbitAsync
Orbit.Async = {}
local Async = Orbit.Async

local timers, lastRun = {}, {}
local CLEANUP_INTERVAL, STALE_THRESHOLD, MIN_ENTRIES_FOR_CLEANUP = 60, 60, 10

local function CleanupStaleEntries()
    local count = 0
    for _ in pairs(lastRun) do
        count = count + 1
        if count >= MIN_ENTRIES_FOR_CLEANUP then
            break
        end
    end
    if count >= MIN_ENTRIES_FOR_CLEANUP then
        local threshold = GetTime() - STALE_THRESHOLD
        for key, timestamp in pairs(lastRun) do
            if timestamp < threshold then
                lastRun[key] = nil
            end
        end
    end
end

local cleanupTicker
local function EnsureCleanupRunning()
    if not cleanupTicker then
        cleanupTicker = C_Timer.NewTicker(CLEANUP_INTERVAL, CleanupStaleEntries)
    end
end

function Async:Debounce(key, func, delay)
    delay = delay or 0.1
    if timers[key] then
        timers[key]:Cancel()
    end
    timers[key] = C_Timer.NewTimer(delay, function()
        timers[key] = nil
        if func then
            func()
        end
    end)
end

function Async:Throttle(key, func, interval)
    interval = interval or 0.1
    EnsureCleanupRunning()
    local now = GetTime()
    if not lastRun[key] or (now - lastRun[key] > interval) then
        lastRun[key] = now
        if func then
            func()
        end
    end
end

function Async:ClearDebounce(key)
    if timers[key] then
        timers[key]:Cancel()
        timers[key] = nil
    end
end

function Async:ClearThrottle(key)
    lastRun[key] = nil
end

function Async:ClearAll()
    for _, timer in pairs(timers) do
        if timer then
            timer:Cancel()
        end
    end
    timers, lastRun = {}, {}
    if cleanupTicker then
        cleanupTicker:Cancel()
        cleanupTicker = nil
    end
end
