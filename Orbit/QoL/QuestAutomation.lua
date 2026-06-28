-- [ QUEST AUTOMATION ]-------------------------------------------------------------------------------
-- Handles auto-accept/auto-turn-in of quests. Events always registered; settings read at fire-time.
local _, Orbit = ...

Orbit.QuestAutomation = {}

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function GetAccountSetting(key, default)
    local v = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings[key]
    if v == nil then return default end
    return v
end

-- Hold-Shift pauses all quest automation (accept + turn-in) so a quest can be handled manually.
local function ShiftSkip()
    return GetAccountSetting("AutoTurnInHoldShift", true) and IsShiftKeyDown()
end

-- [ EVENT HANDLER ]----------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_AUTOCOMPLETE")
frame:RegisterEvent("GOSSIP_SHOW")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "QUEST_DETAIL" then
        if not GetAccountSetting("AutoAcceptQuests", false) then return end
        if ShiftSkip() then return end
        AcceptQuest()

    elseif event == "QUEST_COMPLETE" then
        if not GetAccountSetting("AutoTurnInQuests", false) then return end
        if ShiftSkip() then return end
        local numChoices = GetNumQuestChoices()
        if numChoices <= 1 then
            GetQuestReward(numChoices)
        end

    elseif event == "QUEST_AUTOCOMPLETE" then
        local questID = ...
        if questID then ShowQuestComplete(questID) end

    elseif event == "GOSSIP_SHOW" then
        if ShiftSkip() then return end

        -- Auto turn-in: look for a completable active quest
        if GetAccountSetting("AutoTurnInQuests", false) then
            local activeQuests = C_GossipInfo.GetActiveQuests()
            for _, questInfo in ipairs(activeQuests) do
                if questInfo.isComplete then
                    C_GossipInfo.SelectActiveQuest(questInfo.questID)
                    return
                end
            end
        end

        -- Auto accept: look for available quests to offer
        if GetAccountSetting("AutoAcceptQuests", false) then
            local availableQuests = C_GossipInfo.GetAvailableQuests()
            if #availableQuests == 0 then return end
            if GetAccountSetting("AutoAcceptPreventMulti", true) and #availableQuests > 1 then return end
            C_GossipInfo.SelectAvailableQuest(availableQuests[1].questID)
        end
    end
end)
