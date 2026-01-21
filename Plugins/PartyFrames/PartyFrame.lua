local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- Reference to shared helpers (loaded from PartyFrameHelpers.lua)
local Helpers = nil -- Will be set when first needed

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_PARTY_FRAMES = 4
local POWER_BAR_HEIGHT_RATIO = 0.2

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PartyFrames"

local Plugin = Orbit:RegisterPlugin("Party Frames", SYSTEM_ID, {
    defaults = {
        Width = 160,
        Height = 40,
        Scale = 100,
        ClassColour = true,
        ShowPowerBar = true,
        Orientation = 0,  -- 0 = Vertical, 1 = Horizontal
        Spacing = 0,      -- 0 for merged borders
        HealthTextMode = "percent_short",
        -- Debuff Settings
        DebuffPosition = "Above",  -- Disabled/Above/Below/Left/Right
        MaxDebuffs = 3,
        DebuffSize = 20,
        -- Component Positions (Canvas Mode is single source of truth)
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
        },
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

-- Apply Mixins (including AuraMixin for debuff display)
Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.PartyFramePreviewMixin, Orbit.AuraMixin)

-- Enable Canvas Mode (right-click component editing)
Plugin.canvasMode = true

-- Helper to get global settings from Player Frame
function Plugin:GetPlayerSetting(key)
    local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
    if playerPlugin and playerPlugin.GetSetting then
        return playerPlugin:GetSetting(1, key)
    end
    return nil
end

-- [ HELPERS ]---------------------------------------------------------------------------------------

-- Use centralized power colors from Constants
local function GetPowerColor(powerType)
    return Orbit.Constants.Colors.PowerType[powerType] or { r = 0.5, g = 0.5, b = 0.5 }
end

-- [ POWER BAR CREATION & UPDATE ]-------------------------------------------------------------------

local function CreatePowerBar(parent, unit, plugin)
    local power = CreateFrame("StatusBar", nil, parent)
    power:SetPoint("BOTTOMLEFT", 1, 1)
    power:SetPoint("BOTTOMRIGHT", -1, 1)
    power:SetHeight(parent:GetHeight() * POWER_BAR_HEIGHT_RATIO)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")

    power:SetMinMaxValues(0, 1)
    power:SetValue(0)
    power.unit = unit

    -- Background
    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()

    local color = plugin:GetSetting(1, "BackdropColour")
    if color then
        power.bg:SetColorTexture(color.r, color.g, color.b, color.a or 0.5)
    else
        local bg = Orbit.Constants.Colors.Background
        power.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    end

    return power
end

local function UpdatePowerBar(frame, plugin)
    if not frame.Power then
        return
    end
    local unit = frame.unit
    if not UnitExists(unit) then
        return
    end

    local showPower = plugin:GetSetting(1, "ShowPowerBar")
    if showPower == false then
        frame.Power:Hide()
        return
    end

    frame.Power:Show()

    -- Get power values - pass directly to SetValue (no arithmetic, secret-value safe)
    local power = UnitPower(unit)
    local maxPower = UnitPowerMax(unit)
    local powerType = UnitPowerType(unit)

    frame.Power:SetMinMaxValues(0, maxPower)
    frame.Power:SetValue(power)

    -- Update color based on power type
    local color = GetPowerColor(powerType)
    frame.Power:SetStatusBarColor(color.r, color.g, color.b)
end

local function UpdateFrameLayout(frame, borderSize, plugin)
    -- Lazy-load helpers
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end
    -- Get showPowerBar setting
    local showPowerBar = plugin and plugin:GetSetting(1, "ShowPowerBar")
    if showPowerBar == nil then showPowerBar = true end
    
    Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar)
end

-- [ DEBUFF DISPLAY ]--------------------------------------------------------------------------------

