-- [ GROUP AURA FILTERS ]----------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit

-- Shared post-filter factories for Party and Raid frames.
-- Eliminates duplication between PartyFrame.lua and RaidFrame.lua aura filtering.

Orbit.GroupAuraFilters = {}

local HealerReg = Orbit.HealerAuraRegistry
local IsSecret = issecretvalue or function() return false end

-- Raid buffs always excluded from buff containers (long-term, low-value clutter).
local ALWAYS_EXCLUDED = {}
for _, entry in ipairs(HealerReg.RaidBuffs) do ALWAYS_EXCLUDED[entry.spellId] = true end

-- Exclude active healer aura spellIds unless their slot is disabled.
local _excludedCache = nil
local _excludedCachePlugin = nil
local function GetExcludedSpellIds(plugin)
    if _excludedCache and _excludedCachePlugin == plugin then return _excludedCache end
    local excluded = {}
    for id in pairs(ALWAYS_EXCLUDED) do excluded[id] = true end
    local isDisabled = plugin and plugin.IsComponentDisabled
    for _, slot in ipairs(HealerReg:ActiveSlots()) do
        if not (isDisabled and plugin:IsComponentDisabled(slot.key)) then
            excluded[slot.spellId] = true
            if slot.altSpellId then excluded[slot.altSpellId] = true end
        end
    end
    _excludedCache = excluded
    _excludedCachePlugin = plugin
    return excluded
end
Orbit.EventBus:On("CANVAS_SETTINGS_CHANGED", function() _excludedCache = nil end)

-- Creates a debuff post-filter function.
-- cfg.raidFilterFn: function() returning the filter string (e.g. "HARMFUL" or combat-aware)
function Orbit.GroupAuraFilters:CreateDebuffFilter(cfg)
    return function(plugin, unit, rawAuras, maxCount)
        local raidFilter = cfg.raidFilterFn and cfg.raidFilterFn() or "HARMFUL"
        local excludeCC = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("CrowdControlIcon"))
        local excluded = GetExcludedSpellIds(plugin)
        local result = {}
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
    return function(plugin, unit, rawAuras, maxCount)
        local raidFilter = "HELPFUL|PLAYER"
        local excludeDefensives = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("DefensiveIcon"))
        local excluded = GetExcludedSpellIds(plugin)
        local result = {}
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
