-- [ EQUIPPED SOURCE ]-------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

local FIRST_SLOT = 1
local LAST_SLOT = 19

local Equipped = {
    kind = "equipped",
    events = { "PLAYER_EQUIPMENT_CHANGED" },
    persistent = false,
}
Sources.equipped = Equipped

function Equipped:Build()
    local entries = {}
    for slot = FIRST_SLOT, LAST_SLOT do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local name, _, quality, _, _, _, _, _, _, iconPath = GetItemInfo(link)
            if name then
                entries[#entries + 1] = {
                    kind = "equipped",
                    id = GetInventoryItemID("player", slot) or slot,
                    name = name,
                    lowerName = Tokenize:Fold(name),
                    icon = iconPath or GetInventoryItemTexture("player", slot),
                    quality = quality,
                    secure = { type = "item", item = link },
                }
            end
        end
    end
    return entries
end
