-- [ HELP TOPIC: COOLDOWN MANAGER ]-------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L
local KW = L.PLU_SPT_HELP_CDM_KEYWORDS

Orbit.Spotlight.Index.Help:Register({
    {
        id = "cdm_add", topic = L.PLU_SPT_HELP_TOP_CDM, name = L.PLU_SPT_HELP_CDM_ADD,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_CDM_ADD_TT, keywords = KW, keepOpen = true,
    },
    {
        id = "cdm_remove", topic = L.PLU_SPT_HELP_TOP_CDM, name = L.PLU_SPT_HELP_CDM_REMOVE,
        trigger = L.PLU_SPT_HELP_T_SRC, desc = L.PLU_SPT_HELP_CDM_REMOVE_TT, note = L.PLU_SPT_HELP_CDM_REMOVE_NOTE, keywords = KW, keepOpen = true,
    },
    {
        id = "cdm_editmode", topic = L.PLU_SPT_HELP_TOP_CDM, name = L.PLU_SPT_HELP_CDM_EDIT,
        desc = L.PLU_SPT_HELP_CDM_EDIT_TT, keywords = KW, keepOpen = true,
    },
})
