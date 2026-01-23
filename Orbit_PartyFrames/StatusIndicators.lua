---@type Orbit
local Orbit = Orbit

-- Status Indicator Updates for Party Frames
-- Extracted from PartyFrame.lua for better modularity

Orbit.PartyFrameStatusMixin = {}

-- ============================================================
-- CONSTANTS
-- ============================================================

local ROLE_ATLASES = {
    TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}

local THREAT_COLORS = {
    [0] = nil,  -- No threat - hide
    [1] = { r = 1.0, g = 1.0, b = 0.0, a = 0.5 },  -- Yellow - about to gain/lose
    [2] = { r = 1.0, g = 0.6, b = 0.0, a = 0.6 },  -- Orange - higher threat
    [3] = { r = 1.0, g = 0.4, b = 0.0, a = 0.7 },  -- Orange-Red - has aggro
}

local RAID_TARGET_TEXTURE_COLUMNS = 4
local RAID_TARGET_TEXTURE_ROWS = 4

-- ============================================================
-- STATUS INDICATOR UPDATE FUNCTIONS
-- ============================================================

-- Role Icon (Tank/Healer/DPS)
function Orbit.PartyFrameStatusMixin:UpdateRoleIcon(frame, plugin)
    if not frame.RoleIcon then return end
    
    local showRole = plugin:GetSetting(1, "ShowRoleIcon")
    if showRole == false then
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
    if roleAtlas then
        frame.RoleIcon:SetAtlas(roleAtlas)
        frame.RoleIcon:Show()
    else
        frame.RoleIcon:Hide()
    end
end

-- Leader Icon
function Orbit.PartyFrameStatusMixin:UpdateLeaderIcon(frame, plugin)
    if not frame.LeaderIcon then return end
    
    local showLeader = plugin:GetSetting(1, "ShowLeaderIcon")
    if showLeader == false then
        frame.LeaderIcon:Hide()
        return
    end
    
    local unit = frame.unit
    if not UnitExists(unit) then
        frame.LeaderIcon:Hide()
        return
    end
    
    if UnitIsGroupLeader(unit) then
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
        frame.LeaderIcon:Show()
    elseif UnitIsGroupAssistant(unit) then
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-AssistantIcon")
        frame.LeaderIcon:Show()
    else
        frame.LeaderIcon:Hide()
    end
end

-- Selection Highlight (White border when targeted)
function Orbit.PartyFrameStatusMixin:UpdateSelectionHighlight(frame, plugin)
    if not frame.SelectionHighlight then return end
    
    local showSelection = plugin:GetSetting(1, "ShowSelectionHighlight")
    if showSelection == false then
        frame.SelectionHighlight:Hide()
        return
    end
    
    local unit = frame.unit
    
    -- Fix: Guard against nil unit (UnitIsUnit throws error on nil)
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

-- Aggro Highlight (Threat glow)
function Orbit.PartyFrameStatusMixin:UpdateAggroHighlight(frame, plugin)
    if not frame.AggroHighlight then return end
    
    local showAggro = plugin:GetSetting(1, "ShowAggroHighlight")
    if showAggro == false then
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

-- Phase Icon (Out of phase/warmode indicator)
function Orbit.PartyFrameStatusMixin:UpdatePhaseIcon(frame, plugin)
    if not frame.PhaseIcon then return end
    
    local showPhase = plugin:GetSetting(1, "ShowPhaseIcon")
    if showPhase == false then
        frame.PhaseIcon:Hide()
        return
    end
    
    local unit = frame.unit
    if not UnitExists(unit) then
        frame.PhaseIcon:Hide()
        return
    end
    
    local phaseReason = UnitPhaseReason(unit)
    if phaseReason then
        frame.PhaseIcon:SetAtlas("RaidFrame-Icon-Phasing")
        frame.PhaseIcon:Show()
        frame.PhaseIcon.tooltip = PartyUtil and PartyUtil.GetPhasedReasonString and PartyUtil.GetPhasedReasonString(phaseReason, unit) or "Out of Phase"
    else
        frame.PhaseIcon:Hide()
    end
end

