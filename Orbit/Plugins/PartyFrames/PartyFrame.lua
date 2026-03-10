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
local HEALER_AURA_ICON_SIZE = 16
local HealerReg = Orbit.HealerAuraRegistry
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
        PowerBarHeight = 10,
        Orientation = 0,
        Spacing = 3,
        HealthTextMode = "percent_short",
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT", posX = -75, posY = 0 },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT", posX = 75, posY = 0 },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2, justifyH = "CENTER", posX = 0, posY = 18 },
            RoleIcon = { anchorX = "RIGHT", offsetX = 10, anchorY = "TOP", offsetY = 3, justifyH = "RIGHT" },
            LeaderIcon = { anchorX = "LEFT", offsetX = 10, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", posX = -70, posY = 20 },
            StatusIcons = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
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
        DisabledComponents = (function()
            local d = { "DefensiveIcon", "CrowdControlIcon", "RoleIcon" }
            for _, k in ipairs(Orbit.HealerAuraRegistry:AllSlotKeys()) do d[#d + 1] = k end
            return d
        end)(),
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
    local pct = plugin and plugin:GetSetting(1, "PowerBarHeight")
    local ratio = pct and (pct / 100) or nil
    Helpers:UpdateFrameLayout(frame, borderSize, showPowerBar, ratio)
end

local Filters = Orbit.GroupAuraFilters
local PartyDebuffPostFilter = Filters:CreateDebuffFilter({ raidFilterFn = function() return "HARMFUL" end })
local PartyBuffPostFilter = Filters:CreateBuffFilter()

local Helpers = Orbit.PartyFrameHelpers
local PARTY_SKIN = Orbit.Constants.Aura.SkinWithTimer

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
local function GetComponentIconSize(plugin, key)
    local positions = plugin:GetSetting(1, "ComponentPositions")
    local overrides = positions and positions[key] and positions[key].overrides
    return (overrides and overrides.IconSize) or HEALER_AURA_ICON_SIZE
end

local function UpdateHealerAuras(frame, plugin)
    for _, slot in ipairs(HealerReg:ActiveSlots()) do
        plugin:UpdateSpellAuraIcon(frame, plugin, slot.key, slot.spellId, GetComponentIconSize(plugin, slot.key), slot.altSpellId)
    end
end
local function UpdateMissingRaidBuffs(frame, plugin)
    plugin:UpdateMissingRaidBuffs(frame, plugin, "RaidBuff", HealerReg:ActiveRaidBuffs(), GetComponentIconSize(plugin, "RaidBuff"))
end

-- [ PRIVATE AURA ANCHOR ]---------------------------------------------------------------------------
local function UpdatePrivateAuras(frame, plugin) Orbit.PrivateAuraMixin:Update(frame, plugin, PRIVATE_AURA_ICON_SIZE) end

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

    -- Shared callbacks for event/show handlers
    local eventCallbacks = {
        UpdatePowerBar = UpdatePowerBar, UpdateDebuffs = UpdateDebuffs, UpdateBuffs = UpdateBuffs,
        UpdateDefensiveIcon = UpdateDefensiveIcon, UpdateCrowdControlIcon = UpdateCrowdControlIcon,
        UpdatePrivateAuras = UpdatePrivateAuras, UpdateFrameLayout = UpdateFrameLayout,
        UpdateHealerAuras = UpdateHealerAuras, UpdateMissingRaidBuffs = UpdateMissingRaidBuffs,
    }
    local originalOnEvent = frame:GetScript("OnEvent")
    frame:SetScript("OnShow", Orbit.GroupFrameMixin.CreateOnShowHandler(plugin, eventCallbacks))
    frame:SetScript("OnEvent", Orbit.GroupFrameMixin.CreateEventHandler(plugin, eventCallbacks, originalOnEvent))

    -- Configure frame features (delegated to factory mixin)
    plugin:ConfigureFrame(frame)

    return frame
end

local function HideNativePartyFrames()
    for i = 1, 4 do
        local partyFrame = _G["PartyMemberFrame" .. i]
        if partyFrame then
            OrbitEngine.NativeFrame:Disable(partyFrame)
            if not partyFrame.orbitSetPointHooked then
                hooksecurefunc(partyFrame, "SetPoint", function(self)
                    if InCombatLockdown() then return end
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
    OrbitEngine.NativeFrame:Disable(PartyFrame)
    OrbitEngine.NativeFrame:Disable(CompactPartyFrame)
    for i = 1, 5 do
        local member = _G["CompactPartyFrameMember" .. i]
        if member then member:UnregisterAllEvents() end
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
    for _, k in ipairs(HealerReg:ActiveKeys()) do
        if k == "RaidBuff" then
            local raidBuffs = HealerReg:ActiveRaidBuffs()
            if #raidBuffs > 0 then self:EnsureRaidBuffContainer(firstFrame, k, raidBuffs, GetComponentIconSize(self, k)) end
        else
            self:EnsureAuraIcon(firstFrame, k, GetComponentIconSize(self, k))
        end
    end
    local healerIconKeys = { "RoleIcon", "LeaderIcon", "MarkerIcon", "DefensiveIcon", "CrowdControlIcon", "PrivateAuraAnchor" }
    for _, k in ipairs(HealerReg:ActiveKeys()) do healerIconKeys[#healerIconKeys + 1] = k end
    Orbit.GroupCanvasRegistration:RegisterComponents(pluginRef, self.container, firstFrame,
        { "Name", "HealthText" },
        healerIconKeys,
        AURA_BASE_ICON_SIZE
    )

    -- Container is the selectable frame for Edit Mode
    self.frame = self.container
    self.frame.anchorOptions = { horizontal = true, vertical = false }
    self.frame.orbitResizeBounds = { minW = 50, maxW = 400, minH = 20, maxH = 100 }
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
        self.container:SetPoint(anchor, UIParent, "TOPLEFT", GF.DefaultPartyOffsetX, GF.DefaultPartyOffsetY)
    end

    -- Helper to update visibility driver based on IncludePlayer setting
    local PARTY_BASE_DRIVER = "[petbattle] hide; [@raid1,exists] hide; [@party1,exists] show; hide"
    local function UpdateVisibilityDriver(plugin)
        if InCombatLockdown() or Orbit:IsEditMode() then return end
        RegisterStateDriver(plugin.container, "visibility", PARTY_BASE_DRIVER)
    end
    self.UpdateVisibilityDriver = function() UpdateVisibilityDriver(self) end
    UpdateVisibilityDriver(self)
    self.mountedConfig = { frame = self.container, hoverReveal = true, combatRestore = true }

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
                if frame.unit then
                    UpdateInRange(frame)
                    if frame.UpdateAll then frame:UpdateAll() end
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

    self.skipEditModeApply = true
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
            local result = originalOpen(dlg, frame, plugin, systemIndex)
            if frame == self.container or frame == self.frames[1] then
                self:SchedulePreviewUpdate()
            end
            return result
        end
    end
end

-- Prepare status icons with placeholder atlases for Canvas Mode cloning
function Plugin:PrepareIconsForCanvasMode()
    local frame = self.frames[1]
    if not frame then return end
    Orbit.GroupCanvasRegistration:PrepareIcons(self, frame, {
        statusIcons = { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" },
        statusIconSize = 24,
        roleIcons = { "RoleIcon", "LeaderIcon" },
        roleIconSize = 16,
        defensiveSize = DEFENSIVE_ICON_SIZE,
        crowdControlSize = CROWD_CONTROL_ICON_SIZE,
        privateAuraSize = PRIVATE_AURA_ICON_SIZE,
        healerAuraSize = HEALER_AURA_ICON_SIZE,
    }, HealerReg:ActiveSlots(), HealerReg:ActiveRaidBuffs())
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
    if not frame or InCombatLockdown() then return end
    local width = self:GetSetting(1, "Width") or 160
    local height = self:GetSetting(1, "Height") or 40
    for _, partyFrame in ipairs(self.frames) do
        partyFrame:SetSize(width, height)
        UpdateFrameLayout(partyFrame, self:GetSetting(1, "BorderSize"), self)
        self:UpdateTextSize(partyFrame)
    end
    self:PositionFrames()
    for _, partyFrame in ipairs(self.frames) do
        if partyFrame.ConstrainNameWidth then partyFrame:ConstrainNameWidth() end
    end
end

-- Shared styling applied to BOTH live and preview frames (single source of truth)
function Plugin:ApplyFrameStyle(frame, showPower)
    local width = self:GetSetting(1, "Width") or 160
    local height = self:GetSetting(1, "Height") or 40
    local borderSize = self:GetSetting(1, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(UIParent:GetEffectiveScale() or 1)
    local textureName = self:GetSetting(1, "Texture")

    frame:SetSize(width, height)
    if frame.SetBorder then frame:SetBorder(borderSize) end
    UpdateFrameLayout(frame, borderSize, self)

    -- Texture
    if frame.Health then Orbit.Skin:SkinStatusBar(frame.Health, textureName, nil, true) end
    if frame.Power then
        local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
        frame.Power:SetStatusBarTexture(texturePath)
    end

    -- Power bar visibility
    if showPower ~= nil then
        if frame.Power then
            if showPower then frame.Power:Show() else frame.Power:Hide() end
        end
    end

    -- Text styling
    self:ApplyTextStyling(frame)

    -- Component positions + style overrides (positions, font, color, scale)
    if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end

    -- Icon positions (healer auras, status icons, etc.)
    local savedPositions = self:GetComponentPositions(1)
    if savedPositions then
        local iconKeys = { "RoleIcon", "LeaderIcon", "StatusIcons", "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "MarkerIcon", "DefensiveIcon", "CrowdControlIcon", "PrivateAuraAnchor" }
        local activeKeys = HealerReg:ActiveKeys()
        for _, k in ipairs(activeKeys) do iconKeys[#iconKeys + 1] = k end
        -- Ensure healer aura icons exist with correct size
        for _, k in ipairs(activeKeys) do
            if savedPositions[k] then
                if k == "RaidBuff" then
                    if not frame.RaidBuff then
                        local sz = GetComponentIconSize(self, k)
                        local c = CreateFrame("Frame", nil, frame)
                        c:SetPoint("CENTER", frame, "CENTER", 0, 0)
                        c:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.HealerAura)
                        c._raidIcons = {}
                        c:SetSize(sz, sz)
                        frame.RaidBuff = c
                    end
                else
                    self:EnsureAuraIcon(frame, k, GetComponentIconSize(self, k))
                end
            end
        end
        Orbit.GroupCanvasRegistration:ApplyIconPositions({ frame }, savedPositions, iconKeys)
    end
end

function Plugin:OnCanvasApply()
    Orbit.GroupCanvasRegistration:OnCanvasApply(self)
    self:ApplySettings()
end

function Plugin:ApplySettings()
    if not self.frames then return end

    for _, frame in ipairs(self.frames) do
        if not frame.preview and frame.unit then
            Orbit:SafeAction(function() self:ApplyFrameStyle(frame) end)

            -- Live-only: real data updates
            local healthTextMode = self:GetSetting(1, "HealthTextMode") or "percent_short"
            if frame.SetHealthTextMode then frame:SetHealthTextMode(healthTextMode) end
            local showHealthValue = self:GetSetting(1, "ShowHealthValue")
            if showHealthValue == nil then showHealthValue = true end
            frame.healthTextEnabled = showHealthValue
            if frame.UpdateHealthText then frame:UpdateHealthText() end
            StatusDispatch(frame, self, "UpdateStatusText")
            if frame.SetClassColour then frame:SetClassColour(true) end
            UpdatePowerBar(frame, self)
            UpdateDebuffs(frame, self)
            UpdateBuffs(frame, self)
            UpdateDefensiveIcon(frame, self)
            UpdateCrowdControlIcon(frame, self)
            UpdateHealerAuras(frame, self)
            UpdateMissingRaidBuffs(frame, self)
            StatusDispatch(frame, self, "UpdateAllPartyStatusIcons")
            if frame.UpdateAll then frame:UpdateAll() end
        end
    end

    self:PositionFrames()
    OrbitEngine.Frame:RestorePosition(self.container, self, 1)

    -- Restore drag positions on container (first frame) — skip during preview
    -- to avoid overriding consistent positions set by ApplyPreviewVisuals
    if self.frames[1] and self.frames[1].preview then
        self:SchedulePreviewUpdate()
    else
        local savedPositions = self:GetSetting(1, "ComponentPositions")
        if savedPositions then
            OrbitEngine.ComponentDrag:RestoreFramePositions(self.container, savedPositions)
        end
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
