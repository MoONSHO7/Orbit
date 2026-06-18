-- [ HELP TOPIC: DAMAGE METER ]-----------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "dm_metric", topic = L.PLU_SPT_HELP_TOP_DMGMETER, name = L.PLU_SPT_HELP_DM_METRIC,
        trigger = L.PLU_SPT_HELP_T_SRC, desc = L.PLU_SPT_HELP_DM_METRIC_TT, keepOpen = true,
    },
    {
        id = "dm_break", topic = L.PLU_SPT_HELP_TOP_DMGMETER, name = L.PLU_SPT_HELP_DM_BREAK,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_DM_BREAK_TT, note = L.PLU_SPT_HELP_DM_BREAK_NOTE, keepOpen = true,
    },
    {
        id = "dm_hover", topic = L.PLU_SPT_HELP_TOP_DMGMETER, name = L.PLU_SPT_HELP_DM_HOVER,
        trigger = L.PLU_SPT_HELP_T_HOVER, desc = L.PLU_SPT_HELP_DM_HOVER_TT, note = L.PLU_SPT_HELP_DM_HOVER_NOTE, keepOpen = true,
    },
    {
        id = "dm_detach", topic = L.PLU_SPT_HELP_TOP_DMGMETER, name = L.PLU_SPT_HELP_DM_DETACH,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_DM_DETACH_TT, note = L.PLU_SPT_HELP_DM_DETACH_NOTE, keepOpen = true,
    },
    {
        id = "dm_spec", topic = L.PLU_SPT_HELP_TOP_DMGMETER, name = L.PLU_SPT_HELP_DM_SPEC,
        trigger = L.PLU_SPT_HELP_T_SLC, desc = L.PLU_SPT_HELP_DM_SPEC_TT, note = L.PLU_SPT_HELP_DM_SPEC_NOTE, keepOpen = true,
    },
    {
        id = "dm_hist", topic = L.PLU_SPT_HELP_TOP_DMGMETER, name = L.PLU_SPT_HELP_DM_HIST,
        trigger = L.PLU_SPT_HELP_T_RC, desc = L.PLU_SPT_HELP_DM_HIST_TT, keepOpen = true,
    },
    {
        id = "dm_scroll", topic = L.PLU_SPT_HELP_TOP_DMGMETER, name = L.PLU_SPT_HELP_DM_SCROLL,
        trigger = L.PLU_SPT_HELP_T_WHEEL, desc = L.PLU_SPT_HELP_DM_SCROLL_TT, keepOpen = true,
    },
})
