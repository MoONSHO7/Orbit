-- [ MATCHER ]----------------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Matcher = {}
Orbit.Spotlight.Search.Matcher = Matcher

local string_find = string.find
local string_len = string.len
local table_sort = table.sort
local table_insert = table.insert

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SCORE_EXACT       = 1000
local SCORE_PREFIX      = 500
local SCORE_WORD_START  = 250
local SCORE_SUBSTRING   = 100
local SCORE_CATEGORY    = 100
local FUZZY_MAX_GAPS    = 3
local FUZZY_SCORE_BASE  = 50
local SCORE_FAVORITE    = 15
local SCORE_RECENT_BASE = 40
local KIND_PRIORITY     = {
    macros = 12, equipped = 11, bags = 10, questitems = 9, spellbook = 8,
    professions = 7, toys = 6, mounts = 5, pets = 4, heirlooms = 3,
    currencies = 2,
}

-- [ CATEGORY TOKEN MAP ]-----------------------------------------------------------------------------
-- Built lazily so localization is loaded before we fold label strings.
local categoryTokens
local function EnsureCategoryTokens()
    if categoryTokens then return categoryTokens end
    local L = Orbit.L
    categoryTokens = {}
    for _, k in ipairs(Orbit.Spotlight.Kinds) do
        categoryTokens[k.kind] = k.kind
        local label = L[k.labelKey]
        if label then categoryTokens[Tokenize:Fold(label)] = k.kind end
    end
    return categoryTokens
end

-- Longest-common-prefix match on category labels. Tolerates plurals ("spells"→"spellbook") and
-- short typos; ambiguous ties fall through to name search.
local CATEGORY_MIN_PREFIX = 3

local function LongestCommonPrefix(a, b)
    local n = math.min(#a, #b)
    for i = 1, n do
        if a:byte(i) ~= b:byte(i) then return i - 1 end
    end
    return n
end

local function MatchToken(word, requireMultiWordToken)
    local tokens = EnsureCategoryTokens()
    if tokens[word] then return tokens[word] end
    if #word < CATEGORY_MIN_PREFIX then return nil end
    local winner, bestLCP, ambiguous = nil, 0, false
    for tok, kind in pairs(tokens) do
        if not requireMultiWordToken or tok:find(" ", 1, true) then
            local lcp = LongestCommonPrefix(word, tok)
            if lcp >= CATEGORY_MIN_PREFIX then
                if lcp > bestLCP then
                    winner, bestLCP, ambiguous = kind, lcp, false
                elseif lcp == bestLCP and winner ~= kind then
                    ambiguous = true
                end
            end
        end
    end
    if ambiguous then return nil end
    return winner
end

-- Scans word pairs first so multi-word labels ("quest items") beat single-word prefixes.
local function ExtractCategoryPrefix(query)
    local words = {}
    for word in query:gmatch("%S+") do words[#words + 1] = word end

    for i = 1, #words - 1 do
        local pair = words[i] .. " " .. words[i + 1]
        local kind = MatchToken(pair, true)
        if kind then
            local rest = {}
            for j = 1, #words do
                if j ~= i and j ~= i + 1 then rest[#rest + 1] = words[j] end
            end
            return kind, table.concat(rest, " ")
        end
    end

    for i = 1, #words do
        local kind = MatchToken(words[i])
        if kind then
            local rest = {}
            for j = 1, #words do
                if j ~= i then rest[#rest + 1] = words[j] end
            end
            return kind, table.concat(rest, " ")
        end
    end

    return nil, query
end

-- [ SCORING ]----------------------------------------------------------------------------------------
local function ScoreEntry(query, qlen, entry, fuzzy)
    local name = entry.lowerName
    if not name or name == "" then return 0 end
    if name == query then return SCORE_EXACT end

    local ps, pe = string_find(name, query, 1, true)
    if ps == 1 then return SCORE_PREFIX + (1000 - string_len(name)) end
    if ps then
        local prev = string.sub(name, ps - 1, ps - 1)
        if prev == " " or prev == "-" or prev == "'" then
            return SCORE_WORD_START + (1000 - string_len(name))
        end
        return SCORE_SUBSTRING + (1000 - string_len(name))
    end

    if fuzzy and qlen > 1 then
        local gaps = 0
        local cursor = 1
        local nlen = string_len(name)
        for i = 1, qlen do
            local ch = string.byte(query, i)
            local found
            for j = cursor, nlen do
                if string.byte(name, j) == ch then
                    if j > cursor then gaps = gaps + (j - cursor) end
                    cursor = j + 1
                    found = true
                    break
                end
            end
            if not found then return 0 end
            if gaps > FUZZY_MAX_GAPS * 4 then return 0 end
        end
        return FUZZY_SCORE_BASE - gaps
    end
    return 0
end

-- [ PUBLIC ]-----------------------------------------------------------------------------------------
local function ApplyBoosts(score, entry, recentBoost)
    if entry.favorite then score = score + SCORE_FAVORITE end
    if recentBoost then
        local pos = recentBoost[entry.kind .. ":" .. tostring(entry.id)]
        if pos then score = score + SCORE_RECENT_BASE - (pos - 1) * 5 end
    end
    return score
end

function Matcher:Query(entries, query, enabledKinds, maxResults, fuzzy, hidePassives)
    if not query or query == "" then return {} end

    local kindFilter, nameQuery = ExtractCategoryPrefix(query)
    local results = {}
    local recentBoost = Orbit.Spotlight.Index.Recents and Orbit.Spotlight.Index.Recents:GetBoostIndex() or nil

    if kindFilter and nameQuery == "" then
        for i = 1, #entries do
            local entry = entries[i]
            if entry.kind == kindFilter and enabledKinds[entry.kind] and not (hidePassives and entry.passive) then
                table_insert(results, { entry = entry, score = ApplyBoosts(SCORE_CATEGORY, entry, recentBoost) })
            end
        end
    else
        local effectiveQuery = nameQuery ~= "" and nameQuery or query
        local queryWords = {}
        for w in effectiveQuery:gmatch("%S+") do queryWords[#queryWords + 1] = w end
        if #queryWords == 0 then return {} end
        for i = 1, #entries do
            local entry = entries[i]
            local passKind = kindFilter and (entry.kind == kindFilter) or (not kindFilter and enabledKinds[entry.kind])
            if passKind and enabledKinds[entry.kind] and not (hidePassives and entry.passive) then
                -- Every word must hit (AND semantics); sum scores so strong matches on multiple words rank higher.
                local score = 0
                for _, w in ipairs(queryWords) do
                    local s = ScoreEntry(w, #w, entry, fuzzy)
                    if s == 0 then score = 0; break end
                    score = score + s
                end
                if score > 0 then
                    table_insert(results, { entry = entry, score = ApplyBoosts(score, entry, recentBoost) })
                end
            end
        end
    end

    table_sort(results, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        local pa = KIND_PRIORITY[a.entry.kind] or 0
        local pb = KIND_PRIORITY[b.entry.kind] or 0
        if pa ~= pb then return pa > pb end
        return a.entry.lowerName < b.entry.lowerName
    end)

    local out = {}
    local limit = math.min(maxResults or 25, #results)
    for i = 1, limit do out[i] = results[i].entry end
    return out
end
