---@type Orbit
local Orbit = Orbit

Orbit.GroupFrameHelpers = {}
local Helpers = Orbit.GroupFrameHelpers
local Pixel = Orbit.Engine.Pixel

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local MAX_GROUP_FRAMES = 40
local MAX_RAID_GROUPS = 8
local FRAMES_PER_GROUP = 5

Helpers.LAYOUT = {
    MaxGroupFrames = MAX_GROUP_FRAMES,
    MaxRaidGroups = MAX_RAID_GROUPS,
    FramesPerGroup = FRAMES_PER_GROUP,
    MemberSpacing = 1,
    GroupSpacing = 4,
    PowerBarRatio = 0.1,
    DefaultWidth = 100,
    DefaultHeight = 40,
    AuraBaseIconSize = 10,
}

local GF = Orbit.Constants.GroupFrames

Helpers.GROWTH_DIRECTION = GF.GrowthDirection

local SORT_MODE = { Group = "group", Role = "role", Alphabetical = "alphabetical" }
Helpers.SORT_MODE = SORT_MODE
local ROLE_PRIORITY = GF.RolePriority

-- [ TIER SYSTEM ]------------------------------------------------------------------------------------
local TIER_PARTY = "Party"
local TIER_MYTHIC = "Mythic"
local TIER_HEROIC = "Heroic"
local TIER_WORLD = "World"

Helpers.TIERS = { TIER_PARTY, TIER_MYTHIC, TIER_HEROIC, TIER_WORLD }
Helpers.TIER_LABELS = {
    [TIER_PARTY] = "Party (1-5)",
    [TIER_MYTHIC] = "Mythic (1-20)",
    [TIER_HEROIC] = "Heroic (1-30)",
    [TIER_WORLD] = "World (1-40)",
}

function Helpers:GetTierForGroupSize(numMembers, isInRaid, instanceMaxPlayers)
    if not isInRaid then return TIER_PARTY end
    -- Instance ceiling: clamp effective size to the instance's max player cap
    if instanceMaxPlayers and instanceMaxPlayers > 0 then
        local effective = math.min(numMembers, instanceMaxPlayers)
        if effective <= 20 then return TIER_MYTHIC end
        if effective <= 30 then return TIER_HEROIC end
        return TIER_WORLD
    end
    if numMembers <= 20 then return TIER_MYTHIC end
    if numMembers <= 30 then return TIER_HEROIC end
    return TIER_WORLD
end

function Helpers:IsPartyTier(tier) return tier == TIER_PARTY end

local TIER_MAX_FRAMES = {
    [TIER_PARTY] = 5, [TIER_MYTHIC] = 20,
    [TIER_HEROIC] = 30, [TIER_WORLD] = 40,
}
function Helpers:GetTierMaxFrames(tier) return TIER_MAX_FRAMES[tier] or MAX_GROUP_FRAMES end

-- [ ANCHOR ]-----------------------------------------------------------------------------------------
local CONTAINER_ANCHOR = {
    ["down"] = "TOPLEFT",
    ["up"] = "BOTTOMLEFT",
    ["right"] = "TOPLEFT",
    ["left"] = "TOPRIGHT",
    ["center"] = "CENTER",
}

function Helpers:GetContainerAnchor(growthDirection) return CONTAINER_ANCHOR[growthDirection] or "TOPLEFT" end

-- [ AURA ANCHOR HELPER ]-----------------------------------------------------------------------------
-- "Right" here is a PositionUtils anchor token, NOT a GrowthDirection value. Keep capitalized.
function Helpers:AnchorToPosition(posX, posY, halfW, halfH)
    return Orbit.Engine.PositionUtils.AnchorToPosition(posX, posY, halfW, halfH, "Right")
end

-- [ PARTY-STYLE LAYOUT (simple list) ]---------------------------------------------------------------
function Helpers:CalculatePartyContainerSize(numFrames, frameWidth, frameHeight, spacing, orientation, scale)
    spacing = scale and Pixel:Multiple(spacing or 0, scale) or (spacing or 0)
    orientation = orientation or 0
    numFrames = math.max(1, numFrames)
    if orientation == 0 then
        return frameWidth, (numFrames * frameHeight) + ((numFrames - 1) * spacing)
    end
    return (numFrames * frameWidth) + ((numFrames - 1) * spacing), frameHeight
end

