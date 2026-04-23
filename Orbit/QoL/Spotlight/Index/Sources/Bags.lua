-- [ BAGS SOURCE ]-----------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

-- Covers slots 0..5: backpack (0), four main bags (1-4), and the reagent bag (5).
local NUM_BAGS = 6

local Bags = {
    kind = "bags",
    events = { "BAG_UPDATE_DELAYED" },
    persistent = false,
}
Sources.bags = Bags

function Bags:Build()
    local entries = {}
    local seen = {}
    for bag = 0, NUM_BAGS - 1 do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and info.hyperlink and not seen[info.itemID] then
                seen[info.itemID] = true
                local name, _, quality = GetItemInfo(info.hyperlink)
                name = name or info.hyperlink
                entries[#entries + 1] = {
                    kind = "bags",
                    id = info.itemID,
                    name = name,
                    lowerName = Tokenize:Fold(name),
                    icon = info.iconFileID,
                    count = GetItemCount(info.itemID),
                    quality = quality,
                    secure = { type = "item", item = info.hyperlink },
                }
            end
        end
    end
    return entries
end
