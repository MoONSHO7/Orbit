-- [ PROFESSIONS SOURCE ]-----------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

local Professions = {
    kind = "professions",
    events = { "TRADE_SKILL_LIST_UPDATE", "SKILL_LINES_CHANGED" },
    persistent = false,
}
Sources.professions = Professions

-- Returns profession trade skill entries (the openable professions themselves, not individual recipes).
-- Clicking casts the profession spell which opens the tradeskill window — the expected Spotlight behaviour.
function Professions:Build()
    local entries = {}
    local lineIDs = C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_TradeSkillUI.GetAllProfessionTradeSkillLines()
    if not lineIDs then return entries end
    for _, lineID in ipairs(lineIDs) do
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(lineID)
        if info and info.professionName and info.professionID and info.professionID > 0 then
            local iconID = C_Spell.GetSpellTexture(info.professionID) or info.icon
            entries[#entries + 1] = {
                kind = "professions",
                id = lineID,
                name = info.professionName,
                lowerName = Tokenize:Fold(info.professionName),
                icon = iconID,
                secure = { type = "spell", spell = info.professionName },
            }
        end
    end
    return entries
end
