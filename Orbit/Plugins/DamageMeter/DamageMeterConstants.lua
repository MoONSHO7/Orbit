---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

-- [ DAMAGE METER CONSTANTS ] ------------------------------------------------------------------------
Constants.DamageMeter = {
    SystemID    = "Orbit_DamageMeter",
    DisplayName = "Damage Meter",
    SystemIndex = 1,

    -- The id=1 meter is auto-seeded on load and can never be deleted.
    SeedID = 1,

    -- Hard cap on total meters, including the seed.
    MaxMeters = 5,

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
