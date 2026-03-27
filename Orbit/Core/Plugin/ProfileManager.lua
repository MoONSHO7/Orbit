-- [ PROFILE MANAGER ]-------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable

---@class OrbitProfileManager
Orbit.Profile = Orbit.Profile or {}

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local CLEAN_PROFILE_SOURCE = ":CLEAN:"
local DEBOUNCE_KEY = "ProfileManager_SpecCheck"
local DEBOUNCE_DELAY = 0.1
local DEFAULT_PROFILE = "Global"
local DELAYED_REFRESH = 0.1
local PLAYER_CLASS = select(2, UnitClass("player"))

local GLOBAL_DEFAULTS = {
    Font = "Barlow Condensed Bold",
    BorderSize = 2,
    IconBorderSize = 4,
    FontOutline = "OUTLINE",
    BackdropColour = { r = 0.145, g = 0.145, b = 0.145, a = 0.7 },
    BarColor = { r = 0.2, g = 0.8, b = 0.2, a = 1 },
    BarColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 }, type = "class" } } },
    ClassColorBackground = false,
    UseClassColors = true,
    OverlayAllFrames = false,
    HideWhenMounted = false,
    OverlayTexture = "None",
}

-- TODO(REMOVE): Only used by _MigrateLegacySpecProfiles
-- Spec names that are shared across classes (used for legacy migration only)
local DUPLICATE_SPEC_NAMES = {
    ["Protection"] = true,
    ["Restoration"] = true,
    ["Holy"] = true,
}

-- [ STATE ]-----------------------------------------------------------------------------------------

local isActivatingProfile = false

-- [ CLASS-SCOPED SPEC PROFILES ]--------------------------------------------------------------------

function Orbit.Profile:IsSpecProfilesEnabled()
    local tbl = Orbit.db and Orbit.db.classSpecProfiles
    return tbl and tbl[PLAYER_CLASS] or false
end

function Orbit.Profile:SetSpecProfilesEnabled(value)
    if not Orbit.db then return end
    if not Orbit.db.classSpecProfiles then Orbit.db.classSpecProfiles = {} end
    Orbit.db.classSpecProfiles[PLAYER_CLASS] = value and true or nil
end

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
    if not Orbit.db.classSpecProfiles then Orbit.db.classSpecProfiles = {} end

    -- TODO(REMOVE): Migrate legacy useSpecProfiles boolean into class-keyed table
    if Orbit.db.useSpecProfiles ~= nil then
        if Orbit.db.useSpecProfiles and not Orbit.db.classSpecProfiles[PLAYER_CLASS] then
            Orbit.db.classSpecProfiles[PLAYER_CLASS] = true
        end
        Orbit.db.useSpecProfiles = nil
    end

    if not Orbit.db.GlobalSettings then Orbit.db.GlobalSettings = {} end
    local gs = Orbit.db.GlobalSettings
    for key, default in pairs(GLOBAL_DEFAULTS) do
        if gs[key] == nil then
            gs[key] = type(default) == "table" and CopyTable(default, {}) or default
        end
    end

    if not Orbit.db.profiles[DEFAULT_PROFILE] then
        -- TODO(REMOVE): Migrate legacy "Default" profile to "Global"
        if Orbit.db.profiles["Default"] then
            Orbit.db.profiles[DEFAULT_PROFILE] = Orbit.db.profiles["Default"]
            Orbit.db.profiles["Default"] = nil
            if Orbit.db.activeProfile == "Default" then Orbit.db.activeProfile = DEFAULT_PROFILE end
            if Orbit.db.specMappings then
                for specID, name in pairs(Orbit.db.specMappings) do
                    if name == "Default" then Orbit.db.specMappings[specID] = nil end
                end
            end
        else
            Orbit.db.profiles[DEFAULT_PROFILE] = CopyTable(self.defaults, {})
        end
    end

    if not Orbit.db.activeProfile then Orbit.db.activeProfile = DEFAULT_PROFILE end

    -- Initialize spec mapping system
    if not Orbit.db.specMappings then
        self:_MigrateLegacySpecProfiles()
    end

    Orbit.runtime = Orbit.runtime or {}
    if not Orbit.runtime.Layouts then
        local activeProfile = Orbit.db.profiles[Orbit.db.activeProfile]
        if activeProfile then
            if not activeProfile.Layouts then activeProfile.Layouts = {} end
            Orbit.runtime.Layouts = activeProfile.Layouts
        end
    end

    -- Activate the correct profile for the current spec
    self:CheckSpecProfile()

    for _, profileData in pairs(Orbit.db.profiles) do
        if not profileData.GlobalSettings then
            profileData.GlobalSettings = CopyTable(Orbit.db.GlobalSettings, {})
        end
    end

    -- TODO(REMOVE): Migrate global DisabledPlugins into profiles (one-time migration)
    if Orbit.db.DisabledPlugins then
        for _, profileData in pairs(Orbit.db.profiles) do
            if not profileData.DisabledPlugins then
                profileData.DisabledPlugins = CopyTable(Orbit.db.DisabledPlugins, {})
            end
            if not profileData.HideBlizzardFrames then
                profileData.HideBlizzardFrames = CopyTable(Orbit.db.HideBlizzardFrames or {}, {})
            end
        end
        Orbit.db.DisabledPlugins = Orbit.db.profiles[Orbit.db.activeProfile] and CopyTable(Orbit.db.profiles[Orbit.db.activeProfile].DisabledPlugins or {}, {}) or {}
        Orbit.db.HideBlizzardFrames = Orbit.db.profiles[Orbit.db.activeProfile] and CopyTable(Orbit.db.profiles[Orbit.db.activeProfile].HideBlizzardFrames or {}, {}) or {}
    end

    self:InitializeSpecSwitching()
