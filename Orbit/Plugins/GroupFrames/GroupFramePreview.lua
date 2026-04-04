---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local LCG = LibStub("LibOrbitGlow-1.0")

Orbit.GroupFramePreviewMixin = {}

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local Helpers = Orbit.GroupFrameHelpers
local MAX_PARTY_PREVIEW = 5
local PREVIEW_GROUPS = 4
local DEBOUNCE_DELAY = Orbit.Constants.Timing.DefaultDebounce

local GF = Orbit.Constants.GroupFrames
local OFFLINE_ALPHA = GF.OfflineAlpha
local ROLE_PRIORITY = GF.RolePriority

local PARTY_PRIVATE_AURA_ICON_SIZE = 24
local PARTY_HEALER_AURA_ICON_SIZE = 16
local RAID_PRIVATE_AURA_ICON_SIZE = 18
local RAID_HEALER_AURA_ICON_SIZE = 12
local RAID_STATUS_ICON_SIZE = 18
local HealerReg = Orbit.HealerAuraRegistry

local SafeRegisterUnitWatch = Orbit.GroupFrameMixin.SafeRegisterUnitWatch
local SafeUnregisterUnitWatch = Orbit.GroupFrameMixin.SafeUnregisterUnitWatch

local ApplyIconPosition = function(icon, parentFrame, pos)
    OrbitEngine.PositionUtils.ApplyIconPosition(icon, parentFrame, pos)
end

-- [ PREVIEW DATA ]-----------------------------------------------------------------------------------
-- Pool layout: indices 1-5 = Tanks, 6-15 = Healers, 16-45 = DPS
local TANK_START, TANK_END = 1, 5
local HEALER_START, HEALER_END = 6, 15
local DPS_START, DPS_END = 16, 45

local TIER_COMP = {
    Party  = { tanks = 1, healers = 1, dps = 3  },
    Mythic = { tanks = 2, healers = 4, dps = 14 },
    Heroic = { tanks = 2, healers = 6, dps = 22 },
    World  = { tanks = 4, healers = 8, dps = 28 },
}

local RAID_PREVIEW = {
    Names = {
        -- Tanks (1-5)
        "Bolvar", "Garrosh", "Illidan", "Chen", "Saurfang",
        -- Healers (6-15)
        "Anduin", "Tyrande", "Velen", "Aggra", "Moira",
        "Calia", "Liadrin", "Talanji", "Rehgar", "Nobundo",
        -- DPS (16-45)
        "Arthas", "Jaina", "Thrall", "Sylvanas", "Khadgar",
        "Gul'dan", "Malfurion", "Genn", "Rexxar", "Alleria",
        "Vol'jin", "Maiev", "Rokhan", "Lor'themar", "Wrathion",
        "Wilfred", "Broxigar", "Chromie", "Taran Zhu", "Magni",
        "Nazgrim", "Halduron", "Yrel", "Alexstrasza", "Turalyon",
        "Baine", "Muradin", "Kael'thas", "Darion", "Drek'thar",
    },
    Classes = {
        -- Tanks
        "PALADIN", "WARRIOR", "DEMONHUNTER", "MONK", "WARRIOR",
        -- Healers
        "PALADIN", "DRUID", "PRIEST", "SHAMAN", "PRIEST",
        "PRIEST", "PALADIN", "PRIEST", "SHAMAN", "SHAMAN",
        -- DPS
        "DEATHKNIGHT", "MAGE", "SHAMAN", "HUNTER", "MAGE",
        "WARLOCK", "DRUID", "WARRIOR", "HUNTER", "HUNTER",
        "ROGUE", "ROGUE", "ROGUE", "HUNTER", "EVOKER",
        "WARLOCK", "WARRIOR", "MAGE", "MONK", "SHAMAN",
        "DEATHKNIGHT", "HUNTER", "PALADIN", "EVOKER", "PALADIN",
        "WARRIOR", "WARRIOR", "MAGE", "DEATHKNIGHT", "SHAMAN",
    },
    HealthPcts = {
        100, 85, 60, 40, 95, 75, 90, 50, 80, 70,
        65, 100, 88, 55, 72, 92, 78, 83, 95, 100,
        68, 91, 45, 82, 77, 53, 99, 62, 86, 74,
        58, 93, 71, 48, 87, 96, 64, 79, 100, 85,
        73, 66, 89, 42, 97,
    },
    Roles = {
        -- Tanks
        "TANK", "TANK", "TANK", "TANK", "TANK",
        -- Healers
        "HEALER", "HEALER", "HEALER", "HEALER", "HEALER",
        "HEALER", "HEALER", "HEALER", "HEALER", "HEALER",
        -- DPS
        "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER",
        "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER",
        "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER",
        "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER",
        "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER",
        "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER",
    },
}