local function UpdateDebuffs(frame, plugin)
    if not frame.debuffContainer then
        return
    end

    local position = plugin:GetSetting(1, "DebuffPosition")
    if position == "Disabled" then
        frame.debuffContainer:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.debuffContainer:Hide()
        return
    end

    local maxDebuffs = plugin:GetSetting(1, "MaxDebuffs") or 3
    local debuffSize = plugin:GetSetting(1, "DebuffSize") or 20
    local spacing = 2

    -- Initialize pool if needed
    if not frame.debuffPool then
        frame.debuffPool = CreateFramePool("Button", frame.debuffContainer, "BackdropTemplate")
    end
    frame.debuffPool:ReleaseAll()

    -- Fetch ALL harmful auras (secret-safe, no dispelName filtering)
    local debuffs = plugin:FetchAuras(unit, "HARMFUL", maxDebuffs)

    if #debuffs == 0 then
        frame.debuffContainer:Hide()
        return
    end

    -- Calculate container size based on position (horizontal vs vertical layout)
    local isVertical = (position == "Left" or position == "Right")
    local containerWidth, containerHeight
    
    if isVertical then
        containerWidth = debuffSize
        containerHeight = (#debuffs * debuffSize) + ((#debuffs - 1) * spacing)
    else
        containerWidth = (#debuffs * debuffSize) + ((#debuffs - 1) * spacing)
        containerHeight = debuffSize
    end
    
    frame.debuffContainer:ClearAllPoints()
    frame.debuffContainer:SetSize(containerWidth, containerHeight)

    if position == "Above" then
        frame.debuffContainer:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    elseif position == "Below" then
        frame.debuffContainer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    elseif position == "Left" then
        frame.debuffContainer:SetPoint("TOPRIGHT", frame, "TOPLEFT", -2, 0)
    elseif position == "Right" then
        frame.debuffContainer:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
    end

    -- Skin settings
    local globalBorder = plugin:GetPlayerSetting("BorderSize") or 1
    local skinSettings = {
        zoom = 0,
        borderStyle = 1,
        borderSize = globalBorder,
        showTimer = false,  -- No countdown timers on party debuffs
    }

    -- Layout icons (vertical for Left/Right, horizontal for Above/Below)
    local xOffset, yOffset = 0, 0
    for i, aura in ipairs(debuffs) do
        local icon = frame.debuffPool:Acquire()
        plugin:SetupAuraIcon(icon, aura, debuffSize, unit, skinSettings)
        plugin:SetupAuraTooltip(icon, aura, unit, "HARMFUL")

        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", frame.debuffContainer, "TOPLEFT", xOffset, yOffset)
        
        if isVertical then
            yOffset = yOffset - (debuffSize + spacing)
        else
            xOffset = xOffset + debuffSize + spacing
        end
    end

    frame.debuffContainer:Show()
end

-- [ BIG DEFENSIVE DISPLAY ]-------------------------------------------------------------------------

-- [ STATUS INDICATOR UPDATES ]---------------------------------------------------------------------

-- Role Icon (Tank/Healer/DPS)
local ROLE_ATLASES = {
    TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}

local function UpdateRoleIcon(frame, plugin)
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
local function UpdateLeaderIcon(frame, plugin)
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
local function UpdateSelectionHighlight(frame, plugin)
    if not frame.SelectionHighlight then return end
    
    local showSelection = plugin:GetSetting(1, "ShowSelectionHighlight")
    if showSelection == false then
        frame.SelectionHighlight:Hide()
        return
    end
    
    local unit = frame.unit
    if UnitIsUnit(unit, "target") then
        frame.SelectionHighlight:Show()
    else
        frame.SelectionHighlight:Hide()
    end
end

-- Aggro Highlight (Threat glow)
local THREAT_COLORS = {
    [0] = nil,  -- No threat - hide
    [1] = { r = 1.0, g = 1.0, b = 0.0, a = 0.5 },  -- Yellow - about to gain/lose
    [2] = { r = 1.0, g = 0.6, b = 0.0, a = 0.6 },  -- Orange - higher threat
    [3] = { r = 1.0, g = 0.4, b = 0.0, a = 0.7 },  -- Orange-Red - has aggro
}

local function UpdateAggroHighlight(frame, plugin)
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
local function UpdatePhaseIcon(frame, plugin)
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
local function UpdateReadyCheck(frame, plugin)
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
local function UpdateIncomingRes(frame, plugin)
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
local function UpdateIncomingSummon(frame, plugin)
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

-- Update all status indicators
local function UpdateAllStatusIndicators(frame, plugin)
    UpdateRoleIcon(frame, plugin)
    UpdateLeaderIcon(frame, plugin)
    UpdateSelectionHighlight(frame, plugin)
    UpdateAggroHighlight(frame, plugin)
    UpdatePhaseIcon(frame, plugin)
    UpdateReadyCheck(frame, plugin)
    UpdateIncomingRes(frame, plugin)
    UpdateIncomingSummon(frame, plugin)
end

-- [ PARTY FRAME CREATION ]--------------------------------------------------------------------------

local function CreatePartyFrame(partyIndex, plugin, unitOverride)
    local unit = unitOverride or ("party" .. partyIndex)
    local frameName = unitOverride and "OrbitPartyPlayerFrame" or ("OrbitPartyFrame" .. partyIndex)

    -- Create base unit button
    local frame = OrbitEngine.UnitButton:Create(plugin.container, unit, frameName)
    frame.editModeName = unitOverride and "Party Player Frame" or ("Party Frame " .. partyIndex)
    frame.systemIndex = 1
    frame.partyIndex = partyIndex
    frame.isPlayerFrame = (unitOverride == "player")

    -- IMPORTANT: Set initial size BEFORE creating child components
    local width = plugin:GetSetting(1, "Width") or 160
    local height = plugin:GetSetting(1, "Height") or 40
    frame:SetSize(width, height)

    -- Set frame strata/level for visibility
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(50 + partyIndex)

    UpdateFrameLayout(frame, plugin:GetPlayerSetting("BorderSize"), plugin)

    -- Create power bar
    frame.Power = CreatePowerBar(frame, unit, plugin)

    -- Create debuff container (renders above/below party frame)
    frame.debuffContainer = CreateFrame("Frame", nil, frame)
    frame.debuffContainer:SetFrameLevel(frame:GetFrameLevel() + 10)


    -- Create Status Indicators
    local iconSize = 16
    
    -- Create Overlay container for status indicators to ensure they render above Health/Power bars
    frame.StatusOverlay = CreateFrame("Frame", nil, frame)
    frame.StatusOverlay:SetAllPoints()
    frame.StatusOverlay:SetFrameLevel(frame:GetFrameLevel() + 20)

    -- Role Icon (Tank/Healer/DPS) - Top Left
    frame.RoleIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.RoleIcon:SetSize(iconSize, iconSize)
    frame.RoleIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    frame.RoleIcon:Hide()
    
    -- Leader Icon - Next to Role Icon
    frame.LeaderIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.LeaderIcon:SetSize(iconSize, iconSize)
    frame.LeaderIcon:SetPoint("LEFT", frame.RoleIcon, "RIGHT", 2, 0)
    frame.LeaderIcon:Hide()
    
    -- Selection Highlight (White border when targeted)
    frame.SelectionHighlight = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.SelectionHighlight:SetAllPoints()
    frame.SelectionHighlight:SetColorTexture(1, 1, 1, 0)  -- Transparent base
    frame.SelectionHighlight:SetDrawLayer("OVERLAY", 7)
    frame.SelectionHighlight:Hide()
    
    -- Create actual highlight borders for selection
    local borderThickness = 2
    frame.SelectionBorders = {}
    for _, edge in pairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local border = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
        border:SetColorTexture(1, 1, 1, 0.8)  -- White border
        border:SetDrawLayer("OVERLAY", 6)
        if edge == "TOP" then
            border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            border:SetHeight(borderThickness)
        elseif edge == "BOTTOM" then
            border:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            border:SetHeight(borderThickness)
        elseif edge == "LEFT" then
            border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            border:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            border:SetWidth(borderThickness)
        elseif edge == "RIGHT" then
            border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            border:SetWidth(borderThickness)
        end
        border:Hide()
        frame.SelectionBorders[edge] = border
    end
    -- Override SelectionHighlight show/hide to control borders
    frame.SelectionHighlight.Show = function(self)
        for _, border in pairs(frame.SelectionBorders) do
            border:Show()
        end
    end
    frame.SelectionHighlight.Hide = function(self)
        for _, border in pairs(frame.SelectionBorders) do
            border:Hide()
        end
    end
    
    -- Aggro Highlight (Threat glow) - Full frame overlay
    frame.AggroHighlight = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.AggroHighlight:SetAllPoints()
    frame.AggroHighlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Highlight")
    frame.AggroHighlight:SetBlendMode("ADD")
    frame.AggroHighlight:SetDrawLayer("OVERLAY", 5)
    frame.AggroHighlight:Hide()
    
    -- Phase Icon (Out of phase indicator) - Center
    frame.PhaseIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.PhaseIcon:SetSize(iconSize * 1.5, iconSize * 1.5)
    frame.PhaseIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.PhaseIcon:SetDrawLayer("OVERLAY", 7)
    frame.PhaseIcon:Hide()
    
    -- Ready Check Icon - Center (high priority)
    frame.ReadyCheckIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.ReadyCheckIcon:SetSize(iconSize * 1.5, iconSize * 1.5)
    frame.ReadyCheckIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.ReadyCheckIcon:SetDrawLayer("OVERLAY", 7)
    frame.ReadyCheckIcon:Hide()
    
    -- Incoming Resurrection Icon - Center
    frame.ResIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.ResIcon:SetSize(iconSize * 1.5, iconSize * 1.5)
    frame.ResIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.ResIcon:SetDrawLayer("OVERLAY", 7)
    frame.ResIcon:Hide()
    
    -- Incoming Summon Icon - Center
    frame.SummonIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.SummonIcon:SetSize(iconSize * 1.5, iconSize * 1.5)
    frame.SummonIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.SummonIcon:SetDrawLayer("OVERLAY", 7)
    frame.SummonIcon:Hide()

    -- Register power events
    frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)

    -- Register aura events for debuff display
    frame:RegisterUnitEvent("UNIT_AURA", unit)
    
    -- Register status indicator events
    frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_PHASE", unit)
    frame:RegisterUnitEvent("UNIT_FLAGS", unit)
    frame:RegisterEvent("READY_CHECK")
    frame:RegisterEvent("READY_CHECK_CONFIRM")
    frame:RegisterEvent("READY_CHECK_FINISHED")
    frame:RegisterUnitEvent("INCOMING_RESURRECT_CHANGED", unit)
    frame:RegisterEvent("INCOMING_SUMMON_CHANGED")
    frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")

    -- Update Loop
    frame:SetScript("OnShow", function(self)
        self:UpdateAll()
        UpdatePowerBar(self, plugin)
        UpdateFrameLayout(self, plugin:GetPlayerSetting("BorderSize"), plugin)
        UpdateDebuffs(self, plugin)
        UpdateAllStatusIndicators(self, plugin)
    end)

    -- Extended OnEvent handler
    local originalOnEvent = frame:GetScript("OnEvent")
    frame:SetScript("OnEvent", function(f, event, eventUnit, ...)
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            if eventUnit == unit then
                UpdatePowerBar(f, plugin)
            end
            return
        end

        if event == "UNIT_AURA" then
            if eventUnit == unit then
                UpdateDebuffs(f, plugin)
            end
            return
        end
        
        -- Target changed - update selection highlight for ALL frames
        if event == "PLAYER_TARGET_CHANGED" then
            UpdateSelectionHighlight(f, plugin)
            return
        end
        
        -- Threat updates
        if event == "UNIT_THREAT_SITUATION_UPDATE" then
            if eventUnit == unit then
                UpdateAggroHighlight(f, plugin)
            end
            return
        end
        
        -- Phase updates
        if event == "UNIT_PHASE" or event == "UNIT_FLAGS" then
            if eventUnit == unit then
                UpdatePhaseIcon(f, plugin)
            end
            return
        end
        
        -- Ready check events
        if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            UpdateReadyCheck(f, plugin)
            return
        end
        
        -- Resurrection updates
        if event == "INCOMING_RESURRECT_CHANGED" then
            if eventUnit == unit then
                UpdateIncomingRes(f, plugin)
            end
            return
        end
        
        -- Summon updates
        if event == "INCOMING_SUMMON_CHANGED" then
            UpdateIncomingSummon(f, plugin)
            return
        end
        
        -- Role/Group updates
        if event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" then
            UpdateRoleIcon(f, plugin)
            UpdateLeaderIcon(f, plugin)
            return
        end

        if originalOnEvent then
            originalOnEvent(f, event, eventUnit, ...)
        end
    end)

    -- Enable class coloring (for player party members)
    frame:SetClassColour(true)

    -- Enable reaction coloring (for NPC party members like followers)
    if frame.SetReactionColour then
        frame:SetReactionColour(true)
    end

    -- Enable health text display
    frame.healthTextEnabled = true

    -- Enable advanced health bar features
    if frame.SetAbsorbsEnabled then
        frame:SetAbsorbsEnabled(true)
    end
    if frame.SetHealAbsorbsEnabled then
        frame:SetHealAbsorbsEnabled(true)
    end

    return frame
end

-- [ NATIVE FRAME HIDING ]-------------------------------------------------------------------------

local function HideNativePartyFrames()
    -- Hide legacy party frames (PartyMemberFrame1-4)
    for i = 1, 4 do
        local partyFrame = _G["PartyMemberFrame" .. i]
        if partyFrame then
            partyFrame:ClearAllPoints()
            partyFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
            partyFrame:SetAlpha(0)
            partyFrame:SetScale(0.001)
            partyFrame:EnableMouse(false)

            -- Hook SetPoint to prevent resets
            if not partyFrame.orbitSetPointHooked then
                hooksecurefunc(partyFrame, "SetPoint", function(self)
                    if InCombatLockdown() then
                        return
                    end
                    if not self.isMovingOffscreen then
                        self.isMovingOffscreen = true
                        self:ClearAllPoints()
                        self:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
                        self.isMovingOffscreen = false
                    end
                end)
                partyFrame.orbitSetPointHooked = true
            end
        end
    end

    -- Hide modern PartyFrame container (classic-style party frames in Dragonflight+)
    if PartyFrame then
        OrbitEngine.NativeFrame:Hide(PartyFrame)
    end

    -- Hide CompactPartyFrame (raid-style party frames)
    if CompactPartyFrame then
        OrbitEngine.NativeFrame:Hide(CompactPartyFrame)
    end
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = 1
    local WL = OrbitEngine.WidgetLogic

    local schema = {
        hideNativeSettings = true,
        controls = {
            {
                type = "dropdown",
                key = "Orientation",
                label = "Orientation",
                options = {
                    { text = "Vertical", value = 0 },
                    { text = "Horizontal", value = 1 },
                },
                default = 0,
                onChange = function(val)
                    self:SetSetting(1, "Orientation", val)
                    self:ApplySettings()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:SchedulePreviewUpdate()
                    end
                end,
            },
            { type = "slider", key = "Width", label = "Width", min = 100, max = 250, step = 5, default = 160,
                onChange = function(val)
                    self:SetSetting(1, "Width", val)
                    self:ApplySettings()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:SchedulePreviewUpdate()
                    end
                end,
            },
            { type = "slider", key = "Height", label = "Height", min = 20, max = 60, step = 5, default = 40,
                onChange = function(val)
                    self:SetSetting(1, "Height", val)
                    self:ApplySettings()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:SchedulePreviewUpdate()
                    end
                end,
            },
            { type = "slider", key = "Spacing", label = "Spacing", min = 0, max = 10, step = 1, default = 0,
                onChange = function(val)
                    self:SetSetting(1, "Spacing", val)
                    self:ApplySettings()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:SchedulePreviewUpdate()
                    end
                end,
            },
            {
                type = "dropdown",
                key = "HealthTextMode",
                label = "Health Text",
                options = {
                    { text = "Hide", value = "hide" },
                    { text = "Percentage / Short", value = "percent_short" },
                    { text = "Short / Percentage", value = "short_percent" },
                    { text = "Percentage / Raw", value = "percent_raw" },
                    { text = "Raw / Percentage", value = "raw_percent" },
                },
                default = "percent_short",
                onChange = function(val)
                    self:SetSetting(1, "HealthTextMode", val)
                    self:ApplySettings()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:SchedulePreviewUpdate()
                    end
                end,
            },
            {
                type = "dropdown",
                key = "DebuffPosition",
                label = "Debuff Position",
                options = {
                    { text = "Disabled", value = "Disabled" },
                    { text = "Above", value = "Above" },
                    { text = "Below", value = "Below" },
                    { text = "Left", value = "Left" },
                    { text = "Right", value = "Right" },
                },
                default = "Above",
                onChange = function(val)
                    self:SetSetting(1, "DebuffPosition", val)
                    self:ApplySettings()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:SchedulePreviewUpdate()
                    end
                end,
            },
            { type = "slider", key = "MaxDebuffs", label = "Max Debuffs", min = 1, max = 6, step = 1, default = 3,
                visibleIf = function() return self:GetSetting(1, "DebuffPosition") ~= "Disabled" end,
                onChange = function(val)
                    self:SetSetting(1, "MaxDebuffs", val)
                    self:ApplySettings()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:SchedulePreviewUpdate()
                    end
                end,
            },
            { type = "slider", key = "DebuffSize", label = "Debuff Size", min = 12, max = 32, step = 2, default = 20,
                visibleIf = function() return self:GetSetting(1, "DebuffPosition") ~= "Disabled" end,
                onChange = function(val)
                    self:SetSetting(1, "DebuffSize", val)
                    self:ApplySettings()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:SchedulePreviewUpdate()
                    end
                end,
            },
            { type = "checkbox", key = "ShowPowerBar", label = "Show Power Bar", default = true,
                onChange = function(val)
                    self:SetSetting(1, "ShowPowerBar", val)
                    self:ApplySettings()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:SchedulePreviewUpdate()
                    end
                end,
            },
        },
    }

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------

function Plugin:OnLoad()
    -- Hide native party frames
    HideNativePartyFrames()

    -- Create container frame for all party frames
    self.container = CreateFrame("Frame", "OrbitPartyContainer", UIParent, "SecureHandlerStateTemplate")
    self.container.editModeName = "Party Frames"
    self.container.systemIndex = 1
    self.container:SetFrameStrata("MEDIUM")
    self.container:SetFrameLevel(49)
    self.container:SetClampedToScreen(true)

    -- Create party frames (parented to container)
    self.frames = {}
    for i = 1, MAX_PARTY_FRAMES do
        self.frames[i] = CreatePartyFrame(i, self)
        self.frames[i]:SetParent(self.container)

        -- Set orbitPlugin reference for Canvas Mode support
        self.frames[i].orbitPlugin = self

        -- Register unit watch for visibility
        RegisterUnitWatch(self.frames[i])
    end



    -- Register components for Canvas Mode drag (on CONTAINER, using first frame's elements)
    -- Canvas Mode opens on the container, so components must be registered there
    local pluginRef = self
    local firstFrame = self.frames[1]
    if OrbitEngine.ComponentDrag and firstFrame then
        -- Register Name for drag
        if firstFrame.Name then
            OrbitEngine.ComponentDrag:Attach(firstFrame.Name, self.container, {
                key = "Name",
                onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY, justifyH)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    positions.Name = { anchorX = anchorX, anchorY = anchorY, 
                                       offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end
            })
        end
        -- Register HealthText for drag
        if firstFrame.HealthText then
            OrbitEngine.ComponentDrag:Attach(firstFrame.HealthText, self.container, {
                key = "HealthText",
                onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY, justifyH)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    positions.HealthText = { anchorX = anchorX, anchorY = anchorY, 
                                             offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end
            })
        end
        -- Register RoleIcon for drag
        if firstFrame.RoleIcon then
            OrbitEngine.ComponentDrag:Attach(firstFrame.RoleIcon, self.container, {
                key = "RoleIcon",
                onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    positions.RoleIcon = { anchorX = anchorX, anchorY = anchorY, 
                                           offsetX = offsetX, offsetY = offsetY }
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end
            })
        end
        -- Register LeaderIcon for drag
        if firstFrame.LeaderIcon then
            OrbitEngine.ComponentDrag:Attach(firstFrame.LeaderIcon, self.container, {
                key = "LeaderIcon",
                onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    positions.LeaderIcon = { anchorX = anchorX, anchorY = anchorY, 
                                             offsetX = offsetX, offsetY = offsetY }
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end
            })
        end
        -- Register PhaseIcon for drag
        if firstFrame.PhaseIcon then
            OrbitEngine.ComponentDrag:Attach(firstFrame.PhaseIcon, self.container, {
                key = "PhaseIcon",
                onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    positions.PhaseIcon = { anchorX = anchorX, anchorY = anchorY, 
                                            offsetX = offsetX, offsetY = offsetY }
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end
            })
        end
        -- Register ReadyCheckIcon for drag
        if firstFrame.ReadyCheckIcon then
            OrbitEngine.ComponentDrag:Attach(firstFrame.ReadyCheckIcon, self.container, {
                key = "ReadyCheckIcon",
                onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    positions.ReadyCheckIcon = { anchorX = anchorX, anchorY = anchorY, 
                                                 offsetX = offsetX, offsetY = offsetY }
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end
            })
        end
        -- Register ResIcon for drag
        if firstFrame.ResIcon then
            OrbitEngine.ComponentDrag:Attach(firstFrame.ResIcon, self.container, {
                key = "ResIcon",
                onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    positions.ResIcon = { anchorX = anchorX, anchorY = anchorY, 
                                          offsetX = offsetX, offsetY = offsetY }
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end
            })
        end
        -- Register SummonIcon for drag
        if firstFrame.SummonIcon then
            OrbitEngine.ComponentDrag:Attach(firstFrame.SummonIcon, self.container, {
                key = "SummonIcon",
                onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    positions.SummonIcon = { anchorX = anchorX, anchorY = anchorY, 
                                             offsetX = offsetX, offsetY = offsetY }
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end
            })
        end
    end

    -- Container is the selectable frame for Edit Mode
    self.frame = self.container
    self.frame.anchorOptions = { horizontal = true, vertical = false }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, 1)

    -- Canvas Mode should use the first party frame for preview (not entire container)
    self.container.orbitCanvasFrame = self.frames[1]
    self.container.orbitCanvasTitle = "Party Frame"

    -- Set default container position
    if not self.container:GetPoint() then
        self.container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
    end

    -- Register secure visibility driver (show when in party but NOT in raid, hide when solo)
    local visibilityDriver = "[petbattle] hide; [@raid1,exists] hide; [@party1,exists] show; hide"
    RegisterStateDriver(self.container, "visibility", visibilityDriver)

    -- Explicit Show Bridge: Ensure container is active to receive first state evaluation
    self.container:Show()

    -- Give container a minimum size so it's clickable in Edit Mode
    self.container:SetSize(self:GetSetting(1, "Width") or 160, 100)

    -- Position frames
    self:PositionFrames()

    -- Apply initial settings
    self:ApplySettings()

    -- Register for group events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "GROUP_ROSTER_UPDATE" then
            for i, frame in ipairs(self.frames) do
                if frame.UpdateAll then
                    frame:UpdateAll()
                    UpdatePowerBar(frame, self)
                end
            end
        end

        -- Update container size and reposition frames if out of combat
        if not InCombatLockdown() then
            self:PositionFrames()
            self:UpdateContainerSize()
        end
    end)

    self:RegisterStandardEvents()

    -- Edit Mode callbacks
    if EventRegistry and not self.editModeCallbacksRegistered then
        self.editModeCallbacksRegistered = true

        EventRegistry:RegisterCallback("EditMode.Enter", function()
            if not InCombatLockdown() then
                UnregisterStateDriver(self.container, "visibility")
                self.container:Show()
                self:ShowPreview()
            end
        end, self)

        EventRegistry:RegisterCallback("EditMode.Exit", function()
            if not InCombatLockdown() then
                self:HidePreview()
                local visibilityDriver = "[petbattle] hide; [@raid1,exists] hide; [@party1,exists] show; hide"
                RegisterStateDriver(self.container, "visibility", visibilityDriver)
            end
        end, self)
    end

    -- Pre-hook Canvas Mode Dialog to prepare icons BEFORE cloning
    local dialog = OrbitEngine.CanvasModeDialog or Orbit.CanvasModeDialog
    if dialog and not self.canvasModeHooked then
        self.canvasModeHooked = true
        local originalOpen = dialog.Open
        dialog.Open = function(dlg, frame, plugin, systemIndex)
            -- Check if canvas mode is opening on our container or first frame
            if frame == self.container or frame == self.frames[1] then
                self:PrepareIconsForCanvasMode()
            end
            return originalOpen(dlg, frame, plugin, systemIndex)
        end
    end
