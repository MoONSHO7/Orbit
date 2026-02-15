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
    if posX and posY and halfW and halfH then
        local beyondX = math.max(0, math.abs(posX) - halfW)
        local beyondY = math.max(0, math.abs(posY) - halfH)
        if beyondY > beyondX then return posY > 0 and "Above" or "Below"
        elseif beyondX > beyondY then return posX > 0 and "Right" or "Left" end
        if math.abs(posX) / math.max(halfW, 1) > math.abs(posY) / math.max(halfH, 1) then return posX > 0 and "Right" or "Left"
        else return posY > 0 and "Above" or "Below" end
    end
    return "Right"
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

function Helpers:CalculateContainerSize(numGroups, numPerGroup, frameWidth, frameHeight, memberSpacing, groupSpacing, orientation)
    memberSpacing = memberSpacing or self.LAYOUT.MemberSpacing
    groupSpacing = groupSpacing or self.LAYOUT.GroupSpacing
    numGroups = math.max(1, numGroups)
    numPerGroup = math.max(1, numPerGroup)
    local memberExtent = (numPerGroup * frameHeight) + ((numPerGroup - 1) * memberSpacing)
    local groupExtent = (numGroups * frameWidth) + ((numGroups - 1) * groupSpacing)
    if orientation == 0 then
        return groupExtent, memberExtent
    else
        return memberExtent, groupExtent
    end
end

-- [ FRAME POSITIONING ]-----------------------------------------------------------------------------

function Helpers:CalculateGroupPosition(groupIndex, frameWidth, frameHeight, numPerGroup, memberSpacing, groupSpacing, orientation, growthDirection)
    memberSpacing = memberSpacing or self.LAYOUT.MemberSpacing
    groupSpacing = groupSpacing or self.LAYOUT.GroupSpacing
    local memberExtent = (numPerGroup * frameHeight) + ((numPerGroup - 1) * memberSpacing)
    local step = orientation == 0 and (frameWidth + groupSpacing) or (memberExtent + groupSpacing)
    local offset = (groupIndex - 1) * step
    if orientation == 0 then
        if growthDirection == "Left" then return -offset, 0, "TOPRIGHT", "TOPRIGHT" end
        return offset, 0, "TOPLEFT", "TOPLEFT"
    else
        if growthDirection == "Up" then return 0, offset, "BOTTOMLEFT", "BOTTOMLEFT" end
        return 0, -offset, "TOPLEFT", "TOPLEFT"
    end
end

function Helpers:CalculateMemberPosition(memberIndex, frameWidth, frameHeight, memberSpacing, orientation, memberGrowth)
    memberSpacing = memberSpacing or self.LAYOUT.MemberSpacing
    local step = orientation == 0 and (frameHeight + memberSpacing) or (frameWidth + memberSpacing)
    local offset = (memberIndex - 1) * step
    if orientation == 0 then
        if memberGrowth == "Up" then return 0, offset, "BOTTOMLEFT", "BOTTOMLEFT" end
        return 0, -offset, "TOPLEFT", "TOPLEFT"
    else
        if memberGrowth == "Left" then return -offset, 0, "TOPRIGHT", "TOPRIGHT" end
        return offset, 0, "TOPLEFT", "TOPLEFT"
    end
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
            units[#units + 1] = { token = "raid" .. i, name = name, subgroup = subgroup, className = className, online = online, isDead = isDead, role = role or UnitGroupRolesAssigned("raid" .. i) }
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
            return (a.name or "") < (b.name or "")
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
