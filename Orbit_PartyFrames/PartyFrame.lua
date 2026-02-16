---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local Helpers = nil

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_PARTY_FRAMES = 5
local POWER_BAR_HEIGHT_RATIO = Orbit.PartyFrameHelpers.LAYOUT.PowerBarRatio
local DEFENSIVE_ICON_SIZE = 24
local IMPORTANT_ICON_SIZE = 24
local CROWD_CONTROL_ICON_SIZE = 24
local AURA_BASE_ICON_SIZE = Orbit.PartyFrameHelpers.LAYOUT.AuraBaseIconSize
local AURA_SPACING = 2
local MIN_ICON_SIZE = 10
local OUT_OF_RANGE_ALPHA = 0.2

local ROLE_PRIORITY = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PartyFrames"

local Plugin = Orbit:RegisterPlugin("Party Frames", SYSTEM_ID, {
    defaults = {
        Width = 160,
        Height = 40,
        Scale = 100,
        ClassColour = true,
        ShowPowerBar = true,
        Orientation = 0,
        Spacing = 3,
        HealthTextMode = "percent_short",
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT", posX = -75, posY = 0 },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT", posX = 75, posY = 0 },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2, justifyH = "CENTER", posX = 0, posY = 18 },
            RoleIcon = { anchorX = "RIGHT", offsetX = 10, anchorY = "TOP", offsetY = 3, justifyH = "RIGHT" },
            LeaderIcon = { anchorX = "LEFT", offsetX = 10, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", posX = -70, posY = 20 },
            SummonIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            PhaseIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            ResIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            ReadyCheckIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            DefensiveIcon = { anchorX = "LEFT", offsetX = 2, anchorY = "CENTER", offsetY = 0 },
            ImportantIcon = { anchorX = "RIGHT", offsetX = 2, anchorY = "CENTER", offsetY = 0 },
            CrowdControlIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2 },
            Buffs = {
                anchorX = "LEFT",
                anchorY = "CENTER",
                offsetX = -2,
                offsetY = 0,
                posX = -110,
                posY = 0,
                overrides = { MaxIcons = 3, IconSize = 18, MaxRows = 1 },
            },
            Debuffs = {
                anchorX = "RIGHT",
                anchorY = "CENTER",
                offsetX = -2,
                offsetY = 0,
                posX = 110,
                posY = 0,
                overrides = { MaxIcons = 3, IconSize = 18, MaxRows = 1 },
            },
        },
        DisabledComponents = { "DefensiveIcon", "ImportantIcon", "CrowdControlIcon", "RoleIcon" },
        DisabledComponentsMigrated = true,
        IncludePlayer = true,
        GrowthDirection = "Down",
        DispelIndicatorEnabled = true,
        DispelThickness = 2,
        DispelFrequency = 0.25,
        DispelNumLines = 8,
        DispelColorMagic = { r = 0.2, g = 0.6, b = 1.0, a = 1 },
        DispelColorCurse = { r = 0.6, g = 0.0, b = 1.0, a = 1 },
        DispelColorDisease = { r = 0.6, g = 0.4, b = 0.0, a = 1 },
        DispelColorPoison = { r = 0.0, g = 0.6, b = 0.0, a = 1 },
        AggroIndicatorEnabled = true,
        AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        AggroThickness = 1,
        AggroFrequency = 0.25,
        AggroNumLines = 8,
    },
})

-- Apply Mixins (Status, Dispel, Aggro, Factory) - StatusIconMixin provides shared status icon updates
Mixin(
    Plugin,
    Orbit.UnitFrameMixin,
    Orbit.PartyFramePreviewMixin,
    Orbit.AuraMixin,
    Orbit.PartyFrameDispelMixin,
    Orbit.AggroIndicatorMixin,
    Orbit.StatusIconMixin,
    Orbit.PartyFrameFactoryMixin
)

-- Enable Canvas Mode (right-click component editing)
Plugin.canvasMode = true

-- Migrate from legacy ShowXXX boolean settings to DisabledComponents array
local function MigrateDisabledComponents(plugin)
    local migrated = plugin:GetSetting(1, "DisabledComponentsMigrated")
    if migrated then
        return
    end

    local disabled = {}

    -- Mapping from old ShowXXX settings to component keys
    local mappings = {
        ShowRoleIcon = "RoleIcon",
        ShowLeaderIcon = "LeaderIcon",
        ShowPhaseIcon = "PhaseIcon",
        ShowReadyCheck = "ReadyCheckIcon",
        ShowIncomingRes = "ResIcon",
        ShowIncomingSummon = "SummonIcon",
        ShowMarkerIcon = "MarkerIcon",
        ShowSelectionHighlight = "SelectionHighlight",
        ShowAggroHighlight = "AggroHighlight",
    }

    for oldKey, newKey in pairs(mappings) do
        local oldValue = plugin:GetSetting(1, oldKey)
        -- Only migrate if explicitly set to false (nil means default/enabled)
        if oldValue == false then
            table.insert(disabled, newKey)
        end
    end

    plugin:SetSetting(1, "DisabledComponents", disabled)
    plugin:SetSetting(1, "DisabledComponentsMigrated", true)
end

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function SafeRegisterUnitWatch(frame)
    if not frame then
        return
    end
    Orbit:SafeAction(function() RegisterUnitWatch(frame) end)
end

local function SafeUnregisterUnitWatch(frame)
    if not frame then
        return
    end
    Orbit:SafeAction(function() UnregisterUnitWatch(frame) end)
end

local function GetPowerColor(powerType) return Orbit.Constants.Colors:GetPowerColor(powerType) end

-- [ ROLE SORTING ]---------------------------------------------------------------------------------

local function GetRolePriority(unit)
    if not UnitExists(unit) then
        return 99
    end
    return ROLE_PRIORITY[UnitGroupRolesAssigned(unit)] or 4
end

