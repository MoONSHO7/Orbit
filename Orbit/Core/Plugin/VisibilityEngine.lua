-- [ VISIBILITY ENGINE ]------------------------------------------------------------------------------
local _, Orbit = ...
local OrbitEngine = Orbit.Engine

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.VisibilityEngine = {}
local VE = Orbit.VisibilityEngine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local DEFAULTS = { oocFade = false, opacity = 100, hideMounted = false, mouseOver = true, showWithTarget = true, alphaLock = false }
local STARTUP_DELAY = 0.5

local FRAME_REGISTRY = {
    { key = "PlayerFrame",          display = "Player Frame",          plugin = "Player Frame",       index = 1 },
    { key = "PlayerPower",          display = "Player Power",          plugin = "Player Power",       index = 1 },
    { key = "PlayerCastBar",        display = "Player Cast Bar",       plugin = "Player Cast Bar",    index = 1, opacityOnly = true },
    { key = "PlayerResources",      display = "Player Resources",      plugin = "Player Resources",   index = 1 },
    { key = "PetFrame",             display = "Pet Frame",             plugin = "Pet Frame",          index = 1 },
    { key = "PlayerBuffs",          display = "Player Buffs",          plugin = "Player Buffs",       index = 1 },
    { key = "PlayerDebuffs",        display = "Player Debuffs",        plugin = "Player Debuffs",     index = 1 },
    { key = "TargetFrame",          display = "Target Frame",          plugin = "Target Frame",       index = 1 },
    { key = "FocusFrame",           display = "Focus Frame",           plugin = "Focus Frame",        index = 1 },
    { key = "ActionBar1",           display = "Action Bar 1",          plugin = "Action Bars",        index = 1 },
    { key = "ActionBar2",           display = "Action Bar 2",          plugin = "Action Bars",        index = 2 },
    { key = "ActionBar3",           display = "Action Bar 3",          plugin = "Action Bars",        index = 3 },
    { key = "ActionBar4",           display = "Action Bar 4",          plugin = "Action Bars",        index = 4 },
    { key = "ActionBar5",           display = "Action Bar 5",          plugin = "Action Bars",        index = 5 },
    { key = "ActionBar6",           display = "Action Bar 6",          plugin = "Action Bars",        index = 6 },
    { key = "ActionBar7",           display = "Action Bar 7",          plugin = "Action Bars",        index = 7 },
    { key = "ActionBar8",           display = "Action Bar 8",          plugin = "Action Bars",        index = 8 },
    { key = "PetBar",               display = "Pet Bar",               plugin = "Action Bars",        index = 9 },
    { key = "StanceBar",            display = "Stance Bar",            plugin = "Action Bars",        index = 10 },
    { key = "EssentialCooldowns",   display = "Essential Cooldowns",   plugin = "Cooldown Manager",   index = 1 },
    { key = "UtilityCooldowns",     display = "Utility Cooldowns",     plugin = "Cooldown Manager",   index = 2 },
    { key = "BuffIcons",            display = "Buff Icons",            plugin = "Cooldown Manager",   index = 3 },
    { key = "ChargeBars",           display = "Charge Bars",           plugin = "Cooldown Manager",   index = 20 },
    { key = "BuffBars",             display = "Buff Bars",             plugin = "Cooldown Manager",   index = 30 },
    -- Sentinel indices 1/2 — real Tracked record IDs are >= SystemIndexBase (1000) so they can't collide.
    { key = "TrackedIcons",         display = "Tracked Icons",         plugin = "Tracked Items",      index = 1 },
    { key = "TrackedBars",          display = "Tracked Bars",          plugin = "Tracked Items",      index = 2 },
    { key = "DamageMeters",         display = "Damage Meters",         plugin = "Damage Meter",       index = 1 },
    { key = "GroupFrames",          display = "Group Frames",          plugin = "Group Frames",       index = 1 },
    { key = "BossFrames",           display = "Boss Frames",           plugin = "Boss Frames",        index = 1, opacityOnly = true },
    { key = "MenuBar",              display = "Menu Bar",              plugin = "Menu Bar",           index = 1 },
    { key = "BagBar",               display = "Bag Bar",               plugin = "Bag Bar",            index = 1 },
    { key = "QueueStatus",          display = "Queue Status",          plugin = "Queue Status",       index = 1 },
    { key = "PerformanceInfo",      display = "Performance Info",      plugin = "Performance Info",   index = 1 },
    { key = "CombatTimer",          display = "Combat Timer",          plugin = "Combat Timer",       index = 1 },
    { key = "Minimap",              display = "Minimap",               plugin = "Minimap",            index = 1 },
    { key = "Datatexts",            display = "Datatexts",             plugin = "Datatexts",          index = 1 },
    { key = "ExperienceBar",        display = "XP / Rep Bar",          plugin = "Experience Bar",     index = 1 },
    { key = "HonorBar",             display = "Honor Bar",             plugin = "Honor Bar",          index = 1 },
    { key = "PortalDock",           display = "Portal Dock",           plugin = "Portal Dock",        index = 1 },
}

