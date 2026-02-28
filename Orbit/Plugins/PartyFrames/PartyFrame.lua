---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local Helpers = nil

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local GF = Orbit.Constants.GroupFrames
local MAX_PARTY_FRAMES = 5
local POWER_BAR_HEIGHT_RATIO = Orbit.PartyFrameHelpers.LAYOUT.PowerBarRatio
local DEFENSIVE_ICON_SIZE = 24
local CROWD_CONTROL_ICON_SIZE = 24
local PRIVATE_AURA_ICON_SIZE = 24
local MAX_PRIVATE_AURA_ANCHORS = GF.MaxPrivateAuraAnchors
local AURA_BASE_ICON_SIZE = Orbit.PartyFrameHelpers.LAYOUT.AuraBaseIconSize
local OUT_OF_RANGE_ALPHA = GF.OutOfRangeAlpha
local OFFLINE_ALPHA = GF.OfflineAlpha
local ROLE_PRIORITY = GF.RolePriority

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

            CrowdControlIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2 },
            PrivateAuraAnchor = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 2 },
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
        DisabledComponents = { "DefensiveIcon", "CrowdControlIcon", "RoleIcon" },
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
    Orbit.DispelIndicatorMixin,
    Orbit.AggroIndicatorMixin,
    Orbit.StatusIconMixin,
    Orbit.PartyFrameFactoryMixin
)

-- Enable Canvas Mode (right-click component editing)
Plugin.canvasMode = true
Plugin.supportsHealthText = true

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

local SafeRegisterUnitWatch = Orbit.GroupFrameMixin.SafeRegisterUnitWatch
local SafeUnregisterUnitWatch = Orbit.GroupFrameMixin.SafeUnregisterUnitWatch
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

local Filters = Orbit.GroupAuraFilters
local PartyDebuffPostFilter = Filters:CreateDebuffFilter({ raidFilterFn = function() return "HARMFUL" end })
local PartyBuffPostFilter = Filters:CreateBuffFilter()

local Helpers = Orbit.PartyFrameHelpers
local PARTY_SKIN = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = true }

local PARTY_DEBUFF_CFG = {
    componentKey = "Debuffs", fetchFilter = "HARMFUL", fetchMax = 40,
    postFilter = PartyDebuffPostFilter, tooltipFilter = "HARMFUL",
    skinSettings = PARTY_SKIN, defaultAnchorX = "RIGHT", defaultJustifyH = "LEFT",
    helpers = function() return Orbit.PartyFrameHelpers end,
}

local PARTY_BUFF_CFG = {
    componentKey = "Buffs", fetchFilter = "HELPFUL|PLAYER", fetchMax = 40,
    postFilter = PartyBuffPostFilter, tooltipFilter = "HELPFUL",
    skinSettings = PARTY_SKIN, defaultAnchorX = "LEFT", defaultJustifyH = "RIGHT",
    helpers = function() return Orbit.PartyFrameHelpers end,
}

local function UpdateDebuffs(frame, plugin) plugin:UpdateAuraContainer(frame, plugin, "debuffContainer", "debuffPool", PARTY_DEBUFF_CFG) end
local function UpdateBuffs(frame, plugin) plugin:UpdateAuraContainer(frame, plugin, "buffContainer", "buffPool", PARTY_BUFF_CFG) end
local function UpdateDefensiveIcon(frame, plugin) plugin:UpdateDefensiveIcon(frame, plugin, DEFENSIVE_ICON_SIZE) end
local function UpdateCrowdControlIcon(frame, plugin) plugin:UpdateCrowdControlIcon(frame, plugin, CROWD_CONTROL_ICON_SIZE) end

-- [ PRIVATE AURA ANCHOR ]---------------------------------------------------------------------------

