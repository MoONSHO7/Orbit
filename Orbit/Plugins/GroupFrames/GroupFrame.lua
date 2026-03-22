---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local Helpers = Orbit.GroupFrameHelpers
local Pixel = Orbit.Engine.Pixel

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local GF = Orbit.Constants.GroupFrames
local MAX_GROUP_FRAMES = Helpers.LAYOUT.MaxGroupFrames
local MAX_RAID_GROUPS = Helpers.LAYOUT.MaxRaidGroups
local FRAMES_PER_GROUP = Helpers.LAYOUT.FramesPerGroup
local AURA_BASE_ICON_SIZE = Helpers.LAYOUT.AuraBaseIconSize
local PARTY_DEFENSIVE_ICON_SIZE = 24
local PARTY_CC_ICON_SIZE = 24
local PARTY_PRIVATE_AURA_SIZE = 24
local PARTY_HEALER_AURA_SIZE = 16
local RAID_DEFENSIVE_ICON_SIZE = 18
local RAID_CC_ICON_SIZE = 18
local RAID_PRIVATE_AURA_SIZE = 18
local RAID_HEALER_AURA_SIZE = 12
local RAID_STATUS_ICON_SIZE = 18
local RAID_ROLE_ICON_SIZE = 12
local OUT_OF_RANGE_ALPHA = GF.OutOfRangeAlpha
local OFFLINE_ALPHA = GF.OfflineAlpha
local ROLE_PRIORITY = GF.RolePriority
local MAX_PRIVATE_AURA_ANCHORS = GF.MaxPrivateAuraAnchors
local HealerReg = Orbit.HealerAuraRegistry
local OVERLAY_LEVEL_BOOST = Orbit.Constants.Levels.Tooltip

local UNIT_REREGISTER_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_FREQUENT",
    "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PHASE", "UNIT_FLAGS",
    "UNIT_NAME_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_OTHER_PARTY_CHANGED",
    "INCOMING_RESURRECT_CHANGED", "UNIT_IN_RANGE_UPDATE", "UNIT_CONNECTION",
}

local _pendingPrivateAuraReanchor = false

-- [ TIER DEFAULTS ]---------------------------------------------------------------------------------
local TIER_DEFAULTS = {
    Party = {
        Width = 160, Height = 40, Scale = 100, Spacing = 3, Orientation = 0,
        GrowthDirection = "Down", IncludePlayer = true,
        ShowPowerBar = true, PowerBarHeight = 10,
        HealthTextMode = "percent_short", ShowHealthValue = true,
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
            Buffs = { anchorX = "LEFT", anchorY = "CENTER", offsetX = -2, offsetY = 0, posX = -110, posY = 0, overrides = { MaxIcons = 3, IconSize = 18, MaxRows = 1 } },
            Debuffs = { anchorX = "RIGHT", anchorY = "CENTER", offsetX = -2, offsetY = 0, posX = 110, posY = 0, overrides = { MaxIcons = 3, IconSize = 18, MaxRows = 1 } },
        },
        DisabledComponents = (function()
            local d = { "DefensiveIcon", "CrowdControlIcon", "RoleIcon" }
            for _, k in ipairs(Orbit.HealerAuraRegistry:AllSlotKeys()) do d[#d + 1] = k end
            return d
        end)(),
        DisabledComponentsMigrated = true,
        DispelIndicatorEnabled = true, DispelThickness = 2, DispelFrequency = 0.25, DispelNumLines = 8,
        DispelColorMagic = { r = 0.2, g = 0.6, b = 1.0, a = 1 },
        DispelColorCurse = { r = 0.6, g = 0.0, b = 1.0, a = 1 },
        DispelColorDisease = { r = 0.6, g = 0.4, b = 0.0, a = 1 },
        DispelColorPoison = { r = 0.0, g = 0.6, b = 0.0, a = 1 },
        AggroIndicatorEnabled = true, AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        SelectionColor = { r = 0.8, g = 0.9, b = 1.0, a = 1 },
        AggroThickness = 1, AggroFrequency = 0.25, AggroNumLines = 8,
    },
    Mythic = {
        Width = 100, Height = 40, Scale = 100, MemberSpacing = 2, GroupSpacing = 2,
        GroupsPerRow = 6, GrowthDirection = "Down", SortMode = "Group",
        Orientation = "Horizontal", FlatRows = 1,
        ShowPowerBar = true, PowerBarHeight = 8, ShowGroupLabels = true,
        ShowHealthValue = true, HealthTextMode = "percent_short",
        ComponentPositions = {
            Name = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 10, justifyH = "CENTER", posX = 0, posY = 10 },
            HealthText = { anchorX = "RIGHT", offsetX = 3, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
            Status = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = -1, justifyH = "CENTER", posX = 0, posY = 21 },
            RoleIcon = { anchorX = "RIGHT", offsetX = 2, anchorY = "TOP", offsetY = 2, justifyH = "RIGHT", posX = 48, posY = 18, overrides = { Scale = 0.7 } },
            LeaderIcon = { anchorX = "LEFT", offsetX = 8, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", posX = -42, posY = 20, overrides = { Scale = 0.8 } },
            MainTankIcon = { anchorX = "LEFT", offsetX = 20, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", posX = -30, posY = 20, overrides = { Scale = 0.8 } },
            StatusIcons = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            SummonIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            PhaseIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            ResIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            ReadyCheckIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            DefensiveIcon = { anchorX = "LEFT", offsetX = 2, anchorY = "CENTER", offsetY = 0 },
            CrowdControlIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2 },
            PrivateAuraAnchor = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 2 },
            Buffs = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 2, offsetY = 1, posX = 30, posY = -15, overrides = { MaxIcons = 4, IconSize = 10, MaxRows = 1 } },
            Debuffs = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 1, offsetY = 1, posX = -35, posY = -15, overrides = { MaxIcons = 2, IconSize = 10, MaxRows = 1 } },
        },
        DisabledComponents = (function()
            local d = { "DefensiveIcon", "CrowdControlIcon", "HealthText" }
            for _, k in ipairs(Orbit.HealerAuraRegistry:AllSlotKeys()) do d[#d + 1] = k end
            return d
        end)(),
        DisabledComponentsMigrated = true,
        AggroIndicatorEnabled = true, AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        SelectionColor = { r = 0.8, g = 0.9, b = 1.0, a = 1 },
        AggroThickness = 1,
        DispelIndicatorEnabled = true, DispelThickness = 2, DispelFrequency = 0.2, DispelNumLines = 8,
        DispelColorMagic = { r = 0.2, g = 0.6, b = 1.0, a = 1 },
        DispelColorCurse = { r = 0.6, g = 0.0, b = 1.0, a = 1 },
        DispelColorDisease = { r = 0.6, g = 0.4, b = 0.0, a = 1 },
        DispelColorPoison = { r = 0.0, g = 0.6, b = 0.0, a = 1 },
    },
}
-- Heroic / World inherit from Mythic with size overrides
TIER_DEFAULTS.Heroic = setmetatable({ Width = 80, Height = 32 }, { __index = TIER_DEFAULTS.Mythic })
TIER_DEFAULTS.World = setmetatable({ Width = 72, Height = 28 }, { __index = TIER_DEFAULTS.Mythic })

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_GroupFrames"

