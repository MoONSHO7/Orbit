---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

Orbit.RaidFrameFactoryMixin = {}

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local POWER_BAR_HEIGHT_RATIO = Orbit.RaidFrameHelpers.LAYOUT.PowerBarRatio
local ICON_SIZE = 12
local CENTER_ICON_SIZE = 18

-- [ POWER BAR CREATION ]----------------------------------------------------------------------------

function Orbit.RaidFrameFactoryMixin:CreatePowerBar(parent, unit)
    local power = CreateFrame("StatusBar", nil, parent)
    power:SetPoint("BOTTOMLEFT", 0, 0)
    power:SetPoint("BOTTOMRIGHT", 0, 0)
    power:SetHeight(parent:GetHeight() * POWER_BAR_HEIGHT_RATIO)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    power:SetFrameLevel(parent:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
    power:SetMinMaxValues(0, 1)
    power:SetValue(0)
    power.unit = unit
    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(power, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)
    return power
end

-- [ STATUS ICON CREATION ]--------------------------------------------------------------------------

function Orbit.RaidFrameFactoryMixin:CreateStatusIcons(frame)
    frame.BorderOverlay = CreateFrame("Frame", nil, frame)
    frame.BorderOverlay:SetAllPoints()
    frame.BorderOverlay:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Border)

    frame.StatusOverlay = CreateFrame("Frame", nil, frame)
    frame.StatusOverlay:SetAllPoints()
    frame.StatusOverlay:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)

    frame.RoleIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.RoleIcon:SetSize(ICON_SIZE, ICON_SIZE)
    frame.RoleIcon.orbitOriginalWidth, frame.RoleIcon.orbitOriginalHeight = ICON_SIZE, ICON_SIZE
    frame.RoleIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.RoleIcon:Hide()

    frame.LeaderIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.LeaderIcon:SetSize(ICON_SIZE, ICON_SIZE)
    frame.LeaderIcon.orbitOriginalWidth, frame.LeaderIcon.orbitOriginalHeight = ICON_SIZE, ICON_SIZE
    frame.LeaderIcon:SetPoint("LEFT", frame.RoleIcon, "RIGHT", 1, 0)
    frame.LeaderIcon:Hide()

    frame.MainTankIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.MainTankIcon:SetSize(ICON_SIZE, ICON_SIZE)
    frame.MainTankIcon.orbitOriginalWidth, frame.MainTankIcon.orbitOriginalHeight = ICON_SIZE, ICON_SIZE
    frame.MainTankIcon:SetPoint("LEFT", frame.LeaderIcon, "RIGHT", 1, 0)
    frame.MainTankIcon:Hide()



    for _, iconKey in ipairs({ "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }) do
        local icon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
        icon:SetSize(CENTER_ICON_SIZE, CENTER_ICON_SIZE)
        icon.orbitOriginalWidth, icon.orbitOriginalHeight = CENTER_ICON_SIZE, CENTER_ICON_SIZE
        icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
        icon:SetDrawLayer("OVERLAY", Orbit.Constants.Layers.Text)
        icon:Hide()
        frame[iconKey] = icon
    end

    frame.MarkerIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.MarkerIcon:SetSize(ICON_SIZE, ICON_SIZE)
    frame.MarkerIcon.orbitOriginalWidth, frame.MarkerIcon.orbitOriginalHeight = ICON_SIZE, ICON_SIZE
    frame.MarkerIcon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    frame.MarkerIcon:Hide()

    for _, iconKey in ipairs({ "DefensiveIcon", "CrowdControlIcon" }) do
        local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        btn:SetSize(CENTER_ICON_SIZE, CENTER_ICON_SIZE)
        btn.orbitOriginalWidth, btn.orbitOriginalHeight = CENTER_ICON_SIZE, CENTER_ICON_SIZE
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
    paa:SetSize(CENTER_ICON_SIZE, CENTER_ICON_SIZE)
    paa.orbitOriginalWidth, paa.orbitOriginalHeight = CENTER_ICON_SIZE, CENTER_ICON_SIZE
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

local FACTORY_UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
    "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PHASE", "UNIT_FLAGS",
    "UNIT_NAME_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_OTHER_PARTY_CHANGED",
    "INCOMING_RESURRECT_CHANGED", "UNIT_IN_RANGE_UPDATE", "UNIT_CONNECTION",
}
local FACTORY_GLOBAL_EVENTS = {
    "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
    "INCOMING_SUMMON_CHANGED", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE",
    "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

function Orbit.RaidFrameFactoryMixin:RegisterFrameEvents(frame, unit)
    for _, event in ipairs(FACTORY_UNIT_EVENTS) do frame:RegisterUnitEvent(event, unit) end
    for _, event in ipairs(FACTORY_GLOBAL_EVENTS) do frame:RegisterEvent(event) end
end

-- [ FRAME CONFIGURATION ]---------------------------------------------------------------------------

function Orbit.RaidFrameFactoryMixin:ConfigureFrame(frame)
    frame:SetClassColour(true)
    if frame.SetReactionColour then frame:SetReactionColour(true) end
    frame.healthTextEnabled = true
    if frame.SetAbsorbsEnabled then frame:SetAbsorbsEnabled(true) end
    if frame.SetHealAbsorbsEnabled then frame:SetHealAbsorbsEnabled(true) end
end
