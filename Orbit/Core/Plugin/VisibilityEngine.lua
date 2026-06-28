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

-- Orbit-plugin frames are registered at load by the Plugins-layer manifest (Plugins/VisibilityManifest.lua) via VE:RegisterFrame, so Core holds no plugin names (inward-dependency rule).
local FRAME_REGISTRY = {}
-- O(1) reverse lookup: { [pluginName] = { [systemIndex] = key } }
local REVERSE_LOOKUP = {}

-- Called by the Plugins-layer visibility manifest. entry = { key, display, plugin (name string), index, opacityOnly? }.
function VE:RegisterFrame(entry)
    if not entry or not entry.key then return end
    entry.index = entry.index or 1
    FRAME_REGISTRY[#FRAME_REGISTRY + 1] = entry
    REVERSE_LOOKUP[entry.plugin] = REVERSE_LOOKUP[entry.plugin] or {}
    REVERSE_LOOKUP[entry.plugin][entry.index] = entry.key
end

-- Blizzard frames (no Orbit plugin, resolved via _G[blizzardFrame]). This is Core's catalog of BLIZZARD frames, which Core legitimately owns. `ownedBy` is an accepted exception to the no-plugin-names rule: it is graceful-degrading integration metadata (hide this Blizzard frame's row when the named Orbit replacement is enabled); a stale name just leaves the Blizzard row visible, never errors. Orbit's own designable frames are registered from the Plugins layer (Plugins/VisibilityManifest.lua), not here.
local BLIZZARD_REGISTRY = {
    -- Insecure (full feature set: opacity, oocFade, hideMounted, mouseOver, showWithTarget)
    { key = "BlizzMinimap",          display = L.PLU_VE_MINIMAP,             blizzardFrame = "MinimapCluster",            ownedBy = "Minimap" },
    { key = "ObjectiveTracker",      display = L.PLU_VE_OBJECTIVE_TRACKER,   blizzardFrame = "ObjectiveTrackerFrame",     ownedBy = "Objectives" },
    { key = "BuffFrame",             display = L.PLU_VE_BUFF_FRAME,          blizzardFrame = "BuffFrame",                 ownedBy = "Player Buffs" },
    { key = "DebuffFrame",           display = L.PLU_VE_DEBUFF_FRAME,        blizzardFrame = "DebuffFrame",               ownedBy = "Player Debuffs" },
    { key = "ChatFrame",             display = L.PLU_VE_CHAT_FRAME,          blizzardFrame = "ChatFrame1" },
    { key = "StatusTrackingBar",     display = L.PLU_VE_XP_REP_HONOR_BAR,    blizzardFrame = "StatusTrackingBarManager",  ownedBy = "Status Widget" },
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
    { key = "BlizzMainMenuBar",      display = L.PLU_VE_ACTION_BAR_1,        blizzardFrame = "MainActionBar",             ownedBy = "Action Bars",      secure = true, propagateAlpha = true },
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

-- Category taxonomy for the Fade Profiles picker. Orbit-plugin frames carry their own `category` from Plugins/VisibilityManifest.lua (the sole place plugins are enumerated by name); Blizzard frames map by registry key here, which Core legitimately owns. Returns a stable category KEY the UI localizes.
local CATEGORY_ORDER = { "UnitFrames", "ActionBars", "Cooldowns", "HUD", "Other" }
local CATEGORY_BY_KEY = {
    BlizzPlayerFrame = "UnitFrames", BlizzPetFrame = "UnitFrames", BlizzTargetFrame = "UnitFrames",
    BlizzTargetOfTarget = "UnitFrames", BlizzFocusFrame = "UnitFrames", BlizzPartyFrame = "UnitFrames",
    BlizzRaidFrame = "UnitFrames", BlizzRaidManager = "UnitFrames", BlizzPlayerCastBar = "UnitFrames",
    BlizzMainMenuBar = "ActionBars", BlizzMultiBarBL = "ActionBars", BlizzMultiBarBR = "ActionBars",
    BlizzMultiBarRight = "ActionBars", BlizzMultiBarLeft = "ActionBars", BlizzMultiBar5 = "ActionBars",
    BlizzMultiBar6 = "ActionBars", BlizzMultiBar7 = "ActionBars", BlizzStanceBar = "ActionBars",
    BlizzPetActionBar = "ActionBars", BlizzPossessBar = "ActionBars", BlizzMicroMenu = "ActionBars",
    BlizzBagsBar = "ActionBars", ExtraActionBar = "ActionBars", ZoneAbility = "ActionBars",
    BlizzEssentialCDs = "Cooldowns", BlizzUtilityCDs = "Cooldowns", BlizzBuffIconCDs = "Cooldowns",
}

-- ownedBy: string or {strings} — entry is hidden from VE when ANY listed plugin is enabled (e.g. StatusTrackingBarManager → Experience + Honor).
local function IsOwnedByEnabledPlugin(entry)
    local owned = entry.ownedBy
    if not owned then return false end
    if type(owned) == "string" then return Orbit:IsPluginEnabled(owned) end
    for _, name in ipairs(owned) do
        if Orbit:IsPluginEnabled(name) then return true end
    end
    return false
end

-- select-vararg avoids the {GetChildren()} temp-table alloc on every secure/Blizzard-cluster repaint.
local function ApplyChildAlphaVararg(alpha, ...)
    for i = 1, select("#", ...) do
        select(i, ...):SetAlpha(alpha)
    end
end
local function ApplyChildAlpha(frame, alpha)
    ApplyChildAlphaVararg(alpha, frame:GetChildren())
end

-- [ DB ACCESS ]--------------------------------------------------------------------------------------
local function GetDB()
    local vis = Orbit.Profile and Orbit.Profile:GetActiveVisibility()
    return vis and vis.frames
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

function VE:GetCategoryOrder()
    return CATEGORY_ORDER
end

function VE:GetCategory(entry)
    if entry.plugin then return entry.category or "Other" end
    if entry.blizzardFrame then return CATEGORY_BY_KEY[entry.key] or "HUD" end
    return "Other"
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

function VE:ResetAll()
    local vis = Orbit.Profile and Orbit.Profile:GetActiveVisibility()
    if vis then vis.frames = {} end
    for _, entry in ipairs(self:GetBlizzardFrames()) do
        local f = _G[entry.blizzardFrame]
        if f then f:SetAlpha(1) end
    end
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
    Orbit.MountedVisibility:Refresh(true)
    local systems = Orbit.Engine and Orbit.Engine.systems
    if systems then
        for _, plugin in pairs(systems) do
            if plugin.ApplySettings then plugin:ApplySettings() end
        end
    end
    Orbit:Print(L.MSG_VE_RESET)
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
-- 12.0.5+: SetAlpha on a Blizzard secure frame from insecure context taints it, surfacing in UnitFrame_Update on next event. Skip SetAlpha entirely when all settings are at defaults; SECURE_FRAMES tracks ever-applied frames so resets still flow.
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
    local profileCap = Orbit.FadeProfiles and Orbit.FadeProfiles:GetResolvedAlpha(entry.key) or 1
    if not SECURE_FRAMES[entry.key] and not HasNonDefaultSecureSettings(self, entry) and profileCap >= 1 then return end
    SECURE_FRAMES[entry.key] = entry
    local opacity = (self:GetFrameSetting(entry.key, "opacity") or 100) / 100
    local oocFade = not entry.opacityOnly and self:GetFrameSetting(entry.key, "oocFade")
    local showWithTarget = not entry.opacityOnly and self:GetFrameSetting(entry.key, "showWithTarget")
    local hideMounted = not entry.opacityOnly and self:GetFrameSetting(entry.key, "hideMounted")
    local mounted = Orbit.MountedVisibility and Orbit.MountedVisibility:IsCachedHidden() and hideMounted
    local revealedByTarget = showWithTarget and UnitExists("target")
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local oocHide = oocFade and not inCombat and not revealedByTarget and not Orbit:IsEditMode()
    local alpha = math.min((mounted or oocHide) and 0 or (revealedByTarget and 1 or opacity), profileCap)
    local function apply()
        frame:SetAlpha(alpha)
        if entry.propagateAlpha then
            ApplyChildAlpha(frame, alpha)
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
                    ApplyChildAlpha(frame, opacity)
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
    if not Orbit.EventBus then return end
    Orbit.EventBus:On("ORBIT_MOUNTED_VISIBILITY_CHANGED", function() VE:ApplyAllSecureBlizzardFrames() end)
    -- New profile = different per-profile visibility store: re-apply Blizzard frames and refresh OOCFade snapshots (which key on ORBIT_VISIBILITY_CHANGED).
    Orbit.EventBus:On("ORBIT_PROFILE_CHANGED", function()
        VE:ApplyBlizzardSettings()
        Orbit.EventBus:Fire("ORBIT_VISIBILITY_CHANGED")
    end)
end)

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
                if entry.secure then
                    self:ApplySecureBlizzardFrame(entry)
                else
                    if key == "BlizzMinimap" then frame.orbitOpacityExternal = true end
                    Orbit.OOCFadeMixin:ApplyOOCFade(frame, nil, nil, nil, false, key)
                    if key == "BlizzMinimap" then
                        local opacity = (self:GetFrameSetting(key, "opacity") or 100) / 100
                        ApplyChildAlpha(frame, opacity)
                    end
                end
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
    end)
end)
