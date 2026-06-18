-- [ HELP TOPIC: COLOR PICKER ]-----------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "cp_add", topic = L.PLU_SPT_HELP_TOP_COLOR, name = L.PLU_SPT_HELP_CP_ADD,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_CP_ADD_TT, note = L.PLU_SPT_HELP_CP_ADD_NOTE, keepOpen = true,
    },
    {
        id = "cp_remove", topic = L.PLU_SPT_HELP_TOP_COLOR, name = L.PLU_SPT_HELP_CP_REMOVE,
        trigger = L.PLU_SPT_HELP_T_RC, desc = L.PLU_SPT_HELP_CP_REMOVE_TT, keepOpen = true,
    },
    {
        id = "cp_nudge", topic = L.PLU_SPT_HELP_TOP_COLOR, name = L.PLU_SPT_HELP_CP_NUDGE,
        trigger = L.PLU_SPT_HELP_T_ARROWS, desc = L.PLU_SPT_HELP_CP_NUDGE_TT, keepOpen = true,
    },
})
