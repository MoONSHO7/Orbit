-- [ ORBIT AURA SNAPSHOT CACHE ]----------------------------------------------------------------------
-- Per-frame aura caches keyed by auraInstanceID, patched incrementally on partial UNIT_AURA events. Extracted from AuraMixin so the mixin owns icon/container display, not cache bookkeeping.
local _, addonTable = ...
local Orbit = addonTable
local ipairs = ipairs

Orbit.AuraSnapshotCache = {}
local Cache = Orbit.AuraSnapshotCache

local GetAuraDataByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID
local IsFilteredOut = C_UnitAuras.IsAuraFilteredOutByInstanceID

function Cache:Populate(frame, snapshot)
    local hc = frame._harmfulAuraCache or {}
    local bc = frame._helpfulAuraCache or {}
    wipe(hc)
    wipe(bc)
    for _, a in ipairs(snapshot.harmful) do hc[a.auraInstanceID] = a end
    for _, a in ipairs(snapshot.helpful) do bc[a.auraInstanceID] = a end
    frame._harmfulAuraCache = hc
    frame._helpfulAuraCache = bc
end

function Cache:Patch(frame, unit, updateInfo)
    local hc = frame._harmfulAuraCache
    local bc = frame._helpfulAuraCache
    if not hc or not bc then return false end
    local changed = false
    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            local id = aura.auraInstanceID
            if id then
                local fresh = GetAuraDataByAuraInstanceID(unit, id) or aura
                if not IsFilteredOut(unit, id, "HARMFUL") then hc[id] = fresh; changed = true end
                if not IsFilteredOut(unit, id, "HELPFUL") then bc[id] = fresh; changed = true end
            end
        end
    end
    if updateInfo.updatedAuraInstanceIDs then
        for _, id in ipairs(updateInfo.updatedAuraInstanceIDs) do
            local fresh = GetAuraDataByAuraInstanceID(unit, id)
            if hc[id] then hc[id] = fresh or nil; changed = true
            elseif bc[id] then bc[id] = fresh or nil; changed = true
            elseif fresh then
                if not IsFilteredOut(unit, id, "HARMFUL") then hc[id] = fresh; changed = true end
                if not IsFilteredOut(unit, id, "HELPFUL") then bc[id] = fresh; changed = true end
            end
        end
    end
    if updateInfo.removedAuraInstanceIDs then
        for _, id in ipairs(updateInfo.removedAuraInstanceIDs) do
            if hc[id] then hc[id] = nil; changed = true end
            if bc[id] then bc[id] = nil; changed = true end
        end
    end
    return changed
end

-- CONTRACT: single module-wide scratch table reused across all frames, not per-frame storage. Consumers must fully drain the returned table before the next Build call and never retain a reference past dispatch.
local _RecycledSnapshot = { harmful = {}, helpful = {}, helpfulBySpell = {}, helpfulPlayerBySpell = {} }

function Cache:Build(frame)
    local hc = frame._harmfulAuraCache
    local bc = frame._helpfulAuraCache
    if not hc or not bc then return nil end
    local snap = _RecycledSnapshot
    local harmful = snap.harmful
    local helpful = snap.helpful
    local helpfulBySpell = snap.helpfulBySpell
    local helpfulPlayerBySpell = snap.helpfulPlayerBySpell

    for i = 1, #harmful do harmful[i] = nil end
    for i = 1, #helpful do helpful[i] = nil end
    for k in pairs(helpfulBySpell) do helpfulBySpell[k] = nil end
    for k in pairs(helpfulPlayerBySpell) do helpfulPlayerBySpell[k] = nil end

    for _, a in next, hc do harmful[#harmful + 1] = a end
    for _, a in next, bc do
        helpful[#helpful + 1] = a
        local sid = a.spellId
        if not issecretvalue(sid) then
            helpfulBySpell[sid] = a
            local fromPlayer = a.isFromPlayerOrPlayerPet
            if not issecretvalue(fromPlayer) and fromPlayer then helpfulPlayerBySpell[sid] = a end
        end
    end
    return snap
end
