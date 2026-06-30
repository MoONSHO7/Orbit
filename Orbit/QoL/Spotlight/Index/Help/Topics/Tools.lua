-- [ HELP TOPIC: TOOLS ]------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

local MENU_ROW_HEIGHT = 20
local MENU_VISIBLE_ROWS = 10

-- Language endonyms — shown the same in every locale, so they are not translated.
local LANG_NAMES = {
    enUS = "English", deDE = "Deutsch", frFR = "Français", esES = "Español",
    ptBR = "Português", ruRU = "Русский", koKR = "한국어", zhCN = "简体中文", zhTW = "繁體中文",
}

local function CurrentOverride()
    return Orbit.db.AccountSettings.LocaleOverride
end

local function OpenLangMenu(_, row)
    local menu = MenuUtil.CreateContextMenu(row, function(_, root)
        root:SetScrollMode(MENU_ROW_HEIGHT * MENU_VISIBLE_ROWS)
        root:CreateTitle(L.PLU_SPT_HELP_LANG)
        root:CreateRadio(L.CMN_DEFAULT, function() return CurrentOverride() == nil end, function()
            Orbit.Spotlight.UI.SpotlightFrame:Close()
            Orbit.Localization.SetLocaleOverride("auto")
        end)
        root:CreateDivider()
        local locales = Orbit.Localization and Orbit.Localization.SUPPORTED_LOCALES
        if not locales then return end
        for _, code in ipairs(locales) do
            root:CreateRadio(LANG_NAMES[code] or code, function() return CurrentOverride() == code end, function()
                Orbit.Spotlight.UI.SpotlightFrame:Close()
                Orbit.Localization.SetLocaleOverride(code)
            end)
        end
    end)
    if menu and menu.ScrollBar then menu.ScrollBar:Hide() end
end

local function OpenInspectMenu(_, row)
    local menu = MenuUtil.CreateContextMenu(row, function(_, root)
        root:SetScrollMode(MENU_ROW_HEIGHT * MENU_VISIBLE_ROWS)
        root:CreateTitle(L.PLU_SPT_HELP_INSPECT_MENU_TITLE)
        local systems = Orbit.Engine and Orbit.Engine.systems
        if not systems then return end
        for _, plugin in ipairs(systems) do
            local name = plugin.name
            if name then
                root:CreateButton(name, function()
                    Orbit.Spotlight.UI.SpotlightFrame:Close()
                    Orbit.API:InspectPlugin(name)
                end)
            end
        end
    end)
    if menu and menu.ScrollBar then menu.ScrollBar:Hide() end
end

Orbit.Spotlight.Index.Help:Register({
    {
        id = "tool_version", topic = L.PLU_SPT_HELP_TOP_TOOLS, name = L.PLU_SPT_HELP_VERSION,
        desc = L.PLU_SPT_HELP_VERSION_TT,
        onClick = function() Orbit.API:PrintVersion() end,
    },
    {
        id = "tool_inspect", topic = L.PLU_SPT_HELP_TOP_TOOLS, name = L.PLU_SPT_HELP_INSPECT,
        desc = L.PLU_SPT_HELP_INSPECT_TT,
        onClick = OpenInspectMenu, keepOpen = true,
    },
    {
        id = "tool_lang", topic = L.PLU_SPT_HELP_TOP_TOOLS, name = L.PLU_SPT_HELP_LANG,
        desc = L.PLU_SPT_HELP_LANG_TT, note = L.PLU_SPT_HELP_LANG_NOTE,
        onClick = OpenLangMenu, keepOpen = true,
    },
    {
        id = "tool_perf_start", topic = L.PLU_SPT_HELP_TOP_TOOLS, name = L.PLU_SPT_HELP_PERF_START,
        desc = L.PLU_SPT_HELP_PERF_START_TT,
        onClick = function() if Orbit.Profiler then Orbit.Profiler:Start() end end,
    },
    {
        id = "tool_perf_stop", topic = L.PLU_SPT_HELP_TOP_TOOLS, name = L.PLU_SPT_HELP_PERF_STOP,
        desc = L.PLU_SPT_HELP_PERF_STOP_TT,
        onClick = function() if Orbit.Profiler then Orbit.Profiler:Stop() end end,
    },
    {
        id = "tool_glow_showcase", topic = L.PLU_SPT_HELP_TOP_TOOLS, name = L.PLU_SPT_HELP_GLOW_SHOWCASE,
        desc = L.PLU_SPT_HELP_GLOW_SHOWCASE_TT, keywords = L.PLU_SPT_HELP_GLOW_SHOWCASE_KW,
        onClick = function()
            local lib = LibStub and LibStub("LibOrbitGlow-1.0", true)
            if lib and lib.Showcase then lib.Showcase:Toggle() end
        end,
    },
})
