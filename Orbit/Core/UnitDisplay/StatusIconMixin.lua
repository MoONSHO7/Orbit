-- [ ORBIT STATUS ICON MIXIN ]--------------------------------------------------------------------
-- Shared status icon update functions for unit frames (Party, Player, Target, Focus, Boss)

local _, addonTable = ...
local Orbit = addonTable
local type, ipairs = type, ipairs
local math_floor = math.floor
local LSM = LibStub("LibSharedMedia-3.0")

local GROUP_POSITION_FONT_SIZE = 10

Orbit.StatusIconMixin = {}
local Mixin = Orbit.StatusIconMixin

local ROLE_ATLASES = { TANK = "UI-LFG-RoleIcon-Tank", HEALER = "UI-LFG-RoleIcon-Healer", DAMAGER = "UI-LFG-RoleIcon-DPS" }
local ASSISTANT_ICON_TEXTURE = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
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
    MainTankIcon = "RaidFrame-Icon-MainTank",
    MarkerIcon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
    CombatIcon = "UI-HUD-UnitFrame-Player-CombatIcon",
    ReadyCheckIcon = "UI-LFG-ReadyMark-Raid",
    PhaseIcon = "RaidFrame-Icon-Phasing",
    ResIcon = "RaidFrame-Icon-Rez",
    SummonIcon = "RaidFrame-Icon-SummonPending",
    DefensiveIcon = "UI-LFG-RoleIcon-Tank",
    CrowdControlIcon = "UI-LFG-PendingMark-Raid",
    PrivateAuraAnchor = "UI-LFG-PendingMark-Raid",
    Portrait = "adventureguide-campfire",
}
Mixin.MARKER_ICON_TEXCOORD = { 0.75, 1, 0.25, 0.5 }

-- [ CLASS PREVIEW SPELL IDS ]-------------------------------------------------------------------

local CLASS_DEFENSIVE_SPELLS = {
    WARRIOR = 871,        -- Shield Wall
    PALADIN = 642,        -- Divine Shield
    HUNTER = 186265,      -- Aspect of the Turtle
    ROGUE = 5277,         -- Evasion
    PRIEST = 19236,       -- Desperate Prayer
    DEATHKNIGHT = 48792,  -- Icebound Fortitude
    SHAMAN = 108271,      -- Astral Shift
    MAGE = 45438,         -- Ice Block
    WARLOCK = 104773,     -- Unending Resolve
    MONK = 115203,        -- Fortifying Brew
    DRUID = 22812,        -- Barkskin
    DEMONHUNTER = 198589, -- Blur
    EVOKER = 363916,      -- Obsidian Scales
}



local CLASS_CC_SPELLS = {
    WARRIOR = 5246,       -- Intimidating Shout
    PALADIN = 20066,      -- Repentance
    HUNTER = 187650,      -- Freezing Trap
    ROGUE = 6770,         -- Sap
    PRIEST = 605,         -- Mind Control
    DEATHKNIGHT = 108194, -- Asphyxiate
    SHAMAN = 51514,       -- Hex
    MAGE = 118,           -- Polymorph
    WARLOCK = 5782,       -- Fear
    MONK = 115078,        -- Paralysis
    DRUID = 339,          -- Entangling Roots
    DEMONHUNTER = 217832, -- Imprison
    EVOKER = 360806,      -- Sleep Walk
}

local CLASS_PRIVATE_AURA_SPELLS = {
    WARRIOR = 386208,     -- Defensive Stance
    PALADIN = 1022,       -- Blessing of Protection
    HUNTER = 264735,      -- Survival of the Fittest
    ROGUE = 31224,        -- Cloak of Shadows
    PRIEST = 47788,       -- Guardian Spirit
    DEATHKNIGHT = 48707,  -- Anti-Magic Shell
    SHAMAN = 325174,      -- Spirit Link Totem
    MAGE = 235450,        -- Prismatic Barrier
    WARLOCK = 108416,     -- Dark Pact
    MONK = 116849,        -- Life Cocoon
    DRUID = 102342,       -- Ironbark
    DEMONHUNTER = 196555, -- Netherwalk
    EVOKER = 374348,      -- Renewing Blaze
}

local FALLBACK_DEFENSIVE_TEXTURE = 136041 -- Power Word: Shield

local FALLBACK_CC_TEXTURE = 136071 -- Polymorph (generic CC)
local FALLBACK_PRIVATE_AURA_TEXTURE = 136222 -- Spell Holy SealOfProtection

function Mixin:GetClassPreviewTexture(spellTable, fallbackTexture)
    local _, playerClass = UnitClass("player")
    local spellID = playerClass and spellTable[playerClass]
    if spellID and C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then return tex end
    end
    return fallbackTexture
end

function Mixin:GetDefensiveTexture()
    return self:GetClassPreviewTexture(CLASS_DEFENSIVE_SPELLS, FALLBACK_DEFENSIVE_TEXTURE)