function Helpers:CalculatePartyFramePosition(index, frameWidth, frameHeight, spacing, orientation, growthDirection, scale)
    spacing = scale and Pixel:Multiple(spacing or 0, scale) or (spacing or 0)
    orientation = orientation or 0
    growthDirection = growthDirection or (orientation == 0 and "down" or "right")
    local step = orientation == 0 and (frameHeight + spacing) or (frameWidth + spacing)
    local offset = scale and Pixel:Snap((index - 1) * step, scale) or ((index - 1) * step)
    if growthDirection == "down" then return 0, -offset, "TOPLEFT", "TOPLEFT" end
    if growthDirection == "up" then return 0, offset, "BOTTOMLEFT", "BOTTOMLEFT" end
    if growthDirection == "right" then return offset, 0, "TOPLEFT", "TOPLEFT" end
    if growthDirection == "left" then return -offset, 0, "TOPRIGHT", "TOPRIGHT" end
    if growthDirection == "center" then
        if orientation == 0 then return 0, -offset, "TOPLEFT", "TOPLEFT" end
        return offset, 0, "TOPLEFT", "TOPLEFT"
    end
    return 0, -offset, "TOPLEFT", "TOPLEFT"
end

-- [ RAID-STYLE LAYOUT (group grid) ]-----------------------------------------------------------------
function Helpers:CalculateRaidContainerSize(numGroups, numPerGroup, frameWidth, frameHeight, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, scale)
    memberSpacing = scale and Pixel:Multiple(memberSpacing or self.LAYOUT.MemberSpacing, scale) or (memberSpacing or self.LAYOUT.MemberSpacing)
    groupSpacing = scale and Pixel:Multiple(groupSpacing or self.LAYOUT.GroupSpacing, scale) or (groupSpacing or self.LAYOUT.GroupSpacing)
    numGroups = math.max(1, numGroups)
    numPerGroup = math.max(1, numPerGroup)
    groupsPerRow = math.max(1, math.min(groupsPerRow or numGroups, numGroups))
    if isHorizontal then
        local memberExtent = (numPerGroup * frameWidth) + ((numPerGroup - 1) * memberSpacing)
        local numRows = groupsPerRow
        local numCols = math.ceil(numGroups / groupsPerRow)
        return (numCols * memberExtent) + ((numCols - 1) * groupSpacing), (numRows * frameHeight) + ((numRows - 1) * groupSpacing)
    end
    local numCols = groupsPerRow
    local numRows = math.ceil(numGroups / groupsPerRow)
    local memberExtent = (numPerGroup * frameHeight) + ((numPerGroup - 1) * memberSpacing)
    return (numCols * frameWidth) + ((numCols - 1) * groupSpacing), (numRows * memberExtent) + ((numRows - 1) * groupSpacing)
end

function Helpers:CalculateGroupPosition(groupIndex, frameWidth, frameHeight, numPerGroup, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, scale)
    memberSpacing = scale and Pixel:Multiple(memberSpacing or self.LAYOUT.MemberSpacing, scale) or (memberSpacing or self.LAYOUT.MemberSpacing)
    groupSpacing = scale and Pixel:Multiple(groupSpacing or self.LAYOUT.GroupSpacing, scale) or (groupSpacing or self.LAYOUT.GroupSpacing)
    groupsPerRow = groupsPerRow or 6
    if isHorizontal then
        local memberExtent = (numPerGroup * frameWidth) + ((numPerGroup - 1) * memberSpacing)
        local row = (groupIndex - 1) % groupsPerRow
        local col = math.floor((groupIndex - 1) / groupsPerRow)
        local gx = scale and Pixel:Snap(col * (memberExtent + groupSpacing), scale) or (col * (memberExtent + groupSpacing))
        local gy = scale and Pixel:Snap(row * (frameHeight + groupSpacing), scale) or (row * (frameHeight + groupSpacing))
        return gx, -gy
    end
    local col = (groupIndex - 1) % groupsPerRow
    local row = math.floor((groupIndex - 1) / groupsPerRow)
    local memberExtent = (numPerGroup * frameHeight) + ((numPerGroup - 1) * memberSpacing)
    local gx = scale and Pixel:Snap(col * (frameWidth + groupSpacing), scale) or (col * (frameWidth + groupSpacing))
    local gy = scale and Pixel:Snap(row * (memberExtent + groupSpacing), scale) or (row * (memberExtent + groupSpacing))
    return gx, -gy
