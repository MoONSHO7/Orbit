---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

-- [ DAMAGE METER CONSTANTS ] ------------------------------------------------------------------------
Constants.DamageMeter = {
    SystemID    = "Orbit_DamageMeter",
    DisplayName = "Damage Meter",
    SystemIndex = 1,

    -- Negative sentinel so the master meter id cannot collide with user meter ids (positive ints).
    MasterID = -1,

    -- Total cap INCLUDING master (1 master + 5 user meters at default).
    MaxMeters = 6,

    MeterType = {
        DamageDone           = 0,
        Dps                  = 1,
        HealingDone          = 2,
        Hps                  = 3,
        Absorbs              = 4,
        Interrupts           = 5,
        Dispels              = 6,
        DamageTaken          = 7,
        AvoidableDamageTaken = 8,
        Deaths               = 9,
        EnemyDamageTaken     = 10,
    },

    SessionType = {
        Overall = 0,
        Current = 1,
        Expired = 2,
    },

    Events = {
        SessionUpdated  = "ORBIT_DAMAGEMETER_SESSION_UPDATED",
        SessionReset    = "ORBIT_DAMAGEMETER_RESET",
        CurrentUpdated  = "ORBIT_DAMAGEMETER_CURRENT_UPDATED",
    },
}
