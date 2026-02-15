---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local Helpers = nil

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_RAID_FRAMES = 30
local MAX_RAID_GROUPS = 6
local FRAMES_PER_GROUP = 5
local DEFENSIVE_ICON_SIZE = 18
local IMPORTANT_ICON_SIZE = 18
local CROWD_CONTROL_ICON_SIZE = 18
local AURA_SPACING = 2
local AURA_BASE_ICON_SIZE = 10
local MIN_ICON_SIZE = 10
local OUT_OF_RANGE_ALPHA = 0.2

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_RaidFrames"

local Plugin = Orbit:RegisterPlugin("Raid Frames", SYSTEM_ID, {
    defaults = {
        Width = 90,
        Height = 36,
        Scale = 100,
        MemberSpacing = 1,
        GroupSpacing = 4,
        Orientation = 0,
        GrowthDirection = "Down",
        GroupGrowthDirection = "Right",
        SortMode = "Group",
        ShowPowerBar = true,
        HealthTextMode = "percent_short",

        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 3, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            HealthText = { anchorX = "RIGHT", offsetX = 3, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = -1 },
            RoleIcon = { anchorX = "RIGHT", offsetX = 8, anchorY = "TOP", offsetY = 2, justifyH = "RIGHT" },
            LeaderIcon = { anchorX = "LEFT", offsetX = 8, anchorY = "TOP", offsetY = 0, justifyH = "LEFT" },
            SummonIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
            PhaseIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
            ResIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
            ReadyCheckIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
            DefensiveIcon = { anchorX = "LEFT", offsetX = 2, anchorY = "CENTER", offsetY = 0 },
            ImportantIcon = { anchorX = "RIGHT", offsetX = 2, anchorY = "CENTER", offsetY = 0 },
            CrowdControlIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2 },
            Buffs = {
                anchorX = "LEFT",
                anchorY = "CENTER",
                offsetX = 2,
                offsetY = 0,
                posX = -95,
                posY = 0,
                overrides = { MaxIcons = 3, IconSize = 10, MaxRows = 2 },
            },
            Debuffs = {
                anchorX = "RIGHT",
                anchorY = "CENTER",
                offsetX = 2,
                offsetY = 0,
                posX = 95,
                posY = 0,
                overrides = { MaxIcons = 3, IconSize = 10, MaxRows = 2 },
            },
        },
        DisabledComponents = { "DefensiveIcon", "ImportantIcon", "CrowdControlIcon" },
        DisabledComponentsMigrated = true,
        AggroIndicatorEnabled = true,
        AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        AggroThickness = 1,
        DispelIndicatorEnabled = true,
        DispelThickness = 2,
        DispelFrequency = 0.25,
        DispelNumLines = 8,
        DispelColorMagic = { r = 0.2, g = 0.6, b = 1.0, a = 1 },
        DispelColorCurse = { r = 0.6, g = 0.0, b = 1.0, a = 1 },
        DispelColorDisease = { r = 0.6, g = 0.4, b = 0.0, a = 1 },
        DispelColorPoison = { r = 0.0, g = 0.6, b = 0.0, a = 1 },
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.RaidFramePreviewMixin, Orbit.AuraMixin, Orbit.AggroIndicatorMixin, Orbit.StatusIconMixin, Orbit.RaidFrameFactoryMixin)

if Orbit.PartyFrameDispelMixin then
    Mixin(Plugin, Orbit.PartyFrameDispelMixin)
end

Plugin.canvasMode = true

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

-- [ AURA POST-FILTER ]------------------------------------------------------------------------------

local function IsAuraIncluded(unit, auraInstanceID, filter) return not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, filter) end

-- [ SMART AURA LAYOUT ]-----------------------------------------------------------------------------

local function CalculateSmartAuraLayout(frameWidth, frameHeight, position, maxIcons, numIcons, overrides)
    local isHorizontal = (position == "Above" or position == "Below")
    local maxRows = (overrides and overrides.MaxRows) or 2
    local iconSize = (overrides and overrides.IconSize) or AURA_BASE_ICON_SIZE
    iconSize = math.max(MIN_ICON_SIZE, iconSize)
    local rows, iconsPerRow, containerWidth, containerHeight
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

