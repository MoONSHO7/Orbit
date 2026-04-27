---@type Orbit
local Orbit = Orbit

-- [ SESSION TRACKER ]--------------------------------------------------------------------------------
-- Tracks per-session gain and rate for each bar. Persists across /reload via AccountSettings.
-- A reload preserves the session; logout starts a new one after a configurable stale window.

Orbit.StatusBarSession = {}
local Session = Orbit.StatusBarSession

local STALE_WINDOW_SECONDS = 30 * 60 -- 30m idle → new session
local MIN_ELAPSED_FOR_RATE = 60      -- need 60s before rate stabilises

local function GetStore()
    local as = Orbit.db and Orbit.db.AccountSettings
    if not as then return nil end
    as.StatusBarSessions = as.StatusBarSessions or {}
    return as.StatusBarSessions
end

-- trackerKey identifies a session bucket, e.g. "Orbit_ExperienceBar" or "Orbit_HonorBar"
-- currentValue is whatever the tracker measures (total XP earned, total honor points, etc.)
local function Now() return time() end

function Session:Start(trackerKey, currentTotal)
    local store = GetStore()
    if not store then return end
    local existing = store[trackerKey]
    if existing and (Now() - (existing.lastUpdate or 0)) < STALE_WINDOW_SECONDS then
        -- Fresh reload: keep existing session state
        return
    end
    store[trackerKey] = {
        startTotal = currentTotal or 0,
        startTime = Now(),
        lastUpdate = Now(),
        gained = 0,
    }
end

function Session:Update(trackerKey, currentTotal)
    local store = GetStore()
    if not store then return end
    local s = store[trackerKey]
    if not s then
        self:Start(trackerKey, currentTotal)
        return
    end
    -- If total went backwards (level-up on XP resets UnitXP to 0), accumulate the jump into gained
    if currentTotal and s.startTotal then
        if currentTotal >= s.startTotal then
            s.gained = currentTotal - s.startTotal
        end
    end
    s.lastUpdate = Now()
end

-- Levels reset currentXP to 0 on level up; caller informs the tracker so the session preserves
-- total gain by baking the old max into `gained`.
function Session:OnResetBoundary(trackerKey, priorMax)
    local store = GetStore()
    if not store then return end
    local s = store[trackerKey]
    if not s or not priorMax then return end
    s.gained = (s.gained or 0) + (priorMax - (s.startTotal or 0))
    s.startTotal = 0
    s.lastUpdate = Now()
end

function Session:Reset(trackerKey, currentTotal)
    local store = GetStore()
    if not store then return end
    store[trackerKey] = {
        startTotal = currentTotal or 0,
        startTime = Now(),
        lastUpdate = Now(),
        gained = 0,
    }
end

-- Returns: gained, perHour, elapsedSeconds. perHour stabilises after MIN_ELAPSED_FOR_RATE.
function Session:GetStats(trackerKey)
    local store = GetStore()
    if not store then return 0, 0, 0 end
    local s = store[trackerKey]
    if not s then return 0, 0, 0 end
    local elapsed = Now() - (s.startTime or Now())
    local rate = 0
    if elapsed >= MIN_ELAPSED_FOR_RATE and s.gained and s.gained > 0 then
        rate = s.gained / (elapsed / 3600)
    end
    return s.gained or 0, rate, elapsed
end

-- ETA to reach `remaining` at current rate. Returns math.huge if rate is 0.
function Session:GetETA(trackerKey, remaining)
    local _, rate = self:GetStats(trackerKey)
    if not rate or rate <= 0 or not remaining or remaining <= 0 then return math.huge end
    return (remaining / rate) * 3600
end