end



function Mixin:GetCrowdControlTexture()
    return self:GetClassPreviewTexture(CLASS_CC_SPELLS, FALLBACK_CC_TEXTURE)
end

function Mixin:GetPrivateAuraTexture()
    return self:GetClassPreviewTexture(CLASS_PRIVATE_AURA_SPELLS, FALLBACK_PRIVATE_AURA_TEXTURE)
end

Orbit.IconPreviewAtlases, Orbit.MarkerIconTexCoord, Orbit.RoleAtlases = Mixin.ICON_PREVIEW_ATLASES, Mixin.MARKER_ICON_TEXCOORD, ROLE_ATLASES

local function IsDisabled(plugin, componentKey)
    if type(plugin) ~= "table" then
        return false
    end
    return plugin.IsComponentDisabled and plugin:IsComponentDisabled(componentKey) or false
end

-- Shared guard: null check + disabled check + unit-exists check. Returns unit on success, or nil.
local function GuardedUpdate(frame, plugin, iconKey)
    if not frame or not frame[iconKey] then return nil end
    if IsDisabled(plugin, iconKey) then frame[iconKey]:Hide() return nil end
    local unit = frame.unit
    if not UnitExists(unit) then frame[iconKey]:Hide() return nil end
    return unit
end

-- ROLE ICON (Tank/Healer/DPS)

function Mixin:UpdateRoleIcon(frame, plugin)
    local unit = GuardedUpdate(frame, plugin, "RoleIcon")
    if not unit then return end

    -- Check for vehicle first
    if UnitInVehicle(unit) and UnitHasVehicleUI(unit) then
        frame.RoleIcon:SetAtlas("RaidFrame-Icon-Vehicle")
        frame.RoleIcon:Show()
        return
    end

    local role = UnitGroupRolesAssigned(unit)
    local roleAtlas = ROLE_ATLASES[role]
    local inEditMode = Orbit:IsEditMode()

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
    local unit = GuardedUpdate(frame, plugin, "LeaderIcon")
    if not unit then return end

    local inEditMode = Orbit:IsEditMode()

    if UnitIsGroupLeader(unit) then
        frame.LeaderIcon:SetTexture(nil)
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
        frame.LeaderIcon:Show()
    elseif UnitIsGroupAssistant(unit) then
        frame.LeaderIcon:SetAtlas(nil)
        frame.LeaderIcon:SetTexCoord(0, 1, 0, 1)
        frame.LeaderIcon:SetTexture(ASSISTANT_ICON_TEXTURE)
        frame.LeaderIcon:Show()
    elseif inEditMode then
        frame.LeaderIcon:SetTexture(nil)
        frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
        frame.LeaderIcon:Show()
    else
        frame.LeaderIcon:Hide()
    end
end

-- MAIN TANK / MAIN ASSIST ICON (dual-atlas like LeaderIcon)

function Mixin:UpdateMainTankIcon(frame, plugin)
    local unit = GuardedUpdate(frame, plugin, "MainTankIcon")
    if not unit then return end

    if GetPartyAssignment("MAINTANK", unit) then
        frame.MainTankIcon:SetAtlas("RaidFrame-Icon-MainTank")
        frame.MainTankIcon:Show()
        return
    elseif GetPartyAssignment("MAINASSIST", unit) then
        frame.MainTankIcon:SetAtlas("RaidFrame-Icon-MainAssist")
        frame.MainTankIcon:Show()
        return
    end

    if Orbit:IsEditMode() then
        frame.MainTankIcon:SetAtlas("RaidFrame-Icon-MainTank")
        frame.MainTankIcon:Show()
    else
        frame.MainTankIcon:Hide()
    end
end

-- MARKER ICON (Raid Target)

function Mixin:UpdateMarkerIcon(frame, plugin)
    local unit = GuardedUpdate(frame, plugin, "MarkerIcon")
    if not unit then return end

    local index = GetRaidTargetIndex(unit)

    -- Helper to set sprite sheet cell and property
    local function SetMarkerIndex(i)
        if frame.MarkerIcon.SetSpriteSheetCell then
            frame.MarkerIcon:SetSpriteSheetCell(i, RAID_TARGET_TEXTURE_ROWS, RAID_TARGET_TEXTURE_COLUMNS)
            frame.MarkerIcon.orbitSpriteIndex = i
        else
            local col = (i - 1) % RAID_TARGET_TEXTURE_COLUMNS
            local row = math_floor((i - 1) / RAID_TARGET_TEXTURE_COLUMNS)
            local w = 1 / RAID_TARGET_TEXTURE_COLUMNS
            local h = 1 / RAID_TARGET_TEXTURE_ROWS
            frame.MarkerIcon:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
            frame.MarkerIcon.orbitSpriteIndex = i
        end
    end

    local inEditMode = Orbit:IsEditMode()
    local inCanvasMode = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode:IsActive(frame)

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
    local inEditMode = Orbit:IsEditMode()

    if inCombat or inEditMode then
        frame.CombatIcon:Show()
    else
        frame.CombatIcon:Hide()
    end