-- O(1) reverse lookup: { [pluginName] = { [systemIndex] = key } }
local REVERSE_LOOKUP = {}
for _, entry in ipairs(FRAME_REGISTRY) do
    REVERSE_LOOKUP[entry.plugin] = REVERSE_LOOKUP[entry.plugin] or {}
    REVERSE_LOOKUP[entry.plugin][entry.index] = entry.key
end

-- Blizzard frames (no Orbit plugin, resolved via _G[blizzardFrame])
local BLIZZARD_REGISTRY = {
    -- Insecure (full feature set: opacity, oocFade, hideMounted, mouseOver, showWithTarget)
    { key = "BlizzMinimap",          display = "Minimap",               blizzardFrame = "MinimapCluster",            ownedBy = "Minimap" },
    { key = "ObjectiveTracker",      display = "Objective Tracker",     blizzardFrame = "ObjectiveTrackerFrame" },
    { key = "BuffFrame",             display = "Buff Frame",            blizzardFrame = "BuffFrame",                 ownedBy = "Player Buffs" },
    { key = "DebuffFrame",           display = "Debuff Frame",          blizzardFrame = "DebuffFrame",               ownedBy = "Player Debuffs" },
    { key = "ChatFrame",             display = "Chat Frame",            blizzardFrame = "ChatFrame1" },
    { key = "StatusTrackingBar",     display = "XP / Rep / Honor Bar",  blizzardFrame = "StatusTrackingBarManager",  ownedBy = { "Experience Bar", "Honor Bar" } },
    { key = "DurabilityFrame",       display = "Durability",            blizzardFrame = "DurabilityFrame" },
    { key = "VehicleSeatIndicator",  display = "Vehicle Seat",          blizzardFrame = "VehicleSeatIndicator" },
    { key = "DamageMeter",           display = "Damage Meter",          blizzardFrame = "DamageMeter",               ownedBy = "Damage Meter" },
    { key = "BlizzPlayerCastBar",    display = "Player Cast Bar",       blizzardFrame = "PlayerCastingBarFrame",     ownedBy = "Player Cast Bar", opacityOnly = true },
    { key = "TalkingHead",           display = "Talking Head",          blizzardFrame = "TalkingHeadFrame" },
    { key = "EncounterBar",          display = "Encounter Bar",         blizzardFrame = "EncounterBar" },
    { key = "LossOfControl",         display = "Loss of Control",       blizzardFrame = "LossOfControlFrame",        opacityOnly = true },
    { key = "MirrorTimers",          display = "Mirror Timers",         blizzardFrame = "MirrorTimerContainer" },
    { key = "AlertFrame",            display = "Alert Pop-ups",         blizzardFrame = "AlertFrame",                opacityOnly = true },
    -- Secure (opacity + oocFade + hideMounted + showWithTarget; no mouseOver reveal)
    { key = "BlizzPlayerFrame",      display = "Player Frame",          blizzardFrame = "PlayerFrame",               ownedBy = "Player Frame",     secure = true },
    { key = "BlizzPetFrame",         display = "Pet Frame",             blizzardFrame = "PetFrame",                  ownedBy = "Pet Frame",        secure = true },
    { key = "BlizzTargetFrame",      display = "Target Frame",          blizzardFrame = "TargetFrame",               ownedBy = "Target Frame",     secure = true },
    { key = "BlizzTargetOfTarget",   display = "Target of Target",      blizzardFrame = "TargetFrameToT",            ownedBy = "Target Frame",     secure = true },
    { key = "BlizzFocusFrame",       display = "Focus Frame",           blizzardFrame = "FocusFrame",                ownedBy = "Focus Frame",      secure = true },
    { key = "BlizzPartyFrame",       display = "Party Frame",           blizzardFrame = "PartyFrame",                ownedBy = "Group Frames",     secure = true },
    { key = "BlizzRaidFrame",        display = "Raid Frames",           blizzardFrame = "CompactRaidFrameContainer", ownedBy = "Group Frames",     secure = true },
    { key = "BlizzMainMenuBar",      display = "Action Bar 1",          blizzardFrame = "MainMenuBar",               ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBarBL",       display = "Action Bar 2",          blizzardFrame = "MultiBarBottomLeft",        ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBarBR",       display = "Action Bar 3",          blizzardFrame = "MultiBarBottomRight",       ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBarRight",    display = "Action Bar 4",          blizzardFrame = "MultiBarRight",             ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBarLeft",     display = "Action Bar 5",          blizzardFrame = "MultiBarLeft",              ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBar5",        display = "Action Bar 6",          blizzardFrame = "MultiBar5",                 ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBar6",        display = "Action Bar 7",          blizzardFrame = "MultiBar6",                 ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBar7",        display = "Action Bar 8",          blizzardFrame = "MultiBar7",                 ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzStanceBar",        display = "Stance Bar",            blizzardFrame = "StanceBar",                 ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzPetActionBar",     display = "Pet Action Bar",        blizzardFrame = "PetActionBar",              ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzPossessBar",       display = "Possess Bar",           blizzardFrame = "PossessActionBar",          secure = true, propagateAlpha = true },
    { key = "BlizzMicroMenu",        display = "Micro Menu",            blizzardFrame = "MicroMenuContainer",        ownedBy = "Menu Bar",         secure = true, propagateAlpha = true },
    { key = "BlizzBagsBar",          display = "Bags Bar",              blizzardFrame = "BagsBar",                   ownedBy = "Bag Bar",          secure = true, propagateAlpha = true },
    { key = "BlizzEssentialCDs",     display = "Essential Cooldowns",   blizzardFrame = "EssentialCooldownViewer",   ownedBy = "Cooldown Manager", secure = true },
    { key = "BlizzUtilityCDs",       display = "Utility Cooldowns",     blizzardFrame = "UtilityCooldownViewer",     ownedBy = "Cooldown Manager", secure = true },
    { key = "BlizzBuffIconCDs",      display = "Buff Icon Cooldowns",   blizzardFrame = "BuffIconCooldownViewer",    ownedBy = "Cooldown Manager", secure = true },
    { key = "ExtraActionBar",        display = "Extra Action Button",   blizzardFrame = "ExtraActionBarFrame",       secure = true },
    { key = "ZoneAbility",           display = "Zone Ability",          blizzardFrame = "ZoneAbilityFrame",          secure = true },
}

