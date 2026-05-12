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