end

function Helpers:CalculateMemberPosition(memberIndex, frameWidth, frameHeight, memberSpacing, memberGrowth, isHorizontal, scale)
    memberSpacing = scale and Pixel:Multiple(memberSpacing or self.LAYOUT.MemberSpacing, scale) or (memberSpacing or self.LAYOUT.MemberSpacing)
    if isHorizontal then
        local mx = scale and Pixel:Snap((memberIndex - 1) * (frameWidth + memberSpacing), scale) or ((memberIndex - 1) * (frameWidth + memberSpacing))
        return mx, 0
    end
    local offset = scale and Pixel:Snap((memberIndex - 1) * (frameHeight + memberSpacing), scale) or ((memberIndex - 1) * (frameHeight + memberSpacing))
    if memberGrowth == "up" then return 0, offset end
    return 0, -offset
end

-- [ POWER BAR LAYOUT ]-------------------------------------------------------------------------------
function Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar, powerBarRatio)
    Orbit.UnitFrameMixin:UpdateFrameLayout(frame, borderSize, { showPowerBar = showPowerBar, powerBarRatio = powerBarRatio or self.LAYOUT.PowerBarRatio })
end

-- [ SORTING ]----------------------------------------------------------------------------------------
local _sortedUnits = {}
local _unitDataPool = {}

function Helpers:GetSortedRaidUnits(sortMode)
    for i = 1, #_sortedUnits do _sortedUnits[i] = nil end
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return _sortedUnits end
    local poolIdx = 0
    for i = 1, numMembers do
        local name, _, subgroup, _, _, className, _, online, isDead, role = GetRaidRosterInfo(i)
        if name then
            poolIdx = poolIdx + 1
            local entry = _unitDataPool[poolIdx]
            if not entry then entry = {}; _unitDataPool[poolIdx] = entry end
            entry.token = "raid" .. i
            entry.rosterIndex = i; entry.name = name; entry.subgroup = subgroup
            entry.className = className; entry.online = online; entry.isDead = isDead
            entry.role = role or UnitGroupRolesAssigned("raid" .. i)
            _sortedUnits[#_sortedUnits + 1] = entry
        end
    end
    sortMode = sortMode or SORT_MODE.Group
    if sortMode == SORT_MODE.Role then
        table.sort(_sortedUnits, function(a, b)
            local pa, pb = ROLE_PRIORITY[a.role] or 4, ROLE_PRIORITY[b.role] or 4
            if pa ~= pb then return pa < pb end
            return (a.name or "") < (b.name or "")
        end)
    elseif sortMode == SORT_MODE.Alphabetical then
        table.sort(_sortedUnits, function(a, b) return (a.name or "") < (b.name or "") end)
    else
        table.sort(_sortedUnits, function(a, b)
            if a.subgroup ~= b.subgroup then return (a.subgroup or 1) < (b.subgroup or 1) end
            return (a.rosterIndex or 0) < (b.rosterIndex or 0)
        end)
    end
    return _sortedUnits
end

function Helpers:GetActiveGroups()
    local active = {}
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local _, _, subgroup = GetRaidRosterInfo(i)
        if subgroup then active[subgroup] = true end
    end
    return active
end

-- [ PARTY SORTING ]----------------------------------------------------------------------------------
local PARTY_UNITS = { "party1", "party2", "party3", "party4" }

local function GetRolePriority(unit)
    if not UnitExists(unit) then return 99 end
    return ROLE_PRIORITY[UnitGroupRolesAssigned(unit)] or 4
end

function Helpers:GetSortedPartyUnits(includePlayer)
    local units = {}
    if includePlayer then units[#units + 1] = "player" end
    for i = 1, 4 do
        if UnitExists(PARTY_UNITS[i]) then units[#units + 1] = PARTY_UNITS[i] end
    end
    if #units > 1 then
        table.sort(units, function(a, b)
            local priorityA, priorityB = GetRolePriority(a), GetRolePriority(b)
            if priorityA == priorityB then
                -- issecretvalue guards the legacy path; `or ""` handles nil from newer clients.
                local nameA, nameB = UnitName(a), UnitName(b)
                if issecretvalue(nameA) or issecretvalue(nameB) then return false end
                return (nameA or "") < (nameB or "")
            end
            return priorityA < priorityB
        end)
    end
    return units
end
