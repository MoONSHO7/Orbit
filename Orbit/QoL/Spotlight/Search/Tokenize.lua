-- [ TOKENIZE ]---------------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = {}
Orbit.Spotlight.Search.Tokenize = Tokenize

local string_lower = string.lower
local string_gsub = string.gsub

-- [ FOLD ]-------------------------------------------------------------------------------------------
-- Lowercase and strip common diacritics so "Corrupción" matches "corrupcion".
-- Caller invokes once at index time; per-search path only touches the precomputed lowerName.
local DIACRITIC_MAP = {
    ["à"]="a",["á"]="a",["â"]="a",["ã"]="a",["ä"]="a",["å"]="a",
    ["è"]="e",["é"]="e",["ê"]="e",["ë"]="e",
    ["ì"]="i",["í"]="i",["î"]="i",["ï"]="i",
    ["ò"]="o",["ó"]="o",["ô"]="o",["õ"]="o",["ö"]="o",
    ["ù"]="u",["ú"]="u",["û"]="u",["ü"]="u",
    ["ñ"]="n",["ç"]="c",["ß"]="ss",
    ["À"]="a",["Á"]="a",["Â"]="a",["Ã"]="a",["Ä"]="a",["Å"]="a",
    ["È"]="e",["É"]="e",["Ê"]="e",["Ë"]="e",
    ["Ì"]="i",["Í"]="i",["Î"]="i",["Ï"]="i",
    ["Ò"]="o",["Ó"]="o",["Ô"]="o",["Õ"]="o",["Ö"]="o",
    ["Ù"]="u",["Ú"]="u",["Û"]="u",["Ü"]="u",
    ["Ñ"]="n",["Ç"]="c",
}

function Tokenize:Fold(s)
    if not s or s == "" then return "" end
    local lowered = string_lower(s)
    return (string_gsub(lowered, "[%z\1-\127\194-\244][\128-\191]*", function(c) return DIACRITIC_MAP[c] or c end))
end
