local _, addonTable = ...
local Orbit = addonTable

---@class OrbitProfileManager
Orbit.Profile = Orbit.Profile or {}

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local CLEAN_PROFILE_SOURCE = ":CLEAN:"
local DEBOUNCE_KEY = "ProfileManager_SpecCheck"
local DEBOUNCE_DELAY = 0.1

-- [ INTERNAL STATE ]--------------------------------------------------------------------------------
local isActivatingProfile = false

-- [ UTILITY ]---------------------------------------------------------------------------------------

-- Deep copy tables
local function CopyTable(src, dest)
    if type(dest) ~= "table" then
        dest = {}
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = CopyTable(v, {})
        else
            dest[k] = v
        end
    end
    return dest
end

-- [ INITIALIZATION ]--------------------------------------------------------------------------------
local NO_SPEC_PROFILE = "No-Spec"

function Orbit.Profile:Initialize()
    if not Orbit.db then
        Orbit.db = {}
    end
    if not Orbit.db.profiles then
        Orbit.db.profiles = {}
    end

    -- Ensure GlobalSettings has defaults (eliminates need for fallbacks throughout codebase)
    if not Orbit.db.GlobalSettings then
        Orbit.db.GlobalSettings = {}
    end
    local gs = Orbit.db.GlobalSettings
    if gs.Texture == nil then
        gs.Texture = "Melli"
    end
    if gs.Font == nil then
        gs.Font = "PT Sans Narrow"
    end
    if gs.BorderSize == nil then
        gs.BorderSize = 2
    end
    if gs.TextScale == nil then
        gs.TextScale = "Medium"
    end
    if gs.FontOutline == nil then
        gs.FontOutline = "OUTLINE"
    end
    if gs.BackdropColour == nil then
        gs.BackdropColour = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }
    end
    if gs.BarColor == nil then
        gs.BarColor = { r = 0.2, g = 0.8, b = 0.2, a = 1 }
    end
    if gs.BarColorCurve == nil then
        gs.BarColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 }, type = "class" } } }
    end
    if gs.ClassColorBackground == nil then
        gs.ClassColorBackground = false
    end
    if gs.UseClassColors == nil then
        gs.UseClassColors = true
    end
    if gs.OverlayAllFrames == nil then
        gs.OverlayAllFrames = false
    end
    if gs.OverlayTexture == nil then
        gs.OverlayTexture = "Orbit Gradient"
    end

    -- Ensure Default profile exists (used as template for new profiles)
    if not Orbit.db.profiles["Default"] then
        Orbit.db.profiles["Default"] = CopyTable(self.defaults, {})
    end

    -- Set active profile if missing
    if not Orbit.db.activeProfile then
        Orbit.db.activeProfile = "Default"
    end

    -- DEFENSIVE: Ensure runtime.Layouts is never nil (protects against edge cases)
    Orbit.runtime = Orbit.runtime or {}
    if not Orbit.runtime.Layouts then
        local activeProfile = Orbit.db.profiles[Orbit.db.activeProfile]
        if activeProfile then
            if not activeProfile.Layouts then
                activeProfile.Layouts = {}
            end
            Orbit.runtime.Layouts = activeProfile.Layouts
        else
            -- Fallback: Create empty Layouts if profile somehow doesn't exist
            Orbit.runtime.Layouts = {}
        end
    end

    -- CRITICAL: Synchronously determine and set the correct spec profile
    -- This MUST happen before InitializePlugins() runs, so positions are
    -- applied from the correct profile on first load.
    local specName = self:GetCurrentSpecName()

    if specName and specName ~= "" then
        self:EnsureSpecProfile(specName)
        self:SetActiveProfile(specName)
    else
        -- No specialization (level 1-9 characters) - use dedicated No-Spec profile
        if not Orbit.db.profiles[NO_SPEC_PROFILE] then
            Orbit.db.profiles[NO_SPEC_PROFILE] = CopyTable(self.defaults, {})
            Orbit:Print("Created '" .. NO_SPEC_PROFILE .. "' profile for characters without a specialization.")
        end
        self:SetActiveProfile(NO_SPEC_PROFILE)
    end

    -- Register for FUTURE spec changes only (not initial load)
    self:InitializeSpecSwitching()
end

-- [ PROFILE GETTERS ]-------------------------------------------------------------------------------
function Orbit.Profile:GetActiveProfileName()
    return Orbit.db.activeProfile or "Default"
end

function Orbit.Profile:GetProfiles()
    local names = {}
    for name, _ in pairs(Orbit.db.profiles) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- [ PROFILE CRUD ]----------------------------------------------------------------------------------
