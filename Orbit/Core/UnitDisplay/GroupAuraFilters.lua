-- [ GROUP AURA FILTERS ]----------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit

-- Shared post-filter factories for Party and Raid frames.
-- Eliminates duplication between PartyFrame.lua and RaidFrame.lua aura filtering.

Orbit.GroupAuraFilters = {}

local HealerReg = Orbit.HealerAuraRegistry
local IsSecret = issecretvalue

-- Raid buffs always excluded from buff containers (long-term, low-value clutter).
local ALWAYS_EXCLUDED = {}
for _, entry in ipairs(HealerReg.RaidBuffs) do ALWAYS_EXCLUDED[entry.spellId] = true end
Orbit.GroupAuraFilters.AlwaysExcluded = ALWAYS_EXCLUDED
-- Raid buffs (explicit, all classes)
ALWAYS_EXCLUDED[1126] = true   -- Mark of the Wild
ALWAYS_EXCLUDED[1459] = true   -- Arcane Intellect
ALWAYS_EXCLUDED[6673] = true   -- Battle Shout
ALWAYS_EXCLUDED[21562] = true  -- Power Word: Fortitude
ALWAYS_EXCLUDED[369459] = true -- Source of Magic
ALWAYS_EXCLUDED[462854] = true -- Skyfury
ALWAYS_EXCLUDED[474754] = true -- Symbiotic Relationship

