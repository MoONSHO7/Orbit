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

-- [ EVENT HANDLER ]-----------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_AUTOCOMPLETE")
frame:RegisterEvent("GOSSIP_SHOW")

frame:SetScript("OnEvent", function(_, event, ...)
    -- ------------------------------------------------------------------ QUEST_DETAIL
    if event == "QUEST_DETAIL" then
        if not GetAccountSetting("AutoAcceptQuests", false) then return end
        AcceptQuest()

    -- ------------------------------------------------------------------ QUEST_COMPLETE
    elseif event == "QUEST_COMPLETE" then
        if not GetAccountSetting("AutoTurnInQuests", false) then return end
        if GetAccountSetting("AutoTurnInHoldShift", true) and IsShiftKeyDown() then return end
        if GetNumQuestChoices() > 1 then return end
        CompleteQuest()

    -- ------------------------------------------------------------------ QUEST_AUTOCOMPLETE
    elseif event == "QUEST_AUTOCOMPLETE" then
        local questID = ...
        if questID then ShowQuestComplete(questID) end

    -- ------------------------------------------------------------------ GOSSIP_SHOW
    elseif event == "GOSSIP_SHOW" then
        -- Auto turn-in: look for a completable active quest
        if GetAccountSetting("AutoTurnInQuests", false) then
            if not (GetAccountSetting("AutoTurnInHoldShift", true) and IsShiftKeyDown()) then
                local activeQuests = C_GossipInfo.GetActiveQuests()
                for _, questInfo in ipairs(activeQuests) do
                    if questInfo.isComplete then
                        C_GossipInfo.SelectActiveQuest(questInfo.questID)
                        return
                    end
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