local function UpdatePrivateAuras(frame, plugin)
    local anchor = frame.PrivateAuraAnchor
    if not anchor then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("PrivateAuraAnchor") then
        anchor:Hide()
        return
    end

    -- Clear preview visuals assigned during Canvas Mode
    if anchor.Icon then anchor.Icon:SetTexture(nil) end
    if anchor.SetBackdrop then anchor:SetBackdrop(nil) end
    if anchor.Border then anchor.Border:Hide() end
    if anchor.Shadow then anchor.Shadow:Hide() end

    local unit = frame.unit
    if not unit or not UnitExists(unit) then anchor:Hide() return end

    -- Only recreate anchors if they haven't been created yet for this session/unit
    -- Constantly removing and re-adding them on UNIT_AURA breaks the native timeout UI
    if not frame._privateAuraIDs or frame._privateAuraUnit ~= unit then
        if frame._privateAuraIDs then
            for _, id in ipairs(frame._privateAuraIDs) do 
                C_UnitAuras.RemovePrivateAuraAnchor(id) 
            end
        end
        
        frame._privateAuraIDs = {}
        frame._privateAuraUnit = unit

        local positions = plugin.GetSetting and plugin:GetSetting(1, "ComponentPositions") or {}
        local posData = positions.PrivateAuraAnchor or {}
        local overrides = posData.overrides
        local scale = (overrides and overrides.Scale) or 1
        local iconSize = math.floor(PRIVATE_AURA_ICON_SIZE * scale)
        local spacing = 1
        local totalWidth = (MAX_PRIVATE_AURA_ANCHORS * iconSize) + ((MAX_PRIVATE_AURA_ANCHORS - 1) * spacing)
        local anchorX = posData.anchorX or "CENTER"
        local eff = frame:GetEffectiveScale()

        anchor:SetSize(totalWidth, iconSize)

        for i = 1, MAX_PRIVATE_AURA_ANCHORS do
            local point, relPoint, xOff
            if anchorX == "RIGHT" then
                xOff = OrbitEngine.Pixel:Snap(-((i - 1) * (iconSize + spacing)), eff)
                point, relPoint = "TOPRIGHT", "TOPRIGHT"
            elseif anchorX == "LEFT" then
                xOff = OrbitEngine.Pixel:Snap((i - 1) * (iconSize + spacing), eff)
                point, relPoint = "TOPLEFT", "TOPLEFT"
            else
                local centeredStart = -(totalWidth - iconSize) / 2
                xOff = OrbitEngine.Pixel:Snap(centeredStart + (i - 1) * (iconSize + spacing), eff)
                point, relPoint = "CENTER", "CENTER"
            end
            local anchorID = C_UnitAuras.AddPrivateAuraAnchor({
                unitToken = unit,
                auraIndex = i,
                parent = anchor,
                showCountdownFrame = true,
                showCountdownNumbers = true,
                iconInfo = {
                    iconWidth = iconSize,
                    iconHeight = iconSize,
                    iconAnchor = { point = point, relativeTo = anchor, relativePoint = relPoint, offsetX = xOff, offsetY = 0 },
                    borderScale = 1,
                },
            })
            if anchorID then frame._privateAuraIDs[#frame._privateAuraIDs + 1] = anchorID end
        end
    end
    
    anchor:Show()
end

-- [ STATUS INDICATOR DISPATCH ]---------------------------------------------------------------------

local StatusDispatch = Orbit.GroupFrameMixin.StatusDispatch

-- [ RANGE CHECKING ]--------------------------------------------------------------------------------

local UpdateInRange = Orbit.GroupFrameMixin.UpdateInRange

-- [ PARTY FRAME CREATION ]--------------------------------------------------------------------------

local function CreatePartyFrame(partyIndex, plugin, unitOverride)
    local unit = unitOverride or ("party" .. partyIndex)
    local frameName = unitOverride and "OrbitPartyPlayerFrame" or ("OrbitPartyFrame" .. partyIndex)

    -- Create base unit button
    local frame = OrbitEngine.UnitButton:Create(plugin.container, unit, frameName)
    if frame.NameFrame then frame.NameFrame:SetIgnoreParentAlpha(true) end
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

        UpdateCrowdControlIcon(self, plugin)
        UpdatePrivateAuras(self, plugin)
        StatusDispatch(self, plugin, "UpdateAllPartyStatusIcons")
        StatusDispatch(self, plugin, "UpdateStatusText")
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

                UpdateCrowdControlIcon(f, plugin)
                UpdatePrivateAuras(f, plugin)
                -- Update dispel indicator
                if plugin.UpdateDispelIndicator then
                    plugin:UpdateDispelIndicator(f, plugin)
                end
            end
            return
        end

        -- Combat state change: force refresh buffs for combat-aware filtering
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            UpdateDebuffs(f, plugin)
            UpdateBuffs(f, plugin)
            return
        end

        -- Target changed - update selection highlight for ALL frames
        if event == "PLAYER_TARGET_CHANGED" then
            StatusDispatch(f, plugin, "UpdateSelectionHighlight")
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
                StatusDispatch(f, plugin, "UpdatePhaseIcon")
                StatusDispatch(f, plugin, "UpdateLeaderIcon")
                UpdateInRange(f)
            end
            return
        end
        if event == "UNIT_CONNECTION" then
            if eventUnit == f.unit then
                UpdateInRange(f)
                StatusDispatch(f, plugin, "UpdateStatusText")
            end
            return
        end

        -- Ready check events
        if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            StatusDispatch(f, plugin, "UpdateReadyCheck")
            return
        end

        -- Resurrection updates
        if event == "INCOMING_RESURRECT_CHANGED" then
            if eventUnit == f.unit then
                StatusDispatch(f, plugin, "UpdateIncomingRes")
            end
            return
        end

        -- Summon updates
        if event == "INCOMING_SUMMON_CHANGED" then
            StatusDispatch(f, plugin, "UpdateIncomingSummon")
            return
        end

        if event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
            StatusDispatch(f, plugin, "UpdateRoleIcon")
            StatusDispatch(f, plugin, "UpdateLeaderIcon")
            return
        end

        if event == "RAID_TARGET_UPDATE" then
            StatusDispatch(f, plugin, "UpdateMarkerIcon")
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
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            StatusDispatch(f, plugin, "UpdateStatusText")
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

function Plugin:AddSettings(dialog, systemFrame)
    Orbit.PartyFrameSettings(self, dialog, systemFrame)
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

            "CrowdControlIcon",
            "PrivateAuraAnchor",
        }

        for _, key in ipairs(textComponents) do
            local element = firstFrame[key]
            if element then
                OrbitEngine.ComponentDrag:Attach(element, self.container, {
                    key = key,
                    onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(pluginRef, 1, key),
                })
            end
        end

        for _, key in ipairs(iconComponents) do
            local element = firstFrame[key]
            if element then
                OrbitEngine.ComponentDrag:Attach(element, self.container, {
                    key = key,
                    onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(pluginRef, 1, key),
                })
            end
        end

        local auraContainerComponents = { "Buffs", "Debuffs" }
        for _, key in ipairs(auraContainerComponents) do
            local containerKey = key == "Buffs" and "buffContainer" or "debuffContainer"
            if not firstFrame[containerKey] then
                firstFrame[containerKey] = CreateFrame("Frame", nil, firstFrame)
                firstFrame[containerKey]:SetSize(AURA_BASE_ICON_SIZE, AURA_BASE_ICON_SIZE)
            end
            OrbitEngine.ComponentDrag:Attach(firstFrame[containerKey], self.container, {
                key = key,
                isAuraContainer = true,
                onPositionChange = OrbitEngine.ComponentDrag:MakeAuraPositionCallback(pluginRef, 1, key),
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
    local PARTY_BASE_DRIVER = "[petbattle] hide; [@raid1,exists] hide; [@party1,exists] show; hide"
    local function UpdateVisibilityDriver(plugin)
        if InCombatLockdown() or Orbit:IsEditMode() then return end
        local mv = Orbit.MountedVisibility
        local driver = (mv and mv:ShouldHide() and not IsMounted()) and "hide" or (mv and mv:GetMountedDriver(PARTY_BASE_DRIVER) or PARTY_BASE_DRIVER)
        RegisterStateDriver(plugin.container, "visibility", driver)
    end
    self.UpdateVisibilityDriver = function() UpdateVisibilityDriver(self) end
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
                UpdateVisibilityDriver(self)
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

    -- DefensiveIcon: set .Icon texture for Canvas Mode cloning
    local StatusMixin = Orbit.StatusIconMixin
    if frame.DefensiveIcon then
        frame.DefensiveIcon.Icon:SetTexture(StatusMixin:GetDefensiveTexture())
        frame.DefensiveIcon:SetSize(DEFENSIVE_ICON_SIZE, DEFENSIVE_ICON_SIZE)
        frame.DefensiveIcon:Show()
    end

    if frame.CrowdControlIcon then
        frame.CrowdControlIcon.Icon:SetTexture(StatusMixin:GetCrowdControlTexture())
        frame.CrowdControlIcon:SetSize(CROWD_CONTROL_ICON_SIZE, CROWD_CONTROL_ICON_SIZE)
        frame.CrowdControlIcon:Show()
    end
    if frame.PrivateAuraAnchor then
        frame.PrivateAuraAnchor:SetSize(PRIVATE_AURA_ICON_SIZE, PRIVATE_AURA_ICON_SIZE)
        frame.PrivateAuraAnchor:Show()
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
    self.container.orbitForceAnchorPoint = Helpers:GetContainerAnchor(growthDirection)

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
    local borderSize = self:GetSetting(1, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(UIParent:GetEffectiveScale() or 1)
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
            local showHealthValue = self:GetSetting(1, "ShowHealthValue")
            if showHealthValue == nil then showHealthValue = true end
            frame.healthTextEnabled = showHealthValue
            if frame.UpdateHealthText then frame:UpdateHealthText() end
            StatusDispatch(frame, self, "UpdateStatusText")

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

            UpdateCrowdControlIcon(frame, self)

            -- Update all status indicators
            StatusDispatch(frame, self, "UpdateAllPartyStatusIcons")

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
        OrbitEngine.ComponentDrag:RestoreFramePositions(self.container, savedPositions)

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

                "CrowdControlIcon",
                "PrivateAuraAnchor",
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
        if not frame.preview and frame.unit and frame.UpdateAll then
            frame:UpdateAll()
            UpdatePowerBar(frame, self)
        end
    end
end

Orbit.EventBus:On("DISPEL_STATE_CHANGED", function(unit)
    if not Plugin.frames then return end
    for _, frame in ipairs(Plugin.frames) do
        if frame and frame.unit == unit and frame:IsShown() and Plugin.UpdateDispelIndicator then
            Plugin:UpdateDispelIndicator(frame, Plugin)
        end
    end
end, Plugin)