end

-- Prepare status icons with placeholder atlases for Canvas Mode cloning
function Plugin:PrepareIconsForCanvasMode()
    local frame = self.frames[1]
    if not frame then return end

    -- Set placeholder atlases on icons so Canvas Mode can clone them
    if frame.PhaseIcon then
        frame.PhaseIcon:SetAtlas("RaidFrame-Icon-Phasing")
        frame.PhaseIcon:SetSize(24, 24)
    end
    if frame.ReadyCheckIcon then
        frame.ReadyCheckIcon:SetAtlas("UI-HUD-Minimap-Tracking-Question")
        frame.ReadyCheckIcon:SetSize(24, 24)
    end
    if frame.ResIcon then
        frame.ResIcon:SetAtlas("RaidFrame-Icon-Rez")
        frame.ResIcon:SetSize(24, 24)
    end
    if frame.SummonIcon then
        frame.SummonIcon:SetAtlas("RaidFrame-Icon-SummonPending")
        frame.SummonIcon:SetSize(24, 24)
    end
    -- RoleIcon and LeaderIcon already have atlases set in preview, but ensure they're sized
    if frame.RoleIcon then
        if not frame.RoleIcon:GetAtlas() then
            frame.RoleIcon:SetAtlas("UI-LFG-RoleIcon-DPS-Micro-GroupFinder")
        end
        frame.RoleIcon:SetSize(16, 16)
    end
    if frame.LeaderIcon then
        if not frame.LeaderIcon:GetAtlas() then
            frame.LeaderIcon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon")
        end
        frame.LeaderIcon:SetSize(16, 16)
    end
