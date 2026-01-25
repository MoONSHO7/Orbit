---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- Frame Factory for Party Frames
-- Extracted from PartyFrame.lua for better modularity

Orbit.PartyFrameFactoryMixin = {}

-- ============================================================
-- CONSTANTS
-- ============================================================

local POWER_BAR_HEIGHT_RATIO = 0.15

-- ============================================================
-- POWER BAR CREATION
-- ============================================================

function Orbit.PartyFrameFactoryMixin:CreatePowerBar(parent, unit, plugin)
    local power = CreateFrame("StatusBar", nil, parent)
    power:SetPoint("BOTTOMLEFT", 1, 1)
    power:SetPoint("BOTTOMRIGHT", -1, 1)
    power:SetHeight(parent:GetHeight() * POWER_BAR_HEIGHT_RATIO)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    power:SetFrameLevel(parent:GetFrameLevel() + 2)
    
    -- Create background
    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()
    
    -- Get power bar background color (uses centralized Constants)
    local powerType = UnitPowerType(unit)
    local color = Orbit.Constants.Colors.PowerType and Orbit.Constants.Colors.PowerType[powerType]
    if color then
        power.bg:SetColorTexture(color.r, color.g, color.b, color.a or 0.5)
    else
        local bg = Orbit.Constants.Colors.Background
        power.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    end

    return power
end

-- ============================================================
-- STATUS ICON CREATION
-- ============================================================

function Orbit.PartyFrameFactoryMixin:CreateStatusIcons(frame)
    local iconSize = 16
    
    -- Create Overlay container for status indicators to ensure they render above Health/Power bars
    frame.StatusOverlay = CreateFrame("Frame", nil, frame)
    frame.StatusOverlay:SetAllPoints()
    frame.StatusOverlay:SetFrameLevel(frame:GetFrameLevel() + 20)

    -- Role Icon (Tank/Healer/DPS) - Top Left
    frame.RoleIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.RoleIcon:SetSize(iconSize, iconSize)
    frame.RoleIcon.orbitOriginalWidth = iconSize
    frame.RoleIcon.orbitOriginalHeight = iconSize
    frame.RoleIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    frame.RoleIcon:Hide()
    
    -- Leader Icon - Next to Role Icon
    frame.LeaderIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.LeaderIcon:SetSize(iconSize, iconSize)
    frame.LeaderIcon.orbitOriginalWidth = iconSize
    frame.LeaderIcon.orbitOriginalHeight = iconSize
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
    
    -- Center Icons (Phase, ReadyCheck, Res, Summon) - all share same size/position/layer
    local centerIconSize = iconSize * 1.5
    local centerIcons = { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }
    for _, iconKey in ipairs(centerIcons) do
        local icon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
        icon:SetSize(centerIconSize, centerIconSize)
        icon.orbitOriginalWidth = centerIconSize
        icon.orbitOriginalHeight = centerIconSize
        icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
        icon:SetDrawLayer("OVERLAY", 7)
        icon:Hide()
        frame[iconKey] = icon
    end

    -- Marker Icon - Top Center (default)
    frame.MarkerIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.MarkerIcon:SetSize(iconSize, iconSize)
    frame.MarkerIcon.orbitOriginalWidth = iconSize
    frame.MarkerIcon.orbitOriginalHeight = iconSize
    frame.MarkerIcon:SetPoint("TOP", frame, "TOP", 0, -2)
    frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    frame.MarkerIcon:Hide()
end

-- ============================================================
-- EVENT REGISTRATION
-- ============================================================

function Orbit.PartyFrameFactoryMixin:RegisterFrameEvents(frame, unit)
    -- Register unit-specific events
    local unitEvents = {
        "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_FREQUENT",
        "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PHASE", "UNIT_FLAGS",
        "INCOMING_RESURRECT_CHANGED", "UNIT_IN_RANGE_UPDATE"
    }
    for _, event in ipairs(unitEvents) do
        frame:RegisterUnitEvent(event, unit)
    end
    
    -- Register global events
    local globalEvents = {
        "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
        "INCOMING_SUMMON_CHANGED", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE",
        "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE"
    }
    for _, event in ipairs(globalEvents) do
        frame:RegisterEvent(event)
    end
end

-- ============================================================
-- FRAME CONFIGURATION
-- ============================================================

function Orbit.PartyFrameFactoryMixin:ConfigureFrame(frame)
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
end