-- [ POWER BAR UPDATE ]------------------------------------------------------------------------------

local function UpdatePowerBar(frame, plugin)
    if not frame.Power or not frame.unit or not UnitExists(frame.unit) then
        return
    end
    local showHealerPower = plugin:GetSetting(1, "ShowPowerBar")
    local isHealer = UnitGroupRolesAssigned(frame.unit) == "HEALER"
    if not isHealer or showHealerPower == false then
        frame.Power:Hide()
        return
    end
    frame.Power:Show()
    local power, maxPower, powerType = UnitPower(frame.unit), UnitPowerMax(frame.unit), UnitPowerType(frame.unit)
    frame.Power:SetMinMaxValues(0, maxPower)
    frame.Power:SetValue(power)
    local color = Orbit.Constants.Colors:GetPowerColor(powerType)
    frame.Power:SetStatusBarColor(color.r, color.g, color.b)
end

local function UpdateFrameLayout(frame, borderSize, plugin)
    if not Helpers then
        Helpers = Orbit.RaidFrameHelpers
    end
    local showHealerPower = plugin and plugin:GetSetting(1, "ShowPowerBar")
    if showHealerPower == nil then showHealerPower = true end
    local isHealer = frame.unit and UnitGroupRolesAssigned(frame.unit) == "HEALER"
    Helpers:UpdateFrameLayout(frame, borderSize, showHealerPower and isHealer)
end

-- [ DEBUFF DISPLAY ]--------------------------------------------------------------------------------

local function UpdateDebuffs(frame, plugin)
    if not frame.debuffContainer then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("Debuffs") then frame.debuffContainer:Hide(); return end
    if not Helpers then Helpers = Orbit.RaidFrameHelpers end

    local componentPositions = plugin:GetSetting(1, "ComponentPositions") or {}
    local debuffData = componentPositions.Debuffs or {}
    local debuffOverrides = debuffData.overrides or {}
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()
    local maxDebuffs = debuffOverrides.MaxIcons or 3

    local unit = frame.unit
    if not unit or not UnitExists(unit) then frame.debuffContainer:Hide(); return end

    if not frame.debuffPool then frame.debuffPool = CreateFramePool("Button", frame.debuffContainer, "BackdropTemplate") end
    frame.debuffPool:ReleaseAll()

    local allDebuffs = plugin:FetchAuras(unit, "HARMFUL", 40)
    local excludeCC = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("CrowdControlIcon"))
    local debuffs = {}
    for _, aura in ipairs(allDebuffs) do
        local dominated = excludeCC and aura.auraInstanceID and IsAuraIncluded(unit, aura.auraInstanceID, "HARMFUL|CROWD_CONTROL")
        if not dominated then
            debuffs[#debuffs + 1] = aura
            if #debuffs >= maxDebuffs then break end
        end
    end

    if #debuffs == 0 then frame.debuffContainer:Hide(); return end

    local position = Helpers:AnchorToPosition(debuffData.posX, debuffData.posY, frameWidth / 2, frameHeight / 2)
    local iconSize, rows, iconsPerRow, containerWidth, containerHeight = CalculateSmartAuraLayout(frameWidth, frameHeight, position, maxDebuffs, #debuffs, debuffOverrides)

    frame.debuffContainer:ClearAllPoints()
    frame.debuffContainer:SetSize(containerWidth, containerHeight)

    local anchorX = debuffData.anchorX or "RIGHT"
    local anchorY = debuffData.anchorY or "CENTER"
    local offsetX = debuffData.offsetX or 0
    local offsetY = debuffData.offsetY or 0
    local justifyH = debuffData.justifyH or "LEFT"

    local anchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)
    local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(false, true, anchorY, justifyH)

    local finalX = offsetX
    local finalY = offsetY
    if anchorX == "RIGHT" then finalX = -offsetX end
    if anchorY == "TOP" then finalY = -offsetY end
    frame.debuffContainer:SetPoint(selfAnchor, frame, anchorPoint, finalX, finalY)

    local globalBorder = Orbit.db.GlobalSettings.BorderSize
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = true }

    local col, row = 0, 0
    for _, aura in ipairs(debuffs) do
        local icon = frame.debuffPool:Acquire()
        plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
        plugin:SetupAuraTooltip(icon, aura, unit, "HARMFUL")
        col, row = PositionAuraIcon(icon, frame.debuffContainer, justifyH, anchorY, col, row, iconSize, iconsPerRow)
    end
    frame.debuffContainer:Show()
