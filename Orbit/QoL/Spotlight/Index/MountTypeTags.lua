-- [ MOUNT TYPE TAGS ]--------------------------------------------------------------------------------
-- Maps the creature mountTypeID (returned by C_MountJournal.GetMountInfoExtraByID) to capability tag
-- words that the matcher folds into lowerName so queries like "mounts flying" / "mounts aquatic" work.
--
-- Blizzard's mount journal now surfaces only four filters (Ground / Flying / Aquatic / Ride Along) but
-- does not expose a public mountTypeID → filter mapping. Rather than enumerate every flying creature
-- type ID across expansions (error-prone when patches add new ones), we explicit-list the non-flying
-- IDs and default everything else to "flying". Dragonriding-capable mounts are additionally tagged
-- "skyriding" via the authoritative C_MountJournal.GetCollectedDragonridingMounts lookup.
local _, Orbit = ...
local Tags = {}
Orbit.Spotlight.Index.MountTypeTags = Tags

Tags.EXPLICIT = {
    [230] = "ground",
    [231] = "aquatic",
    [232] = "aquatic",
    [254] = "aquatic",
    [269] = "ground",
    [284] = "ridealong",
    [412] = "aquatic",
    -- 247 / 248 are the legacy "flying + ground" creature types; covered by the flying default below.
}

local function BuildDragonridingSet()
    local set = {}
    if C_MountJournal.GetCollectedDragonridingMounts then
        local ids = C_MountJournal.GetCollectedDragonridingMounts() or {}
        for _, id in ipairs(ids) do set[id] = true end
    end
    return set
end

Tags._dragonridingSet = nil

function Tags:RefreshDragonriding()
    self._dragonridingSet = BuildDragonridingSet()
end

function Tags:ForMount(mountID)
    if not mountID then return nil end
    if not self._dragonridingSet then self:RefreshDragonriding() end
    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    -- Default to "flying" when the creature type isn't explicitly ground/aquatic/ridealong.
    local base = (mountTypeID and self.EXPLICIT[mountTypeID]) or "flying"
    if self._dragonridingSet[mountID] then base = base .. " skyriding" end
    return base
end
