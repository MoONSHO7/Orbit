-- ResourceBarMixin: Shared logic for discrete class resources
local _, Orbit = ...
---@class OrbitResourceBarMixin
Orbit.ResourceBarMixin = {}
local Mixin = Orbit.ResourceBarMixin

-- Druid form IDs
local DRUID_FORMS = {
    CAT = DRUID_CAT_FORM,
    BEAR = DRUID_BEAR_FORM,
    MOONKIN_1 = DRUID_MOONKIN_FORM_1,
    MOONKIN_2 = DRUID_MOONKIN_FORM_2,
}

-- [ CLASS/SPEC RESOURCE MAPPING ]------------------------------------------------------------------
local CLASS_RESOURCES = {
    ROGUE = Enum.PowerType.ComboPoints,
    PALADIN = Enum.PowerType.HolyPower,
    WARLOCK = Enum.PowerType.SoulShards,
    DEATHKNIGHT = Enum.PowerType.Runes,
    EVOKER = Enum.PowerType.Essence,
    -- Spec-dependent classes
    MAGE = {
        [62] = Enum.PowerType.ArcaneCharges, -- Arcane
    },
    MONK = {
        [269] = Enum.PowerType.Chi, -- Windwalker
    },
    DRUID = "FORM_DEPENDENT",
}

--- Get the resource type for the player's current class/spec/form
---@return number|nil powerType The Enum.PowerType value, or nil if no discrete resource
---@return string|nil powerName The power type name for event filtering
function Mixin:GetResourceForPlayer()
    local _, class = UnitClass("player")

    local resource = CLASS_RESOURCES[class]

    -- No resource for this class
    if not resource then
        return nil, nil
    end

    -- Druid is form-dependent
    if resource == "FORM_DEPENDENT" then
        local formID = GetShapeshiftFormID()
        if formID == DRUID_FORMS.CAT then
            return Enum.PowerType.ComboPoints, "COMBO_POINTS"
        end
        -- Other forms don't show discrete resources in this bar
        return nil, nil
    end

    -- Table means spec-dependent
    if type(resource) == "table" then
        local spec = GetSpecialization()
        local specID = spec and GetSpecializationInfo(spec)
        resource = specID and resource[specID]
        if not resource then
            return nil, nil
        end
    end

    -- Get power name from enum
    local powerName = nil
    for name, value in pairs(Enum.PowerType) do
        if value == resource then
            powerName = name:gsub("(%u)", "_%1"):gsub("^_", ""):upper()
            break
        end
    end

    return resource, powerName
end

-- [ RUNE COOLDOWN STATE ]--------------------------------------------------------------------------
--- Get rune state for Death Knights
---@param runeIndex number Rune index (1-6)
---@return boolean ready Is the rune ready?
---@return number remaining Seconds remaining (0 if ready)
---@return number fraction Fill fraction 0-1 (1 if ready)
function Mixin:GetRuneState(runeIndex)
    local start, duration, runeReady = GetRuneCooldown(runeIndex)

    if runeReady then
        return true, 0, 1
    end

    if start and duration and duration > 0 then
        local now = GetTime()
        local elapsed = now - start
        local remaining = math.max(0, duration - elapsed)
        local fraction = math.min(1, elapsed / duration)
        return false, remaining, fraction
    end

    return false, 0, 0
end

--- Get sorted rune display order (ready runes first, then by remaining time)
---@return table displayOrder Array of {index, ready, remaining, fraction}
function Mixin:GetSortedRuneOrder()
    local readyList = {}
    local cdList = {}

    for i = 1, 6 do
        local ready, remaining, fraction = self:GetRuneState(i)
        local entry = { index = i, ready = ready, remaining = remaining, fraction = fraction }

        if ready then
            table.insert(readyList, entry)
        else
            table.insert(cdList, entry)
        end
    end

    -- Sort cooldown runes by remaining time (least remaining first)
    table.sort(cdList, function(a, b)
        return a.remaining < b.remaining
    end)

    -- Ready runes first, then cooldown runes
    local result = {}
    for _, v in ipairs(readyList) do
        table.insert(result, v)
    end
    for _, v in ipairs(cdList) do
        table.insert(result, v)
    end

    return result
end

-- [ ESSENCE RECHARGE STATE ]-----------------------------------------------------------------------
-- Cached essence tracking
local essenceState = {
    nextTick = nil,
    lastEssence = 0,
}

--- Get essence recharge state for Evokers
---@param essenceIndex number Essence index (1-max)
---@param currentEssence number Current essence count
---@param maxEssence number Maximum essence
---@return string state "full", "partial", or "empty"
---@return number remaining Seconds remaining (0 if not partial)
---@return number fraction Fill fraction 0-1
function Mixin:GetEssenceState(essenceIndex, currentEssence, maxEssence)
    local now = GetTime()
    local regenRate = GetPowerRegenForPowerType(Enum.PowerType.Essence) or 0.2
    local tickDuration = 5 / (5 / (1 / regenRate))

    -- If essence changed (gained or spent), handle timer
    if currentEssence ~= essenceState.lastEssence then
        if currentEssence < maxEssence then
            -- Start recharge timer from now
            essenceState.nextTick = now + tickDuration
        else
            -- Full - no timer needed
            essenceState.nextTick = nil
        end
    end

    -- If missing essence and no timer, start it (fallback)
    if currentEssence < maxEssence and not essenceState.nextTick then
        essenceState.nextTick = now + tickDuration
    end

    -- If full, clear timer
    if currentEssence >= maxEssence then
        essenceState.nextTick = nil
    end

    essenceState.lastEssence = currentEssence

    -- Determine state for this specific segment
    if essenceIndex <= currentEssence then
        return "full", 0, 1
    elseif essenceIndex == currentEssence + 1 and essenceState.nextTick then
        local remaining = math.max(0, essenceState.nextTick - now)
        local fraction = 1 - (remaining / tickDuration)
        return "partial", remaining, fraction
    else
        return "empty", 0, 0
    end