end

-- [ BUFF DISPLAY ]----------------------------------------------------------------------------------

local function UpdateBuffs(frame, plugin)
    if not frame.buffContainer then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("Buffs") then frame.buffContainer:Hide(); return end
    if not Helpers then Helpers = Orbit.RaidFrameHelpers end

    local componentPositions = plugin:GetSetting(1, "ComponentPositions") or {}
    local buffData = componentPositions.Buffs or {}
    local buffOverrides = buffData.overrides or {}
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()
    local maxBuffs = buffOverrides.MaxIcons or 3

    local unit = frame.unit
    if not unit or not UnitExists(unit) then frame.buffContainer:Hide(); return end

    if not frame.buffPool then frame.buffPool = CreateFramePool("Button", frame.buffContainer, "BackdropTemplate") end
    frame.buffPool:ReleaseAll()

    local allBuffs = plugin:FetchAuras(unit, "HELPFUL|PLAYER", 40)
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
                buffs[#buffs + 1] = aura
                if #buffs >= maxBuffs then break end
            end
        end
    end

    if #buffs == 0 then frame.buffContainer:Hide(); return end

    local position = Helpers:AnchorToPosition(buffData.posX, buffData.posY, frameWidth / 2, frameHeight / 2)
    local iconSize, rows, iconsPerRow, containerWidth, containerHeight = CalculateSmartAuraLayout(frameWidth, frameHeight, position, maxBuffs, #buffs, buffOverrides)

    frame.buffContainer:ClearAllPoints()
    frame.buffContainer:SetSize(containerWidth, containerHeight)

    local anchorX = buffData.anchorX or "LEFT"
    local anchorY = buffData.anchorY or "CENTER"
    local offsetX = buffData.offsetX or 0
    local offsetY = buffData.offsetY or 0
    local justifyH = buffData.justifyH or "RIGHT"

    local anchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)
    local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(false, true, anchorY, justifyH)

    local finalX = offsetX
    local finalY = offsetY
    if anchorX == "RIGHT" then finalX = -offsetX end
    if anchorY == "TOP" then finalY = -offsetY end
    frame.buffContainer:SetPoint(selfAnchor, frame, anchorPoint, finalX, finalY)

    local globalBorder = Orbit.db.GlobalSettings.BorderSize
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = true }

    local col, row = 0, 0
    for _, aura in ipairs(buffs) do
        local icon = frame.buffPool:Acquire()
        plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
        plugin:SetupAuraTooltip(icon, aura, unit, "HELPFUL")
        col, row = PositionAuraIcon(icon, frame.buffContainer, justifyH, anchorY, col, row, iconSize, iconsPerRow)
    end
    frame.buffContainer:Show()
end

-- [ SINGLE AURA ICON HELPERS ]----------------------------------------------------------------------

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
    if not unit or not UnitExists(unit) then
        icon:Hide()
        return
    end
    local auras = plugin:FetchAuras(unit, filter, 1)
    if #auras == 0 then
        icon:Hide()
        return
    end
    local globalBorder = Orbit.db.GlobalSettings.BorderSize
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false }
    plugin:SetupAuraIcon(icon, auras[1], iconSize, unit, skinSettings)
    local tooltipFilter = filter:find("HARMFUL") and "HARMFUL" or "HELPFUL"
    plugin:SetupAuraTooltip(icon, auras[1], unit, tooltipFilter)
    icon:Show()
end

local function UpdateDefensiveIcon(frame, plugin)
    UpdateSingleAuraIcon(frame, plugin, "DefensiveIcon", "HELPFUL|BIG_DEFENSIVE", DEFENSIVE_ICON_SIZE)
    if frame.DefensiveIcon and not frame.DefensiveIcon:IsShown() then
        UpdateSingleAuraIcon(frame, plugin, "DefensiveIcon", "HELPFUL|EXTERNAL_DEFENSIVE", DEFENSIVE_ICON_SIZE)
    end