end

-- [ FRAME POSITIONING ]-----------------------------------------------------------------------------

function Plugin:PositionFrames()
    if InCombatLockdown() then
        return
    end

    -- Lazy-load helpers
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end

    local spacing = self:GetSetting(1, "Spacing") or 0
    local orientation = self:GetSetting(1, "Orientation") or 0
    local width = self:GetSetting(1, "Width") or 160
    local height = self:GetSetting(1, "Height") or 40
    -- Position party frames
    for i, frame in ipairs(self.frames) do
        frame:ClearAllPoints()

        local xOffset, yOffset = Helpers:CalculateFramePosition(i, width, height, spacing, orientation)
        frame:SetPoint("TOPLEFT", self.container, "TOPLEFT", xOffset, yOffset)
    end

    self:UpdateContainerSize()
end

function Plugin:UpdateContainerSize()
    if InCombatLockdown() then
        return
    end

    -- Lazy-load helpers
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end

    local width = self:GetSetting(1, "Width") or 160
    local height = self:GetSetting(1, "Height") or 40
    local spacing = self:GetSetting(1, "Spacing") or 0
    local orientation = self:GetSetting(1, "Orientation") or 0
    -- Count visible frames (or preview frames)
    local visibleCount = 0
    
    -- Count party frames
    for _, frame in ipairs(self.frames) do
        if frame:IsShown() or frame.preview then
            visibleCount = visibleCount + 1
        end
    end

    visibleCount = math.max(1, visibleCount)

    local containerWidth, containerHeight = Helpers:CalculateContainerSize(
        visibleCount, width, height, spacing, orientation
    )
    self.container:SetSize(containerWidth, containerHeight)
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------