-- Returns a sorted list of units, always sorted by role (Tank > Healer > DPS)
-- If includePlayer is true, includes "player" in the list
local function GetSortedPartyUnits(includePlayer)
    local units = {}
    if includePlayer then
        table.insert(units, "player")
    end
    for i = 1, 4 do
        if UnitExists("party" .. i) then
            table.insert(units, "party" .. i)
        end
    end

    if #units > 1 then
        table.sort(units, function(a, b)
            local priorityA = GetRolePriority(a)
            local priorityB = GetRolePriority(b)
            if priorityA == priorityB then
                -- Secondary sort: alphabetical by name for consistency
                local nameA = UnitName(a) or ""
                local nameB = UnitName(b) or ""
                -- Handle secret values
                if issecretvalue and (issecretvalue(nameA) or issecretvalue(nameB)) then
                    return false -- Maintain original order if names are secret
                end
                return nameA < nameB
            end
            return priorityA < priorityB
        end)
    end

    return units
end

-- [ POWER BAR CREATION & UPDATE ]-------------------------------------------------------------------

local function CreatePowerBar(parent, unit, plugin)
    local power = CreateFrame("StatusBar", nil, parent)
    power:SetPoint("BOTTOMLEFT", 0, 0)
    power:SetPoint("BOTTOMRIGHT", 0, 0)
    power:SetHeight(parent:GetHeight() * POWER_BAR_HEIGHT_RATIO)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")

    power:SetMinMaxValues(0, 1)
    power:SetValue(0)
    power.unit = unit

    -- Background (gradient-aware)
    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(power, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)

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
    local isHealer = UnitGroupRolesAssigned(unit) == "HEALER"
    if showPower == false and not isHealer then
        frame.Power:Hide()
        return
    end
    frame.Power:Show()

    local power, maxPower, powerType = UnitPower(unit), UnitPowerMax(unit), UnitPowerType(unit)
    frame.Power:SetMinMaxValues(0, maxPower)
    frame.Power:SetValue(power)
    local color = GetPowerColor(powerType)
    frame.Power:SetStatusBarColor(color.r, color.g, color.b)
end

local function UpdateFrameLayout(frame, borderSize, plugin)
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end
    local showPowerBar = plugin and plugin:GetSetting(1, "ShowPowerBar")
    if showPowerBar == nil then
        showPowerBar = true
    end
    if not showPowerBar and frame.unit and UnitGroupRolesAssigned(frame.unit) == "HEALER" then
        showPowerBar = true
    end
    Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar)
end

-- [ AURA LAYOUT HELPERS ]---------------------------------------------------------------------------

local function CalculateSmartAuraLayout(frameWidth, frameHeight, position, maxIcons, numIcons, overrides)
    local iconSize, rows, iconsPerRow, containerWidth, containerHeight
    local isHorizontal = (position == "Above" or position == "Below")
    local maxRows = (overrides and overrides.MaxRows) or 2

    iconSize = (overrides and overrides.IconSize) or AURA_BASE_ICON_SIZE
    iconSize = math.max(MIN_ICON_SIZE, iconSize)

    if isHorizontal then
        iconsPerRow = math.max(1, math.floor((frameWidth + AURA_SPACING) / (iconSize + AURA_SPACING)))
        rows = math.min(maxRows, math.ceil(numIcons / iconsPerRow))
        local displayCount = math.min(numIcons, iconsPerRow * rows)
        local displayCols = math.min(displayCount, iconsPerRow)
        containerWidth = (displayCols * iconSize) + ((displayCols - 1) * AURA_SPACING)
        containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
    else
        rows = math.min(maxRows, math.max(1, numIcons))
        iconsPerRow = math.ceil(numIcons / rows)
        containerWidth = math.max(iconSize, (iconsPerRow * iconSize) + ((iconsPerRow - 1) * AURA_SPACING))
        containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
    end

    return iconSize, rows, iconsPerRow, containerWidth, containerHeight
end

local function PositionAuraIcon(icon, container, justifyH, anchorY, col, row, iconSize, iconsPerRow)
    local xOffset = col * (iconSize + AURA_SPACING)
    local yOffset = row * (iconSize + AURA_SPACING)
    icon:ClearAllPoints()
    local growDown = (anchorY ~= "BOTTOM")

    if justifyH == "RIGHT" then
        if growDown then icon:SetPoint("TOPRIGHT", container, "TOPRIGHT", -xOffset, -yOffset)
        else icon:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -xOffset, yOffset) end
    else
        if growDown then icon:SetPoint("TOPLEFT", container, "TOPLEFT", xOffset, -yOffset)
        else icon:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOffset, yOffset) end
    end

    local nextCol = col + 1
    local nextRow = row
    if nextCol >= iconsPerRow then nextCol = 0; nextRow = row + 1 end
    return nextCol, nextRow
end

-- [ AURA POST-FILTER HELPER ]-----------------------------------------------------------------------
-- Returns true if the aura passes the given filter (is NOT filtered out)
local function IsAuraIncluded(unit, auraInstanceID, filter) return not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, filter) end

-- Use shared helper from PartyFrameHelpers
local Helpers = Orbit.PartyFrameHelpers

-- [ DEBUFF DISPLAY ]--------------------------------------------------------------------------------