-- Custom third-party addon frames (resolved via _G[frame] when addon is loaded)
local ADDON_REGISTRY = {
    { key = "Details1",         display = "Details! (Window 1)", addon = "Details",         frame = "DetailsBaseFrame1" },
    { key = "Details2",         display = "Details! (Window 2)", addon = "Details",         frame = "DetailsBaseFrame2" },
    { key = "Details3",         display = "Details! (Window 3)", addon = "Details",         frame = "DetailsBaseFrame3" },
    { key = "OmniCD",           display = "OmniCD",              addon = "OmniCD",          frame = "OmniCD" },
    { key = "Plater",           display = "Plater Nameplates",   addon = "Plater",          frame = "PlaterMainFrame" },
    { key = "Platynator",       display = "Platynator",          addon = "Platynator",      frame = "PlatynatorFrame" },
    { key = "Chattynator",      display = "Chattynator",         addon = "Chattynator",     frame = "ChattynatorFrame" },
    { key = "DandersFrames",    display = "DandersFrames",       addon = "DandersFrames",   frame = "DandersFramesMainFrame" },
    { key = "Cell",             display = "Cell Raid Frames",    addon = "Cell",            frame = "CellMainFrame" },
    { key = "BigWigs",          display = "BigWigs",             addon = "BigWigs",         frame = "BigWigsAnchor" },
    { key = "LittleWigs",       display = "LittleWigs",          addon = "LittleWigs",      frame = "LittleWigsAnchor" },
    { key = "DBM",              display = "Deadly Boss Mods",    addon = "DBM-Core",        frame = "DBMMinimapButton" },
    { key = "Bartender1",       display = "Bartender4 (Bar 1)",  addon = "Bartender4",      frame = "BT4Bar1" },
    { key = "Bartender2",       display = "Bartender4 (Bar 2)",  addon = "Bartender4",      frame = "BT4Bar2" },
    { key = "Bartender3",       display = "Bartender4 (Bar 3)",  addon = "Bartender4",      frame = "BT4Bar3" },
}

