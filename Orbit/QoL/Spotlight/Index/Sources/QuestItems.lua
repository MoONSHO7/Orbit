-- [ QUEST ITEMS SOURCE ]----------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

local QuestItems = {
    kind = "questitems",
    events = { "QUEST_LOG_UPDATE" },
    persistent = false,
}
Sources.questitems = QuestItems

function QuestItems:Build()
    local entries = {}
    local count = C_QuestLog.GetNumQuestLogEntries() or 0
    local seen = {}
    for i = 1, count do
        local link, icon, charges, showWhenComplete = GetQuestLogSpecialItemInfo(i)
        if link and icon and not seen[link] then
            seen[link] = true
            local name = GetItemInfo(link) or link
            entries[#entries + 1] = {
                kind = "questitems",
                id = link,
                name = name,
                lowerName = Tokenize:Fold(name),
                icon = icon,
                count = charges,
                secure = { type = "item", item = link },
            }
        end
    end
    return entries
end
