-- [ VISIBILITY ENGINE ]------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.VisibilityEngine = {}
local VE = Orbit.VisibilityEngine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local DEFAULTS = { oocFade = false, opacity = 100, hideMounted = false, mouseOver = true, showWithTarget = true, alphaLock = false }
local STARTUP_DELAY = 0.5

local FRAME_REGISTRY = {
    { key = "PlayerFrame",          display = L.PLU_VE_PLAYER_FRAME,     plugin = "Player Frame",       index = 1 },
    { key = "PlayerPower",          display = L.PLU_VE_PLAYER_POWER,     plugin = "Player Power",       index = 1 },
    { key = "PlayerCastBar",        display = L.PLU_VE_PLAYER_CAST_BAR,  plugin = "Player Cast Bar",    index = 1, opacityOnly = true },
    { key = "PlayerResources",      display = L.PLU_VE_PLAYER_RESOURCES, plugin = "Player Resources",   index = 1 },
    { key = "PetFrame",             display = L.PLU_VE_PET_FRAME,        plugin = "Pet Frame",          index = 1 },
    { key = "PlayerBuffs",          display = L.PLU_VE_PLAYER_BUFFS,     plugin = "Player Buffs",       index = 1 },
    { key = "PlayerDebuffs",        display = L.PLU_VE_PLAYER_DEBUFFS,   plugin = "Player Debuffs",     index = 1 },
    { key = "TargetFrame",          display = L.PLU_VE_TARGET_FRAME,     plugin = "Target Frame",       index = 1 },
    { key = "FocusFrame",           display = L.PLU_VE_FOCUS_FRAME,      plugin = "Focus Frame",        index = 1 },
    { key = "ActionBar1",           display = L.PLU_VE_ACTION_BAR_1,     plugin = "Action Bars",        index = 1 },
    { key = "ActionBar2",           display = L.PLU_VE_ACTION_BAR_2,     plugin = "Action Bars",        index = 2 },
    { key = "ActionBar3",           display = L.PLU_VE_ACTION_BAR_3,     plugin = "Action Bars",        index = 3 },
    { key = "ActionBar4",           display = L.PLU_VE_ACTION_BAR_4,     plugin = "Action Bars",        index = 4 },
    { key = "ActionBar5",           display = L.PLU_VE_ACTION_BAR_5,     plugin = "Action Bars",        index = 5 },
    { key = "ActionBar6",           display = L.PLU_VE_ACTION_BAR_6,     plugin = "Action Bars",        index = 6 },
    { key = "ActionBar7",           display = L.PLU_VE_ACTION_BAR_7,     plugin = "Action Bars",        index = 7 },
    { key = "ActionBar8",           display = L.PLU_VE_ACTION_BAR_8,     plugin = "Action Bars",        index = 8 },
    { key = "PetBar",               display = L.PLU_VE_PET_BAR,          plugin = "Action Bars",        index = 9 },
    { key = "StanceBar",            display = L.PLU_VE_STANCE_BAR,       plugin = "Action Bars",        index = 10 },
    { key = "EssentialCooldowns",   display = L.PLU_VE_ESSENTIAL_CDS,    plugin = "Cooldown Manager",   index = 1 },
    { key = "UtilityCooldowns",     display = L.PLU_VE_UTILITY_CDS,      plugin = "Cooldown Manager",   index = 2 },
    { key = "BuffIcons",            display = L.PLU_VE_BUFF_ICONS,       plugin = "Cooldown Manager",   index = 3 },
    { key = "ChargeBars",           display = L.PLU_VE_CHARGE_BARS,      plugin = "Cooldown Manager",   index = 20 },
    { key = "BuffBars",             display = L.PLU_VE_BUFF_BARS,        plugin = "Cooldown Manager",   index = 30 },
    -- Sentinel indices 1/2 — real Tracked record IDs are >= SystemIndexBase (1000) so they can't collide.
    { key = "TrackedIcons",         display = L.PLU_VE_TRACKED_ICONS,    plugin = "Tracked Items",      index = 1 },
    { key = "TrackedBars",          display = L.PLU_VE_TRACKED_BARS,     plugin = "Tracked Items",      index = 2 },
    { key = "DamageMeters",         display = L.PLU_VE_DAMAGE_METERS,    plugin = "Damage Meter",       index = 1 },
    { key = "GroupFrames",          display = L.PLU_VE_GROUP_FRAMES,     plugin = "Group Frames",       index = 1 },
    { key = "BossFrames",           display = L.PLU_VE_BOSS_FRAMES,      plugin = "Boss Frames",        index = 1, opacityOnly = true },
    { key = "MenuBar",              display = L.PLU_VE_MENU_BAR,         plugin = "Menu Bar",           index = 1 },
    { key = "BagBar",               display = L.PLU_VE_BAG_BAR,          plugin = "Bag Bar",            index = 1 },
    { key = "QueueStatus",          display = L.PLU_VE_QUEUE_STATUS,     plugin = "Queue Status",       index = 1 },
    { key = "PerformanceInfo",      display = L.PLU_VE_PERFORMANCE_INFO, plugin = "Performance Info",   index = 1 },
    { key = "CombatTimer",          display = L.PLU_VE_COMBAT_TIMER,     plugin = "Combat Timer",       index = 1 },
    { key = "Minimap",              display = L.PLU_VE_MINIMAP,          plugin = "Minimap",            index = 1 },
    { key = "MinimapButton",        display = L.PLU_VE_MINIMAP_BUTTON,   plugin = "Minimap Button",     index = 1 },
    { key = "Datatexts",            display = L.PLU_VE_DATATEXTS,        plugin = "Datatexts",          index = 1 },
    { key = "ExperienceBar",        display = L.PLU_VE_XP_REP_BAR,       plugin = "Experience Bar",     index = 1 },
    { key = "HonorBar",             display = L.PLU_VE_HONOR_BAR,        plugin = "Honor Bar",          index = 1 },
    { key = "PortalDock",           display = L.PLU_VE_PORTAL_DOCK,      plugin = "Portal Dock",        index = 1 },
    { key = "RaidPanel",            display = L.PLU_VE_RAID_PANEL,       plugin = "Raid Panel",         index = 1 },
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
    { key = "BlizzMinimap",          display = L.PLU_VE_MINIMAP,             blizzardFrame = "MinimapCluster",            ownedBy = "Minimap" },
    { key = "ObjectiveTracker",      display = L.PLU_VE_OBJECTIVE_TRACKER,   blizzardFrame = "ObjectiveTrackerFrame" },
    { key = "BuffFrame",             display = L.PLU_VE_BUFF_FRAME,          blizzardFrame = "BuffFrame",                 ownedBy = "Player Buffs" },
    { key = "DebuffFrame",           display = L.PLU_VE_DEBUFF_FRAME,        blizzardFrame = "DebuffFrame",               ownedBy = "Player Debuffs" },
    { key = "ChatFrame",             display = L.PLU_VE_CHAT_FRAME,          blizzardFrame = "ChatFrame1" },
    { key = "StatusTrackingBar",     display = L.PLU_VE_XP_REP_HONOR_BAR,    blizzardFrame = "StatusTrackingBarManager",  ownedBy = { "Experience Bar", "Honor Bar" } },
    { key = "DurabilityFrame",       display = L.PLU_VE_DURABILITY,          blizzardFrame = "DurabilityFrame" },
    { key = "VehicleSeatIndicator",  display = L.PLU_VE_VEHICLE_SEAT,        blizzardFrame = "VehicleSeatIndicator" },
    { key = "DamageMeter",           display = L.PLU_VE_DAMAGE_METER,        blizzardFrame = "DamageMeter",               ownedBy = "Damage Meter" },
    { key = "BlizzPlayerCastBar",    display = L.PLU_VE_PLAYER_CAST_BAR,     blizzardFrame = "PlayerCastingBarFrame",     ownedBy = "Player Cast Bar", opacityOnly = true },
    { key = "TalkingHead",           display = L.PLU_VE_TALKING_HEAD,        blizzardFrame = "TalkingHeadFrame" },
    { key = "EncounterBar",          display = L.PLU_VE_ENCOUNTER_BAR,       blizzardFrame = "EncounterBar" },
    { key = "LossOfControl",         display = L.PLU_VE_LOSS_OF_CONTROL,     blizzardFrame = "LossOfControlFrame",        opacityOnly = true },
    { key = "MirrorTimers",          display = L.PLU_VE_MIRROR_TIMERS,       blizzardFrame = "MirrorTimerContainer" },
    { key = "AlertFrame",            display = L.PLU_VE_ALERT_POPUPS,        blizzardFrame = "AlertFrame",                opacityOnly = true },
    -- Secure (opacity + oocFade + hideMounted + showWithTarget; no mouseOver reveal)
    { key = "BlizzPlayerFrame",      display = L.PLU_VE_PLAYER_FRAME,        blizzardFrame = "PlayerFrame",               ownedBy = "Player Frame",     secure = true },
    { key = "BlizzPetFrame",         display = L.PLU_VE_PET_FRAME,           blizzardFrame = "PetFrame",                  ownedBy = "Pet Frame",        secure = true },
    { key = "BlizzTargetFrame",      display = L.PLU_VE_TARGET_FRAME,        blizzardFrame = "TargetFrame",               ownedBy = "Target Frame",     secure = true },
    { key = "BlizzTargetOfTarget",   display = L.PLU_VE_TARGET_OF_TARGET,    blizzardFrame = "TargetFrameToT",            ownedBy = "Target Frame",     secure = true },
    { key = "BlizzFocusFrame",       display = L.PLU_VE_FOCUS_FRAME,         blizzardFrame = "FocusFrame",                ownedBy = "Focus Frame",      secure = true },
    { key = "BlizzPartyFrame",       display = L.PLU_VE_PARTY_FRAME,         blizzardFrame = "PartyFrame",                ownedBy = "Group Frames",     secure = true },
    { key = "BlizzRaidFrame",        display = L.PLU_VE_RAID_FRAMES,         blizzardFrame = "CompactRaidFrameContainer", ownedBy = "Group Frames",     secure = true },
    { key = "BlizzRaidManager",      display = L.PLU_VE_RAID_MANAGER,        blizzardFrame = "CompactRaidFrameManager",   ownedBy = "Raid Panel",       secure = true },
    { key = "BlizzMainMenuBar",      display = L.PLU_VE_ACTION_BAR_1,        blizzardFrame = "MainMenuBar",               ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBarBL",       display = L.PLU_VE_ACTION_BAR_2,        blizzardFrame = "MultiBarBottomLeft",        ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBarBR",       display = L.PLU_VE_ACTION_BAR_3,        blizzardFrame = "MultiBarBottomRight",       ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBarRight",    display = L.PLU_VE_ACTION_BAR_4,        blizzardFrame = "MultiBarRight",             ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBarLeft",     display = L.PLU_VE_ACTION_BAR_5,        blizzardFrame = "MultiBarLeft",              ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBar5",        display = L.PLU_VE_ACTION_BAR_6,        blizzardFrame = "MultiBar5",                 ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBar6",        display = L.PLU_VE_ACTION_BAR_7,        blizzardFrame = "MultiBar6",                 ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzMultiBar7",        display = L.PLU_VE_ACTION_BAR_8,        blizzardFrame = "MultiBar7",                 ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzStanceBar",        display = L.PLU_VE_STANCE_BAR,          blizzardFrame = "StanceBar",                 ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzPetActionBar",     display = L.PLU_VE_PET_ACTION_BAR,      blizzardFrame = "PetActionBar",              ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
    { key = "BlizzPossessBar",       display = L.PLU_VE_POSSESS_BAR,         blizzardFrame = "PossessActionBar",          secure = true, propagateAlpha = true },
    { key = "BlizzMicroMenu",        display = L.PLU_VE_MICRO_MENU,          blizzardFrame = "MicroMenuContainer",        ownedBy = "Menu Bar",         secure = true, propagateAlpha = true },
    { key = "BlizzBagsBar",          display = L.PLU_VE_BAGS_BAR,            blizzardFrame = "BagsBar",                   ownedBy = "Bag Bar",          secure = true, propagateAlpha = true },
    { key = "BlizzEssentialCDs",     display = L.PLU_VE_ESSENTIAL_CDS,       blizzardFrame = "EssentialCooldownViewer",   ownedBy = "Cooldown Manager", secure = true },
    { key = "BlizzUtilityCDs",       display = L.PLU_VE_UTILITY_CDS,         blizzardFrame = "UtilityCooldownViewer",     ownedBy = "Cooldown Manager", secure = true },
    { key = "BlizzBuffIconCDs",      display = L.PLU_VE_BUFF_ICON_CDS,       blizzardFrame = "BuffIconCooldownViewer",    ownedBy = "Cooldown Manager", secure = true },
    { key = "ExtraActionBar",        display = L.PLU_VE_EXTRA_ACTION_BUTTON, blizzardFrame = "ExtraActionBarFrame",       secure = true },
    { key = "ZoneAbility",           display = L.PLU_VE_ZONE_ABILITY,        blizzardFrame = "ZoneAbilityFrame",          secure = true },
}

-- Custom third-party addon frames (resolved via _G[frame] when addon is loaded)
local ADDON_REGISTRY = {
    { key = "Details1",         display = L.PLU_VE_DETAILS_W1,     addon = "Details",         frame = "DetailsBaseFrame1" },
    { key = "Details2",         display = L.PLU_VE_DETAILS_W2,     addon = "Details",         frame = "DetailsBaseFrame2" },
    { key = "Details3",         display = L.PLU_VE_DETAILS_W3,     addon = "Details",         frame = "DetailsBaseFrame3" },
    { key = "OmniCD",           display = L.PLU_VE_OMNICD,         addon = "OmniCD",          frame = "OmniCD" },
    { key = "Plater",           display = L.PLU_VE_PLATER,         addon = "Plater",          frame = "PlaterMainFrame" },
    { key = "Platynator",       display = L.PLU_VE_PLATYNATOR,     addon = "Platynator",      frame = "PlatynatorFrame" },
    { key = "Chattynator",      display = L.PLU_VE_CHATTYNATOR,    addon = "Chattynator",     frame = "ChattynatorFrame" },
    { key = "DandersFrames",    display = L.PLU_VE_DANDERS_FRAMES, addon = "DandersFrames",   frame = "DandersFramesMainFrame" },
    { key = "Cell",             display = L.PLU_VE_CELL,           addon = "Cell",            frame = "CellMainFrame" },
    { key = "BigWigs",          display = L.PLU_VE_BIGWIGS,        addon = "BigWigs",         frame = "BigWigsAnchor" },
    { key = "LittleWigs",       display = L.PLU_VE_LITTLEWIGS,     addon = "LittleWigs",      frame = "LittleWigsAnchor" },
    { key = "DBM",              display = L.PLU_VE_DBM,            addon = "DBM-Core",        frame = "DBMMinimapButton" },
    { key = "Bartender1",       display = L.PLU_VE_BARTENDER_1,    addon = "Bartender4",      frame = "BT4Bar1" },
    { key = "Bartender2",       display = L.PLU_VE_BARTENDER_2,    addon = "Bartender4",      frame = "BT4Bar2" },
    { key = "Bartender3",       display = L.PLU_VE_BARTENDER_3,    addon = "Bartender4",      frame = "BT4Bar3" },
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

-- True if the user has explicitly stored any value that differs from the default for this entry.
-- Compares each stored value against the actual DEFAULTS table (not truthiness).
local function HasUserCustomisedSettings(key)
    local db = GetDB()
    if not db then return false end
    local frameDB = db[key]
    if not frameDB then return false end
    for settingKey, defaultValue in pairs(DEFAULTS) do
        local stored = frameDB[settingKey]
        if stored ~= nil and stored ~= defaultValue then return true end
    end
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
        if IsOwnedByEnabledPlugin(entry) then
            -- Plugin manages this frame — skip VE application.
        else
            local frame = _G[entry.blizzardFrame]
            if frame then
                if entry.secure then
                    self:ApplySecureBlizzardFrame(entry)
                elseif not HasUserCustomisedSettings(entry.key) then
                    -- All settings at defaults — skip to avoid forcing alpha on frames another addon manages.
                else
                    if entry.key == "BlizzMinimap" then frame.orbitOpacityExternal = true end
                    Orbit.OOCFadeMixin:ApplyOOCFade(frame, nil, nil, nil, false, entry.key)
                    if entry.key == "BlizzMinimap" then
                        local opacity = (self:GetFrameSetting(entry.key, "opacity") or 100) / 100
                        if opacity < 1 then
                            for _, child in ipairs({ frame:GetChildren() }) do child:SetAlpha(opacity) end
                        end
                    end
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
            if IsOwnedByEnabledPlugin(entry) then return end
            if not entry.secure and not HasUserCustomisedSettings(entry.key) then return end
            local frame = _G[entry.blizzardFrame]
            if frame then
                if entry.secure then
                    self:ApplySecureBlizzardFrame(entry)
                else
                    if key == "BlizzMinimap" then frame.orbitOpacityExternal = true end
                    Orbit.OOCFadeMixin:ApplyOOCFade(frame, nil, nil, nil, false, key)
                    if key == "BlizzMinimap" then
                        local opacity = (self:GetFrameSetting(key, "opacity") or 100) / 100
                        if opacity < 1 then
                            for _, child in ipairs({ frame:GetChildren() }) do child:SetAlpha(opacity) end
                        end
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
