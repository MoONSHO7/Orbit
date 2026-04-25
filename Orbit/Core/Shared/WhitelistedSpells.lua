-- [ WHITELISTED SPELLS ]-----------------------------------------------------------------------------
-- Blizzard-whitelisted spell IDs where aura/cooldown fields are NON-SECRET even in combat.
-- Update this file when Blizzard patches add new whitelisted spells.
-- See UNSECRETED.md in project root for full Blizzard whitelist documentation.
-- No executable logic. Only declarations.
local _, Orbit = ...

---@class OrbitWhitelistedSpells
Orbit.WhitelistedSpells = {}
local W = Orbit.WhitelistedSpells

-- [ CLASS RESOURCE AURAS ]---------------------------------------------------------------------------
-- aura.applications is safe for these spell IDs (used by ResourceBarMixin)
W.CLASS_RESOURCES = {
    [344179]  = "Maelstrom Weapon",       -- Enhancement Shaman
    [205473]  = "Icicles",                -- Frost Mage
    [260286]  = "Tip of the Spear",       -- Survival Hunter
    [1225789] = "Soul Fragments",         -- Vengeance/Havoc Demon Hunter
    [1227702] = "Collapsing Star",        -- Devourer Demon Hunter (void meta)
    [395152]  = "Ebon Might",             -- Augmentation Evoker
    [395296]  = "Ebon Might (alt)",       -- Augmentation Evoker variant
    [124255]  = "Stagger",                -- Brewmaster Monk (UnitStagger is safe)
    [1217607] = "Void Metamorphosis",     -- Devourer Demon Hunter
    [95809]   = "Insanity",               -- Shadow Priest
}

-- [ HEALER HOTS & SHIELDS ]--------------------------------------------------------------------------
-- Full aura data (name, spellId, applications, duration, expirationTime) is non-secret.
-- HealerAuraRegistry.lua also references these; keep in sync.
W.HEALER_AURAS = {
    -- Preservation Evoker
    [364343] = "Echo",
    [355941] = "Dream Breath",
    [366155] = "Reversion",
    [376788] = "Echo Dream Breath",
    [367364] = "Echo Reversion",
    [373267] = "Lifebind",
    [363502] = "Dream Flight",
    -- Augmentation Evoker
    [360827] = "Blistering Scales",
    [395152] = "Ebon Might",             -- Also in W.CLASS_RESOURCES
    [410089] = "Prescience",
    [410263] = "Inferno's Blessing",
    [410686] = "Symbiotic Bloom",
    [413984] = "Shifting Sands",
    -- Restoration Druid
    [774]    = "Rejuvenation",
    [8936]   = "Regrowth",
    [33763]  = "Lifebloom",
    [48438]  = "Wild Growth",
    [155777] = "Germination",
    -- Discipline Priest
    [17]     = "Power Word: Shield",
    [194384] = "Atonement",
    [1253593] = "Void Shield",
    -- Holy Priest
    [139]    = "Renew",
    [41635]  = "Prayer of Mending",
    [77489]  = "Echo of Light",
    -- Mistweaver Monk
    [115175] = "Soothing Mist",
    [119611] = "Renewing Mist",
    [124682] = "Enveloping Mist",
    [450769] = "Aspect of Harmony",
    -- Restoration Shaman
    [974]    = "Earth Shield",
    [383648] = "Earth Shield (alt)",
    [61295]  = "Riptide",
    -- Holy Paladin
    [53563]  = "Beacon of Light",
    [156322] = "Eternal Flame",
    [156910] = "Beacon of Faith",
    [1244893] = "Beacon of the Savior",
}

-- [ RAID BUFFS ]-------------------------------------------------------------------------------------
-- Long-term buffs with non-secret aura data.
W.RAID_BUFFS = {
    [1126]   = "Mark of the Wild",
    [1459]   = "Arcane Intellect",
    [6673]   = "Battle Shout",
    [21562]  = "Power Word: Fortitude",
    [369459] = "Source of Magic",
    [462854] = "Skyfury",
    [474754] = "Symbiotic Relationship",
    [364342] = "Blessing of the Bronze",
}

-- [ BLESSING OF THE BRONZE VARIANTS ]----------------------------------------------------------------
W.BRONZE_VARIANTS = {
    [381732] = "Death Knight",
    [381741] = "Demon Hunter",
    [381746] = "Druid",
    [381748] = "Evoker",
    [381749] = "Hunter",
    [381750] = "Mage",
    [381751] = "Monk",
    [381752] = "Paladin",
    [381753] = "Priest",
    [381754] = "Rogue",
    [381756] = "Shaman",
    [381757] = "Warlock",
    [381758] = "Warrior",
}