local Plugin = Orbit:RegisterPlugin("Group Frames", SYSTEM_ID, {
    defaults = {
        Tiers = TIER_DEFAULTS,
        _EditTier = nil,
    },
})

Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.GroupFramePreviewMixin, Orbit.AuraMixin,
    Orbit.DispelIndicatorMixin, Orbit.AggroIndicatorMixin, Orbit.StatusIconMixin,
    Orbit.GroupFrameFactoryMixin)

Plugin.canvasMode = true
Plugin.supportsHealthText = true

-- [ TIER API ]--------------------------------------------------------------------------------------
function Plugin:GetCurrentTier()
    if self._editTierOverride then return self._editTierOverride end
    return self:GetRealTier()
end

function Plugin:GetRealTier()
    local numMembers = GetNumGroupMembers()
    local isInRaid = IsInRaid()
    local _, _, difficultyID, _, maxPlayers = GetInstanceInfo()
    local instanceMax = (difficultyID and difficultyID > 0) and maxPlayers or nil
    return Helpers:GetTierForGroupSize(numMembers, isInRaid, instanceMax)
end

function Plugin:IsPartyTier(tier)
    return Helpers:IsPartyTier(tier or self:GetCurrentTier())
end

function Plugin:GetTierSetting(key, tier)
    tier = tier or self:GetCurrentTier()
    local tiers = self:GetSetting(1, "Tiers")
    if tiers and tiers[tier] and tiers[tier][key] ~= nil then return tiers[tier][key] end
    local defaults = TIER_DEFAULTS[tier]
    return defaults and defaults[key]
end

function Plugin:SetTierSetting(key, value, tier)
    tier = tier or self:GetCurrentTier()
    local tiers = self:GetSetting(1, "Tiers") or {}
    if not tiers[tier] then tiers[tier] = {} end
    tiers[tier][key] = value
    self:SetSetting(1, "Tiers", tiers)
end

function Plugin:CopyTierSettings(sourceTier, destTier)
    local tiers = self:GetSetting(1, "Tiers") or {}
    local source = tiers[sourceTier] or TIER_DEFAULTS[sourceTier] or {}
    
    local existingDest = tiers[destTier] or {}
    local preservedPos = Orbit.Engine.DeepCopy and Orbit.Engine.DeepCopy(existingDest.Position) or existingDest.Position

    tiers[destTier] = {}
    for k, v in pairs(source) do
        if type(v) == "table" then
            tiers[destTier][k] = Orbit.Engine.DeepCopy and Orbit.Engine.DeepCopy(v) or v
        else
            tiers[destTier][k] = v
        end
    end

    tiers[destTier].Position = preservedPos
    self:SetSetting(1, "Tiers", tiers)
end

local PluginMixin_GetSetting = Orbit.PluginMixin.GetSetting
local PluginMixin_SetSetting = Orbit.PluginMixin.SetSetting

-- Build tier-key lookup from defaults so GetSetting/SetSetting auto-route
local TIER_KEYS = { ComponentPositions = true, DisabledComponents = true }
for _, defaults in pairs(TIER_DEFAULTS) do
    for k in pairs(defaults) do TIER_KEYS[k] = true end
end

function Plugin:GetSetting(systemIndex, key)
    if TIER_KEYS[key] then
        local txn = self._ActiveTransaction and self:_ActiveTransaction()
        if txn then
            local pending = txn:GetPending(key)
            if pending ~= nil then return pending end
        end
        local val = self:GetTierSetting(key)
        if val ~= nil then return val end
        if key == "ComponentPositions" or key == "DisabledComponents" then return {} end
        return nil
    end
    return PluginMixin_GetSetting(self, systemIndex, key)
end

function Plugin:SetSetting(systemIndex, key, val)
    if TIER_KEYS[key] then
        self:SetTierSetting(key, val)
        return
    end
    PluginMixin_SetSetting(self, systemIndex, key, val)
end

-- [ HELPERS ]---------------------------------------------------------------------------------------
local SafeRegisterUnitWatch = Orbit.GroupFrameMixin.SafeRegisterUnitWatch
local SafeUnregisterUnitWatch = Orbit.GroupFrameMixin.SafeUnregisterUnitWatch
local function GetPowerColor(powerType) return Orbit.Constants.Colors:GetPowerColor(powerType) end

local function GetDefensiveSize(plugin) return plugin:IsPartyTier() and PARTY_DEFENSIVE_ICON_SIZE or RAID_DEFENSIVE_ICON_SIZE end
local function GetCCSize(plugin) return plugin:IsPartyTier() and PARTY_CC_ICON_SIZE or RAID_CC_ICON_SIZE end
local function GetPrivateAuraSize(plugin) return plugin:IsPartyTier() and PARTY_PRIVATE_AURA_SIZE or RAID_PRIVATE_AURA_SIZE end
local function GetHealerAuraSize(plugin) return plugin:IsPartyTier() and PARTY_HEALER_AURA_SIZE or RAID_HEALER_AURA_SIZE end
local function GetComponentIconSize(plugin, key)
    local positions = plugin:GetTierSetting("ComponentPositions")
    local overrides = positions and positions[key] and positions[key].overrides
    return (overrides and overrides.IconSize) or GetHealerAuraSize(plugin)
