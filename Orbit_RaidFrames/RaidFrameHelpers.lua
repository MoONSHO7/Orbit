---@type Orbit
local Orbit = Orbit

Orbit.RaidFrameHelpers = {}
local Helpers = Orbit.RaidFrameHelpers

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_RAID_FRAMES = 30
local MAX_RAID_GROUPS = 6
local FRAMES_PER_GROUP = 5

Helpers.LAYOUT = {
    MaxRaidFrames = MAX_RAID_FRAMES,
    MaxRaidGroups = MAX_RAID_GROUPS,
    FramesPerGroup = FRAMES_PER_GROUP,
    MemberSpacing = 1,
    GroupSpacing = 4,
    PowerBarRatio = 0.08,
    DefaultWidth = 90,
    DefaultHeight = 36,
    AuraBaseIconSize = 10,
}

Helpers.GROWTH_DIRECTION = { Down = "Down", Up = "Up", Left = "Left", Right = "Right" }

-- Derive aura display position from canvas mode position data
function Helpers:AnchorToPosition(posX, posY, halfW, halfH)
    return Orbit.Engine.PositionUtils.AnchorToPosition(posX, posY, halfW, halfH, "Right")
end

local CONTAINER_ANCHOR = { Down = "TOPLEFT", Up = "BOTTOMLEFT", Right = "TOPLEFT", Left = "TOPRIGHT" }

local SORT_MODE = { Group = "Group", Role = "Role", Alphabetical = "Alphabetical" }
Helpers.SORT_MODE = SORT_MODE

local ROLE_PRIORITY = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }

-- [ ANCHOR ]----------------------------------------------------------------------------------------

function Helpers:GetContainerAnchor(growthDirection)
    return CONTAINER_ANCHOR[growthDirection] or "TOPLEFT"
end

-- [ CONTAINER SIZING ]------------------------------------------------------------------------------

function Helpers:CalculateContainerSize(numGroups, numPerGroup, frameWidth, frameHeight, memberSpacing, groupSpacing, groupsPerRow, isHorizontal)
    memberSpacing = memberSpacing or self.LAYOUT.MemberSpacing
    groupSpacing = groupSpacing or self.LAYOUT.GroupSpacing
    numGroups = math.max(1, numGroups)
    numPerGroup = math.max(1, numPerGroup)
    groupsPerRow = math.max(1, math.min(groupsPerRow or numGroups, numGroups))
    if isHorizontal then
        local memberExtent = (numPerGroup * frameWidth) + ((numPerGroup - 1) * memberSpacing)
        local numRows = groupsPerRow
        local numCols = math.ceil(numGroups / groupsPerRow)
        local containerW = (numCols * memberExtent) + ((numCols - 1) * groupSpacing)
        local containerH = (numRows * frameHeight) + ((numRows - 1) * groupSpacing)
        return containerW, containerH
    end
    local numCols = groupsPerRow
    local numRows = math.ceil(numGroups / groupsPerRow)
    local memberExtent = (numPerGroup * frameHeight) + ((numPerGroup - 1) * memberSpacing)
    local containerW = (numCols * frameWidth) + ((numCols - 1) * groupSpacing)
    local containerH = (numRows * memberExtent) + ((numRows - 1) * groupSpacing)
    return containerW, containerH
end

-- [ FRAME POSITIONING ]-----------------------------------------------------------------------------

function Helpers:CalculateGroupPosition(groupIndex, frameWidth, frameHeight, numPerGroup, memberSpacing, groupSpacing, groupsPerRow, isHorizontal)
    memberSpacing = memberSpacing or self.LAYOUT.MemberSpacing
    groupSpacing = groupSpacing or self.LAYOUT.GroupSpacing
    groupsPerRow = groupsPerRow or 6
    if isHorizontal then
        local memberExtent = (numPerGroup * frameWidth) + ((numPerGroup - 1) * memberSpacing)
        local row = (groupIndex - 1) % groupsPerRow
        local col = math.floor((groupIndex - 1) / groupsPerRow)
        local gx = col * (memberExtent + groupSpacing)
        local gy = -(row * (frameHeight + groupSpacing))
        return gx, gy
    end
    local col = (groupIndex - 1) % groupsPerRow
    local row = math.floor((groupIndex - 1) / groupsPerRow)
    local memberExtent = (numPerGroup * frameHeight) + ((numPerGroup - 1) * memberSpacing)
    local gx = col * (frameWidth + groupSpacing)
    local gy = -(row * (memberExtent + groupSpacing))
    return gx, gy
end

function Helpers:CalculateMemberPosition(memberIndex, frameWidth, frameHeight, memberSpacing, memberGrowth, isHorizontal)
    memberSpacing = memberSpacing or self.LAYOUT.MemberSpacing
    if isHorizontal then
        local offset = (memberIndex - 1) * (frameWidth + memberSpacing)
        return offset, 0
    end
    local offset = (memberIndex - 1) * (frameHeight + memberSpacing)
    if memberGrowth == "Up" then return 0, offset end
    return 0, -offset
end

-- [ POWER BAR LAYOUT ]------------------------------------------------------------------------------

function Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar)
    Orbit.UnitFrameMixin:UpdateFrameLayout(frame, borderSize, { showPowerBar = showPowerBar, powerBarRatio = self.LAYOUT.PowerBarRatio })
end

-- [ SORTING ]---------------------------------------------------------------------------------------

function Helpers:GetSortedRaidUnits(sortMode)
    local units = {}
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return units end
    for i = 1, numMembers do
        local name, _, subgroup, _, _, className, _, online, isDead, role = GetRaidRosterInfo(i)
        if name then
            units[#units + 1] = { token = "raid" .. i, rosterIndex = i, name = name, subgroup = subgroup, className = className, online = online, isDead = isDead, role = role or UnitGroupRolesAssigned("raid" .. i) }
        end
    end
    sortMode = sortMode or SORT_MODE.Group
    if sortMode == SORT_MODE.Role then
        table.sort(units, function(a, b)
            local pa, pb = ROLE_PRIORITY[a.role] or 4, ROLE_PRIORITY[b.role] or 4
            if pa ~= pb then return pa < pb end
            return (a.name or "") < (b.name or "")
        end)
    elseif sortMode == SORT_MODE.Alphabetical then
        table.sort(units, function(a, b) return (a.name or "") < (b.name or "") end)
    else
        table.sort(units, function(a, b)
            if a.subgroup ~= b.subgroup then return (a.subgroup or 1) < (b.subgroup or 1) end
            return (a.rosterIndex or 0) < (b.rosterIndex or 0)
        end)
    end
    return units
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
