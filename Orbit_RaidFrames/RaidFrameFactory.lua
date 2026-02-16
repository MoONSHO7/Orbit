---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

Orbit.RaidFrameFactoryMixin = {}

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local POWER_BAR_HEIGHT_RATIO = Orbit.RaidFrameHelpers.LAYOUT.PowerBarRatio
local ICON_SIZE = 12
local CENTER_ICON_SIZE = 18
local SELECTION_BORDER_THICKNESS = 2

-- [ POWER BAR CREATION ]----------------------------------------------------------------------------

function Orbit.RaidFrameFactoryMixin:CreatePowerBar(parent, unit)
    local power = CreateFrame("StatusBar", nil, parent)
    power:SetPoint("BOTTOMLEFT", 0, 0)
    power:SetPoint("BOTTOMRIGHT", 0, 0)
    power:SetHeight(parent:GetHeight() * POWER_BAR_HEIGHT_RATIO)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    power:SetFrameLevel(parent:GetFrameLevel() + Orbit.Constants.Levels.Cooldown)
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
    frame.BorderOverlay:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Highlight)

    frame.StatusOverlay = CreateFrame("Frame", nil, frame)
    frame.StatusOverlay:SetAllPoints()
    frame.StatusOverlay:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Text)

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

    frame.SelectionHighlight = frame.BorderOverlay:CreateTexture(nil, "ARTWORK")
    frame.SelectionHighlight:SetAllPoints()
    frame.SelectionHighlight:SetColorTexture(1, 1, 1, 0)
    frame.SelectionHighlight:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Highlight)
    frame.SelectionHighlight:Hide()

    local thickness = OrbitEngine.Pixel:Multiple(SELECTION_BORDER_THICKNESS, frame:GetEffectiveScale() or 1)
    frame.SelectionBorders = {}
    for _, edge in pairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local border = frame.BorderOverlay:CreateTexture(nil, "ARTWORK")
        border:SetColorTexture(1, 1, 1, 0.8)
        border:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Highlight)
        if edge == "TOP" then
            border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            border:SetHeight(thickness)
        elseif edge == "BOTTOM" then
            border:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            border:SetHeight(thickness)
        elseif edge == "LEFT" then
            border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            border:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            border:SetWidth(thickness)
        else
            border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            border:SetWidth(thickness)
        end
        border:Hide()
        frame.SelectionBorders[edge] = border
    end

    frame.SelectionHighlight.Show = function() for _, b in pairs(frame.SelectionBorders) do b:Show() end end
    frame.SelectionHighlight.Hide = function() for _, b in pairs(frame.SelectionBorders) do b:Hide() end end

    frame.AggroHighlight = frame.BorderOverlay:CreateTexture(nil, "ARTWORK")
    frame.AggroHighlight:SetAllPoints()
    frame.AggroHighlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Highlight")
    frame.AggroHighlight:SetBlendMode("ADD")
    frame.AggroHighlight:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Highlight)
    frame.AggroHighlight:Hide()

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

    for _, iconKey in ipairs({ "DefensiveIcon", "ImportantIcon", "CrowdControlIcon" }) do
        local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        btn:SetSize(CENTER_ICON_SIZE, CENTER_ICON_SIZE)
        btn.orbitOriginalWidth, btn.orbitOriginalHeight = CENTER_ICON_SIZE, CENTER_ICON_SIZE
        btn:SetPoint("CENTER", frame, "CENTER", 0, 0)
        btn:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Text)
        btn.Icon = btn:CreateTexture(nil, "ARTWORK")
        btn.Icon:SetAllPoints()
        btn.icon = btn.Icon
        btn:Hide()
        frame[iconKey] = btn
    end
end

-- [ EVENT REGISTRATION ]----------------------------------------------------------------------------

function Orbit.RaidFrameFactoryMixin:RegisterFrameEvents(frame, unit)
    local unitEvents = {
        "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_FREQUENT",
        "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PHASE", "UNIT_FLAGS",
        "INCOMING_RESURRECT_CHANGED", "UNIT_IN_RANGE_UPDATE",
    }
    for _, event in ipairs(unitEvents) do frame:RegisterUnitEvent(event, unit) end
    local globalEvents = {
        "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
        "INCOMING_SUMMON_CHANGED", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE",
        "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    }
    for _, event in ipairs(globalEvents) do frame:RegisterEvent(event) end
end

-- [ FRAME CONFIGURATION ]---------------------------------------------------------------------------

function Orbit.RaidFrameFactoryMixin:ConfigureFrame(frame)
    frame:SetClassColour(true)
    if frame.SetReactionColour then frame:SetReactionColour(true) end
    frame.healthTextEnabled = true
    if frame.SetAbsorbsEnabled then frame:SetAbsorbsEnabled(true) end
    if frame.SetHealAbsorbsEnabled then frame:SetHealAbsorbsEnabled(true) end
end
