-- [ MOUNTS SOURCE ]----------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

local Mounts = {
    kind = "mounts",
    events = { "NEW_MOUNT_ADDED", "COMPANION_LEARNED", "COMPANION_UNLEARNED" },
    persistent = true,
}
Sources.mounts = Mounts

function Mounts:signature()
    local ids = C_MountJournal.GetMountIDs()
    return ids and #ids or 0
end

-- Builds a { [mountID] = isFavorite } map by iterating the mount journal's *displayed* list, which is
-- the only place isFavorite is exposed. Depends on the player's journal filter state, so favourites
-- hidden behind filters won't get boosted — acceptable trade-off vs. mutating filter state here.
local function BuildFavoriteMap()
    local map = {}
    local numDisplayed = C_MountJournal.GetNumDisplayedMounts and C_MountJournal.GetNumDisplayedMounts() or 0
    for i = 1, numDisplayed do
        local _, _, _, _, _, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(i)
        if mountID then map[mountID] = isFavorite end
    end
    return map
end

function Mounts:Build()
    local entries = {}
    local ids = C_MountJournal.GetMountIDs()
    if not ids then return entries end
    local MountTypeTags = Orbit.Spotlight.Index.MountTypeTags
    MountTypeTags:RefreshDragonriding()
    local favoriteMap = BuildFavoriteMap()
    for _, mountID in ipairs(ids) do
        local name, _, icon, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        if name and isCollected then
            -- Fold mount capability tags ("flying"/"ground"/"aquatic"/"skyriding") into lowerName so that
            -- a query like "mounts flying" falls through the category prefix and substring-matches the tags.
            local folded = Tokenize:Fold(name)
            local tags = MountTypeTags:ForMount(mountID)
            if tags then folded = folded .. " " .. tags end
            entries[#entries + 1] = {
                kind = "mounts",
                id = mountID,
                name = name,
                lowerName = folded,
                icon = icon,
                favorite = favoriteMap[mountID] or false,
                secure = { type = "macro", macrotext = "/run C_MountJournal.SummonByID(" .. mountID .. ")" },
            }
        end
    end
    return entries
end
