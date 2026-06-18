-- [ HELP TOPIC: OPEN ]-------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

local function OpenPluginManager()
    if Orbit._pluginSettingsCategoryID then
        Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
    else
        Orbit:Print(L.MSG_PLUGIN_MGR_NOT_LOADED)
    end
end

local function OpenVisibilityEngine()
    if Orbit._pluginSettingsCategoryID then
        Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
        if Orbit._openVETab then C_Timer.After(0.05, Orbit._openVETab) end
    else
        Orbit:Print(L.MSG_PLUGIN_MGR_NOT_LOADED)
    end
end

Orbit.Spotlight.Index.Help:Register({
    {
        id = "cmd_editmode", topic = L.PLU_SPT_HELP_TOP_OPEN, name = L.PLU_SPT_HELP_EDITMODE,
        desc = L.PLU_SPT_HELP_EDITMODE_TT, onClick = function() Orbit.OptionsPanel:ToggleEditMode() end,
    },
    {
        id = "cmd_plugins", topic = L.PLU_SPT_HELP_TOP_OPEN, name = L.PLU_SPT_HELP_PLUGINS,
        desc = L.PLU_SPT_HELP_PLUGINS_TT, onClick = OpenPluginManager,
    },
    {
        id = "cmd_ve", topic = L.PLU_SPT_HELP_TOP_OPEN, name = L.PLU_SPT_HELP_VE,
        desc = L.PLU_SPT_HELP_VE_TT, onClick = OpenVisibilityEngine,
    },
    {
        id = "cmd_whatsnew", topic = L.PLU_SPT_HELP_TOP_OPEN, name = L.PLU_SPT_HELP_WHATSNEW,
        desc = L.PLU_SPT_HELP_WHATSNEW_TT, onClick = function() Orbit:ShowWhatsNew() end,
    },
    {
        id = "cmd_tour", topic = L.PLU_SPT_HELP_TOP_OPEN, name = L.PLU_SPT_HELP_TOUR,
        desc = L.PLU_SPT_HELP_TOUR_TT, onClick = function() Orbit.Engine.EditModeTour:OpenAndStart() end,
    },
})
