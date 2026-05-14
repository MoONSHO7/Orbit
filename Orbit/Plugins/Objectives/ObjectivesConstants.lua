-- [ OBJECTIVES CONSTANTS ]---------------------------------------------------------------------------
local _, Orbit = ...

Orbit.ObjectivesConstants = {
    SYSTEM_ID = "Orbit_Objectives",
    DEFAULT_SCALE = 100,
    DEFAULT_WIDTH = 248,
    DEFAULT_HEIGHT = 700,
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

    -- Hover fade (Opacity = 100 means disabled; below 100 enables fade-to-opacity when moused out)
    OPACITY_MIN = 0,
    OPACITY_MAX = 100,
    OPACITY_STEP = 5,
    OPACITY_DEFAULT = 100,

    -- Title font size
    TITLE_FONT_SIZE_MIN = 8,
    TITLE_FONT_SIZE_MAX = 18,
    TITLE_FONT_SIZE_STEP = 1,
    TITLE_FONT_SIZE_DEFAULT = 12,

    -- Objective line font size
    OBJECTIVE_FONT_SIZE_MIN = 8,
    OBJECTIVE_FONT_SIZE_MAX = 16,
    OBJECTIVE_FONT_SIZE_STEP = 1,
    OBJECTIVE_FONT_SIZE_DEFAULT = 10,

    -- Decorative top line
    TOP_LINE_HEIGHT = 1,

    -- Progress bar label font size
    PROGRESS_BAR_FONT_SIZE = 12,

    -- Default colours for quest titles (RGBA tables)
    TITLE_COLOR_DEFAULT     = { r = 1.00, g = 0.82, b = 0.00, a = 1 },
    COMPLETED_COLOR_DEFAULT = { r = 0.90, g = 0.80, b = 0.10, a = 1 },
    FOCUS_COLOR_DEFAULT     = { r = 1.00, g = 1.00, b = 1.00, a = 1 },

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