end

-- [ PROFILE GETTERS ]-------------------------------------------------------------------------------

function Orbit.Profile:GetActiveProfileName() return Orbit.db.activeProfile or DEFAULT_PROFILE end

function Orbit.Profile:GetProfiles()
    local names = {}
    for name, _ in pairs(Orbit.db.profiles) do table.insert(names, name) end
    table.sort(names)
    return names
end

-- [ SPEC MAPPING ]---------------------------------------------------------------------------------

function Orbit.Profile:GetProfileForSpec(specID)
    if not Orbit.db.specMappings then return nil end
    return Orbit.db.specMappings[specID]
end

function Orbit.Profile:SetProfileForSpec(specID, profileName)
    if not Orbit.db.specMappings then Orbit.db.specMappings = {} end
    if profileName and profileName ~= DEFAULT_PROFILE then
        Orbit.db.specMappings[specID] = profileName
    else
        Orbit.db.specMappings[specID] = nil
    end
end

-- TODO(REMOVE): Legacy spec-named profile migration
function Orbit.Profile:_MigrateLegacySpecProfiles()
    Orbit.db.specMappings = {}
    -- Attempt to map legacy spec-named profiles
    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    for i = 1, numSpecs do
        local specID, specName = GetSpecializationInfo(i)
        if specID and specName then
            -- Check for disambiguated names like "Protection (Warrior)"
            local legacyName = specName
            if DUPLICATE_SPEC_NAMES[specName] then
                local _, className = UnitClass("player")
                if className then
                    legacyName = specName .. " (" .. className:sub(1, 1):upper() .. className:sub(2):lower() .. ")"
                end
            end
            if Orbit.db.profiles[legacyName] and legacyName ~= DEFAULT_PROFILE then
                Orbit.db.specMappings[specID] = legacyName
            end
        end
    end
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
        if not Orbit.db.profiles[sourceName] then sourceName = DEFAULT_PROFILE end
        sourceData = Orbit.db.profiles[sourceName]
    end

    Orbit.db.profiles[name] = CopyTable(sourceData, {})
    return true
end

function Orbit.Profile:DeleteProfile(name)
    if name == DEFAULT_PROFILE then return false end
    if name == self:GetActiveProfileName() then return false end
    Orbit.db.profiles[name] = nil
    -- Clean up spec mappings referencing deleted profile
    if Orbit.db.specMappings then
        for specID, mapped in pairs(Orbit.db.specMappings) do
            if mapped == name then Orbit.db.specMappings[specID] = nil end
        end
    end
    return true
end

