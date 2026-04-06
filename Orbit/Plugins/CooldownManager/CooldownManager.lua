---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ] ---------------------------------------------------------------
local ESSENTIAL_INDEX = Constants.Cooldown.SystemIndex.Essential
local UTILITY_INDEX = Constants.Cooldown.SystemIndex.Utility
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon
local BUFFBAR_INDEX = Constants.Cooldown.SystemIndex.BuffBar
local VIEWER_MAP = {}
local DEFAULT_ESSENTIAL_Y = -100
local DEFAULT_UTILITY_Y = -150
local DEFAULT_BUFFICON_Y = -200
local DEFAULT_BUFFBAR_X = 200
local DEFAULT_BUFFBAR_Y = -100

-- [ PLUGIN REGISTRATION ] -----------------------------------------------------
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
            BuffBarName  = { anchorX = "LEFT",  anchorY = "CENTER", offsetX = 5, offsetY = 0, justifyH = "LEFT" },
            BuffBarTimer = { anchorX = "RIGHT", anchorY = "CENTER", offsetX = 5, offsetY = 0, justifyH = "RIGHT" },
        },
        PandemicGlowType = Constants.Glow.Type.Pixel,
        PandemicGlowColor = Constants.Glow.DefaultColor,
        ProcGlowType = Constants.Glow.Type.Medium,
        ProcGlowColor = Constants.Glow.DefaultColor,
        OutOfCombatFade = false,
        ShowOnMouseover = true,
        KeypressColor = { r = 1, g = 1, b = 1, a = 0 },
        AssistedHighlight = false,
    },
})

Plugin.canvasMode = true
Plugin.refreshPriority = true
Plugin.viewerMap = VIEWER_MAP

-- Per-system-index defaults (overrides shared defaults for specific viewers)
Plugin.indexDefaults = {
    [1] = { IconSize = 34, IconLimit = 12 }, -- Essential
    [2] = { IconSize = 34, IconLimit = 8 }, -- Utility
    [3] = { PandemicGlowType = 1 }, -- BuffIcon
    [30] = { PandemicGlowType = 1 }, -- BuffBar
}



-- [ STUBS - Overwritten by sub-modules ] --------------------------------------
function Plugin:AddSettings() end
function Plugin:IsComponentDisabled()
    return false
end
function Plugin:HookProcGlow() end
function Plugin:CheckPandemicFrames() end
function Plugin:MarkPandemicDirty() end
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
    return 12
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



-- [ LIFECYCLE ] ---------------------------------------------------------------
function Plugin:OnLoad()
    self.essentialAnchor = self:CreateAnchor("OrbitEssentialCooldowns", ESSENTIAL_INDEX, "Essential Cooldowns")
    self.utilityAnchor = self:CreateAnchor("OrbitUtilityCooldowns", UTILITY_INDEX, "Utility Cooldowns")
    self.buffIconAnchor = self:CreateAnchor("OrbitBuffIconCooldowns", BUFFICON_INDEX, "Buff Icons")
    self.buffBarAnchor = self:CreateAnchor("OrbitBuffBarCooldowns", BUFFBAR_INDEX, "Buff Bars",
        { horizontal = false, vertical = true, syncScale = false, syncDimensions = true, mergeBorders = true })
    self.buffBarAnchor.orbitNoGroupSelect = true
    VIEWER_MAP[ESSENTIAL_INDEX] = { viewer = EssentialCooldownViewer, anchor = self.essentialAnchor }
    VIEWER_MAP[UTILITY_INDEX] = { viewer = UtilityCooldownViewer, anchor = self.utilityAnchor }
    VIEWER_MAP[BUFFICON_INDEX] = { viewer = BuffIconCooldownViewer, anchor = self.buffIconAnchor }
    VIEWER_MAP[BUFFBAR_INDEX] = { viewer = BuffBarCooldownViewer, anchor = self.buffBarAnchor }

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
        Orbit.Skin:SkinBorder(preview, preview, borderSize)

        -- Text sources
        local fontPath = buffBarPlugin:GetGlobalFont()
        local textSize = 8
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
    self:HookBlizzardViewers()
    SetCVar("cooldownViewerEnabled", "1")

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", self.OnPlayerEnteringWorld, self)
    self:RegisterVisibilityEvents()

    -- Reload items after a profile switch completes.
    Orbit.EventBus:On("ORBIT_PROFILE_CHANGED", function()
        C_Timer.After(0.15, function()
            -- TODO: Phase 3 — replace RepairAllChains with targeted ReconcileChain
            if Orbit.Engine.FrameAnchor then
                Orbit.Engine.FrameAnchor:RepairAllChains()
            end
        end)
    end, self)

    Orbit.EventBus:On("PLAYER_SPECIALIZATION_CHANGED", function()
        C_Timer.After(0.15, function()
            self:ReapplyParentage()
            self:ApplyAll()
            if Orbit.ViewerInjection then Orbit.ViewerInjection:OnSpecChanged() end
            -- TODO: Phase 3 — replace RepairAllChains with targeted ReconcileChain
            if Orbit.Engine.FrameAnchor then
                Orbit.Engine.FrameAnchor:RepairAllChains()
            end
        end)
    end, self)

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        for systemIndex, data in pairs(VIEWER_MAP) do
            local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
            if data.anchor then
                if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(data.anchor, self, systemIndex, "OutOfCombatFade", enableHover) end
            end
            for _, childData in pairs(self.activeChildren or {}) do
                if childData.frame then
                    local csi = childData.frame.systemIndex
                    local hover = self:GetSetting(csi, "ShowOnMouseover") ~= false
                    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(childData.frame, self, csi, "OutOfCombatFade", hover) end
                end
            end
            if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
        end
    end, self)

    -- Initialize viewer injection (drag-and-drop items into Essential/Utility)
    if Orbit.ViewerInjection then Orbit.ViewerInjection:Initialize() end
