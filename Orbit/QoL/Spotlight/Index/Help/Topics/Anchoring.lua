-- [ HELP TOPIC: ANCHORING ]--------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

Orbit.Spotlight.Index.Help:Register({
    {
        id = "anchor_intro", topic = L.PLU_SPT_HELP_TOP_ANCHOR, name = L.PLU_SPT_HELP_ANCHOR_INTRO,
        desc = L.PLU_SPT_HELP_ANCHOR_INTRO_TT, note = L.PLU_SPT_HELP_ANCHOR_INTRO_NOTE, keepOpen = true,
    },
    {
        id = "anchor_snap", topic = L.PLU_SPT_HELP_TOP_ANCHOR, name = L.PLU_SPT_HELP_ANCHOR_SNAP,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_ANCHOR_SNAP_TT, keepOpen = true,
    },
    {
        id = "anchor_break", topic = L.PLU_SPT_HELP_TOP_ANCHOR, name = L.PLU_SPT_HELP_ANCHOR_BREAK,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_ANCHOR_BREAK_TT, keepOpen = true,
    },
    {
        id = "anchor_gap", topic = L.PLU_SPT_HELP_TOP_ANCHOR, name = L.PLU_SPT_HELP_ANCHOR_GAP,
        trigger = L.PLU_SPT_HELP_T_WHEEL, desc = L.PLU_SPT_HELP_ANCHOR_GAP_TT, note = L.PLU_SPT_HELP_ANCHOR_GAP_NOTE, keepOpen = true,
    },
    {
        id = "anchor_grid", topic = L.PLU_SPT_HELP_TOP_ANCHOR, name = L.PLU_SPT_HELP_ANCHOR_GRID,
        trigger = L.PLU_SPT_HELP_T_DRAG, desc = L.PLU_SPT_HELP_ANCHOR_GRID_TT, keepOpen = true,
    },
})