end

local function UpdateImportantIcon(frame, plugin) UpdateSingleAuraIcon(frame, plugin, "ImportantIcon", "HARMFUL|IMPORTANT", IMPORTANT_ICON_SIZE) end

local function UpdateCrowdControlIcon(frame, plugin) UpdateSingleAuraIcon(frame, plugin, "CrowdControlIcon", "HARMFUL|CROWD_CONTROL", CROWD_CONTROL_ICON_SIZE) end

-- [ STATUS INDICATOR WRAPPERS ]---------------------------------------------------------------------

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
    if not frame or not frame.unit or frame.preview then
        frame:SetAlpha(1)
        return
    end
    local inRange = UnitInRange(frame.unit)
    frame:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(inRange, 1, OUT_OF_RANGE_ALPHA))
end

-- [ RAID FRAME CREATION ]---------------------------------------------------------------------------

local function CreateRaidFrame(index, plugin)
    local unit = "raid" .. index
    local frameName = "OrbitRaidFrame" .. index

    local frame = OrbitEngine.UnitButton:Create(plugin.container, unit, frameName)
    frame.editModeName = "Raid Frame " .. index
    frame.systemIndex = 1
    frame.raidIndex = index

    local width = plugin:GetSetting(1, "Width") or 90
    local height = plugin:GetSetting(1, "Height") or 36
    frame:SetSize(width, height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(50 + index)

    UpdateFrameLayout(frame, Orbit.db.GlobalSettings.BorderSize, plugin)

    frame.Power = plugin:CreatePowerBar(frame, unit)
    frame.debuffContainer = CreateFrame("Frame", nil, frame)
    frame.debuffContainer:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.buffContainer = CreateFrame("Frame", nil, frame)
    frame.buffContainer:SetFrameLevel(frame:GetFrameLevel() + 10)

    plugin:CreateStatusIcons(frame)
    plugin:RegisterFrameEvents(frame, unit)

    frame:SetScript("OnShow", function(self)
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

    local originalOnEvent = frame:GetScript("OnEvent")
    frame:SetScript("OnEvent", function(f, event, eventUnit, ...)
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            if eventUnit == f.unit then
                UpdatePowerBar(f, plugin)
            end
            return
        end
        if event == "UNIT_AURA" then
            if eventUnit == f.unit then
                UpdateDebuffs(f, plugin)
                UpdateBuffs(f, plugin)
                UpdateDefensiveIcon(f, plugin)
                UpdateImportantIcon(f, plugin)
                UpdateCrowdControlIcon(f, plugin)
                if plugin.UpdateDispelIndicator then
                    plugin:UpdateDispelIndicator(f, plugin)
                end
            end
            return
        end
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            UpdateBuffs(f, plugin)
            return
        end
        if event == "PLAYER_TARGET_CHANGED" then
            UpdateSelectionHighlight(f, plugin)
            return
        end
        if event == "UNIT_THREAT_SITUATION_UPDATE" then
            if eventUnit == f.unit and plugin.UpdateAggroIndicator then
                plugin:UpdateAggroIndicator(f, plugin)
            end
            return
        end
        if event == "UNIT_PHASE" or event == "UNIT_FLAGS" then
            if eventUnit == f.unit then
                UpdatePhaseIcon(f, plugin)
            end
            return
        end
        if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            UpdateReadyCheck(f, plugin)
            return
        end
        if event == "INCOMING_RESURRECT_CHANGED" then
            if eventUnit == f.unit then
                UpdateIncomingRes(f, plugin)
            end
            return
        end
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

    plugin:ConfigureFrame(frame)
    frame:Hide()
    return frame
end

-- [ HIDE NATIVE RAID FRAMES ]----------------------------------------------------------------------

local function HideNativeRaidFrames()
    if CompactRaidFrameContainer then
        OrbitEngine.NativeFrame:Hide(CompactRaidFrameContainer)
    end
    if CompactRaidFrameManager then
        OrbitEngine.NativeFrame:Hide(CompactRaidFrameManager)
    end
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------

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
    local WL = OrbitEngine.WidgetLogic
    local orientation = self:GetSetting(1, "Orientation") or 0
    local schema = { hideNativeSettings = true, controls = {} }

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Indicators" }, "Layout")

    if currentTab == "Layout" then
        table.insert(schema.controls, {
            type = "dropdown",
            key = "Orientation",
            label = "Orientation",
            default = 0,
            options = { { text = "Vertical", value = 0 }, { text = "Horizontal", value = 1 } },
            onChange = function(val)
                self:SetSetting(1, "Orientation", val)
                self:SetSetting(1, "GrowthDirection", val == 0 and "Down" or "Right")
                self:SetSetting(1, "GroupGrowthDirection", val == 0 and "Right" or "Down")
                self:ApplySettings()
                if self.frames and self.frames[1] and self.frames[1].preview then
                    self:SchedulePreviewUpdate()
                end
                if dialog.orbitTabCallback then
                    dialog.orbitTabCallback()
                end
            end,
        })
        local memberGrowthOptions = orientation == 0 and { { text = "Down", value = "Down" }, { text = "Up", value = "Up" } }
            or { { text = "Right", value = "Right" }, { text = "Left", value = "Left" } }
        table.insert(
            schema.controls,
            {
                type = "dropdown",
                key = "GrowthDirection",
                label = "Member Growth",
                default = orientation == 0 and "Down" or "Right",
                options = memberGrowthOptions,
                onChange = makeOnChange(self, "GrowthDirection"),
            }
        )
        local groupGrowthOptions = orientation == 0 and { { text = "Right", value = "Right" }, { text = "Left", value = "Left" } }
            or { { text = "Down", value = "Down" }, { text = "Up", value = "Up" } }
        table.insert(
            schema.controls,
            {
                type = "dropdown",
                key = "GroupGrowthDirection",
                label = "Group Growth",
                default = orientation == 0 and "Right" or "Down",
                options = groupGrowthOptions,
                onChange = makeOnChange(self, "GroupGrowthDirection"),
            }
        )
        table.insert(schema.controls, {
            type = "dropdown",
            key = "SortMode",
            label = "Sort Mode",
            default = "Group",
            options = { { text = "Group", value = "Group" }, { text = "Role", value = "Role" }, { text = "Alphabetical", value = "Alphabetical" } },
            onChange = function(val)
                self:SetSetting(1, "SortMode", val)
                if not InCombatLockdown() then
                    self:UpdateFrameUnits()
                end
            end,
        })
        table.insert(
            schema.controls,
            { type = "slider", key = "Width", label = "Width", min = 40, max = 200, step = 5, default = 90, onChange = makeOnChange(self, "Width") }
        )
        table.insert(
            schema.controls,
            { type = "slider", key = "Height", label = "Height", min = 16, max = 80, step = 2, default = 36, onChange = makeOnChange(self, "Height") }
        )
        table.insert(
            schema.controls,
            {
                type = "slider",
                key = "MemberSpacing",
                label = "Member Spacing",
                min = 0,
                max = 10,
                step = 1,
                default = 1,
                onChange = makeOnChange(self, "MemberSpacing"),
            }
        )
        table.insert(
            schema.controls,
            {
                type = "slider",
                key = "GroupSpacing",
                label = "Group Spacing",
                min = 0,
                max = 30,
                step = 1,
                default = 4,
                onChange = makeOnChange(self, "GroupSpacing"),
            }
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
        table.insert(
            schema.controls,
            { type = "checkbox", key = "ShowPowerBar", label = "Show Healer Power Bars", default = true, onChange = makeOnChange(self, "ShowPowerBar") }
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

-- [ ON LOAD ]---------------------------------------------------------------------------------------

function Plugin:OnLoad()
    if not Helpers then
        Helpers = Orbit.RaidFrameHelpers
    end

    self.container = CreateFrame("Frame", "OrbitRaidFrameContainer", UIParent, "SecureHandlerStateTemplate")
    self.container.editModeName = "Raid Frames"
    self.container.systemIndex = 1
    self.container:SetFrameStrata("MEDIUM")
    self.container:SetFrameLevel(49)
    self.container:SetClampedToScreen(true)

    self.frames = {}
    for i = 1, MAX_RAID_FRAMES do
        self.frames[i] = CreateRaidFrame(i, self)
        self.frames[i]:SetParent(self.container)
        self.frames[i].orbitPlugin = self
        self.frames[i]:Hide()
    end

    HideNativeRaidFrames()

    -- Canvas Mode: use first raid frame for component editing
    local pluginRef = self
    local firstFrame = self.frames[1]
    if firstFrame and OrbitEngine.ComponentDrag then
        local textComponents = { "Name", "HealthText" }
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
                onPositionChange = function(comp, anchorX, anchorY, offsetX, offsetY, justifyH)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    if not positions[key] then positions[key] = {} end
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

    self.frame = self.container
    self.frame.anchorOptions = { horizontal = true, vertical = false }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, 1)

    self.container.orbitCanvasFrame = self.frames[1]
    self.container.orbitCanvasTitle = "Raid Frame"

    if not self.container:GetPoint() then
        self.container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -300)
    end

    -- Visibility driver: show only in raid
    local function UpdateVisibilityDriver()
        if InCombatLockdown() then
            return
        end
        RegisterStateDriver(self.container, "visibility", "[petbattle] hide; [@raid1,exists] show; hide")
    end
    self.UpdateVisibilityDriver = function() UpdateVisibilityDriver() end
    UpdateVisibilityDriver()
    self.container:Show()

    self.container:SetSize(self:GetSetting(1, "Width") or 90, 100)

    self:PositionFrames()
    self:ApplySettings()
    self:UpdateFrameUnits()

    -- Global event frame
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
            if not InCombatLockdown() then
                self:UpdateFrameUnits()
            end
            for _, frame in ipairs(self.frames) do
                if frame.unit and frame.UpdateAll then
                    frame:UpdateAll()
                    UpdatePowerBar(frame, self)
                end
            end
        end
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
                RegisterStateDriver(self.container, "visibility", "[petbattle] hide; [@raid1,exists] show; hide")
            end
        end, self)
    end

    -- Canvas Mode dialog hook
    local dialog = OrbitEngine.CanvasModeDialog or Orbit.CanvasModeDialog
    if dialog and not self.canvasModeHooked then
        self.canvasModeHooked = true
        local originalOpen = dialog.Open
        dialog.Open = function(dlg, frame, plugin, systemIndex)
            if frame == self.container or frame == self.frames[1] then
                self:PrepareIconsForCanvasMode()
            end
            return originalOpen(dlg, frame, plugin, systemIndex)
        end
    end
end

-- [ PREPARE ICONS FOR CANVAS MODE ]-----------------------------------------------------------------

function Plugin:PrepareIconsForCanvasMode()
    local frame = self.frames[1]
    if not frame then
        return
    end
    local previewAtlases = Orbit.IconPreviewAtlases

    for _, key in ipairs({ "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }) do
        if frame[key] then
            frame[key]:SetAtlas(previewAtlases[key])
            frame[key]:SetSize(18, 18)
        end
    end
    if frame.RoleIcon then
        if not frame.RoleIcon:GetAtlas() then
            frame.RoleIcon:SetAtlas(previewAtlases.RoleIcon)
        end
        frame.RoleIcon:SetSize(12, 12)
    end
    if frame.LeaderIcon then
        if not frame.LeaderIcon:GetAtlas() then
            frame.LeaderIcon:SetAtlas(previewAtlases.LeaderIcon)
        end
        frame.LeaderIcon:SetSize(12, 12)
    end
    if frame.MarkerIcon then
        frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        frame.MarkerIcon.orbitSpriteIndex = 8
        frame.MarkerIcon.orbitSpriteRows = 4
        frame.MarkerIcon.orbitSpriteCols = 4
        local i = 8
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local w, h = 1 / 4, 1 / 4
        frame.MarkerIcon:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
        frame.MarkerIcon:Show()
    end

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
        Helpers = Orbit.RaidFrameHelpers
    end

    local width = self:GetSetting(1, "Width") or Helpers.LAYOUT.DefaultWidth
    local height = self:GetSetting(1, "Height") or Helpers.LAYOUT.DefaultHeight
    local memberSpacing = self:GetSetting(1, "MemberSpacing") or Helpers.LAYOUT.MemberSpacing
    local groupSpacing = self:GetSetting(1, "GroupSpacing") or Helpers.LAYOUT.GroupSpacing
    local orientation = self:GetSetting(1, "Orientation") or 0
    local memberGrowth = self:GetSetting(1, "GrowthDirection") or (orientation == 0 and "Down" or "Right")
    local groupGrowth = self:GetSetting(1, "GroupGrowthDirection") or (orientation == 0 and "Right" or "Down")

    local activeGroups = Helpers:GetActiveGroups()
    local sortMode = self:GetSetting(1, "SortMode") or "Group"

    local isPreview = self.frames[1] and self.frames[1].preview
    local previewGroups = 4
    local groupOrder = {}
    if isPreview then
        for g = 1, previewGroups do
            groupOrder[g] = g
        end
    else
        for g = 1, MAX_RAID_GROUPS do
            if activeGroups[g] then
                groupOrder[#groupOrder + 1] = g
            end
        end
    end

    local groupIndex = 0
    for _, groupNum in ipairs(groupOrder) do
        groupIndex = groupIndex + 1
        local gx, gy = Helpers:CalculateGroupPosition(groupIndex, width, height, FRAMES_PER_GROUP, memberSpacing, groupSpacing, orientation, groupGrowth)

        local memberIndex = 0
        for i = 1, MAX_RAID_FRAMES do
            local frame = self.frames[i]
            if frame and (frame:IsShown() or frame.preview) then
                local belongsToGroup
                if isPreview then
                    belongsToGroup = math.ceil(i / FRAMES_PER_GROUP) == groupNum
                else
                    local _, _, subgroup = GetRaidRosterInfo(i)
                    belongsToGroup = (subgroup == groupNum)
                end
                if sortMode ~= "Group" then
                    belongsToGroup = true
                end

                if belongsToGroup then
                    memberIndex = memberIndex + 1
                    local mx, my = Helpers:CalculateMemberPosition(memberIndex, width, height, memberSpacing, orientation, memberGrowth)
                    frame:ClearAllPoints()
                    frame:SetPoint("TOPLEFT", self.container, "TOPLEFT", gx + mx, gy + my)
                end
            end
        end

        if sortMode ~= "Group" then
            break
        end
    end

    self:UpdateContainerSize()
end

function Plugin:UpdateContainerSize()
    if InCombatLockdown() then
        return
    end
    if not Helpers then
        Helpers = Orbit.RaidFrameHelpers
    end

    local width = self:GetSetting(1, "Width") or Helpers.LAYOUT.DefaultWidth
    local height = self:GetSetting(1, "Height") or Helpers.LAYOUT.DefaultHeight
    local memberSpacing = self:GetSetting(1, "MemberSpacing") or Helpers.LAYOUT.MemberSpacing
    local groupSpacing = self:GetSetting(1, "GroupSpacing") or Helpers.LAYOUT.GroupSpacing
    local orientation = self:GetSetting(1, "Orientation") or 0

    local isPreview = self.frames[1] and self.frames[1].preview
    local numGroups = 0
    if isPreview then
        numGroups = 4
    else
        local activeGroups = Helpers:GetActiveGroups()
        for _ in pairs(activeGroups) do
            numGroups = numGroups + 1
        end
        numGroups = math.max(1, numGroups)
    end

    local containerW, containerH = Helpers:CalculateContainerSize(numGroups, FRAMES_PER_GROUP, width, height, memberSpacing, groupSpacing, orientation)
    self.container:SetSize(containerW, containerH)
end

-- [ DYNAMIC UNIT ASSIGNMENT ]----------------------------------------------------------------------

function Plugin:UpdateFrameUnits()
    if InCombatLockdown() then
        return
    end
    if self.frames and self.frames[1] and self.frames[1].preview then
        return
    end
    if not Helpers then
        Helpers = Orbit.RaidFrameHelpers
    end

    local sortMode = self:GetSetting(1, "SortMode") or "Group"
    local sortedUnits = Helpers:GetSortedRaidUnits(sortMode)

    for i = 1, MAX_RAID_FRAMES do
        local frame = self.frames[i]
        if frame then
            local unitData = sortedUnits[i]
            if unitData then
                local token = unitData.token
                local currentUnit = frame:GetAttribute("unit")
                if currentUnit ~= token then
                    frame:SetAttribute("unit", token)
                    frame.unit = token

                    local unitEvents = {
                        "UNIT_POWER_UPDATE",
                        "UNIT_MAXPOWER",
                        "UNIT_DISPLAYPOWER",
                        "UNIT_POWER_FREQUENT",
                        "UNIT_AURA",
                        "UNIT_THREAT_SITUATION_UPDATE",
                        "UNIT_PHASE",
                        "UNIT_FLAGS",
                        "INCOMING_RESURRECT_CHANGED",
                        "UNIT_IN_RANGE_UPDATE",
                    }
                    for _, event in ipairs(unitEvents) do
                        frame:UnregisterEvent(event)
                    end
                    for _, event in ipairs(unitEvents) do
                        frame:RegisterUnitEvent(event, token)
                    end
                end

                SafeUnregisterUnitWatch(frame)
                SafeRegisterUnitWatch(frame)
                frame:Show()
                if frame.UpdateAll then
                    frame:UpdateAll()
                end
            else
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
    local width = self:GetSetting(1, "Width") or 90
    local height = self:GetSetting(1, "Height") or 36
    for _, raidFrame in ipairs(self.frames) do
        raidFrame:SetSize(width, height)
        UpdateFrameLayout(raidFrame, self:GetSetting(1, "BorderSize"), self)
    end
    self:PositionFrames()
end

function Plugin:ApplySettings()
    if not self.frames then
        return
    end

    local width = self:GetSetting(1, "Width") or 90
    local height = self:GetSetting(1, "Height") or 36
    local healthTextMode = self:GetSetting(1, "HealthTextMode") or "percent_short"
    local borderSize = self:GetSetting(1, "BorderSize") or 1
    local textureName = self:GetSetting(1, "Texture")
    local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"

    for _, frame in ipairs(self.frames) do
        if not frame.preview and frame.unit then
            Orbit:SafeAction(function() frame:SetSize(width, height) end)
            if frame.Health then
                frame.Health:SetStatusBarTexture(texturePath)
            end
            if frame.Power then
                frame.Power:SetStatusBarTexture(texturePath)
            end
            if frame.SetBorder then
                frame:SetBorder(borderSize)
            end
            UpdateFrameLayout(frame, borderSize, self)
            if frame.SetHealthTextMode then
                frame:SetHealthTextMode(healthTextMode)
            end
            if frame.SetClassColour then
                frame:SetClassColour(true)
            end
            self:ApplyTextStyling(frame)
            UpdatePowerBar(frame, self)
            UpdateDebuffs(frame, self)
            UpdateBuffs(frame, self)
            UpdateDefensiveIcon(frame, self)
            UpdateImportantIcon(frame, self)
            UpdateCrowdControlIcon(frame, self)
            UpdateAllStatusIndicators(frame, self)
            if frame.UpdateAll then
                frame:UpdateAll()
            end
        end
    end

    self:PositionFrames()
    OrbitEngine.Frame:RestorePosition(self.container, self, 1)

    local savedPositions = self:GetSetting(1, "ComponentPositions")
    if savedPositions then
        if OrbitEngine.ComponentDrag then
            OrbitEngine.ComponentDrag:RestoreFramePositions(self.container, savedPositions)
        end
        for _, frame in ipairs(self.frames) do
            if frame.ApplyComponentPositions then
                frame:ApplyComponentPositions(savedPositions)
            end
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
                    local finalX = pos.offsetX or 0
                    local finalY = pos.offsetY or 0
                    if anchorX == "RIGHT" then
                        finalX = -finalX
                    end
                    if anchorY == "TOP" then
                        finalY = -finalY
                    end
                    frame[iconKey]:ClearAllPoints()
                    frame[iconKey]:SetPoint("CENTER", frame, anchorPoint, finalX, finalY)
                end
            end
        end
    end

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
