-- [ HELP TOPIC: EDIT MODE ]--------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "em_canvas", topic = L.PLU_SPT_HELP_TOP_EDITMODE, name = L.PLU_SPT_HELP_EM_CANVAS,
        trigger = L.PLU_SPT_HELP_T_RC, desc = L.PLU_SPT_HELP_EM_CANVAS_TT, keepOpen = true,
    },
    {
        id = "em_prec", topic = L.PLU_SPT_HELP_TOP_EDITMODE, name = L.PLU_SPT_HELP_EM_PREC,
        trigger = L.PLU_SPT_HELP_T_SDRAG, desc = L.PLU_SPT_HELP_EM_PREC_TT, keepOpen = true,
    },
    {
        id = "em_nudge", topic = L.PLU_SPT_HELP_TOP_EDITMODE, name = L.PLU_SPT_HELP_EM_NUDGE,
        trigger = L.PLU_SPT_HELP_T_ARROWS, desc = L.PLU_SPT_HELP_EM_NUDGE_TT, note = L.PLU_SPT_HELP_EM_NUDGE_NOTE, keepOpen = true,
    },
    {
        id = "em_resize", topic = L.PLU_SPT_HELP_TOP_EDITMODE, name = L.PLU_SPT_HELP_EM_RESIZE,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_EM_RESIZE_TT, note = L.PLU_SPT_HELP_EM_RESIZE_NOTE, keepOpen = true,
    },
    {
        id = "em_group", topic = L.PLU_SPT_HELP_TOP_EDITMODE, name = L.PLU_SPT_HELP_EM_GROUP,
        trigger = L.PLU_SPT_HELP_T_SLC, desc = L.PLU_SPT_HELP_EM_GROUP_TT, keepOpen = true,
    },
})
