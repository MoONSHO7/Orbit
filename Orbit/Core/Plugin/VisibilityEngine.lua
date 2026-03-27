-- [ VISIBILITY ENGINE ]-----------------------------------------------------------------------------
-- Centralized visibility settings for all Orbit frames.
-- Stores per-frame: oocFade, opacity, hideMounted, mouseOver, showWithTarget.

local _, Orbit = ...
local OrbitEngine = Orbit.Engine

-- [ MODULE ]----------------------------------------------------------------------------------------
Orbit.VisibilityEngine = {}
local VE = Orbit.VisibilityEngine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local DEFAULTS = { oocFade = false, opacity = 100, hideMounted = false, mouseOver = true, showWithTarget = true }

-- Ordered list of manageable frames: { key, displayName, pluginName, systemIndex }
-- key = unique string used as DB key
-- Orbit plugin frames (plugin + index)
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
    { key = "TrackedCooldowns",     display = "Tracked Cooldowns",     plugin = "Cooldown Manager",   index = 4 },
    { key = "ChargeBars",           display = "Charge Bars",           plugin = "Cooldown Manager",   index = 20 },
    { key = "BuffBars",             display = "Buff Bars",             plugin = "Cooldown Manager",   index = 30 },
    { key = "GroupFrames",          display = "Group Frames",          plugin = "Group Frames",       index = 1 },
    { key = "BossFrames",           display = "Boss Frames",           plugin = "Boss Frames",        index = 1, opacityOnly = true },
    { key = "MenuBar",              display = "Menu Bar",              plugin = "Menu Bar",           index = 1 },
    { key = "BagBar",               display = "Bag Bar",               plugin = "Bag Bar",            index = 1 },
    { key = "QueueStatus",          display = "Queue Status",          plugin = "Queue Status",       index = 1 },
    { key = "PerformanceInfo",      display = "Performance Info",      plugin = "Performance Info",   index = 1 },
    { key = "CombatTimer",          display = "Combat Timer",          plugin = "Combat Timer",       index = 1 },
}

-- Blizzard frames (no Orbit plugin, resolved via _G[blizzardFrame])
local BLIZZARD_REGISTRY = {
    { key = "Minimap",              display = "Minimap",               blizzardFrame = "MinimapCluster" },
    { key = "ObjectiveTracker",     display = "Objective Tracker",     blizzardFrame = "ObjectiveTrackerFrame" },
    { key = "BuffFrame",            display = "Buff Frame",            blizzardFrame = "BuffFrame" },
    { key = "DebuffFrame",          display = "Debuff Frame",          blizzardFrame = "DebuffFrame" },
    { key = "ChatFrame",            display = "Chat Frame",            blizzardFrame = "ChatFrame1" },
    { key = "StatusTrackingBar",    display = "XP / Rep Bar",          blizzardFrame = "StatusTrackingBarManager" },
    { key = "DurabilityFrame",      display = "Durability",            blizzardFrame = "DurabilityFrame" },
    { key = "VehicleSeatIndicator", display = "Vehicle Seat",          blizzardFrame = "VehicleSeatIndicator" },
    { key = "DamageMeter",          display = "Damage Meter",          blizzardFrame = "DamageMeter" },
}

-- [ DB ACCESS ]-------------------------------------------------------------------------------------
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

-- [ API ]-------------------------------------------------------------------------------------------
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

function VE:GetFrameDefaults()
    return DEFAULTS
end

function VE:GetBlizzardFrames()
    return BLIZZARD_REGISTRY
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

-- Look up the registry key for a given plugin name + system index
function VE:GetKeyForPlugin(pluginName, systemIndex)
    for _, entry in ipairs(FRAME_REGISTRY) do
        if entry.plugin == pluginName and entry.index == systemIndex then return entry.key end
    end
    -- Fallback: single-entry plugin with non-matching index (string SYSTEM_IDs)
    local singleMatch
    for _, entry in ipairs(FRAME_REGISTRY) do
        if entry.plugin == pluginName then
            if singleMatch then return nil end
            singleMatch = entry
        end
    end
    return singleMatch and singleMatch.key or nil
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

-- [ MIGRATION ]-------------------------------------------------------------------------------------
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

-- [ APPLY ]------------------------------------------------------------------------------------------
function VE:ApplyBlizzardSettings()
    if not Orbit.OOCFadeMixin then return end
    for _, entry in ipairs(BLIZZARD_REGISTRY) do
        local frame = _G[entry.blizzardFrame]
        if frame then
            if entry.key == "Minimap" then frame.orbitOpacityExternal = true end
            Orbit.OOCFadeMixin:ApplyOOCFade(frame, nil, nil, nil, false, entry.key)
            -- Minimap: apply opacity to cluster children (including Minimap itself for engine-rendered POI pins)
            if entry.key == "Minimap" then
                local opacity = (self:GetFrameSetting(entry.key, "opacity") or 100) / 100
                for _, child in ipairs({ frame:GetChildren() }) do child:SetAlpha(opacity) end
            end
        end
    end
end

function VE:ApplyAll()
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
    self:ApplyBlizzardSettings()
end

function VE:ApplyFrame(key)
    if not Orbit.OOCFadeMixin then return end
    for _, entry in ipairs(BLIZZARD_REGISTRY) do
        if entry.key == key then
            local frame = _G[entry.blizzardFrame]
            if frame then
                if key == "Minimap" then frame.orbitOpacityExternal = true end
                Orbit.OOCFadeMixin:ApplyOOCFade(frame, nil, nil, nil, false, key)
                if key == "Minimap" then
                    local opacity = (self:GetFrameSetting(key, "opacity") or 100) / 100
                    for _, child in ipairs({ frame:GetChildren() }) do child:SetAlpha(opacity) end
                end
            end
            return
        end
    end
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
end

-- [ STARTUP ]----------------------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(0.5, function() VE:ApplyBlizzardSettings() end)
end)
