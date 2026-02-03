-- [ ORBIT STATUS ICON MIXIN ]--------------------------------------------------------------------
-- Shared status icon update functions for unit frames (Party, Player, Target, Focus, Boss)

local _, addonTable = ...
local Orbit = addonTable

Orbit.StatusIconMixin = {}
local Mixin = Orbit.StatusIconMixin

local ROLE_ATLASES = { TANK = "UI-LFG-RoleIcon-Tank", HEALER = "UI-LFG-RoleIcon-Healer", DAMAGER = "UI-LFG-RoleIcon-DPS" }
local THREAT_COLORS = {
    [0] = nil,
    [1] = { r = 1.0, g = 1.0, b = 0.0, a = 0.5 },
    [2] = { r = 1.0, g = 0.6, b = 0.0, a = 0.6 },
    [3] = { r = 1.0, g = 0.4, b = 0.0, a = 0.7 },
}
local RAID_TARGET_TEXTURE_COLUMNS, RAID_TARGET_TEXTURE_ROWS = 4, 4

Mixin.ICON_PREVIEW_ATLASES = {
    RoleIcon = "UI-LFG-RoleIcon-DPS",
    LeaderIcon = "UI-HUD-UnitFrame-Player-Group-LeaderIcon",
    MarkerIcon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
    CombatIcon = "UI-HUD-UnitFrame-Player-CombatIcon",
    ReadyCheckIcon = "UI-LFG-ReadyMark-Raid",
    PhaseIcon = "RaidFrame-Icon-Phasing",
    ResIcon = "RaidFrame-Icon-Rez",
    SummonIcon = "RaidFrame-Icon-SummonPending",
}
Mixin.MARKER_ICON_TEXCOORD = { 0.75, 1, 0.25, 0.5 }
Orbit.IconPreviewAtlases, Orbit.MarkerIconTexCoord, Orbit.RoleAtlases = Mixin.ICON_PREVIEW_ATLASES, Mixin.MARKER_ICON_TEXCOORD, ROLE_ATLASES

local function IsDisabled(plugin, componentKey)
    if type(plugin) ~= "table" then
        return false
    end
    return plugin.IsComponentDisabled and plugin:IsComponentDisabled(componentKey) or false
end

-- ROLE ICON (Tank/Healer/DPS)

function Mixin:UpdateRoleIcon(frame, plugin)
    if not frame or not frame.RoleIcon then
        return
    end

    if IsDisabled(plugin, "RoleIcon") then
        frame.RoleIcon:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.RoleIcon:Hide()
        return
    end

    -- Check for vehicle first
    if UnitInVehicle(unit) and UnitHasVehicleUI(unit) then
        frame.RoleIcon:SetAtlas("RaidFrame-Icon-Vehicle")
        frame.RoleIcon:Show()
        return
    end

    local role = UnitGroupRolesAssigned(unit)
    local roleAtlas = ROLE_ATLASES[role]

    -- In Edit Mode, show a preview role icon if no role assigned
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()

    if roleAtlas then
        frame.RoleIcon:SetAtlas(roleAtlas)
        frame.RoleIcon:Show()
    elseif inEditMode then
        frame.RoleIcon:SetAtlas(ROLE_ATLASES["DAMAGER"])
        frame.RoleIcon:Show()
    else
        frame.RoleIcon:Hide()
    end
end

-- LEADER ICON

function Mixin:UpdateLeaderIcon(frame, plugin)
    if not frame or not frame.LeaderIcon then
        return
    end

    if IsDisabled(plugin, "LeaderIcon") then
        frame.LeaderIcon:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.LeaderIcon:Hide()
        return
    end

    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()

    if UnitIsGroupLeader(unit) then
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
        frame.LeaderIcon:Show()
    elseif UnitIsGroupAssistant(unit) then
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-AssistantIcon")
        frame.LeaderIcon:Show()
    elseif inEditMode then
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
        frame.LeaderIcon:Show()
    else
        frame.LeaderIcon:Hide()
    end
end

-- MARKER ICON (Raid Target)

function Mixin:UpdateMarkerIcon(frame, plugin)
    if not frame or not frame.MarkerIcon then
        return
    end

    if IsDisabled(plugin, "MarkerIcon") then
        frame.MarkerIcon:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.MarkerIcon:Hide()
        return
    end

    local index = GetRaidTargetIndex(unit)

    -- Helper to set sprite sheet cell and property
    local function SetMarkerIndex(i)
        if frame.MarkerIcon.SetSpriteSheetCell then
            frame.MarkerIcon:SetSpriteSheetCell(i, RAID_TARGET_TEXTURE_ROWS, RAID_TARGET_TEXTURE_COLUMNS)
            frame.MarkerIcon.orbitSpriteIndex = i
        else
            local col = (i - 1) % RAID_TARGET_TEXTURE_COLUMNS
            local row = math.floor((i - 1) / RAID_TARGET_TEXTURE_COLUMNS)
            local w = 1 / RAID_TARGET_TEXTURE_COLUMNS
            local h = 1 / RAID_TARGET_TEXTURE_ROWS
            frame.MarkerIcon:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
            frame.MarkerIcon.orbitSpriteIndex = i
        end
    end

    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local inCanvasMode = Orbit.Engine.ComponentEdit and Orbit.Engine.ComponentEdit:IsActive(frame)

    if index then
        SetMarkerIndex(index)
        frame.MarkerIcon:Show()
    elseif inEditMode or inCanvasMode then
        SetMarkerIndex(8) -- Skull as preview
        frame.MarkerIcon:Show()
    else
        frame.MarkerIcon:Hide()
    end
