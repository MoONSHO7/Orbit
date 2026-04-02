-- [ GROUP FRAME EVENT HANDLER ]--------------------------------------------------------------------
-- Shared OnEvent dispatch for group frame types (Party, Raid)

local _, Orbit = ...

local GroupFrameMixin = Orbit.GroupFrameMixin
local StatusDispatch = GroupFrameMixin.StatusDispatch
local UpdateInRange = GroupFrameMixin.UpdateInRange

-- [ AURA UPDATE DISPATCH ]------------------------------------------------------------------------
-- Aura component keys checked before building a snapshot
local AURA_COMPONENT_KEYS = { "Debuffs", "Buffs", "DefensiveIcon", "CrowdControlIcon" }

local function HasAnyAuraComponent(plugin)
    local cache = plugin._auraComponentsActive
    if cache ~= nil then return cache end
    local disabled = plugin.IsComponentDisabled
    if not disabled then plugin._auraComponentsActive = true; return true end
    for _, key in ipairs(AURA_COMPONENT_KEYS) do
        if not plugin:IsComponentDisabled(key) then plugin._auraComponentsActive = true; return true end
    end
    -- Check healer aura slots
    local HealerReg = Orbit.HealerAuraRegistry
    if HealerReg then
        for _, slot in ipairs(HealerReg:ActiveSlots()) do
            if not plugin:IsComponentDisabled(slot.key) then plugin._auraComponentsActive = true; return true end
        end
        if not plugin:IsComponentDisabled("RaidBuff") then plugin._auraComponentsActive = true; return true end
    end
    -- Check dispel indicator
    if plugin.UpdateDispelIndicator then plugin._auraComponentsActive = true; return true end
    plugin._auraComponentsActive = false
    return false
end

local AuraMixin
local function GetAuraMixin()
    if not AuraMixin then AuraMixin = Orbit.AuraMixin end
    return AuraMixin
end

local function DispatchAuraConsumers(f, plugin, callbacks, snapshot)
    f._auraSnapshot = snapshot
    callbacks.UpdateDebuffs(f, plugin)
    callbacks.UpdateBuffs(f, plugin)
    callbacks.UpdateDefensiveIcon(f, plugin)
    callbacks.UpdateCrowdControlIcon(f, plugin)
    if callbacks.UpdateHealerAuras then callbacks.UpdateHealerAuras(f, plugin) end
    if callbacks.UpdateMissingRaidBuffs then callbacks.UpdateMissingRaidBuffs(f, plugin) end
    if plugin.UpdateDispelIndicator then plugin:UpdateDispelIndicator(f, plugin, snapshot.harmful) end
    f._auraSnapshot = nil
end

local function ProcessAuraUpdate(f, plugin, callbacks, updateInfo)
    local unit = f.unit
    if not unit or not UnitExists(unit) then return end
    if not HasAnyAuraComponent(plugin) then return end
    local M = GetAuraMixin()
    local isFullUpdate = not updateInfo or updateInfo.isFullUpdate
    -- Incremental path: patch existing caches if available
    if not isFullUpdate and f._harmfulAuraCache then
        local changed = M:PatchCaches(f, unit, updateInfo)
        if not changed then return end
        local snapshot = M:BuildSnapshotFromCaches(f)
        if snapshot then DispatchAuraConsumers(f, plugin, callbacks, snapshot) end
        return
    end
    -- Full path: build from API, seed caches for future incremental updates
    local snapshot = M:BuildAuraSnapshot(unit)
    M:PopulateCaches(f, snapshot)
    DispatchAuraConsumers(f, plugin, callbacks, snapshot)
end

-- [ HANDLER FACTORY ]------------------------------------------------------------------------------
function GroupFrameMixin.CreateEventHandler(plugin, callbacks, originalOnEvent)
    local handler = function(f, event, eventUnit, ...)
        if f.preview then return end
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            if eventUnit == f.unit then
                if originalOnEvent then originalOnEvent(f, event, eventUnit, ...) end
            end
            return
        end
        if event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_PREDICTION" then
            if eventUnit == f.unit then
                if originalOnEvent then originalOnEvent(f, event, eventUnit, ...) end
            end
            return
        end
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
            if eventUnit == f.unit then callbacks.UpdatePowerBar(f, plugin) end
            return
        end
        if event == "UNIT_AURA" then
            if eventUnit == f.unit then
                local updateInfo = ...
                ProcessAuraUpdate(f, plugin, callbacks, updateInfo)
            end
            return
        end
        if event == "UNIT_THREAT_SITUATION_UPDATE" then
            if eventUnit == f.unit and plugin.UpdateAggroIndicator then
                plugin:UpdateAggroIndicator(f, plugin)
            end
            return
        end
        if event == "UNIT_NAME_UPDATE" then
            if eventUnit == f.unit then StatusDispatch(f, plugin, "UpdateName") end
            return
        end
        if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
            if eventUnit == f.unit then
                GetAuraMixin():WipeCaches(f)
                if f.UpdateAll then f:UpdateAll() end
                ProcessAuraUpdate(f, plugin, callbacks, nil)
                StatusDispatch(f, plugin, "UpdateName")
            end
            return
        end
        if event == "UNIT_PHASE" or event == "UNIT_FLAGS" or event == "UNIT_OTHER_PARTY_CHANGED" then
            if eventUnit == f.unit then
                StatusDispatch(f, plugin, "UpdatePhaseIcon")
                StatusDispatch(f, plugin, "UpdateLeaderIcon")
                UpdateInRange(f)
            end
            return
        end
        if event == "UNIT_CONNECTION" then
            if eventUnit == f.unit then
                UpdateInRange(f)
                StatusDispatch(f, plugin, "UpdateStatusText")
            end
            return
        end
        if event == "INCOMING_RESURRECT_CHANGED" then
            if eventUnit == f.unit then StatusDispatch(f, plugin, "UpdateIncomingRes") end
            return
        end
        if event == "UNIT_IN_RANGE_UPDATE" then
            if eventUnit == f.unit then UpdateInRange(f) end
            return
        end
        if originalOnEvent then originalOnEvent(f, event, eventUnit, ...) end
    end
    return function(f, event, eventUnit, ...)
        local profilerActive = Orbit.Profiler and Orbit.Profiler:IsActive()
        local start = profilerActive and debugprofilestop() or nil
        handler(f, event, eventUnit, ...)
        if start then
            Orbit.Profiler:RecordContext(plugin.system or plugin.name or "Orbit_GroupFrames", event, debugprofilestop() - start)
        end
    end
