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

-- isFavorite is only exposed via the displayed list — so journal filter state can hide favourites from the boost; acceptable vs. mutating filter state.
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
            -- Fold capability tags into lowerName so "mounts flying" matches via substring.
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
