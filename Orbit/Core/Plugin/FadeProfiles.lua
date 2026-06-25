-- [ FADE PROFILES ENGINE ]---------------------------------------------------------------------------
-- Resolved alpha is the lowest firing profile's target (lowest-alpha-wins), consumed as a multiplicative cap by OOCFadeMixin and ApplySecureBlizzardFrame.
local _, Orbit = ...

Orbit.FadeProfiles = {}
local FP = Orbit.FadeProfiles

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local RECOMPUTE_DEBOUNCE = 0.05

-- [ INSTANCE PREDICATES ]----------------------------------------------------------------------------
-- Instance type/difficulty/delve state are world state (not secret values), safe to read and compare in Lua. No macro conditional exists for instance type, so these conditions evaluate via a Lua predicate instead of SecureCmdOptionParse.
local DUNGEON_CHALLENGE = (DifficultyUtil and DifficultyUtil.ID and DifficultyUtil.ID.DungeonChallenge) or 8
local function CurInstanceType()
    local inInstance, t = IsInInstance()
    return inInstance and t or "none"
end
local function CurInstanceDifficulty()
    return select(3, GetInstanceInfo())
end
-- Mirrors Blizzard's InstanceDifficultyMixin:IsInDelve — HasActiveDelve(mapID) is the canonical membership test (the tier API reflects party walk-in data and can persist after leaving).
local function InActiveDelve()
    if not (C_DelvesUI and C_DelvesUI.HasActiveDelve) then return false end
    local _, _, _, mapID = UnitPosition("player")
    local ok, res = pcall(C_DelvesUI.HasActiveDelve, mapID)
    return ok and res == true
end

-- Explicit true/false clauses per condition: the "no" prefix can't derive negation for @unit/value clauses. perFrame = live hover; predicate = Lua-evaluated (instance state).
local CONDITION_CATALOG = {
    { key = "combat",    labelKey = "CFG_FP_COND_COMBAT",    category = "Combat",   trueClause = "combat",          falseClause = "nocombat" },
    { key = "mouseover", labelKey = "CFG_FP_COND_MOUSEOVER", category = "Self",     perFrame = true, defaultState = "separate" },
    { key = "resting",   labelKey = "CFG_FP_COND_RESTING",   category = "Self",     trueClause = "resting",         falseClause = "noresting" },
    { key = "mounted",   labelKey = "CFG_FP_COND_MOUNTED",   category = "Movement", trueClause = "mounted",         falseClause = "nomounted" },
    { key = "flying",    labelKey = "CFG_FP_COND_FLYING",    category = "Movement", trueClause = "flying",          falseClause = "noflying" },
    { key = "swimming",  labelKey = "CFG_FP_COND_SWIMMING",  category = "Movement", trueClause = "swimming",        falseClause = "noswimming" },
    { key = "stealth",   labelKey = "CFG_FP_COND_STEALTH",   category = "Self",     trueClause = "stealth",         falseClause = "nostealth" },
    { key = "vehicle",   labelKey = "CFG_FP_COND_VEHICLE",   category = "Self",     trueClause = "vehicleui",       falseClause = "novehicleui" },
    { key = "petbattle", labelKey = "CFG_FP_COND_PETBATTLE", category = "Self",     trueClause = "petbattle",       falseClause = "nopetbattle" },
    { key = "raid",      labelKey = "CFG_FP_COND_RAID",      category = "Group",    trueClause = "group:raid",      falseClause = "nogroup:raid" },
    { key = "party",     labelKey = "CFG_FP_COND_PARTY",     category = "Group",    trueClause = "group:party",     falseClause = "nogroup:party" },
    { key = "group",     labelKey = "CFG_FP_COND_GROUP",     category = "Group",    trueClause = "group",           falseClause = "nogroup" },
    { key = "target",    labelKey = "CFG_FP_COND_TARGET",    category = "Target",   trueClause = "@target,exists",  falseClause = "@target,noexists" },
    { key = "focus",     labelKey = "CFG_FP_COND_FOCUS",     category = "Target",   trueClause = "@focus,exists",   falseClause = "@focus,noexists" },
    { key = "pet",       labelKey = "CFG_FP_COND_PET",       category = "Self",     trueClause = "@pet,exists",     falseClause = "@pet,noexists" },
    { key = "dead",      labelKey = "CFG_FP_COND_DEAD",      category = "Self",     predicate = function() return UnitIsDeadOrGhost("player") end },
    { key = "dungeon",     labelKey = "CFG_FP_COND_DUNGEON",      category = "Instance", predicate = function() return CurInstanceType() == "party" and CurInstanceDifficulty() ~= DUNGEON_CHALLENGE end },
    { key = "mythicplus",  labelKey = "CFG_FP_COND_MYTHICPLUS",   category = "Instance", predicate = function() return CurInstanceType() == "party" and CurInstanceDifficulty() == DUNGEON_CHALLENGE end },
    { key = "raidinst",    labelKey = "CFG_FP_COND_RAIDINST",     category = "Instance", predicate = function() return CurInstanceType() == "raid" end },
    { key = "delve",       labelKey = "CFG_FP_COND_DELVE",        category = "Instance", predicate = InActiveDelve },
    { key = "battleground", labelKey = "CFG_FP_COND_BATTLEGROUND", category = "Instance", predicate = function() return CurInstanceType() == "pvp" end },
    { key = "arena",       labelKey = "CFG_FP_COND_ARENA",        category = "Instance", predicate = function() return CurInstanceType() == "arena" end },
}
local CATALOG_BY_KEY = {}
for _, def in ipairs(CONDITION_CATALOG) do CATALOG_BY_KEY[def.key] = def end

