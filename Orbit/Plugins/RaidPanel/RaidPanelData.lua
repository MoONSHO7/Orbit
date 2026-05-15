-- RaidPanelData.lua: Static slot definitions for the Raid Panel dock.

local _, Orbit = ...
local L = Orbit.L

Orbit.RaidPanelData = {}
local PD = Orbit.RaidPanelData

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
PD.RAID_TARGET_TEXTURE  = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
PD.RAID_TARGET_COLUMNS  = 4
PD.RAID_TARGET_ROWS     = 4
PD.MARKER_COUNT         = 8

-- [ SLOT ORDER ] ------------------------------------------------------------------------------------
PD.SLOT_ORDER = {
    "DIFFICULTY",
    "READY_CHECK",
    "ROLE_CHECK",
    "MARKER_1", "MARKER_2", "MARKER_3", "MARKER_4",
    "MARKER_5", "MARKER_6", "MARKER_7", "MARKER_8",
    "CLEAR_MARKERS",
    "PINGS",
}

-- [ SLOT DEFINITIONS ] ------------------------------------------------------------------------------
PD.SLOTS = {
    DIFFICULTY = {
        kind     = "menu",
        menuKey  = "difficulty",
        dynamic  = "difficulty",
        sizeMult = 1.3,
        label    = L.PLU_RAIDPANEL_DIFFICULTY,
    },
    READY_CHECK = {
        kind          = "action",
        action        = DoReadyCheck,
        atlas         = "GM-icon-readyCheck",
        atlasHover    = "GM-icon-readyCheck-hover",
        atlasPressed  = "GM-icon-readyCheck-pressed",
        sizeMult      = 1.3,
        label         = L.PLU_RAIDPANEL_READY_CHECK,
    },
    ROLE_CHECK = {
        kind          = "action",
        action        = InitiateRolePoll,
        atlas         = "GM-icon-roles",
        atlasHover    = "GM-icon-roles-hover",
        atlasPressed  = "GM-icon-roles-pressed",
        sizeMult      = 1.3,
        label         = L.PLU_RAIDPANEL_ROLE_CHECK,
    },
    PINGS = {
        kind     = "menu",
        menuKey  = "pings",
        atlas    = "Ping_Marker_Icon_NonThreat",
        label    = L.PLU_RAIDPANEL_RESTRICT_PINGS,
    },
    CLEAR_MARKERS = {
        kind          = "clearmarkers",
        action        = RemoveRaidTargets,
        atlas         = "GM-raidMarker-reset",
        atlasHover    = "GM-raidMarker-reset-hover",
        atlasPressed  = "GM-raidMarker-reset-pressed",
        label         = L.PLU_RAIDPANEL_CLEAR_MARKERS,
    },
}

PD.MARKER_NAMES = {
    [1] = L.PLU_RAIDPANEL_MARKER_STAR,
    [2] = L.PLU_RAIDPANEL_MARKER_CIRCLE,
    [3] = L.PLU_RAIDPANEL_MARKER_DIAMOND,
    [4] = L.PLU_RAIDPANEL_MARKER_TRIANGLE,
    [5] = L.PLU_RAIDPANEL_MARKER_MOON,
    [6] = L.PLU_RAIDPANEL_MARKER_SQUARE,
    [7] = L.PLU_RAIDPANEL_MARKER_CROSS,
    [8] = L.PLU_RAIDPANEL_MARKER_SKULL,
}

for i = 1, PD.MARKER_COUNT do
    PD.SLOTS["MARKER_" .. i] = {
        kind        = "marker",
        markerIndex = i,
        sizeMult    = 0.8,
        label       = PD.MARKER_NAMES[i],
    }
end

-- [ DIFFICULTY MENU DATA ] --------------------------------------------------------------------------
PD.DUNGEON_DIFFICULTIES = {
    { id = 1,  label = L.PLU_RAIDPANEL_DIFF_NORMAL  },
    { id = 2,  label = L.PLU_RAIDPANEL_DIFF_HEROIC  },
    { id = 23, label = L.PLU_RAIDPANEL_DIFF_MYTHIC  },
}

PD.RAID_DIFFICULTIES = {
    { id = 17, label = L.PLU_RAIDPANEL_DIFF_LFR     },
    { id = 14, label = L.PLU_RAIDPANEL_DIFF_NORMAL  },
    { id = 15, label = L.PLU_RAIDPANEL_DIFF_HEROIC  },
    { id = 16, label = L.PLU_RAIDPANEL_DIFF_MYTHIC  },
}

-- [ PING RESTRICTION DATA ] -------------------------------------------------------------------------
PD.PING_RESTRICTIONS = {
    { value = 0, label = L.PLU_RAIDPANEL_PINGS_NONE         },
    { value = 1, label = L.PLU_RAIDPANEL_PINGS_LEADER       },
    { value = 2, label = L.PLU_RAIDPANEL_PINGS_ASSIST       },
    { value = 3, label = L.PLU_RAIDPANEL_PINGS_TANK_HEALER  },
}

-- [ DYNAMIC ATLAS RESOLVERS ] -----------------------------------------------------------------------
local DIFF_NORMAL = { normal = "GM-icon-difficulty-normal",         pressed = "GM-icon-difficulty-normal-pressed"         }
local DIFF_HEROIC = { normal = "GM-icon-difficulty-heroicSelected", pressed = "GM-icon-difficulty-heroicSelected-pressed" }
local DIFF_MYTHIC = { normal = "GM-icon-difficulty-mythic",         pressed = "GM-icon-difficulty-mythic-pressed"         }

local DIFFICULTY_FAMILIES = {
    [1]  = DIFF_NORMAL, [2]  = DIFF_HEROIC, [23] = DIFF_MYTHIC,
    [14] = DIFF_NORMAL, [15] = DIFF_HEROIC, [16] = DIFF_MYTHIC, [17] = DIFF_NORMAL,
}

function PD.GetCurrentDifficultyAtlases()
    local id = IsInRaid() and GetRaidDifficultyID() or GetDungeonDifficultyID()
    return DIFFICULTY_FAMILIES[id] or DIFF_NORMAL
end

