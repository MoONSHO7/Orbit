-- [ ORBIT SLASH COMMANDS ]--------------------------------------------------------------------------

local _, Orbit = ...

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local POPUP_PREFERRED_INDEX = 3
local MAX_INSPECT_DEPTH = 2
local MAX_INSPECT_ITEMS = 20

-- [ CONFIRMATION POPUPS ]---------------------------------------------------------------------------

StaticPopupDialogs["ORBIT_CONFIRM_HARD_RESET"] = {
    text = "|cFFFF0000DANGER|r\n\nYou are about to FACTORY RESET Orbit.\n\nAll profiles, settings, and data will be wiped.\nThe UI will reload immediately.\n\nAre you sure?",
    button1 = "Factory Reset", button2 = "Cancel",
    OnAccept = function(self) Orbit.API:HardReset() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

StaticPopupDialogs["ORBIT_CONFIRM_RESET_ACCOUNT"] = {
    text = "|cFFFF0000WARNING|r\n\nYou are about to reset all Account Settings to defaults.\n\nThis includes class colors, reaction colors, recent colors, QoL toggles, and spec profile mappings.\n\nThe UI will reload immediately.\n\nAre you sure?",
    button1 = "Reset Account Settings", button2 = "Cancel",
    OnAccept = function(self)
        if Orbit.db then Orbit.db.AccountSettings = {} end
        Orbit:Print("|cFFFF0000Account Settings reset.|r Reloading UI...")
        ReloadUI()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

StaticPopupDialogs["ORBIT_CONFIRM_RESET_PLUGIN"] = {
    text = "|cFFFF0000WARNING|r\n\nYou are about to reset '%s' to default settings and position.\n\nThis cannot be undone.\n\nAre you sure?",
    button1 = "Reset Plugin", button2 = "Cancel",
    OnAccept = function(self, pluginName)
        local plugin = Orbit:GetPlugin(pluginName)
        if not plugin or not plugin.system then return end
        local db = Orbit.runtime and Orbit.runtime.Layouts
        if db and db["Orbit"] then db["Orbit"][plugin.system] = nil end
        if db and db["Default"] then db["Default"][plugin.system] = nil end
        if plugin.frame and Orbit.Engine.PositionManager then
            Orbit.Engine.PositionManager:ClearFrame(plugin.frame)
        end
        if plugin.frame then
            plugin.frame:ClearAllPoints()
            plugin.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        if plugin.ApplySettings then plugin:ApplySettings() end
        Orbit:Print("'" .. pluginName .. "' reset to defaults.")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function FormatValue(v, depth)
    if type(v) == "table" then
        if depth >= MAX_INSPECT_DEPTH then return "{...}" end
        local items = {}
        local count = 0
        for k, val in pairs(v) do
            if count >= MAX_INSPECT_ITEMS then items[#items + 1] = "..."; break end
            items[#items + 1] = tostring(k) .. "=" .. FormatValue(val, depth + 1)
            count = count + 1
        end
        return "{" .. table.concat(items, ", ") .. "}"
    elseif type(v) == "string" then
        return "\"" .. v .. "\""
    end
    return tostring(v)
end

local function PrintHelp()
    Orbit:Print("Commands:")
    print("  |cFF00FFFF/orbit|r — Toggle Edit Mode + Settings")
    print("  |cFF00FFFF/orbit help|r — This list")
    print("  |cFF00FFFF/orbit version|r — Version, profile, and system info")
    print("  |cFF00FFFF/orbit list|r — List all plugins with ON/OFF status")
    print("  |cFF00FFFF/orbit plugins|r — Open Plugin Manager")
    print("  |cFF00FFFF/orbit profile|r — Show current profile")
    print("  |cFF00FFFF/orbit profile <name>|r — Switch to profile")
    print("  |cFF00FFFF/orbit frames <name>|r — Show frame position/visibility")
    print("  |cFF00FFFF/orbit inspect <name>|r — Dump plugin settings")
    print("  |cFF00FFFF/orbit refresh <name>|r — Force re-apply plugin")
    print("  |cFF00FFFF/orbit reset|r — Reset Account Settings")
    print("  |cFF00FFFF/orbit reset <name>|r — Reset a plugin to defaults")
    print("  |cFF00FFFF/orbit ve|r — Open Visibility Engine")
    print("  |cFF00FFFF/orbit ve reset|r — Reset VE to defaults")
    print("  |cFF00FFFF/orbit whatsnew|r — Show changelog")
    print("  |cFF00FFFF/orbit hardreset|r — Factory reset (wipes everything)")
end

local function PrintVersion()
    local state = Orbit.API and Orbit.API:GetState() or {}
    local _, build = GetBuildInfo()
    Orbit:Print("|cFFFFD100Version:|r " .. (state.Version or "?"))
    print("  |cFFAAAAAA Profile:|r " .. (state.Profile or "?"))
    print("  |cFFAAAAAA Spec:|r " .. (state.Spec or "?"))
    print("  |cFFAAAAAA Plugins:|r " .. (state.NumPlugins or 0))
    print("  |cFFAAAAAA Combat:|r " .. (state.InCombat and "Yes" or "No"))
    print("  |cFFAAAAAA WoW Build:|r " .. (build or "?"))
end

local function PrintProfile(targetName)
    local pm = Orbit.Profile
    if not pm then Orbit:Print("ProfileManager not loaded."); return end
    if not targetName or targetName == "" then
        Orbit:Print("Active profile: |cFFFFD100" .. pm:GetActiveProfileName() .. "|r")
        local profiles = pm:GetProfiles()
        if #profiles > 1 then print("  Available: " .. table.concat(profiles, ", ")) end
        return
    end
    if not Orbit.db.profiles[targetName] then
        Orbit:Print("Profile not found: " .. targetName); return
    end
    pm:SetActiveProfile(targetName)
end

local function PrintFrameInfo(pluginName)
    if not pluginName or pluginName == "" then
        Orbit:Print("Usage: /orbit frames <plugin_name>")
        Orbit:Print("Use |cFF00FFFF/orbit list|r to see plugin names.")
        return
    end
    local plugin = Orbit:GetPlugin(pluginName)
    if not plugin then Orbit:Print("Plugin not found: " .. pluginName); return end
    Orbit:Print("Frame info for |cFFFFD100" .. (plugin.name or pluginName) .. "|r:")
    local frames = {}
    if plugin.frame then frames[#frames + 1] = { name = "frame", f = plugin.frame } end
    if plugin.essentialAnchor then frames[#frames + 1] = { name = "essentialAnchor", f = plugin.essentialAnchor } end
    if plugin.utilityAnchor then frames[#frames + 1] = { name = "utilityAnchor", f = plugin.utilityAnchor } end
    if plugin.buffIconAnchor then frames[#frames + 1] = { name = "buffIconAnchor", f = plugin.buffIconAnchor } end
    if #frames == 0 then print("  (no frames registered)"); return end
    for _, entry in ipairs(frames) do
        local f = entry.f
        local shown = f:IsShown() and "|cFF00FF00shown|r" or "|cFFFF0000hidden|r"
        local alpha = string.format("%.0f%%", (f:GetAlpha() or 1) * 100)
        local w, h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
        local point, rel, relPoint, x, y = f:GetPoint(1)
        local posStr = "unanchored"
        if point then
            local relName = (rel and rel.GetName and rel:GetName()) or "UIParent"
            posStr = string.format("%s > %s:%s (%.1f, %.1f)", point, relName, relPoint or "?", x or 0, y or 0)
        end
        print(string.format("  |cFFAAAAAA%s:|r %s  alpha=%s  size=%dx%d", entry.name, shown, alpha, w, h))
        print(string.format("    anchor: %s", posStr))
    end
end

local function PrintInspect(pluginName)
    if not pluginName or pluginName == "" then
        Orbit:Print("Usage: /orbit inspect <plugin_name>")
        Orbit:Print("Use |cFF00FFFF/orbit list|r to see plugin names.")
        return
    end
    local plugin = Orbit:GetPlugin(pluginName)
    if not plugin or not plugin.system then Orbit:Print("Plugin not found: " .. pluginName); return end
    local layouts = Orbit.runtime and Orbit.runtime.Layouts
    local settings = layouts and layouts["Orbit"] and layouts["Orbit"][plugin.system]
    if not settings then Orbit:Print("No saved settings for " .. pluginName); return end
    Orbit:Print("Settings for |cFFFFD100" .. plugin.name .. "|r (" .. plugin.system .. "):")
    local count = 0
    for key, value in pairs(settings) do
        if count >= MAX_INSPECT_ITEMS then print("  |cFFAAAAAA...(truncated)|r"); break end
        print("  |cFFFFD100" .. tostring(key) .. "|r = " .. FormatValue(value, 0))
        count = count + 1
    end
end

-- [ SLASH HANDLER ]---------------------------------------------------------------------------------

SLASH_ORBIT1 = "/orbit"
SLASH_ORBIT2 = "/orb"

SlashCmdList["ORBIT"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do table.insert(args, word) end
    local cmd = args[1] and args[1]:lower() or ""
    local function RestArgs() return msg:match("^%S+%s+(.+)$") end
    local Panel = Orbit.OptionsPanel

    if cmd == "" then
        if EditModeManagerFrame then
            if EditModeManagerFrame:IsShown() then
                HideUIPanel(EditModeManagerFrame)
                Panel:Hide()
            else
                ShowUIPanel(EditModeManagerFrame)
                Panel:Open("Global")
            end
        else
            Orbit:Print("Edit Mode not available.")
        end
        return
    end

    if cmd == "help" or cmd == "?" then PrintHelp(); return end
    if cmd == "version" or cmd == "ver" or cmd == "v" then PrintVersion(); return end
    if cmd == "whatsnew" then Orbit:ShowWhatsNew(); return end

    if cmd == "ve" then
        local sub = args[2] and args[2]:lower() or ""
        if sub == "reset" then
            if Orbit.db then Orbit.db.VisibilityEngine = {} end
            if Orbit.VisibilityEngine then
                for _, entry in ipairs(Orbit.VisibilityEngine:GetBlizzardFrames()) do
                    local f = _G[entry.blizzardFrame]
                    if f then f:SetAlpha(1) end
                end
            end
            if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
            Orbit.MountedVisibility:Refresh(true)
            local systems = Orbit.Engine and Orbit.Engine.systems
            if systems then
                for _, plugin in pairs(systems) do
                    if plugin.ApplySettings then plugin:ApplySettings() end
                end
            end
            Orbit:Print("Visibility Engine reset to defaults.")
        else
            if Orbit._pluginSettingsCategoryID then
                Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
                if Orbit._openVETab then C_Timer.After(0.05, Orbit._openVETab) end
            else
                Orbit:Print("Plugin Manager not yet loaded.")
            end
        end
        return
    end

    if cmd == "plugins" then
        if Orbit._pluginSettingsCategoryID then
            Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
        else
            Orbit:Print("Plugin Manager not yet loaded.")
        end
    elseif cmd == "list" then
        local systems = Orbit.Engine and Orbit.Engine.systems
        if not systems or #systems == 0 then Orbit:Print("No plugins registered."); return end
        Orbit:Print("Registered plugins (use name with other commands):")
        for _, plugin in ipairs(systems) do
            local status = Orbit:IsPluginEnabled(plugin.name) and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
            print("  " .. status .. "  |cFFFFD100" .. (plugin.name or "?") .. "|r")
        end
    elseif cmd == "profile" then
        PrintProfile(RestArgs())
    elseif cmd == "frames" then
        PrintFrameInfo(RestArgs())
    elseif cmd == "inspect" then
        PrintInspect(RestArgs())
    elseif cmd == "reset" then
        local target = RestArgs() or ""
        if target == "" then
            StaticPopup_Show("ORBIT_CONFIRM_RESET_ACCOUNT")
        else
            local plugin = Orbit:GetPlugin(target)
            if not plugin then Orbit:Print("Plugin not found: " .. target); return end
            local dialog = StaticPopup_Show("ORBIT_CONFIRM_RESET_PLUGIN", plugin.name)
            if dialog then dialog.data = plugin.name end
        end
    elseif cmd == "hardreset" then StaticPopup_Show("ORBIT_CONFIRM_HARD_RESET")
    elseif cmd == "portal" or cmd == "p" then
        local subCmd = args[2] and args[2]:lower() or ""
        Orbit.EventBus:Fire("ORBIT_PORTAL_COMMAND", subCmd)
    elseif cmd == "refresh" then
        local target = RestArgs() or ""
        if target == "" then
            Orbit:Print("Usage: /orbit refresh <plugin_name>")
            return
        end
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons.regionCache = setmetatable({}, { __mode = "k" })
        end
        local plugin = Orbit:GetPlugin(target)
        if plugin then
            if plugin.ReapplyParentage then plugin:ReapplyParentage() end
            if plugin.ApplyAll then plugin:ApplyAll()
            elseif plugin.ApplySettings then plugin:ApplySettings() end
            Orbit:Print(target .. " refreshed.")
        else
            Orbit:Print("Plugin not found: " .. target)
        end
    elseif cmd == "flush" then
        if Orbit.ViewerInjection then
            Orbit.ViewerInjection:FlushAll()
            Orbit:Print("Cleared all injected cooldown icons.")
        else
            Orbit:Print("ViewerInjection not loaded.")
        end
    else
        Orbit:Print("Unknown command: " .. cmd .. ". Type |cFF00FFFF/orbit help|r for a list.")
    end
end
