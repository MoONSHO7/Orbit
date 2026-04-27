-- [ HEIRLOOMS SOURCE ]-------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

local Heirlooms = {
    kind = "heirlooms",
    events = { "HEIRLOOMS_UPDATED" },
    persistent = true,
}
Sources.heirlooms = Heirlooms

function Heirlooms:signature()
    local ids = C_Heirloom.GetHeirloomItemIDs()
    return ids and #ids or 0
end

function Heirlooms:Build()
    local entries = {}
    local ids = C_Heirloom.GetHeirloomItemIDs()
    if not ids then return entries end
    for _, itemID in ipairs(ids) do
        if C_Heirloom.PlayerHasHeirloom(itemID) then
            local name, icon = C_Heirloom.GetHeirloomInfo(itemID)
            if name then
                entries[#entries + 1] = {
                    kind = "heirlooms",
                    id = itemID,
                    name = name,
                    lowerName = Tokenize:Fold(name),
                    icon = icon,
                    quality = Enum.ItemQuality.Heirloom,
                    secure = { type = "item", item = tostring(itemID) },
                }
            end
        end
    end
    return entries
end
