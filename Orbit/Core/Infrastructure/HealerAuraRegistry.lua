-- [ HEALER AURA REGISTRY ]-------------------------------------------------------------------------
-- Slot-based spell-ID mapping for healer buffs/HoTs and raid buffs.
-- 7 shared slots (HealerAura1-7) + RaidBuff. Each slot maps to a different spell per spec.
local _, Orbit = ...

Orbit.HealerAuraRegistry = {}
local Registry = Orbit.HealerAuraRegistry
local _, playerClass = UnitClass("player")

-- [ MAX SLOTS ]-------------------------------------------------------------------------------------
local MAX_HEALER_SLOTS = 7

-- [ SPEC SPELL DATA (sorted by spellId ascending) ]------------------------------------------------
local SPEC_SPELLS = {
    [65]   = { -- Holy Paladin
        { spellId = 53563,   label = "Beacon of Light" },
        { spellId = 156322,  label = "Eternal Flame" },
        { spellId = 156910,  label = "Beacon of Faith" },
        { spellId = 1244893, label = "Beacon of the Savior" },
    },
    [105]  = { -- Resto Druid
        { spellId = 774,    label = "Rejuvenation" },
        { spellId = 8936,   label = "Regrowth" },
        { spellId = 33763,  label = "Lifebloom" },
        { spellId = 48438,  label = "Wild Growth" },
        { spellId = 155777, label = "Germination" },
    },
    [256]  = { -- Disc Priest
        { spellId = 17,      label = "Power Word: Shield" },
        { spellId = 194384,  label = "Atonement" },
        { spellId = 1253593, label = "Void Shield" },
    },
    [257]  = { -- Holy Priest
        { spellId = 139,   label = "Renew" },
        { spellId = 41635, label = "Prayer of Mending" },
        { spellId = 77489, label = "Echo of Light" },
    },
    [264]  = { -- Restoration Shaman
        { spellId = 974,   label = "Earth Shield", altSpellId = 383648 },
        { spellId = 61295, label = "Riptide" },
    },
    [270]  = { -- Mistweaver Monk
        { spellId = 115175, label = "Soothing Mist" },
        { spellId = 119611, label = "Renewing Mist" },
        { spellId = 124682, label = "Enveloping Mist" },
        { spellId = 450769, label = "Aspect of Harmony" },
    },
    [1468] = { -- Preservation Evoker
        { spellId = 355941, label = "Dream Breath" },
        { spellId = 363502, label = "Dream Flight" },
        { spellId = 364343, label = "Echo" },
        { spellId = 366155, label = "Reversion" },
        { spellId = 367364, label = "Echo Reversion" },
        { spellId = 373267, label = "Lifebind" },
        { spellId = 376788, label = "Echo Dream Breath" },
    },
    [1473] = { -- Augmentation Evoker
        { spellId = 360827, label = "Blistering Scales" },
        { spellId = 395152, label = "Ebon Might" },
        { spellId = 410089, label = "Prescience" },
        { spellId = 410263, label = "Inferno's Blessing" },
        { spellId = 410686, label = "Symbiotic Bloom" },
        { spellId = 413984, label = "Shifting Sands" },
    },
}

-- [ RAID BUFF DATA ]--------------------------------------------------------------------------------
local RAID_BUFFS = {
    { spellId = 1459,   label = "Arcane Intellect",       classFilter = "MAGE" },
    { spellId = 6673,   label = "Battle Shout",           classFilter = "WARRIOR" },
    { spellId = 21562,  label = "Power Word: Fortitude",  classFilter = "PRIEST" },
    { spellId = 369459, label = "Source of Magic",        classFilter = "EVOKER" },
    { spellId = 462854, label = "Skyfury",                classFilter = "SHAMAN" },
    { spellId = 474754, label = "Symbiotic Relationship", classFilter = "EVOKER" },
}

-- [ SLOT KEY GENERATION ]---------------------------------------------------------------------------
local SLOT_KEYS = {}
for i = 1, MAX_HEALER_SLOTS do SLOT_KEYS[i] = "HealerAura" .. i end
local RAID_BUFF_KEY = "RaidBuff"

-- [ CACHES (built once at load) ]-------------------------------------------------------------------
local _activeSlots = {}    -- { { key, spellId, label, altSpellId }, ... }
local _activeRaidBuffs = {} -- { { key = "RaidBuff", spellId, label }, ... }
local _activeKeys = {}     -- { "HealerAura1", ..., "RaidBuff" }
local _allSlotKeys = {}    -- all 7 + RaidBuff (for DisabledComponents)
local _excludedSpellIds = {} -- set of all active spell IDs for filter exclusion

-- Build all slot keys (for DisabledComponents defaults)
for i = 1, MAX_HEALER_SLOTS do _allSlotKeys[#_allSlotKeys + 1] = SLOT_KEYS[i] end
_allSlotKeys[#_allSlotKeys + 1] = RAID_BUFF_KEY

-- Resolve active spec at load time
local function BuildCaches()
    local specId = GetSpecializationInfo and GetSpecializationInfo(GetSpecialization() or 0)
    local spells = specId and SPEC_SPELLS[specId]
    _activeSlots = {}
    _activeRaidBuffs = {}
    _activeKeys = {}
    _excludedSpellIds = {}
    if spells then
        for i, spell in ipairs(spells) do
            if i > MAX_HEALER_SLOTS then break end
            local slot = { key = SLOT_KEYS[i], spellId = spell.spellId, label = spell.label, altSpellId = spell.altSpellId }
            _activeSlots[i] = slot
            _activeKeys[#_activeKeys + 1] = slot.key
            _excludedSpellIds[spell.spellId] = true
            if spell.altSpellId then _excludedSpellIds[spell.altSpellId] = true end
        end
    end
    for _, buff in ipairs(RAID_BUFFS) do
        if buff.classFilter == playerClass then
            _activeRaidBuffs[#_activeRaidBuffs + 1] = { spellId = buff.spellId, label = buff.label }
            _excludedSpellIds[buff.spellId] = true
        end
    end
    if #_activeRaidBuffs > 0 then _activeKeys[#_activeKeys + 1] = RAID_BUFF_KEY end
end
BuildCaches()

-- [ PUBLIC API ]------------------------------------------------------------------------------------
function Registry:ActiveSlots() return _activeSlots end
function Registry:ActiveRaidBuffs() return _activeRaidBuffs end
function Registry:ActiveKeys() return _activeKeys end
function Registry:AllSlotKeys() return _allSlotKeys end
function Registry:SlotCount() return #_activeSlots end
function Registry:ExcludedSpellIds() return _excludedSpellIds end

function Registry:GetSlotLabel(key)
    for _, slot in ipairs(_activeSlots) do
        if slot.key == key then return slot.label end
    end
    if key == RAID_BUFF_KEY and _activeRaidBuffs[1] then return "Raid Buff" end
    return key
end

-- Expose raw data for filter/exclusion building
Registry.RaidBuffs = RAID_BUFFS
Registry.SLOT_KEYS = SLOT_KEYS
Registry.RAID_BUFF_KEY = RAID_BUFF_KEY
