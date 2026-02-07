-- ResourceBarMixin: Shared logic for discrete class resources
local _, Orbit = ...
---@class OrbitResourceBarMixin
Orbit.ResourceBarMixin = {}
local Mixin = Orbit.ResourceBarMixin

local DRUID_FORMS = { CAT = DRUID_CAT_FORM, BEAR = DRUID_BEAR_FORM, MOONKIN_1 = DRUID_MOONKIN_FORM_1, MOONKIN_2 = DRUID_MOONKIN_FORM_2 }

-- [ SPELL IDS ]-------------------------------------------------------------------------------------
local SOUL_CLEAVE_ID = 228477
local SOUL_FRAGMENTS_AURA_ID = 1225789
local COLLAPSING_STAR_AURA_ID = 1227702
local SOUL_GLUTTON_TALENT_ID = 1247534
local EBON_MIGHT_AURA_ID = 395296
local EBON_MIGHT_MAX_DURATION = 20
local VENGEANCE_SPEC_ID = 581
local DEVOURER_SPEC_ID = 1480
local AUGMENTATION_SPEC_ID = 1473

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

function Mixin:GetResourceForPlayer()
    local _, class = UnitClass("player")
    local resource = CLASS_RESOURCES[class]
    if not resource then
        return nil, nil
    end
    if resource == "FORM_DEPENDENT" then
        if GetShapeshiftFormID() == DRUID_FORMS.CAT then
            return Enum.PowerType.ComboPoints, "COMBO_POINTS"
        end
        return nil, nil
    end
    if type(resource) == "table" then
        local spec = GetSpecialization()
        local specID = spec and GetSpecializationInfo(spec)
        resource = specID and resource[specID]
        if not resource then
            return nil, nil
        end
    end
    local powerName = nil
    for name, value in pairs(Enum.PowerType) do
        if value == resource then
            powerName = name:gsub("(%u)", "_%1"):gsub("^_", ""):upper()
            break
        end
    end
    return resource, powerName
end

function Mixin:GetRuneState(runeIndex)
    local start, duration, runeReady = GetRuneCooldown(runeIndex)
    if runeReady then
        return true, 0, 1
    end
    if start and duration and duration > 0 then
        local elapsed = GetTime() - start
        return false, math.max(0, duration - elapsed), math.min(1, elapsed / duration)
    end
    return false, 0, 0
end

function Mixin:GetSortedRuneOrder()
    local readyList, cdList = {}, {}
    for i = 1, 6 do
        local ready, remaining, fraction = self:GetRuneState(i)
        table.insert(ready and readyList or cdList, { index = i, ready = ready, remaining = remaining, fraction = fraction })
    end
    table.sort(cdList, function(a, b)
        return a.remaining < b.remaining
    end)
    local result = {}
    for _, v in ipairs(readyList) do
        table.insert(result, v)
    end
    for _, v in ipairs(cdList) do
        table.insert(result, v)
    end
    return result
end

local essenceState = { nextTick = nil, lastEssence = 0 }

function Mixin:GetEssenceState(essenceIndex, currentEssence, maxEssence)
    local now = GetTime()
    local tickDuration = 1 / (GetPowerRegenForPowerType(Enum.PowerType.Essence) or 0.2)
    if currentEssence ~= essenceState.lastEssence then
        essenceState.nextTick = currentEssence < maxEssence and (now + tickDuration) or nil
    end
    if currentEssence < maxEssence and not essenceState.nextTick then
        essenceState.nextTick = now + tickDuration
    end
    if currentEssence >= maxEssence then
        essenceState.nextTick = nil
    end
    essenceState.lastEssence = currentEssence
    if essenceIndex <= currentEssence then
        return "full", 0, 1
    elseif essenceIndex == currentEssence + 1 and essenceState.nextTick then
        local remaining = math.max(0, essenceState.nextTick - now)
        return "partial", remaining, 1 - (remaining / tickDuration)
    else
        return "empty", 0, 0
    end
end

function Mixin:GetChargedPoints()
    local lookup = {}
    for _, idx in ipairs(GetUnitChargedPowerPoints("player") or {}) do
        lookup[idx] = true
    end
    return lookup
end

function Mixin:GetContinuousResourceForPlayer()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    if class == "MONK" and specID == 268 then
        return "STAGGER"
    end
    if class == "DEMONHUNTER" and (specID == VENGEANCE_SPEC_ID or specID == DEVOURER_SPEC_ID) then
        return "SOUL_FRAGMENTS"
    end
    if class == "PRIEST" and specID == 258 then
        return "MANA"
    end
    if class == "SHAMAN" and specID == 262 and UnitPowerType("player") ~= Enum.PowerType.Mana then
        return "MANA"
    end
    if class == "SHAMAN" and specID == 263 then
        return "MAELSTROM_WEAPON"
    end
    if class == "DRUID" and specID == 102 then
        local formID, primary = GetShapeshiftFormID(), UnitPowerType("player")
        if formID ~= DRUID_FORMS.CAT and formID ~= DRUID_FORMS.BEAR and primary ~= Enum.PowerType.Mana then
            return "MANA"
        end
    end
    return nil
end

function Mixin:GetStaggerState()
    local stagger, maxHealth = UnitStagger("player") or 0, UnitHealthMax("player") or 1
    local level = C_UnitAuras.GetPlayerAuraBySpellID(124273) and "HEAVY" or C_UnitAuras.GetPlayerAuraBySpellID(124274) and "MEDIUM" or "LOW"
    return stagger, maxHealth, level
end

function Mixin:GetSoulFragmentsState()
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    if specID == VENGEANCE_SPEC_ID then
        local current = C_Spell.GetSpellCastCount(SOUL_CLEAVE_ID) or 0
        return current, 6, false
    end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(SOUL_FRAGMENTS_AURA_ID) or C_UnitAuras.GetPlayerAuraBySpellID(COLLAPSING_STAR_AURA_ID)
    local current = aura and aura.applications or 0
    local max = C_SpellBook.IsSpellKnown(SOUL_GLUTTON_TALENT_ID) and 35 or 50
    local isVoidMeta = aura and aura.spellId == COLLAPSING_STAR_AURA_ID
    return current, max, isVoidMeta
end

function Mixin:GetEbonMightState()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(EBON_MIGHT_AURA_ID)
    if not aura then return 0, EBON_MIGHT_MAX_DURATION end
    local remaining = math.max(0, aura.expirationTime - GetTime())
    return remaining, EBON_MIGHT_MAX_DURATION
end

local MAELSTROM_WEAPON_ID = 344179
function Mixin:GetMaelstromWeaponState()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(MAELSTROM_WEAPON_ID)
    if not aura then
        return 0, 10, false, nil
    end
    return aura.applications or 0, 10, true, aura.auraInstanceID
end
