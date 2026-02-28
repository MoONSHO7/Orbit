-- [ PROFILE MANAGER ]-------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable

---@class OrbitProfileManager
Orbit.Profile = Orbit.Profile or {}

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local CLEAN_PROFILE_SOURCE = ":CLEAN:"
local DEBOUNCE_KEY = "ProfileManager_SpecCheck"
local DEBOUNCE_DELAY = 0.1
local NO_SPEC_PROFILE = "No-Spec"

local DELAYED_REFRESH = 0.1

local GLOBAL_DEFAULTS = {
    Font = "PT Sans Narrow",
    BorderSize = 2,
    TextScale = "Medium",
    FontOutline = "OUTLINE",
    BackdropColour = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 },
    BarColor = { r = 0.2, g = 0.8, b = 0.2, a = 1 },
    BarColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 }, type = "class" } } },
    ClassColorBackground = false,
    UseClassColors = true,
    OverlayAllFrames = false,
    HideWhenMounted = false,
    OverlayTexture = "Orbit Gradient",
}

local DUPLICATE_SPEC_NAMES = {
    ["Protection"] = true,
    ["Restoration"] = true,
    ["Holy"] = true,
}

-- [ STATE ]-----------------------------------------------------------------------------------------

local isActivatingProfile = false

-- [ UTILITY ]---------------------------------------------------------------------------------------

local function CopyTable(src, dest)
    if type(dest) ~= "table" then dest = {} end
    for k, v in pairs(src) do
        dest[k] = type(v) == "table" and CopyTable(v, {}) or v
    end
    return dest
end

local function SafeApplyPlugin(plugin)
    local success, err = pcall(function() plugin:ApplySettings(nil) end)
    if not success then
        Orbit:Print("Error refreshing plugin " .. (plugin.name or "?") .. ": " .. tostring(err))
    end
end

-- [ INITIALIZATION ]--------------------------------------------------------------------------------

function Orbit.Profile:Initialize()
    if not Orbit.db then Orbit.db = {} end
    if not Orbit.db.profiles then Orbit.db.profiles = {} end

    if not Orbit.db.GlobalSettings then Orbit.db.GlobalSettings = {} end
    local gs = Orbit.db.GlobalSettings
    for key, default in pairs(GLOBAL_DEFAULTS) do
        if gs[key] == nil then
            gs[key] = type(default) == "table" and CopyTable(default, {}) or default
        end
    end

    if not Orbit.db.profiles["Default"] then
        Orbit.db.profiles["Default"] = CopyTable(self.defaults, {})
    end

    if not Orbit.db.activeProfile then Orbit.db.activeProfile = "Default" end

    Orbit.runtime = Orbit.runtime or {}
    if not Orbit.runtime.Layouts then
        local activeProfile = Orbit.db.profiles[Orbit.db.activeProfile]
        if activeProfile then
            if not activeProfile.Layouts then activeProfile.Layouts = {} end
            Orbit.runtime.Layouts = activeProfile.Layouts
        end
    end

    local specName = self:GetCurrentSpecName()
    if specName and specName ~= "" then
        self:EnsureSpecProfile(specName)
        self:SetActiveProfile(specName)
    else
        if not Orbit.db.profiles[NO_SPEC_PROFILE] then
            Orbit.db.profiles[NO_SPEC_PROFILE] = CopyTable(self.defaults, {})
            Orbit:Print("Created '" .. NO_SPEC_PROFILE .. "' profile for characters without a specialization.")
        end
        self:SetActiveProfile(NO_SPEC_PROFILE)
    end

    for _, profileData in pairs(Orbit.db.profiles) do
        if not profileData.GlobalSettings then
            profileData.GlobalSettings = CopyTable(Orbit.db.GlobalSettings, {})
        end
    end

    self:InitializeSpecSwitching()
end

-- [ PROFILE GETTERS ]-------------------------------------------------------------------------------