-- Drop any token the live client rejects: SecureCmdOptionParse is authoritative and Blizzard moves conditionals between patches.
local VALIDATED_CATALOG = {}
for _, def in ipairs(CONDITION_CATALOG) do
    if def.perFrame or def.predicate then
        VALIDATED_CATALOG[#VALIDATED_CATALOG + 1] = def
    elseif pcall(SecureCmdOptionParse, "[" .. def.trueClause .. "] 1; 0") then
        VALIDATED_CATALOG[#VALIDATED_CATALOG + 1] = def
    end
end

-- [ DB ACCESS ]--------------------------------------------------------------------------------------
local function GetDB()
    if not Orbit.db then return nil end
    local db = Orbit.db.FadeProfiles
    if not db then
        db = { profiles = {}, revealAll = false, nextId = 1 }
        Orbit.db.FadeProfiles = db
    end
    return db
end

local function FindProfile(id)
    local db = GetDB()
    if not db then return nil end
    for i, p in ipairs(db.profiles) do
        if p.id == id then return p, i end
    end
    return nil
end

-- [ EVALUATION & RESOLUTION ]------------------------------------------------------------------------
local resolved = {}
local mouseoverProfiles = {}
local fired = {}
local movementPoll
local hoverByKey = {}
local anyHovered = {}
local hasLinked = false

-- Each non-perFrame condition resolves to a boolean: macro conditions via SecureCmdOptionParse, instance conditions via their Lua predicate (no macro conditional exists for those). "no" state negates.
local function ConditionTrue(c, def)
    if def.predicate then
        local raw = def.predicate() and true or false
        if c.state == "false" then return not raw end
        return raw
    end
    local clause = (c.state == "false") and def.falseClause or def.trueClause
    local ok, res = pcall(SecureCmdOptionParse, "[" .. clause .. "] 1; 0")
    return ok and res == "1"
end

-- Mouseover is a per-frame condition (no macro conditional exists for "cursor over THIS frame") so it is resolved live against each member's hover state, not in the global driver eval.
local function MouseoverState(profile)
    for _, c in ipairs(profile.conditions) do
        local def = CATALOG_BY_KEY[c.key]
        if def and def.perFrame then return c.state end
    end
    return nil
end

-- "group" mouseover mode reveals every member when any one is hovered; "separate" reveals each on its own hover.
local function ProfileLinked(profile)
    for _, c in ipairs(profile.conditions) do
        local def = CATALOG_BY_KEY[c.key]
        if def and def.perFrame then return c.state == "group" end
    end
    return false
end

local function NeedsMovementPoll()
    local db = GetDB()
    if not db or db.revealAll then return false end
    for _, p in ipairs(db.profiles) do
        if p.enabled then
            for _, c in ipairs(p.conditions) do
                if c.key == "flying" or c.key == "swimming" then return true end
            end
        end
    end
    return false
end

-- AND-runs are ANDed; an "or" connector starts a new group; groups are ORed (AND binds tighter, matching macro-conditional semantics). No firing conditions = always fires.
function FP:IsFiring(profile)
    if not profile.enabled then return false end
    local result, current, hasAny = false, nil, false
    for _, c in ipairs(profile.conditions) do
        local def = CATALOG_BY_KEY[c.key]
        if def and not def.perFrame then
            hasAny = true
            local m = ConditionTrue(c, def)
            if current == nil or c.connector == "or" then
                if current ~= nil then result = result or current end
                current = m
            else
                current = current and m
            end
        end
    end
    if not hasAny then return true end
    return result or current
end

function FP:Recompute()
    wipe(resolved)
    wipe(mouseoverProfiles)
    wipe(fired)
    wipe(anyHovered)
    hasLinked = false
    local db = GetDB()
    if db and not db.revealAll then
        for _, p in ipairs(db.profiles) do
            local firing = self:IsFiring(p)
            fired[p.id] = firing
            if firing then
                local a = (p.fade or 100) / 100
                local mState = MouseoverState(p)
                if mState then
                    local linked = (mState == "group")
                    if linked then
                        hasLinked = true
                        for mk in pairs(p.members) do
                            if hoverByKey[mk] then anyHovered[p.id] = true; break end
                        end
                    end
                    for veKey in pairs(p.members) do
                        local list = mouseoverProfiles[veKey]
                        if not list then list = {}; mouseoverProfiles[veKey] = list end
                        list[#list + 1] = { target = a, profileId = p.id, linked = linked, maxAlpha = (p.maxOpacity or 100) / 100 }
                    end
                else
                    for veKey in pairs(p.members) do
                        if not resolved[veKey] or a < resolved[veKey] then resolved[veKey] = a end
                    end
                end
            end
        end
    end
    if movementPoll then movementPoll:SetShown(NeedsMovementPoll()) end
    if Orbit.EventBus then Orbit.EventBus:Fire("ORBIT_VISIBILITY_CHANGED") end
    if Orbit.VisibilityEngine then Orbit.VisibilityEngine:ApplyAllSecureBlizzardFrames() end
end

function FP:GetResolvedAlpha(veKey)
    return resolved[veKey] or 1
end

-- Live mouseover resolution: caller passes the member's current hover state (the secure Blizzard path has no hover ticker, so mouseover conditions never reach it — matching VisibilityEngine's "secure frames, no mouseOver" rule).
function FP:GetMouseoverAlpha(veKey, isMouseOver)
    local list = mouseoverProfiles[veKey]
    if not list then return 1 end
    local a = 1
    for _, e in ipairs(list) do
        local hovered
        if e.linked then hovered = anyHovered[e.profileId] or false else hovered = isMouseOver end
        local cap
        if hovered then cap = e.maxAlpha or 1 else cap = e.target end
        if cap < a then a = cap end
    end
    return a
end

function FP:FrameHasMouseoverProfile(veKey)
    return mouseoverProfiles[veKey] ~= nil
end

-- Linked groups: a member's hover reveals the whole group. OOCFadeMixin's hover ticker reports each member's hover here; when the group's any-member-hovered state flips, refresh so siblings update too.
function FP:OnFrameHoverChanged(veKey, isOver)
    if not veKey then return end
    hoverByKey[veKey] = isOver or nil
    if not hasLinked then return end
    local db = GetDB()
    if not db then return end
    local changed = false
    for _, p in ipairs(db.profiles) do
        if ProfileLinked(p) and p.enabled and p.members[veKey] then
            local any = false
            for mk in pairs(p.members) do
                if hoverByKey[mk] then any = true; break end
            end
            if (anyHovered[p.id] or false) ~= any then anyHovered[p.id] = any or nil; changed = true end
        end
    end
    if changed and Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
end

function FP:IsProfileFiring(id)
    return fired[id] or false
end

-- [ API ]--------------------------------------------------------------------------------------------
function FP:GetConditionCatalog()
    return (#VALIDATED_CATALOG > 0) and VALIDATED_CATALOG or CONDITION_CATALOG
end

function FP:GetProfiles()
    local db = GetDB()
    return db and db.profiles or {}
end

function FP:GetProfilesForMember(veKey)
    local out = {}
    local db = GetDB()
    if not db then return out end
    for _, p in ipairs(db.profiles) do
        if p.members[veKey] then out[#out + 1] = p end
    end
    return out
end

function FP:IsRevealAll()
    local db = GetDB()
    return db and db.revealAll or false
end

local function Changed(self)
    self:Recompute()
    if Orbit.EventBus then Orbit.EventBus:Fire("ORBIT_FADE_PROFILES_CHANGED") end
end

function FP:SetRevealAll(state)
    local db = GetDB()
    if not db then return end
    db.revealAll = state and true or false
    Changed(self)
end

local function UniqueName(db, base, exceptId)
    local taken = {}
    for _, p in ipairs(db.profiles) do if p.id ~= exceptId then taken[p.name] = true end end
    if not taken[base] then return base end
    local n = 2
    while taken[base .. " " .. n] do n = n + 1 end
    return base .. " " .. n
end

function FP:CreateProfile(name)
    local db = GetDB()
    if not db then return nil end
    local id = db.nextId or 1
    db.nextId = id + 1
    db.profiles[#db.profiles + 1] = { id = id, name = UniqueName(db, name), enabled = true, fade = 50, maxOpacity = 100, conditions = {}, members = {} }
    Changed(self)
    return id
end

function FP:DuplicateProfile(id, name)
    local db = GetDB()
    local src = FindProfile(id)
    if not db or not src then return nil end
    local newId = db.nextId or 1
    db.nextId = newId + 1
    local conds = {}
    for _, c in ipairs(src.conditions) do conds[#conds + 1] = { key = c.key, state = c.state, connector = c.connector } end
    local members = {}
    for k in pairs(src.members) do members[k] = true end
    db.profiles[#db.profiles + 1] = {
        id = newId, name = UniqueName(db, name or src.name), enabled = src.enabled,
        fade = src.fade, maxOpacity = src.maxOpacity, conditions = conds, members = members,
    }
    Changed(self)
    return newId
end

function FP:DeleteProfile(id)
    local db = GetDB()
    if not db then return end
    local _, index = FindProfile(id)
    if index then table.remove(db.profiles, index) end
    Changed(self)
end

function FP:SetEnabled(id, state)
    local p = FindProfile(id)
    if p then p.enabled = state and true or false; Changed(self) end
end

function FP:SetName(id, name)
    local db = GetDB()
    local p = FindProfile(id)
    if not db or not p or not name or name == "" then return end
    p.name = UniqueName(db, name, id)
    Changed(self)
end

-- fade = opacity when dimmed (low handle); maxOpacity = ceiling when mouseover-revealed (high handle). Clamped so max >= fade.
function FP:SetFadeRange(id, fade, maxOpacity)
    local p = FindProfile(id)
    if not p then return end
    fade = math.max(0, math.min(100, fade))
    maxOpacity = math.max(0, math.min(100, maxOpacity))
    if maxOpacity < fade then maxOpacity = fade end
    p.fade = fade
    p.maxOpacity = maxOpacity
    Changed(self)
end

function FP:AddCondition(id, conditionKey, state)
    local p = FindProfile(id)
    local def = CATALOG_BY_KEY[conditionKey]
    if not p or not def then return end
    p.conditions[#p.conditions + 1] = { key = conditionKey, state = state or def.defaultState or "true", connector = "and" }
    Changed(self)
end

function FP:SetConditionState(id, index, state)
    local p = FindProfile(id)
    if p and p.conditions[index] then p.conditions[index].state = state; Changed(self) end
end

function FP:SetConditionConnector(id, index, connector)
    local p = FindProfile(id)
    if p and p.conditions[index] then p.conditions[index].connector = connector; Changed(self) end
end

function FP:RemoveCondition(id, index)
    local p = FindProfile(id)
    if p and p.conditions[index] then table.remove(p.conditions, index); Changed(self) end
end

function FP:SetMember(id, veKey, isMember)
    local p = FindProfile(id)
    if not p then return end
    p.members[veKey] = isMember and true or nil
    Changed(self)
end

function FP:IsMember(id, veKey)
    local p = FindProfile(id)
    return p and p.members[veKey] or false
end

-- [ EVENT RE-EVALUATION ]----------------------------------------------------------------------------
local pending
local function ScheduleRecompute()
    if pending then return end
    pending = true
    C_Timer.After(RECOMPUTE_DEBOUNCE, function()
        pending = false
        FP:Recompute()
    end)
end

local eventFrame = CreateFrame("Frame")
local RE_EVAL_EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "GROUP_ROSTER_UPDATE", "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_SHAPESHIFT_FORM", "UPDATE_STEALTH",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING", "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE",
    "PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "PLAYER_DEAD",
    "PLAYER_ALIVE", "PLAYER_UNGHOST", "WALK_IN_DATA_UPDATE", "ACTIVE_DELVE_DATA_UPDATE",
}
for _, event in ipairs(RE_EVAL_EVENTS) do eventFrame:RegisterEvent(event) end
eventFrame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
eventFrame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
eventFrame:RegisterUnitEvent("UNIT_PET", "player")
eventFrame:SetScript("OnEvent", ScheduleRecompute)

-- [flying]/[swimming] have no triggering event; poll on a throttled OnUpdate only while an enabled profile uses them (mirrors Blizzard's secure state-driver 0.2s rescan), toggled by Recompute via NeedsMovementPoll.
local POLL_THROTTLE = 0.2
movementPoll = CreateFrame("Frame")
movementPoll:Hide()
movementPoll._elapsed = 0
movementPoll:SetScript("OnShow", function(self) self._lastFly, self._lastSwim = nil, nil end)
-- The poll is shown by config, not by being airborne, so only Recompute when flying/swimming actually flips (mirrors Blizzard's state-driver newValue~=oldValue gate); otherwise it is two cheap C calls per tick.
movementPoll:SetScript("OnUpdate", function(self, elapsed)
    self._elapsed = self._elapsed + elapsed
    if self._elapsed < POLL_THROTTLE then return end
    self._elapsed = 0
    local fly, swim = IsFlying(), IsSwimming()
    if fly == self._lastFly and swim == self._lastSwim then return end
    self._lastFly, self._lastSwim = fly, swim
    FP:Recompute()
end)

-- Fold the legacy split model (separate "linked" condition + true/false mouseover states) into the mouseover condition's separate/group state. Idempotent.
local function MigrateProfiles(db)
    for _, p in ipairs(db.profiles) do
        local linkedOn, moCond, kept = false, nil, {}
        for _, c in ipairs(p.conditions) do
            if c.key == "linked" then
                if c.state ~= "false" then linkedOn = true end
            else
                kept[#kept + 1] = c
                if c.key == "mouseover" then moCond = c end
            end
        end
        p.conditions = kept
        if moCond and moCond.state ~= "separate" and moCond.state ~= "group" then
            moCond.state = linkedOn and "group" or "separate"
        elseif moCond and linkedOn then
            moCond.state = "group"
        end
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(0.5, function()
        local db = GetDB()
        if db then MigrateProfiles(db) end
        FP:Recompute()
    end)
end)

-- Profiles persist at the OrbitDB root (account-wide). Re-apply caps on profile switch in case member frames were rebuilt.
C_Timer.After(0, function()
    if Orbit.EventBus then Orbit.EventBus:On("ORBIT_PROFILE_CHANGED", function() FP:Recompute() end) end
end)
