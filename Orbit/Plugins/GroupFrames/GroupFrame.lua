---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local Helpers = Orbit.GroupFrameHelpers
local Pixel = Orbit.Engine.Pixel

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local GF = Orbit.Constants.GroupFrames
local MAX_GROUP_FRAMES = Helpers.LAYOUT.MaxGroupFrames
local MAX_RAID_GROUPS = Helpers.LAYOUT.MaxRaidGroups
local FRAMES_PER_GROUP = Helpers.LAYOUT.FramesPerGroup
local MAX_PARTY_MEMBERS = 4
local DEFAULT_WIDTH = Helpers.LAYOUT.DefaultWidth
local DEFAULT_HEIGHT = Helpers.LAYOUT.DefaultHeight
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

-- [ TIER DEFAULTS ]----------------------------------------------------------------------------------
local TIER_DEFAULTS = {
    Party = {
        Width = 160, Height = 40, Scale = 100, Spacing = 3, Orientation = 0,
        GrowthDirection = "down", IncludePlayer = true,
        ShowPowerBar = true, PowerBarHeight = 10,
        HealthTextMode = "percent_short", ShowHealthValue = true,
        OutOfRangeOpacity = 30,
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT", selfAnchorY = "CENTER", posX = -75, posY = 0 },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT", selfAnchorY = "CENTER", posX = 75, posY = 0 },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2, justifyH = "CENTER", selfAnchorY = "TOP", posX = 0, posY = 18 },
            RoleIcon = { anchorX = "RIGHT", offsetX = 5, anchorY = "TOP", offsetY = 5, justifyH = "RIGHT", selfAnchorY = "TOP", posX = 75, posY = 15 },
            LeaderIcon = { anchorX = "LEFT", offsetX = 10, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", selfAnchorY = "TOP", posX = -70, posY = 20 },
            StatusIcons = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 10, justifyH = "CENTER", selfAnchorY = "BOTTOM", posX = 0, posY = -10, overrides = { IconSize = 15 } },
            SummonIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 10, justifyH = "CENTER", posX = 0, posY = -10 },
            PhaseIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 10, justifyH = "CENTER", posX = 0, posY = -10 },
            ResIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 10, justifyH = "CENTER", posX = 0, posY = -10 },
            ReadyCheckIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 10, justifyH = "CENTER", posX = 0, posY = -10 },
            DefensiveIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", selfAnchorY = "CENTER", posX = 0, posY = 0, overrides = { IconSize = 34 } },
            CrowdControlIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2 },
            PrivateAuraAnchor = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", selfAnchorY = "CENTER", posX = 0, posY = 0 },
            Buffs = { anchorX = "LEFT", anchorY = "CENTER", offsetX = -2, offsetY = 0, justifyH = "RIGHT", selfAnchorY = "CENTER", posX = -110, posY = 0, overrides = { MaxIcons = 4, IconSize = 34, MaxRows = 2 } },
            Debuffs = { anchorX = "RIGHT", anchorY = "CENTER", offsetX = -2, offsetY = 0, justifyH = "LEFT", selfAnchorY = "CENTER", posX = 110, posY = 0, overrides = { MaxIcons = 4, IconSize = 34, MaxRows = 2 } },
            MainTankIcon = { anchorX = "LEFT", offsetX = 25, anchorY = "TOP", offsetY = 1, justifyH = "LEFT", selfAnchorY = "TOP", posX = -55, posY = 19, overrides = { Scale = 0.7 } },
        },
        DisabledComponents = (function()
            local d = { "CrowdControlIcon", "RoleIcon" }
            for _, k in ipairs(Orbit.HealerAuraRegistry:AllSlotKeys()) do d[#d + 1] = k end
            d[#d + 1] = "RaidBuff"
            d[#d + 1] = "Status"
            return d
        end)(),
        DisabledComponentsMigrated = true,
        DispelIndicatorEnabled = true, DispelGlowType = Orbit.Constants.Glow.Type.Pixel, DispelThickness = 2, DispelFrequency = 0.0, DispelNumLines = 8, DispelLength = 15, DispelBorder = false,
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
        GroupsPerRow = 6, GrowthDirection = "down", SortMode = "group",
        Orientation = "horizontal", FlatRows = 1,
        ShowPowerBar = true, PowerBarHeight = 16, ShowGroupLabels = true,
        ShowHealthValue = false, HealthTextMode = "percent_short",
        OutOfRangeOpacity = 30,
        ComponentPositions = {
            Name = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 10, justifyH = "CENTER", selfAnchorY = "TOP", posX = 0, posY = 10 },
            HealthText = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 10, justifyH = "CENTER", selfAnchorY = "BOTTOM", posX = 0, posY = -10, overrides = { ShowHealthValue = false, FontSize = 10 } },
            MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = -1, justifyH = "CENTER", selfAnchorY = "TOP", posX = 0, posY = 21 },
            RoleIcon = { anchorX = "RIGHT", offsetX = 5, anchorY = "TOP", offsetY = 5, justifyH = "RIGHT", selfAnchorY = "TOP", posX = 45, posY = 15, overrides = { Scale = 0.7 } },
            LeaderIcon = { anchorX = "LEFT", offsetX = 8, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", selfAnchorY = "TOP", posX = -42, posY = 20, overrides = { Scale = 0.8 } },
            MainTankIcon = { anchorX = "LEFT", offsetX = 20, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", selfAnchorY = "TOP", posX = -30, posY = 20, overrides = { Scale = 0.6 } },
            StatusIcons = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", selfAnchorY = "CENTER", posX = 0, posY = 0 },
            SummonIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            PhaseIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            ResIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            ReadyCheckIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
            DefensiveIcon = { anchorX = "LEFT", offsetX = 1, anchorY = "BOTTOM", offsetY = 1, justifyH = "LEFT", selfAnchorY = "BOTTOM", posX = -49, posY = -19, overrides = { IconSize = 22 } },
            CrowdControlIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 2 },
            PrivateAuraAnchor = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", selfAnchorY = "CENTER", posX = 0, posY = 0, overrides = { IconSize = 20 } },
            Buffs = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 1, offsetY = 1, justifyH = "RIGHT", selfAnchorY = "BOTTOM", posX = 48, posY = -18, overrides = { MaxIcons = 5, IconSize = 18, MaxRows = 2 } },
        },
        DisabledComponents = (function()
            local d = { "CrowdControlIcon" }
            for _, k in ipairs(Orbit.HealerAuraRegistry:AllSlotKeys()) do d[#d + 1] = k end
            d[#d + 1] = "RaidBuff"
            d[#d + 1] = "Status"
            d[#d + 1] = "Debuffs"
            return d
        end)(),
        DisabledComponentsMigrated = true,
        AggroIndicatorEnabled = true, AggroColor = { r = 1.0, g = 0.0, b = 0.0, a = 1 },
        SelectionColor = { r = 0.8, g = 0.9, b = 1.0, a = 1 },
        AggroThickness = 1,
        DispelIndicatorEnabled = true, DispelGlowType = Orbit.Constants.Glow.Type.Pixel, DispelThickness = 2, DispelFrequency = 0.0, DispelNumLines = 8, DispelLength = 15, DispelBorder = false,
        DispelColorMagic = { r = 0.2, g = 0.6, b = 1.0, a = 1 },
        DispelColorCurse = { r = 0.6, g = 0.0, b = 1.0, a = 1 },
        DispelColorDisease = { r = 0.6, g = 0.4, b = 0.0, a = 1 },
        DispelColorPoison = { r = 0.0, g = 0.6, b = 0.0, a = 1 },
    },
}
-- Heroic / World inherit from Mythic with size overrides
TIER_DEFAULTS.Heroic = setmetatable({ Width = 100, Height = 40, ShowPowerBar = false, PowerBarHeight = 8 }, { __index = TIER_DEFAULTS.Mythic })
TIER_DEFAULTS.World = setmetatable({
    Width = 65, Height = 30, GroupsPerRow = 4, ShowGroupLabels = false, ShowPowerBar = false, DispelOnlyByMe = true,
    ComponentPositions = {
        RoleIcon = { anchorX = "RIGHT", offsetX = 5, anchorY = "TOP", offsetY = 5, justifyH = "RIGHT", selfAnchorY = "TOP", posX = 31, posY = 9, overrides = { Scale = 0.7 } },
        LeaderIcon = { anchorX = "LEFT", offsetX = 8, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", selfAnchorY = "TOP", posX = -28, posY = 14, overrides = { Scale = 0.8 } },
        MarkerIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = -1, justifyH = "CENTER", selfAnchorY = "TOP", posX = 0, posY = 15, overrides = { Scale = 0.6 } },
        SummonIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
        StatusIcons = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", selfAnchorY = "CENTER", posX = 0, posY = 0, overrides = { IconSize = 14 } },
        PrivateAuraAnchor = { anchorX = "LEFT", offsetX = 1, anchorY = "BOTTOM", offsetY = 1, justifyH = "LEFT", selfAnchorY = "BOTTOM", posX = -35, posY = -13, overrides = { IconSize = 14 } },
        Name = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 8, justifyH = "CENTER", selfAnchorY = "TOP", posX = 0, posY = 6 },
        ResIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
        PhaseIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
        HealthText = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 7, justifyH = "CENTER", selfAnchorY = "BOTTOM", posX = 0, posY = -7, overrides = { ShowHealthValue = false, FontSize = 8 } },
        ReadyCheckIcon = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER", posX = 0, posY = 0 },
        MainTankIcon = { anchorX = "LEFT", offsetX = 20, anchorY = "TOP", offsetY = 0, justifyH = "LEFT", selfAnchorY = "TOP", posX = -16, posY = 14, overrides = { Scale = 0.6 } },
    },
    DisabledComponents = (function()
        local d = { "CrowdControlIcon" }
        for _, k in ipairs(Orbit.HealerAuraRegistry:AllSlotKeys()) do d[#d + 1] = k end
        d[#d + 1] = "RaidBuff"
        d[#d + 1] = "Status"
        d[#d + 1] = "Debuffs"
        d[#d + 1] = "DefensiveIcon"
        d[#d + 1] = "Buffs"
        return d
    end)(),
}, { __index = TIER_DEFAULTS.Mythic })

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_GroupFrames"

local Plugin = Orbit:RegisterPlugin("Group Frames", SYSTEM_ID, {
    defaults = {
        Tiers = TIER_DEFAULTS,
        _EditTier = nil,
        HideBlizzardRaidPanel = false,
    },
})

Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.GroupFramePreviewMixin, Orbit.AuraMixin,
    Orbit.DispelIndicatorMixin, Orbit.AggroIndicatorMixin, Orbit.StatusIconMixin,
    Orbit.GroupFrameFactoryMixin, Orbit.GroupFrameLayoutMixin)

Plugin.canvasMode = true
Plugin.supportsHealthText = true

-- [ TIER API ]---------------------------------------------------------------------------------------
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
    local preservedPos = existingDest.Position and CopyTable(existingDest.Position) or nil

    tiers[destTier] = {}
    for k, v in pairs(source) do
        if type(v) == "table" then
            tiers[destTier][k] = CopyTable(v)
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

-- [ HELPERS ]----------------------------------------------------------------------------------------
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

-- [ POWER BAR UPDATE ]-------------------------------------------------------------------------------
local POWER_EVENTS = Orbit.GroupFrameFactoryMixin.POWER_EVENTS

local function UpdatePowerBar(frame, plugin)
    if not frame.Power or not frame.unit or not UnitExists(frame.unit) then return end
    local isParty = plugin:IsPartyTier()
    local showPower = plugin:GetTierSetting("ShowPowerBar")
    local isHealer = UnitGroupRolesAssigned(frame.unit) == "HEALER"
    local shouldShow = isParty and (showPower ~= false or isHealer) or (isHealer and showPower ~= false)
    if shouldShow then
        if not frame._powerEventsRegistered then
            for _, ev in ipairs(POWER_EVENTS) do frame:RegisterUnitEvent(ev, frame.unit) end
            frame._powerEventsRegistered = true
        end
        frame.Power:Show()
        local power, maxPower, powerType = UnitPower(frame.unit), UnitPowerMax(frame.unit), UnitPowerType(frame.unit)
        frame.Power:SetMinMaxValues(0, maxPower)
        frame.Power:SetValue(power)
        local color = GetPowerColor(powerType)
        frame.Power:SetStatusBarColor(color.r, color.g, color.b)
    else
        if frame._powerEventsRegistered then
            for _, ev in ipairs(POWER_EVENTS) do frame:UnregisterEvent(ev) end
            frame._powerEventsRegistered = false
        end
        frame.Power:Hide()
    end
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

-- [ AURA DISPLAY CONFIG ] ---------------------------------------------------------------------------
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
    if plugin._pendingPrivateAuraReanchor then return end
    plugin._pendingPrivateAuraReanchor = true
    C_Timer.After(0, function()
        plugin._pendingPrivateAuraReanchor = false
        if not plugin.frames then return end
        for _, frame in ipairs(plugin.frames) do
            if frame.unit and frame:IsShown() then UpdatePrivateAuras(frame, plugin) end
        end
    end)
end




-- [ DEBOUNCED ROSTER UPDATE ] -----------------------------------------------------------------------
local function ScheduleDebouncedRosterUpdate(plugin, updateVisibility)
    if updateVisibility then plugin._rosterNeedsVisibility = true end
    -- First event of a burst resizes synchronously so tier flips don't show a 1-frame stale layout.
    if not plugin._rosterUpdatePending and not InCombatLockdown() then
        plugin:CheckTierChange()
    end
    if plugin._rosterUpdatePending then return end
    plugin._rosterUpdatePending = true
    C_Timer.After(0, function()
        plugin._rosterUpdatePending = false
        local needsVis = plugin._rosterNeedsVisibility
        plugin._rosterNeedsVisibility = false
        if needsVis and plugin.UpdateVisibilityDriver then plugin.UpdateVisibilityDriver() end
        local oldTier = plugin._currentTier
        plugin:CheckTierChange()
        if plugin._currentTier ~= oldTier then
            Orbit.EventBus:Fire("GROUP_ROSTER_SETTLED")
            return
        end
        if not InCombatLockdown() then 
            plugin:UpdateFrameUnits() 
        else 
            -- IN COMBAT: We cannot add/remove secure frames. But WoW silently shifts
            -- players between unit tokens (e.g. raid4 becomes raid3). We MUST force
            -- the *visible* frames to instantly pull the new underlying player's Health/Name.
            if plugin.frames then
                for _, frame in ipairs(plugin.frames) do
                    if not frame.preview and frame.unit and frame:IsShown() then
                        -- Flush old GUID cache to force validation post-combat
                        frame._guidCache = nil 
                        if frame.UpdateAll then frame:UpdateAll() end
                        UpdateInRange(frame)
                    end
                end
            end
            SchedulePrivateAuraReanchor(plugin) 
        end
        Orbit.EventBus:Fire("GROUP_ROSTER_SETTLED")
    end)
end

-- [ SHARED EVENT CALLBACKS ]-------------------------------------------------------------------------
local SHARED_EVENT_CALLBACKS = {
    UpdatePowerBar = UpdatePowerBar, UpdateDebuffs = UpdateDebuffs, UpdateBuffs = UpdateBuffs,
    UpdateDefensiveIcon = UpdateDefensiveIcon, UpdateCrowdControlIcon = UpdateCrowdControlIcon,
    UpdatePrivateAuras = UpdatePrivateAuras, UpdateFrameLayout = UpdateFrameLayout,
    UpdateHealerAuras = UpdateHealerAuras, UpdateMissingRaidBuffs = UpdateMissingRaidBuffs,
    UpdateMainTankIcon = true,
}

-- [ GROUP FRAME CREATION ]---------------------------------------------------------------------------
local function CreateGroupFrame(index, plugin)
    local unit = "raid" .. index
    local frameName = "OrbitGroupFrame" .. index

    local frame = OrbitEngine.UnitButton:Create(plugin.container, unit, frameName, true)
    frame.editModeName = "Group Frame " .. index
    frame.systemIndex = 1
    frame.groupIndex = index

    local width = plugin:GetTierSetting("Width") or DEFAULT_WIDTH
    local height = plugin:GetTierSetting("Height") or DEFAULT_HEIGHT
    frame:SetSize(width, height)
    frame:SetFrameStrata(Orbit.Constants.Strata.HUD)
    frame:SetFrameLevel(Orbit.StrataEngine:GetFrameLevel("Global_HUD", "Orbit_GroupFrames") + index)

    UpdateFrameLayout(frame, Orbit.db.GlobalSettings.BorderSize, plugin)

    frame.Power = plugin:CreatePowerBar(frame, unit)
    frame.debuffContainer = CreateFrame("Frame", nil, frame)
    frame.debuffContainer:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
    frame.buffContainer = CreateFrame("Frame", nil, frame)
    frame.buffContainer:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)

    plugin:CreateStatusIcons(frame, plugin:IsPartyTier())

    local originalOnEvent = frame:GetScript("OnEvent")
    frame:SetScript("OnShow", Orbit.GroupFrameMixin.CreateOnShowHandler(plugin, SHARED_EVENT_CALLBACKS))
    frame:SetScript("OnEvent", Orbit.GroupFrameMixin.CreateEventHandler(plugin, SHARED_EVENT_CALLBACKS, originalOnEvent))

    plugin:ConfigureFrame(frame)
    frame:Hide()
    return frame
end

-- [ HIDE NATIVE FRAMES ]-----------------------------------------------------------------------------
local function HideNativeGroupFrames()
    UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")
    if CompactRaidFrameManager_SetSetting then
        CompactRaidFrameManager_SetSetting("IsShown", "0")
    end
    for i = 1, 4 do
        local f = _G["PartyMemberFrame" .. i]
        if f then OrbitEngine.NativeFrame:Park(f) end
    end
    OrbitEngine.NativeFrame:Park(PartyFrame)
    OrbitEngine.NativeFrame:Park(CompactPartyFrame)
    OrbitEngine.NativeFrame:Park(CompactRaidFrameContainer)
    if PartyFrame and PartyFrame.PartyMemberFramePool then
        for child in PartyFrame.PartyMemberFramePool:EnumerateActive() do
            OrbitEngine.NativeFrame:Park(child)
        end
    end
end

function Plugin:UpdateBlizzardRaidPanelVisibility()
    if self:GetSetting(1, "HideBlizzardRaidPanel") then
        OrbitEngine.NativeFrame:Park(CompactRaidFrameManager)
    else
        OrbitEngine.NativeFrame:Unpark(CompactRaidFrameManager)
    end
end
function Plugin:AddSettings(dialog, systemFrame)
    Orbit.GroupFrameSettings(self, dialog, systemFrame)
end

-- [ ON LOAD ]----------------------------------------------------------------------------------------
function Plugin:OnLoad()
    HideNativeGroupFrames()
    self:UpdateBlizzardRaidPanelVisibility()

    self._currentTier = self:GetCurrentTier()

    self.container = CreateFrame("Frame", "OrbitGroupFrameContainer", UIParent, "SecureHandlerStateTemplate")
    self.container:SetAttribute("_onstate-visibility", [[ if newstate == "hide" then self:Hide() else self:Show() end ]])
    self.container.editModeName = "Group Frames"
    self.container.systemIndex = 1
    self.container:SetFrameStrata(Orbit.Constants.Strata.HUD)
    self.container:SetFrameLevel(Orbit.StrataEngine:GetFrameLevel("Global_HUD", "Orbit_GroupFrames") - 1)
    self.container:SetClampedToScreen(true)
    Pixel:Enforce(self.container)

    self.frames = {}
    for i = 1, MAX_GROUP_FRAMES do
        self.frames[i] = CreateGroupFrame(i, self)
        self.frames[i]:SetParent(self.container)
        self.frames[i].orbitPlugin = self
        self.frames[i]:Hide()
    end

    -- Centralized global event handler (replaces per-frame registration)
    self._globalEventFrame = Orbit.GroupFrameMixin.CreateGlobalEventHandler(self, SHARED_EVENT_CALLBACKS)

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
    self.frame.orbitHeightSync = true
    self.frame.orbitResizeBounds = { minW = 50, maxW = 400, minH = 20, maxH = 100 }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, 1)

    self.container.orbitCanvasFrame = self.frames[1]
    self.container.orbitCanvasTitle = "Group Frame: " .. self:GetCurrentTier()

    self:RestoreTierPosition(self._currentTier)

    -- Visibility driver: unified — show when in any group
    local function UpdateVisibilityDriver()
        if InCombatLockdown() or Orbit:IsEditMode() then return end
        local _, instanceType = IsInInstance()
        local driver = "[petbattle] hide; [group] show; hide"
        if instanceType == "arena" or instanceType == "pvp" then
            driver = "[petbattle] hide; show"
        end
        RegisterStateDriver(self.container, "visibility", driver)
    end
    self.UpdateVisibilityDriver = function() UpdateVisibilityDriver() end
    UpdateVisibilityDriver()
    self.mountedConfig = { frame = self.container }
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(self.container, self, 1) end

    self.container:Show()
    self.container:SetSize(self:GetTierSetting("Width") or DEFAULT_WIDTH, DEFAULT_HEIGHT)

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
            -- Nuclear option: wipe GUID cache on reload/zone to force full re-validate
            for _, f in ipairs(self.frames) do f._guidCache = nil end

            C_Timer.After(1, function()
                if InCombatLockdown() then return end
                UpdateVisibilityDriver()
                if not self:CheckTierChange() then
                    self:UpdateFrameUnits()
                end
                for _, frame in ipairs(self.frames) do
                    if not frame.preview and frame.unit and frame:IsShown() then
                        if frame.UpdateAll then frame:UpdateAll() end
                        UpdateInRange(frame)
                    end
                end
            end)
            return
        end
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
            ScheduleDebouncedRosterUpdate(self, true)
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            UpdateVisibilityDriver()
            if self._pendingTierApply then
                local oldTier = self._pendingTierApply
                self._pendingTierApply = nil
                self:SaveCurrentTierPosition(oldTier)
                self:UpdateFrameUnits()
                self:ApplySettings()
                self:RestoreTierPosition(self._currentTier)
            else
                if not self:CheckTierChange() then
                    self:UpdateFrameUnits()
                end
            end
            return
        end
        if event == "ZONE_CHANGED_NEW_AREA" then
            C_Timer.After(0.5, function()
                UpdateVisibilityDriver()
                if not self:CheckTierChange() and not InCombatLockdown() then
                    self:UpdateFrameUnits()
                    self:ApplySettings()
                end
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

-- [ PER-TIER POSITION ]------------------------------------------------------------------------------
function Plugin:SaveCurrentTierPosition(tier)
    tier = tier or self:GetCurrentTier()
    if not self.container or not tier then return end
    local point, relativeTo, relativePoint, x, y = self.container:GetPoint()
    if not point then return end
    local relName = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent"
    local pm = OrbitEngine.PositionManager
    if pm then
        local eph = pm:GetPosition(self.container)
        if eph and eph.point then
            point, x, y = eph.point, eph.x, eph.y
            relName = eph.relativeTo or relName
            relativePoint = eph.relativePoint or relativePoint
        end
    end
    self:SetTierSetting("Position", { point = point, relativeTo = relName, relativePoint = relativePoint or point, x = x, y = y }, tier)
end

local TIER_DEFAULT_POSITIONS = {
    Party  = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", x = 100,  y = -120 },
    Mythic = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", x = 100,  y = -260 },
    Heroic = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", x = 260,  y = -260 },
    World  = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "TOPLEFT", x = 420,  y = -260 },
}

function Plugin:RestoreTierPosition(tier)
    tier = tier or self:GetCurrentTier()
    if not self.container or InCombatLockdown() then return end
    local pos = self:GetTierSetting("Position", tier)
    if not pos or not pos.point then
        local legacy = self:GetSetting(1, "Position")
        if legacy and legacy.point then
            pos = legacy
            self:SetTierSetting("Position", pos, tier)
        end
    end
    if not pos or not pos.point then
        pos = TIER_DEFAULT_POSITIONS[tier] or TIER_DEFAULT_POSITIONS.Party
        self:SetTierSetting("Position", pos, tier)
    end
    local x, y = Pixel:SnapPosition(pos.x, pos.y, pos.point, self.container:GetWidth(), self.container:GetHeight(), self.container:GetEffectiveScale())
    local relativeTo = (pos.relativeTo and _G[pos.relativeTo]) or UIParent
    self.container:ClearAllPoints()
    self.container:SetPoint(pos.point, relativeTo, pos.relativePoint or pos.point, x, y)
    if OrbitEngine.PositionManager then OrbitEngine.PositionManager:ClearFrame(self.container) end
end

-- [ TIER CHANGE DETECTION ]--------------------------------------------------------------------------
function Plugin:CheckTierChange()
    local newTier = self:GetCurrentTier()
    if newTier ~= self._currentTier then
        local oldTier = self._currentTier
        self._currentTier = newTier
        self.container.orbitCanvasTitle = "Group Frame: " .. newTier
        if not InCombatLockdown() then
            self._pendingTierApply = nil
            self:SaveCurrentTierPosition(oldTier)
            self:UpdateFrameUnits()
            self:ApplySettings()
            self:RestoreTierPosition(newTier)
        else
            self._pendingTierApply = oldTier
        end
        return true
    end
    return false
end

-- [ PREPARE ICONS FOR CANVAS MODE ]------------------------------------------------------------------
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


-- [ DYNAMIC UNIT ASSIGNMENT ] -----------------------------------------------------------------------
function Plugin:UpdateFrameUnits()
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:UpdateFrameUnits() end)
        return
    end
    if self.frames and self.frames[1] and self.frames[1].preview then return end

    local isParty = self:IsPartyTier()
    local changed

    if isParty then
        changed = self:AssignPartyUnits()
    else
        changed = self:AssignRaidUnits()
    end

    if changed then
        self:PositionFrames()
        self:UpdateContainerSize()
    end
end

function Plugin:AssignPartyUnits()
    local includePlayer = self:GetTierSetting("IncludePlayer")
    local sortedUnits = Helpers:GetSortedPartyUnits(includePlayer)
    local tierWidth = self:GetTierSetting("Width") or DEFAULT_WIDTH
    local tierHeight = self:GetTierSetting("Height") or DEFAULT_HEIGHT
    local changed = false

    for i = 1, MAX_GROUP_FRAMES do
        local frame = self.frames[i]
        if frame then
            local unit = sortedUnits[i]
            if unit then
                local currentUnit = frame:GetAttribute("unit")
                -- UnitGUID can return a secret in combat. Check issecretvalue BEFORE any `or nil`
                -- or boolean test — those would throw.
                local newGuid = UnitGUID(unit)
                if issecretvalue(newGuid) then newGuid = nil end

                local guidChanged = newGuid and frame._guidCache ~= newGuid

                if currentUnit ~= unit or guidChanged then
                    SafeUnregisterUnitWatch(frame)
                    frame:SetAttribute("unit", unit)
                    frame.unit = unit
                    frame._guidCache = newGuid
                    self:UnregisterFrameEvents(frame)
                    self:RegisterUnitEvents(frame, unit)
                    UpdatePrivateAuras(frame, self)
                    frame:SetSize(tierWidth, tierHeight)
                    SafeRegisterUnitWatch(frame)
                    changed = true
                end
                if not frame:IsShown() then frame:Show(); changed = true end
                if frame.UpdateAll then frame:UpdateAll() end
                UpdatePowerBar(frame, self)
                UpdateInRange(frame)
            else
                local wasVisible = frame:IsShown() or frame.unit ~= nil
                SafeUnregisterUnitWatch(frame)
                self:UnregisterFrameEvents(frame)
                frame:SetAttribute("unit", nil)
                frame.unit = nil
                frame:Hide()
                if wasVisible then changed = true end
            end
        end
    end
    return changed
end

function Plugin:AssignRaidUnits()
    local sortMode = self:GetTierSetting("SortMode") or "group"
    local sortedUnits = Helpers:GetSortedRaidUnits(sortMode)
    local tierWidth = self:GetTierSetting("Width") or DEFAULT_WIDTH
    local tierHeight = self:GetTierSetting("Height") or DEFAULT_HEIGHT
    local changed = false

    for i = 1, MAX_GROUP_FRAMES do
        local frame = self.frames[i]
        if frame then
            local unitData = sortedUnits[i]
            if unitData then
                local token = unitData.token
                local currentUnit = frame:GetAttribute("unit")
                -- UnitGUID can return a secret in combat. Check issecretvalue BEFORE any `or nil`
                -- or boolean test — those would throw.
                local newGuid = token and UnitGUID(token)
                if issecretvalue(newGuid) then newGuid = nil end

                local guidChanged = newGuid and frame._guidCache ~= newGuid

                if currentUnit ~= token or guidChanged then
                    SafeUnregisterUnitWatch(frame)
                    frame:SetAttribute("unit", token)
                    frame.unit = token
                    frame._guidCache = newGuid
                    self:UnregisterFrameEvents(frame)
                    self:RegisterUnitEvents(frame, token)
                    UpdatePrivateAuras(frame, self)
                    frame:SetSize(tierWidth, tierHeight)
                    SafeRegisterUnitWatch(frame)
                    changed = true
                end
                if not frame:IsShown() then frame:Show(); changed = true end
                if frame.UpdateAll then frame:UpdateAll() end
                UpdatePowerBar(frame, self)
                UpdateInRange(frame)
            else
                local wasVisible = frame:IsShown() or frame.unit ~= nil
                SafeUnregisterUnitWatch(frame)
                self:UnregisterFrameEvents(frame)
                frame:SetAttribute("unit", nil)
                frame.unit = nil
                frame:Hide()
                if wasVisible then changed = true end
            end
        end
    end
    return changed
end

-- [ SETTINGS APPLICATION ]---------------------------------------------------------------------------
function Plugin:UpdateLayout(frame)
    if not frame or InCombatLockdown() then return end
    local width = self:GetTierSetting("Width") or DEFAULT_WIDTH
    local height = self:GetTierSetting("Height") or DEFAULT_HEIGHT
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
    local width = self:GetTierSetting("Width") or DEFAULT_WIDTH
    local height = self:GetTierSetting("Height") or DEFAULT_HEIGHT
    local borderSize = self:GetSetting(1, "BorderSize") or Orbit.Engine.Pixel:DefaultBorderSize(UIParent:GetEffectiveScale() or 1)
    local textureName = self:GetSetting(1, "Texture")

    local isParty = self:IsPartyTier()
    local spacing = self:GetTierSetting("Spacing") or 0
    local mSpacing = self:GetTierSetting("MemberSpacing") or 2
    local gSpacing = self:GetTierSetting("GroupSpacing") or 2

    frame:SetSize(width, height)
    UpdateFrameLayout(frame, borderSize, self, showPower)
    if frame.SetBorder then frame:SetBorder(borderSize) end

    if frame.Health then Orbit.Skin:SkinStatusBar(frame.Health, textureName, nil, true) end
    if frame.TotalAbsorbBar then
        local absorbTextureName = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.AbsorbTexture
        frame.TotalAbsorbBar:SetStatusBarTexture(LSM:Fetch("statusbar", absorbTextureName or "Blizzard"))
    end
    if frame.Power then
        local texturePath = LSM:Fetch("statusbar", textureName) or "Interface\\TargetingFrame\\UI-StatusBar"
        frame.Power:SetStatusBarTexture(texturePath)
    end

    if showPower ~= nil and frame.Power then
        if showPower then frame.Power:Show() else frame.Power:Hide() end
    end

    self:ApplyTextStyling(frame)
    if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end

    -- Reset icon base sizes to current tier (icons are created once at load; tier may change)
    local iconSize = isParty and 16 or 12
    local savedPositions = self:GetComponentPositions(1)
    local statusOverrides = savedPositions and savedPositions.StatusIcons and savedPositions.StatusIcons.overrides
    local customStatusSize = statusOverrides and statusOverrides.IconSize

    local centerIconSize = customStatusSize or (isParty and 24 or 18)
    for _, k in ipairs({ "RoleIcon", "LeaderIcon", "MainTankIcon", "MarkerIcon" }) do
        if frame[k] and frame[k].SetSize then frame[k]:SetSize(iconSize, iconSize); frame[k].orbitOriginalWidth, frame[k].orbitOriginalHeight = iconSize, iconSize end
    end
    for _, k in ipairs({ "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }) do
        if frame[k] and frame[k].SetSize then frame[k]:SetSize(centerIconSize, centerIconSize); frame[k].orbitOriginalWidth, frame[k].orbitOriginalHeight = centerIconSize, centerIconSize end
    end

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
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:ApplySettings() end)
        return
    end
    self._auraComponentsActive = nil
    self._dispelSettingsCache = nil
    self._aggroSettingsCache = nil

    local tierWidth = self:GetTierSetting("Width") or DEFAULT_WIDTH
    local tierHeight = self:GetTierSetting("Height") or DEFAULT_HEIGHT
    local borderSize = self:GetSetting(1, "BorderSize")
    for _, frame in ipairs(self.frames) do
        if not frame.preview and frame.unit then
            frame:SetSize(tierWidth, tierHeight)
            UpdateFrameLayout(frame, borderSize, self)
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

-- [ DISPEL EVENT BUS ]-------------------------------------------------------------------------------
Orbit.EventBus:On("DISPEL_STATE_CHANGED", function(unit)
    if not Plugin.frames then return end
    for _, frame in ipairs(Plugin.frames) do
        if frame and frame.unit == unit and frame:IsShown() and Plugin.UpdateDispelIndicator then
            Plugin:UpdateDispelIndicator(frame, Plugin)
        end
    end
end, Plugin)