function Orbit.Profile:CreateProfile(name, copyFrom)
    if Orbit.db.profiles[name] then
        return false
    end -- Already exists

    local sourceName = copyFrom or self:GetActiveProfileName()

    -- CRITICAL: If copying from active profile, flush pending positions first
    -- so the new profile inherits the most recent changes
    if sourceName == self:GetActiveProfileName() then
        if Orbit.Engine and Orbit.Engine.PositionManager then
            Orbit.Engine.PositionManager:FlushToStorage()
        end
    end

    local sourceData

    if sourceName == CLEAN_PROFILE_SOURCE then
        -- Use immutable default structure (Deep Copy)
        sourceData = self.defaults
    else
        if not Orbit.db.profiles[sourceName] then
            sourceName = "Default"
        end
        sourceData = Orbit.db.profiles[sourceName]
    end

    Orbit.db.profiles[name] = CopyTable(sourceData, {})
    return true
end

function Orbit.Profile:DeleteProfile(name)
    if name == "Default" then
        return false
    end
    if name == self:GetActiveProfileName() then
        return false
    end -- Can't delete active

    Orbit.db.profiles[name] = nil
    return true
end

function Orbit.Profile:SetActiveProfile(name)
    if not Orbit.db.profiles[name] then
        return false
    end

    -- Reentrant guard: Prevent nested profile switches
    if isActivatingProfile then
        return false
    end

    local profile = Orbit.db.profiles[name]
    if not profile.Layouts then
        profile.Layouts = {}
    end

    -- If already active, just ensure runtime references exist and return
    if Orbit.db.activeProfile == name then
        Orbit.runtime = Orbit.runtime or {}
        Orbit.runtime.Layouts = profile.Layouts
        return true
    end

    isActivatingProfile = true

    -- CRITICAL: Flush pending positions to the OLD profile BEFORE changing references!
    -- FlushToStorage calls SetSetting which writes to Orbit.runtime.Layouts (which references profile.Layouts).
    -- If we change the runtime reference first, edits go to the WRONG profile.
    if Orbit.Engine and Orbit.Engine.PositionManager then
        Orbit.Engine.PositionManager:FlushToStorage()
        Orbit.Engine.PositionManager:DiscardChanges()
    end

    -- NOW switch the runtime references to the new profile
    -- Using Orbit.runtime (not Orbit.db) so WoW doesn't serialize these references
    Orbit.db.activeProfile = name
    Orbit.runtime = Orbit.runtime or {}
    Orbit.runtime.Layouts = profile.Layouts

    -- Notify User
    Orbit:Print(name .. " Profile Loaded.")

    -- Refresh all registered plugins - TWO PASSES to ensure anchor targets position before dependents
    if Orbit.Engine and Orbit.Engine.systems then
        -- PASS 1: Apply anchor targets first (CooldownViewers, etc.)
        for _, plugin in ipairs(Orbit.Engine.systems) do
            if plugin.ApplySettings then
                -- CooldownViewer is a common anchor target
                local isAnchorTarget = plugin.system == "Orbit_CooldownViewer"
                if isAnchorTarget then
                    local success, err = pcall(function()
                        plugin:ApplySettings(nil)
                    end)
                    if not success then
                        Orbit:Print("Error refreshing plugin " .. (plugin.name or "?") .. ": " .. tostring(err))
                    end
                end
            end
        end

        -- PASS 2: Apply all other plugins (dependent frames)
        for _, plugin in ipairs(Orbit.Engine.systems) do
            if plugin.ApplySettings then
                local isAnchorTarget = plugin.system == "Orbit_CooldownViewer"
                if not isAnchorTarget then
                    local success, err = pcall(function()
                        plugin:ApplySettings(nil)
                    end)
                    if not success then
                        Orbit:Print("Error refreshing plugin " .. (plugin.name or "?") .. ": " .. tostring(err))
                    end
                end
            end
        end

        -- PASS 3: Delayed re-apply to catch any anchor recalculations
        -- This mirrors what happens on PLAYER_ENTERING_WORLD
        C_Timer.After(0.1, function()
            for _, plugin in ipairs(Orbit.Engine.systems) do
                if plugin.ApplySettings then
                    pcall(function()
                        plugin:ApplySettings(nil)
                    end)
                end
            end
        end)
    end

    -- Refresh Options Panel if open
    if Orbit.OptionsPanel and Orbit.OptionsPanel.Refresh then
        Orbit.OptionsPanel:Refresh()
    end

    isActivatingProfile = false

    -- Notify subsystems that the profile has fully switched
    -- (runtime references are updated, all plugins have been refreshed)
    if Orbit.EventBus then
        Orbit.EventBus:Fire("ORBIT_PROFILE_CHANGED", name)
    end

    return true
end

-- Known duplicate spec names across classes that need disambiguation
local DUPLICATE_SPEC_NAMES = {
    ["Protection"] = true, -- Warrior, Paladin
    ["Restoration"] = true, -- Druid, Shaman
    ["Holy"] = true, -- Paladin, Priest
}

