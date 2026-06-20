local _, addonTable = ...
local Orbit = addonTable
local L = Orbit.L

-- [ ORBIT API ]--------------------------------------------------------------------------------------
---@class OrbitAPI
Orbit.API = {}
local API = Orbit.API

function API:GetState()
    return {
        Version = Orbit.version,
        Profile = Orbit.Profile and Orbit.Profile:GetActiveProfileName() or "Unknown",
        Spec = (GetSpecialization and select(2, GetSpecializationInfo(GetSpecialization() or 1))) or "None",
        InCombat = InCombatLockdown(),
        NumPlugins = Orbit.Engine and Orbit.Engine.systems and #Orbit.Engine.systems or 0,
    }
end

function API:ResetProfile(profileName)
    if InCombatLockdown() then
        Orbit:Print(L.MSG_NO_RESET_IN_COMBAT)
        return false
    end

    local pm = Orbit.Profile
    if not pm then
        return false
    end

    profileName = profileName or pm:GetActiveProfileName()

    -- Safety: Ensure the active profile exists before nuking
    if not Orbit.db.profiles[pm:GetActiveProfileName()] then
        pm:Initialize()
    end

    Orbit:Print(L.MSG_RESETTING_PROFILE_F:format(profileName))

    -- 1. Nuke existing data using raw DB access (bypass "Active" check in DeleteProfile)
    Orbit.db.profiles[profileName] = nil

    -- ":CLEAN:" sentinel tells CreateProfile to use defaults instead of cloning.
    pm:CreateProfile(profileName, ":CLEAN:")

    -- 3. Reload if it was active
    if profileName == pm:GetActiveProfileName() then
        pm:SetActiveProfile(profileName)
    end

    Orbit:Print(L.MSG_PROFILE_RESET_DONE_F:format(profileName))
    return true
end

function API:HardReset()
    if InCombatLockdown() then
        return
    end

    -- Wipe SavedVariables
    OrbitDB = nil

    Orbit:Print(L.MSG_FACTORY_RESET_INITIATED)
    ReloadUI()
end

function API:UnlockFrames()
    if InCombatLockdown() then
        Orbit:Print(L.MSG_NO_MOVE_IN_COMBAT)
        return
    end

    local count = 0
    if Orbit.Engine and Orbit.Engine.systems then
        for _, plugin in ipairs(Orbit.Engine.systems) do
            -- 1. Standard Plugins (plugin.frame)
            if plugin.frame and plugin.frame.ClearAllPoints then
                plugin.frame:ClearAllPoints()
                plugin.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                plugin.frame:Show()
                count = count + 1
            end

            -- 2. Multi-Anchor Plugins (e.g. CooldownManager)
            if plugin.essentialAnchor or plugin.utilityAnchor or plugin.buffIconAnchor then
                local anchors = { plugin.essentialAnchor, plugin.utilityAnchor, plugin.buffIconAnchor }
                for _, anchor in ipairs(anchors) do
                    if anchor and anchor.ClearAllPoints then
                        anchor:ClearAllPoints()
                        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                        anchor:Show()
                        count = count + 1
                    end
                end
            end

            -- 3. Generic Viewers/Subframes (Future proofing)
            if plugin.viewers then
                for _, viewer in pairs(plugin.viewers) do
                    if viewer.ClearAllPoints then
                        viewer:ClearAllPoints()
                        viewer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                        viewer:Show()
                        count = count + 1
                    end
                end
            end
        end
    end

    -- Flush pending positions so these new spots stick (if using Persistence)
    if Orbit.Engine.PositionManager then
        Orbit.Engine.PositionManager:FlushToStorage()
    end

    Orbit:Print(L.MSG_FRAMES_RESET_F:format(count))
end

function API:DumpDebugInfo()
    local parts = {}

    -- System Info
    table.insert(parts, "Orbit " .. (Orbit.version or "?"))
    table.insert(parts, "Profile: " .. (Orbit.Profile and Orbit.Profile:GetActiveProfileName() or "?"))
    table.insert(parts, "Spec: " .. ((GetSpecialization and select(2, GetSpecializationInfo(GetSpecialization() or 1))) or "None"))
    table.insert(parts, "Date: " .. date("%Y-%m-%d %H:%M:%S"))
    table.insert(parts, "")

    -- Error Log
    table.insert(parts, "[ ERROR LOG ]")
    local log = OrbitErrorLogDB and OrbitErrorLogDB.entries
    if log and #log > 0 then
        for i, entry in ipairs(log) do
            table.insert(parts, string.format("#%d [%s] %s: %s", i, entry.time or "?", entry.source or "?", entry.error or "?"))
        end
    else
        table.insert(parts, "No errors logged.")
    end

    return table.concat(parts, "\n")
end

-- [ MAINTENANCE OPERATIONS ]-------------------------------------------------------------------------
function API:ResetAccountSettings()
    Orbit.Engine.Layout:ShowConfirm({
        title = L.CMN_RESET_ACCOUNT_SETTINGS,
        text = L.CMD_RESET_ACCOUNT_WARNING,
        acceptText = L.CMN_RESET_ACCOUNT_SETTINGS,
        onAccept = function()
            if Orbit.db then Orbit.db.AccountSettings = {} end
            Orbit:Print(L.MSG_ACCOUNT_RESET)
            ReloadUI()
        end,
    })
end

function API:ResetPluginSettings(plugin)
    Orbit.Engine.Layout:ShowConfirm({
        title = L.CMN_RESET_PLUGIN,
        text = L.CMD_RESET_PLUGIN_WARNING_F:format(plugin.name),
        acceptText = L.CMN_RESET_PLUGIN,
        onAccept = function()
            if not plugin.system then return end
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
            Orbit:Print(L.MSG_PLUGIN_RESET_F:format(plugin.name))
        end,
    })
end

function API:ConfirmHardReset()
    Orbit.Engine.Layout:ShowConfirm({
        title = L.CMN_FACTORY_RESET,
        text = L.CMD_HARD_RESET_WARNING,
        acceptText = L.CMN_FACTORY_RESET,
        onAccept = function() Orbit.API:HardReset() end,
    })
end

-- [ DIAGNOSTICS ]------------------------------------------------------------------------------------
local MAX_INSPECT_DEPTH = 2
local MAX_INSPECT_ITEMS = 20

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

function API:PrintVersion()
    local state = self:GetState()
    local _, build = GetBuildInfo()
    Orbit:Print("|cFFFFD100" .. L.CMD_VERSION_LABEL .. "|r " .. (state.Version or "?"))
    print("  |cFFAAAAAA " .. L.CMD_PROFILE_LABEL .. "|r " .. (state.Profile or "?"))
    print("  |cFFAAAAAA " .. L.CMD_SPEC_LABEL .. "|r " .. (state.Spec or "?"))
    print("  |cFFAAAAAA " .. L.CMD_PLUGINS_LABEL .. "|r " .. (state.NumPlugins or 0))
    print("  |cFFAAAAAA " .. L.CMD_COMBAT_LABEL .. "|r " .. (state.InCombat and L.CMN_YES or L.CMN_NO))
    print("  |cFFAAAAAA " .. L.CMD_WOW_BUILD_LABEL .. "|r " .. (build or "?"))
end

function API:InspectPlugin(pluginName)
    if not pluginName or pluginName == "" then return end
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

-- Export to global for external scripts
_G["OrbitAPI"] = Orbit.API
