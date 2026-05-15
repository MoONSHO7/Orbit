-- [ ORBIT STATUS ICON MIXIN ] -----------------------------------------------------------------------
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
local ROUND_ROLE_ATLASES = { TANK = "icons_64x64_tank", HEALER = "icons_64x64_heal", DAMAGER = "icons_64x64_damage" }
local HEADER_ROLE_ATLASES = { TANK = "GO-icon-role-Header-Tank", HEALER = "GO-icon-role-Header-Healer", DAMAGER = "GO-icon-role-Header-DPS", DAMAGER_RANGED = "GO-icon-role-Header-DPS-Ranged" }
local ASSISTANT_ICON_TEXTURE = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
local LEADER_ATLASES = {
    default = { leader = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", assistTexture = ASSISTANT_ICON_TEXTURE },
    header  = { leader = "GO-icon-Header-Assist-Applied", assist = "GO-icon-Header-Assist-Available" },
}
local THREAT_COLORS = {
    [0] = nil,
    [1] = { r = 1.0, g = 1.0, b = 0.0, a = 0.7 },
    [2] = { r = 1.0, g = 0.6, b = 0.0, a = 0.8 },
    [3] = { r = 1.0, g = 0.0, b = 0.0, a = 1.0 },
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
    PvpIcon = "AllianceAssaultsMapBanner",
    DispelIcon = "icons_64x64_magic",
}
Mixin.MARKER_ICON_TEXCOORD = { 0.75, 1, 0.25, 0.5 }

function Mixin:ApplyMarkerSprite(icon, index)
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    local col = (index - 1) % RAID_TARGET_TEXTURE_COLUMNS
    local row = math_floor((index - 1) / RAID_TARGET_TEXTURE_COLUMNS)
    local w, h = 1 / RAID_TARGET_TEXTURE_COLUMNS, 1 / RAID_TARGET_TEXTURE_ROWS
    icon:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
end

-- [ CLASS PREVIEW SPELL IDS ] -----------------------------------------------------------------------
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

-- [ RANGED DPS SPEC DETECTION ] ---------------------------------------------------------------------
local RANGED_DPS_SPECS = {
    [102]  = true, -- Balance Druid
    [253]  = true, -- Beast Mastery Hunter
    [254]  = true, -- Marksmanship Hunter
    [62]   = true, -- Arcane Mage
    [63]   = true, -- Fire Mage
    [64]   = true, -- Frost Mage
    [258]  = true, -- Shadow Priest
    [262]  = true, -- Elemental Shaman
    [265]  = true, -- Affliction Warlock
    [266]  = true, -- Demonology Warlock
    [267]  = true, -- Destruction Warlock
    [1467] = true, -- Devastation Evoker
    [1473] = true, -- Augmentation Evoker
}

local function IsRangedDPS(unit)
    if UnitIsUnit(unit, "player") then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            return RANGED_DPS_SPECS[specID] or false
        end
        return false
    end
    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    return specID and RANGED_DPS_SPECS[specID] or false
end
Mixin.IsRangedDPS = IsRangedDPS

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
    local inEditMode = Orbit:IsEditMode()

    -- Resolve overrides: RoleIconStyle + HideDPS
    local atlases = ROLE_ATLASES
    local hideDPS = false
    if plugin then
        local positions = plugin:GetSetting(1, "ComponentPositions")
        local roleOverrides = positions and positions.RoleIcon and positions.RoleIcon.overrides
        if roleOverrides then
            local style = roleOverrides.RoleIconStyle
            if style == "round" then atlases = ROUND_ROLE_ATLASES
            elseif style == "header" then atlases = HEADER_ROLE_ATLASES end
            hideDPS = roleOverrides.HideDPS
        end
    end

    local roleAtlas = atlases[role]
    if role == "DAMAGER" and atlases.DAMAGER_RANGED and IsRangedDPS(unit) then
        roleAtlas = atlases.DAMAGER_RANGED
    end
    if role == "DAMAGER" and hideDPS then
        frame.RoleIcon:Hide()
    elseif roleAtlas then
        frame.RoleIcon:SetAtlas(roleAtlas)
        frame.RoleIcon:Show()
    elseif inEditMode and not hideDPS then
        frame.RoleIcon:SetAtlas(atlases["DAMAGER"])
        frame.RoleIcon:Show()
    elseif inEditMode and hideDPS then
        frame.RoleIcon:SetAtlas(atlases["HEALER"])
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

    -- Resolve LeaderIconStyle override
    local style = "default"
    if plugin then
        local positions = plugin:GetSetting(1, "ComponentPositions")
        local overrides = positions and positions.LeaderIcon and positions.LeaderIcon.overrides
        if overrides and overrides.LeaderIconStyle then style = overrides.LeaderIconStyle end
    end
    local la = LEADER_ATLASES[style] or LEADER_ATLASES.default

    if UnitIsGroupLeader(unit) then
        frame.LeaderIcon:SetTexture(nil)
        frame.LeaderIcon:SetTexCoord(0, 1, 0, 1)
        frame.LeaderIcon:SetAtlas(la.leader)
        frame.LeaderIcon:Show()
    elseif UnitIsGroupAssistant(unit) then
        if la.assist then
            frame.LeaderIcon:SetTexture(nil)
            frame.LeaderIcon:SetTexCoord(0, 1, 0, 1)
            frame.LeaderIcon:SetAtlas(la.assist)
        else
            frame.LeaderIcon:SetAtlas(nil)
            frame.LeaderIcon:SetTexCoord(0, 1, 0, 1)
            frame.LeaderIcon:SetTexture(la.assistTexture or ASSISTANT_ICON_TEXTURE)
        end
        frame.LeaderIcon:Show()
    elseif inEditMode then
        frame.LeaderIcon:SetTexture(nil)
        frame.LeaderIcon:SetTexCoord(0, 1, 0, 1)
        frame.LeaderIcon:SetAtlas(la.leader)
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
    local inCanvasMode = Orbit.Engine.CanvasMode:IsActive(frame)

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

local COMBAT_ICON_ATLASES = {
    default = "UI-HUD-UnitFrame-Player-CombatIcon",
    pvp = "UI-EventPoi-pvp",
}

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
        local style = "default"
        if plugin then
            local positions = plugin:GetSetting(1, "ComponentPositions")
            local overrides = positions and positions.CombatIcon and positions.CombatIcon.overrides
            if overrides and overrides.CombatIconStyle then style = overrides.CombatIconStyle end
        end
        frame.CombatIcon:SetAtlas(COMBAT_ICON_ATLASES[style] or COMBAT_ICON_ATLASES.default, false)
        frame.CombatIcon:Show()
    else
        frame.CombatIcon:Hide()
    end
end

-- PVP ICON

local PVP_FACTION_ATLASES = {
    Alliance = "AllianceAssaultsMapBanner",
    Horde = "HordeAssaultsMapBanner",
}
local PVP_ICON_DEFAULT_SIZE = 18

function Mixin:UpdatePvpIcon(frame, plugin)
    local unit = GuardedUpdate(frame, plugin, "PvpIcon")
    if not unit then return end

    local isPlayer = UnitIsUnit(unit, "player")
    local isPvp = (isPlayer and C_PvP and C_PvP.IsWarModeDesired and C_PvP.IsWarModeDesired()) or (not isPlayer and UnitIsPVP(unit))
    local showIcon = isPvp or Orbit:IsEditMode()
    if showIcon then
        local faction = isPvp and UnitFactionGroup(unit) or UnitFactionGroup("player")
        frame.PvpIcon:SetAtlas(PVP_FACTION_ATLASES[faction] or PVP_FACTION_ATLASES.Alliance, false)
        -- Always enforce pixel sizing: saved IconSize > default
        local size = PVP_ICON_DEFAULT_SIZE
        if plugin and plugin.GetComponentPositions then
            local positions = plugin:GetComponentPositions(1)
            local saved = positions and positions.PvpIcon and positions.PvpIcon.overrides and positions.PvpIcon.overrides.IconSize
            if saved and saved > 0 then size = saved end
        end
        local ratio = frame.PvpIcon.orbitOriginalHeight and frame.PvpIcon.orbitOriginalWidth and frame.PvpIcon.orbitOriginalWidth > 0 and (frame.PvpIcon.orbitOriginalHeight / frame.PvpIcon.orbitOriginalWidth) or 1
        local pvpScale = frame:GetEffectiveScale() or 1
        frame.PvpIcon:SetSize(Orbit.Engine.Pixel:Snap(size, pvpScale), Orbit.Engine.Pixel:Snap(size * ratio, pvpScale))
        frame.PvpIcon:Show()
    else
        frame.PvpIcon:Hide()
    end
end

-- SELECTION HIGHLIGHT

local SELECTION_STORAGE_KEY = "_selectionBorderOverlay"
local SELECTION_COLOR_DEFAULT = { r = 0.8, g = 0.9, b = 1.0, a = 1.0 }

function Mixin:UpdateSelectionHighlight(frame, plugin)
    if not frame then return end
    local unit = frame.unit
    if not unit or not UnitExists(unit) then
        Orbit.Skin:ClearHighlightBorder(frame, SELECTION_STORAGE_KEY)
        return
    end
    if UnitIsUnit(unit, "target") then
        local raw = plugin and plugin.GetSetting and plugin:GetSetting(1, "SelectionColor")
        local color = (Orbit.Engine.ColorCurve and Orbit.Engine.ColorCurve:GetFirstColorFromCurve(raw) or raw) or SELECTION_COLOR_DEFAULT
        Orbit.Skin:ApplyHighlightBorder(frame, SELECTION_STORAGE_KEY, color, Orbit.Constants.Levels.Border + 1, "ADD")
    else
        Orbit.Skin:ClearHighlightBorder(frame, SELECTION_STORAGE_KEY)
    end
end

-- AGGRO HIGHLIGHT (Threat glow)

local AGGRO_HIGHLIGHT_KEY = "_aggroHighlightOverlay"

function Mixin:UpdateAggroHighlight(frame, plugin)
    if not frame then return end
    if IsDisabled(plugin, "AggroHighlight") then
        Orbit.Skin:ClearHighlightBorder(frame, AGGRO_HIGHLIGHT_KEY)
        return
    end
    local unit = frame.unit
    if not unit or not UnitExists(unit) then
        Orbit.Skin:ClearHighlightBorder(frame, AGGRO_HIGHLIGHT_KEY)
        return
    end
    local threatStatus = UnitThreatSituation(unit)
    if threatStatus and threatStatus >= 1 then
        local rawColor = (threatStatus == 3) and (plugin and plugin.GetSetting and plugin:GetSetting(1, "AggroColor")) or nil
        local color = (rawColor and Orbit.Engine.ColorCurve and Orbit.Engine.ColorCurve:GetFirstColorFromCurve(rawColor) or rawColor) or THREAT_COLORS[threatStatus]
        Orbit.Skin:ApplyHighlightBorder(frame, AGGRO_HIGHLIGHT_KEY, color, Orbit.Constants.Levels.Border + 2)
    else
        Orbit.Skin:ClearHighlightBorder(frame, AGGRO_HIGHLIGHT_KEY)
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

    -- Apply global font to GroupPositionText, then re-apply Canvas Mode overrides
    local fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font) or "Fonts\\FRIZQT__.TTF"
    frame.GroupPositionText:SetFont(fontPath, GROUP_POSITION_FONT_SIZE, Orbit.Skin:GetFontOutline())
    Orbit.Skin:ApplyFontShadow(frame.GroupPositionText)
    local positions = plugin and plugin.GetSetting and plugin:GetSetting(1, "ComponentPositions")
    local overrides = positions and positions.GroupPositionText and positions.GroupPositionText.overrides
    if overrides then
        Orbit.Engine.OverrideUtils.ApplyFontOverrides(frame.GroupPositionText, overrides, GROUP_POSITION_FONT_SIZE, fontPath)
        Orbit.Engine.OverrideUtils.ApplyTextColor(frame.GroupPositionText, overrides, nil, unit)
    end

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
    local inCanvasMode = Orbit.Engine.CanvasMode:IsActive(frame)

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
    local inCanvasMode = Orbit.Engine.CanvasMode:IsActive(frame)

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
    local inCanvasMode = Orbit.Engine.CanvasMode:IsActive(frame)

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
    local inCanvasMode = Orbit.Engine.CanvasMode:IsActive(frame)

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
    if not UnitIsConnected(unit) then frame.HealthText:SetText(Orbit.L.CMN_OFFLINE); frame.HealthText:SetTextColor(0.7, 0.7, 0.7, 1); frame.HealthText:Show(); return end
    if UnitIsDeadOrGhost(unit) then frame.HealthText:SetText(Orbit.L.CMN_DEAD); frame.HealthText:SetTextColor(0.7, 0.7, 0.7, 1); frame.HealthText:Show(); return end
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