end

-- [ POWER BAR UPDATE ]------------------------------------------------------------------------------
local function UpdatePowerBar(frame, plugin)
    if not frame.Power or not frame.unit or not UnitExists(frame.unit) then return end
    local isParty = plugin:IsPartyTier()
    local showPower = plugin:GetTierSetting("ShowPowerBar")
    local isHealer = UnitGroupRolesAssigned(frame.unit) == "HEALER"
    if isParty then
        if showPower == false and not isHealer then frame.Power:Hide(); return end
    else
        if not isHealer or showPower == false then frame.Power:Hide(); return end
    end
    frame.Power:Show()
    local power, maxPower, powerType = UnitPower(frame.unit), UnitPowerMax(frame.unit), UnitPowerType(frame.unit)
    frame.Power:SetMinMaxValues(0, maxPower)
    frame.Power:SetValue(power)
    local color = GetPowerColor(powerType)
    frame.Power:SetStatusBarColor(color.r, color.g, color.b)
end

local function UpdateFrameLayout(frame, borderSize, plugin, showPowerOverride)
    local showPower
    if showPowerOverride ~= nil then
        showPower = showPowerOverride
    else
        local showSetting = plugin and plugin:GetTierSetting("ShowPowerBar")
        if showSetting == nil then showSetting = true end
        local isHealer = frame.unit and UnitGroupRolesAssigned(frame.unit) == "HEALER"
        if plugin:IsPartyTier() then
            showPower = showSetting or isHealer
        else
            showPower = (showSetting and isHealer) or false
        end
    end
    local pct = plugin and plugin:GetTierSetting("PowerBarHeight")
    local ratio = pct and (pct / 100) or nil
    Helpers:UpdateFrameLayout(frame, borderSize, showPower, ratio)
end

-- [ AURA DISPLAY CONFIG ]--------------------------------------------------------------------------
local Filters = Orbit.GroupAuraFilters
local GroupDebuffPostFilter = Filters:CreateDebuffFilter({
    raidFilterFn = function() return UnitAffectingCombat("player") and "HARMFUL|RAID_IN_COMBAT" or "HARMFUL" end,
})
local GroupBuffPostFilter = Filters:CreateBuffFilter()
local GROUP_SKIN = Orbit.Constants.Aura.SkinWithTimer

local GROUP_DEBUFF_CFG = {
    componentKey = "Debuffs", fetchFilter = "HARMFUL", fetchMax = 40,
    postFilter = GroupDebuffPostFilter, tooltipFilter = "HARMFUL",
    skinSettings = GROUP_SKIN, defaultAnchorX = "RIGHT", defaultJustifyH = "LEFT",
    helpers = function() return Orbit.GroupFrameHelpers end,
}
local GROUP_BUFF_CFG = {
    componentKey = "Buffs", fetchFilter = "HELPFUL|PLAYER", fetchMax = 40,
    postFilter = GroupBuffPostFilter, tooltipFilter = "HELPFUL",
    skinSettings = GROUP_SKIN, defaultAnchorX = "LEFT", defaultJustifyH = "RIGHT",
    helpers = function() return Orbit.GroupFrameHelpers end,
}

local function UpdateDebuffs(frame, plugin) plugin:UpdateAuraContainer(frame, plugin, "debuffContainer", "debuffPool", GROUP_DEBUFF_CFG) end
local function UpdateBuffs(frame, plugin) plugin:UpdateAuraContainer(frame, plugin, "buffContainer", "buffPool", GROUP_BUFF_CFG) end
local function UpdateDefensiveIcon(frame, plugin) plugin:UpdateDefensiveIcon(frame, plugin, GetDefensiveSize(plugin)) end
local function UpdateCrowdControlIcon(frame, plugin) plugin:UpdateCrowdControlIcon(frame, plugin, GetCCSize(plugin)) end
local function UpdateHealerAuras(frame, plugin)
    for _, slot in ipairs(HealerReg:ActiveSlots()) do
        plugin:UpdateSpellAuraIcon(frame, plugin, slot.key, slot.spellId, GetComponentIconSize(plugin, slot.key), slot.altSpellId)
    end
end
local function UpdateMissingRaidBuffs(frame, plugin)
    plugin:UpdateMissingRaidBuffs(frame, plugin, "RaidBuff", HealerReg:ActiveRaidBuffs(), GetComponentIconSize(plugin, "RaidBuff"))
end
local function UpdatePrivateAuras(frame, plugin) Orbit.PrivateAuraMixin:Update(frame, plugin, GetPrivateAuraSize(plugin)) end

local StatusDispatch = Orbit.GroupFrameMixin.StatusDispatch
local UpdateInRange = Orbit.GroupFrameMixin.UpdateInRange

local function SchedulePrivateAuraReanchor(plugin)
    if _pendingPrivateAuraReanchor then return end
    _pendingPrivateAuraReanchor = true
    C_Timer.After(0, function()
        _pendingPrivateAuraReanchor = false
        if not plugin.frames then return end
        for _, frame in ipairs(plugin.frames) do
            if frame.unit and frame:IsShown() then UpdatePrivateAuras(frame, plugin) end
        end
    end)
end

