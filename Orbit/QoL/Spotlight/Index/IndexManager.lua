-- [ INDEX MANAGER ]---------------------------------------------------------------------------------
local _, Orbit = ...
local IndexManager = {}
Orbit.Spotlight.Index.IndexManager = IndexManager

local Sources = Orbit.Spotlight.Index.Sources
local Async = Orbit.Async

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local DEBOUNCE_KEY = "Spotlight.IndexInvalidate"
local DEBOUNCE_DELAY = 0.5
-- Bump whenever the schema of cached entries changes so stale serialised entries don't shadow new fields.
-- v3 — mount capability tags reworked: "flying" is now the default tag, with explicit overrides only for
-- ground / aquatic / ridealong. Dragonriding-capable mounts get an additional "skyriding" sub-tag.
-- v4 — heirlooms no longer carry the `passive` flag (Hide Passives filter is now spellbook-only); the
-- passive toggle shouldn't retroactively hide heirlooms that were tagged under the old schema.
-- v5 — mounts/pets now carry `favorite` and heirlooms carry `quality`; previously-serialised entries
-- missing those fields would silently deprioritise favourites and lose quality-tinted labels.
local CACHE_VERSION = 5

-- [ STATE ]-----------------------------------------------------------------------------------------
IndexManager._master = {}
IndexManager._sourceDirty = {}
IndexManager._eventFrame = nil
IndexManager._registered = false
IndexManager._built = false

-- [ CACHE ]-----------------------------------------------------------------------------------------
local function GetCacheStore()
    local acct = Orbit.db.AccountSettings
    acct.SpotlightIndex = acct.SpotlightIndex or { version = CACHE_VERSION, sources = {} }
    if acct.SpotlightIndex.version ~= CACHE_VERSION then
        acct.SpotlightIndex = { version = CACHE_VERSION, sources = {} }
    end
    return acct.SpotlightIndex.sources
end

local function LoadCachedSource(name)
    return GetCacheStore()[name]
end

local function SaveCachedSource(name, entries, signature)
    GetCacheStore()[name] = { entries = entries, signature = signature }
end

-- [ EVENTS ]----------------------------------------------------------------------------------------
local function OnEvent(_, event)
    local names = {}
    for name, source in pairs(Sources) do
        if source.events then
            for _, e in ipairs(source.events) do
                if e == event then names[#names + 1] = name; break end
            end
        end
    end
    for _, name in ipairs(names) do
        IndexManager._sourceDirty[name] = true
    end
    if #names > 0 then
        Async:Debounce(DEBOUNCE_KEY, function() IndexManager:Rebuild() end, DEBOUNCE_DELAY)
    end
end

function IndexManager:RegisterEvents()
    if self._registered then return end
    self._registered = true
    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame")
        self._eventFrame:SetScript("OnEvent", OnEvent)
    end
    for _, source in pairs(Sources) do
        if source.events then
            for _, event in ipairs(source.events) do
                self._eventFrame:RegisterEvent(event)
            end
        end
    end
end

function IndexManager:UnregisterEvents()
    if not self._registered then return end
    self._registered = false
    if self._eventFrame then self._eventFrame:UnregisterAllEvents() end
end

-- [ BUILD ]-----------------------------------------------------------------------------------------
-- Persistent sources only write to cache when their signature changes; volatile ones always rebuild.
function IndexManager:EnsureBuilt(enabledKinds)
    if self._built and not next(self._sourceDirty) then return end
    self:Rebuild(enabledKinds)
end

function IndexManager:Rebuild(enabledKinds)
    local master = {}
    local counts = {}
    for name, source in pairs(Sources) do
        if not enabledKinds or enabledKinds[name] then
            local entries
            if source.persistent then
                local sig = source.signature and source:signature() or 0
                local cached = LoadCachedSource(name)
                if cached and cached.signature == sig and not self._sourceDirty[name] then
                    entries = cached.entries
                else
                    local ok, built = pcall(function() return source:Build() end)
                    entries = ok and built or {}
                    if ok then SaveCachedSource(name, entries, sig) end
                end
            else
                local ok, built = pcall(function() return source:Build() end)
                entries = ok and built or {}
            end
            counts[name] = #entries
            for i = 1, #entries do master[#master + 1] = entries[i] end
        end
        self._sourceDirty[name] = nil
    end
    self._master = master
    self._lastCounts = counts
    self._built = true
end

function IndexManager:GetLastCounts() return self._lastCounts or {} end

function IndexManager:GetMaster()
    return self._master
end

function IndexManager:InvalidateAll()
    for name in pairs(Sources) do self._sourceDirty[name] = true end
    self._built = false
end
