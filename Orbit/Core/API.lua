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

    -- Safety: Ensure Default profile exists before nuking
    if not Orbit.db.profiles["Default"] then
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

    Orbit:Print(string.format("Reset positions for %d frames.", count))
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

-- Export to global for external scripts
_G["OrbitAPI"] = Orbit.API