function Orbit.Profile:GetActiveProfileName() return Orbit.db.activeProfile or "Default" end

function Orbit.Profile:GetProfiles()
    local names = {}
    for name, _ in pairs(Orbit.db.profiles) do table.insert(names, name) end
    table.sort(names)
    return names
end

-- [ PROFILE CRUD ]----------------------------------------------------------------------------------

function Orbit.Profile:CreateProfile(name, copyFrom)
    if Orbit.db.profiles[name] then return false end

    local sourceName = copyFrom or self:GetActiveProfileName()

    if sourceName == self:GetActiveProfileName() then
        if Orbit.Engine and Orbit.Engine.PositionManager then
            Orbit.Engine.PositionManager:FlushToStorage()
        end
        self:FlushGlobalSettings()
    end

    local sourceData
    if sourceName == CLEAN_PROFILE_SOURCE then
        sourceData = self.defaults
    else
        if not Orbit.db.profiles[sourceName] then sourceName = "Default" end
        sourceData = Orbit.db.profiles[sourceName]
    end

    Orbit.db.profiles[name] = CopyTable(sourceData, {})
    return true
end

function Orbit.Profile:DeleteProfile(name)
    if name == "Default" then return false end
    if name == self:GetActiveProfileName() then return false end
    Orbit.db.profiles[name] = nil
    return true
end

function Orbit.Profile:SetActiveProfile(name)
    if not Orbit.db.profiles[name] then return false end
    if isActivatingProfile then return false end

    local profile = Orbit.db.profiles[name]
    if not profile.Layouts then profile.Layouts = {} end

    if Orbit.db.activeProfile == name then
        Orbit.runtime = Orbit.runtime or {}
        Orbit.runtime.Layouts = profile.Layouts
        if profile.GlobalSettings then Orbit.db.GlobalSettings = CopyTable(profile.GlobalSettings, {}) end
        return true
    end

    isActivatingProfile = true

    if Orbit.Engine and Orbit.Engine.PositionManager then
        Orbit.Engine.PositionManager:FlushToStorage()
        Orbit.Engine.PositionManager:DiscardChanges()
    end

    local oldProfile = Orbit.db.profiles[Orbit.db.activeProfile]
    if oldProfile then oldProfile.GlobalSettings = CopyTable(Orbit.db.GlobalSettings, {}) end

    Orbit.db.activeProfile = name
    Orbit.runtime = Orbit.runtime or {}
    Orbit.runtime.Layouts = profile.Layouts

    if profile.GlobalSettings then Orbit.db.GlobalSettings = CopyTable(profile.GlobalSettings, {}) end
    Orbit:Print(name .. " Profile Loaded.")

    if Orbit.Engine and Orbit.Engine.systems then
        for _, plugin in ipairs(Orbit.Engine.systems) do
            if plugin.ApplySettings and plugin.refreshPriority then SafeApplyPlugin(plugin) end
        end
        for _, plugin in ipairs(Orbit.Engine.systems) do
            if plugin.ApplySettings and not plugin.refreshPriority then SafeApplyPlugin(plugin) end
        end
        C_Timer.After(DELAYED_REFRESH, function()
            for _, plugin in ipairs(Orbit.Engine.systems) do
                if plugin.ApplySettings then pcall(function() plugin:ApplySettings(nil) end) end
            end
        end)
    end

    if Orbit.OptionsPanel and Orbit.OptionsPanel.Refresh then Orbit.OptionsPanel:Refresh() end
    isActivatingProfile = false

    if Orbit.EventBus then Orbit.EventBus:Fire("ORBIT_PROFILE_CHANGED", name) end
    return true
end

-- [ SPEC MANAGEMENT ]-------------------------------------------------------------------------------