local function UpdateDebuffs(frame, plugin)
    if not frame.debuffContainer then
        return
    end

    -- Check if debuffs are disabled via canvas mode dock
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("Debuffs") then
        frame.debuffContainer:Hide()
        return
    end

    -- Read position and overrides from ComponentPositions (set via Canvas Mode)
    local componentPositions = plugin:GetSetting(1, "ComponentPositions") or {}
    local debuffData = componentPositions.Debuffs or {}
    local debuffOverrides = debuffData.overrides or {}
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()
    local maxDebuffs = debuffOverrides.MaxIcons or 3

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.debuffContainer:Hide()
        return
    end

    -- Initialize pool if needed
    if not frame.debuffPool then
        frame.debuffPool = CreateFramePool("Button", frame.debuffContainer, "BackdropTemplate")
    end
    frame.debuffPool:ReleaseAll()

    -- Fetch harmful auras with post-filtering
    local allDebuffs = plugin:FetchAuras(unit, "HARMFUL", 40)

    -- Post-filter: exclude crowd control if CrowdControlIcon is enabled (handled separately)
    local excludeCC = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("CrowdControlIcon"))
    local debuffs = {}
    for _, aura in ipairs(allDebuffs) do
        local dominated = excludeCC and aura.auraInstanceID and IsAuraIncluded(unit, aura.auraInstanceID, "HARMFUL|CROWD_CONTROL")
        if not dominated then
            table.insert(debuffs, aura)
            if #debuffs >= maxDebuffs then
                break
            end
        end
    end

    if #debuffs == 0 then
        frame.debuffContainer:Hide()
        return
    end

    -- Calculate smart layout (position string needed for icon growth direction)
    local position = Helpers:AnchorToPosition(debuffData.posX, debuffData.posY, frameWidth / 2, frameHeight / 2)
    local iconSize, rows, iconsPerRow, containerWidth, containerHeight =
        CalculateSmartAuraLayout(frameWidth, frameHeight, position, maxDebuffs, #debuffs, debuffOverrides)

    -- Position container using saved anchor data (same system as all other components)
    frame.debuffContainer:ClearAllPoints()
    frame.debuffContainer:SetSize(containerWidth, containerHeight)

    local anchorX = debuffData.anchorX or "RIGHT"
    local anchorY = debuffData.anchorY or "CENTER"
    local offsetX = debuffData.offsetX or 0
    local offsetY = debuffData.offsetY or 0
    local justifyH = debuffData.justifyH or "LEFT"

    -- Frame-side anchor (where on the frame to attach)
    local anchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)

    -- Container self-anchor: justifyH edge + anchorY (matches edge-relative offsets from drag system)
    local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(false, true, anchorY, justifyH)

    local finalX = offsetX
    local finalY = offsetY
    if anchorX == "RIGHT" then
        finalX = -offsetX
    end
    if anchorY == "TOP" then
        finalY = -offsetY
    end

    frame.debuffContainer:SetPoint(selfAnchor, frame, anchorPoint, finalX, finalY)

    -- Skin settings
    local globalBorder = Orbit.db.GlobalSettings.BorderSize
    local skinSettings = {
        zoom = 0,
        borderStyle = 1,
        borderSize = globalBorder,
        showTimer = true,
    }

    -- Layout icons with smart positioning
    local col, row = 0, 0
    for i, aura in ipairs(debuffs) do
        local icon = frame.debuffPool:Acquire()
        plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
        plugin:SetupAuraTooltip(icon, aura, unit, "HARMFUL")

        col, row = PositionAuraIcon(icon, frame.debuffContainer, justifyH, anchorY, col, row, iconSize, iconsPerRow)
    end

    frame.debuffContainer:Show()
end

-- [ BUFF DISPLAY ]----------------------------------------------------------------------------------
-- Shows only buffs cast by the player (HELPFUL|PLAYER filter)

local function UpdateBuffs(frame, plugin)
    if not frame.buffContainer then
        return
    end

    -- Check if buffs are disabled via canvas mode dock
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("Buffs") then
        frame.buffContainer:Hide()
        return
    end

    -- Read position and overrides from ComponentPositions (set via Canvas Mode)
    local componentPositions = plugin:GetSetting(1, "ComponentPositions") or {}
    local buffData = componentPositions.Buffs or {}
    local buffOverrides = buffData.overrides or {}
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()
    local maxBuffs = buffOverrides.MaxIcons or 3

    local unit = frame.unit
    if not UnitExists(unit) then
        frame.buffContainer:Hide()
        return
    end

    -- Initialize pool if needed
    if not frame.buffPool then
        frame.buffPool = CreateFramePool("Button", frame.buffContainer, "BackdropTemplate")
    end
    frame.buffPool:ReleaseAll()

    -- Fetch player buffs with combat-aware post-filtering
    local allBuffs = plugin:FetchAuras(unit, "HELPFUL|PLAYER", 40)

    -- Post-filter: combat-aware raid relevance + conditionally exclude defensives
    local inCombat = UnitAffectingCombat("player")
    local raidFilter = inCombat and "HELPFUL|PLAYER|RAID_IN_COMBAT" or "HELPFUL|PLAYER|RAID"
    local excludeDefensives = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("DefensiveIcon"))
    local buffs = {}
    for _, aura in ipairs(allBuffs) do
        if aura.auraInstanceID then
            local passesRaid = IsAuraIncluded(unit, aura.auraInstanceID, raidFilter)
            local isBigDef = excludeDefensives and IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|BIG_DEFENSIVE")
            local isExtDef = excludeDefensives and IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
            if passesRaid and not isBigDef and not isExtDef then
                table.insert(buffs, aura)
                if #buffs >= maxBuffs then
                    break
                end
            end
        end
    end

    if #buffs == 0 then
        frame.buffContainer:Hide()
        return
    end

    -- Calculate smart layout (position string needed for icon growth direction)
    local position = Helpers:AnchorToPosition(buffData.posX, buffData.posY, frameWidth / 2, frameHeight / 2)
    local iconSize, rows, iconsPerRow, containerWidth, containerHeight =
        CalculateSmartAuraLayout(frameWidth, frameHeight, position, maxBuffs, #buffs, buffOverrides)

    -- Position container using saved anchor data (same system as all other components)
    frame.buffContainer:ClearAllPoints()
    frame.buffContainer:SetSize(containerWidth, containerHeight)

    local anchorX = buffData.anchorX or "LEFT"
    local anchorY = buffData.anchorY or "CENTER"
    local offsetX = buffData.offsetX or 0
    local offsetY = buffData.offsetY or 0
    local justifyH = buffData.justifyH or "RIGHT"

    -- Frame-side anchor
    local anchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)

    -- Container self-anchor: justifyH edge + anchorY (matches edge-relative offsets from drag system)
    local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(false, true, anchorY, justifyH)

    local finalX = offsetX
    local finalY = offsetY
    if anchorX == "RIGHT" then
        finalX = -offsetX
    end
    if anchorY == "TOP" then
        finalY = -offsetY
    end

    frame.buffContainer:SetPoint(selfAnchor, frame, anchorPoint, finalX, finalY)

    -- Skin settings
    local globalBorder = Orbit.db.GlobalSettings.BorderSize
    local skinSettings = {
        zoom = 0,
        borderStyle = 1,
        borderSize = globalBorder,
        showTimer = true,
    }

    -- Layout icons with smart positioning
    local col, row = 0, 0
    for i, aura in ipairs(buffs) do
        local icon = frame.buffPool:Acquire()
        plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
        plugin:SetupAuraTooltip(icon, aura, unit, "HELPFUL")

        col, row = PositionAuraIcon(icon, frame.buffContainer, justifyH, anchorY, col, row, iconSize, iconsPerRow)
    end

    frame.buffContainer:Show()
