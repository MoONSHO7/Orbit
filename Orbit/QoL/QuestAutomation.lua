-- [ QUEST AUTOMATION ]-------------------------------------------------------------------------------
-- Handles auto-accept and auto-turn-in of quests.
-- Events are always registered; settings are read at fire-time so no dynamic
-- register/unregister is needed.
local _, Orbit = ...

Orbit.QuestAutomation = {}

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function GetAccountSetting(key, default)
    local v = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings[key]
    if v == nil then
        return default
    end
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
    -- Fired when a single quest-offer dialog is shown (NPC or item pickup).
    if event == "QUEST_DETAIL" then
        if not GetAccountSetting("AutoAcceptQuests", false) then
            return
        end
        AcceptQuest()

    -- ------------------------------------------------------------------ QUEST_COMPLETE
    -- Fired when the quest-complete (turn-in) dialog is shown.
    elseif event == "QUEST_COMPLETE" then
        if not GetAccountSetting("AutoTurnInQuests", false) then
            return
        end
        -- Hold-Shift-to-skip guard
        if GetAccountSetting("AutoTurnInHoldShift", false) and IsShiftKeyDown() then
            return
        end
        -- Never auto-pick when the player must choose a reward
        if GetNumQuestChoices() > 1 then
            return
        end
        CompleteQuest()

    -- ------------------------------------------------------------------ QUEST_AUTOCOMPLETE
    -- Fired for quests that complete in the world (bonus objectives, etc.).
    -- We must open the complete dialog ourselves.
    elseif event == "QUEST_AUTOCOMPLETE" then
        local questID = ...
        if questID then
            pcall(ShowQuestComplete, questID)
        end

    -- ------------------------------------------------------------------ GOSSIP_SHOW
    -- Fired when a gossip NPC dialog opens.  Handle turn-in before accept so
    -- completing quests takes priority over starting new ones.
    elseif event == "GOSSIP_SHOW" then
        -- Auto turn-in: look for a completable active quest
        if GetAccountSetting("AutoTurnInQuests", false) then
            if not (GetAccountSetting("AutoTurnInHoldShift", false) and IsShiftKeyDown()) then
                local activeQuests = C_GossipInfo.GetActiveQuests()
                for _, questInfo in ipairs(activeQuests or {}) do
                    if questInfo.isComplete then
                        C_GossipInfo.SelectActiveQuest(questInfo.questID)
                        return -- Gossip frame will update; stop here
                    end
                end
            end
        end

        -- Auto accept: look for available quests to offer
        if GetAccountSetting("AutoAcceptQuests", false) then
            local availableQuests = C_GossipInfo.GetAvailableQuests()
            if not availableQuests or #availableQuests == 0 then
                return
            end
            -- Prevent-multi guard: skip auto-accept when there are multiple quests
            if GetAccountSetting("AutoAcceptPreventMulti", false) and #availableQuests > 1 then
                return
            end
            -- Select the first (or only) quest — this fires QUEST_DETAIL which
            -- triggers auto-accept above, completing the chain.
            C_GossipInfo.SelectAvailableQuest(availableQuests[1].questID)
        end
    end
end)
