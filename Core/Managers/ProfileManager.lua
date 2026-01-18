local _, addonTable = ...
local Orbit = addonTable

---@class OrbitProfileManager
Orbit.Profile = {}

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

-- [ IMMUTABLE DEFAULTS ]----------------------------------------------------------------------------
-- Preconfigured layout for new profiles (first-time users get this)
-- Based on the Affliction profile's refined "Orbit" layout
Orbit.Profile.defaults = {
    Layouts = {
        ["Orbit"] = {
            ["Orbit_FocusCastBar"] = {
                [1] = {
                    Anchor = {
                        target = "OrbitFocusFrame",
                        padding = 2,
                        edge = "TOP",
                        align = "LEFT",
                    },
                    CastBarWidth = 200,
                    CastBarHeight = 18,
                    CastBarTextSize = 10,
                },
            },
            ["Orbit_FocusFrame"] = {
                [3] = {
                    Anchor = {
                        target = "OrbitTargetFrame",
                        padding = 30,
                        edge = "RIGHT",
                        align = "BOTTOM",
                    },
                    ReactionColour = false,
                    Height = 40,
                    EnableFocusPower = true,
                    EnableFocusTarget = true,
                    Width = 160,
                    ComponentPositions = {
                        LevelText = {
                            offsetX = -3,
                            justifyH = "LEFT",
                            offsetY = 6,
                            anchorX = "RIGHT",
                            anchorY = "TOP",
                        },
                        HealthText = {
                            offsetX = 5,
                            justifyH = "RIGHT",
                            offsetY = 0,
                            anchorX = "RIGHT",
                            anchorY = "CENTER",
                        },
                        Name = {
                            offsetX = 5,
                            justifyH = "LEFT",
                            offsetY = 0,
                            anchorX = "LEFT",
                            anchorY = "CENTER",
                        },
                        RareEliteIcon = {
                            offsetX = -8,
                            justifyH = "LEFT",
                            offsetY = 9,
                            anchorX = "RIGHT",
                            anchorY = "BOTTOM",
                        },
                    },
                },
            },
            ["Orbit_FocusDebuffs"] = {
                [1] = {
                    Scale = 100,
                    MaxRows = 2,
                    Spacing = 2,
                    IconsPerRow = 5,
                    Anchor = {
                        target = "OrbitFocusCastBar",
                        padding = 2,
                        edge = "TOP",
                        align = "LEFT",
                    },
                },
            },
            ["Orbit_TalkingHead"] = {
                ["Orbit_TalkingHead"] = {
                    Anchor = false,
                    Position = {
                        y = -122.5,
                        x = 0,
                        point = "TOP",
                    },
                    Scale = 60,
                },
            },
            ["Orbit_CooldownViewer"] = {
                [1] = {
                    aspectRatio = "4:3",
                    Anchor = false,
                    IconLimit = 10,
                    IconSize = 120,
                    Opacity = 100,
                    IconPadding = 1,
                    Position = {
                        y = -223.8,
                        x = 0,
                        point = "CENTER",
                    },
                },
                [2] = {
                    aspectRatio = "4:3",
                    Anchor = {
                        target = "OrbitEssentialCooldowns",
                        padding = 2,
                        edge = "BOTTOM",
                        align = "CENTER",
                    },
                    IconLimit = 10,
                    IconSize = 90,
                    Opacity = 100,
                    IconPadding = 1,
                    Position = {
                        y = -13.0,
                        relativeTo = "OrbitEssentialCooldowns",
                        point = "TOP",
                        relativePoint = "BOTTOM",
                        x = 0,
                    },
                },
                [3] = {
                    aspectRatio = "4:3",
                    Anchor = {
                        target = "OrbitPlayerResources",
                        padding = 2,
                        edge = "TOP",
                        align = "CENTER",
                    },
                    IconLimit = 10,
                    IconSize = 90,
                    Opacity = 100,
                    IconPadding = 1,
                    Position = {
                        y = -5.3,
                        relativeTo = "OrbitPlayerResources",
                        point = "BOTTOM",
                        relativePoint = "TOP",
                        x = 0,
                    },
                },
            },
            ["Orbit_TargetPower"] = {
                [1] = {
                    Height = 12,
                    Anchor = {
                        target = "OrbitTargetFrame",
                        padding = 0,
                        edge = "BOTTOM",
                        align = "RIGHT",
                    },
                    ShowText = true,
                    Width = 200,
                },
            },
            ["Orbit_MicroMenu"] = {
                ["Orbit_MicroMenu"] = {
                    Anchor = false,
                    Padding = -5,
                    Rows = 1,
                    Position = {
                        y = 0.55,
                        x = 0,
                        point = "BOTTOMRIGHT",
                    },
                },
            },
            ["Orbit_BagBar"] = {
                ["Orbit_BagBar"] = {
                    Anchor = {
                        target = "OrbitMicroMenuContainer",
                        padding = 2,
                        edge = "TOP",
                        align = "RIGHT",
                    },
                    Opacity = 100,
                    Scale = 100,
                },
            },
            ["Orbit_ActionBars"] = {
                [1] = {
                    Anchor = false,
                    Opacity = 100,
                    Position = {
                        y = 5.9,
                        relativeTo = "UIParent",
                        point = "BOTTOM",
                        relativePoint = "BOTTOM",
                        x = 0,
                    },
                    Scale = 90,
                    NumIcons = 12,
                    IconPadding = 2,
                    Rows = 1,
                },
                [2] = {
                    Anchor = {
                        target = "OrbitActionBar1",
                        padding = 2,
                        edge = "TOP",
                        align = "LEFT",
                    },
                    Scale = 100,
                    NumIcons = 12,
                    Rows = 1,
                    IconPadding = 2,
                    Position = {
                        y = -8.1,
                        relativeTo = "OrbitActionBar1",
                        point = "BOTTOMLEFT",
                        relativePoint = "TOPLEFT",
                        x = -113.5,
                    },
                },
                [3] = {
                    Opacity = 100,
                    Anchor = {
                        target = "OrbitActionBar2",
                        padding = 15,
                        edge = "LEFT",
                        align = "TOP",
                    },
                    Scale = 80,
                    NumIcons = 8,
                    IconPadding = 2,
                    Rows = 2,
                },
                [4] = {
                    Opacity = 100,
                    Anchor = {
                        target = "OrbitActionBar1",
                        padding = 15,
                        edge = "RIGHT",
                        align = "BOTTOM",
                    },
                    Scale = 80,
                    Rows = 2,
                    IconPadding = 2,
                    NumIcons = 8,
                },
                [5] = {
                    Rows = 1,
                    Anchor = {
                        target = "OrbitActionBar6",
                        padding = 2,
                        edge = "TOP",
                        align = "RIGHT",
                    },
                    Opacity = 100,
                    IconPadding = 2,
                    NumIcons = 12,
                },
                [6] = {
                    Anchor = {
                        target = "OrbitActionBar7",
                        padding = 2,
                        edge = "TOP",
                        align = "LEFT",
                    },
                    Rows = 1,
                    IconPadding = 2,
                },
                [7] = {
                    Anchor = {
                        target = "OrbitActionBar8",
                        padding = 2,
                        edge = "TOP",
                        align = "RIGHT",
                    },
                    Rows = 1,
                    IconPadding = 2,
                },
                [8] = {
                    Anchor = false,
                    Position = {
                        y = -92.2,
                        x = 114.1,
                        point = "LEFT",
                    },
                    Scale = 100,
                    Rows = 1,
                    IconPadding = 2,
                    NumIcons = 12,
                },
                [9] = {
                    Anchor = false,
                    Position = {
                        y = 71.7,
                        x = -3.1,
                        point = "BOTTOM",
                    },
                    HideEmptyButtons = true,
                    Scale = 100,
                    Rows = 1,
                    IconPadding = 2,
                    Opacity = 0,
                },
                [10] = {
                    Anchor = false,
                    Position = {
                        y = -108.6,
                        x = 33.7,
                        point = "LEFT",
                    },
                    Scale = 100,
                    Rows = 1,
                    IconPadding = 2,
                    Opacity = 100,
                },
                [11] = {
                    Anchor = {
                        target = "OrbitStanceBar",
                        padding = 2,
                        edge = "RIGHT",
                        align = "TOP",
                    },
                    Rows = 1,
                    IconPadding = 2,
                },
                [12] = {
                    Anchor = false,
                    Opacity = 100,
                    IconPadding = 2,
                    Position = {
                        y = 270.4,
                        x = -252.0,
                        point = "BOTTOM",
                    },
                },
            },
            ["Orbit_PlayerFrame"] = {
                [1] = {
                    Width = 160,
                    EnablePlayerPower = true,
                    Height = 40,
                    Position = {
                        y = 301.5,
                        x = -346.8,
                        point = "BOTTOM",
                    },
                    Anchor = false,
                    ShowHealAbsorbs = true,
                    TextSize = 12,
                    ShowAbsorbs = true,
                    ShowCombatIcon = true,
                    ShowLevel = true,
                    ComponentPositions = {
                        LevelText = {
                            offsetX = -3,
                            justifyH = "LEFT",
                            offsetY = 5,
                            anchorX = "RIGHT",
                            anchorY = "TOP",
                        },
                        HealthText = {
                            offsetX = 5,
                            justifyH = "RIGHT",
                            offsetY = 0,
                            anchorX = "RIGHT",
                            anchorY = "CENTER",
                        },
                        Name = {
                            offsetX = 5,
                            justifyH = "LEFT",
                            offsetY = 0,
                            anchorX = "LEFT",
                            anchorY = "CENTER",
                        },
                        CombatIcon = {
                            offsetX = -10,
                            justifyH = "LEFT",
                            offsetY = 10,
                            anchorX = "RIGHT",
                            anchorY = "BOTTOM",
                        },
                    },
                },
            },
            ["Orbit_BossFrames"] = {
                [1] = {
                    CastBarHeight = 25,
                    Scale = 100,
                    MaxDebuffs = 4,
                    Width = 140,
                    DebuffPosition = "Above",
                    Position = {
                        y = 146.1,
                        x = -434.3,
                        point = "RIGHT",
                    },
                    Height = 40,
                    CastBarPosition = "Below",
                    DebuffSize = 32,
                    Anchor = false,
                },
            },
            ["Orbit_QueueStatus"] = {
                ["Orbit_QueueStatus"] = {
                    Anchor = false,
                    Position = {
                        y = -0.7,
                        x = 0,
                        point = "LEFT",
                    },
                },
            },
            ["Orbit_PlayerPower"] = {
                [1] = {
                    Height = 10,
                    ShowText = false,
                    Anchor = {
                        target = "OrbitEssentialCooldowns",
                        padding = 2,
                        edge = "TOP",
                        align = "CENTER",
                    },
                },
            },
            ["Orbit_TargetBuffs"] = {
                [1] = {
                    IconsPerRow = 5,
                    MaxRows = 2,
                    Spacing = 2,
                    Scale = 100,
                    Anchor = {
                        target = "OrbitTargetPower",
                        padding = -2,
                        edge = "BOTTOM",
                        align = "CENTER",
                    },
                },
            },
            ["Orbit_PlayerResources"] = {
                [1] = {
                    ShowText = true,
                    Spacing = 2,
                    Height = 10,
                    Anchor = {
                        target = "OrbitPlayerPower",
                        padding = 2,
                        edge = "TOP",
                        align = "CENTER",
                    },
                    TextSize = 15,
                    Width = 200,
                },
            },
            ["Orbit_FocusBuffs"] = {
                [1] = {
                    Scale = 100,
                    MaxRows = 2,
                    IconsPerRow = 5,
                    Anchor = {
                        target = "OrbitFocusPower",
                        padding = -2,
                        edge = "BOTTOM",
                        align = "LEFT",
                    },
                },
            },
            [13] = {
                [13] = {
                    EyeSize = 100,
                    Size = 100,
                },
            },
            ["Orbit_TargetCastBar"] = {
                [1] = {
                    Anchor = {
                        target = "OrbitTargetFrame",
                        padding = 2,
                        edge = "TOP",
                    },
                    CastBarHeight = 18,
                    CastBarTextSize = 10,
                },
            },
            ["Orbit_CombatTimer"] = {
                ["Orbit_CombatTimer"] = {
                    Anchor = {
                        target = "OrbitActionBar3",
                        padding = 15,
                        edge = "LEFT",
                        align = "CENTER",
                    },
                    Opacity = 100,
                    Scale = 100,
                    Position = {
                        y = 0,
                        relativeTo = "OrbitActionBar3",
                        point = "RIGHT",
                        relativePoint = "LEFT",
                        x = -8.4,
                    },
                },
            },
            ["Orbit_PlayerCastBar"] = {
                [1] = {
                    CastBarWidth = 300,
                    CastBarTextSize = 10,
                    Anchor = false,
                    Position = {
                        y = 216.4,
                        x = -0.6,
                        point = "BOTTOM",
                    },
                    CastBarTimer = true,
                    CastBarText = true,
                    CastBarHeight = 35,
                },
            },
            ["Orbit_TargetFrame"] = {
                [2] = {
                    EnableTargetPower = true,
                    EnableTargetTarget = true,
                    MaxBuffs = 16,
                    AuraSize = 20,
                    Anchor = false,
                    Position = {
                        y = -269.7,
                        x = 346.3,
                        point = "CENTER",
                    },
                    ComponentPositions = {
                        LevelText = {
                            offsetX = -3,
                            justifyH = "LEFT",
                            offsetY = 6,
                            anchorX = "RIGHT",
                            anchorY = "TOP",
                        },
                        HealthText = {
                            offsetX = 5,
                            justifyH = "RIGHT",
                            offsetY = 0,
                            anchorX = "RIGHT",
                            anchorY = "CENTER",
                        },
                        Name = {
                            offsetX = 5,
                            justifyH = "LEFT",
                            offsetY = 0,
                            anchorX = "LEFT",
                            anchorY = "CENTER",
                        },
                        RareEliteIcon = {
                            offsetX = -8,
                            justifyH = "LEFT",
                            offsetY = 10,
                            anchorX = "RIGHT",
                            anchorY = "BOTTOM",
                        },
                    },
                },
            },
            ["Orbit_TargetOfTargetFrame"] = {
                [100] = {
                    Height = 20,
                    Anchor = {
                        target = "OrbitTargetBuffsFrame",
                        padding = 10,
                        edge = "BOTTOM",
                        align = "RIGHT",
                    },
                    Width = 100,
                },
            },
            ["Orbit_TargetOfFocusFrame"] = {
                [101] = {
                    Height = 20,
                    Anchor = {
                        target = "OrbitFocusBuffsFrame",
                        padding = 10,
                        edge = "BOTTOM",
                        align = "RIGHT",
                    },
                    Width = 100,
                },
            },
            [14] = {
                [14] = {
                    Size = 70,
                },
            },
            ["Orbit_TargetDebuffs"] = {
                [1] = {
                    Scale = 100,
                    MaxRows = 2,
                    IconsPerRow = 5,
                    Anchor = {
                        target = "OrbitTargetCastBar",
                        padding = 2,
                        edge = "TOP",
                        align = "RIGHT",
                    },
                },
            },
            ["Orbit_PlayerPetFrame"] = {
                [8] = {
                    Height = 20,
                    Anchor = {
                        target = "OrbitPlayerFrame",
                        padding = 2,
                        edge = "BOTTOM",
                        align = "LEFT",
                    },
                    Width = 90,
                },
            },
            ["Orbit_FocusPower"] = {
                [1] = {
                    Height = 12,
                    Anchor = {
                        target = "OrbitFocusFrame",
                        padding = 0,
                        edge = "BOTTOM",
                        align = "CENTER",
                    },
                    ShowText = true,
                    Width = 200,
                },
            },
            ["Orbit_Performance"] = {
                ["Orbit_Performance"] = {
                    Anchor = {
                        target = "OrbitActionBar4",
                        padding = 15,
                        edge = "RIGHT",
                        align = "CENTER",
                    },
                    Opacity = 100,
                },
            },
        },
    },
    DisabledPlugins = {},
    Locks = {},
}

