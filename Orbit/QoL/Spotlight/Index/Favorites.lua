-- [ FAVORITES ]--------------------------------------------------------------------------------------
local _, Orbit = ...
local Favorites = {}
Orbit.Spotlight.Index.Favorites = Favorites

local SUPPORTED = { mounts = true, pets = true, toys = true }

-- C_MountJournal.SetIsFavorite is index-based on the displayed list (filter-dependent), not mountID.
-- canFavorite is false for restricted mounts (e.g. faction-specific on the wrong faction).
local function ToggleMount(entry, value)
    for i = 1, C_MountJournal.GetNumDisplayedMounts() do
        local _, _, _, _, _, _, _, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(i)
        if mountID == entry.id then
            local _, canFavorite = C_MountJournal.GetIsFavorite(i)
            if not canFavorite then return false end
            C_MountJournal.SetIsFavorite(i, value)
            return true
        end
    end
    return false
end

local function TogglePet(entry, value)
    C_PetJournal.SetFavorite(entry.petGUID, value and 1 or 0)
    return true
end

local function ToggleToy(entry, value)
    C_ToyBox.SetIsFavorite(entry.id, value)
    return true
end

local TOGGLERS = { mounts = ToggleMount, pets = TogglePet, toys = ToggleToy }

function Favorites:IsSupported(kind) return SUPPORTED[kind] == true end

function Favorites:Toggle(entry)
    if not SUPPORTED[entry.kind] then return nil end
    local newValue = not entry.favorite
    if not TOGGLERS[entry.kind](entry, newValue) then return nil end
    entry.favorite = newValue
    return newValue
end
