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

    Border = {
        None   = 1,
        PerBar = 2,
        Frame  = 3,
    },

    Background = {
        None   = 1,
        PerBar = 2,
        Frame  = 3,
    },

    Title = {
        Off         = 1,
        TopLeft     = 2,
        TopRight    = 3,
        BottomLeft  = 4,
        BottomRight = 5,
    },

    IconPos = {
        Left  = 1,
        Off   = 2,
        Right = 3,
    },

    -- Default styling baseline shared by seed creation, CreateMeter, and NormalizeMeterDefs.
    DefaultDef = {
        barCount     = 10,
        barWidth     = 219,
        barHeight    = 20,
        barGap       = 1,
        iconPosition = 1,
        style        = 100,
        border       = 3,
        background   = 3,
        title        = 2,
        titleSize    = 14,
    },

    -- Default position when a def has none (CreateMeter uses CENTER; seed overrides explicitly).
    DefaultPosition     = { point = "TOPLEFT", x = 200, y = -200 },
    SeedPosition        = { point = "TOPLEFT", x = 40,  y = -200 },
    CenteredPosition    = { point = "CENTER",  x = 0,   y = 0 },

    -- Frame levels for layering multiple meters within the same strata.
    FrameLevelBase      = 10,
    FrameLevelStride    = 10,
    StretchTabLevelBump = 20,
    PreviewLevelBump    = 10,

    -- Bar-stretch tab limits (sets the hard ceiling on Edit Mode vertical resize).
    MaxBarsStretch      = 40,
    MinBarHeightPx      = 18,

    -- Bar-list render padding used by default text positions.
    TextPadInner        = 4,
    NameAfterRankPad    = 22,
    DpsAfterTotalPad    = 48,
    BarFontSize         = 10,
    BackdropAlpha       = 0.4,

    -- Edit Mode vertical resize bounds.
    ResizeBounds = {
        minW = 100, maxW = 600,
        minH = 18,
    },

    -- View-mode auto-exit + ticker cadence (seconds).
    ViewTimeoutSeconds = 20,
    UITickerSeconds    = 0.5,

    -- Session windows Blizzard persists and we must neutralize on each disable pass.
    SessionWindowCount = 3,
}

-- MeterType → PLU_DM_METRIC_* label key. Declared after the table so it can reference MeterType enum.
do
    local DM = Constants.DamageMeter
    DM.MetricLabelKeys = {
        [DM.MeterType.DamageDone]            = "PLU_DM_METRIC_DAMAGE",
        [DM.MeterType.Dps]                   = "PLU_DM_METRIC_DAMAGE",
        [DM.MeterType.HealingDone]           = "PLU_DM_METRIC_HEALING",
        [DM.MeterType.Hps]                   = "PLU_DM_METRIC_HEALING",
        [DM.MeterType.DamageTaken]           = "PLU_DM_METRIC_DAMAGETAKEN",
        [DM.MeterType.AvoidableDamageTaken]  = "PLU_DM_METRIC_AVOIDABLEDAMAGE",
        [DM.MeterType.EnemyDamageTaken]      = "PLU_DM_METRIC_ENEMYDAMAGETAKEN",
        [DM.MeterType.Interrupts]            = "PLU_DM_METRIC_INTERRUPTS",
        [DM.MeterType.Dispels]               = "PLU_DM_METRIC_DISPELS",
        [DM.MeterType.Deaths]                = "PLU_DM_METRIC_DEATHS",
    }
end