function Orbit.Profile:RenameProfile(oldName, newName)
    if oldName == DEFAULT_PROFILE then return false, "Cannot rename Global profile" end
    if not Orbit.db.profiles[oldName] then return false, "Profile does not exist" end
    if Orbit.db.profiles[newName] then return false, "A profile with that name already exists" end
    if not newName or newName == "" then return false, "Invalid name" end
    Orbit.db.profiles[newName] = Orbit.db.profiles[oldName]
    Orbit.db.profiles[oldName] = nil
    if Orbit.db.activeProfile == oldName then Orbit.db.activeProfile = newName end
    -- Update spec mappings
    if Orbit.db.specMappings then
        for specID, mapped in pairs(Orbit.db.specMappings) do
            if mapped == oldName then Orbit.db.specMappings[specID] = newName end
        end
    end
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
    if oldProfile then
        oldProfile.GlobalSettings = CopyTable(Orbit.db.GlobalSettings, {})
        oldProfile.DisabledPlugins = CopyTable(Orbit.db.DisabledPlugins or {}, {})
        oldProfile.HideBlizzardFrames = CopyTable(Orbit.db.HideBlizzardFrames or {}, {})
    end

    Orbit.db.activeProfile = name
    Orbit.runtime = Orbit.runtime or {}
    Orbit.runtime.Layouts = profile.Layouts

    if profile.GlobalSettings then Orbit.db.GlobalSettings = CopyTable(profile.GlobalSettings, {}) end
    local oldDisabled = CopyTable(Orbit.db.DisabledPlugins or {}, {})
    local oldHidden = CopyTable(Orbit.db.HideBlizzardFrames or {}, {})
    Orbit.db.DisabledPlugins = CopyTable(profile.DisabledPlugins or {}, {})
    Orbit.db.HideBlizzardFrames = CopyTable(profile.HideBlizzardFrames or {}, {})
    Orbit:Print(name .. " Profile Loaded.")

    -- Diff plugin states: live-toggle clean plugins, flag dirty ones for reload
    local needsReload = false
    if Orbit.Engine and Orbit.Engine.systems then
        for _, plugin in ipairs(Orbit.Engine.systems) do
            local wasDisabled = oldDisabled[plugin.name] or false
            local nowDisabled = Orbit.db.DisabledPlugins[plugin.name] or false
            local wasHidden = oldHidden[plugin.name] or false
            local nowHidden = Orbit.db.HideBlizzardFrames[plugin.name] or false
            local stateChanged = (wasDisabled ~= nowDisabled) or (wasHidden ~= nowHidden)
            if stateChanged then
                if plugin.liveToggle and not nowHidden and not wasHidden then
                    Orbit:LiveTogglePlugin(plugin.name, not nowDisabled)
                else
                    needsReload = true
                end
            end
        end

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
            if Orbit.Engine.FrameAnchor then
                Orbit.Engine.FrameAnchor:RepairAllChains()
            end
        end)
    end

    if Orbit.OptionsPanel and Orbit.OptionsPanel.Refresh then Orbit.OptionsPanel:Refresh() end
    isActivatingProfile = false

    if needsReload then
        StaticPopupDialogs["ORBIT_PROFILE_RELOAD"] = StaticPopupDialogs["ORBIT_PROFILE_RELOAD"] or {
            text = "Some plugin changes require a UI reload to take effect.",
            button1 = "Reload Now",
            button2 = "Later",
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("ORBIT_PROFILE_RELOAD")
    end

    Orbit.EventBus:Fire("ORBIT_PROFILE_CHANGED", name)
    return true
end

-- [ SPEC MANAGEMENT ]-------------------------------------------------------------------------------

function Orbit.Profile:CheckSpecProfile()
    if not Orbit.db or not Orbit.db.profiles then return end
    if not self:IsSpecProfilesEnabled() then return end
    if not Orbit.db.specMappings then return end
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then self:SetActiveProfile(Orbit.db.activeProfile or DEFAULT_PROFILE); return end
    local specID = GetSpecializationInfo(specIndex)
    if not specID then self:SetActiveProfile(Orbit.db.activeProfile or DEFAULT_PROFILE); return end
    local mapped = Orbit.db.specMappings[specID]
    if mapped and Orbit.db.profiles[mapped] then
        self:SetActiveProfile(mapped)
    end
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
    if active then
        active.GlobalSettings = CopyTable(Orbit.db.GlobalSettings, {})
        active.DisabledPlugins = CopyTable(Orbit.db.DisabledPlugins or {}, {})
        active.HideBlizzardFrames = CopyTable(Orbit.db.HideBlizzardFrames or {}, {})
    end
end

-- [ IMPORT / EXPORT ]-------------------------------------------------------------------------------

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

function Orbit.Profile:ExportProfile()
    self:FlushGlobalSettings()
    local exportData = {
        meta = { addon = "Orbit", version = Orbit.version, date = date(), type = "Collection", name = "All Profiles Backup" },
        data = Orbit.db.profiles,
        specMappings = Orbit.db.specMappings,
    }
    return "--OrbitProfile--" .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(exportData)))
end

function Orbit.Profile:ExportSingleProfile(profileName)
    self:FlushGlobalSettings()
    local profileData = Orbit.db.profiles[profileName]
    if not profileData then return nil end
    local exportData = {
        meta = { addon = "Orbit", version = Orbit.version, date = date(), type = "Single", name = profileName },
        data = profileData,
    }
    return "--OrbitProfile--" .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(exportData)))
end

function Orbit.Profile:ImportProfile(str, name)
    str = str:gsub("^%-%-OrbitProfile%-%-", "")
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
        if t.specMappings then
            Orbit.db.specMappings = CopyTable(t.specMappings, {})
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