-- [ GROUP FRAME CREATION ]--------------------------------------------------------------------------
local function CreateGroupFrame(index, plugin)
    local unit = "raid" .. index
    local frameName = "OrbitGroupFrame" .. index

    local frame = OrbitEngine.UnitButton:Create(plugin.container, unit, frameName, true)
    if frame.NameFrame then frame.NameFrame:SetIgnoreParentAlpha(true) end
    frame.editModeName = "Group Frame " .. index
    frame.systemIndex = 1
    frame.groupIndex = index

    local width = plugin:GetTierSetting("Width") or 100
    local height = plugin:GetTierSetting("Height") or 40
    frame:SetSize(width, height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(Orbit.Constants.Levels.GroupBase + index)

    UpdateFrameLayout(frame, Orbit.db.GlobalSettings.BorderSize, plugin)

    frame.Power = plugin:CreatePowerBar(frame, unit)
    frame.debuffContainer = CreateFrame("Frame", nil, frame)
    frame.debuffContainer:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
    frame.buffContainer = CreateFrame("Frame", nil, frame)
    frame.buffContainer:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)

    plugin:CreateStatusIcons(frame, plugin:IsPartyTier())

    local eventCallbacks = {
        UpdatePowerBar = UpdatePowerBar, UpdateDebuffs = UpdateDebuffs, UpdateBuffs = UpdateBuffs,
        UpdateDefensiveIcon = UpdateDefensiveIcon, UpdateCrowdControlIcon = UpdateCrowdControlIcon,
        UpdatePrivateAuras = UpdatePrivateAuras, UpdateFrameLayout = UpdateFrameLayout,
        UpdateHealerAuras = UpdateHealerAuras, UpdateMissingRaidBuffs = UpdateMissingRaidBuffs,
        UpdateMainTankIcon = true,
    }
    local originalOnEvent = frame:GetScript("OnEvent")
    frame:SetScript("OnShow", Orbit.GroupFrameMixin.CreateOnShowHandler(plugin, eventCallbacks))
    frame:SetScript("OnEvent", Orbit.GroupFrameMixin.CreateEventHandler(plugin, eventCallbacks, originalOnEvent))

    plugin:ConfigureFrame(frame)
    frame:Hide()
    return frame
end

-- [ HIDE NATIVE FRAMES ]----------------------------------------------------------------------------
local function HideNativeGroupFrames()
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
    OrbitEngine.NativeFrame:Disable(CompactRaidFrameContainer)
    OrbitEngine.NativeFrame:Disable(CompactRaidFrameManager)
end

function Plugin:AddSettings(dialog, systemFrame)
    Orbit.GroupFrameSettings(self, dialog, systemFrame)
end

-- TODO(REMOVE): Migrates legacy PartyFrames/RaidFrames settings into GroupFrames tiers
-- [ MIGRATION ]-------------------------------------------------------------------------------------
local function MigrateFromLegacy(plugin)
    local db = Orbit.db
    if not db or not db.Layouts then return end
    local layoutName = "Orbit"
    if Orbit.Profile and Orbit.Profile.GetCurrentLayout then layoutName = Orbit.Profile:GetCurrentLayout() or layoutName end
    local layout = db.Layouts[layoutName]
    if not layout then return end

    local partyData = layout["Orbit_PartyFrames"] and layout["Orbit_PartyFrames"][1]
    local raidData = layout["Orbit_RaidFrames"] and layout["Orbit_RaidFrames"][1]
    local groupData = layout["Orbit_GroupFrames"] and layout["Orbit_GroupFrames"][1]

    -- Skip if already migrated or no legacy data
    if groupData and groupData._migrated then return end
    if not partyData and not raidData then return end

    local tiers = plugin:GetSetting(1, "Tiers") or {}

    -- Migrate party settings
    if partyData then
        tiers.Party = tiers.Party or {}
        for k, v in pairs(partyData) do
            if k ~= "Position" and k ~= "Anchor" then tiers.Party[k] = v end
        end
    end

    -- Migrate raid settings to all raid tiers
    if raidData then
        local LEGACY_TIER_MAP = { SmallRaid = "Mythic", MediumRaid = "Mythic", LargeRaid = "Heroic", MassiveRaid = "World" }
        for _, tierKey in ipairs({ "Mythic", "Heroic", "World" }) do
            tiers[tierKey] = tiers[tierKey] or {}
            for k, v in pairs(raidData) do
                if k ~= "Position" and k ~= "Anchor" then tiers[tierKey][k] = v end
            end
        end
        -- Migrate any saved old tier keys forward
        for oldKey, newKey in pairs(LEGACY_TIER_MAP) do
            if tiers[oldKey] then
                for k, v in pairs(tiers[oldKey]) do
                    if tiers[newKey][k] == nil then tiers[newKey][k] = v end
                end
                tiers[oldKey] = nil
            end
        end
    end

    plugin:SetSetting(1, "Tiers", tiers)
    plugin:SetSetting(1, "_migrated", true)
end