end

-- [ SINGLE AURA ICON HELPER ]----------------------------------------------------------------------

local function UpdateSingleAuraIcon(frame, plugin, iconKey, filter, iconSize)
    local icon = frame[iconKey]
    if not icon then
        return
    end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled(iconKey) then
        icon:Hide()
        return
    end

    local unit = frame.unit
    if not UnitExists(unit) then
        icon:Hide()
        return
    end

    local auras = plugin:FetchAuras(unit, filter, 1)
    if #auras == 0 then
        icon:Hide()
        return
    end

    local aura = auras[1]
    local globalBorder = Orbit.db.GlobalSettings.BorderSize
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false }
    plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
    local tooltipFilter = filter:find("HARMFUL") and "HARMFUL" or "HELPFUL"
    plugin:SetupAuraTooltip(icon, aura, unit, tooltipFilter)
    icon:Show()
end

-- [ DEFENSIVE ICON DISPLAY ]------------------------------------------------------------------------

local function UpdateDefensiveIcon(frame, plugin)
    UpdateSingleAuraIcon(frame, plugin, "DefensiveIcon", "HELPFUL|BIG_DEFENSIVE", DEFENSIVE_ICON_SIZE)
    if frame.DefensiveIcon and not frame.DefensiveIcon:IsShown() then
        UpdateSingleAuraIcon(frame, plugin, "DefensiveIcon", "HELPFUL|EXTERNAL_DEFENSIVE", DEFENSIVE_ICON_SIZE)
    end
end

-- [ IMPORTANT ICON DISPLAY ]------------------------------------------------------------------------

local function UpdateImportantIcon(frame, plugin) UpdateSingleAuraIcon(frame, plugin, "ImportantIcon", "HARMFUL|IMPORTANT", IMPORTANT_ICON_SIZE) end

-- [ CROWD CONTROL ICON DISPLAY ]--------------------------------------------------------------------

local function UpdateCrowdControlIcon(frame, plugin) UpdateSingleAuraIcon(frame, plugin, "CrowdControlIcon", "HARMFUL|CROWD_CONTROL", CROWD_CONTROL_ICON_SIZE) end

-- [ STATUS INDICATOR UPDATES ]---------------------------------------------------------------------
local function UpdateRoleIcon(frame, plugin)
    if plugin.UpdateRoleIcon then
        plugin:UpdateRoleIcon(frame, plugin)
    end
end

local function UpdateLeaderIcon(frame, plugin)
    if plugin.UpdateLeaderIcon then
        plugin:UpdateLeaderIcon(frame, plugin)
    end
end

local function UpdateSelectionHighlight(frame, plugin)
    if plugin.UpdateSelectionHighlight then
        plugin:UpdateSelectionHighlight(frame, plugin)
    end
end

local function UpdateAggroHighlight(frame, plugin)
    if plugin.UpdateAggroHighlight then
        plugin:UpdateAggroHighlight(frame, plugin)
    end
end

local function UpdatePhaseIcon(frame, plugin)
    if plugin.UpdatePhaseIcon then
        plugin:UpdatePhaseIcon(frame, plugin)
    end
end

local function UpdateReadyCheck(frame, plugin)
    if plugin.UpdateReadyCheck then
        plugin:UpdateReadyCheck(frame, plugin)
    end
end

local function UpdateIncomingRes(frame, plugin)
    if plugin.UpdateIncomingRes then
        plugin:UpdateIncomingRes(frame, plugin)
    end
end

local function UpdateIncomingSummon(frame, plugin)
    if plugin.UpdateIncomingSummon then
        plugin:UpdateIncomingSummon(frame, plugin)
    end
end

local function UpdateMarkerIcon(frame, plugin)
    if plugin.UpdateMarkerIcon then
        plugin:UpdateMarkerIcon(frame, plugin)
    end
end

local function UpdateAllStatusIndicators(frame, plugin)
    if plugin.UpdateAllPartyStatusIcons then
        plugin:UpdateAllPartyStatusIcons(frame, plugin)
    end
end

-- [ RANGE CHECKING ]--------------------------------------------------------------------------------