end

-- [ ONSHOW FACTORY ]-------------------------------------------------------------------------------
-- Creates a shared OnShow handler for group frames.
function GroupFrameMixin.CreateOnShowHandler(plugin, callbacks)
    return function(self)
        if self.preview then return end
        if not self.unit then return end
        self:UpdateAll()
        callbacks.UpdatePowerBar(self, plugin)
        callbacks.UpdateFrameLayout(self, Orbit.db.GlobalSettings.BorderSize, plugin)
        callbacks.UpdateDebuffs(self, plugin)
        callbacks.UpdateBuffs(self, plugin)
        callbacks.UpdateDefensiveIcon(self, plugin)
        callbacks.UpdateCrowdControlIcon(self, plugin)
        if callbacks.UpdatePrivateAuras then callbacks.UpdatePrivateAuras(self, plugin) end
        if callbacks.UpdateHealerAuras then callbacks.UpdateHealerAuras(self, plugin) end
        if callbacks.UpdateMissingRaidBuffs then callbacks.UpdateMissingRaidBuffs(self, plugin) end
        StatusDispatch(self, plugin, "UpdateAllPartyStatusIcons")
        StatusDispatch(self, plugin, "UpdateStatusText")
        UpdateInRange(self)
    end
end

-- [ CENTRALIZED GLOBAL EVENT HANDLER ]-------------------------------------------------------------
-- Single event frame handles all global events and dispatches to visible frames.
-- Eliminates N per-frame closures per global event (was O(40) closures, now O(1) + iteration).
local GLOBAL_EVENTS = {
    "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
    "INCOMING_SUMMON_CHANGED", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE",
    "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

function GroupFrameMixin.CreateGlobalEventHandler(plugin, callbacks)
    local eventFrame = CreateFrame("Frame")
    for _, ev in ipairs(GLOBAL_EVENTS) do eventFrame:RegisterEvent(ev) end
    local handler = function(_, event)
        local frames = plugin.frames
        if not frames then return end
        if event == "PLAYER_TARGET_CHANGED" then
            for _, f in ipairs(frames) do
                if not f.preview and f.unit and f:IsShown() then StatusDispatch(f, plugin, "UpdateSelectionHighlight") end
            end
            return
        end
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            local M = GetAuraMixin()
            local snapshots = {}
            for _, f in ipairs(frames) do
                if not f.preview and f.unit and f:IsShown() then
                    if not snapshots[f.unit] then snapshots[f.unit] = M:BuildAuraSnapshot(f.unit) end
                    local snap = snapshots[f.unit]
                    M:PopulateCaches(f, snap)
                    f._auraSnapshot = snap
                    callbacks.UpdateDebuffs(f, plugin)
                    callbacks.UpdateBuffs(f, plugin)
                    f._auraSnapshot = nil
                end
            end
            return
        end
        if event == "RAID_TARGET_UPDATE" then
            for _, f in ipairs(frames) do
                if not f.preview and f.unit and f:IsShown() then StatusDispatch(f, plugin, "UpdateMarkerIcon") end
            end
            return
        end
        if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            for _, f in ipairs(frames) do
                if not f.preview and f.unit and f:IsShown() then StatusDispatch(f, plugin, "UpdateReadyCheck") end
            end
            return
        end
        if event == "INCOMING_SUMMON_CHANGED" then
            for _, f in ipairs(frames) do
                if not f.preview and f.unit and f:IsShown() then StatusDispatch(f, plugin, "UpdateIncomingSummon") end
            end
            return
        end
        if event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
            for _, f in ipairs(frames) do
                if not f.preview and f.unit and f:IsShown() then
                    StatusDispatch(f, plugin, "UpdateRoleIcon")
                    StatusDispatch(f, plugin, "UpdateLeaderIcon")
                    if callbacks.UpdateMainTankIcon then StatusDispatch(f, plugin, "UpdateMainTankIcon") end
                    callbacks.UpdatePowerBar(f, plugin)
                end
            end
            return
        end
    end
    
    eventFrame:SetScript("OnEvent", function(self, event)
        local profilerActive = Orbit.Profiler and Orbit.Profiler:IsActive()
        local start = profilerActive and debugprofilestop() or nil
        handler(self, event)
        if start then
            Orbit.Profiler:RecordContext(plugin.system or plugin.name or "Orbit_GroupFrames", event, debugprofilestop() - start)
        end
    end)
    return eventFrame
end

