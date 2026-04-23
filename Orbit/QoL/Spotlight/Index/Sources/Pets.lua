-- [ PETS SOURCE ]-----------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

local Pets = {
    kind = "pets",
    events = { "PET_JOURNAL_LIST_UPDATE", "NEW_PET_ADDED" },
    persistent = true,
}
Sources.pets = Pets

function Pets:signature()
    local owned = C_PetJournal.GetNumPets()
    return owned or 0
end

function Pets:Build()
    local entries = {}
    local owned = C_PetJournal.GetNumPets() or 0
    local seenSpecies = {}
    for i = 1, owned do
        local petID, speciesID, isOwned, customName, _, isFavorite, _, name, icon, petType = C_PetJournal.GetPetInfoByIndex(i)
        if isOwned and petID and name and not seenSpecies[speciesID] then
            seenSpecies[speciesID] = true
            local displayName = customName or name
            -- Fold the localized pet family (Dragonkin, Humanoid, Beast, etc.) into lowerName so a query like
            -- "pets dragon" substring-matches "dragonkin" in the tag region after the category prefix is consumed.
            local folded = Tokenize:Fold(displayName)
            local familyName = petType and _G["BATTLE_PET_NAME_" .. petType]
            if familyName then folded = folded .. " " .. Tokenize:Fold(familyName) end
            entries[#entries + 1] = {
                kind = "pets",
                id = speciesID,
                petGUID = petID,
                name = displayName,
                lowerName = folded,
                icon = icon,
                favorite = isFavorite,
                secure = { type = "macro", macrotext = "/run C_PetJournal.SummonPetByGUID(\"" .. petID .. "\")" },
            }
        end
    end
    return entries
end
