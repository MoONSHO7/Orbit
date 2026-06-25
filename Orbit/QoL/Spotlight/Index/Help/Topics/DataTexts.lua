-- [ HELP TOPIC: DATA TEXTS ]-------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "dt_drawer", topic = L.PLU_SPT_HELP_TOP_DATATEXT, name = L.PLU_SPT_HELP_DT_DRAWER,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_DT_DRAWER_TT, note = L.PLU_SPT_HELP_DT_DRAWER_NOTE, keepOpen = true,
    },
    {
        id = "dt_return", topic = L.PLU_SPT_HELP_TOP_DATATEXT, name = L.PLU_SPT_HELP_DT_RETURN,
        trigger = L.PLU_SPT_HELP_T_RC, desc = L.PLU_SPT_HELP_DT_RETURN_TT, keepOpen = true,
    },
    {
        id = "dt_move", topic = L.PLU_SPT_HELP_TOP_DATATEXT, name = L.PLU_SPT_HELP_DT_MOVE,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_DT_MOVE_TT, keepOpen = true,
    },
    {
        id = "dt_perf", topic = L.PLU_SPT_HELP_TOP_DATATEXT, name = L.PLU_SPT_HELP_DT_PERF,
        desc = L.PLU_SPT_HELP_DT_PERF_TT, note = L.PLU_SPT_HELP_DT_PERF_NOTE, keepOpen = true,
    },
    {
        id = "dt_volume", topic = L.PLU_SPT_HELP_TOP_DATATEXT, name = L.PLU_SPT_HELP_DT_VOLUME,
        trigger = L.PLU_SPT_HELP_T_WHEEL, desc = L.PLU_SPT_HELP_DT_VOLUME_TT, keepOpen = true,
    },
    {
        id = "dt_time", topic = L.PLU_SPT_HELP_TOP_DATATEXT, name = L.PLU_SPT_HELP_DT_TIME,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_DT_TIME_TT, keepOpen = true,
    },
})