end

-- SELECTION HIGHLIGHT

function Mixin:UpdateSelectionHighlight(frame, plugin)
    local unit = GuardedUpdate(frame, plugin, "SelectionHighlight")
    if not unit then return end

    if UnitIsUnit(unit, "target") then
        frame.SelectionHighlight:Show()
    else
        frame.SelectionHighlight:Hide()
    end
end

-- AGGRO HIGHLIGHT (Threat glow)

function Mixin:UpdateAggroHighlight(frame, plugin)
    local unit = GuardedUpdate(frame, plugin, "AggroHighlight")
    if not unit then return end

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
    local inEditMode = Orbit:IsEditMode()

    -- Apply global font to GroupPositionText
    local fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font) or "Fonts\\FRIZQT__.TTF"
    frame.GroupPositionText:SetFont(fontPath, GROUP_POSITION_FONT_SIZE, Orbit.Skin:GetFontOutline())

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
    local unit = GuardedUpdate(frame, plugin, "PhaseIcon")
    if not unit then return end

    local inEditMode = Orbit:IsEditMode()
    local inCanvasMode = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode:IsActive(frame)

    local phaseReason = UnitPhaseReason(unit)
    if phaseReason then
        frame.PhaseIcon:SetAtlas("RaidFrame-Icon-Phasing")
        frame.PhaseIcon:Show()
        frame.PhaseIcon.tooltip = PartyUtil and PartyUtil.GetPhasedReasonString and PartyUtil.GetPhasedReasonString(phaseReason, unit) or "Out of Phase"
    elseif inEditMode or inCanvasMode then
        frame.PhaseIcon:SetAtlas("RaidFrame-Icon-Phasing")
        frame.PhaseIcon:Show()
    else
        frame.PhaseIcon:Hide()
    end
end

-- Ready Check Icon
function Mixin:UpdateReadyCheck(frame, plugin)
    local unit = GuardedUpdate(frame, plugin, "ReadyCheckIcon")
    if not unit then return end

    local inEditMode = Orbit:IsEditMode()
    local inCanvasMode = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode:IsActive(frame)

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
        frame.ReadyCheckIcon:SetAtlas("UI-LFG-ReadyMark-Raid")
        frame.ReadyCheckIcon:Show()
    else
        frame.ReadyCheckIcon:Hide()
    end
end

-- Incoming Resurrection Icon
function Mixin:UpdateIncomingRes(frame, plugin)
    local unit = GuardedUpdate(frame, plugin, "ResIcon")
    if not unit then return end

    local inEditMode = Orbit:IsEditMode()
    local inCanvasMode = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode:IsActive(frame)

    if UnitHasIncomingResurrection(unit) then
        frame.ResIcon:SetAtlas("RaidFrame-Icon-Rez")
        frame.ResIcon:Show()
    elseif inEditMode or inCanvasMode then
        frame.ResIcon:SetAtlas("RaidFrame-Icon-Rez")
        frame.ResIcon:Show()
    else
        frame.ResIcon:Hide()
    end
end

-- Incoming Summon Icon
function Mixin:UpdateIncomingSummon(frame, plugin)
    local unit = GuardedUpdate(frame, plugin, "SummonIcon")
    if not unit then return end

    local inEditMode = Orbit:IsEditMode()
    local inCanvasMode = Orbit.Engine.CanvasMode and Orbit.Engine.CanvasMode:IsActive(frame)

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
        frame.SummonIcon:SetAtlas("RaidFrame-Icon-SummonPending")
        frame.SummonIcon:Show()
    else
        frame.SummonIcon:Hide()
    end
end

-- STATUS TEXT (Offline / Dead indicator, independent of HealthText)

function Mixin:UpdateStatusText(frame, plugin)
    if not frame or not frame.HealthText then return end
    if frame.healthTextEnabled then return end
    local unit = frame.unit
    if not unit or not UnitExists(unit) then frame.HealthText:Hide(); return end
    if not UnitIsConnected(unit) then frame.HealthText:SetText("Offline"); frame.HealthText:SetTextColor(0.7, 0.7, 0.7, 1); frame.HealthText:Show(); return end
    if UnitIsDeadOrGhost(unit) then frame.HealthText:SetText("Dead"); frame.HealthText:SetTextColor(0.7, 0.7, 0.7, 1); frame.HealthText:Show(); return end
    frame.HealthText:Hide()
end

-- BATCH UPDATE: All common status indicators

function Mixin:UpdateAllStatusIcons(frame, plugin)
    self:UpdateName(frame, plugin)
    self:UpdateHealthText(frame, plugin)
    self:UpdateStatusText(frame, plugin)
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
