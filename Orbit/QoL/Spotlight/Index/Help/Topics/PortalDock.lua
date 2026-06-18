-- [ HELP TOPIC: PORTAL DOCK ]------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "pd_search", topic = L.PLU_SPT_HELP_TOP_PORTAL, name = L.PLU_SPT_HELP_PD_SEARCH,
        trigger = L.PLU_SPT_HELP_T_TYPE, desc = L.PLU_SPT_HELP_PD_SEARCH_TT, keepOpen = true,
    },
    {
        id = "pd_category", topic = L.PLU_SPT_HELP_TOP_PORTAL, name = L.PLU_SPT_HELP_PD_CATEGORY,
        trigger = L.PLU_SPT_HELP_T_SWHEEL, desc = L.PLU_SPT_HELP_PD_CATEGORY_TT, note = L.PLU_SPT_HELP_PD_CATEGORY_NOTE, keepOpen = true,
    },
    {
        id = "pd_favorite", topic = L.PLU_SPT_HELP_TOP_PORTAL, name = L.PLU_SPT_HELP_PD_FAVORITE,
        trigger = L.PLU_SPT_HELP_T_SRC, desc = L.PLU_SPT_HELP_PD_FAVORITE_TT, keepOpen = true,
    },
    {
        id = "pd_scan", topic = L.PLU_SPT_HELP_TOP_PORTAL, name = L.PLU_SPT_HELP_PD_SCAN,
        desc = L.PLU_SPT_HELP_PD_SCAN_TT, onClick = function()
            local portal = Orbit:GetPlugin("Orbit_Portal")
            if portal and portal.HandleCommand then portal:HandleCommand("scan") end
        end,
    },
})