function Orbit.Profile:GetCurrentSpecName()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local _, specName = GetSpecializationInfo(specIndex)
    if not specName then return nil end

    if DUPLICATE_SPEC_NAMES[specName] then
        local _, className = UnitClass("player")
        if className then
            return specName .. " (" .. className:sub(1, 1):upper() .. className:sub(2):lower() .. ")"
        end
    end
    return specName
end

function Orbit.Profile:EnsureSpecProfile(specName)
    if not specName or specName == "" then return false end
    if Orbit.db.profiles[specName] then return true end
    self:CreateProfile(specName, nil)
    Orbit:Print("Created profile '" .. specName .. "' (Copied from previous active profile)")
    return true
end

function Orbit.Profile:CopyProfileData(sourceProfileName)
    local activeProfileName = self:GetActiveProfileName()
    if not sourceProfileName or sourceProfileName == "" then return false, "No source profile specified" end
    if not Orbit.db.profiles[sourceProfileName] then return false, "Source profile does not exist" end
    if sourceProfileName == activeProfileName then return false, "Cannot copy from the active profile" end

    local sourceProfile = Orbit.db.profiles[sourceProfileName]
    local activeProfile = Orbit.db.profiles[activeProfileName]
    activeProfile.Layouts = CopyTable(sourceProfile.Layouts or {}, {})
    activeProfile.GlobalSettings = CopyTable(sourceProfile.GlobalSettings or Orbit.db.GlobalSettings, {})
    Orbit.db.GlobalSettings = CopyTable(activeProfile.GlobalSettings, {})
    Orbit:Print("Copied settings from '" .. sourceProfileName .. "' to '" .. activeProfileName .. "'")
    return true
end

function Orbit.Profile:CheckSpecProfile()
    if not Orbit.db or not Orbit.db.profiles then return end
    local specName = self:GetCurrentSpecName()
    if not specName then return end
    self:EnsureSpecProfile(specName)
    self:SetActiveProfile(specName)
end

function Orbit.Profile:InitializeSpecSwitching()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
        Orbit.Async:Debounce(DEBOUNCE_KEY, function() self:CheckSpecProfile() end, DEBOUNCE_DELAY)
    end)
end

function Orbit.Profile:FlushGlobalSettings()
    local active = Orbit.db.profiles[Orbit.db.activeProfile]
    if active then active.GlobalSettings = CopyTable(Orbit.db.GlobalSettings, {}) end
end

-- [ IMPORT / EXPORT ]-------------------------------------------------------------------------------

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

function Orbit.Profile:ExportProfile()
    self:FlushGlobalSettings()
    local exportData = {
        meta = { addon = "Orbit", version = Orbit.version, date = date(), type = "Collection", name = "All Profiles Backup" },
        data = Orbit.db.profiles,
    }
    return LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(exportData)))
end

function Orbit.Profile:ImportProfile(str, name)
    local decoded = LibDeflate:DecodeForPrint(str)
    if not decoded then return false, "Decoding Failed" end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return false, "Decompression Failed" end
    local success, t = LibSerialize:Deserialize(decompressed)
    if not success then return false, "Deserialization Failed: " .. tostring(t) end
    if type(t) ~= "table" or not t.meta or t.meta.addon ~= "Orbit" then return false, "Not an Orbit Profile" end

    if t.meta.type == "Collection" then
        Orbit.db.profiles = {}
        local count = 0
        for profileName, profileData in pairs(t.data) do
            Orbit.db.profiles[profileName] = profileData
            count = count + 1
        end
        Orbit:Print(string.format("Imported Collection (%d profiles). Existing profiles wiped.", count))
        self:CheckSpecProfile()
        return true
    end

    if not name or name == "" then name = t.meta.name or ("Imported " .. date("%Y%m%d")) end
    Orbit:Print(string.format("Importing profile '%s' (from %s)...", name, t.meta.date or "Unknown"))
    Orbit.db.profiles[name] = t.data
    if name == self:GetActiveProfileName() then self:SetActiveProfile(name) end
    return true
end
