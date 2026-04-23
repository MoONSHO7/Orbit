---@type Orbit
local Orbit = Orbit

-- [ PENDING XP SCANNER ]----------------------------------------------------------------------------
-- Scans the quest log and sums XP rewards for quests that are ready to hand in (objectives complete).
-- Rendered as a secondary fill on the XP bar so users see how close they are to "can ding now".

Orbit.StatusBarPendingXP = {}
local PendingXP = Orbit.StatusBarPendingXP

function PendingXP:Sum()
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then return 0 end
    local total = 0
    local numEntries = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and C_QuestLog.IsComplete(info.questID) then
            local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(info.questID) or 0
            if type(xp) == "number" and xp > 0 then
                total = total + xp
            end
        end
    end
    return total
end

-- Sum of XP for ALL quests in the log (ready or not) — for "quests-to-level" estimation.
function PendingXP:SumAll()
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then return 0, 0 end
    local total, count = 0, 0
    local numEntries = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(info.questID) or 0
            if type(xp) == "number" and xp > 0 then
                total = total + xp
                count = count + 1
            end
        end
    end
    return total, count
end
