---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

Orbit.PartyFrameFactoryMixin = {}

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local POWER_BAR_HEIGHT_RATIO = Orbit.PartyFrameHelpers.LAYOUT.PowerBarRatio

-- [ POWER BAR CREATION ]----------------------------------------------------------------------------
function Orbit.PartyFrameFactoryMixin:CreatePowerBar(parent, unit, plugin)
    local power = CreateFrame("StatusBar", nil, parent)
    power:SetPoint("BOTTOMLEFT", 0, 0)
    power:SetPoint("BOTTOMRIGHT", 0, 0)
    power:SetHeight(parent:GetHeight() * POWER_BAR_HEIGHT_RATIO)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    power:SetFrameLevel(parent:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()
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

-- [ STATUS ICON CREATION ]--------------------------------------------------------------------------

function Orbit.PartyFrameFactoryMixin:CreateStatusIcons(frame)
    local iconSize = 16

    -- BorderOverlay: Selection/Aggro borders (below glow, above icons)
    frame.BorderOverlay = CreateFrame("Frame", nil, frame)
    frame.BorderOverlay:SetAllPoints()
    frame.BorderOverlay:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Border)

    -- StatusOverlay: Text and component icons (above glow)
    frame.StatusOverlay = CreateFrame("Frame", nil, frame)
    frame.StatusOverlay:SetAllPoints()
    frame.StatusOverlay:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
    if frame.StatusOverlay.SetIgnoreParentAlpha then frame.StatusOverlay:SetIgnoreParentAlpha(true) end

    frame.RoleIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.RoleIcon:SetSize(iconSize, iconSize)
    frame.RoleIcon.orbitOriginalWidth, frame.RoleIcon.orbitOriginalHeight = iconSize, iconSize
    frame.RoleIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    frame.RoleIcon:Hide()

    frame.LeaderIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.LeaderIcon:SetSize(iconSize, iconSize)
    frame.LeaderIcon.orbitOriginalWidth, frame.LeaderIcon.orbitOriginalHeight = iconSize, iconSize
    frame.LeaderIcon:SetPoint("LEFT", frame.RoleIcon, "RIGHT", 2, 0)
    frame.LeaderIcon:Hide()



    local centerIconSize = iconSize * 1.5
    for _, iconKey in ipairs({ "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }) do
        local icon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
        icon:SetSize(centerIconSize, centerIconSize)
        icon.orbitOriginalWidth, icon.orbitOriginalHeight = centerIconSize, centerIconSize
        icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
        icon:SetDrawLayer("OVERLAY", Orbit.Constants.Layers.Text)
        icon:Hide()
        frame[iconKey] = icon
    end
    frame.MarkerIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.MarkerIcon:SetSize(iconSize, iconSize)
    frame.MarkerIcon.orbitOriginalWidth, frame.MarkerIcon.orbitOriginalHeight = iconSize, iconSize
    frame.MarkerIcon:SetPoint("TOP", frame, "TOP", 0, -2)
    frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    frame.MarkerIcon:Hide()

    -- Defensive and Important single-aura icons (Button frames for skin/border support)
    local auraIconSize = centerIconSize
    for _, iconKey in ipairs({ "DefensiveIcon", "CrowdControlIcon" }) do
        local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        btn:SetSize(auraIconSize, auraIconSize)
        btn.orbitOriginalWidth, btn.orbitOriginalHeight = auraIconSize, auraIconSize
        btn:SetPoint("CENTER", frame, "CENTER", 0, 0)
        btn:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
        btn.Icon = btn:CreateTexture(nil, "ARTWORK")
        btn.Icon:SetAllPoints()
        btn.icon = btn.Icon
        btn:Hide()
        btn:EnableMouse(false)
        frame[iconKey] = btn
    end

    local paa = CreateFrame("Frame", nil, frame)
    paa:SetSize(auraIconSize, auraIconSize)
    paa.orbitOriginalWidth, paa.orbitOriginalHeight = auraIconSize, auraIconSize
    paa:SetPoint("CENTER", frame, "CENTER", 0, 0)
    paa:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
    paa:EnableMouse(false)
    if paa.SetPropagateMouseMotion then paa:SetPropagateMouseMotion(true) end
    if paa.SetPropagateMouseClicks then paa:SetPropagateMouseClicks(true) end
    paa.Icon = paa:CreateTexture(nil, "ARTWORK")
    paa.Icon:SetAllPoints()
    paa.icon = paa.Icon
    paa:Hide()
    frame.PrivateAuraAnchor = paa
end

-- [ EVENT REGISTRATION ]----------------------------------------------------------------------------

function Orbit.PartyFrameFactoryMixin:RegisterFrameEvents(frame, unit)
    local unitEvents = {
        "UNIT_HEALTH",
        "UNIT_MAXHEALTH",
        "UNIT_ABSORB_AMOUNT_CHANGED",
        "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
        "UNIT_HEAL_PREDICTION",
        "UNIT_POWER_UPDATE",
        "UNIT_MAXPOWER",
        "UNIT_DISPLAYPOWER",
        "UNIT_POWER_FREQUENT",
        "UNIT_AURA",
        "UNIT_THREAT_SITUATION_UPDATE",
        "UNIT_PHASE",
        "UNIT_FLAGS",
        "UNIT_NAME_UPDATE",
        "UNIT_ENTERED_VEHICLE",
        "UNIT_EXITED_VEHICLE",
        "UNIT_OTHER_PARTY_CHANGED",
        "INCOMING_RESURRECT_CHANGED",
        "UNIT_IN_RANGE_UPDATE",
        "UNIT_CONNECTION",
    }
    for _, event in ipairs(unitEvents) do
        frame:RegisterUnitEvent(event, unit)
    end
    local globalEvents = {
        "READY_CHECK",
        "READY_CHECK_CONFIRM",
        "READY_CHECK_FINISHED",
        "INCOMING_SUMMON_CHANGED",
        "PLAYER_ROLES_ASSIGNED",
        "GROUP_ROSTER_UPDATE",
        "PLAYER_TARGET_CHANGED",
        "RAID_TARGET_UPDATE",
        "PARTY_LEADER_CHANGED",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED",
    }
    for _, event in ipairs(globalEvents) do
        frame:RegisterEvent(event)
    end
end

-- [ FRAME CONFIGURATION ]---------------------------------------------------------------------------

function Orbit.PartyFrameFactoryMixin:ConfigureFrame(frame)
    frame:SetClassColour(true)
    if frame.SetReactionColour then
        frame:SetReactionColour(true)
    end
    frame.healthTextEnabled = true
    if frame.SetAbsorbsEnabled then
        frame:SetAbsorbsEnabled(true)
    end
    if frame.SetHealAbsorbsEnabled then
        frame:SetHealAbsorbsEnabled(true)
    end
end
