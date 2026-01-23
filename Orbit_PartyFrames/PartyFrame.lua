---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- Reference to shared helpers (loaded from PartyFrameHelpers.lua)
local Helpers = nil -- Will be set when first needed

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_PARTY_FRAMES = 5  -- 4 party + 1 potential player
local POWER_BAR_HEIGHT_RATIO = 0.2

-- Role priority for sorting (Tank > Healer > DPS > None)
local ROLE_PRIORITY = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
    NONE = 4,
}

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
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = -2 },
        },
        ShowMarkerIcon = true,
        IncludePlayer = false,  -- Show player in party frames
        SortByRole = true,      -- Tank > Healer > DPS ordering
        -- Dispel Indicator Settings
        DispelIndicatorEnabled = true,
        DispelFilterMode = "PLAYER",  -- PLAYER or ALL
        DispelThickness = 2,
        DispelFrequency = 0.25,
        DispelNumLines = 8,
        DispelColorMagic = { r = 0.2, g = 0.6, b = 1.0, a = 1 },
        DispelColorCurse = { r = 0.6, g = 0.0, b = 1.0, a = 1 },
        DispelColorDisease = { r = 0.6, g = 0.4, b = 0.0, a = 1 },
        DispelColorPoison = { r = 0.0, g = 0.6, b = 0.0, a = 1 },
        DispelDebug = false,  -- Debug mode (not shown in UI, toggle via /run)
        -- Aggro Indicator Settings
        AggroIndicatorEnabled = true,
        AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        AggroThickness = 2,
        AggroFrequency = 0.25,
        AggroNumLines = 8,
    },
}, Orbit.Constants.PluginGroups.PartyFrames)

-- Apply Mixins (Status, Dispel, Aggro, Factory)
Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.PartyFramePreviewMixin, Orbit.AuraMixin, Orbit.PartyFrameDispelMixin, Orbit.PartyFrameAggroMixin, Orbit.PartyFrameStatusMixin, Orbit.PartyFrameFactoryMixin)

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

-- Combat-safe wrappers for UnitWatch using Orbit.CombatManager
-- Prevents taint by queueing operations during combat
local function SafeRegisterUnitWatch(frame)
    if not frame then return end
    
    Orbit:SafeAction(function()
        RegisterUnitWatch(frame)
    end)
end

local function SafeUnregisterUnitWatch(frame)
    if not frame then return end
    
    Orbit:SafeAction(function()
        UnregisterUnitWatch(frame)
    end)
end

-- Use centralized power colors from Constants
local function GetPowerColor(powerType)
    return Orbit.Constants.Colors.PowerType[powerType] or { r = 0.5, g = 0.5, b = 0.5 }
end

-- [ ROLE SORTING ]---------------------------------------------------------------------------------

local function GetRolePriority(unit)
    if not UnitExists(unit) then return 99 end
    local role = UnitGroupRolesAssigned(unit)
    return ROLE_PRIORITY[role] or 4
end

