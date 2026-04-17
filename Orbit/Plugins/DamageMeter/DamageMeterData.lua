---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local SESSION_TYPE = DM.SessionType
local METER_TYPE = DM.MeterType

-- [ DATA ADAPTER ] ----------------------------------------------------------------------------------
-- Returned numbers are secret in combat (SecretWhenInCombat) — only forward to sinks, never arithmetic.

OrbitEngine.DamageMeterData = {}
local Data = OrbitEngine.DamageMeterData

-- Returns true when the native API surface is loaded and usable.
function Data:IsAvailable()
    if not C_DamageMeter then return false end
    if not C_DamageMeter.IsDamageMeterAvailable then return false end
    local ok = C_DamageMeter.IsDamageMeterAvailable()
    return ok and true or false
end

-- Returns the array of tracked sessions shipped by the server, or an empty table.
function Data:GetAvailableSessions()
    if not self:IsAvailable() then return {} end
    return C_DamageMeter.GetAvailableCombatSessions() or {}
end

-- Returns the non-secret duration for a session type, or nil when unknown.
function Data:GetDurationSeconds(sessionType)
    if not self:IsAvailable() then return nil end
    return C_DamageMeter.GetSessionDurationSeconds(sessionType or SESSION_TYPE.Current)
end

function Data:GetSession(sessionType, meterType)
    if not self:IsAvailable() then return nil end
    sessionType = sessionType or SESSION_TYPE.Current
    meterType = meterType or METER_TYPE.Dps
    return C_DamageMeter.GetCombatSessionFromType(sessionType, meterType)
end

function Data:ResolveSession(sessionID, sessionType, meterType)
    if not self:IsAvailable() then return nil end
    meterType = meterType or METER_TYPE.Dps
    if sessionID then
        return C_DamageMeter.GetCombatSessionFromID(sessionID, meterType)
    end
    return C_DamageMeter.GetCombatSessionFromType(sessionType or SESSION_TYPE.Current, meterType)
end

function Data:ResolveSessionSource(sessionID, sessionType, meterType, sourceGUID, sourceCreatureID)
    if not self:IsAvailable() then return nil end
    meterType = meterType or METER_TYPE.Dps
    if sessionID then
        return C_DamageMeter.GetCombatSessionSourceFromID(sessionID, meterType, sourceGUID, sourceCreatureID)
    end
    return C_DamageMeter.GetCombatSessionSourceFromType(
        sessionType or SESSION_TYPE.Current, meterType, sourceGUID, sourceCreatureID
    )
end

function Data:GetSessionByID(sessionID, meterType)
    if not self:IsAvailable() or not sessionID then return nil end
    return C_DamageMeter.GetCombatSessionFromID(sessionID, meterType or METER_TYPE.Dps)
end

function Data:GetSessionSource(sessionType, meterType, sourceGUID, sourceCreatureID)
    if not self:IsAvailable() then return nil end
    return C_DamageMeter.GetCombatSessionSourceFromType(
        sessionType or SESSION_TYPE.Current,
        meterType or METER_TYPE.Dps,
        sourceGUID, sourceCreatureID
    )
end

function Data:GetSessionSourceByID(sessionID, meterType, sourceGUID, sourceCreatureID)
    if not self:IsAvailable() or not sessionID then return nil end
    return C_DamageMeter.GetCombatSessionSourceFromID(
        sessionID, meterType or METER_TYPE.Dps, sourceGUID, sourceCreatureID
    )
end

function Data:ResetAllSessions()
    if not self:IsAvailable() then return end
    if not InCombatLockdown() then C_DamageMeter.ResetAllCombatSessions() end
end

-- combatSources array indices are server rank-ordered; never compare totalAmount in Lua (secret).
function Data:GetSources(sessionType, meterType)
    local session = self:GetSession(sessionType, meterType)
    if not session then return {} end
    return session.combatSources or {}
end

-- Enum exposure so other modules can reference meter/session types without reaching into Constants.
Data.MeterType = METER_TYPE
Data.SessionType = SESSION_TYPE
