-- [ COOLDOWN LEARN ] --------------------------------------------------------------------------------
-- Learns a spell's aura duration from the live aura on its next application. One self-disabling UNIT_AURA listener.
local _, Orbit = ...

---@class OrbitCooldownLearn
Orbit.CooldownLearn = {}
local CooldownLearn = Orbit.CooldownLearn

-- [ STATE ] -----------------------------------------------------------------------------------------------
local byAuraSpell = {}
local frame

-- [ LISTENER ] --------------------------------------------------------------------------------------------
local function UpdateListener()
    if next(byAuraSpell) ~= nil then
        if not frame then
            frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", function(_, _, _, updateInfo) CooldownLearn:_OnUnitAura(updateInfo) end)
        end
        frame:RegisterUnitEvent("UNIT_AURA", "player")
    elseif frame then
        frame:UnregisterEvent("UNIT_AURA")
    end
end

-- [ SUBSCRIPTIONS ] ---------------------------------------------------------------------------------------
function CooldownLearn:Cancel(handle)
    if not handle then return end
    for sid, subs in pairs(byAuraSpell) do
        if subs[handle] ~= nil then
            subs[handle] = nil
            if next(subs) == nil then byAuraSpell[sid] = nil end
        end
    end
    UpdateListener()
end

-- One-shot: the first matching aura application delivers to every subscriber, then the handle is cancelled.
function CooldownLearn:Request(spellIDs, callback)
    if not spellIDs or not callback then return nil end
    local handle = {}
    for _, sid in ipairs(spellIDs) do
        if sid then
            local subs = byAuraSpell[sid]
            if not subs then subs = {}; byAuraSpell[sid] = subs end
            subs[handle] = callback
        end
    end
    UpdateListener()
    return handle
end

-- [ EVENT ] -----------------------------------------------------------------------------------------------
-- aura.spellId / aura.duration are SecretWhenUnitAuraRestricted; a secret table key or comparison throws, so guard both before use.
function CooldownLearn:_OnUnitAura(updateInfo)
    if not updateInfo or not updateInfo.addedAuras then return end
    for _, aura in ipairs(updateInfo.addedAuras) do
        local sid = aura.spellId
        if sid and not issecretvalue(sid) then
            local subs = byAuraSpell[sid]
            if subs then
                local dur = aura.duration
                if dur and not issecretvalue(dur) and dur > 0 then
                    local delivered
                    for handle, cb in pairs(subs) do
                        cb(dur, sid)
                        delivered = delivered or {}
                        delivered[#delivered + 1] = handle
                    end
                    if delivered then
                        for _, h in ipairs(delivered) do self:Cancel(h) end
                    end
                end
            end
        end
    end
end