-- Class mechanics
ALWAYS_EXCLUDED[395152] = true -- Ebon Might
ALWAYS_EXCLUDED[395296] = true -- Ebon Might (alt)
ALWAYS_EXCLUDED[1217607] = true -- Void Metamorphosis
ALWAYS_EXCLUDED[260286] = true -- Tip of the Spear
ALWAYS_EXCLUDED[205473] = true -- Icicles
ALWAYS_EXCLUDED[124255] = true -- Stagger
ALWAYS_EXCLUDED[344179] = true -- Maelstrom Weapon
ALWAYS_EXCLUDED[95809] = true -- Insanity
ALWAYS_EXCLUDED[425782] = true -- Second Wind
-- Poisons
ALWAYS_EXCLUDED[381637] = true -- Atrophic Poison
ALWAYS_EXCLUDED[5761] = true -- Numbing Poison
ALWAYS_EXCLUDED[8679] = true -- Wound Poison
ALWAYS_EXCLUDED[2823] = true -- Deadly Poison
ALWAYS_EXCLUDED[3408] = true -- Crippling Poison
ALWAYS_EXCLUDED[315584] = true -- Instant Poison
ALWAYS_EXCLUDED[381664] = true -- Amplifying Poison
-- Exhaustion / Sated
ALWAYS_EXCLUDED[57724] = true -- Sated
ALWAYS_EXCLUDED[57723] = true -- Exhaustion
ALWAYS_EXCLUDED[390435] = true -- Exhaustion (alt)
ALWAYS_EXCLUDED[80354] = true -- Temporal Displacement
ALWAYS_EXCLUDED[264689] = true -- Fatigued
-- Deserter
ALWAYS_EXCLUDED[71041] = true -- Dungeon Deserter
ALWAYS_EXCLUDED[26013] = true -- Deserter
-- Flight / Dragonriding
ALWAYS_EXCLUDED[404468] = true -- Flight Style: Steady
ALWAYS_EXCLUDED[404464] = true -- Flight Style: Skyriding
ALWAYS_EXCLUDED[460002] = true -- Switch Flight Style
ALWAYS_EXCLUDED[460003] = true -- Switch Flight Style (alt)
ALWAYS_EXCLUDED[377234] = true -- Thrill of the Skies
ALWAYS_EXCLUDED[361584] = true -- Whirling Surge
ALWAYS_EXCLUDED[372608] = true -- Surge Forward
ALWAYS_EXCLUDED[372610] = true -- Skyward Ascent
ALWAYS_EXCLUDED[403092] = true -- Aerial Halt
ALWAYS_EXCLUDED[388367] = true -- Ohn'ahra's Gusts
-- Ride Along
ALWAYS_EXCLUDED[447959] = true -- Ride Along - Enabled
ALWAYS_EXCLUDED[447960] = true -- Ride Along - Inactive
-- Misc utility
ALWAYS_EXCLUDED[8690] = true -- Hearthstone
ALWAYS_EXCLUDED[20608] = true -- Reincarnation
-- Long-term self buffs
ALWAYS_EXCLUDED[433568] = true -- Rite of Sanctification
ALWAYS_EXCLUDED[433583] = true -- Rite of Adjuration
-- Shaman imbuements
ALWAYS_EXCLUDED[319773] = true -- Windfury Weapon
ALWAYS_EXCLUDED[319778] = true -- Flametongue Weapon
ALWAYS_EXCLUDED[382021] = true -- Earthliving Weapon
ALWAYS_EXCLUDED[382022] = true -- Earthliving Weapon (alt)
ALWAYS_EXCLUDED[457496] = true -- Tidecaller's Guard
ALWAYS_EXCLUDED[457481] = true -- Tidecaller's Guard (alt)
ALWAYS_EXCLUDED[462757] = true -- Thunderstrike Ward
ALWAYS_EXCLUDED[462742] = true -- Thunderstrike Ward (alt)
-- Blessing of the Bronze
ALWAYS_EXCLUDED[381732] = true -- Death Knight
ALWAYS_EXCLUDED[381741] = true -- Demon Hunter
ALWAYS_EXCLUDED[381746] = true -- Druid
ALWAYS_EXCLUDED[381748] = true -- Evoker
ALWAYS_EXCLUDED[381749] = true -- Hunter
ALWAYS_EXCLUDED[381750] = true -- Mage
ALWAYS_EXCLUDED[381751] = true -- Monk
ALWAYS_EXCLUDED[381752] = true -- Paladin
ALWAYS_EXCLUDED[381753] = true -- Priest
ALWAYS_EXCLUDED[381754] = true -- Rogue
ALWAYS_EXCLUDED[381756] = true -- Shaman
ALWAYS_EXCLUDED[381757] = true -- Warlock
ALWAYS_EXCLUDED[381758] = true -- Warrior
-- Dungeon paths
ALWAYS_EXCLUDED[131206] = true -- Path of the Shado-Pan
ALWAYS_EXCLUDED[131222] = true -- Path of the Mogu King
ALWAYS_EXCLUDED[131225] = true -- Path of the Setting Sun
ALWAYS_EXCLUDED[445444] = true -- Path of the Light's Reverence
ALWAYS_EXCLUDED[159899] = true -- Path of the Crescent Moon
ALWAYS_EXCLUDED[131228] = true -- Path of the Black Ox
ALWAYS_EXCLUDED[159897] = true -- Path of the Vigilant
ALWAYS_EXCLUDED[131205] = true -- Path of the Stout Brew
ALWAYS_EXCLUDED[131232] = true -- Path of the Necromancer
ALWAYS_EXCLUDED[131229] = true -- Path of the Scarlet Mitre
ALWAYS_EXCLUDED[159896] = true -- Path of the Iron Prow
ALWAYS_EXCLUDED[131231] = true -- Path of the Scarlet Blade
ALWAYS_EXCLUDED[373262] = true -- Path of the Fallen Guardian
ALWAYS_EXCLUDED[131204] = true -- Path of the Jade Serpent
ALWAYS_EXCLUDED[159898] = true -- Path of the Skies
ALWAYS_EXCLUDED[354462] = true -- Path of the Courageous
ALWAYS_EXCLUDED[354466] = true -- Path of the Ascendant
ALWAYS_EXCLUDED[393267] = true -- Path of the Rotting Woods
ALWAYS_EXCLUDED[1254563] = true -- Path of the Fractured Core
ALWAYS_EXCLUDED[354463] = true -- Path of the Plagued
ALWAYS_EXCLUDED[373274] = true -- Path of the Scrappy Prince
ALWAYS_EXCLUDED[159900] = true -- Path of the Dark Rail
ALWAYS_EXCLUDED[354469] = true -- Path of the Stone Warden
ALWAYS_EXCLUDED[159901] = true -- Path of the Verdant
ALWAYS_EXCLUDED[354464] = true -- Path of the Misty Forest
ALWAYS_EXCLUDED[354467] = true -- Path of the Undefeated
ALWAYS_EXCLUDED[393279] = true -- Path of Arcane Secrets
ALWAYS_EXCLUDED[367416] = true -- Path of the Streetwise Merchant
ALWAYS_EXCLUDED[393276] = true -- Path of the Obsidian Hoard
ALWAYS_EXCLUDED[1237215] = true -- Path of the Eco-Dome
ALWAYS_EXCLUDED[445416] = true -- Path of Nerubian Ascension
ALWAYS_EXCLUDED[159895] = true -- Path of the Bloodmaul
ALWAYS_EXCLUDED[159902] = true -- Path of the Burning Mountain
ALWAYS_EXCLUDED[393273] = true -- Path of the Draconic Diploma
ALWAYS_EXCLUDED[410071] = true -- Path of the Freebooter
ALWAYS_EXCLUDED[410074] = true -- Path of Festering Rot
ALWAYS_EXCLUDED[354468] = true -- Path of the Scheming Loa
ALWAYS_EXCLUDED[393256] = true -- Path of the Clutch Defender
ALWAYS_EXCLUDED[393764] = true -- Path of Proven Worth
ALWAYS_EXCLUDED[410078] = true -- Path of the Earth-Warder
ALWAYS_EXCLUDED[467553] = true -- Path of the Azerite Refinery
ALWAYS_EXCLUDED[1254400] = true -- Path of the Windrunners
ALWAYS_EXCLUDED[354465] = true -- Path of the Sinful Soul
ALWAYS_EXCLUDED[393262] = true -- Path of the Windswept Plains
ALWAYS_EXCLUDED[445418] = true -- Path of the Besieged Harbor
ALWAYS_EXCLUDED[1254559] = true -- Path of Cavernous Depths
ALWAYS_EXCLUDED[393222] = true -- Path of the Watcher's Legacy
ALWAYS_EXCLUDED[393766] = true -- Path of the Grand Magistrix
ALWAYS_EXCLUDED[445440] = true -- Path of the Flaming Brewery
ALWAYS_EXCLUDED[1254551] = true -- Path of Dark Dereliction
ALWAYS_EXCLUDED[410080] = true -- Path of Wind's Domain
ALWAYS_EXCLUDED[424153] = true -- Path of Ancient Horrors
ALWAYS_EXCLUDED[424163] = true -- Path of the Nightmare Lord
ALWAYS_EXCLUDED[1254555] = true -- Path of Unyielding Blight
ALWAYS_EXCLUDED[393283] = true -- Path of the Titanic Reservoir
ALWAYS_EXCLUDED[424142] = true -- Path of the Tidehunter
ALWAYS_EXCLUDED[424197] = true -- Path of Twisted Time
ALWAYS_EXCLUDED[445414] = true -- Path of the Arathi Flagship
ALWAYS_EXCLUDED[445417] = true -- Path of the Ruined City
ALWAYS_EXCLUDED[424167] = true -- Path of Heart's Bane
ALWAYS_EXCLUDED[424187] = true -- Path of the Golden Tomb
ALWAYS_EXCLUDED[445269] = true -- Path of the Corrupted Foundry
ALWAYS_EXCLUDED[445424] = true -- Path of the Twilight Fortress
ALWAYS_EXCLUDED[464256] = true -- Path of the Besieged Harbor (alt)
ALWAYS_EXCLUDED[467555] = true -- Path of the Azerite Refinery (alt)
ALWAYS_EXCLUDED[1216786] = true -- Path of the Circuit Breaker
ALWAYS_EXCLUDED[1254572] = true -- Path of Devoted Magistry
ALWAYS_EXCLUDED[445441] = true -- Path of the Warding Candles
ALWAYS_EXCLUDED[445443] = true -- Path of the Fallen Stormriders

