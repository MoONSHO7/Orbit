-- [ TOYS SOURCE ]-----------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

local Toys = {
    kind = "toys",
    events = { "TOYS_UPDATED" },
    persistent = true,
}
Sources.toys = Toys

function Toys:signature()
    return C_ToyBox.GetNumLearnedDisplayedToys and C_ToyBox.GetNumLearnedDisplayedToys() or (C_ToyBox.GetNumToys() or 0)
end

function Toys:Build()
    local entries = {}
    local count = C_ToyBox.GetNumToys() or 0
    for i = 1, count do
        local itemID = C_ToyBox.GetToyFromIndex(i)
        if itemID and itemID > 0 and PlayerHasToy(itemID) then
            local _, toyName, iconID = C_ToyBox.GetToyInfo(itemID)
            if toyName then
                entries[#entries + 1] = {
                    kind = "toys",
                    id = itemID,
                    name = toyName,
                    lowerName = Tokenize:Fold(toyName),
                    icon = iconID,
                    -- Macrotext instead of type="toy" because programmatic :Click() from our Enter-key
                    -- handler trips UseToy's protected-function guard. "/use item:<id>" routes through
                    -- the secure item handler and works for both hardware clicks and keyboard activation.
                    secure = { type = "macro", macrotext = "/use item:" .. itemID },
                }
            end
        end
    end
    return entries
end