function Plugin:UpdateLayout(frame)
    if not frame then
        return
    end
    if InCombatLockdown() then
        return
    end

    local width = self:GetSetting(1, "Width") or 160
    local height = self:GetSetting(1, "Height") or 40

    for _, partyFrame in ipairs(self.frames) do
        partyFrame:SetSize(width, height)
        UpdateFrameLayout(partyFrame, self:GetPlayerSetting("BorderSize"), self)
    end

    self:PositionFrames()
end

function Plugin:ApplySettings()
    if not self.frames then
        return
    end

    local width = self:GetSetting(1, "Width") or 160
    local height = self:GetSetting(1, "Height") or 40
    local healthTextMode = self:GetSetting(1, "HealthTextMode") or "percent_short"
    local borderSize = self:GetPlayerSetting("BorderSize") or 1
    local textureName = self:GetPlayerSetting("Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"

    -- Build list of all frames
    local allFrames = {}
    for _, frame in ipairs(self.frames) do
        table.insert(allFrames, frame)
    end

    for _, frame in ipairs(allFrames) do
        -- Only apply settings to non-preview frames
        if not frame.preview then
            -- Apply size
            Orbit:SafeAction(function()
                frame:SetSize(width, height)
            end)

            -- Apply texture
            if frame.Health then
                frame.Health:SetStatusBarTexture(texturePath)
            end
            if frame.Power then
                frame.Power:SetStatusBarTexture(texturePath)
            end

            -- Apply border
            if frame.SetBorder then
                frame:SetBorder(borderSize)
            end

            -- Apply layout
            UpdateFrameLayout(frame, borderSize, self)

            -- Apply health text mode
            if frame.SetHealthTextMode then
                frame:SetHealthTextMode(healthTextMode)
            end

            -- Re-apply class coloring (ensures it takes effect after preview)
            if frame.SetClassColour then
                frame:SetClassColour(true)
            end

            -- Apply text styling from global settings
            self:ApplyTextStyling(frame)

            -- Update power bar visibility
            UpdatePowerBar(frame, self)

            -- Update debuff display
            UpdateDebuffs(frame, self)
            
            -- Update all status indicators
            UpdateAllStatusIndicators(frame, self)

            -- Trigger full update (applies class color to health bar)
            if frame.UpdateAll then
                frame:UpdateAll()
            end
        end
    end

    -- Reposition frames
    self:PositionFrames()

    -- Restore container position
    OrbitEngine.Frame:RestorePosition(self.container, self, 1)

    -- Apply saved component positions to all party frames
    local savedPositions = self:GetSetting(1, "ComponentPositions")
    if savedPositions then
        -- Restore positions for components registered on container
        if OrbitEngine.ComponentDrag then
            OrbitEngine.ComponentDrag:RestoreFramePositions(self.container, savedPositions)
        end
        
        -- Also apply positions to ALL frames' elements (not just first frame)
        for _, frame in ipairs(self.frames) do
            -- Apply via UnitButton mixin (for Name/HealthText with justifyH)
            if frame.ApplyComponentPositions then
                frame:ApplyComponentPositions(savedPositions)
            end

            -- Apply positions for other status icons
            local icons = { "RoleIcon", "LeaderIcon", "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }
            for _, iconKey in ipairs(icons) do
                if frame[iconKey] and savedPositions[iconKey] then
                    local pos = savedPositions[iconKey]
                    local anchorX = pos.anchorX or "CENTER"
                    local anchorY = pos.anchorY or "CENTER"
                    local offsetX = pos.offsetX or 0
                    local offsetY = pos.offsetY or 0
                    
                    local anchorPoint
                    if anchorY == "CENTER" and anchorX == "CENTER" then
                        anchorPoint = "CENTER"
                    elseif anchorY == "CENTER" then
                        anchorPoint = anchorX
                    elseif anchorX == "CENTER" then
                        anchorPoint = anchorY
                    else
                        anchorPoint = anchorY .. anchorX
                    end
                    
                    local finalX = offsetX
                    local finalY = offsetY
                    if anchorX == "RIGHT" then finalX = -offsetX end
                    if anchorY == "TOP" then finalY = -offsetY end
                    
                    frame[iconKey]:ClearAllPoints()
                    -- These are parented to StatusOverlay but positioned relative to frame for drag consistency
                    frame[iconKey]:SetPoint("CENTER", frame, anchorPoint, finalX, finalY)
                end
            end
        end
    end
end

function Plugin:UpdateVisuals()
    for _, frame in ipairs(self.frames) do
        if frame.UpdateAll then
            frame:UpdateAll()
            UpdatePowerBar(frame, self)
        end
    end
end
