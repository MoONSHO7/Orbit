---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local ESSENTIAL_INDEX = Constants.Cooldown.SystemIndex.Essential
local UTILITY_INDEX = Constants.Cooldown.SystemIndex.Utility
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon
local TRACKED_INDEX = Constants.Cooldown.SystemIndex.Tracked
local BUFFBAR_INDEX = Constants.Cooldown.SystemIndex.BuffBar
local VIEWER_MAP = {}
local DEFAULT_ESSENTIAL_Y = -100
local DEFAULT_UTILITY_Y = -150
local DEFAULT_BUFFICON_Y = -200
local DEFAULT_BUFFBAR_X = 200
local DEFAULT_BUFFBAR_Y = -100

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Cooldown Manager", "Orbit_CooldownViewer", {
    defaults = {
        aspectRatio = "4:3",
        IconSize = Constants.Cooldown.DefaultIconSize,
        IconPadding = Constants.Cooldown.DefaultPadding,
        ActiveSwipeColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.95, b = 0.57, a = 0.7 } } } },
        CooldownSwipeColorCurve = { pins = { { position = 0, color = { r = 0, g = 0, b = 0, a = 0.8 } } } },
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
        AssistedHighlight = false,
    },
})

Plugin.canvasMode = true
Plugin.refreshPriority = true
Plugin.viewerMap = VIEWER_MAP