end

-- COMBAT ICON

function Mixin:UpdateCombatIcon(frame, plugin)
    if not frame or not frame.CombatIcon then
        return
    end

    if IsDisabled(plugin, "CombatIcon") then
        frame.CombatIcon:Hide()
        return
    end

    local unit = frame.unit
    local inCombat = UnitExists(unit) and UnitAffectingCombat(unit)
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()

    if inCombat or inEditMode then
        frame.CombatIcon:Show()
    else
        frame.CombatIcon:Hide()
    end
end

-- SELECTION HIGHLIGHT

function Mixin:UpdateSelectionHighlight(frame, plugin)
    if not frame or not frame.SelectionHighlight then
        return
    end

    if IsDisabled(plugin, "SelectionHighlight") then
        frame.SelectionHighlight:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.SelectionHighlight:Hide()
        return
    end

    if UnitIsUnit(unit, "target") then
        frame.SelectionHighlight:Show()
    else
        frame.SelectionHighlight:Hide()
    end
end

-- AGGRO HIGHLIGHT (Threat glow)

function Mixin:UpdateAggroHighlight(frame, plugin)
    if not frame or not frame.AggroHighlight then
        return
    end

    if IsDisabled(plugin, "AggroHighlight") then
        frame.AggroHighlight:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.AggroHighlight:Hide()
        return
    end

    local threatStatus = UnitThreatSituation(unit)
    local threatColor = threatStatus and THREAT_COLORS[threatStatus]

    if threatColor then
        frame.AggroHighlight:SetVertexColor(threatColor.r, threatColor.g, threatColor.b, threatColor.a)
        frame.AggroHighlight:Show()
    else
        frame.AggroHighlight:Hide()
    end
end

-- GROUP POSITION TEXT

function Mixin:UpdateGroupPosition(frame, plugin)
    if not frame or not frame.GroupPositionText then
        return
    end

    if IsDisabled(plugin, "GroupPositionText") then
        frame.GroupPositionText:Hide()
        return
    end

    local unit = frame.unit
    local isInRaid = IsInRaid()
    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()

    if isInRaid and unit then
        local raidIndex = UnitInRaid(unit)
        if raidIndex then
            local _, _, subgroup = GetRaidRosterInfo(raidIndex + 1)
            if subgroup then
                frame.GroupPositionText:SetText("G" .. subgroup)
                frame.GroupPositionText:Show()
            else
                frame.GroupPositionText:Hide()
            end
        else
            frame.GroupPositionText:Hide()
        end
    elseif inEditMode then
        frame.GroupPositionText:SetText("G1")
        frame.GroupPositionText:Show()
    else
        frame.GroupPositionText:Hide()
    end
end

-- NAME (Unit name text)

function Mixin:UpdateName(frame, plugin)
    if not frame or not frame.Name then
        return
    end

    if IsDisabled(plugin, "Name") then
        frame.Name:Hide()
        return
    end

    if UnitExists(frame.unit) then
        frame.Name:Show()
    end
end

-- HEALTH TEXT

function Mixin:UpdateHealthText(frame, plugin)
    if not frame or not frame.HealthText then
        return
    end

    if IsDisabled(plugin, "HealthText") then
        frame.HealthText:Hide()
        return
    end

    if UnitExists(frame.unit) then
        frame.HealthText:Show()
    end
end

-- PARTY-SPECIFIC ICONS

-- Phase Icon (Out of phase/warmode indicator)
function Mixin:UpdatePhaseIcon(frame, plugin)
    if not frame or not frame.PhaseIcon then
        return
    end

    if IsDisabled(plugin, "PhaseIcon") then
        frame.PhaseIcon:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.PhaseIcon:Hide()
        return
    end

    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local inCanvasMode = Orbit.Engine.ComponentEdit and Orbit.Engine.ComponentEdit:IsActive(frame)

    local phaseReason = UnitPhaseReason(unit)
    if phaseReason then
        frame.PhaseIcon:SetAtlas("RaidFrame-Icon-Phasing")
        frame.PhaseIcon:Show()
        frame.PhaseIcon.tooltip = PartyUtil and PartyUtil.GetPhasedReasonString and PartyUtil.GetPhasedReasonString(phaseReason, unit) or "Out of Phase"
    elseif inEditMode or inCanvasMode then
        -- Show preview in Edit/Canvas mode
        frame.PhaseIcon:SetAtlas("RaidFrame-Icon-Phasing")
        frame.PhaseIcon:Show()
    else
        frame.PhaseIcon:Hide()
    end