local function UpdateInRange(frame)
    if not frame or not frame.unit then
        return
    end
    if frame.isPlayerFrame or frame.preview then
        frame:SetAlpha(1)
        return
    end
    local inRange = UnitInRange(frame.unit)
    frame:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(inRange, 1, OUT_OF_RANGE_ALPHA))
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

    UpdateFrameLayout(frame, Orbit.db.GlobalSettings.BorderSize, plugin)

    -- Create power bar
    frame.Power = CreatePowerBar(frame, unit, plugin)

    -- Create debuff container (renders above/below party frame)
    frame.debuffContainer = CreateFrame("Frame", nil, frame)
    frame.debuffContainer:SetFrameLevel(frame:GetFrameLevel() + 10)

    -- Create buff container (for player-cast buffs)
    frame.buffContainer = CreateFrame("Frame", nil, frame)
    frame.buffContainer:SetFrameLevel(frame:GetFrameLevel() + 10)

    -- Create Status Indicators (delegated to factory mixin)
    plugin:CreateStatusIcons(frame)

    -- Register frame events (delegated to factory mixin)
    plugin:RegisterFrameEvents(frame, unit)

    -- Update Loop
    frame:SetScript("OnShow", function(self)
        -- Guard against nil unit (frames start hidden, unit assigned later)
        if not self.unit then
            return
        end

        self:UpdateAll()
        UpdatePowerBar(self, plugin)
        UpdateFrameLayout(self, Orbit.db.GlobalSettings.BorderSize, plugin)
        UpdateDebuffs(self, plugin)
        UpdateBuffs(self, plugin)
        UpdateDefensiveIcon(self, plugin)
        UpdateImportantIcon(self, plugin)
        UpdateCrowdControlIcon(self, plugin)
        UpdateAllStatusIndicators(self, plugin)
        UpdateInRange(self)
    end)

    -- Extended OnEvent handler
    local originalOnEvent = frame:GetScript("OnEvent")
    frame:SetScript("OnEvent", function(f, event, eventUnit, ...)
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            if eventUnit == f.unit then
                UpdatePowerBar(f, plugin)
            end
            return
        end

        if event == "UNIT_AURA" then
            -- Use f.unit (current assigned unit) not closure 'unit' which may be stale
            if eventUnit == f.unit then
                UpdateDebuffs(f, plugin)
                UpdateBuffs(f, plugin)
                UpdateDefensiveIcon(f, plugin)
                UpdateImportantIcon(f, plugin)
                UpdateCrowdControlIcon(f, plugin)
                -- Update dispel indicator
                if plugin.UpdateDispelIndicator then
                    plugin:UpdateDispelIndicator(f, plugin)
                end
            end
            return
        end

        -- Combat state change: force refresh buffs for combat-aware filtering
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            UpdateBuffs(f, plugin)
            return
        end

        -- Target changed - update selection highlight for ALL frames
        if event == "PLAYER_TARGET_CHANGED" then
            UpdateSelectionHighlight(f, plugin)
            return
        end

        -- Threat updates
        if event == "UNIT_THREAT_SITUATION_UPDATE" then
            if eventUnit == f.unit then
                -- Update aggro indicator
                if plugin.UpdateAggroIndicator then
                    plugin:UpdateAggroIndicator(f, plugin)
                end
            end
            return
        end

        -- Phase updates
        if event == "UNIT_PHASE" or event == "UNIT_FLAGS" then
            if eventUnit == f.unit then
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
            if eventUnit == f.unit then
                UpdateIncomingRes(f, plugin)
            end
            return
        end

        -- Summon updates
        if event == "INCOMING_SUMMON_CHANGED" then
            UpdateIncomingSummon(f, plugin)
            return
        end

        if event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" then
            UpdateRoleIcon(f, plugin)
            UpdateLeaderIcon(f, plugin)
            return
        end

        if event == "RAID_TARGET_UPDATE" then
            UpdateMarkerIcon(f, plugin)
            return
        end

        -- Range updates (fade out-of-range party members)
        if event == "UNIT_IN_RANGE_UPDATE" then
            if eventUnit == f.unit then
                UpdateInRange(f)
            end
            return
        end

        if originalOnEvent then
            originalOnEvent(f, event, eventUnit, ...)
        end
    end)

    -- Configure frame features (delegated to factory mixin)
    plugin:ConfigureFrame(frame)

    return frame
end

local function HideNativePartyFrames()
    for i = 1, 4 do
        local partyFrame = _G["PartyMemberFrame" .. i]
        if partyFrame then
            partyFrame:ClearAllPoints()
            partyFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
            partyFrame:SetAlpha(0)
            partyFrame:SetScale(0.001)
            partyFrame:EnableMouse(false)
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
    if PartyFrame then
        OrbitEngine.NativeFrame:Hide(PartyFrame)
    end
    if CompactPartyFrame then
        OrbitEngine.NativeFrame:Hide(CompactPartyFrame)
    end
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------

-- Helper to reduce repetitive onChange handlers
local function makeOnChange(plugin, key, preApply)
    return function(val)
        plugin:SetSetting(1, key, val)
        if preApply then
            preApply(val)
        end
        plugin:ApplySettings()
        if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then
            plugin:SchedulePreviewUpdate()
        end
    end