-- [ INITIALIZATION ]--------------------------------------------------------------------------------
function Orbit.Profile:Initialize()
    if not Orbit.db then
        Orbit.db = {}
    end
    if not Orbit.db.profiles then
        Orbit.db.profiles = {}
    end

    -- Ensure Default profile exists
    if not Orbit.db.profiles["Default"] then
        Orbit.db.profiles["Default"] = CopyTable(self.defaults, {})
    end

    -- Set active profile if missing
    if not Orbit.db.activeProfile then
        Orbit.db.activeProfile = "Default"
    end

    -- CRITICAL: Synchronously determine and set the correct spec profile
    -- This MUST happen before InitializePlugins() runs, so positions are
    -- applied from the correct profile on first load.
    local specName = self:GetCurrentSpecName()

    if specName then
        self:EnsureSpecProfile(specName)
        self:SetActiveProfile(specName)
    else
        self:SetActiveProfile(Orbit.db.activeProfile)
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
    if not profile.DisabledPlugins then
        profile.DisabledPlugins = {}
    end
    if not profile.Locks then
        profile.Locks = {}
    end

    -- If already active, just ensure runtime references exist and return
    if Orbit.db.activeProfile == name then
        Orbit.runtime = Orbit.runtime or {}
        Orbit.runtime.Layouts = profile.Layouts
        Orbit.runtime.DisabledPlugins = profile.DisabledPlugins
        Orbit.runtime.Locks = profile.Locks
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
    Orbit.runtime.DisabledPlugins = profile.DisabledPlugins
    Orbit.runtime.Locks = profile.Locks

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
    return true
end

-- [ SPEC BINDING ]----------------------------------------------------------------------------------
function Orbit.Profile:GetCurrentSpecName()
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end

    local _, specName = GetSpecializationInfo(specIndex)
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
