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

local CROWD_CONTROL_ICON_SIZE = 18
local PRIVATE_AURA_ICON_SIZE = 18
local MAX_PRIVATE_AURA_ANCHORS = 3
local AURA_BASE_ICON_SIZE = 10
local OUT_OF_RANGE_ALPHA = 0.2
local OFFLINE_ALPHA = 0.35
local UNIT_REREGISTER_EVENTS = {
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_FREQUENT",
    "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PHASE", "UNIT_FLAGS",
    "INCOMING_RESURRECT_CHANGED", "UNIT_IN_RANGE_UPDATE", "UNIT_CONNECTION",
}

local _pendingPrivateAuraReanchor = false

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_RaidFrames"

local Plugin = Orbit:RegisterPlugin("Raid Frames", SYSTEM_ID, {
    defaults = {
        Width = 100,
        Height = 40,
        Scale = 100,
        MemberSpacing = 2,
        GroupSpacing = 2,
        GroupsPerRow = 6,
        GrowthDirection = "Down",
        SortMode = "Group",
        Orientation = "Horizontal",
        FlatRows = 1,
        ShowPowerBar = true,
        ShowGroupLabels = true,
        ShowHealthValue = true,
        HealthTextMode = "percent_short",

        ComponentPositions = {
            Name = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 10, justifyH = "CENTER", posX = 0, posY = 10 },
            HealthText = { anchorX = "RIGHT", offsetX = 3, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            Status = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = -1, justifyH = "CENTER", posX = 0, posY = 21 },
            RoleIcon = { anchorX = "RIGHT", offsetX = 2, anchorY = "TOP", offsetY = 2, justifyH = "RIGHT", posX = 48, posY = 18, overrides = { Scale = 0.7 } },
            LeaderIcon = { anchorX = "LEFT", offsetX = 8, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", posX = -42, posY = 20, overrides = { Scale = 0.8 } },
            MainTankIcon = { anchorX = "LEFT", offsetX = 20, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", posX = -30, posY = 20, overrides = { Scale = 0.8 } },
            SummonIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            PhaseIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            ResIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            ReadyCheckIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            DefensiveIcon = { anchorX = "LEFT", offsetX = 2, anchorY = "CENTER", offsetY = 0 },

            CrowdControlIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2 },
            PrivateAuraAnchor = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 2 },
            Buffs = {
                anchorX = "RIGHT",
                anchorY = "BOTTOM",
                offsetX = 2,
                offsetY = 1,
                posX = 30,
                posY = -15,
                overrides = { MaxIcons = 4, IconSize = 10, MaxRows = 1 },
            },
            Debuffs = {
                anchorX = "LEFT",
                anchorY = "BOTTOM",
                offsetX = 1,
                offsetY = 1,
                posX = -35,
                posY = -15,
                overrides = { MaxIcons = 2, IconSize = 10, MaxRows = 1 },
            },
        },
        DisabledComponents = { "DefensiveIcon", "CrowdControlIcon", "HealthText" },
        DisabledComponentsMigrated = true,
        AggroIndicatorEnabled = true,
        AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        AggroThickness = 1,
        DispelIndicatorEnabled = true,
        DispelThickness = 2,
        DispelFrequency = 0.2,
        DispelNumLines = 8,
        DispelColorMagic = { r = 0.2, g = 0.6, b = 1.0, a = 1 },
        DispelColorCurse = { r = 0.6, g = 0.0, b = 1.0, a = 1 },
        DispelColorDisease = { r = 0.6, g = 0.4, b = 0.0, a = 1 },
        DispelColorPoison = { r = 0.0, g = 0.6, b = 0.0, a = 1 },
    },
})

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

-- [ POWER BAR UPDATE ]------------------------------------------------------------------------------

local function UpdatePowerBar(frame, plugin)
    if not frame.Power or not frame.unit or not UnitExists(frame.unit) then return end
    local showHealerPower = plugin:GetSetting(1, "ShowPowerBar")
    local isHealer = UnitGroupRolesAssigned(frame.unit) == "HEALER"
    if not isHealer or showHealerPower == false then frame.Power:Hide(); return end
    frame.Power:Show()
    local power, maxPower, powerType = UnitPower(frame.unit), UnitPowerMax(frame.unit), UnitPowerType(frame.unit)
    frame.Power:SetMinMaxValues(0, maxPower)
    frame.Power:SetValue(power)
    local color = Orbit.Constants.Colors:GetPowerColor(powerType)
    frame.Power:SetStatusBarColor(color.r, color.g, color.b)