-- Per-system-index defaults (overrides shared defaults for specific viewers)
Plugin.indexDefaults = {
    [1] = { IconSize = 120, IconLimit = 12 }, -- Essential
    [2] = { IconSize = 90, IconLimit = 8 }, -- Utility
    [3] = { PandemicGlowType = 1 }, -- BuffIcon
    [30] = { PandemicGlowType = 1 }, -- BuffBar
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
function Plugin:OnCanvasApply() if self.buffBarAnchor then self:ProcessChildren(self.buffBarAnchor) end end
function Plugin:HookGCDSwipe() end
function Plugin:GetGrowthDirection()
    return "DOWN"
end
function Plugin:GetBaseFontSize()
    local s = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.TextScale or 1
    return 12 * s
end
function Plugin:GetGlobalFont()
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    if fontName and LSM then
        return LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    end
    return STANDARD_TEXT_FONT
end
function Plugin:GetTextOverlay() end
function Plugin:CreateKeybindText() end
function Plugin:ApplyTextSettings() end
function Plugin:SetupCanvasPreview() end

Plugin.defaults = {
    ComponentPositions = {
        BuffBarName  = { anchorX = "LEFT",  anchorY = "CENTER", offsetX = 5, offsetY = 0, justifyH = "LEFT" },
        BuffBarTimer = { anchorX = "RIGHT", anchorY = "CENTER", offsetX = 5, offsetY = 0, justifyH = "RIGHT" },
    },
}

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self.essentialAnchor = self:CreateAnchor("OrbitEssentialCooldowns", ESSENTIAL_INDEX, "Essential Cooldowns")
    self.utilityAnchor = self:CreateAnchor("OrbitUtilityCooldowns", UTILITY_INDEX, "Utility Cooldowns")
    self.buffIconAnchor = self:CreateAnchor("OrbitBuffIconCooldowns", BUFFICON_INDEX, "Buff Icons")
    self.buffBarAnchor = self:CreateAnchor("OrbitBuffBarCooldowns", BUFFBAR_INDEX, "Buff Bars",
        { horizontal = false, vertical = true, syncScale = true, syncDimensions = true })
    self.buffBarAnchor.orbitNoGroupSelect = true
    self.trackedAnchor = self:CreateTrackedAnchor("OrbitTrackedCooldowns", TRACKED_INDEX, "Tracked Cooldowns")

    VIEWER_MAP[ESSENTIAL_INDEX] = { viewer = EssentialCooldownViewer, anchor = self.essentialAnchor }
    VIEWER_MAP[UTILITY_INDEX] = { viewer = UtilityCooldownViewer, anchor = self.utilityAnchor }
    VIEWER_MAP[BUFFICON_INDEX] = { viewer = BuffIconCooldownViewer, anchor = self.buffIconAnchor }
    VIEWER_MAP[BUFFBAR_INDEX] = { viewer = BuffBarCooldownViewer, anchor = self.buffBarAnchor }
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

    -- BuffBar gets a bar-shaped canvas preview instead of icon grid
    local buffBarPlugin = self
    self.buffBarAnchor.CreateCanvasPreview = function(anchor, options)
        local parent = options.parent or UIParent
        local barH = buffBarPlugin:GetSetting(BUFFBAR_INDEX, "Height") or 20
        local barW = buffBarPlugin:GetSetting(BUFFBAR_INDEX, "Width") or 200

        local preview = CreateFrame("Frame", nil, parent)
        preview:SetSize(barW, barH)
        preview.sourceFrame = anchor
        preview.sourceWidth = barW
        preview.sourceHeight = barH
        preview.previewScale = 1
        preview.components = {}

        -- Icon (static decoration, outside left of bar)
        local iconSize = barH
        local icon = preview:CreateTexture(nil, "OVERLAY")
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("LEFT", preview, "LEFT", 0, 0)
        local iconTex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(21562) or "Interface\\Icons\\Spell_Holy_WordFortitude"
        icon:SetTexture(iconTex)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        -- Bar background (starts after icon)
        local bg = preview:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", preview, "TOPLEFT", iconSize, 0)
        bg:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", 0, 0)
        local bgColor = Orbit.Constants.Colors.Background
        bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)

        -- Bar fill (partial width to simulate remaining duration)
        local fill = preview:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", preview, "TOPLEFT", iconSize, 0)
        fill:SetPoint("BOTTOM", preview, "BOTTOM", 0, 0)
        fill:SetWidth((barW - iconSize) * 0.6)
        local LSM = LibStub("LibSharedMedia-3.0", true)
        local texturePath = LSM and LSM:Fetch("statusbar", Orbit.db.GlobalSettings.Texture or "Blizzard") or ""
        fill:SetTexture(texturePath)
        fill:SetVertexColor(0.3, 0.7, 1, 1)

        -- Border
        local borderSize = Orbit.db.GlobalSettings.BorderSize or 1
        Orbit.Skin:SkinBorder(preview, preview, borderSize, nil, true)

        -- Text sources
        local fontPath = buffBarPlugin:GetGlobalFont()
        local textSize = Orbit.Skin:GetAdaptiveTextSize(barH, 8, 14, 0.55)
        local name = preview:CreateFontString(nil, "OVERLAY", nil, 7)
        name:SetFont(fontPath, textSize, Orbit.Skin:GetFontOutline())
        name:SetPoint("LEFT", preview, "LEFT", iconSize + 5, 0)
        name:SetText("Preview Buff")
        name:SetTextColor(1, 1, 1, 1)

        local timer = preview:CreateFontString(nil, "OVERLAY", nil, 7)
        timer:SetFont(fontPath, textSize, Orbit.Skin:GetFontOutline())
        timer:SetPoint("RIGHT", preview, "RIGHT", -5, 0)
        timer:SetText("12.4")
        timer:SetTextColor(1, 1, 1, 1)

        -- Register text components for Canvas Mode drag
        local savedPositions = buffBarPlugin:GetSetting(BUFFBAR_INDEX, "ComponentPositions") or {}
        local barW2 = barW / 2
        local namePos = savedPositions["BuffBarName"]
        local timerPos = savedPositions["BuffBarTimer"]
        local nameX = namePos and namePos.posX or (-barW2 + name:GetStringWidth() / 2 + iconSize + 5)
        local nameY = namePos and namePos.posY or 0
        local timerX = timerPos and timerPos.posX or (barW2 - timer:GetStringWidth() / 2 - 5)
        local timerY = timerPos and timerPos.posY or 0

        local CDC = OrbitEngine.CanvasMode.CreateDraggableComponent
        if CDC then
            local nameComp = CDC(preview, "BuffBarName", name, nameX, nameY, namePos)
            local timerComp = CDC(preview, "BuffBarTimer", timer, timerX, timerY, timerPos)
            local fl = preview:GetFrameLevel() + 10
            if nameComp then nameComp:SetFrameLevel(fl) end
            if timerComp then timerComp:SetFrameLevel(fl) end
            name:Hide()
            timer:Hide()
            if nameComp then preview.components["BuffBarName"] = nameComp end
            if timerComp then preview.components["BuffBarTimer"] = timerComp end
        end

        return preview
    end

    self:RestoreChildFrames()
    self:HookBlizzardViewers()
    self:StartTrackedUpdateTicker()
    self:RegisterCursorWatcher()
    self:SetupEditModeHooks()
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
        for systemIndex, data in pairs(VIEWER_MAP) do
            local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
            if data.viewer then
                Orbit.OOCFadeMixin:ApplyOOCFade(data.viewer, self, systemIndex, "OutOfCombatFade", enableHover)
            end
            if (data.isTracked or data.isChargeBar) and data.anchor then
                Orbit.OOCFadeMixin:ApplyOOCFade(data.anchor, self, systemIndex, "OutOfCombatFade", enableHover)
            end
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

