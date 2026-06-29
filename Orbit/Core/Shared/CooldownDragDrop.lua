-- [ COOLDOWN DRAG DROP ] ----------------------------------------------------------------------------
-- pure cursor → (type, id, texture, durations, slot, useSpellId) resolver. no plugin refs / frame creation / saved-data writes.
local _, Orbit = ...

---@class OrbitCooldownDragDrop
Orbit.CooldownDragDrop = {}
local DragDrop = Orbit.CooldownDragDrop

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local EQUIPMENT_SLOTS = { 13, 14 }

-- [ TOOLTIP PARSER ALIASES ] ------------------------------------------------------------------------
local function ParseActiveDuration(itemType, id)
    return Orbit.TooltipParser and Orbit.TooltipParser:ParseActiveDuration(itemType, id)
end

local function ParseCooldownDuration(itemType, id)
    return Orbit.TooltipParser and Orbit.TooltipParser:ParseCooldownDuration(itemType, id)
end

-- [ SPELL OVERRIDE ALIAS ] --------------------------------------------------------------------------
local function GetActiveSpellID(spellID)
    return FindSpellOverrideByID(spellID)
end

-- [ COOLDOWN VALIDATION ] ---------------------------------------------------------------------------
-- issecretvalue-guards on GetSpellBaseCooldown / C_Spell.GetSpellCharges so the comparisons never throw in combat.
function DragDrop:HasCooldown(itemType, id)
    if itemType == "spell" then
        local activeId = GetActiveSpellID(id)
        if Orbit.CooldownData:IsTracked(id) or Orbit.CooldownData:IsTracked(activeId) then return true end
        local cd = GetSpellBaseCooldown(activeId)
        if cd and not issecretvalue(cd) and cd > 0 then return true end
        local ci = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(activeId)
        if ci and ci.maxCharges and not issecretvalue(ci.maxCharges) and ci.maxCharges > 1 then return true end
        return false
    elseif itemType == "item" then
        return GetItemSpell(id) ~= nil
    end
    return false
end

-- [ CURSOR RESOLUTION ] -----------------------------------------------------------------------------
-- Unwraps spellbook subType so the caller always gets a real spellID, never a book-slot index.
function DragDrop:ResolveCursorInfo()
    local cursorType, id, subType, spellID = GetCursorInfo()
    if cursorType == "spell" then
        local actualId = spellID or id
        if not spellID and subType and subType ~= "" then
            local bookInfo = C_SpellBook.GetSpellBookItemInfo(id, Enum.SpellBookSpellBank[subType] or Enum.SpellBookSpellBank.Player)
            if bookInfo and bookInfo.spellID then actualId = bookInfo.spellID end
        end
        return "spell", actualId
    elseif cursorType == "item" then
        return "item", id
    end
    return nil, nil
end

-- Cursor → spellId (nil for non-spell cursors). Same spellbook unwrap as above.
function DragDrop:ResolveSpellFromCursor()
    local cursorType, id, subType, spellID = GetCursorInfo()
    if cursorType ~= "spell" then return nil end
    local actualId = spellID or id
    if subType and subType ~= "" then
        local bookInfo = C_SpellBook.GetSpellBookItemInfo(id, Enum.SpellBookSpellBank[subType] or Enum.SpellBookSpellBank.Player)
        if bookInfo and bookInfo.spellID then actualId = bookInfo.spellID end
    end
    return actualId
end

-- pcall guards HasCooldown — any underlying API can start throwing on a secret-value boundary in a future patch.
function DragDrop:IsDraggingCooldownAbility()
    local itemType, actualId = self:ResolveCursorInfo()
    if not itemType then return false end
    local ok, result = pcall(self.HasCooldown, self, itemType, actualId)
    return ok and result
end

-- [ CHARGE SPELL VALIDATION ] -----------------------------------------------------------------------
-- ci.maxCharges is secret in combat — the boolean test itself would throw without the issecretvalue guard.
function DragDrop:IsChargeSpell(spellId)
    if not spellId then return false, nil end
    local ci = C_Spell.GetSpellCharges(spellId)
    if not ci or issecretvalue(ci.maxCharges) then return false, ci end
    return ci.maxCharges and ci.maxCharges > 1, ci
end

