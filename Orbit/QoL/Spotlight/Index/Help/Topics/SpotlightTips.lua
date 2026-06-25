-- [ HELP TOPIC: SPOTLIGHT ]--------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "sp_category", topic = L.PLU_SPT_HELP_TOP_SPOTLIGHT, name = L.PLU_SPT_HELP_SP_CATEGORY,
        trigger = L.PLU_SPT_HELP_T_TYPE, desc = L.PLU_SPT_HELP_SP_CATEGORY_TT, keepOpen = true,
    },
    {
        id = "sp_favorite", topic = L.PLU_SPT_HELP_TOP_SPOTLIGHT, name = L.PLU_SPT_HELP_SP_FAVORITE,
        trigger = L.PLU_SPT_HELP_T_RC, desc = L.PLU_SPT_HELP_SP_FAVORITE_TT, keepOpen = true,
    },
    {
        id = "sp_drag", topic = L.PLU_SPT_HELP_TOP_SPOTLIGHT, name = L.PLU_SPT_HELP_SP_DRAG,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_SP_DRAG_TT, keepOpen = true,
    },
})
