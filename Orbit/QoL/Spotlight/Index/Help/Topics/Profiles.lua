-- [ HELP TOPIC: PROFILES ]---------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "pf_copy", topic = L.PLU_SPT_HELP_TOP_PROFILES, name = L.PLU_SPT_HELP_PF_COPY,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_PF_COPY_TT, keepOpen = true,
    },
    {
        id = "pf_share", topic = L.PLU_SPT_HELP_TOP_PROFILES, name = L.PLU_SPT_HELP_PF_SHARE,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_PF_SHARE_TT, keepOpen = true,
    },
    {
        id = "pf_delete", topic = L.PLU_SPT_HELP_TOP_PROFILES, name = L.PLU_SPT_HELP_PF_DELETE,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_PF_DELETE_TT, keepOpen = true,
    },
})
