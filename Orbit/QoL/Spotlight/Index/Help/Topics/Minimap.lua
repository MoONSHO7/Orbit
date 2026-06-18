-- [ HELP TOPIC: MINIMAP ]----------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "mm_zoom", topic = L.PLU_SPT_HELP_TOP_MINIMAP, name = L.PLU_SPT_HELP_MM_ZOOM,
        trigger = L.PLU_SPT_HELP_T_WHEEL, desc = L.PLU_SPT_HELP_MM_ZOOM_TT, keepOpen = true,
    },
    {
        id = "mm_clicks", topic = L.PLU_SPT_HELP_TOP_MINIMAP, name = L.PLU_SPT_HELP_MM_CLICKS,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_MM_CLICKS_TT, note = L.PLU_SPT_HELP_MM_CLICKS_NOTE, keepOpen = true,
    },
    {
        id = "mm_clock", topic = L.PLU_SPT_HELP_TOP_MINIMAP, name = L.PLU_SPT_HELP_MM_CLOCK,
        trigger = L.PLU_SPT_HELP_T_LC, desc = L.PLU_SPT_HELP_MM_CLOCK_TT, keepOpen = true,
    },
})
