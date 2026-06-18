-- [ HELP TOPIC: RAID MARKERS ]-----------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "mark_target",
        topic = L.PLU_SPT_HELP_TOP_MARKERS,
        name = L.PLU_SPT_HELP_MARK_TGT,
        trigger = L.PLU_SPT_HELP_T_LC,
        desc = L.PLU_SPT_HELP_MARK_TGT_TT,
        keepOpen = true,
    },
    {
        id = "mark_world",
        topic = L.PLU_SPT_HELP_TOP_MARKERS,
        name = L.PLU_SPT_HELP_MARK_WORLD,
        trigger = L.PLU_SPT_HELP_T_SLC,
        desc = L.PLU_SPT_HELP_MARK_WORLD_TT,
        keepOpen = true,
    },
    {
        id = "mark_clear",
        topic = L.PLU_SPT_HELP_TOP_MARKERS,
        name = L.PLU_SPT_HELP_MARK_CLEAR,
        trigger = L.PLU_SPT_HELP_T_LC,
        desc = L.PLU_SPT_HELP_MARK_CLEAR_TT,
        keepOpen = true,
    },
})
