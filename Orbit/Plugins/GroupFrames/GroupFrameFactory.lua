---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

Orbit.GroupFrameFactoryMixin = {}

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local Helpers = Orbit.GroupFrameHelpers
local POWER_BAR_HEIGHT_RATIO = Helpers.LAYOUT.PowerBarRatio
local PARTY_ICON_SIZE = 16
local PARTY_CENTER_ICON_SIZE = 24
local RAID_ICON_SIZE = 12
local RAID_CENTER_ICON_SIZE = 18

-- [ POWER BAR CREATION ]----------------------------------------------------------------------------
function Orbit.GroupFrameFactoryMixin:CreatePowerBar(parent, unit)
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
function Orbit.GroupFrameFactoryMixin:CreateStatusIcons(frame, isPartyTier)
    local iconSize = isPartyTier and PARTY_ICON_SIZE or RAID_ICON_SIZE
    local centerIconSize = isPartyTier and PARTY_CENTER_ICON_SIZE or RAID_CENTER_ICON_SIZE

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
    frame.RoleIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", isPartyTier and 2 or 1, isPartyTier and -2 or -1)
    frame.RoleIcon:Hide()

    frame.LeaderIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.LeaderIcon:SetSize(iconSize, iconSize)
    frame.LeaderIcon.orbitOriginalWidth, frame.LeaderIcon.orbitOriginalHeight = iconSize, iconSize
    frame.LeaderIcon:SetPoint("LEFT", frame.RoleIcon, "RIGHT", isPartyTier and 2 or 1, 0)
    frame.LeaderIcon:Hide()

    -- MainTankIcon (raid-only, but always created for simplicity)
    frame.MainTankIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.MainTankIcon:SetSize(iconSize, iconSize)
    frame.MainTankIcon.orbitOriginalWidth, frame.MainTankIcon.orbitOriginalHeight = iconSize, iconSize
    frame.MainTankIcon:SetPoint("LEFT", frame.LeaderIcon, "RIGHT", 1, 0)
    frame.MainTankIcon:Hide()

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
    frame.MarkerIcon:SetPoint(isPartyTier and "TOP" or "TOPRIGHT", frame, isPartyTier and "TOP" or "TOPRIGHT", isPartyTier and 0 or -1, isPartyTier and -2 or -1)
    frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    frame.MarkerIcon:Hide()

    -- Defensive and CC single-aura icons (Button frames for skin/border support)
    for _, iconKey in ipairs({ "DefensiveIcon", "CrowdControlIcon" }) do
        local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        btn:SetSize(centerIconSize, centerIconSize)
        btn.orbitOriginalWidth, btn.orbitOriginalHeight = centerIconSize, centerIconSize
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
    paa:SetSize(centerIconSize, centerIconSize)
    paa.orbitOriginalWidth, paa.orbitOriginalHeight = centerIconSize, centerIconSize
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
local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_FREQUENT",
    "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PHASE", "UNIT_FLAGS",
    "UNIT_NAME_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_OTHER_PARTY_CHANGED",
    "INCOMING_RESURRECT_CHANGED", "UNIT_IN_RANGE_UPDATE", "UNIT_CONNECTION",
}
local GLOBAL_EVENTS = {
    "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
    "INCOMING_SUMMON_CHANGED", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE",
    "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

function Orbit.GroupFrameFactoryMixin:RegisterUnitEvents(frame, unit)
    for _, event in ipairs(UNIT_EVENTS) do frame:RegisterUnitEvent(event, unit) end
end

function Orbit.GroupFrameFactoryMixin:RegisterGlobalEvents(frame)
    if frame._globalEventsRegistered then return end
    for _, event in ipairs(GLOBAL_EVENTS) do frame:RegisterEvent(event) end
    frame._globalEventsRegistered = true
end

function Orbit.GroupFrameFactoryMixin:UnregisterFrameEvents(frame)
    for _, event in ipairs(UNIT_EVENTS) do frame:UnregisterEvent(event) end
    if frame._globalEventsRegistered then
        for _, event in ipairs(GLOBAL_EVENTS) do frame:UnregisterEvent(event) end
        frame._globalEventsRegistered = nil
    end
end

function Orbit.GroupFrameFactoryMixin:RegisterFrameEvents(frame, unit)
    self:RegisterUnitEvents(frame, unit)
    self:RegisterGlobalEvents(frame)
end

-- [ FRAME CONFIGURATION ]---------------------------------------------------------------------------
function Orbit.GroupFrameFactoryMixin:ConfigureFrame(frame)
    frame:SetClassColour(true)
    if frame.SetReactionColour then frame:SetReactionColour(true) end
    frame.healthTextEnabled = true
    if frame.SetAbsorbsEnabled then frame:SetAbsorbsEnabled(true) end
    if frame.SetHealAbsorbsEnabled then frame:SetHealAbsorbsEnabled(true) end
end
