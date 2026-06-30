-- [ OBJECTIVES ZONE FILTER ]-------------------------------------------------------------------------
-- Auto-tracks quests in the player's current zone and untracks quests from other zones by managing the watch list — the tracker only shows watched quests, and there is no taint-safe way to override Blizzard's ShouldDisplayQuest. Quest data is non-secret and the watch APIs are AllowedWhenUntainted, so this is taint-light and combat-safe. Manual pins, the super-tracked quest, complete/turn-in-ready quests, and zoneless/account quests always stay visible.
---@type Orbit
local Orbit = Orbit

local C = Orbit.ObjectivesConstants
local SYSTEM_ID = C.SYSTEM_ID

local Plugin = Orbit:GetPlugin("Objectives")

local C_QuestLog = C_QuestLog
local C_Map = C_Map
local C_SuperTrack = C_SuperTrack
local C_TaskQuest = C_TaskQuest
local GetQuestUiMapID = GetQuestUiMapID
local ipairs, pairs, next, wipe = ipairs, pairs, next, wipe
local WATCH_AUTOMATIC = Enum.QuestWatchType and Enum.QuestWatchType.Automatic
local WATCH_MANUAL = Enum.QuestWatchType and Enum.QuestWatchType.Manual
local CONTINENT = Enum.UIMapType and Enum.UIMapType.Continent
local ZONE = Enum.UIMapType and Enum.UIMapType.Zone

-- Zone change can fire ZONE_CHANGED (sub-area) without ZONE_CHANGED_NEW_AREA, so listen to both; quest events re-assert after accept/turn-in/abandon and after any watch change (autoQuestWatch re-adds out-of-zone quests, which we then drop).
local ZONE_FILTER_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "QUEST_ACCEPTED",
    "QUEST_TURNED_IN",
    "QUEST_REMOVED",
    "QUEST_WATCH_LIST_CHANGED",
}

-- The player's current map plus its ancestors up to (and including) stopType: Continent for the quest filter (continent-wide quests show across the continent), Zone for world quests (tight — only the current zone, so an adjacent/child area like Zul'Aman never bleeds into Eversong Woods). A quest matches when its GetQuestUiMapID is in this set; sibling zones are always excluded.
local function BuildZoneMapSet(stopType)
    local set = {}
    local mapID = C_Map.GetBestMapForUnit("player")
    while mapID and mapID ~= 0 do
        set[mapID] = true
        local info = C_Map.GetMapInfo(mapID)
        if not info then break end
        if stopType and info.mapType and info.mapType <= stopType then break end
        mapID = info.parentMapID
    end
    return set
end

-- [ EVALUATE ]---------------------------------------------------------------------------------------
-- Walk the quest log once: track current-zone quests, untrack other-zone quests. `AddQuestWatch` can't set the watch type (only the World-Quest variant takes one), so quests we add read back as Manual and are indistinguishable from real pins by type alone — we instead flag every quest we manage in `_zoneAutoTracked`, and only ever untrack those (plus engine-Automatic watches). Genuine manual pins, the super-tracked quest, complete/turn-in-ready quests, and zoneless/account quests are never removed.
function Plugin:EvaluateZoneFilter()
    if not self._zoneFilterEnabled then return end
    if self._zoneFilterUpdating then return end

    local zoneMaps = BuildZoneMapSet(CONTINENT)
    if not next(zoneMaps) then return end

    local tracked = self._zoneAutoTracked
    local removed = self._zoneAutoRemoved
    local superID = C_SuperTrack.GetSuperTrackedQuestID()

    -- Guard our own AddQuestWatch/RemoveQuestWatch — each fires QUEST_WATCH_LIST_CHANGED, which would otherwise re-enter.
    self._zoneFilterUpdating = true

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and not info.isTask and not info.isBounty then
            local questID = info.questID
            if questID then
                local questMap = GetQuestUiMapID(questID) or 0
                local inZone = questMap ~= 0 and zoneMaps[questMap]
                local watchType = C_QuestLog.GetQuestWatchType(questID)
                local watched = watchType ~= nil

                if inZone then
                    if not watched then
                        C_QuestLog.AddQuestWatch(questID)
                        tracked[questID] = true
                    elseif watchType == WATCH_AUTOMATIC then
                        tracked[questID] = true
                    end
                    removed[questID] = nil
                elseif watched and (tracked[questID] or watchType == WATCH_AUTOMATIC)
                    and questMap ~= 0 and questID ~= superID
                    and not C_QuestLog.IsComplete(questID) and not C_QuestLog.ReadyForTurnIn(questID) then
                    C_QuestLog.RemoveQuestWatch(questID)
                    tracked[questID] = nil
                    removed[questID] = true
                end
            end
        end
    end

    self._zoneFilterUpdating = false
end

