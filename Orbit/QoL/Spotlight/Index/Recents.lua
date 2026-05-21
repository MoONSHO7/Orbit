-- [ RECENTS ]----------------------------------------------------------------------------------------
-- MRU list (last N activations) persisted to AccountSettings; matcher reads GetBoostIndex() so recent picks rank higher on re-search.
local _, Orbit = ...
local Recents = {}
Orbit.Spotlight.Index.Recents = Recents

local MAX_ENTRIES = 5

-- [ STORE ]------------------------------------------------------------------------------------------
local function GetList()
    local acct = Orbit.db.AccountSettings
    acct.SpotlightRecents = acct.SpotlightRecents or {}
    return acct.SpotlightRecents
end

local function MakeKey(kind, id) return kind .. ":" .. tostring(id) end

-- [ PUBLIC ]-----------------------------------------------------------------------------------------
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

-- { [key] = rank } where 1 = most recent — matcher scales recency bonus so latest out-ranks older.
function Recents:GetBoostIndex()
    local list = GetList()
    local boost = {}
    for i, key in ipairs(list) do boost[key] = i end
    return boost
end