-- ownedBy may be a string (single owner) or a table of strings (multi-owner — entry is hidden
-- from the VE table whenever any listed plugin is enabled). Used by frames replaced by more than
-- one Orbit plugin (e.g. StatusTrackingBarManager handles both Experience and Honor bars).
local function IsOwnedByEnabledPlugin(entry)
    local owned = entry.ownedBy
    if not owned then return false end
    if type(owned) == "string" then return Orbit:IsPluginEnabled(owned) end
    for _, name in ipairs(owned) do
        if Orbit:IsPluginEnabled(name) then return true end
    end
    return false
end

-- [ DB ACCESS ]--------------------------------------------------------------------------------------
local function GetDB()
    if not Orbit.db then return nil end
    if not Orbit.db.VisibilityEngine then Orbit.db.VisibilityEngine = {} end
    return Orbit.db.VisibilityEngine
end

local function GetFrameDB(key)
    local db = GetDB()
    if not db then return nil end
    if not db[key] then db[key] = {} end
    return db[key]
end

-- [ API ]--------------------------------------------------------------------------------------------
function VE:GetFrameSetting(key, settingKey)
    local frameDB = GetFrameDB(key)
    if not frameDB then return DEFAULTS[settingKey] end
    local val = frameDB[settingKey]
    if val == nil then return DEFAULTS[settingKey] end
    return val
end

function VE:SetFrameSetting(key, settingKey, value)
    local frameDB = GetFrameDB(key)
    if not frameDB then return end
    frameDB[settingKey] = value
    if Orbit.EventBus then Orbit.EventBus:Fire("ORBIT_VISIBILITY_CHANGED", key, settingKey, value) end
end

function VE:GetAllFrames()
    return FRAME_REGISTRY
end

-- Returns true if the entry (Orbit or Blizzard) is opacity-only. O(n) but rarely called.
function VE:IsOpacityOnly(key)
    for _, e in ipairs(FRAME_REGISTRY) do if e.key == key then return e.opacityOnly == true end end
    for _, e in ipairs(BLIZZARD_REGISTRY) do if e.key == key then return e.opacityOnly == true end end
    return false
end

function VE:GetFrameDefaults()
    return DEFAULTS
end

