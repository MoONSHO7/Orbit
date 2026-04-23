-- [ MACROS SOURCE ]---------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

local MAX_GLOBAL = 120
local MAX_CHAR = 138

local Macros = {
    kind = "macros",
    events = { "UPDATE_MACROS" },
    persistent = false,
}
Sources.macros = Macros

function Macros:Build()
    local entries = {}
    local global, perChar = GetNumMacros()
    global = global or 0
    perChar = perChar or 0

    for i = 1, global do
        local name, iconID = GetMacroInfo(i)
        if name then
            entries[#entries + 1] = {
                kind = "macros",
                id = i,
                name = name,
                lowerName = Tokenize:Fold(name),
                icon = iconID,
                secure = { type = "macro", macro = i },
            }
        end
    end

    local charStart = MAX_GLOBAL + 1
    for i = charStart, charStart + perChar - 1 do
        local name, iconID = GetMacroInfo(i)
        if name then
            entries[#entries + 1] = {
                kind = "macros",
                id = i,
                name = name,
                lowerName = Tokenize:Fold(name),
                icon = iconID,
                secure = { type = "macro", macro = i },
            }
        end
    end
    return entries
end