-- [ CANVAS MODE DETECTION ]-------------------------------------------------------------------------
local function IsCanvasModeActive(plugin)
    if OrbitEngine and OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.currentFrame then
        local dl = OrbitEngine.CanvasModeDialog or (Orbit and Orbit.CanvasModeDialog)
        if dl and not dl:IsShown() then return false end
        if OrbitEngine.CanvasMode.currentFrame == plugin.container then return true end
        for _, frame in ipairs(plugin.frames) do
            if OrbitEngine.CanvasMode.currentFrame == frame then return true end
        end
    end
    return false
end

-- [ PREVIEW SORT ORDER ]----------------------------------------------------------------------------
local function ShuffleRange(startIdx, endIdx)
    local pool = {}
    for i = startIdx, endIdx do pool[#pool + 1] = i end
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    return pool
end

local function GetPreviewSortOrder(plugin)
    local tier = plugin:GetCurrentTier()
    local comp = TIER_COMP[tier] or TIER_COMP.Mythic
    
    if not plugin._previewRosterTier or plugin._previewRosterTier ~= tier then
        plugin._previewRosterTanks = ShuffleRange(TANK_START, TANK_END)
        plugin._previewRosterHealers = ShuffleRange(HEALER_START, HEALER_END)
        plugin._previewRosterDPS = ShuffleRange(DPS_START, DPS_END)
        plugin._previewRosterTier = tier
    end

    local order = {}
    for i = 1, comp.tanks do order[#order + 1] = plugin._previewRosterTanks[i] end
    for i = 1, comp.healers do order[#order + 1] = plugin._previewRosterHealers[i] end
    for i = 1, comp.dps do order[#order + 1] = plugin._previewRosterDPS[i] end
    
    local sortMode = plugin:GetTierSetting("SortMode") or "Group"
    if sortMode == "Role" then
        table.sort(order, function(a, b)
            local pa, pb = ROLE_PRIORITY[RAID_PREVIEW.Roles[a]] or 4, ROLE_PRIORITY[RAID_PREVIEW.Roles[b]] or 4
            if pa ~= pb then return pa < pb end
            return (RAID_PREVIEW.Names[a] or "") < (RAID_PREVIEW.Names[b] or "")
        end)
    elseif sortMode == "Alphabetical" then
        table.sort(order, function(a, b) return (RAID_PREVIEW.Names[a] or "") < (RAID_PREVIEW.Names[b] or "") end)
    end
    return order
end

-- [ SHOW PREVIEW ]----------------------------------------------------------------------------------
function Orbit.GroupFramePreviewMixin:ShowPreview()
    if InCombatLockdown() or not self.frames or not self.container then return end


    UnregisterStateDriver(self.container, "visibility")
    self.container:Show()

    local isCanvasMode = IsCanvasModeActive(self)
    local isParty = self:IsPartyTier()

    local currentTier = self:GetCurrentTier()
    local comp = TIER_COMP[currentTier] or TIER_COMP.Mythic
    local framesToShow
    if isCanvasMode then
        framesToShow = 1
    elseif isParty then
        local includePlayer = self:GetTierSetting("IncludePlayer")
        framesToShow = includePlayer and 5 or 4
    else
        framesToShow = comp.tanks + comp.healers + comp.dps
    end

    local maxFrames = Helpers.LAYOUT.MaxGroupFrames
    for i = 1, maxFrames do
        local frame = self.frames[i]
        if frame then
            SafeUnregisterUnitWatch(frame)
            if frame.SetAttribute then frame:SetAttribute("unit", nil) end
            frame.unit = nil
            if i <= framesToShow then
                frame.preview = true
                frame:Show()
            else
                frame.preview = nil
                frame:Hide()
            end
        end
    end

    self:PositionFrames()
    self:UpdateContainerSize()
    OrbitEngine.FrameSelection:ForceUpdate(self.container)

    C_Timer.After(DEBOUNCE_DELAY, function()
        if self.frames then
            self:ApplyPreviewVisuals()
            if not isCanvasMode then self:StartPreviewAnimation() end
        end
    end)

    Orbit.PreviewAnimator:WatchCanvas(self)
end

-- [ APPLY PREVIEW VISUALS ]-------------------------------------------------------------------------
function Orbit.GroupFramePreviewMixin:ApplyPreviewVisuals()
    if not self.frames then return end

    local isCanvasMode = IsCanvasModeActive(self)
    local isParty = self:IsPartyTier()
    local previewData = RAID_PREVIEW
    local sortOrder = GetPreviewSortOrder(self)
    local componentPositions = self:GetComponentPositions(1)
    local isDisabled = self.IsComponentDisabled and function(key) return self:IsComponentDisabled(key) end or function() return false end
    local roleAtlases = Orbit.RoleAtlases

    local currentTier = self:GetCurrentTier()
    local comp = TIER_COMP[currentTier] or TIER_COMP.Mythic
    local maxPreview
    if isCanvasMode then
        maxPreview = 1
    elseif isParty then
        local includePlayer = self:GetTierSetting("IncludePlayer")
        maxPreview = includePlayer and 5 or 4
    else
        maxPreview = comp.tanks + comp.healers + comp.dps
    end
    local showPower = self:GetTierSetting("ShowPowerBar")
    if showPower == nil then showPower = true end

    for i = 1, maxPreview do
        local frame = self.frames[i]
        if frame and frame.preview then
            local dataIdx = sortOrder and sortOrder[i] or i
            local role = previewData.Roles[dataIdx]
            local isHealer = role == "HEALER"
            local showThisPower = isParty and (showPower or isHealer) or (showPower and isHealer)

            -- Shared styling (size, border, texture, text, positions)
            self:ApplyFrameStyle(frame, showThisPower)

            -- Preview backdrop
            if self.ApplyPreviewBackdrop then self:ApplyPreviewBackdrop(frame)
            elseif self.CreateBackground then
                self:CreateBackground(frame)
                local globalSettings = Orbit.db.GlobalSettings or {}
                Orbit.Skin:ApplyGradientBackground(frame, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)
            end

            -- Health bar
            if frame.Health then
                frame.Health:SetMinMaxValues(0, 100)
                frame.Health:SetValue(100)
                local classFile = previewData.Classes[dataIdx]
                local classColor = C_ClassColor and C_ClassColor.GetClassColor(classFile) or RAID_CLASS_COLORS[classFile]
                if classColor then frame.Health:SetStatusBarColor(classColor.r, classColor.g, classColor.b) end
                frame.Health:Show()
                if frame.HealthDamageBar then frame.HealthDamageBar:Hide() end
                if frame.HealthDamageTexture then frame.HealthDamageTexture:Hide() end
            end

            -- Power bar
            if frame.Power and showThisPower then
                frame.Power:SetMinMaxValues(0, 100)
                frame.Power:SetValue(100)
                frame.Power:SetStatusBarColor(0, 0.5, 1)
            end

            -- Name
            if frame.Name then
                if isDisabled("Name") then frame.Name:Hide()
                else
                    frame._fullName = previewData.Names[dataIdx]
                    frame.Name:SetText(previewData.Names[dataIdx])
                    frame.Name:SetTextColor(1, 1, 1, 1)
                    frame.Name:Show()
                end
            end

            -- Health text
            if frame.HealthText then
                local showHealthValue = self:GetTierSetting("ShowHealthValue")
                if showHealthValue == nil then showHealthValue = true end
                if isDisabled("HealthText") or not showHealthValue then frame.HealthText:Hide()
                else
                    frame.HealthText:SetText("100%")
                    frame.HealthText:SetTextColor(1, 1, 1, 1)
                    frame.HealthText:Show()
                end
            end

            frame:SetAlpha(1)
            frame.previewClassFile = previewData.Classes[dataIdx]

            -- Role icon
            if frame.RoleIcon then
                if isDisabled("RoleIcon") then frame.RoleIcon:Hide()
                else
                    local roleOverrides = componentPositions.RoleIcon and componentPositions.RoleIcon.overrides
                    local hideDPS = roleOverrides and roleOverrides.HideDPS
                    local activeAtlases = roleAtlases
                    if roleOverrides and roleOverrides.RoleIconStyle == "round" then
                        activeAtlases = { TANK = "icons_64x64_tank", HEALER = "icons_64x64_heal", DAMAGER = "icons_64x64_damage" }
                    end
                    if role == "DAMAGER" and hideDPS then frame.RoleIcon:Hide()
                    elseif activeAtlases[role] then
                        frame.RoleIcon:SetAtlas(activeAtlases[role])
                        frame.RoleIcon:Show()
                        if componentPositions.RoleIcon then ApplyIconPosition(frame.RoleIcon, frame, componentPositions.RoleIcon) end
                    else frame.RoleIcon:Hide() end
                end
            end

            -- Leader icon
            if frame.LeaderIcon then
                if isDisabled("LeaderIcon") then frame.LeaderIcon:Hide()
                elseif i == 1 then
                    frame.LeaderIcon:SetAtlas(Orbit.IconPreviewAtlases and Orbit.IconPreviewAtlases.LeaderIcon or "UI-HUD-UnitFrame-Player-Group-LeaderIcon")
                    frame.LeaderIcon:Show()
                    if componentPositions.LeaderIcon then ApplyIconPosition(frame.LeaderIcon, frame, componentPositions.LeaderIcon) end
                else frame.LeaderIcon:Hide() end
            end

            -- MainTankIcon (raid tiers only)
            if frame.MainTankIcon then
                if isParty or isDisabled("MainTankIcon") then frame.MainTankIcon:Hide()
                elseif isCanvasMode or (role == "TANK" and i <= 2) then
                    frame.MainTankIcon:SetAtlas(i == 1 and "RaidFrame-Icon-MainTank" or "RaidFrame-Icon-MainAssist")
                    frame.MainTankIcon:Show()
                    if componentPositions.MainTankIcon then ApplyIconPosition(frame.MainTankIcon, frame, componentPositions.MainTankIcon) end
                else frame.MainTankIcon:Hide() end
            end

            -- Selection/Aggro highlights
            if i == 2 then Orbit.Skin:ApplyHighlightBorder(frame, "_selectionBorderOverlay", { r = 1, g = 1, b = 1, a = 0.5 })
            else Orbit.Skin:ClearHighlightBorder(frame, "_selectionBorderOverlay") end
            if i == 2 then Orbit.Skin:ApplyHighlightBorder(frame, "_aggroHighlightOverlay", { r = 1.0, g = 0.6, b = 0.0, a = 0.6 })
            else Orbit.Skin:ClearHighlightBorder(frame, "_aggroHighlightOverlay") end

            -- Canvas Mode icons
            local privateAuraSize = isParty and PARTY_PRIVATE_AURA_ICON_SIZE or RAID_PRIVATE_AURA_ICON_SIZE
            local healerAuraSize = isParty and PARTY_HEALER_AURA_ICON_SIZE or RAID_HEALER_AURA_ICON_SIZE
            local statusIconSize = isParty and 24 or RAID_STATUS_ICON_SIZE
            local statusIcons = { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }
            local hideKeys = not isParty and { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "DefensiveIcon", "CrowdControlIcon", "PrivateAuraAnchor", "MainTankIcon" } or nil
            Orbit.GroupCanvasRegistration:ShowCanvasModeIcons(self, frame, isCanvasMode, {
                statusIcons = statusIcons,
                statusIconSize = statusIconSize, statusIconSpacing = statusIconSize + 4,
                privateAuraSize = privateAuraSize,
                healerAuraSize = healerAuraSize,
                hideKeys = hideKeys,
            }, HealerReg:ActiveSlots(), HealerReg:ActiveRaidBuffs(), HealerReg:ActiveKeys())

            -- Auras
            if isCanvasMode then self:ShowPreviewAuras(frame, i)
            else Orbit.AuraPreview:HideFrameAuras(frame) end

            LCG.Hide(frame, "Pixel", "preview")
        end
    end
end

-- [ PREVIEW AURAS ]---------------------------------------------------------------------------------
local GROUP_PREVIEW_AURA_CFG = {
    helpers = function() return Orbit.GroupFrameHelpers end,
    defaultAnchorX = "RIGHT", defaultJustifyH = "LEFT",
    defaultMax = 3,
}
local GROUP_PREVIEW_BUFF_CFG = {
    helpers = function() return Orbit.GroupFrameHelpers end,
    defaultAnchorX = "LEFT", defaultJustifyH = "RIGHT",
    defaultMax = 3,
}

function Orbit.GroupFramePreviewMixin:ShowPreviewAuras(frame, frameIndex)
    Orbit.AuraPreview:ShowFrameAuras(self, frame, GROUP_PREVIEW_AURA_CFG, GROUP_PREVIEW_BUFF_CFG)
end

-- [ HIDE PREVIEW ]----------------------------------------------------------------------------------
function Orbit.GroupFramePreviewMixin:HidePreview()
    if InCombatLockdown() or not self.frames then return end

    self._editTierOverride = nil
    self._previewRosterTier = nil

    Orbit.PreviewAnimator:Stop(self)
    Orbit.PreviewAnimator:StopAuras(self)
    Orbit.PreviewAnimator:StopHealerAuras(self)
    if Orbit.PreviewAnimator.StopDispels then Orbit.PreviewAnimator:StopDispels(self) end
    Orbit.PreviewAnimator:UnwatchCanvas(self)

    local maxFrames = Helpers.LAYOUT.MaxGroupFrames
    for i = 1, maxFrames do
        local frame = self.frames[i]
        if frame then
            frame.preview = nil
            frame:SetAlpha(1)
            frame:EnableMouse(true)
            frame:SetAttribute("unit", nil)
            frame.unit = nil
            frame:Hide()
            if frame.previewDebuffs then
                for _, icon in ipairs(frame.previewDebuffs) do icon:Hide() end
                wipe(frame.previewDebuffs)
            end
            if frame.previewBuffs then
                for _, icon in ipairs(frame.previewBuffs) do icon:Hide() end
                wipe(frame.previewBuffs)
            end
            if frame._privateAuraIDs then
                for _, id in ipairs(frame._privateAuraIDs) do C_UnitAuras.RemovePrivateAuraAnchor(id) end
                wipe(frame._privateAuraIDs)
            end
            local paa = frame.PrivateAuraAnchor
            if paa then
                if paa._previewIcons then for _, sub in ipairs(paa._previewIcons) do sub:Hide() end end
                paa:Hide()
            end
            LCG.Hide(frame, "Pixel", "preview")
            for _, key in ipairs(HealerReg:ActiveKeys()) do
                if frame[key] then frame[key]:Hide() end
            end
            if frame.HealthDamageBar then frame.HealthDamageBar:Show() end
            if frame.HealthDamageTexture then frame.HealthDamageTexture:Show() end
        end
    end

    self:UpdateFrameUnits()
    if self.ApplySettings then self:ApplySettings() end
    self:UpdateContainerSize()
end

-- [ SCHEDULE PREVIEW UPDATE ]-----------------------------------------------------------------------
function Orbit.GroupFramePreviewMixin:SchedulePreviewUpdate()
    if not self._previewVisualsScheduled then
        self._previewVisualsScheduled = true
        C_Timer.After(DEBOUNCE_DELAY, function()
            self._previewVisualsScheduled = false
            if self.frames then
                self:ApplyPreviewVisuals()
                self:PositionFrames()
                self:UpdateContainerSize()
            end
        end)
    end
end

-- [ PREVIEW BACKDROP ]------------------------------------------------------------------------------
function Orbit.GroupFramePreviewMixin:ApplyPreviewBackdrop(frame)
    if not frame then return end
    if self.CreateBackground then self:CreateBackground(frame) end
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(frame, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)
end

-- [ PREVIEW ANIMATION ]-----------------------------------------------------------------------------
function Orbit.GroupFramePreviewMixin:StartPreviewAnimation()
    if not self.frames then return end
    local isParty = self:IsPartyTier()
    local isCanvasMode = IsCanvasModeActive(self)
    local currentTier = self:GetCurrentTier()
    local comp = TIER_COMP[currentTier] or TIER_COMP.Mythic
    local previewData = RAID_PREVIEW
    local sortOrder = GetPreviewSortOrder(self)
    local healerSlots = HealerReg:ActiveSlots()
    local isDisabled = self.IsComponentDisabled and function(k) return self:IsComponentDisabled(k) end or function() return false end
    local enabledSlots = {}
    for _, slot in ipairs(healerSlots) do
        if not isDisabled(slot.key) then enabledSlots[#enabledSlots + 1] = slot end
    end

    local maxPreview
    if isCanvasMode then
        maxPreview = 1
    elseif isParty then
        local includePlayer = self:GetTierSetting("IncludePlayer")
        maxPreview = includePlayer and 5 or 4
    else
        maxPreview = comp.tanks + comp.healers + comp.dps
    end

    local visibleFrames = {}
    for i = 1, maxPreview do
        local f = self.frames[i]
        if f and f.preview and f:IsShown() then visibleFrames[#visibleFrames + 1] = f end
    end

    local animConfig = {
        frames = visibleFrames,
        getHelpers = function() return Orbit.GroupFrameHelpers end,
        getHealth = function(i)
            local idx = sortOrder and sortOrder[i] or i
            return (previewData.HealthPcts[idx] or 75) / 100
        end,
        getDead = function(i)
            if isParty then
                local idx = sortOrder and sortOrder[i] or i
                local s = previewData.Status and previewData.Status[idx]
                return s == "Dead" or s == "Offline"
            end
            return false
        end,
        healerSlots = enabledSlots,
        raidBuffKey = not isDisabled("RaidBuff") and "RaidBuff" or nil,
    }

    -- Dispel preview for raid tiers
    if not isParty then
        local dispelEnabled = self:GetTierSetting("DispelIndicatorEnabled")
        if dispelEnabled then
            animConfig.dispelSettings = {
                thickness = self:GetTierSetting("DispelThickness") or 2,
                frequency = self:GetTierSetting("DispelFrequency") or 0.25,
                numLines = self:GetTierSetting("DispelNumLines") or 8,
                colors = {
                    Magic = self:GetTierSetting("DispelColorMagic") or { r = 0.2, g = 0.6, b = 1.0, a = 1 },
                    Curse = self:GetTierSetting("DispelColorCurse") or { r = 0.6, g = 0.0, b = 1.0, a = 1 },
                    Disease = self:GetTierSetting("DispelColorDisease") or { r = 0.6, g = 0.4, b = 0.0, a = 1 },
                    Poison = self:GetTierSetting("DispelColorPoison") or { r = 0.0, g = 0.6, b = 0.0, a = 1 },
                },
            }
        end
    end

    Orbit.PreviewAnimator:StartAll(self, animConfig)
end