end

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = 1
    local WL = OrbitEngine.WidgetLogic
    local orientation = self:GetSetting(1, "Orientation") or 0

    local schema = { hideNativeSettings = true, controls = {} }

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Auras", "Indicators" }, "Layout")

    if currentTab == "Layout" then
        table.insert(schema.controls, {
            type = "dropdown",
            key = "Orientation",
            label = "Orientation",
            default = 0,
            options = { { text = "Vertical", value = 0 }, { text = "Horizontal", value = 1 } },
            onChange = function(val)
                self:SetSetting(1, "Orientation", val)
                local defaultGrowth = val == 0 and "Down" or "Right"
                self:SetSetting(1, "GrowthDirection", defaultGrowth)
                self:ApplySettings()
                if self.frames and self.frames[1] and self.frames[1].preview then
                    self:SchedulePreviewUpdate()
                end
                if dialog.orbitTabCallback then
                    dialog.orbitTabCallback()
                end
            end,
        })
        local growthOptions = orientation == 0 and { { text = "Down", value = "Down" }, { text = "Up", value = "Up" } }
            or { { text = "Right", value = "Right" }, { text = "Left", value = "Left" } }
        table.insert(schema.controls, {
            type = "dropdown",
            key = "GrowthDirection",
            label = "Growth Direction",
            default = orientation == 0 and "Down" or "Right",
            options = growthOptions,
            onChange = makeOnChange(self, "GrowthDirection"),
        })
        table.insert(
            schema.controls,
            { type = "slider", key = "Width", label = "Width", min = 50, max = 300, step = 5, default = 160, onChange = makeOnChange(self, "Width") }
        )
        table.insert(
            schema.controls,
            { type = "slider", key = "Height", label = "Height", min = 20, max = 100, step = 5, default = 40, onChange = makeOnChange(self, "Height") }
        )
        table.insert(
            schema.controls,
            { type = "slider", key = "Spacing", label = "Spacing", min = 0, max = 25, step = 1, default = 0, onChange = makeOnChange(self, "Spacing") }
        )
        table.insert(schema.controls, {
            type = "dropdown",
            key = "HealthTextMode",
            label = "Health Text",
            default = "percent_short",
            options = {
                { text = "Percentage", value = "percent" },
                { text = "Short Health", value = "short" },
                { text = "Raw Health", value = "raw" },
                { text = "Short - Percentage", value = "short_and_percent" },
                { text = "Percentage / Short", value = "percent_short" },
                { text = "Percentage / Raw", value = "percent_raw" },
                { text = "Short / Percentage", value = "short_percent" },
                { text = "Short / Raw", value = "short_raw" },
                { text = "Raw / Short", value = "raw_short" },
                { text = "Raw / Percentage", value = "raw_percent" },
            },
            onChange = makeOnChange(self, "HealthTextMode"),
        })
        table.insert(schema.controls, {
            type = "checkbox",
            key = "IncludePlayer",
            label = "Include Player",
            default = false,
            onChange = makeOnChange(self, "IncludePlayer", function(val)
                if self.frames and self.frames[1] and self.frames[1].preview then
                    self:ShowPreview()
                else
                    self:UpdateFrameUnits()
                end
            end),
        })
        table.insert(
            schema.controls,
            { type = "checkbox", key = "ShowPowerBar", label = "Show Power Bar", default = true, onChange = makeOnChange(self, "ShowPowerBar") }
        )
    elseif currentTab == "Indicators" then
        table.insert(schema.controls, {
            type = "checkbox",
            key = "DispelIndicatorEnabled",
            label = "Enable Dispel Indicators",
            default = true,
            onChange = makeOnChange(self, "DispelIndicatorEnabled", function()
                if self.UpdateAllDispelIndicators then
                    self:UpdateAllDispelIndicators(self)
                end
            end),
        })
        table.insert(schema.controls, {
            type = "slider",
            key = "DispelThickness",
            label = "Dispel Border Thickness",
            default = 2,
            min = 1,
            max = 5,
            step = 1,
            onChange = makeOnChange(self, "DispelThickness", function()
                if self.UpdateAllDispelIndicators then
                    self:UpdateAllDispelIndicators(self)
                end
            end),
        })
        table.insert(schema.controls, {
            type = "slider",
            key = "DispelFrequency",
            label = "Dispel Animation Speed",
            default = 0.25,
            min = 0.1,
            max = 1.0,
            step = 0.05,
            onChange = makeOnChange(self, "DispelFrequency", function()
                if self.UpdateAllDispelIndicators then
                    self:UpdateAllDispelIndicators(self)
                end
            end),
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------

function Plugin:OnLoad()
    -- Migrate legacy ShowXXX settings to DisabledComponents array
    MigrateDisabledComponents(self)

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

        -- NOTE: Don't register unit watch here - UpdateFrameUnits handles visibility
        -- based on IncludePlayer and SortByRole settings
        self.frames[i]:Hide() -- Start hidden, UpdateFrameUnits will show valid frames
    end

    -- Register components for Canvas Mode drag (on CONTAINER, using first frame's elements)
    -- Canvas Mode opens on the container, so components must be registered there
    local pluginRef = self
    local firstFrame = self.frames[1]
    if OrbitEngine.ComponentDrag and firstFrame then
        -- Components that support justifyH (text elements)
        local textComponents = { "Name", "HealthText" }
        -- Components that don't support justifyH (icons)
        local iconComponents = {
            "RoleIcon",
            "LeaderIcon",
            "PhaseIcon",
            "ReadyCheckIcon",
            "ResIcon",
            "SummonIcon",
            "MarkerIcon",
            "DefensiveIcon",
            "ImportantIcon",
            "CrowdControlIcon",
        }

        -- Register text components with justifyH support
        for _, key in ipairs(textComponents) do
            local element = firstFrame[key]
            if element then
                OrbitEngine.ComponentDrag:Attach(element, self.container, {
                    key = key,
                    onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY, justifyH)
                        local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                        positions[key] = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                        pluginRef:SetSetting(1, "ComponentPositions", positions)
                    end,
                })
            end
        end

        -- Register icon components without justifyH
        for _, key in ipairs(iconComponents) do
            local element = firstFrame[key]
            if element then
                OrbitEngine.ComponentDrag:Attach(element, self.container, {
                    key = key,
                    onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY)
                        local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                        positions[key] = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY }
                        pluginRef:SetSetting(1, "ComponentPositions", positions)
                    end,
                })
            end
        end

        -- Register aura containers (Buffs/Debuffs) as canvas mode components
        local auraContainerComponents = { "Buffs", "Debuffs" }
        for _, key in ipairs(auraContainerComponents) do
            local containerKey = key == "Buffs" and "buffContainer" or "debuffContainer"
            -- Ensure container exists on first frame for registration
            if not firstFrame[containerKey] then
                firstFrame[containerKey] = CreateFrame("Frame", nil, firstFrame)
                firstFrame[containerKey]:SetSize(AURA_BASE_ICON_SIZE, AURA_BASE_ICON_SIZE)
            end
            OrbitEngine.ComponentDrag:Attach(firstFrame[containerKey], self.container, {
                key = key,
                isAuraContainer = true,
                onPositionChange = function(comp, anchorX, anchorY, offsetX, offsetY, justifyH)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    if not positions[key] then
                        positions[key] = {}
                    end
                    positions[key].anchorX = anchorX
                    positions[key].anchorY = anchorY
                    positions[key].offsetX = offsetX
                    positions[key].offsetY = offsetY
                    positions[key].justifyH = justifyH
                    local compParent = comp:GetParent()
                    if compParent then
                        local cx, cy = comp:GetCenter()
                        local px, py = compParent:GetCenter()
                        if cx and px then positions[key].posX = cx - px end
                        if cy and py then positions[key].posY = cy - py end
                    end
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end,
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

    -- Set default container position (anchor matches growth direction)
    if not self.container:GetPoint() then
        if not Helpers then
            Helpers = Orbit.PartyFrameHelpers
        end
        local growDir = self:GetSetting(1, "GrowthDirection") or "Down"
        local anchor = Helpers:GetContainerAnchor(growDir)
        self.container:SetPoint(anchor, UIParent, "TOPLEFT", 20, -200)
    end

    -- Helper to update visibility driver based on IncludePlayer setting
    local function UpdateVisibilityDriver(plugin)
        if InCombatLockdown() then
            return
        end

        -- Always require party to exist - IncludePlayer just adds player to the frames
        -- Both settings use the same visibility: show only when in party (not raid)
        local visibilityDriver = "[petbattle] hide; [@raid1,exists] hide; [@party1,exists] show; hide"

        RegisterStateDriver(plugin.container, "visibility", visibilityDriver)
    end
    self.UpdateVisibilityDriver = function() UpdateVisibilityDriver(self) end

    -- Register secure visibility driver
    UpdateVisibilityDriver(self)

    -- Explicit Show Bridge: Ensure container is active to receive first state evaluation
    self.container:Show()

    -- Give container a minimum size so it's clickable in Edit Mode
    self.container:SetSize(self:GetSetting(1, "Width") or 160, 100)

    -- Position frames
    self:PositionFrames()

    -- Apply initial settings
    self:ApplySettings()

    -- Initial unit assignment (sorting and player inclusion)
    self:UpdateFrameUnits()

    -- Register for group events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
            -- Re-sort and reassign units when group or roles change
            if not InCombatLockdown() then
                self:UpdateFrameUnits()
            end

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
    if not frame then
        return
    end

    local previewAtlases = Orbit.IconPreviewAtlases

    -- Set placeholder atlases on icons so Canvas Mode can clone them
    if frame.PhaseIcon then
        frame.PhaseIcon:SetAtlas(previewAtlases.PhaseIcon)
        frame.PhaseIcon:SetSize(24, 24)
    end
    if frame.ReadyCheckIcon then
        frame.ReadyCheckIcon:SetAtlas(previewAtlases.ReadyCheckIcon)
        frame.ReadyCheckIcon:SetSize(24, 24)
    end
    if frame.ResIcon then
        frame.ResIcon:SetAtlas(previewAtlases.ResIcon)
        frame.ResIcon:SetSize(24, 24)
    end
    if frame.SummonIcon then
        frame.SummonIcon:SetAtlas(previewAtlases.SummonIcon)
        frame.SummonIcon:SetSize(24, 24)
    end
    -- RoleIcon and LeaderIcon already have atlases set in preview, but ensure they're sized
    if frame.RoleIcon then
        if not frame.RoleIcon:GetAtlas() then
            frame.RoleIcon:SetAtlas(previewAtlases.RoleIcon)
        end
        frame.RoleIcon:SetSize(16, 16)
    end
    if frame.LeaderIcon then
        if not frame.LeaderIcon:GetAtlas() then
            frame.LeaderIcon:SetAtlas(previewAtlases.LeaderIcon)
        end
        frame.LeaderIcon:SetSize(16, 16)
    end

    -- MarkerIcon uses sprite sheet, needs specific setup
    if frame.MarkerIcon then
        frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        frame.MarkerIcon.orbitSpriteIndex = 8 -- Skull for preview
        frame.MarkerIcon.orbitSpriteRows = 4
        frame.MarkerIcon.orbitSpriteCols = 4

        -- Apply sprite sheet cell manually for preview
        local i = 8
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local w = 1 / 4
        local h = 1 / 4
        frame.MarkerIcon:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
        frame.MarkerIcon:Show()
    end

    -- DefensiveIcon/ImportantIcon: set .Icon texture for Canvas Mode cloning
    local StatusMixin = Orbit.StatusIconMixin
    if frame.DefensiveIcon then
        frame.DefensiveIcon.Icon:SetTexture(StatusMixin:GetDefensiveTexture())
        frame.DefensiveIcon:SetSize(DEFENSIVE_ICON_SIZE, DEFENSIVE_ICON_SIZE)
        frame.DefensiveIcon:Show()
    end
    if frame.ImportantIcon then
        frame.ImportantIcon.Icon:SetTexture(StatusMixin:GetImportantTexture())
        frame.ImportantIcon:SetSize(IMPORTANT_ICON_SIZE, IMPORTANT_ICON_SIZE)
        frame.ImportantIcon:Show()
    end
    if frame.CrowdControlIcon then
        frame.CrowdControlIcon.Icon:SetTexture(StatusMixin:GetCrowdControlTexture())
        frame.CrowdControlIcon:SetSize(CROWD_CONTROL_ICON_SIZE, CROWD_CONTROL_ICON_SIZE)
        frame.CrowdControlIcon:Show()
    end
end

-- [ FRAME POSITIONING ]-----------------------------------------------------------------------------

function Plugin:PositionFrames()
    if InCombatLockdown() then
        return
    end
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end

    local spacing = self:GetSetting(1, "Spacing") or 0
    local orientation = self:GetSetting(1, "Orientation") or 0
    local width = self:GetSetting(1, "Width") or 160
    local height = self:GetSetting(1, "Height") or 40
    local growthDirection = self:GetSetting(1, "GrowthDirection") or (orientation == 0 and "Down" or "Right")

    -- Re-anchor container to match growth direction (prevents frame shift on party size change)
    local desiredAnchor = Helpers:GetContainerAnchor(growthDirection)
    local currentAnchor = select(1, self.container:GetPoint(1))
    if currentAnchor and currentAnchor ~= desiredAnchor then
        local scale = self.container:GetEffectiveScale()
        local parentScale = UIParent:GetEffectiveScale()
        local left, bottom = self.container:GetLeft(), self.container:GetBottom()
        local top, right = self.container:GetTop(), self.container:GetRight()
        if left and bottom and top and right then
            local ratio = parentScale / scale
            local parentLeft = UIParent:GetLeft() or 0
            local parentBottom = UIParent:GetBottom() or 0
            local parentTop = UIParent:GetTop() or (GetScreenHeight() * parentScale)
            local parentRight = UIParent:GetRight() or (GetScreenWidth() * parentScale)
            local x, y
            if desiredAnchor == "TOPLEFT" then
                x = (left - parentLeft) * ratio
                y = (top - parentTop) * ratio
            elseif desiredAnchor == "BOTTOMLEFT" then
                x = (left - parentLeft) * ratio
                y = (bottom - parentBottom) * ratio
            elseif desiredAnchor == "TOPRIGHT" then
                x = (right - parentRight) * ratio
                y = (top - parentTop) * ratio
            else
                x = (left - parentLeft) * ratio
                y = (top - parentTop) * ratio
            end
            self.container:ClearAllPoints()
            self.container:SetPoint(desiredAnchor, UIParent, desiredAnchor, x, y)
            -- Persist new anchor through position system
            local PM = OrbitEngine.PositionManager
            if PM then
                PM:SetPosition(self.container, desiredAnchor, x, y)
                PM:MarkDirty(self.container)
            end
            self:SetSetting(1, "Position", { point = desiredAnchor, x = x, y = y })
        end
    end

    local visibleIndex = 0
    for _, frame in ipairs(self.frames) do
        frame:ClearAllPoints()
        if frame:IsShown() or frame.preview then
            visibleIndex = visibleIndex + 1
            local xOffset, yOffset, frameAnchor, containerAnchor =
                Helpers:CalculateFramePosition(visibleIndex, width, height, spacing, orientation, growthDirection)
            frame:SetPoint(frameAnchor, self.container, containerAnchor, xOffset, yOffset)
        end
    end

    self:UpdateContainerSize()
end

function Plugin:UpdateContainerSize()
    if InCombatLockdown() then
        return
    end
    if not Helpers then
        Helpers = Orbit.PartyFrameHelpers
    end
    local width = self:GetSetting(1, "Width") or 160
    local height = self:GetSetting(1, "Height") or 40
    local spacing, orientation = self:GetSetting(1, "Spacing") or 0, self:GetSetting(1, "Orientation") or 0
    local visibleCount = 0
    for _, frame in ipairs(self.frames) do
        if frame:IsShown() or frame.preview then
            visibleCount = visibleCount + 1
        end
    end
    visibleCount = math.max(1, visibleCount)

    local containerWidth, containerHeight = Helpers:CalculateContainerSize(visibleCount, width, height, spacing, orientation)
    self.container:SetSize(containerWidth, containerHeight)
end

-- [ DYNAMIC UNIT ASSIGNMENT ]----------------------------------------------------------------------

function Plugin:UpdateFrameUnits()
    if InCombatLockdown() then
        return
    end
    if self.frames and self.frames[1] and self.frames[1].preview then
        return
    end

    local includePlayer = self:GetSetting(1, "IncludePlayer")
    local sortedUnits = GetSortedPartyUnits(includePlayer)

    -- Assign units to frames
    for i = 1, MAX_PARTY_FRAMES do
        local frame = self.frames[i]
        if frame then
            local unit = sortedUnits[i]
            if unit then
                -- Update secure unit attribute (only if changed)
                local currentUnit = frame:GetAttribute("unit")
                if currentUnit ~= unit then
                    frame:SetAttribute("unit", unit)
                    frame.unit = unit

                    -- Re-register unit-specific events
                    frame:UnregisterEvent("UNIT_POWER_UPDATE")
                    frame:UnregisterEvent("UNIT_MAXPOWER")
                    frame:UnregisterEvent("UNIT_DISPLAYPOWER")
                    frame:UnregisterEvent("UNIT_POWER_FREQUENT")
                    frame:UnregisterEvent("UNIT_AURA")
                    frame:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
                    frame:UnregisterEvent("UNIT_PHASE")
                    frame:UnregisterEvent("UNIT_FLAGS")
                    frame:UnregisterEvent("INCOMING_RESURRECT_CHANGED")
                    frame:UnregisterEvent("UNIT_IN_RANGE_UPDATE")

                    frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
                    frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
                    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
                    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)
                    frame:RegisterUnitEvent("UNIT_AURA", unit)
                    frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", unit)
                    frame:RegisterUnitEvent("UNIT_PHASE", unit)
                    frame:RegisterUnitEvent("UNIT_FLAGS", unit)
                    frame:RegisterUnitEvent("INCOMING_RESURRECT_CHANGED", unit)
                    frame:RegisterUnitEvent("UNIT_IN_RANGE_UPDATE", unit)
                end

                -- Update unit watch for visibility
                SafeUnregisterUnitWatch(frame)
                SafeRegisterUnitWatch(frame)

                frame:Show()
                if frame.UpdateAll then
                    frame:UpdateAll()
                end
            else
                -- No unit for this slot - hide frame and clear unit
                SafeUnregisterUnitWatch(frame)
                frame:SetAttribute("unit", nil)
                frame.unit = nil
                frame:Hide()
            end
        end
    end

    self:PositionFrames()
    self:UpdateContainerSize()
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------

function Plugin:UpdateLayout(frame)
    if not frame or InCombatLockdown() then
        return
    end

    local width = self:GetSetting(1, "Width") or 160
    local height = self:GetSetting(1, "Height") or 40

    for _, partyFrame in ipairs(self.frames) do
        partyFrame:SetSize(width, height)
        UpdateFrameLayout(partyFrame, self:GetSetting(1, "BorderSize"), self)
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
    local borderSize = self:GetSetting(1, "BorderSize") or 1
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"

    -- Build list of all frames
    local allFrames = {}
    for _, frame in ipairs(self.frames) do
        table.insert(allFrames, frame)
    end

    for _, frame in ipairs(allFrames) do
        -- Only apply settings to non-preview frames WITH valid units
        if not frame.preview and frame.unit then
            -- Apply size
            Orbit:SafeAction(function() frame:SetSize(width, height) end)

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

            -- Update buff display
            UpdateBuffs(frame, self)

            -- Update defensive/important aura icons
            UpdateDefensiveIcon(frame, self)
            UpdateImportantIcon(frame, self)
            UpdateCrowdControlIcon(frame, self)

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
            local icons = {
                "RoleIcon",
                "LeaderIcon",
                "PhaseIcon",
                "ReadyCheckIcon",
                "ResIcon",
                "SummonIcon",
                "MarkerIcon",
                "DefensiveIcon",
                "ImportantIcon",
                "CrowdControlIcon",
            }
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
                    if anchorX == "RIGHT" then
                        finalX = -offsetX
                    end
                    if anchorY == "TOP" then
                        finalY = -offsetY
                    end

                    frame[iconKey]:ClearAllPoints()
                    -- These are parented to StatusOverlay but positioned relative to frame for drag consistency
                    frame[iconKey]:SetPoint("CENTER", frame, anchorPoint, finalX, finalY)
                end
            end
        end
    end

    -- Refresh preview if active (e.g., after Canvas Mode Apply)
    if self.frames[1] and self.frames[1].preview then
        self:SchedulePreviewUpdate()
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