-- Ready Check Icon
function Orbit.PartyFrameStatusMixin:UpdateReadyCheck(frame, plugin)
    if not frame.ReadyCheckIcon then return end
    
    local showReadyCheck = plugin:GetSetting(1, "ShowReadyCheck")
    if showReadyCheck == false then
        frame.ReadyCheckIcon:Hide()
        return
    end
    
    local unit = frame.unit
    if not UnitExists(unit) then
        frame.ReadyCheckIcon:Hide()
        return
    end
    
    local readyStatus = GetReadyCheckStatus(unit)
    if readyStatus == "ready" then
        frame.ReadyCheckIcon:SetAtlas("UI-HUD-Minimap-Tracking-Checkmark")
        frame.ReadyCheckIcon:Show()
    elseif readyStatus == "notready" then
        frame.ReadyCheckIcon:SetAtlas("UI-HUD-Minimap-Tracking-DenyMark")
        frame.ReadyCheckIcon:Show()
    elseif readyStatus == "waiting" then
        frame.ReadyCheckIcon:SetAtlas("UI-HUD-Minimap-Tracking-Question")
        frame.ReadyCheckIcon:Show()
    else
        frame.ReadyCheckIcon:Hide()
    end
end

-- Incoming Resurrection Icon
function Orbit.PartyFrameStatusMixin:UpdateIncomingRes(frame, plugin)
    if not frame.ResIcon then return end
    
    local showRes = plugin:GetSetting(1, "ShowIncomingRes")
    if showRes == false then
        frame.ResIcon:Hide()
        return
    end
    
    local unit = frame.unit
    if not UnitExists(unit) then
        frame.ResIcon:Hide()
        return
    end
    
    if UnitHasIncomingResurrection(unit) then
        frame.ResIcon:SetAtlas("RaidFrame-Icon-Rez")
        frame.ResIcon:Show()
    else
        frame.ResIcon:Hide()
    end
end

-- Incoming Summon Icon
function Orbit.PartyFrameStatusMixin:UpdateIncomingSummon(frame, plugin)
    if not frame.SummonIcon then return end
    
    local showSummon = plugin:GetSetting(1, "ShowIncomingSummon")
    if showSummon == false then
        frame.SummonIcon:Hide()
        return
    end
    
    local unit = frame.unit
    if not UnitExists(unit) then
        frame.SummonIcon:Hide()
        return
    end
    
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
    else
        frame.SummonIcon:Hide()
    end
end

-- Marker Icon (Raid Target)
function Orbit.PartyFrameStatusMixin:UpdateMarkerIcon(frame, plugin)
    if not frame.MarkerIcon then return end

    local showMarker = plugin:GetSetting(1, "ShowMarkerIcon")
    if showMarker == false then
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
             frame.MarkerIcon.orbitSpriteIndex = i -- Required for Canvas Mode
        else
            -- Fallback if mixin missing
            local col = (i - 1) % RAID_TARGET_TEXTURE_COLUMNS
            local row = math.floor((i - 1) / RAID_TARGET_TEXTURE_COLUMNS)
            local w = 1 / RAID_TARGET_TEXTURE_COLUMNS
            local h = 1 / RAID_TARGET_TEXTURE_ROWS
            frame.MarkerIcon:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
            frame.MarkerIcon.orbitSpriteIndex = i
        end
    end

    if index then
        SetMarkerIndex(index)
        frame.MarkerIcon:Show()
    else
        frame.MarkerIcon:Hide()
    end
end

-- Update all status indicators
function Orbit.PartyFrameStatusMixin:UpdateAllStatusIndicators(frame, plugin)
    self:UpdateRoleIcon(frame, plugin)
    self:UpdateLeaderIcon(frame, plugin)
    self:UpdateSelectionHighlight(frame, plugin)
    self:UpdateAggroHighlight(frame, plugin)
    self:UpdatePhaseIcon(frame, plugin)
    self:UpdateReadyCheck(frame, plugin)
    self:UpdateIncomingRes(frame, plugin)
    self:UpdateIncomingSummon(frame, plugin)
    self:UpdateMarkerIcon(frame, plugin)
end