-- [ ROGUE POISONS ] ---------------------------------------------------------------------------------
W.ROGUE_POISONS = {
    [2823]   = "Deadly Poison",
    [8679]   = "Wound Poison",
    [3408]   = "Crippling Poison",
    [5761]   = "Numbing Poison",
    [315584] = "Instant Poison",
    [381637] = "Atrophic Poison",
    [381664] = "Amplifying Poison",
}

-- [ SHAMAN IMBUEMENTS ]------------------------------------------------------------------------------
W.SHAMAN_IMBUEMENTS = {
    [319773] = "Windfury Weapon",
    [319778] = "Flametongue Weapon",
    [382021] = "Earthliving Weapon",
    [382022] = "Earthliving Weapon (alt)",
    [457496] = "Tidecaller's Guard",
    [457481] = "Tidecaller's Guard (alt)",
    [462757] = "Thunderstrike Ward",
    [462742] = "Thunderstrike Ward (alt)",
}

-- [ EXHAUSTION / SATED ]-----------------------------------------------------------------------------
W.EXHAUSTION = {
    [57724]  = "Sated",
    [57723]  = "Exhaustion",
    [390435] = "Exhaustion (alt)",
    [80354]  = "Temporal Displacement",
    [264689] = "Fatigued",
}

-- [ SKYRIDING ]--------------------------------------------------------------------------------------
W.SKYRIDING = {
    [425782] = "Second Wind",
    [372608] = "Surge Forward",
    [372610] = "Skyward Ascent",
    [403092] = "Aerial Halt",
    [361584] = "Whirling Surge",
    [418592] = "Lightning Rush",
    [460002] = "Switch Flight Style",
    [377234] = "Thrill of the Skies",
    [388367] = "Ohn'ahra's Gusts",
    [418590] = "Static Charge",
    [369968] = "Skyriding Racing",
}

-- [ COMBAT RESURRECTION ] ---------------------------------------------------------------------------
-- Cooldowns AND charge counts are non-secret for battle res spells.
W.COMBAT_RES = {
    [20484]  = "Rebirth",              -- Druid
    [61999]  = "Raise Ally",           -- Death Knight
    [20707]  = "Soulstone",            -- Warlock
    [391054] = "Intercession",         -- Paladin
    [212051] = "Reawaken",             -- Evoker
    [269586] = "Emergency Soul Link",  -- Engineering
    [221955] = "Convincingly Realistic Jumper Cables", -- TWW Engineering
}

-- [ SYSTEM SPELLS ]----------------------------------------------------------------------------------
W.SYSTEM = {
    [61304] = "GCD Dummy Spell",
    [8690]  = "Hearthstone",
    [20608] = "Reincarnation",
}

-- [ UTILITY / LONG-TERM BUFFS ]----------------------------------------------------------------------
W.UTILITY = {
    [433568] = "Rite of Sanctification",
    [433583] = "Rite of Adjuration",
    [71041]  = "Dungeon Deserter",
    [26013]  = "Deserter",
}

-- [ QUICK LOOKUP TABLE ]-----------------------------------------------------------------------------
-- Merged lookup for fast O(1) checks: W.IsWhitelisted[spellId] == true
W.IsWhitelisted = {}

local function MergeInto(dest, source)
    for id in pairs(source) do dest[id] = true end
end

MergeInto(W.IsWhitelisted, W.CLASS_RESOURCES)
MergeInto(W.IsWhitelisted, W.HEALER_AURAS)
MergeInto(W.IsWhitelisted, W.RAID_BUFFS)
MergeInto(W.IsWhitelisted, W.BRONZE_VARIANTS)
MergeInto(W.IsWhitelisted, W.ROGUE_POISONS)
MergeInto(W.IsWhitelisted, W.SHAMAN_IMBUEMENTS)
MergeInto(W.IsWhitelisted, W.EXHAUSTION)
MergeInto(W.IsWhitelisted, W.SKYRIDING)
MergeInto(W.IsWhitelisted, W.COMBAT_RES)
MergeInto(W.IsWhitelisted, W.SYSTEM)
MergeInto(W.IsWhitelisted, W.UTILITY)

-- [ API ]--------------------------------------------------------------------------------------------
function W:IsSpellWhitelisted(spellId)
    return self.IsWhitelisted[spellId] == true
end

function W:IsClassResource(spellId)
    return self.CLASS_RESOURCES[spellId] ~= nil
end

function W:IsHealerAura(spellId)
    return self.HEALER_AURAS[spellId] ~= nil
end

function W:IsCombatRes(spellId)
    return self.COMBAT_RES[spellId] ~= nil
end
