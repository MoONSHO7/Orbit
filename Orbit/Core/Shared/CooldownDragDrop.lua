-- [ COOLDOWN DRAG DROP ] ----------------------------------------------------------------------------
-- Pure helpers for resolving a cursor payload (spell/item) into a validated
-- cooldown ability. Consumed by any plugin that accepts drag-and-drop of
-- cooldown-bearing spells or items — currently CooldownManager/ViewerInjection
-- and (future) the redesigned Tracked plugin. No plugin references, no frame
-- creation, no saved-data writes — just cursor → validated (type, id) and the
-- metadata a consumer needs to build an entry (texture, active/cooldown
-- durations, equipment slot, useSpellId).
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
-- True when the given spell/item has any form of cooldown, charge system, or
-- tooltip-declared duration. Guards secret-value boundaries on
-- GetSpellBaseCooldown and C_Spell.GetSpellCharges so the comparison/boolean
-- test never throws in combat.
function DragDrop:HasCooldown(itemType, id)
    if itemType == "spell" then
        local activeId = GetActiveSpellID(id)
        local cd = GetSpellBaseCooldown(activeId)
        if cd and not issecretvalue(cd) and cd > 0 then return true end
        local ci = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(activeId)
        if ci and ci.maxCharges and not issecretvalue(ci.maxCharges) and ci.maxCharges > 1 then return true end
        return ParseCooldownDuration("spell", activeId) ~= nil
    elseif itemType == "item" then
        if ParseCooldownDuration("item", id) ~= nil then return true end
        return GetItemSpell(id) ~= nil
    end
    return false
end

-- [ CURSOR RESOLUTION ] -----------------------------------------------------------------------------
-- Cursor → (itemType, actualId). Unwraps spellbook subType for book-slot spells
-- so the caller always gets a real spellID, never a book-slot index.
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

-- True when the cursor currently holds a spell/item with a cooldown or charge
-- system. pcall wraps HasCooldown because any of the underlying API calls can
-- throw on a secret-value boundary if a new API version starts returning one.
function DragDrop:IsDraggingCooldownAbility()
    local itemType, actualId = self:ResolveCursorInfo()
    if not itemType then return false end
    local ok, result = pcall(self.HasCooldown, self, itemType, actualId)
    return ok and result
end

-- [ CHARGE SPELL VALIDATION ] -----------------------------------------------------------------------
-- Returns (isChargeSpell, chargeInfo). ci.maxCharges is secret in combat so the
-- check must be guarded or the boolean test itself would throw.
function DragDrop:IsChargeSpell(spellId)
    if not spellId then return false, nil end
    local ci = C_Spell.GetSpellCharges(spellId)
    if not ci or issecretvalue(ci.maxCharges) then return false, ci end
    return ci.maxCharges and ci.maxCharges > 1, ci
end

-- [ EQUIPMENT SLOT RESOLUTION ] ---------------------------------------------------------------------
-- Returns the inventory slot id (13 or 14) if the item is currently equipped
-- in a trinket slot, otherwise nil. Used by ViewerInjection to track trinkets
-- by slot so the injected icon follows gear swaps automatically.
function DragDrop:ResolveEquipmentSlot(itemId)
    for _, slotId in ipairs(EQUIPMENT_SLOTS) do
        local equippedId = GetInventoryItemID("player", slotId)
        if equippedId and equippedId == itemId then return slotId end
    end
    return nil
end

-- [ CURSOR TEXTURE ] --------------------------------------------------------------------------------
-- Resolves the cursor's current payload to an icon textureID. Returns nil when
-- the cursor is empty or holding a non-spell/item payload.
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
-- Build the per-slot entry stored under a `TrackedItems[key]` table. Captures
-- active duration, cooldown duration, useSpellId (items only), and equipment
-- slotId so a consumer can render the icon and timer without a second API
-- lookup.
function DragDrop:BuildTrackedItemEntry(itemType, itemId, x, y)
    if not (itemType and itemId) then return nil end
    local parseId = (itemType == "spell") and GetActiveSpellID(itemId) or itemId
    local actDur = ParseActiveDuration(itemType, parseId)
    local cdDur = ParseCooldownDuration(itemType, parseId)
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
    }
end

-- Build the per-viewer entry stored under `InjectedItems`. Captures the
-- insertion-order metadata (afterNativeIndex) that the consumer uses to
-- interleave injected frames with the native cooldown viewer icons.
function DragDrop:BuildInjectedItemEntry(itemType, itemId, afterNativeIndex)
    if not (itemType and itemId) then return nil end
    local parseId = (itemType == "spell") and GetActiveSpellID(itemId) or itemId
    local useSpellId = (itemType == "item") and select(2, GetItemSpell(itemId)) or nil
    local slotId = (itemType == "item") and self:ResolveEquipmentSlot(itemId) or nil
    local activeDuration = ParseActiveDuration(itemType, parseId)
    return {
        type = itemType,
        id = itemId,
        useSpellId = useSpellId,
        slotId = slotId,
        activeDuration = activeDuration,
        afterNativeIndex = afterNativeIndex or 0,
    }
end

-- Build the payload stored on a TrackedBar record. Captures everything the bar
-- needs to pick a render mode (charges / active+cd / cd-only) and drive it
-- without a second API or tooltip lookup. maxCharges is spell-only and is
-- captured at drop time outside combat (the boundary is guarded by
-- IsChargeSpell's secret check). Items don't get a maxCharges field — per
-- product decision, charges mode is for spells/abilities only; items render
-- as cd-only or active+cd via TooltipParser durations.
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
    local useSpellId = (itemType == "item") and select(2, GetItemSpell(id)) or nil
    local slotId = (itemType == "item") and self:ResolveEquipmentSlot(id) or nil
    return {
        type = itemType,
        id = id,
        maxCharges = maxCharges,
        activeDuration = ParseActiveDuration(itemType, parseId),
        cooldownDuration = ParseCooldownDuration(itemType, parseId),
        useSpellId = useSpellId,
        slotId = slotId,
    }
end
