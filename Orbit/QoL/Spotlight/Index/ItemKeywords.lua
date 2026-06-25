-- [ ITEM SEARCH KEYWORDS ]---------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L
local ItemKeywords = {}
Orbit.Spotlight.Index.ItemKeywords = ItemKeywords

local SLOT_SYNONYM = {
    INVTYPE_FINGER = "PLU_SPT_ITEM_RING",
    INVTYPE_NECK   = "PLU_SPT_ITEM_NECK",
    INVTYPE_CLOAK  = "PLU_SPT_ITEM_CLOAK",
}

function ItemKeywords:Build(itemRef)
    local parts = {}
    -- "Items" (client string) so a leading "item" prefix scopes to items, e.g. "item ring".
    if _G.ITEMS then parts[#parts + 1] = _G.ITEMS end
    if not itemRef then return table.concat(parts, " ") end
    local _, _, _, _, _, itemType, itemSubType, _, equipLoc, _, _, _, _, bindType, _, _, isCraftingReagent = GetItemInfo(itemRef)
    if not itemType then return table.concat(parts, " ") end
    parts[#parts + 1] = itemType
    if itemSubType and itemSubType ~= "" and itemSubType ~= itemType then parts[#parts + 1] = itemSubType end
    if equipLoc and equipLoc ~= "" then
        local slotName = _G[equipLoc]
        if slotName and slotName ~= "" then parts[#parts + 1] = slotName end
        local synKey = SLOT_SYNONYM[equipLoc]
        if synKey then parts[#parts + 1] = L[synKey] end
    end
    if isCraftingReagent then parts[#parts + 1] = L.PLU_SPT_ITEM_REAGENT end
    if bindType == 7 or bindType == 8 or bindType == 9 then
        parts[#parts + 1] = L.PLU_SPT_ITEM_WARBOUND
        local accountStr = _G.ITEM_ACCOUNTBOUND
        if accountStr and accountStr ~= "" then parts[#parts + 1] = accountStr end
    elseif bindType == 2 then
        local boe = _G.ITEM_BIND_ON_EQUIP
        if boe and boe ~= "" then parts[#parts + 1] = boe end
    end
    return table.concat(parts, " ")
end
