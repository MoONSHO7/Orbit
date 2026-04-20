-- [ METATALENTS / CONSTANTS ] -----------------------------------------------------------------------
-- Shared constants, WCL tier colors, and the HeatmapColor function for the MetaTalents module.
-- This file is loaded first; it seeds the Orbit.MetaTalents namespace for every sibling file.

local _, Orbit = ...
Orbit.MetaTalents = Orbit.MetaTalents or {}
Orbit.MetaTalents._active = false
Orbit.MetaTalents._hooked = false
Orbit.MetaTalents._dropdownsSetup = false

local C = {}
Orbit.MetaTalents.Constants = C

-- [ GENERAL ] ---------------------------------------------------------------------------------------
C.LOD_ADDON = "OrbitData"
C.FONT_TEMPLATE = "GameFontHighlightSmallOutline"
C.MIN_PICK_RATE = 1
C.MIN_APPLY_LEVEL = 81
C.DEFAULT_CONTENT = "Algeth'ar Academy"
C.DEFAULT_DIFFICULTY = "Mythic+"
C.CONFIG_NAME = "Orbit Loadout"
C.LOGIN_DELAY = 0.5
C.STATE_DEBOUNCE = 0.1

-- [ BADGE LAYOUT ] ----------------------------------------------------------------------------------
C.BADGE_WIDTH = 42
C.BADGE_HEIGHT = 16
C.BADGE_FONT_SIZE = 13
C.BADGE_LEVEL_OFFSET = 2
C.BADGE_TOP_OFFSET = 11
C.BADGE_TEXT_X = 1
C.BADGE_SHADOW_WIDTH = 73
C.BADGE_SHADOW_HEIGHT = 42
C.BADGE_SHADOW_ALPHA = 0.95

-- [ WCL TIER COLORS ] -------------------------------------------------------------------------------
local COLOR_PINK   = { 0.886, 0.408, 0.659 }
local COLOR_PURPLE = { 0.639, 0.208, 0.933 }
local COLOR_BLUE   = { 0.000, 0.439, 0.867 }
local COLOR_GREEN  = { 0.118, 1.000, 0.000 }
local COLOR_GRAY   = { 0.400, 0.400, 0.400 }

local PINK_THRESHOLD = 95
local PURPLE_THRESHOLD = 75
local BLUE_THRESHOLD = 50
local GREEN_THRESHOLD = 25

-- [ HEATMAP COLOR ] ---------------------------------------------------------------------------------
function C.HeatmapColor(pct)
    if pct >= PINK_THRESHOLD then return COLOR_PINK[1], COLOR_PINK[2], COLOR_PINK[3] end
    if pct >= PURPLE_THRESHOLD then return COLOR_PURPLE[1], COLOR_PURPLE[2], COLOR_PURPLE[3] end
    if pct >= BLUE_THRESHOLD then return COLOR_BLUE[1], COLOR_BLUE[2], COLOR_BLUE[3] end
    if pct >= GREEN_THRESHOLD then return COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3] end
    return COLOR_GRAY[1], COLOR_GRAY[2], COLOR_GRAY[3]
end