end

-- [ CHARGED COMBO POINTS ]-------------------------------------------------------------------------
function Mixin:GetChargedPoints()
    local lookup = {}
    for _, idx in ipairs(GetUnitChargedPowerPoints("player") or {}) do
        lookup[idx] = true
    end
    return lookup
end

-- [ CONTINUOUS RESOURCE DETECTION ]----------------------------------------------------------------
--- Check if player should show a continuous bar resource instead of discrete
---@return string|nil resourceType "STAGGER", "SOUL_FRAGMENTS", "EBON_MIGHT", "MAELSTROM", or nil
function Mixin:GetContinuousResourceForPlayer()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)

    -- Brewmaster Monk - Stagger
    if class == "MONK" and specID == 268 then
        return "STAGGER"
    end

    -- NOTE: Augmentation Evoker Ebon Might is now handled by PlayerPower (mana bar)
    -- PlayerResources will show Essence (discrete segments) like Devastation Evoker

    -- Demon Hunter - Soul Fragments (Devourer hero talent tree)
    -- Check if the DemonHunterSoulFragmentsBar exists and is being used
    if class == "DEMONHUNTER" then
        if DemonHunterSoulFragmentsBar and DemonHunterSoulFragmentsBar:IsShown() then
            return "SOUL_FRAGMENTS"
        end
    end

    -- Priests (Shadow) - Mana
    if class == "PRIEST" and specID == 258 then
        return "MANA"
    end

    -- Shaman (Elemental) - Mana
    -- Only if primary power is NOT Mana
    if class == "SHAMAN" and specID == 262 then
        local primary = UnitPowerType("player")
        if primary ~= Enum.PowerType.Mana then
            return "MANA"
        end
    end

    -- Enhancement Shaman - Maelstrom Weapon stacks (aura-based)
    if class == "SHAMAN" and specID == 263 then
        return "MAELSTROM_WEAPON"
    end

    -- Druid (Balance) - Mana
    -- EXCEPT when in Cat Form (prioritize Combo Points which are discrete)
    -- EXCEPT when in Bear Form (Rage is primary, Mana is background/unused)
    -- AND EXCEPT when Primary Power is already Mana (e.g. Travel Form, Human Form default)
    if class == "DRUID" and specID == 102 then
        local formID = GetShapeshiftFormID()
        local primary = UnitPowerType("player")
        if formID ~= DRUID_FORMS.CAT and formID ~= DRUID_FORMS.BEAR and primary ~= Enum.PowerType.Mana then
            return "MANA"
        end
    end

    return nil
end

-- [ STAGGER STATE ]--------------------------------------------------------------------------------
function Mixin:GetStaggerState()
    local stagger = UnitStagger("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    local level = C_UnitAuras.GetPlayerAuraBySpellID(124273) and "HEAVY" 
        or C_UnitAuras.GetPlayerAuraBySpellID(124274) and "MEDIUM" 
        or "LOW"
    return stagger, maxHealth, level
end

-- [ SOUL FRAGMENTS STATE ]-------------------------------------------------------------------------
function Mixin:GetSoulFragmentsState()
    if not PlayerFrame or not PlayerFrame:IsShown() or not DemonHunterSoulFragmentsBar or not DemonHunterSoulFragmentsBar:IsShown() then
        return nil, nil, false
    end
    local current = DemonHunterSoulFragmentsBar:GetValue()
    local _, max = DemonHunterSoulFragmentsBar:GetMinMaxValues()
    local isVoidMeta = DemonHunterSoulFragmentsBar.CollapsingStarBackground and DemonHunterSoulFragmentsBar.CollapsingStarBackground:IsShown()
    return current, max, isVoidMeta
end

-- [ EBON MIGHT STATE ]-----------------------------------------------------------------------------
function Mixin:GetEbonMightState()
    if not PlayerFrame or not PlayerFrame:IsShown() or not EvokerEbonMightBar or not EvokerEbonMightBar:IsShown() then
        return nil, nil
    end
    local current = EvokerEbonMightBar:GetValue()
    local _, max = EvokerEbonMightBar:GetMinMaxValues()
    return current, max
end

-- [ MAELSTROM WEAPON STATE ]-----------------------------------------------------------------------
local MAELSTROM_WEAPON_ID = 344179

function Mixin:GetMaelstromWeaponState()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(MAELSTROM_WEAPON_ID)
    if not aura then return 0, 10, false, nil end
    return aura.applications or 0, 10, true, aura.auraInstanceID
end
