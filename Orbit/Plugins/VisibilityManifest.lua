-- [ VISIBILITY FRAME MANIFEST ]----------------------------------------------------------------------
-- Names every Orbit-plugin frame shown in the Visibility config panel. Lives in the Plugins layer (not Core) so Core/Plugin/VisibilityEngine.lua stays plugin-agnostic per the inward-dependency rule; this manifest is the one place allowed to enumerate plugins by name.
local _, Orbit = ...
local L = Orbit.L
local VE = Orbit.VisibilityEngine

local FRAMES = {
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
    { key = "StatusWidget",         display = L.PLU_STATUS_BAR_V2_NAME,  plugin = "Status Widget",      index = 1 },
    { key = "PortalDock",           display = L.PLU_VE_PORTAL_DOCK,      plugin = "Portal Dock",        index = 1 },
    { key = "RaidPanel",            display = L.PLU_VE_RAID_PANEL,       plugin = "Raid Panel",         index = 1 },
}

for _, entry in ipairs(FRAMES) do VE:RegisterFrame(entry) end