-- Exclude active healer aura spellIds unless their slot is disabled.
-- Cached to avoid O(n) copy of 150+ entries on every aura update.
local excludedCache = nil
local function GetExcludedSpellIds(plugin)
    if excludedCache then return excludedCache end
    local excluded = {}
    for id in pairs(ALWAYS_EXCLUDED) do excluded[id] = true end
    local isDisabled = plugin and plugin.IsComponentDisabled
    for _, slot in ipairs(HealerReg:ActiveSlots()) do
        if not (isDisabled and plugin:IsComponentDisabled(slot.key)) then
            excluded[slot.spellId] = true
            if slot.altSpellId then excluded[slot.altSpellId] = true end
        end
    end
    excludedCache = excluded
    return excluded
end

function Orbit.GroupAuraFilters:InvalidateCache() excludedCache = nil end

-- Flush cache when component visibility changes affect the exclusion set.
Orbit.EventBus:On("CANVAS_SETTINGS_CHANGED", function() excludedCache = nil end)

local _RecycledFilterList = {}

-- Creates a debuff post-filter function.
-- cfg.raidFilterFn: function() returning the filter string (e.g. "HARMFUL" or combat-aware)
function Orbit.GroupAuraFilters:CreateDebuffFilter(cfg)
    return function(plugin, unit, rawAuras, maxCount, filterOverride)
        local raidFilter = filterOverride or (cfg.raidFilterFn and cfg.raidFilterFn() or "HARMFUL")
        local excludeCC = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("CrowdControlIcon"))
        local excluded = GetExcludedSpellIds(plugin)
        local result = _RecycledFilterList
        for i = 1, #result do result[i] = nil end
        for _, aura in ipairs(rawAuras) do
            if aura.auraInstanceID then
                local sid = aura.spellId
                if not IsSecret(sid) and excluded[sid] then
                    -- skip: handled by dedicated SingleAura icon
                else
                    local passesFilter = plugin:IsAuraIncluded(unit, aura.auraInstanceID, raidFilter)
                    local passesCC = not excludeCC and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HARMFUL|CROWD_CONTROL")
                    local dominated = excludeCC and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HARMFUL|CROWD_CONTROL")
                    if (passesFilter or passesCC) and not dominated then
                        result[#result + 1] = aura
                        if #result >= maxCount then break end
                    end
                end
            end
        end
        return result
    end
end

-- Creates a buff post-filter function.
function Orbit.GroupAuraFilters:CreateBuffFilter()
    return function(plugin, unit, rawAuras, maxCount, filterOverride)
        local raidFilter = filterOverride or "HELPFUL|PLAYER"
        local excludeDefensives = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("DefensiveIcon"))
        local excluded = GetExcludedSpellIds(plugin)
        local result = _RecycledFilterList
        for i = 1, #result do result[i] = nil end
        for _, aura in ipairs(rawAuras) do
            if aura.auraInstanceID then
                local sid = aura.spellId
                if not IsSecret(sid) and excluded[sid] then
                    -- skip: handled by dedicated SingleAura icon
                else
                    local passesRaid = plugin:IsAuraIncluded(unit, aura.auraInstanceID, raidFilter)
                    local passesDef = not excludeDefensives and (plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|BIG_DEFENSIVE") or plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE"))
                    local isBigDef = excludeDefensives and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|BIG_DEFENSIVE")
                    local isExtDef = excludeDefensives and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
                    if (passesRaid or passesDef) and not isBigDef and not isExtDef then
                        result[#result + 1] = aura
                        if #result >= maxCount then break end
                    end
                end
            end
        end
        return result
    end
end