function VE:GetBlizzardFrames()
    local result = {}
    for _, entry in ipairs(BLIZZARD_REGISTRY) do
        if not IsOwnedByEnabledPlugin(entry) then
            result[#result + 1] = entry
        end
    end
    return result
end

function VE:GetThirdPartyFrames()
    local active = {}
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    for _, entry in ipairs(ADDON_REGISTRY) do
        if isLoaded(entry.addon) and _G[entry.frame] then
            table.insert(active, entry)
        end
    end
    return active
end

function VE:IsBlizzardEntry(entry)
    return entry.blizzardFrame ~= nil
end

function VE:GetBlizzardFrame(entry)
    return entry.blizzardFrame and _G[entry.blizzardFrame]
end

-- Resolve a frame registry entry to its plugin object
function VE:GetPlugin(entry)
    return Orbit._pluginsByName and Orbit._pluginsByName[entry.plugin]
end

-- Look up the registry key for a given plugin name + system index (O(1) via reverse lookup)
function VE:GetKeyForPlugin(pluginName, systemIndex)
    local byPlugin = REVERSE_LOOKUP[pluginName]
    if not byPlugin then return nil end
    local key = byPlugin[systemIndex]
    if key then return key end
    -- Fallback: single-entry plugin with non-matching index (string SYSTEM_IDs)
    local singleKey
    for _, k in pairs(byPlugin) do
        if singleKey then return nil end
        singleKey = k
    end
    return singleKey
end

-- Check if a plugin frame should be hidden due to mounted state (unified helper)
function VE:IsFrameMountedHidden(pluginName, systemIndex)
    if not Orbit.MountedVisibility or not Orbit.MountedVisibility:IsCachedHidden() then return false end
    local veKey = self:GetKeyForPlugin(pluginName, systemIndex)
    return veKey and self:GetFrameSetting(veKey, "hideMounted") or false
end

-- Check if a plugin has the hideMounted setting enabled (config check, ignores current mount state)
function VE:HasMountedHideSetting(pluginName, systemIndex)
    local veKey = self:GetKeyForPlugin(pluginName, systemIndex)
    return veKey and self:GetFrameSetting(veKey, "hideMounted") or false
end

-- Check if any frame in VE has a specific boolean setting enabled
function VE:AnyFrameHasSetting(settingKey)
    local db = GetDB()
    if not db then return false end
    for key, _ in pairs(db) do
        if type(db[key]) == "table" and db[key][settingKey] then return true end
    end
    return false
end

-- [ MIGRATION ]--------------------------------------------------------------------------------------
-- One-time migration from per-plugin settings to centralized VisibilityEngine DB
function VE:Migrate()
    local db = GetDB()
    if not db then return end
    if db._migrated then return end
    local MIGRATION_MAP = {
        { setting = "OutOfCombatFade", veKey = "oocFade" },
        { setting = "ShowOnMouseover", veKey = "mouseOver" },
        { setting = "Opacity",         veKey = "opacity" },
    }
    for _, entry in ipairs(FRAME_REGISTRY) do
        local plugin = self:GetPlugin(entry)
        if plugin and plugin.GetSetting then
            for _, m in ipairs(MIGRATION_MAP) do
                local val = plugin:GetSetting(entry.index, m.setting)
                if val ~= nil then
                    local frameDB = GetFrameDB(entry.key)
                    if frameDB[m.veKey] == nil then frameDB[m.veKey] = val end
                end
            end
        end
    end
    db._migrated = true
end

-- [ APPLY ] -----------------------------------------------------------------------------------------
-- 12.0.5+ note: direct SetAlpha on a Blizzard secure frame from insecure context taints it. The
-- taint then surfaces in Blizzard's own UnitFrame_Update path on the next event (e.g. PLAYER_TARGET_CHANGED
-- → TargetFrame:OnEvent → UnitFrameHealthBar_Update fails on secret UnitHealthMax). To avoid tainting
-- frames the user has not actually configured, skip the SetAlpha entirely when all settings are at
-- defaults. SECURE_FRAMES tracks frames we've ever applied to so resets back to defaults still flow.
local SECURE_FRAMES = {}
local function HasNonDefaultSecureSettings(self, entry)
    local op = self:GetFrameSetting(entry.key, "opacity") or 100
    if op ~= 100 then return true end
    if entry.opacityOnly then return false end
    if self:GetFrameSetting(entry.key, "oocFade") then return true end
    if self:GetFrameSetting(entry.key, "showWithTarget") then return true end
    if self:GetFrameSetting(entry.key, "hideMounted") then return true end
    return false
end
function VE:ApplySecureBlizzardFrame(entry)
    if IsOwnedByEnabledPlugin(entry) then return end
    local frame = _G[entry.blizzardFrame]
    if not frame then return end
    if not SECURE_FRAMES[entry.key] and not HasNonDefaultSecureSettings(self, entry) then return end
    SECURE_FRAMES[entry.key] = entry
    local opacity = (self:GetFrameSetting(entry.key, "opacity") or 100) / 100
    local oocFade = not entry.opacityOnly and self:GetFrameSetting(entry.key, "oocFade")
    local showWithTarget = not entry.opacityOnly and self:GetFrameSetting(entry.key, "showWithTarget")
    local hideMounted = not entry.opacityOnly and self:GetFrameSetting(entry.key, "hideMounted")
    local mounted = Orbit.MountedVisibility and Orbit.MountedVisibility:IsCachedHidden() and hideMounted
    local revealedByTarget = showWithTarget and UnitExists("target")
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local oocHide = oocFade and not inCombat and not revealedByTarget and not Orbit:IsEditMode()
    local alpha = (mounted or oocHide) and 0 or (revealedByTarget and 1 or opacity)
    local function apply()
        frame:SetAlpha(alpha)
        if entry.propagateAlpha then
            for _, child in ipairs({ frame:GetChildren() }) do child:SetAlpha(alpha) end
        end
    end
    if InCombatLockdown() then
        if Orbit.CombatManager then Orbit.CombatManager:QueueUpdate(apply) end
    else
        apply()
    end
