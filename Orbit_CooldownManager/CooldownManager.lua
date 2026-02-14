---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local ESSENTIAL_INDEX = Constants.Cooldown.SystemIndex.Essential
local UTILITY_INDEX = Constants.Cooldown.SystemIndex.Utility
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon
local TRACKED_INDEX = Constants.Cooldown.SystemIndex.Tracked
local VIEWER_MAP = {}

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Cooldown Manager", "Orbit_CooldownViewer", {
    defaults = {
        aspectRatio = "4:3",
        IconSize = Constants.Cooldown.DefaultIconSize,
        IconPadding = Constants.Cooldown.DefaultPadding,
        SwipeColor = { r = 0, g = 0, b = 0, a = 0.8 },
        SwipeColorCurve = { pins = { { position = 0, color = { r = 0, g = 0, b = 0, a = 0.8 } } } },
        Opacity = 100,
        Orientation = 0,
        IconLimit = Constants.Cooldown.DefaultLimit,
        ShowGCDSwipe = true,
        DisabledComponents = { "Keybind" },
        ComponentPositions = {
            Timer = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0, justifyH = "CENTER" },
            Stacks = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 1, offsetY = 5, justifyH = "LEFT" },
            Charges = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 1, offsetY = 5, justifyH = "RIGHT" },
            Keybind = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2, justifyH = "RIGHT" },
        },
        PandemicGlowType = Constants.PandemicGlow.DefaultType,
        PandemicGlowColor = Constants.PandemicGlow.DefaultColor,
        ProcGlowType = Constants.PandemicGlow.DefaultType,
        ProcGlowColor = Constants.PandemicGlow.DefaultColor,
        OutOfCombatFade = false,
        ShowOnMouseover = true,
        TrackedItems = {},
        KeypressColor = { r = 1, g = 1, b = 1, a = 0 },
    },
}, Orbit.Constants.PluginGroups.CooldownManager)

Plugin.canvasMode = true
Plugin.viewerMap = VIEWER_MAP

-- Per-system-index defaults (overrides shared defaults for specific viewers)
Plugin.indexDefaults = {
    [1] = { IconSize = 120, IconLimit = 12 }, -- Essential
    [2] = { IconSize = 90, IconLimit = 8 }, -- Utility
    [3] = { PandemicGlowType = 1 }, -- BuffIcon
}

-- Generates a spec-specific settings key, e.g. "TrackedItems_267"
function Plugin:GetSpecKey(baseKey)
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    return baseKey .. "_" .. (specID or 0)
end

-- [ STUBS - Overwritten by sub-modules ]------------------------------------------------------------
function Plugin:AddSettings() end
function Plugin:IsComponentDisabled()
    return false
end
function Plugin:HookProcGlow() end
function Plugin:CheckPandemicFrames() end
function Plugin:FixGlowTransparency() end
function Plugin:HookBlizzardViewers() end
function Plugin:SetupViewerHooks() end
function Plugin:ReapplyParentage() end
function Plugin:EnforceViewerParentage() end
function Plugin:MonitorViewers() end
function Plugin:CheckViewer() end
function Plugin:OnPlayerEnteringWorld() end
function Plugin:ProcessChildren() end
function Plugin:HookGCDSwipe() end
function Plugin:GetGrowthDirection()
    return "DOWN"
end
function Plugin:GetBaseFontSize()
    return 12
end
function Plugin:GetGlobalFont()
    return STANDARD_TEXT_FONT
end
function Plugin:GetTextOverlay() end
function Plugin:CreateKeybindText() end
function Plugin:ApplyTextSettings() end
function Plugin:SetupCanvasPreview() end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self.essentialAnchor = self:CreateAnchor("OrbitEssentialCooldowns", ESSENTIAL_INDEX, "Essential Cooldowns")
    self.utilityAnchor = self:CreateAnchor("OrbitUtilityCooldowns", UTILITY_INDEX, "Utility Cooldowns")
    self.buffIconAnchor = self:CreateAnchor("OrbitBuffIconCooldowns", BUFFICON_INDEX, "Buff Icons")
    self.trackedAnchor = self:CreateTrackedAnchor("OrbitTrackedCooldowns", TRACKED_INDEX, "Tracked Cooldowns")

    VIEWER_MAP[ESSENTIAL_INDEX] = { viewer = EssentialCooldownViewer, anchor = self.essentialAnchor }
    VIEWER_MAP[UTILITY_INDEX] = { viewer = UtilityCooldownViewer, anchor = self.utilityAnchor }
    VIEWER_MAP[BUFFICON_INDEX] = { viewer = BuffIconCooldownViewer, anchor = self.buffIconAnchor }
    VIEWER_MAP[TRACKED_INDEX] = { viewer = nil, anchor = self.trackedAnchor, isTracked = true }

    -- Exclude Blizzard viewer frames from snap targets; Orbit anchor frames handle positioning
    for _, entry in pairs(VIEWER_MAP) do
        if entry.viewer then
            entry.viewer.orbitSnapExclude = true
        end
    end
    self.viewerMap = VIEWER_MAP

    self:SetupCanvasPreview(self.essentialAnchor, ESSENTIAL_INDEX)
    self:SetupCanvasPreview(self.utilityAnchor, UTILITY_INDEX)
    self:SetupCanvasPreview(self.buffIconAnchor, BUFFICON_INDEX)
    self:SetupTrackedCanvasPreview(self.trackedAnchor, TRACKED_INDEX)

    self:RestoreChildFrames()
    self:HookBlizzardViewers()
    self:StartTrackedUpdateTicker()
    self:RegisterCursorWatcher()
    self:SetupEditModeHooks()
    self:RegisterTalentWatcher()
    self:RegisterSpellCastWatcher()
    self:RestoreChargeBars()

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", self.OnPlayerEnteringWorld, self)
    self:RegisterVisibilityEvents()

    -- Reload tracked abilities and charge bars after a profile switch completes.
    -- This replaces the old PLAYER_SPECIALIZATION_CHANGED handler which raced
    -- against the ProfileManager's debounced profile switch.
    Orbit.EventBus:On("ORBIT_PROFILE_CHANGED", function()
        self:ReloadTrackedForSpec()
        self:ReparseActiveDurations()
    end, self)

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        if Orbit.OOCFadeMixin then
            for systemIndex, data in pairs(VIEWER_MAP) do
                local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
                if data.viewer then
                    Orbit.OOCFadeMixin:ApplyOOCFade(data.viewer, self, systemIndex, "OutOfCombatFade", enableHover)
                end
                if (data.isTracked or data.isChargeBar) and data.anchor then
                    Orbit.OOCFadeMixin:ApplyOOCFade(data.anchor, self, systemIndex, "OutOfCombatFade", enableHover)
                end
            end
            -- Also apply to tracked ability children
            for _, childData in pairs(self.activeChildren or {}) do
                if childData.frame then
                    local csi = childData.frame.systemIndex
                    local hover = self:GetSetting(csi, "ShowOnMouseover") ~= false
                    Orbit.OOCFadeMixin:ApplyOOCFade(childData.frame, self, csi, "OutOfCombatFade", hover)
                end
            end
            -- Also apply to charge bar children
            for _, childData in pairs(self.activeChargeChildren or {}) do
                if childData.frame then
                    local csi = childData.frame.systemIndex
                    local hover = self:GetSetting(csi, "ShowOnMouseover") ~= false
                    Orbit.OOCFadeMixin:ApplyOOCFade(childData.frame, self, csi, "OutOfCombatFade", hover)
                end
            end
            Orbit.OOCFadeMixin:RefreshAll()
        end
    end, self)
