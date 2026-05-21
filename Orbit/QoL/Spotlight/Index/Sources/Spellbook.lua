-- [ SPELLBOOK SOURCE ]-------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

local PLAYER_BANK = Enum.SpellBookSpellBank.Player
local PET_BANK = Enum.SpellBookSpellBank.Pet

local Spellbook = {
    kind = "spellbook",
    -- UNIT_PET picks up hunter/warlock pet spellbook once the pet is summoned.
    events = { "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "UNIT_PET" },
    persistent = false,
}
Sources.spellbook = Spellbook

-- Shared by top-level + flyout-slot walks so inner flyout spells (Portals, Summon destinations) appear as searchable rows.
local function AppendSpellEntry(entries, name, spellID, passive)
    if not name or not spellID then return end
    entries[#entries + 1] = {
        kind = "spellbook",
        id = spellID,
        name = name,
        lowerName = Tokenize:Fold(name),
        icon = C_Spell.GetSpellTexture(spellID),
        passive = passive or false,
        secure = { type = "spell", spell = name },
    }
end

-- Flat 1..numPetSpells; only enumerated when HasPetSpells reports a non-zero count.
local function AppendPetSpells(entries)
    if not C_SpellBook.HasPetSpells then return end
    local numPetSpells = C_SpellBook.HasPetSpells()
    if not numPetSpells or numPetSpells <= 0 then return end
    for slot = 1, numPetSpells do
        local info = C_SpellBook.GetSpellBookItemInfo(slot, PET_BANK)
        if info and info.name and info.itemType == Enum.SpellBookItemType.Spell and info.spellID then
            AppendSpellEntry(entries, info.name, info.spellID, info.isPassive)
        end
    end
end

function Spellbook:Build()
    local entries = {}
    local numLines = C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines() or 0

    for lineIdx = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIdx)
        -- shouldHide fences off other specs' trees — never expose non-active-spec abilities.
        if lineInfo and not lineInfo.shouldHide then
            local offset = lineInfo.itemIndexOffset or 0
            local count = lineInfo.numSpellBookItems or 0
            for i = 1, count do
                local slotIndex = offset + i
                local info = C_SpellBook.GetSpellBookItemInfo(slotIndex, PLAYER_BANK)
                -- isOffSpec: individual entries within a visible line that belong to a non-active spec.
                if info and info.name and not info.isOffSpec then
                    if info.itemType == Enum.SpellBookItemType.Spell and info.spellID then
                        AppendSpellEntry(entries, info.name, info.spellID, info.isPassive)
                    elseif info.itemType == Enum.SpellBookItemType.Flyout and info.actionID then
                        -- Flyout contents: each inner spell is an addressable cast target.
                        local _, _, numSlots, isKnown = GetFlyoutInfo(info.actionID)
                        if isKnown and numSlots then
                            for slot = 1, numSlots do
                                local slotSpellID, _, slotKnown, slotName = GetFlyoutSlotInfo(info.actionID, slot)
                                if slotKnown then
                                    AppendSpellEntry(entries, slotName, slotSpellID, false)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    AppendPetSpells(entries)
    return entries
end
