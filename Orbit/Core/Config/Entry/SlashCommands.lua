-- [ ORBIT SLASH COMMANDS ]---------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local POPUP_PREFERRED_INDEX = 3
local MAX_INSPECT_DEPTH = 2
local MAX_INSPECT_ITEMS = 20

-- [ CONFIRMATION POPUPS ]----------------------------------------------------------------------------
StaticPopupDialogs["ORBIT_CONFIRM_HARD_RESET"] = {
    text = L.CMD_HARD_RESET_WARNING,
    button1 = L.CMN_FACTORY_RESET, button2 = L.CMN_CANCEL,
    OnAccept = function(self) Orbit.API:HardReset() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

StaticPopupDialogs["ORBIT_CONFIRM_RESET_ACCOUNT"] = {
    text = L.CMD_RESET_ACCOUNT_WARNING,
    button1 = L.CMN_RESET_ACCOUNT_SETTINGS, button2 = L.CMN_CANCEL,
    OnAccept = function(self)
        if Orbit.db then Orbit.db.AccountSettings = {} end
        Orbit:Print(L.MSG_ACCOUNT_RESET)
        ReloadUI()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

StaticPopupDialogs["ORBIT_CONFIRM_RESET_PLUGIN"] = {
    text = L.CMD_RESET_PLUGIN_WARNING_F,
    button1 = L.CMN_RESET_PLUGIN, button2 = L.CMN_CANCEL,
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
        Orbit:Print(L.MSG_PLUGIN_RESET_F:format(pluginName))
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

-- [ HELPERS ]----------------------------------------------------------------------------------------
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
    Orbit:Print(L.CMD_HELP_HEADER)
    print("  " .. L.CMD_HELP_ORBIT)
    print("  " .. L.CMD_HELP_HELP)
    print("  " .. L.CMD_HELP_VERSION)
    print("  " .. L.CMD_HELP_LIST)
    print("  " .. L.CMD_HELP_PLUGINS)
    print("  " .. L.CMD_HELP_PROFILE_SHOW)
    print("  " .. L.CMD_HELP_PROFILE_SWITCH)
    print("  " .. L.CMD_HELP_FRAMES)
    print("  " .. L.CMD_HELP_INSPECT)
    print("  " .. L.CMD_HELP_REFRESH)
    print("  " .. L.CMD_HELP_RESET)
    print("  " .. L.CMD_HELP_RESET_PLUGIN)
    print("  " .. L.CMD_HELP_VE)
    print("  " .. L.CMD_HELP_VE_RESET)
    print("  " .. L.CMD_HELP_TRACKED_FLUSH)
    print("  " .. L.CMD_HELP_WHATSNEW)
    print("  " .. L.CMD_HELP_HARDRESET)
end

local function PrintVersion()
    local state = Orbit.API and Orbit.API:GetState() or {}
    local _, build = GetBuildInfo()
    Orbit:Print("|cFFFFD100" .. L.CMD_VERSION_LABEL .. "|r " .. (state.Version or "?"))
    print("  |cFFAAAAAA " .. L.CMD_PROFILE_LABEL .. "|r " .. (state.Profile or "?"))
    print("  |cFFAAAAAA " .. L.CMD_SPEC_LABEL .. "|r " .. (state.Spec or "?"))
    print("  |cFFAAAAAA " .. L.CMD_PLUGINS_LABEL .. "|r " .. (state.NumPlugins or 0))
    print("  |cFFAAAAAA " .. L.CMD_COMBAT_LABEL .. "|r " .. (state.InCombat and "Yes" or "No"))
    print("  |cFFAAAAAA " .. L.CMD_WOW_BUILD_LABEL .. "|r " .. (build or "?"))
end

local function PrintProfile(targetName)
    local pm = Orbit.Profile
    if not pm then Orbit:Print(L.MSG_PROFILE_MGR_NOT_LOADED); return end
    if not targetName or targetName == "" then
        Orbit:Print(L.MSG_ACTIVE_PROFILE_F:format("|cFFFFD100" .. pm:GetActiveProfileName() .. "|r"))
        local profiles = pm:GetProfiles()
        if #profiles > 1 then print("  " .. L.MSG_AVAILABLE_PROFILES_F:format(table.concat(profiles, ", "))) end
        return
    end
    if not Orbit.db.profiles[targetName] then
        Orbit:Print(L.MSG_PROFILE_NOT_FOUND_F:format(targetName)); return
    end
    pm:SetActiveProfile(targetName)
end

local function PrintFrameInfo(pluginName)
    if not pluginName or pluginName == "" then
        Orbit:Print(L.CMD_FRAMES_USAGE)
        Orbit:Print(L.CMD_SEE_LIST)
        return
    end
    local plugin = Orbit:GetPlugin(pluginName)
    if not plugin then Orbit:Print(L.MSG_PLUGIN_NOT_FOUND_F:format(pluginName)); return end
    Orbit:Print(L.MSG_FRAME_INFO_F:format(plugin.name or pluginName))
    local frames = {}
    if plugin.frame then frames[#frames + 1] = { name = "frame", f = plugin.frame } end
    if plugin.essentialAnchor then frames[#frames + 1] = { name = "essentialAnchor", f = plugin.essentialAnchor } end
    if plugin.utilityAnchor then frames[#frames + 1] = { name = "utilityAnchor", f = plugin.utilityAnchor } end
    if plugin.buffIconAnchor then frames[#frames + 1] = { name = "buffIconAnchor", f = plugin.buffIconAnchor } end
    if #frames == 0 then print("  " .. L.MSG_NO_FRAMES_REGISTERED); return end
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

-- [ ANCHOR DIAGNOSTIC ]-----------------------------------------------------------------------------
local function PrintAnchor(frameName)
    if not frameName or frameName == "" then
        Orbit:Print("Usage: /orbit anchor <FrameName>  (e.g. /orbit anchor OrbitPlayerPower)")
        return
    end
    local f = _G[frameName]
    if not f then Orbit:Print("No frame named '" .. frameName .. "' in _G"); return end
    local A = Orbit.Engine.FrameAnchor
    local G = Orbit.Engine.AnchorGraph
    if not A or not G then Orbit:Print("FrameAnchor / AnchorGraph not loaded"); return end

    local phys = A.anchors[f]
    local log = A.logicalAnchors and A.logicalAnchors[f]
    print("|cFFFFD100" .. frameName .. "|r  skipped=" .. tostring(G:IsSkipped(f)))
    if phys and phys.parent then
        print("  physical: " .. (phys.parent:GetName() or "?") .. " edge=" .. tostring(phys.edge))
    else
        print("  physical: |cFFFF0000NONE|r")
        local pt, rel, _, x, y = f:GetPoint(1)
        if pt then print(string.format("    SetPoint: %s @ %s (%.0f, %.0f)", pt, (rel and rel.GetName and rel:GetName()) or "UIParent", x or 0, y or 0)) end
    end
    if log and log.parent then
        print("  logical:  " .. (log.parent:GetName() or "?") .. " edge=" .. tostring(log.edge))
    end

    local p = f.orbitPlugin
    local sysIdx = f.systemIndex
    if p and sysIdx and p.GetSetting then
        local anchor = p:GetSetting(sysIdx, "Anchor")
        local position = p:GetSetting(sysIdx, "Position")
        if anchor then
            print("  saved Anchor: target=" .. tostring(anchor.target) .. " edge=" .. tostring(anchor.edge))
            print("    fallback=" .. tostring(anchor.fallback))
            if anchor.ancestry then
                print("    ancestry=" .. table.concat(anchor.ancestry, " > "))
            else
                print("    ancestry=|cFFFF0000nil|r  (re-drag in edit mode to populate)")
            end
            local function probe(name, label)
                if not name then return end
                local cand = _G[name]
                if not cand then print("    " .. label .. " " .. name .. ": |cFFFF0000not in _G|r"); return end
                local skipped = G:IsSkipped(cand)
                local hasParent = A.anchors[cand] and A.anchors[cand].parent
                local parentStr = hasParent and (" (parent=" .. (A.anchors[cand].parent:GetName() or "?") .. ")") or " (no parent)"
                print(string.format("    %s %s: exists, skipped=%s%s", label, name, tostring(skipped), parentStr))
            end
            probe(anchor.target, "target")
            if anchor.ancestry then
                for i = 1, #anchor.ancestry do probe(anchor.ancestry[i], "  ancestry[" .. i .. "]") end
            elseif anchor.fallback then
                probe(anchor.fallback, "fallback")
            end
        elseif position then
            print("  saved Position: " .. position.point .. " (" .. (position.x or 0) .. ", " .. (position.y or 0) .. ")")
        else
            print("  no saved Anchor/Position (using defaultPosition)")
        end
    end
end

local function PrintInspect(pluginName)
    if not pluginName or pluginName == "" then
        Orbit:Print(L.CMD_INSPECT_USAGE)
        Orbit:Print(L.CMD_SEE_LIST)
        return
    end
    local plugin = Orbit:GetPlugin(pluginName)
    if not plugin or not plugin.system then Orbit:Print(L.MSG_PLUGIN_NOT_FOUND_F:format(pluginName)); return end
    local layouts = Orbit.runtime and Orbit.runtime.Layouts
    local settings = layouts and layouts["Orbit"] and layouts["Orbit"][plugin.system]
    if not settings then Orbit:Print(L.MSG_NO_SAVED_SETTINGS_F:format(pluginName)); return end
    Orbit:Print(L.MSG_INSPECT_HEADER_F:format(plugin.name, tostring(plugin.system)))
    local count = 0
    for key, value in pairs(settings) do
        if count >= MAX_INSPECT_ITEMS then print("  " .. L.MSG_INSPECT_TRUNCATED); break end
        print("  |cFFFFD100" .. tostring(key) .. "|r = " .. FormatValue(value, 0))
        count = count + 1
    end
end

-- [ SLASH HANDLER ]----------------------------------------------------------------------------------
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
                securecall("HideUIPanel", EditModeManagerFrame)
                Panel:Hide()
            else
                securecall("ShowUIPanel", EditModeManagerFrame)
                Panel:Open("Global")
            end
        else
            Orbit:Print(L.MSG_EDIT_MODE_UNAVAILABLE)
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
            Orbit:Print(L.MSG_VE_RESET)
        else
            if Orbit._pluginSettingsCategoryID then
                Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
                if Orbit._openVETab then C_Timer.After(0.05, Orbit._openVETab) end
            else
                Orbit:Print(L.MSG_PLUGIN_MGR_NOT_LOADED)
            end
        end
        return
    end

    if cmd == "plugins" then
        if Orbit._pluginSettingsCategoryID then
            Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
        else
            Orbit:Print(L.MSG_PLUGIN_MGR_NOT_LOADED)
        end
    elseif cmd == "list" then
        local systems = Orbit.Engine and Orbit.Engine.systems
        if not systems or #systems == 0 then Orbit:Print(L.MSG_NO_PLUGINS); return end
        Orbit:Print(L.MSG_PLUGINS_LIST_HEADER)
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
    elseif cmd == "anchor" then
        PrintAnchor(RestArgs())
    elseif cmd == "reset" then
        local target = RestArgs() or ""
        if target == "" then
            StaticPopup_Show("ORBIT_CONFIRM_RESET_ACCOUNT")
        else
            local plugin = Orbit:GetPlugin(target)
            if not plugin then Orbit:Print(L.MSG_PLUGIN_NOT_FOUND_F:format(target)); return end
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
            Orbit:Print(L.CMD_REFRESH_USAGE)
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
            Orbit:Print(L.MSG_PLUGIN_REFRESHED_F:format(target))
        else
            Orbit:Print(L.MSG_PLUGIN_NOT_FOUND_F:format(target))
        end
    elseif cmd == "flush" then
        if Orbit.ViewerInjection then
            Orbit.ViewerInjection:FlushAll()
            Orbit:Print(L.MSG_COOLDOWNS_CLEARED)
        else
            Orbit:Print(L.MSG_VIEWER_INJECTION_MISSING)
        end
    elseif cmd == "tracked" then
        local sub = args[2] and args[2]:lower() or ""
        if sub == "flush" then
            local plugin = Orbit:GetPlugin("Orbit_Tracked")
            if plugin and plugin.FlushCurrentSpec then
                plugin:FlushCurrentSpec()
            else
                Orbit:Print(L.MSG_TRACKED_NOT_LOADED)
            end
        else
            Orbit:Print(L.CMD_TRACKED_USAGE)
        end
    else
        Orbit:Print(L.CMD_UNKNOWN_COMMAND_F:format(cmd))
    end
end
