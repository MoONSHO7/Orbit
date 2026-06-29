-- [ COOLDOWN DATA ] ---------------------------------------------------------------------------------
-- C_CooldownViewer metadata as a spellID -> cooldownInfo reverse lookup, rebuilt on spec/talent change; O(1) reads.
local _, Orbit = ...

---@class OrbitCooldownData
Orbit.CooldownData = {}
local CooldownData = Orbit.CooldownData

-- [ STATE ] -----------------------------------------------------------------------------------------------
local bySpell = {}
local built = false

-- [ CACHE BUILD ] -----------------------------------------------------------------------------------------
local function Index(info)
    if not info then return end
    if info.spellID then bySpell[info.spellID] = info end
    if info.overrideSpellID then bySpell[info.overrideSpellID] = info end
    if info.overrideTooltipSpellID then bySpell[info.overrideTooltipSpellID] = info end
end

function CooldownData:Rebuild()
    wipe(bySpell)
    built = true
    if not (C_CooldownViewer and Enum and Enum.CooldownViewerCategory) then return end
    local categories = {
        Enum.CooldownViewerCategory.Essential,
        Enum.CooldownViewerCategory.Utility,
        Enum.CooldownViewerCategory.TrackedBuff,
        Enum.CooldownViewerCategory.TrackedBar,
    }
    for _, category in ipairs(categories) do
        local ids = C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
        if ids then
            for _, cooldownID in ipairs(ids) do
                Index(C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID))
            end
        end
    end
end

-- [ READS ] -----------------------------------------------------------------------------------------------
-- Returned table is owned by the cache and replaced on the next Rebuild; never hold it across a spec/talent change.
function CooldownData:GetInfo(spellID)
    if not built then self:Rebuild() end
    return spellID and bySpell[spellID] or nil
end

function CooldownData:IsTracked(spellID)
    return self:GetInfo(spellID) ~= nil
end

function CooldownData:HasAura(spellID)
    local info = self:GetInfo(spellID)
    return info ~= nil and info.hasAura == true
end

function CooldownData:IsSelfAura(spellID)
    local info = self:GetInfo(spellID)
    return info ~= nil and info.selfAura == true
end

function CooldownData:HasCharges(spellID)
    local info = self:GetInfo(spellID)
    return info ~= nil and info.charges == true
end

function CooldownData:GetAuraSpellIDs(spellID)
    local info = self:GetInfo(spellID)
    return info and info.linkedSpellIDs or nil
end

-- True when the spell is a CDM buff/debuff entry (TrackedBuff/TrackedBar category) — render as a live-aura cell, not a cooldown.
function CooldownData:IsAuraCategory(spellID)
    local info = self:GetInfo(spellID)
    if not info or not (Enum and Enum.CooldownViewerCategory) then return false end
    return info.category == Enum.CooldownViewerCategory.TrackedBuff or info.category == Enum.CooldownViewerCategory.TrackedBar
end

-- Mirrors Blizzard's charge-query precedence (overrideSpellID or spellID); falls back to the live override API. Never nil for a valid id.
function CooldownData:GetActiveSpellID(spellID)
    if not spellID then return spellID end
    local info = self:GetInfo(spellID)
    if info then
        return info.overrideSpellID or info.spellID or spellID
    end
    if C_Spell and C_Spell.GetOverrideSpell then
        return C_Spell.GetOverrideSpell(spellID) or spellID
    end
    return spellID
end

-- Base cooldown in seconds, or nil if none / unavailable / secret (combat) so callers keep their last-known value.
function CooldownData:GetBaseCooldownSeconds(spellID)
    if not spellID or not GetSpellBaseCooldown then return nil end
    local ms = GetSpellBaseCooldown(spellID)
    if not ms or issecretvalue(ms) or ms <= 0 then return nil end
    return ms / 1000
end

-- [ ACTIVE-DURATION OVERRIDES ] -----------------------------------------------------------------------------
-- Spells whose CDM aura is NOT the ability's active phase (instant effects, target debuffs); value = forced active seconds (0 = no active phase).
CooldownData.ActiveDurationOverrideSeconds = {
    [1122] = 30,
    [633] = 0,
    [48743] = 0,
}

function CooldownData:GetActiveDurationOverride(spellID)
    return spellID and self.ActiveDurationOverrideSeconds[spellID] or nil
end

-- Returns (value, watchList): value = override or nil; a non-nil watchList means a learnable self-aura, pass it to CooldownLearn:Request.
function CooldownData:ResolveActiveDuration(spellID)
    local activeId = self:GetActiveSpellID(spellID)
    local override = self:GetActiveDurationOverride(spellID) or self:GetActiveDurationOverride(activeId)
    if override ~= nil then return override, nil end
    if not self:IsSelfAura(activeId) then return nil, nil end
    local watch = { spellID }
    if activeId and activeId ~= spellID then watch[#watch + 1] = activeId end
    local linked = self:GetAuraSpellIDs(activeId)
    if linked then for _, s in ipairs(linked) do watch[#watch + 1] = s end end
    return nil, watch
end

-- [ EVENTS ] ----------------------------------------------------------------------------------------------
-- Mark dirty rather than rebuild inline: coalesces the multiple TRAIT_CONFIG_UPDATED fires per talent commit into one lazy rebuild on the next read.
local frame = CreateFrame("Frame")
frame:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
frame:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
frame:RegisterEvent("COOLDOWN_VIEWER_TABLE_HOTFIXED")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:SetScript("OnEvent", function() built = false end)