function Plugin:UpdateVisibility()
    local shouldHide = (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player"))
        or (Orbit.MountedVisibility:ShouldHide())
    local alpha = shouldHide and 0 or 1
    for _, data in pairs(VIEWER_MAP) do
        if data.anchor then
            data.anchor.orbitMountedSuppressed = shouldHide or nil
            data.anchor:SetAlpha(alpha)
        end
    end
    for _, childData in pairs(self.activeChildren or {}) do
        if childData.frame then
            childData.frame.orbitMountedSuppressed = shouldHide or nil
            childData.frame:SetAlpha(alpha)
        end
    end
    for _, childData in pairs(self.activeChargeChildren or {}) do
        if childData.frame then
            childData.frame.orbitMountedSuppressed = shouldHide or nil
            childData.frame:SetAlpha(alpha)
        end
    end
end

-- [ ANCHOR CREATION ]-------------------------------------------------------------------------------
function Plugin:CreateAnchor(name, systemIndex, label, overrideOptions)
    local frame = CreateFrame("Frame", name, UIParent)
    OrbitEngine.Pixel:Enforce(frame)
    frame:SetSize(40, 40)
    frame:SetClampedToScreen(true)
    frame.systemIndex = systemIndex
    frame.editModeName = label
    frame:EnableMouse(false)
    frame.anchorOptions = overrideOptions or { horizontal = true, vertical = true, syncScale = true, syncDimensions = false, useRowDimension = true }
    frame.orbitChainSync = true
    OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)

    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()

    if not frame:GetPoint() then
        if systemIndex == ESSENTIAL_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_ESSENTIAL_Y)
        elseif systemIndex == UTILITY_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_UTILITY_Y)
        elseif systemIndex == BUFFICON_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_BUFFICON_Y)
        elseif systemIndex == BUFFBAR_INDEX then
            frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_BUFFBAR_X, DEFAULT_BUFFBAR_Y)
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
    if self.buffBarAnchor then
        self:ApplySettings(self.buffBarAnchor)
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

    local isMountedHidden = Orbit.MountedVisibility:ShouldHide()
    local alpha = self:GetSetting(systemIndex, "Opacity") or 100
    OrbitEngine.NativeFrame:Modify(frame, { alpha = isMountedHidden and 0 or (alpha / 100) })
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
    if self._monitorEventFrame then
        self._monitorEventFrame:UnregisterAllEvents()
    end
    if self._trackedEventFrame then
        self._trackedEventFrame:UnregisterAllEvents()
    end
    if self._chargeEventFrame then
        self._chargeEventFrame:UnregisterAllEvents()
    end
    if self.chargeUpdateTicker then
        self.chargeUpdateTicker:Cancel()
        self.chargeUpdateTicker = nil
    end
    if self._pandemicTicker then
        self._pandemicTicker:Cancel()
        self._pandemicTicker = nil
    end
    if self._oocThrottleTimer then
        self._oocThrottleTimer:Cancel()
        self._oocThrottleTimer = nil
    end
end
