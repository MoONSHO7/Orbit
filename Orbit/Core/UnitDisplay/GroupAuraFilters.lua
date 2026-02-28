-- [ GROUP AURA FILTERS ]----------------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit

-- Shared post-filter factories for Party and Raid frames.
-- Eliminates duplication between PartyFrame.lua and RaidFrame.lua aura filtering.

Orbit.GroupAuraFilters = {}

-- Creates a debuff post-filter function.
-- cfg.raidFilterFn: function() returning the filter string (e.g. "HARMFUL" or combat-aware)
function Orbit.GroupAuraFilters:CreateDebuffFilter(cfg)
    return function(plugin, unit, rawAuras, maxCount)
        local raidFilter = cfg.raidFilterFn and cfg.raidFilterFn() or "HARMFUL"
        local excludeCC = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("CrowdControlIcon"))
        local result = {}
        for _, aura in ipairs(rawAuras) do
            if aura.auraInstanceID then
                local passesFilter = plugin:IsAuraIncluded(unit, aura.auraInstanceID, raidFilter)
                local passesCC = not excludeCC and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HARMFUL|CROWD_CONTROL")
                local dominated = excludeCC and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HARMFUL|CROWD_CONTROL")
                if (passesFilter or passesCC) and not dominated then
                    result[#result + 1] = aura
                    if #result >= maxCount then break end
                end
            end
        end
        return result
    end
end

-- Creates a buff post-filter function.
function Orbit.GroupAuraFilters:CreateBuffFilter()
    return function(plugin, unit, rawAuras, maxCount)
        local inCombat = UnitAffectingCombat("player")
        local raidFilter = inCombat and "HELPFUL|PLAYER|RAID_IN_COMBAT" or "HELPFUL|PLAYER|RAID"
        local excludeDefensives = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("DefensiveIcon"))
        local result = {}
        for _, aura in ipairs(rawAuras) do
            if aura.auraInstanceID then
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
        return result
    end
end
