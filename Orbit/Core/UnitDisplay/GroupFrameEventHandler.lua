-- [ GROUP FRAME EVENT HANDLER ]--------------------------------------------------------------------
-- Shared OnEvent dispatch for group frame types (Party, Raid)

local _, Orbit = ...

local GroupFrameMixin = Orbit.GroupFrameMixin
local StatusDispatch = GroupFrameMixin.StatusDispatch
local UpdateInRange = GroupFrameMixin.UpdateInRange

-- [ HANDLER FACTORY ]------------------------------------------------------------------------------
-- Creates a shared OnEvent handler for group frames.
-- callbacks: { UpdatePowerBar, UpdateDebuffs, UpdateBuffs, UpdateDefensiveIcon,
--              UpdateCrowdControlIcon, UpdatePrivateAuras }
function GroupFrameMixin.CreateEventHandler(plugin, callbacks, originalOnEvent)
    return function(f, event, eventUnit, ...)
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            if eventUnit == f.unit then callbacks.UpdatePowerBar(f, plugin) end
            return
        end
        if event == "UNIT_AURA" then
            if eventUnit == f.unit then
                callbacks.UpdateDebuffs(f, plugin)
                callbacks.UpdateBuffs(f, plugin)
                callbacks.UpdateDefensiveIcon(f, plugin)
                callbacks.UpdateCrowdControlIcon(f, plugin)
                if callbacks.UpdatePrivateAuras then callbacks.UpdatePrivateAuras(f, plugin) end
                if plugin.UpdateDispelIndicator then plugin:UpdateDispelIndicator(f, plugin) end
            end
            return
        end
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            callbacks.UpdateDebuffs(f, plugin)
            callbacks.UpdateBuffs(f, plugin)
            return
        end
        if event == "PLAYER_TARGET_CHANGED" then
            StatusDispatch(f, plugin, "UpdateSelectionHighlight")
            return
        end
        if event == "UNIT_THREAT_SITUATION_UPDATE" then
            if eventUnit == f.unit and plugin.UpdateAggroIndicator then
                plugin:UpdateAggroIndicator(f, plugin)
            end
            return
        end
        if event == "UNIT_PHASE" or event == "UNIT_FLAGS" then
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
        if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            StatusDispatch(f, plugin, "UpdateReadyCheck")
            return
        end
        if event == "INCOMING_RESURRECT_CHANGED" then
            if eventUnit == f.unit then StatusDispatch(f, plugin, "UpdateIncomingRes") end
            return
        end
        if event == "INCOMING_SUMMON_CHANGED" then
            StatusDispatch(f, plugin, "UpdateIncomingSummon")
            return
        end
        if event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
            StatusDispatch(f, plugin, "UpdateRoleIcon")
            StatusDispatch(f, plugin, "UpdateLeaderIcon")
            if callbacks.UpdateMainTankIcon then StatusDispatch(f, plugin, "UpdateMainTankIcon") end
            return
        end
        if event == "RAID_TARGET_UPDATE" then
            StatusDispatch(f, plugin, "UpdateMarkerIcon")
            return
        end
        if event == "UNIT_IN_RANGE_UPDATE" then
            if eventUnit == f.unit then UpdateInRange(f) end
            return
        end
        if originalOnEvent then originalOnEvent(f, event, eventUnit, ...) end
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            StatusDispatch(f, plugin, "UpdateStatusText")
        end
    end
end

-- [ ONSHOW FACTORY ]-------------------------------------------------------------------------------
-- Creates a shared OnShow handler for group frames.
function GroupFrameMixin.CreateOnShowHandler(plugin, callbacks)
    return function(self)
        if not self.unit then return end
        self:UpdateAll()
        callbacks.UpdatePowerBar(self, plugin)
        callbacks.UpdateFrameLayout(self, Orbit.db.GlobalSettings.BorderSize, plugin)
        callbacks.UpdateDebuffs(self, plugin)
        callbacks.UpdateBuffs(self, plugin)
        callbacks.UpdateDefensiveIcon(self, plugin)
        callbacks.UpdateCrowdControlIcon(self, plugin)
        if callbacks.UpdatePrivateAuras then callbacks.UpdatePrivateAuras(self, plugin) end
        StatusDispatch(self, plugin, "UpdateAllPartyStatusIcons")
        StatusDispatch(self, plugin, "UpdateStatusText")
        UpdateInRange(self)
    end
end