end

-- [ ANCHOR CREATION ]-------------------------------------------------------------------------------
function Plugin:CreateAnchor(name, systemIndex, label)
    local frame = CreateFrame("Frame", name, UIParent)
    OrbitEngine.Pixel:Enforce(frame)
    frame:SetSize(40, 40)
    frame:SetClampedToScreen(true)
    frame.systemIndex = systemIndex
    frame.editModeName = label
    frame:EnableMouse(false)
    frame.anchorOptions = { horizontal = true, vertical = true, syncScale = true, syncDimensions = false, useRowDimension = true }
    frame.orbitChainSync = true
    OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)

    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()

    if not frame:GetPoint() then
        if systemIndex == ESSENTIAL_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
        elseif systemIndex == UTILITY_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
        elseif systemIndex == BUFFICON_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        end
    end

    frame.OnAnchorChanged = function(self, parent, edge, padding)
        Plugin:ProcessChildren(self)
    end
    self:ApplySettings(frame)
    return frame
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplyAll()
    self:ReapplyParentage()
    if self.essentialAnchor then
        self:ApplySettings(self.essentialAnchor)
    end
    if self.utilityAnchor then
        self:ApplySettings(self.utilityAnchor)
    end
    if self.buffIconAnchor then
        self:ApplySettings(self.buffIconAnchor)
    end
    if self.trackedAnchor then
        self:ApplyTrackedSettings(self.trackedAnchor)
    end
    for _, childData in pairs(self.activeChildren or {}) do
        if childData.frame then
            self:ApplyTrackedSettings(childData.frame)
        end
    end
    if self.chargeBarAnchor then
        self:ApplyChargeBarSettings(self.chargeBarAnchor)
    end
    for _, childData in pairs(self.activeChargeChildren or {}) do
        if childData.frame then
            self:ApplyChargeBarSettings(childData.frame)
        end
    end
end

function Plugin:ApplySettings(frame)
    if not frame then
        self:ApplyAll()
        return
    end
    if InCombatLockdown() then
        return
    end
    if (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player")) then
        return
    end

    local systemIndex = frame.systemIndex
    local resolvedFrame = self:GetFrameBySystemIndex(systemIndex)
    if resolvedFrame then
        frame = resolvedFrame
    end
    if not frame or not frame.SetScale then
        return
    end

    if frame.isTrackedBar then
        self:ApplyTrackedSettings(frame)
        return
    end
    if frame.isChargeBar then
        self:ApplyChargeBarSettings(frame)
        return
    end

    local alpha = self:GetSetting(systemIndex, "Opacity") or 100
    OrbitEngine.NativeFrame:Modify(frame, { alpha = alpha / 100 })
    frame:Show()
    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)
    self:ProcessChildren(frame)
    OrbitEngine.Frame:DisableMouseRecursive(frame)
end

function Plugin:UpdateLayout(frame)
    if not frame or not frame.systemIndex then
        return
    end
    if frame.isTrackedBar then
        self:LayoutTrackedIcons(frame, frame.systemIndex)
    elseif frame.isChargeBar then
        return
    else
        self:ProcessChildren(frame)
    end
end

function Plugin:UpdateVisuals(frame)
    if frame then
        self:ApplySettings(frame)
    end
end

function Plugin:GetFrameBySystemIndex(systemIndex)
    local entry = VIEWER_MAP[systemIndex]
    return entry and entry.anchor or nil
end

-- [ CLEANUP ]---------------------------------------------------------------------------------------
function Plugin:OnDisable()
    if self.monitorTicker then
        self.monitorTicker:Cancel()
        self.monitorTicker = nil
    end
    if self.trackedTicker then
        self.trackedTicker:Cancel()
        self.trackedTicker = nil
    end
end