end

function VE:ApplyAllSecureBlizzardFrames()
    for _, entry in ipairs(BLIZZARD_REGISTRY) do
        if entry.secure then self:ApplySecureBlizzardFrame(entry) end
    end
end

function VE:ApplyBlizzardSettings()
    if not Orbit.OOCFadeMixin then return end
    for _, entry in ipairs(BLIZZARD_REGISTRY) do
        local frame = _G[entry.blizzardFrame]
        if frame then
            if entry.secure then
                self:ApplySecureBlizzardFrame(entry)
            else
                if entry.key == "BlizzMinimap" then frame.orbitOpacityExternal = true end
                Orbit.OOCFadeMixin:ApplyOOCFade(frame, nil, nil, nil, false, entry.key)
                -- Minimap: apply opacity to cluster children (including Minimap itself for engine-rendered POI pins)
                if entry.key == "BlizzMinimap" then
                    local opacity = (self:GetFrameSetting(entry.key, "opacity") or 100) / 100
                    for _, child in ipairs({ frame:GetChildren() }) do child:SetAlpha(opacity) end
                end
            end
        end
    end
end

-- Re-apply secure frames on combat exit and target/mount changes
local secureEvents = CreateFrame("Frame")
secureEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
secureEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
secureEvents:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
secureEvents:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
secureEvents:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
secureEvents:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
secureEvents:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
secureEvents:SetScript("OnEvent", function(_, event)
    local p = Orbit.Profiler
    local s = p and p:Begin()
    VE:ApplyAllSecureBlizzardFrames()
    if p then p:End("Orbit_VisibilityEngine", event, s) end
end)
C_Timer.After(0, function()
    if Orbit.EventBus then Orbit.EventBus:On("MOUNTED_VISIBILITY_CHANGED", function() VE:ApplyAllSecureBlizzardFrames() end) end
end)

function VE:ApplyAll()
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
    self:ApplyBlizzardSettings()
    self:ApplyAddonSettings()
end

function VE:ApplyAddonSettings()
    if not Orbit.OOCFadeMixin then return end
    for _, entry in ipairs(self:GetThirdPartyFrames()) do
        local frame = _G[entry.frame]
        if frame then
            Orbit.OOCFadeMixin:ApplyOOCFade(frame, nil, nil, nil, false, entry.key)
        end
    end
end

function VE:ApplyFrame(key)
    if not Orbit.OOCFadeMixin then return end
    for _, entry in ipairs(BLIZZARD_REGISTRY) do
        if entry.key == key then
            local frame = _G[entry.blizzardFrame]
            if frame then
                if entry.secure then
                    self:ApplySecureBlizzardFrame(entry)
                else
                    if key == "BlizzMinimap" then frame.orbitOpacityExternal = true end
                    Orbit.OOCFadeMixin:ApplyOOCFade(frame, nil, nil, nil, false, key)
                    if key == "BlizzMinimap" then
                        local opacity = (self:GetFrameSetting(key, "opacity") or 100) / 100
                        for _, child in ipairs({ frame:GetChildren() }) do child:SetAlpha(opacity) end
                    end
                end
            end
            return
        end
    end
    for _, entry in ipairs(ADDON_REGISTRY) do
        if entry.key == key then
            local frame = _G[entry.frame]
            if frame then
                Orbit.OOCFadeMixin:ApplyOOCFade(frame, nil, nil, nil, false, key)
            end
            return
        end
    end
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
end

-- [ STARTUP ] ---------------------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(STARTUP_DELAY, function()
        VE:ApplyBlizzardSettings()
        VE:ApplyAddonSettings()
    end)
end)
