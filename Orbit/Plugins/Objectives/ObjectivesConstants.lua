-- [ OBJECTIVES CONSTANTS ]---------------------------------------------------------------------------
local _, Orbit = ...

Orbit.ObjectivesConstants = {
    SYSTEM_ID = "Orbit_Objectives",
    DEFAULT_SCALE = 100,
    DEFAULT_WIDTH = 248,
    DEFAULT_HEIGHT = 700,
    DEFAULT_ANCHOR_X = -80,
    DEFAULT_ANCHOR_Y = -260,
    WIDTH_MIN = 180,
    WIDTH_MAX = 400,
    WIDTH_STEP = 2,
    HEIGHT_MIN = 200,
    HEIGHT_MAX = 1200,
    HEIGHT_STEP = 10,
    BG_OPACITY_MIN = 0,
    BG_OPACITY_MAX = 100,
    BG_OPACITY_STEP = 5,
    BG_OPACITY_DEFAULT = 0,
    CONTENT_PADDING = 6,
    HEADER_SEPARATOR_HEIGHT = 2,
    OPACITY_MIN = 0,
    OPACITY_MAX = 100,
    OPACITY_STEP = 5,
    OPACITY_DEFAULT = 100,
    TITLE_FONT_SIZE_MIN = 8,
    TITLE_FONT_SIZE_MAX = 18,
    TITLE_FONT_SIZE_STEP = 1,
    TITLE_FONT_SIZE_DEFAULT = 12,
    OBJECTIVE_FONT_SIZE_MIN = 8,
    OBJECTIVE_FONT_SIZE_MAX = 16,
    OBJECTIVE_FONT_SIZE_STEP = 1,
    OBJECTIVE_FONT_SIZE_DEFAULT = 10,
    TOP_LINE_HEIGHT = 1,
    PROGRESS_BAR_FONT_SIZE = 12,
    PROGRESS_BAR_HEIGHT = 14,
    PROGRESS_BAR_CONTAINER_HEIGHT = 16,
    BAR_BG_ALPHA = 0.85,
    SCROLL_SPEED = 60,
    SCROLL_BOTTOM_PADDING = 20,
    MAX_TRACKER_HEIGHT = 50000,
    MIN_TRACKER_HEIGHT = 50,
    HIGHLIGHT_BRIGHTEN = 1.3,
    DEFERRED_RESKIN_DELAY = 0.5,
    POI_SIZE = 18,
    MAX_QUESTS = 35,
    TITLE_COLOR_DEFAULT     = { r = 1.00, g = 0.82, b = 0.00, a = 1 },
    COMPLETED_COLOR_DEFAULT = { r = 0.90, g = 0.80, b = 0.10, a = 1 },
    FOCUS_COLOR_DEFAULT     = { r = 1.00, g = 1.00, b = 1.00, a = 1 },

    -- POI tag-specific title colours (overrides classification when tag matches)
    TAG_COLOR_GROUP   = { r = 0.40, g = 0.70, b = 1.00 },
    TAG_COLOR_RAID    = { r = 0.90, g = 0.30, b = 0.10 },
    TAG_COLOR_PVP     = { r = 0.90, g = 0.20, b = 0.20 },
    TAG_COLOR_ACCOUNT = { r = 0.40, g = 0.80, b = 0.95 },

    -- All tracker module globals that Blizzard creates
    TRACKER_MODULES = {
        "ScenarioObjectiveTracker",
        "UIWidgetObjectiveTracker",
        "CampaignQuestObjectiveTracker",
        "QuestObjectiveTracker",
        "AdventureObjectiveTracker",
        "AchievementObjectiveTracker",
        "MonthlyActivitiesObjectiveTracker",
        "ProfessionsRecipeTracker",
        "BonusObjectiveTracker",
        "WorldQuestObjectiveTracker",
        "InitiativeTasksObjectiveTracker",
    },
}

-- Validate/recover a colour from plain {r,g,b} or legacy colour-curve {pins=...} format.
function Orbit.ObjectivesConstants.ValidateColor(c, fallback)
    if type(c) ~= "table" then return fallback end
    if type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then return c end
    if c.pins and c.pins[1] and type(c.pins[1].color) == "table" then
        local pin = c.pins[1].color
        if type(pin.r) == "number" and type(pin.g) == "number" and type(pin.b) == "number" then
            return { r = pin.r, g = pin.g, b = pin.b, a = pin.a or 1 }
        end
    end
    return fallback
end