end

-- Ready Check Icon
function Mixin:UpdateReadyCheck(frame, plugin)
    if not frame or not frame.ReadyCheckIcon then
        return
    end

    if IsDisabled(plugin, "ReadyCheckIcon") then
        frame.ReadyCheckIcon:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.ReadyCheckIcon:Hide()
        return
    end

    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local inCanvasMode = Orbit.Engine.ComponentEdit and Orbit.Engine.ComponentEdit:IsActive(frame)

    local readyStatus = GetReadyCheckStatus(unit)
    if readyStatus == "ready" then
        frame.ReadyCheckIcon:SetAtlas("UI-LFG-ReadyMark-Raid")
        frame.ReadyCheckIcon:Show()
    elseif readyStatus == "notready" then
        frame.ReadyCheckIcon:SetAtlas("UI-LFG-DeclineMark-Raid")
        frame.ReadyCheckIcon:Show()
    elseif readyStatus == "waiting" then
        frame.ReadyCheckIcon:SetAtlas("UI-LFG-PendingMark-Raid")
        frame.ReadyCheckIcon:Show()
    elseif inEditMode or inCanvasMode then
        -- Show preview in Edit/Canvas mode (use checkmark for recognizability)
        frame.ReadyCheckIcon:SetAtlas("UI-LFG-ReadyMark-Raid")
        frame.ReadyCheckIcon:Show()
    else
        frame.ReadyCheckIcon:Hide()
    end
end

-- Incoming Resurrection Icon
function Mixin:UpdateIncomingRes(frame, plugin)
    if not frame or not frame.ResIcon then
        return
    end

    if IsDisabled(plugin, "ResIcon") then
        frame.ResIcon:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.ResIcon:Hide()
        return
    end

    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local inCanvasMode = Orbit.Engine.ComponentEdit and Orbit.Engine.ComponentEdit:IsActive(frame)

    if UnitHasIncomingResurrection(unit) then
        frame.ResIcon:SetAtlas("RaidFrame-Icon-Rez")
        frame.ResIcon:Show()
    elseif inEditMode or inCanvasMode then
        -- Show preview in Edit/Canvas mode
        frame.ResIcon:SetAtlas("RaidFrame-Icon-Rez")
        frame.ResIcon:Show()
    else
        frame.ResIcon:Hide()
    end
end

-- Incoming Summon Icon
function Mixin:UpdateIncomingSummon(frame, plugin)
    if not frame or not frame.SummonIcon then
        return
    end

    if IsDisabled(plugin, "SummonIcon") then
        frame.SummonIcon:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.SummonIcon:Hide()
        return
    end

    local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local inCanvasMode = Orbit.Engine.ComponentEdit and Orbit.Engine.ComponentEdit:IsActive(frame)

    if C_IncomingSummon and C_IncomingSummon.HasIncomingSummon(unit) then
        local status = C_IncomingSummon.IncomingSummonStatus(unit)
        if status == Enum.SummonStatus.Pending then
            frame.SummonIcon:SetAtlas("RaidFrame-Icon-SummonPending")
            frame.SummonIcon:Show()
        elseif status == Enum.SummonStatus.Accepted then
            frame.SummonIcon:SetAtlas("RaidFrame-Icon-SummonAccepted")
            frame.SummonIcon:Show()
        elseif status == Enum.SummonStatus.Declined then
            frame.SummonIcon:SetAtlas("RaidFrame-Icon-SummonDeclined")
            frame.SummonIcon:Show()
        else
            frame.SummonIcon:Hide()
        end
    elseif inEditMode or inCanvasMode then
        -- Show preview in Edit/Canvas mode
        frame.SummonIcon:SetAtlas("RaidFrame-Icon-SummonPending")
        frame.SummonIcon:Show()
    else
        frame.SummonIcon:Hide()
    end
end

-- BATCH UPDATE: All common status indicators

function Mixin:UpdateAllStatusIcons(frame, plugin)
    self:UpdateName(frame, plugin)
    self:UpdateHealthText(frame, plugin)
    self:UpdateRoleIcon(frame, plugin)
    self:UpdateLeaderIcon(frame, plugin)
    self:UpdateMarkerIcon(frame, plugin)
    self:UpdateCombatIcon(frame, plugin)
    self:UpdateSelectionHighlight(frame, plugin)
    self:UpdateAggroHighlight(frame, plugin)
    self:UpdateGroupPosition(frame, plugin)
end

-- Party-specific batch update (includes PhaseIcon, ReadyCheck, etc.)
function Mixin:UpdateAllPartyStatusIcons(frame, plugin)
    self:UpdateAllStatusIcons(frame, plugin)
    self:UpdatePhaseIcon(frame, plugin)
    self:UpdateReadyCheck(frame, plugin)
    self:UpdateIncomingRes(frame, plugin)
    self:UpdateIncomingSummon(frame, plugin)
end