-- [ ON LOAD ]---------------------------------------------------------------------------------------
function Plugin:OnLoad()
    MigrateFromLegacy(self)

    HideNativeGroupFrames()

    self._currentTier = self:GetCurrentTier()

    self.container = CreateFrame("Frame", "OrbitGroupFrameContainer", UIParent, "SecureHandlerStateTemplate")
    self.container.editModeName = "Group Frames"
    self.container.systemIndex = 1
    self.container:SetFrameStrata("MEDIUM")
    self.container:SetFrameLevel(Orbit.Constants.Levels.GroupContainer)
    self.container:SetClampedToScreen(true)

    self.frames = {}
    for i = 1, MAX_GROUP_FRAMES do
        self.frames[i] = CreateGroupFrame(i, self)
        self.frames[i]:SetParent(self.container)
        self.frames[i].orbitPlugin = self
        self.frames[i]:Hide()
    end

    -- Canvas Mode registration
    local firstFrame = self.frames[1]
    for _, k in ipairs(HealerReg:ActiveKeys()) do
        if k == "RaidBuff" then
            local raidBuffs = HealerReg:ActiveRaidBuffs()
            if #raidBuffs > 0 then self:EnsureRaidBuffContainer(firstFrame, k, raidBuffs, GetComponentIconSize(self, k)) end
        else
            self:EnsureAuraIcon(firstFrame, k, GetComponentIconSize(self, k))
        end
    end
    local iconKeys = { "RoleIcon", "LeaderIcon", "MainTankIcon", "MarkerIcon", "DefensiveIcon", "CrowdControlIcon", "PrivateAuraAnchor" }
    for _, k in ipairs(HealerReg:ActiveKeys()) do iconKeys[#iconKeys + 1] = k end
    Orbit.GroupCanvasRegistration:RegisterComponents(self, self.container, firstFrame,
        { "Name", "HealthText" }, iconKeys, AURA_BASE_ICON_SIZE)

    self.frame = self.container
    self.frame.anchorOptions = { horizontal = true, vertical = false }
    self.frame.orbitResizeBounds = { minW = 50, maxW = 400, minH = 20, maxH = 100 }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, 1)

    self.container.orbitCanvasFrame = self.frames[1]
    self.container.orbitCanvasTitle = "Group Frame: " .. self:GetCurrentTier()

    if not self.container:GetPoint() then
        self.container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", GF.DefaultPartyOffsetX or 100, GF.DefaultPartyOffsetY or -120)
    end

    -- Visibility driver: unified — show when in any group
    local function UpdateVisibilityDriver()
        if InCombatLockdown() or Orbit:IsEditMode() then return end
        local _, instanceType = IsInInstance()
        local driver
        if instanceType == "arena" then
            driver = "[petbattle] hide; show"
        elseif instanceType == "pvp" then
            driver = "[petbattle] hide; show"
        else
            driver = "[petbattle] hide; [@party1,exists] show; hide"
        end
        RegisterStateDriver(self.container, "visibility", driver)
    end
    self.UpdateVisibilityDriver = function() UpdateVisibilityDriver() end
    UpdateVisibilityDriver()
    self.mountedConfig = { frame = self.container, hoverReveal = true, combatRestore = true }

    self.container:Show()
    self.container:SetSize(self:GetTierSetting("Width") or 100, 100)

    self:PositionFrames()
    self:ApplySettings()
    self:UpdateFrameUnits()

    -- Global event frame
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.5, function() UpdateVisibilityDriver(); self:CheckTierChange(); self:UpdateFrameUnits() end)
            return
        end
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
            UpdateVisibilityDriver()
            self:CheckTierChange()
            if not InCombatLockdown() then self:UpdateFrameUnits() else SchedulePrivateAuraReanchor(self) end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            UpdateVisibilityDriver()
            self:CheckTierChange()
            self:UpdateFrameUnits()
            return
        end
        if event == "ZONE_CHANGED_NEW_AREA" then
            C_Timer.After(0.5, function()
                UpdateVisibilityDriver()
                self:CheckTierChange()
                if not InCombatLockdown() then self:UpdateFrameUnits() end
            end)
        end
    end)

    self.skipEditModeApply = true
    self:RegisterStandardEvents()

    -- Edit Mode callbacks
    if EventRegistry and not self.editModeCallbacksRegistered then
        self.editModeCallbacksRegistered = true
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            if not InCombatLockdown() then
                local activeTier = self:GetRealTier() or "Party"
                self:SetSetting(1, "_EditTier", activeTier)
                self._editTierOverride = activeTier
                self._currentTier = activeTier
                self.container.orbitCanvasTitle = "Group Frame: " .. activeTier
                self:ApplySettings()
                UnregisterStateDriver(self.container, "visibility")
                self.container:Show()
                self:ShowPreview()
            end
        end, self)
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            if not InCombatLockdown() then
                self._undoSnapshot = nil
                self:SaveCurrentTierPosition()
                self:HidePreview()
                self._currentTier = self:GetRealTier()
                self:ApplySettings()
                UpdateVisibilityDriver()
                self:UpdateFrameUnits()
            end
        end, self)
    end

    -- Canvas Mode dialog hook
    local dialog = OrbitEngine.CanvasModeDialog or Orbit.CanvasModeDialog
    if dialog and not self.canvasModeHooked then
        self.canvasModeHooked = true
        local originalOpen = dialog.Open
        dialog.Open = function(dlg, frame, pluginArg, systemIndex)
            if frame == self.container or frame == self.frames[1] then
                self:PrepareIconsForCanvasMode()
            end
            local result = originalOpen(dlg, frame, pluginArg, systemIndex)
            if frame == self.container or frame == self.frames[1] then
                self:SchedulePreviewUpdate()
            end
            return result
        end
    end
end

-- [ PER-TIER POSITION ]-----------------------------------------------------------------------------
function Plugin:SaveCurrentTierPosition(tier)
    tier = tier or self:GetCurrentTier()
    if not self.container or not tier then return end
    local point, _, _, x, y = self.container:GetPoint()
    if not point then return end
    local pm = OrbitEngine.PositionManager
    if pm then
        local eph = pm:GetPosition(self.container)
        if eph and eph.point then point, x, y = eph.point, eph.x, eph.y end
    end
    self:SetTierSetting("Position", { point = point, x = x, y = y }, tier)
end

function Plugin:RestoreTierPosition(tier)
    tier = tier or self:GetCurrentTier()
    if not self.container or InCombatLockdown() then return end
    local pos = self:GetTierSetting("Position", tier)
    if not pos or not pos.point then
        pos = self:GetSetting(1, "Position")
    end
    if not pos or not pos.point then return end
    local x, y = pos.x, pos.y
    if OrbitEngine.Pixel then
        x, y = OrbitEngine.Pixel:SnapPosition(x, y, pos.point, self.container:GetWidth(), self.container:GetHeight(), self.container:GetEffectiveScale())
    end
    self.container:ClearAllPoints()
    self.container:SetPoint(pos.point, x, y)
    if OrbitEngine.PositionManager then OrbitEngine.PositionManager:ClearFrame(self.container) end
end

-- [ TIER CHANGE DETECTION ]-------------------------------------------------------------------------
function Plugin:CheckTierChange()
    local newTier = self:GetCurrentTier()
    if newTier ~= self._currentTier then
        local oldTier = self._currentTier
        self._currentTier = newTier
        self.container.orbitCanvasTitle = "Group Frame: " .. newTier
        if not InCombatLockdown() then
            self:SaveCurrentTierPosition(oldTier)
            self:UpdateFrameUnits()
            self:ApplySettings()
            self:RestoreTierPosition(newTier)
        end
    end
end