-- [ WORLD QUESTS ]-----------------------------------------------------------------------------------
-- Auto-track every world quest on the current map, untrack the ones we added that left the area. World quests are a separate watch list: AddWorldQuestWatch DOES take a type, but Automatic watches are engine-capped (only a few survive), so we add as Manual to keep them all and flag them in _zoneAutoTrackedWQ — user-pinned world quests (watched, never flagged by us) are left alone.
function Plugin:EvaluateWorldQuestZone()
    if not self._zoneWQEnabled then return end
    if self._zoneFilterUpdating then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end

    -- GetQuestsOnMap can return world quests from adjacent/child areas (e.g. Zul'Aman bleeding into Eversong Woods), so confirm each WQ's own zone (GetQuestUiMapID) is the current zone — a zone-level set, never the continent.
    local zoneMaps = BuildZoneMapSet(ZONE)
    local trackedWQ = self._zoneAutoTrackedWQ
    self._zoneFilterUpdating = true

    local inArea = {}
    local tasks = C_TaskQuest.GetQuestsOnMap(mapID)
    if tasks then
        for _, poi in ipairs(tasks) do
            local questID = poi.questID
            if questID and C_QuestLog.IsWorldQuest(questID) and zoneMaps[GetQuestUiMapID(questID) or 0] then
                inArea[questID] = true
                if C_QuestLog.GetQuestWatchType(questID) == nil then
                    C_QuestLog.AddWorldQuestWatch(questID, WATCH_MANUAL)
                    trackedWQ[questID] = true
                end
            end
        end
    end

    for questID in pairs(trackedWQ) do
        if not inArea[questID] then
            C_QuestLog.RemoveWorldQuestWatch(questID)
            trackedWQ[questID] = nil
        end
    end

    self._zoneFilterUpdating = false
end

-- Coalesce a burst of events into one evaluation on the next frame; ignore the watch-list events our own pass generates.
function Plugin:ScheduleZoneFilterUpdate()
    if self._zoneFilterUpdating or self._zoneFilterPending then return end
    self._zoneFilterPending = true
    RunNextFrame(function()
        self._zoneFilterPending = false
        self:EvaluateZoneFilter()
        self:EvaluateWorldQuestZone()
    end)
end

-- Re-watch the quests this session's filtering removed (that still exist and aren't already watched), so turning the filter off restores what it hid.
function Plugin:RestoreZoneFilter()
    local removed = self._zoneAutoRemoved
    if not removed or not next(removed) then return end
    self._zoneFilterUpdating = true
    for questID in pairs(removed) do
        if C_QuestLog.GetLogIndexForQuestID(questID) and not C_QuestLog.GetQuestWatchType(questID) then
            C_QuestLog.AddQuestWatch(questID)
        end
    end
    wipe(removed)
    self._zoneFilterUpdating = false
end

-- Untrack the world quests this session added (the WQ tracker is additive, so turning it off removes what it added).
function Plugin:RemoveAutoTrackedWorldQuests()
    local trackedWQ = self._zoneAutoTrackedWQ
    if not trackedWQ or not next(trackedWQ) then return end
    self._zoneFilterUpdating = true
    for questID in pairs(trackedWQ) do
        C_QuestLog.RemoveWorldQuestWatch(questID)
    end
    wipe(trackedWQ)
    self._zoneFilterUpdating = false
end

-- [ ENABLE / DISABLE ]-------------------------------------------------------------------------------
-- The current-zone quest filter and the area world-quest tracker are independent toggles that share one event frame and the current-map math. Idempotent: ApplySettings calls this every pass; each feature only acts on its own enabled-state transition (filter restores removed quests on off; WQ tracker untracks its adds on off).
function Plugin:UpdateZoneFilters()
    if not self._zoneFilterFrame then
        self._zoneAutoTracked = {}
        self._zoneAutoRemoved = {}
        self._zoneAutoTrackedWQ = {}
        self._zoneFilterFrame = CreateFrame("Frame")
        self._zoneFilterFrame:SetScript("OnEvent", function() self:ScheduleZoneFilterUpdate() end)
    end

    local filter = self:GetSetting(SYSTEM_ID, "ZoneFilter") and true or false
    local worldQuests = self:GetSetting(SYSTEM_ID, "ZoneWorldQuests") and true or false
    local filterTurnedOn = filter and not self._zoneFilterEnabled
    local wqTurnedOn = worldQuests and not self._zoneWQEnabled

    if filter ~= self._zoneFilterEnabled then
        self._zoneFilterEnabled = filter
        if not filter then self:RestoreZoneFilter() end
    end
    if worldQuests ~= self._zoneWQEnabled then
        self._zoneWQEnabled = worldQuests
        if not worldQuests then self:RemoveAutoTrackedWorldQuests() end
    end

    local frame = self._zoneFilterFrame
    if filter or worldQuests then
        for _, event in ipairs(ZONE_FILTER_EVENTS) do frame:RegisterEvent(event) end
    else
        frame:UnregisterAllEvents()
    end

    if filterTurnedOn then self:EvaluateZoneFilter() end
    if wqTurnedOn then self:EvaluateWorldQuestZone() end
end
