-- [ HELP TOPIC: RESET ]------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

local MENU_ROW_HEIGHT = 20
local MENU_VISIBLE_ROWS = 10

local function OpenResetMenu(_, row)
    local menu = MenuUtil.CreateContextMenu(row, function(_, root)
        root:SetScrollMode(MENU_ROW_HEIGHT * MENU_VISIBLE_ROWS)
        root:CreateTitle(L.PLU_SPT_HELP_RESET_MENU_TITLE)
        root:CreateButton(L.PLU_SPT_HELP_RESET_ACCOUNT, function()
            Orbit.Spotlight.UI.SpotlightFrame:Close()
            Orbit.API:ResetAccountSettings()
        end)
        local systems = Orbit.Engine and Orbit.Engine.systems
        if not systems then return end
        local headerAdded = false
        for _, plugin in ipairs(systems) do
            local name = plugin.name
            if name and Orbit:IsPluginEnabled(name) then
                if not headerAdded then
                    root:CreateDivider()
                    root:CreateTitle(L.PLU_SPT_HELP_RESET_PLUGINS)
                    headerAdded = true
                end
                root:CreateButton(name, function()
                    Orbit.Spotlight.UI.SpotlightFrame:Close()
                    Orbit.API:ResetPluginSettings(plugin)
                end)
            end
        end
    end)
    if menu and menu.ScrollBar then menu.ScrollBar:Hide() end
end

Orbit.Spotlight.Index.Help:Register({
    {
        id = "cmd_reset", topic = L.PLU_SPT_HELP_TOP_RESET, name = L.PLU_SPT_HELP_RESET,
        desc = L.PLU_SPT_HELP_RESET_TT, onClick = OpenResetMenu, keepOpen = true,
    },
    {
        id = "cmd_hardreset", topic = L.PLU_SPT_HELP_TOP_RESET, name = L.PLU_SPT_HELP_HARDRESET,
        desc = L.PLU_SPT_HELP_HARDRESET_TT, onClick = function() Orbit.API:ConfirmHardReset() end,
    },
    {
        id = "cmd_flush", topic = L.PLU_SPT_HELP_TOP_RESET, name = L.PLU_SPT_HELP_FLUSH,
        desc = L.PLU_SPT_HELP_FLUSH_TT, onClick = function()
            if Orbit.ViewerInjection then
                Orbit.ViewerInjection:FlushAll()
                Orbit:Print(L.MSG_COOLDOWNS_CLEARED)
            else
                Orbit:Print(L.MSG_VIEWER_INJECTION_MISSING)
            end
        end,
    },
    {
        id = "cmd_trkflush", topic = L.PLU_SPT_HELP_TOP_RESET, name = L.PLU_SPT_HELP_TRKFLUSH,
        desc = L.PLU_SPT_HELP_TRKFLUSH_TT, onClick = function()
            local tracked = Orbit:GetPlugin("Orbit_Tracked")
            if tracked and tracked.FlushCurrentSpec then
                tracked:FlushCurrentSpec()
            else
                Orbit:Print(L.MSG_TRACKED_NOT_LOADED)
            end
        end,
    },
    {
        id = "cmd_vereset", topic = L.PLU_SPT_HELP_TOP_RESET, name = L.PLU_SPT_HELP_VERESET,
        desc = L.PLU_SPT_HELP_VERESET_TT, onClick = function() Orbit.VisibilityEngine:ResetAll() end,
    },
})