function Orbit.Profile:GetCurrentSpecName()
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end

    local _, specName = GetSpecializationInfo(specIndex)
    if not specName then
        return nil
    end

    -- Disambiguate duplicate spec names with class name
    if DUPLICATE_SPEC_NAMES[specName] then
        local _, className = UnitClass("player")
        if className then
            -- Proper case: "Protection (Warrior)"
            local properClassName = className:sub(1, 1):upper() .. className:sub(2):lower()
            return specName .. " (" .. properClassName .. ")"
        end
    end

    return specName
end

function Orbit.Profile:EnsureSpecProfile(specName)
    if not specName or specName == "" then
        return false
    end

    if Orbit.db.profiles[specName] then
        return true -- Already exists
    end

    -- Create new profile from ACTIVE profile (Inheritance)
    -- We pass nil as the second argument so CreateProfile defaults to copying the active profile
    self:CreateProfile(specName, nil)
    Orbit:Print("Created profile '" .. specName .. "' (Copied from previous active profile)")

    return true
end

function Orbit.Profile:CopyProfileData(sourceProfileName)
    local activeProfileName = self:GetActiveProfileName()

    -- Validation
    if not sourceProfileName or sourceProfileName == "" then
        return false, "No source profile specified"
    end
    if not Orbit.db.profiles[sourceProfileName] then
        return false, "Source profile does not exist"
    end
    if sourceProfileName == activeProfileName then
        return false, "Cannot copy from the active profile"
    end

    -- Deep copy source data to active profile
    local sourceProfile = Orbit.db.profiles[sourceProfileName]
    local activeProfile = Orbit.db.profiles[activeProfileName]

    activeProfile.Layouts = CopyTable(sourceProfile.Layouts or {}, {})

    Orbit:Print("Copied settings from '" .. sourceProfileName .. "' to '" .. activeProfileName .. "'")

    return true
end

function Orbit.Profile:CheckSpecProfile()
    -- Initialization guard: Ensure profile data is ready
    if not Orbit.db or not Orbit.db.profiles then
        return
    end

    local specName = self:GetCurrentSpecName()
    if not specName then
        return
    end

    -- Strict adherence to spec-named profiles
    self:EnsureSpecProfile(specName)

    -- Switch to spec's profile (SetActiveProfile handles "already active" silently)
    self:SetActiveProfile(specName)
end

function Orbit.Profile:InitializeSpecSwitching()
    local frame = CreateFrame("Frame")
    -- Only listen for spec changes AFTER initial load
    -- Initial profile is set synchronously in Initialize()
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    frame:SetScript("OnEvent", function(_, event)
        -- Debounce spec changes to prevent race conditions during rapid switches
        Orbit.Async:Debounce(DEBOUNCE_KEY, function()
            self:CheckSpecProfile()
        end, DEBOUNCE_DELAY)
    end)
end

-- [ IMPORT / EXPORT ]-------------------------------------------------------------------------------
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

function Orbit.Profile:ExportProfile()
    local exportData = {
        meta = {
            addon = "Orbit",
            version = Orbit.version,
            date = date(),
            type = "Collection",
            name = "All Profiles Backup",
        },
        data = Orbit.db.profiles,
    }

    local serialized = LibSerialize:Serialize(exportData)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)

    return encoded
end

function Orbit.Profile:ImportProfile(str, name)
    local decoded = LibDeflate:DecodeForPrint(str)
    if not decoded then
        return false, "Decoding Failed"
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return false, "Decompression Failed"
    end

    local success, t = LibSerialize:Deserialize(decompressed)
    if not success then
        return false, "Deserialization Failed: " .. tostring(t)
    end

    if type(t) ~= "table" or not t.meta or t.meta.addon ~= "Orbit" then
        return false, "Not an Orbit Profile"
    end

    -- Handle Collection Import (All Profiles)
    if t.meta.type == "Collection" then
        -- Wipe all existing profiles (Replace Collection)
        Orbit.db.profiles = {}

        local count = 0
        for profileName, profileData in pairs(t.data) do
            Orbit.db.profiles[profileName] = profileData
            count = count + 1
        end
        Orbit:Print(string.format("Imported Collection (%d profiles). Existing profiles wiped.", count))

        -- Re-evaluate spec to ensure we land on the correct profile
        self:CheckSpecProfile()
        return true
    end

    -- Handle Single Profile Import
    if not name or name == "" then
        name = t.meta.name or ("Imported " .. date("%Y%m%d"))
    end

    Orbit:Print(string.format("Importing profile '%s' (from %s)...", name, t.meta.date or "Unknown"))
    Orbit.db.profiles[name] = t.data

    -- If we overwrote the active profile, refresh references
    if name == self:GetActiveProfileName() then
        self:SetActiveProfile(name)
    end

    return true
end