-- [ EQUIPMENT SLOT RESOLUTION ] ---------------------------------------------------------------------
-- ViewerInjection tracks trinkets by slot so the injected icon follows gear swaps automatically.
function DragDrop:ResolveEquipmentSlot(itemId)
    for _, slotId in ipairs(EQUIPMENT_SLOTS) do
        local equippedId = GetInventoryItemID("player", slotId)
        if equippedId and equippedId == itemId then return slotId end
    end
    return nil
end

-- [ CURSOR TEXTURE ] --------------------------------------------------------------------------------
function DragDrop:GetCursorTexture()
    local itemType, id = self:ResolveCursorInfo()
    if not itemType then return nil end
    if itemType == "spell" then
        local info = C_Spell.GetSpellInfo(GetActiveSpellID(id))
        return info and info.iconID
    elseif itemType == "item" then
        return C_Item.GetItemIconByID(id)
    end
    return nil
end

-- [ SAVED-DATA BUILDERS ] ---------------------------------------------------------------------------
-- Captures durations + useSpellId + slotId so the consumer renders without a second API lookup.
function DragDrop:BuildTrackedItemEntry(itemType, itemId, x, y)
    if not (itemType and itemId) then return nil end
    local parseId = (itemType == "spell") and GetActiveSpellID(itemId) or itemId
    local actDur, cdDur
    if itemType == "spell" then
        actDur = Orbit.CooldownData:GetActiveDurationOverride(parseId)
        cdDur = Orbit.CooldownData:GetBaseCooldownSeconds(parseId)
    else
        actDur = ParseActiveDuration(itemType, parseId)
        cdDur = ParseCooldownDuration(itemType, parseId)
    end
    local useSpellId = (itemType == "item") and select(2, GetItemSpell(itemId)) or nil
    local slotId = (itemType == "item") and self:ResolveEquipmentSlot(itemId) or nil
    return {
        type = itemType,
        id = itemId,
        x = x,
        y = y,
        activeDuration = actDur,
        cooldownDuration = cdDur,
        useSpellId = useSpellId,
        slotId = slotId,
        aura = (itemType == "spell") and Orbit.CooldownData:IsAuraCategory(parseId) or nil,
    }
end

-- afterNativeIndex lets the consumer interleave injected frames with native cooldown viewer icons.
function DragDrop:BuildInjectedItemEntry(itemType, itemId, afterNativeIndex)
    if not (itemType and itemId) then return nil end
    local parseId = (itemType == "spell") and GetActiveSpellID(itemId) or itemId
    local useSpellId = (itemType == "item") and select(2, GetItemSpell(itemId)) or nil
    local slotId = (itemType == "item") and self:ResolveEquipmentSlot(itemId) or nil
    local activeDuration
    if itemType == "spell" then
        activeDuration = Orbit.CooldownData:GetActiveDurationOverride(parseId)
    else
        activeDuration = ParseActiveDuration(itemType, parseId)
    end
    return {
        type = itemType,
        id = itemId,
        useSpellId = useSpellId,
        slotId = slotId,
        activeDuration = activeDuration,
        afterNativeIndex = afterNativeIndex or 0,
    }
end

-- maxCharges is spell-only and captured at drop time outside combat (IsChargeSpell's secret check); items use cd-only/active+cd via TooltipParser durations.
function DragDrop:BuildTrackedBarPayload(itemType, id)
    if not (itemType and id) then return nil end
    local parseId = (itemType == "spell") and GetActiveSpellID(id) or id
    local maxCharges
    if itemType == "spell" then
        local _, ci = self:IsChargeSpell(parseId)
        if ci and ci.maxCharges and not issecretvalue(ci.maxCharges) and ci.maxCharges > 1 then
            maxCharges = ci.maxCharges
        end
    end
    local actDur, cdDur
    if itemType == "spell" then
        actDur = Orbit.CooldownData:GetActiveDurationOverride(parseId)
        cdDur = Orbit.CooldownData:GetBaseCooldownSeconds(parseId)
    else
        actDur = ParseActiveDuration(itemType, parseId)
        cdDur = ParseCooldownDuration(itemType, parseId)
    end
    local useSpellId = (itemType == "item") and select(2, GetItemSpell(id)) or nil
    local slotId = (itemType == "item") and self:ResolveEquipmentSlot(id) or nil
    return {
        type = itemType,
        id = id,
        maxCharges = maxCharges,
        activeDuration = actDur,
        cooldownDuration = cdDur,
        useSpellId = useSpellId,
        slotId = slotId,
    }
end