end

local function UpdateFrameLayout(frame, borderSize, plugin)
    if not Helpers then Helpers = Orbit.RaidFrameHelpers end
    local showHealerPower = plugin and plugin:GetSetting(1, "ShowPowerBar")
    if showHealerPower == nil then showHealerPower = true end
    local isHealer = frame.unit and UnitGroupRolesAssigned(frame.unit) == "HEALER"
    Helpers:UpdateFrameLayout(frame, borderSize, showHealerPower and isHealer)
end

-- [ AURA DISPLAY CONFIG ]--------------------------------------------------------------------------

local function RaidDebuffPostFilter(plugin, unit, rawAuras, maxCount)
    local inCombat = UnitAffectingCombat("player")
    local raidFilter = inCombat and "HARMFUL|RAID_IN_COMBAT" or "HARMFUL"
    local excludeCC = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("CrowdControlIcon"))
    local result = {}
    for _, aura in ipairs(rawAuras) do
        if aura.auraInstanceID then
            local passesRaid = plugin:IsAuraIncluded(unit, aura.auraInstanceID, raidFilter)
            local passesCC = not excludeCC and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HARMFUL|CROWD_CONTROL")
            local dominated = excludeCC and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HARMFUL|CROWD_CONTROL")
            if (passesRaid or passesCC) and not dominated then
                result[#result + 1] = aura
                if #result >= maxCount then break end
            end
        end
    end
    return result
end

local function RaidBuffPostFilter(plugin, unit, rawAuras, maxCount)
    local inCombat = UnitAffectingCombat("player")
    local raidFilter = inCombat and "HELPFUL|PLAYER|RAID_IN_COMBAT" or "HELPFUL|PLAYER|RAID"
    local excludeDefensives = not (plugin.IsComponentDisabled and plugin:IsComponentDisabled("DefensiveIcon"))
    local result = {}
    for _, aura in ipairs(rawAuras) do
        if aura.auraInstanceID then
            local passesRaid = plugin:IsAuraIncluded(unit, aura.auraInstanceID, raidFilter)
            local passesDef = not excludeDefensives and (plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|BIG_DEFENSIVE") or plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE"))
            local isBigDef = excludeDefensives and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|BIG_DEFENSIVE")
            local isExtDef = excludeDefensives and plugin:IsAuraIncluded(unit, aura.auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
            if (passesRaid or passesDef) and not isBigDef and not isExtDef then
                result[#result + 1] = aura
                if #result >= maxCount then break end
            end
        end
    end
    return result
end

local RAID_SKIN = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = true }

local RAID_DEBUFF_CFG = {
    componentKey = "Debuffs", fetchFilter = "HARMFUL", fetchMax = 40,
    postFilter = RaidDebuffPostFilter, tooltipFilter = "HARMFUL",
    skinSettings = RAID_SKIN, defaultAnchorX = "RIGHT", defaultJustifyH = "LEFT",
    helpers = function() return Orbit.RaidFrameHelpers end,
}

local RAID_BUFF_CFG = {
    componentKey = "Buffs", fetchFilter = "HELPFUL|PLAYER", fetchMax = 40,
    postFilter = RaidBuffPostFilter, tooltipFilter = "HELPFUL",
    skinSettings = RAID_SKIN, defaultAnchorX = "LEFT", defaultJustifyH = "RIGHT",
    helpers = function() return Orbit.RaidFrameHelpers end,
}

local function UpdateDebuffs(frame, plugin) plugin:UpdateAuraContainer(frame, plugin, "debuffContainer", "debuffPool", RAID_DEBUFF_CFG) end
local function UpdateBuffs(frame, plugin) plugin:UpdateAuraContainer(frame, plugin, "buffContainer", "buffPool", RAID_BUFF_CFG) end
local function UpdateDefensiveIcon(frame, plugin) plugin:UpdateDefensiveIcon(frame, plugin, DEFENSIVE_ICON_SIZE) end
local function UpdateCrowdControlIcon(frame, plugin) plugin:UpdateCrowdControlIcon(frame, plugin, CROWD_CONTROL_ICON_SIZE) end

-- [ PRIVATE AURA ANCHOR ]---------------------------------------------------------------------------

local function RemovePrivateAuraAnchors(frame)
    if not frame._privateAuraIDs then return end
    for _, id in ipairs(frame._privateAuraIDs) do C_UnitAuras.RemovePrivateAuraAnchor(id) end
    wipe(frame._privateAuraIDs)
end

local function CreatePrivateAuraAnchors(frame, plugin)
    local anchor = frame.PrivateAuraAnchor
    local unit = frame.unit
    RemovePrivateAuraAnchors(frame)
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

local function ReanchorPrivateAuras(frame, plugin)
    if not frame._privateAuraIDs or #frame._privateAuraIDs == 0 then return end
    if frame._privateAuraUnit == frame.unit then return end
    CreatePrivateAuraAnchors(frame, plugin)
end

local function SchedulePrivateAuraReanchor(plugin)
    if _pendingPrivateAuraReanchor then return end
    _pendingPrivateAuraReanchor = true
    C_Timer.After(0, function()
        _pendingPrivateAuraReanchor = false
        if not plugin.frames then return end
        for _, frame in ipairs(plugin.frames) do
            if frame.unit and frame:IsShown() then ReanchorPrivateAuras(frame, plugin) end
        end
    end)
end

local function UpdatePrivateAuras(frame, plugin)
    local anchor = frame.PrivateAuraAnchor
    if not anchor then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("PrivateAuraAnchor") then
        anchor:Hide()
        return
    end

    if anchor.Icon then anchor.Icon:SetTexture(nil) end
    if anchor.SetBackdrop then anchor:SetBackdrop(nil) end
    if anchor.Border then anchor.Border:Hide() end
    if anchor.Shadow then anchor.Shadow:Hide() end

    local unit = frame.unit
    if not unit or not UnitExists(unit) then anchor:Hide() return end

    if not frame._privateAuraIDs or frame._privateAuraUnit ~= unit then
        CreatePrivateAuraAnchors(frame, plugin)
    end

    anchor:Show()
end

-- [ STATUS INDICATOR DISPATCH ]---------------------------------------------------------------------

local function StatusDispatch(frame, plugin, method)
    plugin[method](plugin, frame, plugin)
end

-- [ RANGE CHECKING ]--------------------------------------------------------------------------------

local function UpdateInRange(frame)
    if not frame or not frame.unit or frame.preview then
        frame:SetAlpha(1)
        return
    end
    if not UnitIsConnected(frame.unit) then frame:SetAlpha(OFFLINE_ALPHA); return end
    if UnitPhaseReason(frame.unit) then frame:SetAlpha(OUT_OF_RANGE_ALPHA); return end
    frame:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(UnitInRange(frame.unit), 1, OUT_OF_RANGE_ALPHA))
