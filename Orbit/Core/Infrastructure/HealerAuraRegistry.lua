-- [ HEALER AURA REGISTRY ]-------------------------------------------------------------------------
-- Slot-based spell-ID mapping for healer buffs/HoTs and raid buffs.
-- 7 shared slots (HealerAura1-7) + RaidBuff. Each slot maps to a different spell per spec.
local _, Orbit = ...

Orbit.HealerAuraRegistry = {}
local Registry = Orbit.HealerAuraRegistry
local _, playerClass = UnitClass("player")

-- [ MAX SLOTS ]-------------------------------------------------------------------------------------
local MAX_HEALER_SLOTS = 7

-- [ SPEC SPELL DATA ]-------------------------------------------------------------------------------
local SPEC_SPELLS = {
    [1468] = { -- Preservation Evoker
        { spellId = 364343, label = "Echo" },
        { spellId = 355941, label = "Dream Breath" },
        { spellId = 366155, label = "Reversion" },
        { spellId = 376788, label = "Echo Dream Breath" },
        { spellId = 367364, label = "Echo Reversion" },
        { spellId = 373267, label = "Lifebind" },
        { spellId = 363502, label = "Dream Flight" },
    },
    [1473] = { -- Augmentation Evoker
        { spellId = 360827, label = "Blistering Scales" },
        { spellId = 395152, label = "Ebon Might" },
        { spellId = 410089, label = "Prescience" },
        { spellId = 410263, label = "Inferno's Blessing" },
        { spellId = 410686, label = "Symbiotic Bloom" },
        { spellId = 413984, label = "Shifting Sands" },
    },
    [105]  = { -- Resto Druid
        { spellId = 33763,  label = "Lifebloom" },
        { spellId = 774,    label = "Rejuvenation" },
        { spellId = 155777, label = "Germination" },
        { spellId = 8936,   label = "Regrowth" },
        { spellId = 48438,  label = "Wild Growth" },
    },
    [256]  = { -- Disc Priest
        { spellId = 194384,  label = "Atonement" },
        { spellId = 17,      label = "Power Word: Shield" },
        { spellId = 1253593, label = "Void Shield" },
    },
    [257]  = { -- Holy Priest
        { spellId = 41635, label = "Prayer of Mending" },
        { spellId = 139,   label = "Renew" },
        { spellId = 77489, label = "Echo of Light" },
    },
    [270]  = { -- Mistweaver Monk
        { spellId = 115175, label = "Soothing Mist" },
        { spellId = 119611, label = "Renewing Mist" },
        { spellId = 124682, label = "Enveloping Mist" },
        { spellId = 450769, label = "Aspect of Harmony" },
    },
    [264]  = { -- Restoration Shaman
        { spellId = 974,   label = "Earth Shield", altSpellId = 383648 },
        { spellId = 61295, label = "Riptide" },
    },
    [65]   = { -- Holy Paladin
        { spellId = 53563,   label = "Beacon of Light" },
        { spellId = 156322,  label = "Eternal Flame" },
        { spellId = 156910,  label = "Beacon of Faith" },
        { spellId = 1244893, label = "Beacon of the Savior" },
    },
}

-- [ RAID BUFF DATA ]--------------------------------------------------------------------------------
local RAID_BUFFS = {
    { spellId = 1126,   label = "Mark of the Wild",        classFilter = "DRUID" },
    { spellId = 1459,   label = "Arcane Intellect",       classFilter = "MAGE" },
    { spellId = 6673,   label = "Battle Shout",           classFilter = "WARRIOR" },
    { spellId = 21562,  label = "Power Word: Fortitude",  classFilter = "PRIEST" },
    { spellId = 369459, label = "Source of Magic",        classFilter = "EVOKER" },
    { spellId = 462854, label = "Skyfury",                classFilter = "SHAMAN" },
    { spellId = 474754, label = "Symbiotic Relationship", classFilter = "EVOKER" },
}

-- Lookup of ALL raid buff spell IDs (all classes) for presence checking
local ALL_RAID_BUFF_IDS = {}
for _, buff in ipairs(RAID_BUFFS) do ALL_RAID_BUFF_IDS[buff.spellId] = true end

-- [ SLOT KEY GENERATION ]---------------------------------------------------------------------------
local SLOT_KEYS = {}
for i = 1, MAX_HEALER_SLOTS do SLOT_KEYS[i] = "HealerAura" .. i end
local RAID_BUFF_KEY = "RaidBuff"

-- [ CACHES (built once at load) ]-------------------------------------------------------------------
local _activeSlots = {}    -- { { key, spellId, label, altSpellId }, ... }
local _activeRaidBuffs = {} -- { { key = "RaidBuff", spellId, label }, ... }
local _activeKeys = {}     -- { "HealerAura1", ..., "RaidBuff" }
local _allSlotKeys = {}    -- all 7 + RaidBuff (for DisabledComponents)

-- Build all slot keys (for DisabledComponents defaults)
for i = 1, MAX_HEALER_SLOTS do _allSlotKeys[#_allSlotKeys + 1] = SLOT_KEYS[i] end
_allSlotKeys[#_allSlotKeys + 1] = RAID_BUFF_KEY

-- Resolve active spec at load time
local function BuildCaches()
    local specIndex = GetSpecialization and GetSpecialization() or 0
    local specId = GetSpecializationInfo and specIndex and specIndex > 0 and GetSpecializationInfo(specIndex)
    local spells = specId and SPEC_SPELLS[specId]
    _activeSlots = {}
    _activeRaidBuffs = {}
    _activeKeys = {}
    if spells then
        for i, spell in ipairs(spells) do
            if i > MAX_HEALER_SLOTS then break end
            local slot = { key = SLOT_KEYS[i], spellId = spell.spellId, label = spell.label, altSpellId = spell.altSpellId }
            _activeSlots[i] = slot
            _activeKeys[#_activeKeys + 1] = slot.key
        end
    end
    for _, buff in ipairs(RAID_BUFFS) do
        if buff.classFilter == playerClass then
            _activeRaidBuffs[#_activeRaidBuffs + 1] = { spellId = buff.spellId, label = buff.label }
        end
    end
    if #_activeRaidBuffs > 0 then _activeKeys[#_activeKeys + 1] = RAID_BUFF_KEY end
end
BuildCaches()

local rebuildFrame = CreateFrame("Frame")
rebuildFrame:RegisterEvent("PLAYER_LOGIN")
rebuildFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
rebuildFrame:SetScript("OnEvent", BuildCaches)

function Registry:Rebuild() BuildCaches() end

-- [ PUBLIC API ]------------------------------------------------------------------------------------
function Registry:ActiveSlots() return _activeSlots end
function Registry:ActiveRaidBuffs() return _activeRaidBuffs end
function Registry:ActiveKeys() return _activeKeys end
function Registry:AllSlotKeys() return _allSlotKeys end
function Registry:SlotCount() return #_activeSlots end

function Registry:GetSlotLabel(key)
    for _, slot in ipairs(_activeSlots) do
        if slot.key == key then return slot.label end
    end
    if key == RAID_BUFF_KEY and _activeRaidBuffs[1] then return "Raid Buff" end
    return key
end

-- Expose raw data for filter/exclusion building
Registry.RaidBuffs = RAID_BUFFS
Registry.AllRaidBuffIds = ALL_RAID_BUFF_IDS
Registry.SLOT_KEYS = SLOT_KEYS
Registry.RAID_BUFF_KEY = RAID_BUFF_KEY
