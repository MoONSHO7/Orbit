-- [ HELP TOPIC: TRACKED ]----------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L
local KW = L.PLU_SPT_HELP_CDM_KEYWORDS

Orbit.Spotlight.Index.Help:Register({
    {
        id = "trk_create", topic = L.PLU_SPT_HELP_TOP_CDM, name = L.PLU_SPT_HELP_TRK_CREATE,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_TRK_CREATE_TT, keywords = KW, keepOpen = true,
    },
    {
        id = "trk_add", topic = L.PLU_SPT_HELP_TOP_CDM, name = L.PLU_SPT_HELP_TRK_ADD,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_TRK_ADD_TT, keywords = KW, keepOpen = true,
    },
    {
        id = "trk_icon", topic = L.PLU_SPT_HELP_TOP_CDM, name = L.PLU_SPT_HELP_TRK_ICON,
        trigger = L.PLU_SPT_HELP_T_SRC, desc = L.PLU_SPT_HELP_TRK_ICON_TT, keywords = KW, keepOpen = true,
    },
    {
        id = "trk_bar", topic = L.PLU_SPT_HELP_TOP_CDM, name = L.PLU_SPT_HELP_TRK_BAR,
        trigger = L.PLU_SPT_HELP_T_SRC, desc = L.PLU_SPT_HELP_TRK_BAR_TT, keywords = KW, keepOpen = true,
    },
    {
        id = "trk_container", topic = L.PLU_SPT_HELP_TOP_CDM, name = L.PLU_SPT_HELP_TRK_CONTAINER,
        trigger = L.PLU_SPT_HELP_T_SRC, desc = L.PLU_SPT_HELP_TRK_CONTAINER_TT, keywords = KW, keepOpen = true,
    },
})