-- Returns a sorted list of units based on role
-- If includePlayer is true, includes "player" in the list
local function GetSortedPartyUnits(includePlayer, sortByRole)
    local units = {}
    
    -- Add player if requested
    if includePlayer then
        table.insert(units, "player")
    end
    
    -- Add party members
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            table.insert(units, unit)
        end
    end
    
    -- Sort by role if enabled
    if sortByRole and #units > 1 then
        table.sort(units, function(a, b)
            local priorityA = GetRolePriority(a)
            local priorityB = GetRolePriority(b)
            if priorityA == priorityB then
                -- Secondary sort: alphabetical by name for consistency
                local nameA = UnitName(a) or ""
                local nameB = UnitName(b) or ""
                -- Handle secret values
                if issecretvalue and (issecretvalue(nameA) or issecretvalue(nameB)) then
                    return false  -- Maintain original order if names are secret
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
-- These are thin wrappers that delegate to the StatusMixin methods on Plugin

local function UpdateRoleIcon(frame, plugin)
    if plugin.UpdateRoleIcon then plugin:UpdateRoleIcon(frame, plugin) end
end

local function UpdateLeaderIcon(frame, plugin)
    if plugin.UpdateLeaderIcon then plugin:UpdateLeaderIcon(frame, plugin) end
end

local function UpdateSelectionHighlight(frame, plugin)
    if plugin.UpdateSelectionHighlight then plugin:UpdateSelectionHighlight(frame, plugin) end
end

local function UpdateAggroHighlight(frame, plugin)
    if plugin.UpdateAggroHighlight then plugin:UpdateAggroHighlight(frame, plugin) end
end

local function UpdatePhaseIcon(frame, plugin)
    if plugin.UpdatePhaseIcon then plugin:UpdatePhaseIcon(frame, plugin) end
end

local function UpdateReadyCheck(frame, plugin)
    if plugin.UpdateReadyCheck then plugin:UpdateReadyCheck(frame, plugin) end
end

local function UpdateIncomingRes(frame, plugin)
    if plugin.UpdateIncomingRes then plugin:UpdateIncomingRes(frame, plugin) end
end

local function UpdateIncomingSummon(frame, plugin)
    if plugin.UpdateIncomingSummon then plugin:UpdateIncomingSummon(frame, plugin) end
end

local function UpdateMarkerIcon(frame, plugin)
    if plugin.UpdateMarkerIcon then plugin:UpdateMarkerIcon(frame, plugin) end
end

local function UpdateAllStatusIndicators(frame, plugin)
    if plugin.UpdateAllStatusIndicators then plugin:UpdateAllStatusIndicators(frame, plugin) end
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

    -- Create Status Indicators (delegated to factory mixin)
    plugin:CreateStatusIcons(frame)

    -- Register frame events (delegated to factory mixin)
    plugin:RegisterFrameEvents(frame, unit)

    -- Update Loop
    frame:SetScript("OnShow", function(self)
        -- Guard against nil unit (frames start hidden, unit assigned later)
        if not self.unit then return end
        
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
            -- Use f.unit (current assigned unit) not closure 'unit' which may be stale
            if eventUnit == f.unit then
                UpdateDebuffs(f, plugin)
                -- Update dispel indicator
                if plugin.UpdateDispelIndicator then
                    plugin:UpdateDispelIndicator(f, plugin)
                end
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
        
        if event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" then
            UpdateRoleIcon(f, plugin)
            UpdateLeaderIcon(f, plugin)
            return
        end

        if event == "RAID_TARGET_UPDATE" then
            UpdateMarkerIcon(f, plugin)
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

-- Helper to reduce repetitive onChange handlers
local function makeOnChange(plugin, key, preApply)
    return function(val)
        plugin:SetSetting(1, key, val)
        if preApply then preApply(val) end
        plugin:ApplySettings()
        if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then
            plugin:SchedulePreviewUpdate()
        end
    end
end

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = 1
    local WL = OrbitEngine.WidgetLogic

    local schema = {
        hideNativeSettings = true,
        controls = {
            { type = "dropdown", key = "Orientation", label = "Orientation", default = 0,
                options = { { text = "Vertical", value = 0 }, { text = "Horizontal", value = 1 } },
                onChange = makeOnChange(self, "Orientation"),
            },
            { type = "slider", key = "Width", label = "Width", min = 100, max = 250, step = 5, default = 160,
                onChange = makeOnChange(self, "Width"),
            },
            { type = "slider", key = "Height", label = "Height", min = 20, max = 60, step = 5, default = 40,
                onChange = makeOnChange(self, "Height"),
            },
            { type = "slider", key = "Spacing", label = "Spacing", min = 0, max = 10, step = 1, default = 0,
                onChange = makeOnChange(self, "Spacing"),
            },
            { type = "dropdown", key = "HealthTextMode", label = "Health Text", default = "percent_short",
                options = {
                    { text = "Hide", value = "hide" },
                    { text = "Percentage / Short", value = "percent_short" },
                    { text = "Short / Percentage", value = "short_percent" },
                    { text = "Percentage / Raw", value = "percent_raw" },
                    { text = "Raw / Percentage", value = "raw_percent" },
                },
                onChange = makeOnChange(self, "HealthTextMode"),
            },
            { type = "dropdown", key = "DebuffPosition", label = "Debuff Position", default = "Above",
                options = {
                    { text = "Disabled", value = "Disabled" },
                    { text = "Above", value = "Above" },
                    { text = "Below", value = "Below" },
                    { text = "Left", value = "Left" },
                    { text = "Right", value = "Right" },
                },
                onChange = makeOnChange(self, "DebuffPosition"),
            },
            { type = "slider", key = "MaxDebuffs", label = "Max Debuffs", min = 1, max = 6, step = 1, default = 3,
                visibleIf = function() return self:GetSetting(1, "DebuffPosition") ~= "Disabled" end,
                onChange = makeOnChange(self, "MaxDebuffs"),
            },
            { type = "slider", key = "DebuffSize", label = "Debuff Size", min = 12, max = 32, step = 2, default = 20,
                visibleIf = function() return self:GetSetting(1, "DebuffPosition") ~= "Disabled" end,
                onChange = makeOnChange(self, "DebuffSize"),
            },
            { type = "checkbox", key = "IncludePlayer", label = "Include Player", default = false,
                onChange = makeOnChange(self, "IncludePlayer", function(val)
                    -- In preview mode, ShowPreview recalculates framesToShow with new setting
                    -- UpdateFrameUnits early-returns during preview, so call ShowPreview instead
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:ShowPreview()
                    else
                        self:UpdateFrameUnits()
                    end
                end),
            },
            { type = "checkbox", key = "SortByRole", label = "Sort by Role", default = true,
                onChange = makeOnChange(self, "SortByRole", function()
                    if self.frames and self.frames[1] and self.frames[1].preview then
                        self:ShowPreview()
                    else
                        self:UpdateFrameUnits()
                    end
                end),
            },
            { type = "checkbox", key = "ShowMarkerIcon", label = "Show Marker Icon", default = true,
                onChange = makeOnChange(self, "ShowMarkerIcon"),
            },
            { type = "checkbox", key = "ShowPowerBar", label = "Show Power Bar", default = true,
                onChange = makeOnChange(self, "ShowPowerBar"),
            },
            -- Dispel Indicators
            { type = "header", label = "Dispel Indicators" },
            { type = "checkbox", key = "DispelIndicatorEnabled", label = "Enable Dispel Indicators", default = true,
                onChange = makeOnChange(self, "DispelIndicatorEnabled", function()
                    if self.UpdateAllDispelIndicators then
                        self:UpdateAllDispelIndicators(self)
                    end
                end),
            },
            { type = "dropdown", key = "DispelFilterMode", label = "Filter Mode", default = "PLAYER",
                options = {
                    { value = "PLAYER", label = "Dispellable by Me" },
                    { value = "ALL", label = "All Dispellable" },
                },
                onChange = makeOnChange(self, "DispelFilterMode", function()
                    if self.UpdateAllDispelIndicators then
                        self:UpdateAllDispelIndicators(self)
                    end
                end),
            },
            { type = "slider", key = "DispelThickness", label = "Border Thickness", default = 2, min = 1, max = 5, step = 1,
                onChange = makeOnChange(self, "DispelThickness", function()
                    if self.UpdateAllDispelIndicators then
                        self:UpdateAllDispelIndicators(self)
                    end
                end),
            },
            { type = "slider", key = "DispelFrequency", label = "Animation Speed", default = 0.25, min = 0.1, max = 1.0, step = 0.05,
                onChange = makeOnChange(self, "DispelFrequency", function()
                    if self.UpdateAllDispelIndicators then
                        self:UpdateAllDispelIndicators(self)
                    end
                end),
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

        -- NOTE: Don't register unit watch here - UpdateFrameUnits handles visibility
        -- based on IncludePlayer and SortByRole settings
        self.frames[i]:Hide()  -- Start hidden, UpdateFrameUnits will show valid frames
    end



    -- Register components for Canvas Mode drag (on CONTAINER, using first frame's elements)
    -- Canvas Mode opens on the container, so components must be registered there
    local pluginRef = self
    local firstFrame = self.frames[1]
    if OrbitEngine.ComponentDrag and firstFrame then
        -- Components that support justifyH (text elements)
        local textComponents = {"Name", "HealthText"}
        -- Components that don't support justifyH (icons)
        local iconComponents = {"RoleIcon", "LeaderIcon", "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "MarkerIcon"}
        
        -- Register text components with justifyH support
        for _, key in ipairs(textComponents) do
            local element = firstFrame[key]
            if element then
                OrbitEngine.ComponentDrag:Attach(element, self.container, {
                    key = key,
                    onPositionChange = function(_, anchorX, anchorY, offsetX, offsetY, justifyH)
                        local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                        positions[key] = { anchorX = anchorX, anchorY = anchorY, 
                                          offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                        pluginRef:SetSetting(1, "ComponentPositions", positions)
                    end
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
                        positions[key] = { anchorX = anchorX, anchorY = anchorY, 
                                          offsetX = offsetX, offsetY = offsetY }
                        pluginRef:SetSetting(1, "ComponentPositions", positions)
                    end
                })
            end
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

    -- Helper to update visibility driver based on IncludePlayer setting
    local function UpdateVisibilityDriver(plugin)
        if InCombatLockdown() then return end
        
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

-- [ DYNAMIC UNIT ASSIGNMENT ]----------------------------------------------------------------------

function Plugin:UpdateFrameUnits()
    if InCombatLockdown() then return end
    
    -- Don't modify frames during preview mode - let ShowPreview handle display
    if self.frames and self.frames[1] and self.frames[1].preview then
        return
    end
    
    local includePlayer = self:GetSetting(1, "IncludePlayer")
    local sortByRole = self:GetSetting(1, "SortByRole")
    local sortedUnits = GetSortedPartyUnits(includePlayer, sortByRole)
    
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
                    
                    frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
                    frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
                    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
                    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)
                    frame:RegisterUnitEvent("UNIT_AURA", unit)
                    frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", unit)
                    frame:RegisterUnitEvent("UNIT_PHASE", unit)
                    frame:RegisterUnitEvent("UNIT_FLAGS", unit)
                    frame:RegisterUnitEvent("INCOMING_RESURRECT_CHANGED", unit)
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
        -- Only apply settings to non-preview frames WITH valid units
        if not frame.preview and frame.unit then
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
            local icons = { "RoleIcon", "LeaderIcon", "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "MarkerIcon" }
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