-- [ PREPARE ICONS FOR CANVAS MODE ]-----------------------------------------------------------------
function Plugin:PrepareIconsForCanvasMode()
    local frame = self.frames[1]
    if not frame then return end
    local isParty = self:IsPartyTier()
    Orbit.GroupCanvasRegistration:PrepareIcons(self, frame, {
        statusIcons = { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" },
        statusIconSize = isParty and 24 or RAID_STATUS_ICON_SIZE,
        roleIcons = isParty and { "RoleIcon", "LeaderIcon" } or { "RoleIcon", "LeaderIcon", "MainTankIcon" },
        roleIconSize = isParty and 16 or RAID_ROLE_ICON_SIZE,
        defensiveSize = GetDefensiveSize(self),
        crowdControlSize = GetCCSize(self),
        privateAuraSize = GetPrivateAuraSize(self),
        healerAuraSize = GetHealerAuraSize(self),
    }, HealerReg:ActiveSlots(), HealerReg:ActiveRaidBuffs())
end

-- [ FRAME POSITIONING ]-----------------------------------------------------------------------------
function Plugin:PositionFrames()
    if InCombatLockdown() then return end

    local isParty = self:IsPartyTier()

    if isParty then
        self:PositionPartyFrames()
    else
        self:PositionRaidFrames()
    end
    self:UpdateContainerSize()
end

function Plugin:PositionPartyFrames()
    if self.groupLabels then
        for i = 1, MAX_RAID_GROUPS do if self.groupLabels[i] then self.groupLabels[i]:Hide() end end
    end
    local spacing = self:GetTierSetting("Spacing") or 0
    local orientation = self:GetTierSetting("Orientation") or 0
    local width = self:GetTierSetting("Width") or 160
    local height = self:GetTierSetting("Height") or 40
    local growthDirection = self:GetTierSetting("GrowthDirection") or (orientation == 0 and "Down" or "Right")
    self.container.orbitForceAnchorPoint = Helpers:GetContainerAnchor(growthDirection)

    local visibleIndex = 0
    local scale = self.container:GetEffectiveScale() or 1
    for _, frame in ipairs(self.frames) do
        frame:ClearAllPoints()
        if frame:IsShown() or frame.preview then
            visibleIndex = visibleIndex + 1
            local xOffset, yOffset, frameAnchor, containerAnchor =
                Helpers:CalculatePartyFramePosition(visibleIndex, width, height, spacing, orientation, growthDirection, scale)
            frame:SetPoint(frameAnchor, self.container, containerAnchor, xOffset, yOffset)
        end
    end
end

function Plugin:PositionRaidFrames()
    local width = self:GetTierSetting("Width") or 100
    local height = self:GetTierSetting("Height") or 40
    local memberSpacing = self:GetTierSetting("MemberSpacing") or 2
    local groupSpacing = self:GetTierSetting("GroupSpacing") or 2
    local groupsPerRow = self:GetTierSetting("GroupsPerRow") or 6
    local memberGrowth = self:GetTierSetting("GrowthDirection") or "Down"
    self.container.orbitForceAnchorPoint = Helpers:GetContainerAnchor(memberGrowth)
    local isHorizontal = (self:GetTierSetting("Orientation") or "Vertical") == "Horizontal"

    local activeGroups = Helpers:GetActiveGroups()
    local sortMode = self:GetTierSetting("SortMode") or "Group"

    local isPreview = self.frames[1] and self.frames[1].preview
    local groupOrder = {}
    if isPreview then
        local tierMax = Helpers:GetTierMaxFrames(self:GetCurrentTier())
        local previewGroups = math.ceil(tierMax / FRAMES_PER_GROUP)
        for g = 1, previewGroups do groupOrder[g] = g end
    else
        for g = 1, MAX_RAID_GROUPS do
            if activeGroups[g] then groupOrder[#groupOrder + 1] = g end
        end
    end

    local growUp = (memberGrowth == "Up")
    local scale = self.container:GetEffectiveScale() or 1

    if sortMode ~= "Group" then
        local flatRows = math.max(1, self:GetTierSetting("FlatRows") or 1)
        local visibleFrames = {}
        for i = 1, MAX_GROUP_FRAMES do
            local frame = self.frames[i]
            if frame and ((frame.preview) or (frame.unit and UnitExists(frame.unit))) then
                visibleFrames[#visibleFrames + 1] = frame
            end
        end
        local totalFrames = #visibleFrames
        local framesPerCol = math.ceil(totalFrames / flatRows)
        local msPx = Pixel:Multiple(memberSpacing, scale)
        for idx, frame in ipairs(visibleFrames) do
            local col = math.floor((idx - 1) / framesPerCol)
            local row = (idx - 1) % framesPerCol
            local fx = Pixel:Snap(col * (width + msPx), scale)
            local fy = Pixel:Snap(row * (height + msPx), scale)
            frame:ClearAllPoints()
            if growUp then
                frame:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", fx, fy)
            else
                frame:SetPoint("TOPLEFT", self.container, "TOPLEFT", fx, -fy)
            end
        end
    else
        local frameBuckets = {}
        for g = 1, MAX_RAID_GROUPS do frameBuckets[g] = {} end
        for i = 1, MAX_GROUP_FRAMES do
            local frame = self.frames[i]
            if frame then
                if isPreview then
                    local previewGroup = math.ceil(i / FRAMES_PER_GROUP)
                    if frame.preview and previewGroup <= #groupOrder then
                        local bucket = frameBuckets[previewGroup]
                        bucket[#bucket + 1] = frame
                    end
                elseif frame.unit and UnitExists(frame.unit) then
                    local raidIndex = tonumber(frame.unit:match("(%d+)"))
                    local subgroup = raidIndex and select(3, GetRaidRosterInfo(raidIndex))
                    if subgroup then
                        local bucket = frameBuckets[subgroup]
                        bucket[#bucket + 1] = frame
                    end
                end
            end
        end

        for groupIdx, groupNum in ipairs(groupOrder) do
            local gx, gy = Helpers:CalculateGroupPosition(groupIdx, width, height, FRAMES_PER_GROUP, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, scale)
            local bucket = frameBuckets[groupNum] or {}
            for memberIndex, frame in ipairs(bucket) do
                if memberIndex > FRAMES_PER_GROUP then break end
                local mx, my = Helpers:CalculateMemberPosition(memberIndex, width, height, memberSpacing, memberGrowth, isHorizontal, scale)
                frame:ClearAllPoints()
                if growUp then
                    frame:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", gx + mx, -gy + my)
                else
                    frame:SetPoint("TOPLEFT", self.container, "TOPLEFT", gx + mx, gy + my)
                end
            end
        end
    end

    self:UpdateGroupLabels(sortMode, groupOrder, width, height, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, growUp, scale)
end

-- [ GROUP LABELS ]----------------------------------------------------------------------------------
local GROUP_LABEL_FONT_SIZE = 12
local GROUP_LABEL_ALPHA = 0.65
local GROUP_LABEL_PADDING = 5

function Plugin:UpdateGroupLabels(sortMode, groupOrder, width, height, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, growUp, scale)
    if not self.groupLabels then self.groupLabels = {} end
    local showLabels = (sortMode == "Group") and self:GetTierSetting("ShowGroupLabels")

    for i = 1, MAX_RAID_GROUPS do
        if self.groupLabels[i] then self.groupLabels[i]:Hide() end
    end
    if not showLabels then return end

    if not self.groupLabelOverlay then
        self.groupLabelOverlay = CreateFrame("Frame", nil, self.container)
        self.groupLabelOverlay:SetAllPoints()
        self.groupLabelOverlay:SetFrameLevel(self.container:GetFrameLevel() + OVERLAY_LEVEL_BOOST)
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

        local gx, gy = Helpers:CalculateGroupPosition(idx, width, height, FRAMES_PER_GROUP, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, scale)
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

-- [ CONTAINER SIZE ]--------------------------------------------------------------------------------
function Plugin:UpdateContainerSize()
    if InCombatLockdown() then return end

    local isParty = self:IsPartyTier()
    local isPreview = self.frames[1] and self.frames[1].preview

    if isParty then
        local width = self:GetTierSetting("Width") or 160
        local height = self:GetTierSetting("Height") or 40
        local spacing = self:GetTierSetting("Spacing") or 0
        local orientation = self:GetTierSetting("Orientation") or 0
        local visibleCount = 0
        for _, frame in ipairs(self.frames) do
            if frame:IsShown() or frame.preview then visibleCount = visibleCount + 1 end
        end
        visibleCount = math.max(1, visibleCount)
        local scale = self.container:GetEffectiveScale() or 1
        local containerW, containerH = Helpers:CalculatePartyContainerSize(visibleCount, width, height, spacing, orientation, scale)
        self.container:SetSize(containerW, containerH)
    else
        local width = self:GetTierSetting("Width") or 100
        local height = self:GetTierSetting("Height") or 40
        local memberSpacing = self:GetTierSetting("MemberSpacing") or 2
        local groupSpacing = self:GetTierSetting("GroupSpacing") or 2
        local groupsPerRow = self:GetTierSetting("GroupsPerRow") or 6
        local sortMode = self:GetTierSetting("SortMode") or "Group"

        if sortMode ~= "Group" then
            local flatRows = math.max(1, self:GetTierSetting("FlatRows") or 1)
            local totalFrames = 0
            for _, frame in ipairs(self.frames) do
                if frame:IsShown() or frame.preview then totalFrames = totalFrames + 1 end
            end
            totalFrames = math.max(1, totalFrames)
            local framesPerCol = math.ceil(totalFrames / flatRows)
            local scale = self.container:GetEffectiveScale() or 1
            local msPx = Pixel:Multiple(memberSpacing, scale)
            local containerW = (flatRows * width) + ((flatRows - 1) * msPx)
            local containerH = (framesPerCol * height) + ((framesPerCol - 1) * msPx)
            self.container:SetSize(containerW, containerH)
        else
            local numGroups = 0
            if isPreview then
                local tierMax = Helpers:GetTierMaxFrames(self:GetCurrentTier())
                numGroups = math.ceil(tierMax / FRAMES_PER_GROUP)
            else
                local activeGroups = Helpers:GetActiveGroups()
                for _ in pairs(activeGroups) do numGroups = numGroups + 1 end
                numGroups = math.max(1, numGroups)
            end
            local isHorizontal = (self:GetTierSetting("Orientation") or "Vertical") == "Horizontal"
            local scale = self.container:GetEffectiveScale() or 1
            local containerW, containerH = Helpers:CalculateRaidContainerSize(numGroups, FRAMES_PER_GROUP, width, height, memberSpacing, groupSpacing, groupsPerRow, isHorizontal, scale)
            self.container:SetSize(containerW, containerH)
        end
    end

    local spacing = self:GetTierSetting("Spacing") or 0
    local memberSpacing = self:GetTierSetting("MemberSpacing") or 2
    local groupSpacing = self:GetTierSetting("GroupSpacing") or 2
    local isMerged = (isParty and spacing == 0) or (not isParty and memberSpacing == 0 and groupSpacing == 0)

    if isMerged then
        local borderSize = self:GetSetting(1, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(self.container:GetEffectiveScale() or 1)
        Orbit.Skin:SkinBorder(self.container, self.container, borderSize, nil, false, false)
        
        local maxLevel = self.container:GetFrameLevel()
        for _, frame in ipairs(self.frames) do
            if frame:IsShown() or frame.preview then
                local fl = frame:GetFrameLevel()
                if fl > maxLevel then maxLevel = fl end
            end
        end
        local borderLevel = maxLevel + Orbit.Constants.Levels.Border

        if self.container._edgeBorderOverlay then 
            self.container._edgeBorderOverlay:SetFrameLevel(borderLevel)
            if self.container._activeBorderMode == "nineslice" then
                self.container._edgeBorderOverlay:Show()
            end
        end
        if self.container._borderFrame then 
            self.container._borderFrame:SetFrameLevel(borderLevel)
            if self.container._activeBorderMode == "flat" then
                self.container._borderFrame:Show()
            end
        end
    else
        Orbit.Skin.DefaultSetBorderHidden(self.container, true)
    end
end

-- [ DYNAMIC UNIT ASSIGNMENT ]----------------------------------------------------------------------
function Plugin:UpdateFrameUnits()
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:UpdateFrameUnits() end)
        return
    end
    if self.frames and self.frames[1] and self.frames[1].preview then return end

    local isParty = self:IsPartyTier()

    if isParty then
        self:AssignPartyUnits()
    else
        self:AssignRaidUnits()
    end

    self:PositionFrames()
    self:UpdateContainerSize()
end

function Plugin:AssignPartyUnits()
    local includePlayer = self:GetTierSetting("IncludePlayer")
    local sortedUnits = Helpers:GetSortedPartyUnits(includePlayer)

    for i = 1, MAX_GROUP_FRAMES do
        local frame = self.frames[i]
        if frame then
            local unit = sortedUnits[i]
            if unit then
                local currentUnit = frame:GetAttribute("unit")
                if currentUnit ~= unit then
                    frame:SetAttribute("unit", unit)
                    frame.unit = unit
                    self:UnregisterFrameEvents(frame)
                    self:RegisterUnitEvents(frame, unit)
                    UpdatePrivateAuras(frame, self)
                end
                self:RegisterGlobalEvents(frame)
                SafeUnregisterUnitWatch(frame)
                SafeRegisterUnitWatch(frame)
                frame:Show()
                if frame.UpdateAll then frame:UpdateAll() end
            else
                SafeUnregisterUnitWatch(frame)
                self:UnregisterFrameEvents(frame)
                frame:SetAttribute("unit", nil)
                frame.unit = nil
                frame:Hide()
            end
        end
    end
end

function Plugin:AssignRaidUnits()
    local sortMode = self:GetTierSetting("SortMode") or "Group"
    local sortedUnits = Helpers:GetSortedRaidUnits(sortMode)

    for i = 1, MAX_GROUP_FRAMES do
        local frame = self.frames[i]
        if frame then
            local unitData = sortedUnits[i]
            if unitData then
                local token = unitData.token
                local currentUnit = frame:GetAttribute("unit")
                if currentUnit ~= token then
                    frame:SetAttribute("unit", token)
                    frame.unit = token
                    self:UnregisterFrameEvents(frame)
                    self:RegisterUnitEvents(frame, token)
                    UpdatePrivateAuras(frame, self)
                end
                self:RegisterGlobalEvents(frame)
                SafeUnregisterUnitWatch(frame)
                SafeRegisterUnitWatch(frame)
                frame:Show()
                if frame.UpdateAll then frame:UpdateAll() end
            else
                SafeUnregisterUnitWatch(frame)
                self:UnregisterFrameEvents(frame)
                frame:SetAttribute("unit", nil)
                frame.unit = nil
                frame:Hide()
            end
        end
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:UpdateLayout(frame)
    if not frame or InCombatLockdown() then return end
    local width = self:GetTierSetting("Width") or 100
    local height = self:GetTierSetting("Height") or 40
    for _, f in ipairs(self.frames) do
        f:SetSize(width, height)
        UpdateFrameLayout(f, self:GetSetting(1, "BorderSize"), self)
        self:UpdateTextSize(f)
    end
    self:PositionFrames()
    for _, f in ipairs(self.frames) do
        if f.ConstrainNameWidth then f:ConstrainNameWidth() end
    end
end

function Plugin:ApplyFrameStyle(frame, showPower)
    local width = self:GetTierSetting("Width") or 100
    local height = self:GetTierSetting("Height") or 40
    local borderSize = self:GetSetting(1, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(UIParent:GetEffectiveScale() or 1)
    local textureName = self:GetSetting(1, "Texture")

    local isParty = self:IsPartyTier()
    local spacing = self:GetTierSetting("Spacing") or 0
    local mSpacing = self:GetTierSetting("MemberSpacing") or 2
    local gSpacing = self:GetTierSetting("GroupSpacing") or 2
    frame._groupBorderActive = (isParty and spacing == 0) or (not isParty and mSpacing == 0 and gSpacing == 0)

    frame:SetSize(width, height)
    UpdateFrameLayout(frame, borderSize, self, showPower)
    if frame.SetBorder then frame:SetBorder(borderSize) end

    if frame.Health then Orbit.Skin:SkinStatusBar(frame.Health, textureName, nil, true) end
    if frame.Power then
        local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
        frame.Power:SetStatusBarTexture(texturePath)
    end

    if showPower ~= nil and frame.Power then
        if showPower then frame.Power:Show() else frame.Power:Hide() end
    end

    self:ApplyTextStyling(frame)
    if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end

    local savedPositions = self:GetComponentPositions(1)
    if savedPositions then
        local allIconKeys = { "RoleIcon", "LeaderIcon", "MainTankIcon", "StatusIcons", "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "MarkerIcon", "DefensiveIcon", "CrowdControlIcon", "PrivateAuraAnchor" }
        local activeKeys = HealerReg:ActiveKeys()
        for _, k in ipairs(activeKeys) do allIconKeys[#allIconKeys + 1] = k end
        for _, k in ipairs(activeKeys) do
            if savedPositions[k] then
                if k == "RaidBuff" then
                    if not frame.RaidBuff then
                        local sz = GetComponentIconSize(self, k)
                        local c = CreateFrame("Frame", nil, frame)
                        c:SetPoint("CENTER", frame, "CENTER", 0, 0)
                        c:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
                        c._raidIcons = {}
                        c:SetSize(sz, sz)
                        frame.RaidBuff = c
                    end
                else
                    self:EnsureAuraIcon(frame, k, GetComponentIconSize(self, k))
                end
            end
        end
        Orbit.GroupCanvasRegistration:ApplyIconPositions({ frame }, savedPositions, allIconKeys)
    end
end

function Plugin:OnCanvasApply()
    self:ApplySettings()
    Orbit.GroupCanvasRegistration:OnCanvasApply(self)
end

function Plugin:ApplySettings()
    if not self.frames then return end
    self._auraComponentsActive = nil

    for _, frame in ipairs(self.frames) do
        if not frame.preview and frame.unit then
            Orbit:SafeAction(function() self:ApplyFrameStyle(frame) end)

            local healthTextMode = self:GetTierSetting("HealthTextMode") or "percent_short"
            if frame.SetHealthTextMode then frame:SetHealthTextMode(healthTextMode) end
            local showHealthValue = self:GetTierSetting("ShowHealthValue")
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
            UpdatePrivateAuras(frame, self)
            StatusDispatch(frame, self, "UpdateAllPartyStatusIcons")
            if frame.UpdateAll then frame:UpdateAll() end
        end
    end

    self:PositionFrames()
    if not Orbit:IsEditMode() then
        self:RestoreTierPosition()
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

-- [ DISPEL EVENT BUS ]------------------------------------------------------------------------------
Orbit.EventBus:On("DISPEL_STATE_CHANGED", function(unit)
    if not Plugin.frames then return end
    for _, frame in ipairs(Plugin.frames) do
        if frame and frame.unit == unit and frame:IsShown() and Plugin.UpdateDispelIndicator then
            Plugin:UpdateDispelIndicator(frame, Plugin)
        end
    end
end, Plugin)
