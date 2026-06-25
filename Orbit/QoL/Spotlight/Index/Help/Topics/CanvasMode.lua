-- [ HELP TOPIC: CANVAS MODE ]------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "cm_edit", topic = L.PLU_SPT_HELP_TOP_CANVAS, name = L.PLU_SPT_HELP_CM_EDIT,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_CM_EDIT_TT, note = L.PLU_SPT_HELP_CM_EDIT_NOTE, keepOpen = true,
    },
    {
        id = "cm_move", topic = L.PLU_SPT_HELP_TOP_CANVAS, name = L.PLU_SPT_HELP_CM_MOVE,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_CM_MOVE_TT, keepOpen = true,
    },
    {
        id = "cm_disable", topic = L.PLU_SPT_HELP_TOP_CANVAS, name = L.PLU_SPT_HELP_CM_DISABLE,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_CM_DISABLE_TT, note = L.PLU_SPT_HELP_CM_DISABLE_NOTE, keepOpen = true,
    },
    {
        id = "cm_nudge", topic = L.PLU_SPT_HELP_TOP_CANVAS, name = L.PLU_SPT_HELP_CM_NUDGE,
        trigger = L.PLU_SPT_HELP_T_ARROWS, desc = L.PLU_SPT_HELP_CM_NUDGE_TT, keepOpen = true,
    },
})
