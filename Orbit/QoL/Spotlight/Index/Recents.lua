-- [ RECENTS ]---------------------------------------------------------------------------------------
-- Tracks the last N activated entries as an MRU (most-recently-used) list persisted to AccountSettings.
-- The matcher reads GetBoostIndex() to bonus-score matching entries so users' recent choices bubble up
-- when they re-search the same term.
local _, Orbit = ...
local Recents = {}
Orbit.Spotlight.Index.Recents = Recents

local MAX_ENTRIES = 5

-- [ STORE ]-----------------------------------------------------------------------------------------
local function GetList()
    local acct = Orbit.db.AccountSettings
    acct.SpotlightRecents = acct.SpotlightRecents or {}
    return acct.SpotlightRecents
end

local function MakeKey(kind, id) return kind .. ":" .. tostring(id) end

-- [ PUBLIC ]----------------------------------------------------------------------------------------
-- Pushes an entry to the front. Removes a prior occurrence so the list stays deduped at MAX_ENTRIES.
function Recents:Record(entry)
    if not entry or not entry.kind or entry.id == nil then return end
    local key = MakeKey(entry.kind, entry.id)
    local list = GetList()
    for i = #list, 1, -1 do
        if list[i] == key then table.remove(list, i) end
    end
    table.insert(list, 1, key)
    while #list > MAX_ENTRIES do table.remove(list) end
end

-- Returns a map { [key] = position } where position is the 1-based rank (1 = most recent). The matcher
-- uses the position to scale the recency bonus so the very latest entry out-ranks older recents.
function Recents:GetBoostIndex()
    local list = GetList()
    local boost = {}
    for i, key in ipairs(list) do boost[key] = i end
    return boost
end

function Recents:BuildKey(kind, id) return MakeKey(kind, id) end

function Recents:MaxEntries() return MAX_ENTRIES end