end

-- [ RAID FRAME CREATION ]---------------------------------------------------------------------------

local function CreateRaidFrame(index, plugin)
    local unit = "raid" .. index
    local frameName = "OrbitRaidFrame" .. index

    local frame = OrbitEngine.UnitButton:Create(plugin.container, unit, frameName)
    if frame.NameFrame then frame.NameFrame:SetIgnoreParentAlpha(true) end
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

        UpdateCrowdControlIcon(self, plugin)
        UpdatePrivateAuras(self, plugin)
        StatusDispatch(self, plugin, "UpdateAllPartyStatusIcons")
        StatusDispatch(self, plugin, "UpdateStatusText")
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

                UpdateCrowdControlIcon(f, plugin)
                UpdatePrivateAuras(f, plugin)
                if plugin.UpdateDispelIndicator then
                    plugin:UpdateDispelIndicator(f, plugin)
                end
            end
            return
        end
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            UpdateDebuffs(f, plugin)
            UpdateBuffs(f, plugin)
            return
        end
        if event == "PLAYER_TARGET_CHANGED" then
            StatusDispatch(f, plugin, "UpdateSelectionHighlight")
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
        if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            StatusDispatch(f, plugin, "UpdateReadyCheck")
            return
        end
        if event == "INCOMING_RESURRECT_CHANGED" then
            if eventUnit == f.unit then
                StatusDispatch(f, plugin, "UpdateIncomingRes")
            end
            return
        end
        if event == "INCOMING_SUMMON_CHANGED" then
            StatusDispatch(f, plugin, "UpdateIncomingSummon")
            return
        end
        if event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
            StatusDispatch(f, plugin, "UpdateRoleIcon")
            StatusDispatch(f, plugin, "UpdateLeaderIcon")
            StatusDispatch(f, plugin, "UpdateMainTankIcon")
            return
        end
        if event == "RAID_TARGET_UPDATE" then
            StatusDispatch(f, plugin, "UpdateMarkerIcon")
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
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            StatusDispatch(f, plugin, "UpdateStatusText")
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
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Indicators" }, "Layout")

    if currentTab == "Layout" then
        if (self:GetSetting(1, "SortMode") or "Group") == "Group" then
            table.insert(schema.controls, {
                type = "dropdown",
                key = "Orientation",
                label = "Orientation",
                default = "Vertical",
                options = { { text = "Vertical", value = "Vertical" }, { text = "Horizontal", value = "Horizontal" } },
                onChange = makeOnChange(self, "Orientation"),
            })
        end
        table.insert(schema.controls, {
            type = "dropdown",
            key = "GrowthDirection",
            label = "Growth Direction",
            default = "Down",
            options = { { text = "Down", value = "Down" }, { text = "Up", value = "Up" } },
            onChange = makeOnChange(self, "GrowthDirection"),
        })
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
                    self:PositionFrames()
                end
                if self.frames and self.frames[1] and self.frames[1].preview then
                    self:SchedulePreviewUpdate()
                end
                C_Timer.After(0, function() OrbitEngine.Layout:Reset(dialog); self:AddSettings(dialog, systemFrame) end)
            end,
        })
        table.insert(schema.controls, { type = "slider", key = "Width", label = "Width", min = 40, max = 200, step = 1, default = 90, onChange = makeOnChange(self, "Width") })
        table.insert(schema.controls, { type = "slider", key = "Height", label = "Height", min = 16, max = 80, step = 1, default = 36, onChange = makeOnChange(self, "Height") })
        table.insert(schema.controls, { type = "slider", key = "MemberSpacing", label = "Member Spacing", min = -5, max = 50, step = 1, default = 1, onChange = makeOnChange(self, "MemberSpacing") })
        if (self:GetSetting(1, "SortMode") or "Group") == "Group" then
            table.insert(schema.controls, {
                type = "slider",
                key = "GroupsPerRow",
                label = "Groups Per Row",
                min = 1,
                max = 6,
                step = 1,
                default = 6,
                onChange = makeOnChange(self, "GroupsPerRow"),
            })
            table.insert(
                schema.controls,
                {
                    type = "slider",
                    key = "GroupSpacing",
                    label = "Group Spacing",
                    min = -5,
                    max = 50,
                    step = 1,
                    default = 4,
                    onChange = makeOnChange(self, "GroupSpacing"),
                }
            )
        else
            table.insert(schema.controls, {
                type = "slider",
                key = "FlatRows",
                label = "Rows",
                min = 1,
                max = 4,
                step = 1,
                default = 1,
                onChange = makeOnChange(self, "FlatRows"),
            })
        end
        table.insert(schema.controls, { type = "checkbox", key = "ShowPowerBar", label = "Show Healer Power Bars", default = true, onChange = makeOnChange(self, "ShowPowerBar") })
    elseif currentTab == "Indicators" then
        if (self:GetSetting(1, "SortMode") or "Group") == "Group" then
            table.insert(schema.controls, { type = "checkbox", key = "ShowGroupLabels", label = "Show Groups", default = true, onChange = makeOnChange(self, "ShowGroupLabels") })
        end
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
        local textKeyMap = {}
        local iconComponents = {
            "RoleIcon",
            "LeaderIcon",
            "MainTankIcon",
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
            local dragKey = textKeyMap[key] or key
            if element then
                OrbitEngine.ComponentDrag:Attach(element, self.container, {
                    key = dragKey,
                    onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(pluginRef, 1, dragKey),
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

    self.frame = self.container
    self.frame.anchorOptions = { horizontal = true, vertical = false }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, 1)

    self.container.orbitCanvasFrame = self.frames[1]
    self.container.orbitCanvasTitle = "Raid Frame"

    if not self.container:GetPoint() then
        self.container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -300)
    end

    -- Visibility driver: show only in raid
    local RAID_BASE_DRIVER = "[petbattle] hide; [@raid1,exists] show; hide"
    local function UpdateVisibilityDriver()
        if InCombatLockdown() or Orbit:IsEditMode() then return end
        local mv = Orbit.MountedVisibility
        local driver = (mv and mv:ShouldHide() and not IsMounted()) and "hide" or (mv and mv:GetMountedDriver(RAID_BASE_DRIVER) or RAID_BASE_DRIVER)
        RegisterStateDriver(self.container, "visibility", driver)
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
            else
                SchedulePrivateAuraReanchor(self)
            end
            for _, frame in ipairs(self.frames) do
                if frame.unit and frame.UpdateAll then
                    frame:UpdateAll()
                    UpdatePowerBar(frame, self)
                end
            end
        end
        if event == "PLAYER_REGEN_ENABLED" then
            self:UpdateFrameUnits()
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
                UpdateVisibilityDriver()
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
    if frame.MainTankIcon then
        if not frame.MainTankIcon:GetAtlas() then
            frame.MainTankIcon:SetAtlas(previewAtlases.MainTankIcon)
        end
        frame.MainTankIcon:SetSize(12, 12)
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
    local groupsPerRow = self:GetSetting(1, "GroupsPerRow") or 6
    local memberGrowth = self:GetSetting(1, "GrowthDirection") or "Down"
    self.container.orbitForceAnchorPoint = Helpers:GetContainerAnchor(memberGrowth)
    local isHorizontal = (self:GetSetting(1, "Orientation") or "Vertical") == "Horizontal"

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

    local growUp = (memberGrowth == "Up")

    if sortMode ~= "Group" then
        local flatRows = math.max(1, self:GetSetting(1, "FlatRows") or 1)
        local visibleFrames = {}
        for i = 1, MAX_RAID_FRAMES do
            local frame = self.frames[i]
            if frame and ((frame.preview) or (frame.unit and UnitExists(frame.unit))) then
                visibleFrames[#visibleFrames + 1] = frame
            end
        end
        local totalFrames = #visibleFrames
        local framesPerCol = math.ceil(totalFrames / flatRows)
        for idx, frame in ipairs(visibleFrames) do
            local col = math.floor((idx - 1) / framesPerCol)
            local row = (idx - 1) % framesPerCol
            local fx = col * (width + memberSpacing)
            local fy = row * (height + memberSpacing)
            frame:ClearAllPoints()
            if growUp then
                frame:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", fx, fy)
            else
                frame:SetPoint("TOPLEFT", self.container, "TOPLEFT", fx, -fy)
            end
        end
    else
        local groupIndex = 0
        for _, groupNum in ipairs(groupOrder) do
            groupIndex = groupIndex + 1
            local gx, gy = Helpers:CalculateGroupPosition(groupIndex, width, height, FRAMES_PER_GROUP, memberSpacing, groupSpacing, groupsPerRow, isHorizontal)

            local memberIndex = 0
            for i = 1, MAX_RAID_FRAMES do
                local frame = self.frames[i]
                if frame then
                    local belongsToGroup
                    if isPreview then
                        if frame.preview and math.ceil(i / FRAMES_PER_GROUP) == groupNum then belongsToGroup = true end
                    elseif frame.unit and UnitExists(frame.unit) then
                        local raidIndex = tonumber(frame.unit:match("(%d+)"))
                        local subgroup = raidIndex and select(3, GetRaidRosterInfo(raidIndex))
                        belongsToGroup = (subgroup == groupNum)
                    end

                    if belongsToGroup and memberIndex < FRAMES_PER_GROUP then
                        memberIndex = memberIndex + 1
                        local mx, my = Helpers:CalculateMemberPosition(memberIndex, width, height, memberSpacing, memberGrowth, isHorizontal)
                        frame:ClearAllPoints()
                        if growUp then
                            frame:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", gx + mx, -gy + my)
                        else
                            frame:SetPoint("TOPLEFT", self.container, "TOPLEFT", gx + mx, gy + my)
                        end
                    end
                end
            end
        end
    end

    self:UpdateGroupLabels(sortMode, groupOrder, width, height, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, growUp)
    self:UpdateContainerSize()
end

-- [ GROUP LABELS ]----------------------------------------------------------------------------------

local GROUP_LABEL_OFFSET = 50
local GROUP_LABEL_FONT_SIZE = 12
local GROUP_LABEL_ALPHA = 0.65
local GROUP_LABEL_PADDING = 5

function Plugin:UpdateGroupLabels(sortMode, groupOrder, width, height, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, growUp)
    if not self.groupLabels then self.groupLabels = {} end
    local showLabels = (sortMode == "Group") and self:GetSetting(1, "ShowGroupLabels")

    for i = 1, MAX_RAID_GROUPS do
        if self.groupLabels[i] then self.groupLabels[i]:Hide() end
    end
    if not showLabels then return end

    if not self.groupLabelOverlay then
        self.groupLabelOverlay = CreateFrame("Frame", nil, self.container)
        self.groupLabelOverlay:SetAllPoints()
        self.groupLabelOverlay:SetFrameLevel(self.container:GetFrameLevel() + 100)
    end

    local fontPath = (LSM and LSM:Fetch("font", Orbit.db.GlobalSettings.Font)) or STANDARD_TEXT_FONT
    for idx, groupNum in ipairs(groupOrder) do
        if not self.groupLabels[idx] then
            self.groupLabels[idx] = self.groupLabelOverlay:CreateFontString(nil, "OVERLAY")
            self.groupLabels[idx]:SetTextColor(1, 1, 1, GROUP_LABEL_ALPHA)
        end
        local label = self.groupLabels[idx]
        label:SetFont(fontPath, GROUP_LABEL_FONT_SIZE, "OUTLINE")
        label:SetText("G" .. groupNum)
        label:ClearAllPoints()

        local gx, gy = Helpers:CalculateGroupPosition(idx, width, height, FRAMES_PER_GROUP, memberSpacing, groupSpacing, groupsPerRow, isHorizontal)
        if isHorizontal then
            local rowCenter = height / 2
            if growUp then
                label:SetPoint("RIGHT", self.container, "BOTTOMLEFT", gx - GROUP_LABEL_PADDING, -gy + rowCenter)
            else
                label:SetPoint("RIGHT", self.container, "TOPLEFT", gx - GROUP_LABEL_PADDING, gy - rowCenter)
            end
        else
            local colCenter = width / 2
            if growUp then
                label:SetPoint("BOTTOM", self.container, "BOTTOMLEFT", gx + colCenter, -gy + GROUP_LABEL_PADDING)
            else
                label:SetPoint("BOTTOM", self.container, "TOPLEFT", gx + colCenter, gy + GROUP_LABEL_PADDING)
            end
        end
        label:Show()
    end
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
    local groupsPerRow = self:GetSetting(1, "GroupsPerRow") or 6

    local sortMode = self:GetSetting(1, "SortMode") or "Group"
    local isPreview = self.frames[1] and self.frames[1].preview

    if sortMode ~= "Group" then
        local flatRows = math.max(1, self:GetSetting(1, "FlatRows") or 1)
        local totalFrames = 0
        for _, frame in ipairs(self.frames) do
            if frame:IsShown() or frame.preview then totalFrames = totalFrames + 1 end
        end
        totalFrames = math.max(1, totalFrames)
        local framesPerCol = math.ceil(totalFrames / flatRows)
        local containerW = (flatRows * width) + ((flatRows - 1) * memberSpacing)
        local containerH = (framesPerCol * height) + ((framesPerCol - 1) * memberSpacing)
        self.container:SetSize(containerW, containerH)
        return
    end

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

    local isHorizontal = (self:GetSetting(1, "Orientation") or "Vertical") == "Horizontal"
    local containerW, containerH = Helpers:CalculateContainerSize(numGroups, FRAMES_PER_GROUP, width, height, memberSpacing, groupSpacing, groupsPerRow, isHorizontal)
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

                    for _, event in ipairs(UNIT_REREGISTER_EVENTS) do
                        frame:UnregisterEvent(event)
                    end
                    for _, event in ipairs(UNIT_REREGISTER_EVENTS) do
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
    local showHealthValue = self:GetSetting(1, "ShowHealthValue")
    if showHealthValue == nil then showHealthValue = true end
    local healthTextMode = self:GetSetting(1, "HealthTextMode") or "percent_short"
    local borderSize = self:GetSetting(1, "BorderSize") or (Orbit.Engine.Pixel and Orbit.Engine.Pixel:Multiple(1, UIParent:GetEffectiveScale() or 1) or 1)
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
            frame.healthTextEnabled = showHealthValue
            if frame.UpdateHealthText then frame:UpdateHealthText() end
            StatusDispatch(frame, self, "UpdateStatusText")
            if frame.SetClassColour then
                frame:SetClassColour(true)
            end
            self:ApplyTextStyling(frame)
            UpdatePowerBar(frame, self)
            UpdateDebuffs(frame, self)
            UpdateBuffs(frame, self)
            UpdateDefensiveIcon(frame, self)

            UpdateCrowdControlIcon(frame, self)
            UpdatePrivateAuras(frame, self)
            StatusDispatch(frame, self, "UpdateAllPartyStatusIcons")
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
                "MainTankIcon",
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
        if not frame.preview and frame.unit and frame.UpdateAll then
            frame:UpdateAll()
            UpdatePowerBar(frame, self)
        end
    end
end
