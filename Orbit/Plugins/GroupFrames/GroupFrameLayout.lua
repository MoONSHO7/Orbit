---@type Orbit
local Orbit = Orbit
local LSM = LibStub("LibSharedMedia-3.0")

local Helpers = Orbit.GroupFrameHelpers
local Pixel = Orbit.Engine.Pixel

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local MAX_GROUP_FRAMES = Helpers.LAYOUT.MaxGroupFrames
local MAX_RAID_GROUPS = Helpers.LAYOUT.MaxRaidGroups
local FRAMES_PER_GROUP = Helpers.LAYOUT.FramesPerGroup
local OVERLAY_LEVEL_BOOST = Orbit.Constants.Levels.Tooltip

-- [ GROUP LABELS ]-----------------------------------------------------------------------------------
local GROUP_LABEL_FONT_SIZE = 12
local GROUP_LABEL_ALPHA = 0.65
local GROUP_LABEL_PADDING = 5

Orbit.GroupFrameLayoutMixin = {}

-- [ FRAME POSITIONING ]------------------------------------------------------------------------------
function Orbit.GroupFrameLayoutMixin:PositionFrames()
    if InCombatLockdown() then return end
    if self:IsPartyTier() then
        self:PositionPartyFrames()
    else
        self:PositionRaidFrames()
    end
    self:UpdateContainerSize()
end

function Orbit.GroupFrameLayoutMixin:PositionPartyFrames()
    if self.groupLabels then
        for i = 1, MAX_RAID_GROUPS do if self.groupLabels[i] then self.groupLabels[i]:Hide() end end
    end
    local spacing = self:GetTierSetting("Spacing") or 0
    local orientation = self:GetTierSetting("Orientation") or 0
    local width = self:GetTierSetting("Width") or 160
    local height = self:GetTierSetting("Height") or 40
    local growthDirection = self:GetTierSetting("GrowthDirection") or (orientation == 0 and "down" or "right")
    self.container.orbitForceAnchorPoint = Helpers:GetContainerAnchor(growthDirection)

    local visibleIndex = 0
    local scale = self.container:GetEffectiveScale() or 1
    for _, frame in ipairs(self.frames) do
        frame:ClearAllPoints()
        if frame:IsShown() or frame.preview then
            visibleIndex = visibleIndex + 1
            local xOffset, yOffset, frameAnchor, containerAnchor =
                Helpers:CalculatePartyFramePosition(visibleIndex, width, height, spacing, orientation, growthDirection, scale)
            frame:SetPoint(frameAnchor, self.container, containerAnchor, xOffset, yOffset)
        end
    end
end

