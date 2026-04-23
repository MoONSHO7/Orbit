-- [ MATCHER ]---------------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Matcher = {}
Orbit.Spotlight.Search.Matcher = Matcher

local string_find = string.find
local string_len = string.len
local table_sort = table.sort
local table_insert = table.insert

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local SCORE_EXACT       = 1000
local SCORE_PREFIX      = 500
local SCORE_WORD_START  = 250
local SCORE_SUBSTRING   = 100
local SCORE_CATEGORY    = 100
local FUZZY_MAX_GAPS    = 3
local FUZZY_SCORE_BASE  = 50
-- Favourite and recency bonuses sit on top of the name-match score so they influence ordering within a
-- score tier without overpowering strong name matches. Recency scales by MRU position (index 1 = biggest).
local SCORE_FAVORITE    = 15
local SCORE_RECENT_BASE = 40
local KIND_PRIORITY     = {
    macros = 12, equipped = 11, bags = 10, questitems = 9, spellbook = 8,
    professions = 7, toys = 6, mounts = 5, pets = 4, heirlooms = 3,
    currencies = 2,
}

-- [ CATEGORY TOKEN MAP ]----------------------------------------------------------------------------
-- Maps user-typed category labels (folded) to internal kind keys. Built lazily from localization so the
-- map stays in sync with the PLU_SPT_SRC_* strings that label checkboxes and result rows.
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

-- Pulls a category prefix off the query. Matches exact category tokens AND prefixes (min 3 chars) as long as
-- the prefix uniquely resolves to one category — so "mount"/"mou" both hit "mounts", but "m" (ambiguous with
-- macros) falls through to normal search. Two-word labels like "quest items" take priority over one-word prefixes.
local CATEGORY_MIN_PREFIX = 3

local function MatchToken(word)
    local tokens = EnsureCategoryTokens()
    if tokens[word] then return tokens[word] end
    if #word < CATEGORY_MIN_PREFIX then return nil end
    local only
    for tok, kind in pairs(tokens) do
        if tok:sub(1, #word) == word then
            if only and only ~= kind then return nil end
            only = kind
        end
    end
    return only
end

-- Word order is irrelevant: "pets human" and "human pets" both filter to pets + name "human". We scan
-- every word (and pair of adjacent words for the multi-word "quest items" label), consume the first
-- word that resolves to a category, and join the remainder as the name query.
local function ExtractCategoryPrefix(query)
    local words = {}
    for word in query:gmatch("%S+") do words[#words + 1] = word end

    for i = 1, #words - 1 do
        local pair = words[i] .. " " .. words[i + 1]
        local kind = MatchToken(pair)
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

-- [ SCORING ]---------------------------------------------------------------------------------------
-- Cheap pass: exact > prefix > word-boundary > substring. Fuzzy only runs when fuzzy=true and no substring hit.
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

-- [ PUBLIC ]----------------------------------------------------------------------------------------
-- Query can be either a name substring or a category-prefix + optional name filter ("mounts", "mounts swift").
-- When the user types a bare category name with no drill-down, every entry of that kind is returned, sorted
-- alphabetically so the list behaves like browsing the category rather than searching it.
-- Applies favourite + recency bonuses on top of the base match score. Kept out of ScoreEntry so the
-- core substring/fuzzy grading stays query-shape-agnostic.
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
        local qlen = string_len(effectiveQuery)
        for i = 1, #entries do
            local entry = entries[i]
            local passKind = kindFilter and (entry.kind == kindFilter) or (not kindFilter and enabledKinds[entry.kind])
            if passKind and enabledKinds[entry.kind] and not (hidePassives and entry.passive) then
                local score = ScoreEntry(effectiveQuery, qlen, entry, fuzzy)
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
