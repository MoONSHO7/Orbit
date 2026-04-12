-- [ GROUP AURA FILTERS ]----------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit

-- Shared post-filter factories for Party and Raid frames.

Orbit.GroupAuraFilters = {}

local HealerReg = Orbit.HealerAuraRegistry
local W = Orbit.WhitelistedSpells
local IsSecret = issecretvalue

-- Raid buffs always excluded from buff containers (long-term, low-value clutter).
local ALWAYS_EXCLUDED = {}
for _, entry in ipairs(HealerReg.RaidBuffs) do
    ALWAYS_EXCLUDED[entry.spellId] = true
    if entry.variants then for _, vid in ipairs(entry.variants) do ALWAYS_EXCLUDED[vid] = true end end
end
Orbit.GroupAuraFilters.AlwaysExcluded = ALWAYS_EXCLUDED
-- [ WHITELISTED CATEGORIES ]------------------------------------------------------------------------
-- Merge WhitelistedSpells categories that are low-value clutter on group frames.
local function MergeInto(dest, source) for id in pairs(source) do dest[id] = true end end
MergeInto(ALWAYS_EXCLUDED, W.RAID_BUFFS)
MergeInto(ALWAYS_EXCLUDED, W.CLASS_RESOURCES)
MergeInto(ALWAYS_EXCLUDED, W.BRONZE_VARIANTS)
MergeInto(ALWAYS_EXCLUDED, W.ROGUE_POISONS)
MergeInto(ALWAYS_EXCLUDED, W.SHAMAN_IMBUEMENTS)
MergeInto(ALWAYS_EXCLUDED, W.EXHAUSTION)
MergeInto(ALWAYS_EXCLUDED, W.SKYRIDING)
MergeInto(ALWAYS_EXCLUDED, W.UTILITY)
MergeInto(ALWAYS_EXCLUDED, W.SYSTEM)
-- [ NON-WHITELISTED EXCLUSIONS ]--------------------------------------------------------------------
-- Flight style auras and ride-along not in WhitelistedSpells (not secret-relevant).
ALWAYS_EXCLUDED[404468] = true -- Flight Style: Steady
ALWAYS_EXCLUDED[404464] = true -- Flight Style: Skyriding
ALWAYS_EXCLUDED[460003] = true -- Switch Flight Style (alt)
ALWAYS_EXCLUDED[447959] = true -- Ride Along - Enabled
ALWAYS_EXCLUDED[447960] = true -- Ride Along - Inactive
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

-- Exclude active healer aura spellIds unless their slot is disabled; evaluated dynamically.
local function IsSpellExcluded(plugin, sid)
    if ALWAYS_EXCLUDED[sid] then return true end

    local isDisabled = plugin and plugin.IsComponentDisabled
    for _, slot in ipairs(HealerReg:ActiveSlots()) do
        if slot.spellId == sid or slot.altSpellId == sid then
            local disabled = isDisabled and plugin:IsComponentDisabled(slot.key)
            if not disabled then
                return true
            end
        end
    end
    return false
end

function Orbit.GroupAuraFilters:InvalidateCache() end

local _RecycledFilterList = {}

-- Creates a debuff post-filter; cfg.raidFilterFn returns the filter string.
function Orbit.GroupAuraFilters:CreateDebuffFilter(cfg)
    return function(plugin, unit, rawAuras, maxCount, filterOverride)
        local raidFilter = filterOverride or (cfg.raidFilterFn and cfg.raidFilterFn() or "HARMFUL")
        local excludeCC = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("CrowdControlIcon"))
        local result = _RecycledFilterList
        for i = 1, #result do result[i] = nil end
        for _, aura in ipairs(rawAuras) do
            if aura.auraInstanceID then
                local sid = aura.spellId
                if not IsSecret(sid) and IsSpellExcluded(plugin, sid) then
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
        local result = _RecycledFilterList
        for i = 1, #result do result[i] = nil end
        for _, aura in ipairs(rawAuras) do
            if aura.auraInstanceID then
                local sid = aura.spellId
                if not IsSecret(sid) and IsSpellExcluded(plugin, sid) then
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