function Orbit.GroupFrameLayoutMixin:PositionRaidFrames()
    local width = self:GetTierSetting("Width") or 100
    local height = self:GetTierSetting("Height") or 40
    local memberSpacing = self:GetTierSetting("MemberSpacing") or 2
    local groupSpacing = self:GetTierSetting("GroupSpacing") or 2
    local groupsPerRow = self:GetTierSetting("GroupsPerRow") or 6
    local memberGrowth = self:GetTierSetting("GrowthDirection") or "down"
    self.container.orbitForceAnchorPoint = Helpers:GetContainerAnchor(memberGrowth)
    local isHorizontal = (self:GetTierSetting("Orientation") or "vertical") == "horizontal"

    local activeGroups = Helpers:GetActiveGroups()
    local sortMode = self:GetTierSetting("SortMode") or "group"

    local isPreview = self.frames[1] and self.frames[1].preview
    local groupOrder = {}
    if isPreview then
        local tierMax = Helpers:GetTierMaxFrames(self:GetCurrentTier())
        local previewGroups = math.ceil(tierMax / FRAMES_PER_GROUP)
        for g = 1, previewGroups do groupOrder[g] = g end
    else
        for g = 1, MAX_RAID_GROUPS do
            if activeGroups[g] then groupOrder[#groupOrder + 1] = g end
        end
    end

    local growUp = (memberGrowth == "up")
    local scale = self.container:GetEffectiveScale() or 1

    if sortMode ~= "group" then
        local flatRows = math.max(1, self:GetTierSetting("FlatRows") or 1)
        local visibleFrames = {}
        for i = 1, MAX_GROUP_FRAMES do
            local frame = self.frames[i]
            if frame and ((frame.preview) or (frame.unit and UnitExists(frame.unit))) then
                visibleFrames[#visibleFrames + 1] = frame
            end
        end
        local totalFrames = #visibleFrames
        local framesPerCol = math.ceil(totalFrames / flatRows)
        local msPx = Pixel:Multiple(memberSpacing, scale)
        for idx, frame in ipairs(visibleFrames) do
            local col = math.floor((idx - 1) / framesPerCol)
            local row = (idx - 1) % framesPerCol
            local fx = Pixel:Snap(col * (width + msPx), scale)
            local fy = Pixel:Snap(row * (height + msPx), scale)
            frame:ClearAllPoints()
            if growUp then
                frame:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", fx, fy)
            else
                frame:SetPoint("TOPLEFT", self.container, "TOPLEFT", fx, -fy)
            end
        end
    else
        local frameBuckets = {}
        for g = 1, MAX_RAID_GROUPS do frameBuckets[g] = {} end
        for i = 1, MAX_GROUP_FRAMES do
            local frame = self.frames[i]
            if frame then
                if isPreview then
                    local previewGroup = math.ceil(i / FRAMES_PER_GROUP)
                    if frame.preview and previewGroup <= #groupOrder then
                        local bucket = frameBuckets[previewGroup]
                        bucket[#bucket + 1] = frame
                    end
                elseif frame.unit and UnitExists(frame.unit) then
                    local raidIndex = tonumber(frame.unit:match("(%d+)"))
                    local subgroup = raidIndex and select(3, GetRaidRosterInfo(raidIndex))
                    if subgroup then
                        local bucket = frameBuckets[subgroup]
                        bucket[#bucket + 1] = frame
                    end
                end
            end
        end

        for groupIdx, groupNum in ipairs(groupOrder) do
            local gx, gy = Helpers:CalculateGroupPosition(groupIdx, width, height, FRAMES_PER_GROUP, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, scale)
            local bucket = frameBuckets[groupNum] or {}
            for memberIndex, frame in ipairs(bucket) do
                if memberIndex > FRAMES_PER_GROUP then break end
                local mx, my = Helpers:CalculateMemberPosition(memberIndex, width, height, memberSpacing, memberGrowth, isHorizontal, scale)
                frame:ClearAllPoints()
                if growUp then
                    frame:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", gx + mx, -gy + my)
                else
                    frame:SetPoint("TOPLEFT", self.container, "TOPLEFT", gx + mx, gy + my)
                end
            end
        end
    end

    self:UpdateGroupLabels(sortMode, groupOrder, width, height, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, growUp, scale)
end

-- [ GROUP LABELS ]-----------------------------------------------------------------------------------
function Orbit.GroupFrameLayoutMixin:UpdateGroupLabels(sortMode, groupOrder, width, height, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, growUp, scale)
    if not self.groupLabels then self.groupLabels = {} end
    local showLabels = (sortMode == "group") and self:GetTierSetting("ShowGroupLabels")

    for i = 1, MAX_RAID_GROUPS do
        if self.groupLabels[i] then self.groupLabels[i]:Hide() end
    end
    if not showLabels then return end

    if not self.groupLabelOverlay then
        self.groupLabelOverlay = CreateFrame("Frame", nil, self.container)
        self.groupLabelOverlay:SetAllPoints()
        self.groupLabelOverlay:SetFrameLevel(self.container:GetFrameLevel() + OVERLAY_LEVEL_BOOST)
    end

    local fontPath = (LSM and LSM:Fetch("font", Orbit.db.GlobalSettings.Font)) or STANDARD_TEXT_FONT
    for idx, groupNum in ipairs(groupOrder) do
        if not self.groupLabels[idx] then
            self.groupLabels[idx] = self.groupLabelOverlay:CreateFontString(nil, "OVERLAY")
            self.groupLabels[idx]:SetTextColor(1, 1, 1, GROUP_LABEL_ALPHA)
        end
        local label = self.groupLabels[idx]
        label:SetFont(fontPath, GROUP_LABEL_FONT_SIZE, "OUTLINE")
        label:SetText("G" .. groupNum)
        label:ClearAllPoints()

        local gx, gy = Helpers:CalculateGroupPosition(idx, width, height, FRAMES_PER_GROUP, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, scale)
        if isHorizontal then
            local rowCenter = Pixel:Snap(height / 2, scale)
            if growUp then
                label:SetPoint("RIGHT", self.container, "BOTTOMLEFT", gx - GROUP_LABEL_PADDING, -gy + rowCenter)
            else
                label:SetPoint("RIGHT", self.container, "TOPLEFT", gx - GROUP_LABEL_PADDING, gy - rowCenter)
            end
        else
            local colCenter = Pixel:Snap(width / 2, scale)
            if growUp then
                label:SetPoint("BOTTOM", self.container, "BOTTOMLEFT", gx + colCenter, -gy + GROUP_LABEL_PADDING)
            else
                label:SetPoint("BOTTOM", self.container, "TOPLEFT", gx + colCenter, gy + GROUP_LABEL_PADDING)
            end
        end
        label:Show()
    end
end

-- [ CONTAINER SIZE ]---------------------------------------------------------------------------------
function Orbit.GroupFrameLayoutMixin:UpdateContainerSize()
    if InCombatLockdown() then return end

    local isParty = self:IsPartyTier()
    local isPreview = self.frames[1] and self.frames[1].preview

    if isParty then
        local width = self:GetTierSetting("Width") or 160
        local height = self:GetTierSetting("Height") or 40
        local spacing = self:GetTierSetting("Spacing") or 0
        local orientation = self:GetTierSetting("Orientation") or 0
        local visibleCount = 0
        for _, frame in ipairs(self.frames) do
            if frame:IsShown() or frame.preview then visibleCount = visibleCount + 1 end
        end
        visibleCount = math.max(1, visibleCount)
        local scale = self.container:GetEffectiveScale() or 1
        local containerW, containerH = Helpers:CalculatePartyContainerSize(visibleCount, width, height, spacing, orientation, scale)
        self.container:SetSize(containerW, containerH)
    else
        local width = self:GetTierSetting("Width") or 100
        local height = self:GetTierSetting("Height") or 40
        local memberSpacing = self:GetTierSetting("MemberSpacing") or 2
        local groupSpacing = self:GetTierSetting("GroupSpacing") or 2
        local groupsPerRow = self:GetTierSetting("GroupsPerRow") or 6
        local sortMode = self:GetTierSetting("SortMode") or "group"

        if sortMode ~= "group" then
            local flatRows = math.max(1, self:GetTierSetting("FlatRows") or 1)
            local totalFrames = 0
            for _, frame in ipairs(self.frames) do
                if frame:IsShown() or frame.preview then totalFrames = totalFrames + 1 end
            end
            totalFrames = math.max(1, totalFrames)
            local framesPerCol = math.ceil(totalFrames / flatRows)
            local scale = self.container:GetEffectiveScale() or 1
            local msPx = Pixel:Multiple(memberSpacing, scale)
            local containerW = (flatRows * width) + ((flatRows - 1) * msPx)
            local containerH = (framesPerCol * height) + ((framesPerCol - 1) * msPx)
            self.container:SetSize(containerW, containerH)
        else
            local numGroups = 0
            if isPreview then
                local tierMax = Helpers:GetTierMaxFrames(self:GetCurrentTier())
                numGroups = math.ceil(tierMax / FRAMES_PER_GROUP)
            else
                local activeGroups = Helpers:GetActiveGroups()
                for _ in pairs(activeGroups) do numGroups = numGroups + 1 end
                numGroups = math.max(1, numGroups)
            end
            local isHorizontal = (self:GetTierSetting("Orientation") or "vertical") == "horizontal"
            local scale = self.container:GetEffectiveScale() or 1
            local containerW, containerH = Helpers:CalculateRaidContainerSize(numGroups, FRAMES_PER_GROUP, width, height, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, scale)
            self.container:SetSize(containerW, containerH)
        end
    end

    Orbit.Skin.DefaultSetBorderHidden(self.container, true)
end