end

function Plugin:UpdateVisibility()
    local isMounted = Orbit.MountedVisibility:IsCachedHidden()
    local isPetBattle = (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player"))
    local inCombat = InCombatLockdown()
    for _, data in pairs(VIEWER_MAP) do
        if data.anchor then
            local sysIdx = data.anchor.systemIndex
            local veKey = Orbit.VisibilityEngine and Orbit.VisibilityEngine:GetKeyForPlugin(self.name, sysIdx)
            local isMountedHidden = (isMounted and veKey and Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted"))
            local frameHideAlpha = isMountedHidden and 0 or ((self:GetSetting(sysIdx, "Opacity") or 100) / 100)
            data.anchor.orbitMountedSuppressed = isMountedHidden or nil
            if not inCombat then
                if isPetBattle then data.anchor.orbitHiddenByAlpha = false; data.anchor:Hide()
                else data.anchor:Show() end
            end
            data.anchor:SetAlpha(frameHideAlpha)
        end
    end
    for _, childData in pairs(self.activeChildren or {}) do
        if childData.frame then
            local csi = childData.frame.systemIndex
            local veKey = Orbit.VisibilityEngine and Orbit.VisibilityEngine:GetKeyForPlugin(self.name, csi)
            local isMountedHidden = (isMounted and veKey and Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted"))
            local frameHideAlpha = isMountedHidden and 0 or ((self:GetSetting(csi, "Opacity") or 100) / 100)
            childData.frame.orbitMountedSuppressed = isMountedHidden or nil
            if not inCombat then
                if isPetBattle then childData.frame.orbitHiddenByAlpha = false; childData.frame:Hide()
                else childData.frame:Show() end
            end
            childData.frame:SetAlpha(frameHideAlpha)
        end
    end
    if not isPetBattle then
        for _, data in pairs(VIEWER_MAP) do
            if data.anchor and not data.anchor.orbitMountedSuppressed then self:ProcessChildren(data.anchor) end
        end
    end
end

-- [ ANCHOR CREATION ] ---------------------------------------------------------
function Plugin:CreateAnchor(name, systemIndex, label, overrideOptions)
    local frame = CreateFrame("Frame", name, UIParent)
    OrbitEngine.Pixel:Enforce(frame)
    frame:SetSize(40, 40)
    frame:SetClampedToScreen(true)
    frame.systemIndex = systemIndex
    frame.editModeName = label
    frame:EnableMouse(false)
    frame.anchorOptions = overrideOptions or { horizontal = true, vertical = true, syncScale = false, syncDimensions = false, useRowDimension = true, mergeBorders = true }
    frame.orbitChainSync = true
    frame.orbitCursorReveal = true
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

-- [ SETTINGS APPLICATION ] ----------------------------------------------------
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
        frame:Hide()
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

    if frame.isChargeBar then
        return
    end

    local veKey = Orbit.VisibilityEngine and Orbit.VisibilityEngine:GetKeyForPlugin(self.name, systemIndex)
    local isMountedHidden = Orbit.MountedVisibility:IsCachedHidden() and veKey and Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted")
    local alpha = (self:GetSetting(systemIndex, "Opacity") or 100) / 100
    if isMountedHidden then
        frame:SetAlpha(0)
        frame:Show()
        return
    end
    Orbit.Animation:ApplyHoverFade(frame, alpha, 1, Orbit:IsEditMode())
    frame:Show()
    OrbitEngine.Frame:RestorePosition(frame, self, systemIndex)
    self:ProcessChildren(frame)
    OrbitEngine.Frame:DisableMouseRecursive(frame)
end

function Plugin:UpdateLayout(frame)
    if not frame or not frame.systemIndex then
        return
    end
    self:ProcessChildren(frame)
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

-- [ SPEC DATA HELPER ] --------------------------------------------------------
function Plugin:GetCurrentSpecID()
    local specIndex = GetSpecialization()
    return specIndex and GetSpecializationInfo(specIndex)
end

function Plugin:GetSpecData(systemIndex, key)
    local specID = self:GetCurrentSpecID()
    if not specID then return nil end
    if not Orbit.db.SpecData then Orbit.db.SpecData = {} end
    if not Orbit.db.SpecData[specID] then Orbit.db.SpecData[specID] = {} end
    if not Orbit.db.SpecData[specID][systemIndex] then Orbit.db.SpecData[specID][systemIndex] = {} end
    return Orbit.db.SpecData[specID][systemIndex][key]
end

function Plugin:SetSpecData(systemIndex, key, value)
    local specID = self:GetCurrentSpecID()
    if not specID then return end
    if not Orbit.db.SpecData then Orbit.db.SpecData = {} end
    if not Orbit.db.SpecData[specID] then Orbit.db.SpecData[specID] = {} end
    if not Orbit.db.SpecData[specID][systemIndex] then Orbit.db.SpecData[specID][systemIndex] = {} end
    Orbit.db.SpecData[specID][systemIndex][key] = value
end

-- [ CLEANUP ] -----------------------------------------------------------------
function Plugin:OnDisable()
    if self._monitorEventFrame then
        self._monitorEventFrame:UnregisterAllEvents()
    end
    if self._oocThrottleTimer then
        self._oocThrottleTimer:Cancel()
        self._oocThrottleTimer = nil
    end
end
