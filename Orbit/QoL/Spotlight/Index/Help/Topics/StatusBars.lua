-- [ HELP TOPIC: STATUS BARS ]------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "sb_link", topic = L.PLU_SPT_HELP_TOP_STATUSBAR, name = L.PLU_SPT_HELP_SB_LINK,
        trigger = L.PLU_SPT_HELP_T_SLC, desc = L.PLU_SPT_HELP_SB_LINK_TT, keepOpen = true,
    },
    {
        id = "sb_open", topic = L.PLU_SPT_HELP_TOP_STATUSBAR, name = L.PLU_SPT_HELP_SB_OPEN,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_SB_OPEN_TT, keepOpen = true,
    },
})
