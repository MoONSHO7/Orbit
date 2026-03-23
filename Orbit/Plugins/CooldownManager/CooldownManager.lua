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

-- [ SPEC-SCOPED STORAGE ]--------------------------------------------------------------------------
-- Tracked Cooldowns and Charge Bars store data per-spec OUTSIDE of profiles.
-- Data lives in OrbitDB.SpecData[specID][systemIndex][key].
local TRACKED_CHILD_START = Constants.Cooldown.SystemIndex.Tracked_ChildStart
local TRACKED_CHILD_END = TRACKED_CHILD_START + Constants.Cooldown.MaxChildFrames - 1
local CHARGE_BAR_INDEX = Constants.Cooldown.SystemIndex.ChargeBar
local CHARGE_CHILD_START = Constants.Cooldown.SystemIndex.ChargeBar_ChildStart
local CHARGE_CHILD_END = CHARGE_CHILD_START + Constants.Cooldown.MaxChargeBarChildren - 1
local SPEC_SCOPED_KEYS = { TrackedItems = true, ChargeSpell = true, ChargeChildren = true, Position = true, Anchor = true }

local function IsSpecScopedIndex(sysIdx)
    return (sysIdx >= TRACKED_INDEX and sysIdx <= TRACKED_CHILD_END) or (sysIdx >= CHARGE_BAR_INDEX and sysIdx <= CHARGE_CHILD_END)
end

function Plugin:GetCurrentSpecID()
    local specIndex = GetSpecialization()
    return specIndex and GetSpecializationInfo(specIndex)
end

function Plugin:GetSpecData(systemIndex, key)
    local specID = self:GetCurrentSpecID()
    if not specID then return nil end
    local specStore = Orbit.db.SpecData and Orbit.db.SpecData[specID]
    if not specStore then return nil end
    local node = specStore[systemIndex]
    return node and node[key]
end

function Plugin:SetSpecData(systemIndex, key, value)
    local specID = self:GetCurrentSpecID()
    if not specID then return end
    if not Orbit.db.SpecData then Orbit.db.SpecData = {} end
    if not Orbit.db.SpecData[specID] then Orbit.db.SpecData[specID] = {} end
    if not Orbit.db.SpecData[specID][systemIndex] then Orbit.db.SpecData[specID][systemIndex] = {} end
    Orbit.db.SpecData[specID][systemIndex][key] = value
end

-- Override GetSetting/SetSetting to redirect spec-scoped keys for spec-scoped indices
local OriginalGetSetting = Orbit.PluginMixin.GetSetting
local OriginalSetSetting = Orbit.PluginMixin.SetSetting

function Plugin:GetSetting(systemIndex, key)
    if IsSpecScopedIndex(systemIndex) then
        local val = self:GetSpecData(systemIndex, key)
        return val
    end
    return OriginalGetSetting(self, systemIndex, key)
end

function Plugin:SetSetting(systemIndex, key, value)
    if IsSpecScopedIndex(systemIndex) then
        self:SetSpecData(systemIndex, key, value)
        return
    end
    OriginalSetSetting(self, systemIndex, key, value)
end

-- TODO(REMOVE): Legacy helper, only used by MigrateSpecData — remove after migration period
-- Generates a spec-specific settings key, e.g. "TrackedItems_267" (legacy, used for migration)
function Plugin:GetSpecKey(baseKey)
    local specID = self:GetCurrentSpecID()
    return baseKey .. "_" .. (specID or 0)
end

-- TODO(REMOVE): One-time migration from profile-keyed spec data to SpecData store
-- One-time migration: move GetSpecKey data from profiles into SpecData
function Plugin:MigrateSpecData()
    if Orbit.db.SpecData._migrated then return end
    local db = Orbit.runtime and Orbit.runtime.Layouts
    if not db then return end
    local layoutID = self:GetLayoutID()
    local profileData = db[layoutID] and db[layoutID][self.system]
    if not profileData then Orbit.db.SpecData._migrated = true; return end
    local MIGRATE_BASES = { "TrackedItems", "ChargeSpell", "ChargeChildren", "Position", "Anchor" }
    for sysIdx, node in pairs(profileData) do
        if type(node) == "table" and IsSpecScopedIndex(sysIdx) then
            for _, base in ipairs(MIGRATE_BASES) do
                for nodeKey, val in pairs(node) do
                    local specID = tostring(nodeKey):match("^" .. base .. "_(%d+)$")
                    if specID then
                        specID = tonumber(specID)
                        if not Orbit.db.SpecData[specID] then Orbit.db.SpecData[specID] = {} end
                        if not Orbit.db.SpecData[specID][sysIdx] then Orbit.db.SpecData[specID][sysIdx] = {} end
                        if not Orbit.db.SpecData[specID][sysIdx][base] then
                            Orbit.db.SpecData[specID][sysIdx][base] = val
                        end
                        node[nodeKey] = nil
                    end
                end
            end
        end
    end
    Orbit.db.SpecData._migrated = true
end

-- Ensure SpecData nodes exist for every class spec so spec-scoped reads never hit nil
function Plugin:SeedAllSpecSpatialData()
    local numSpecs = GetNumSpecializations()
    if not numSpecs or numSpecs == 0 then return end
    if not Orbit.db.SpecData then Orbit.db.SpecData = {} end
    local indices = { TRACKED_INDEX }
    for s = 0, Constants.Cooldown.MaxChildFrames - 1 do indices[#indices + 1] = TRACKED_CHILD_START + s end
    indices[#indices + 1] = CHARGE_BAR_INDEX
    for s = 0, Constants.Cooldown.MaxChargeBarChildren - 1 do indices[#indices + 1] = CHARGE_CHILD_START + s end
    for i = 1, numSpecs do
        local specID = GetSpecializationInfo(i)
        if specID then
            if not Orbit.db.SpecData[specID] then Orbit.db.SpecData[specID] = {} end
            for _, sysIdx in ipairs(indices) do
                if not Orbit.db.SpecData[specID][sysIdx] then Orbit.db.SpecData[specID][sysIdx] = {} end
            end
        end
    end
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
-- Flush tracked/charge bar spatial state from PositionManager to SpecData for a given specID.
-- Called before spec reload so the OLD spec's ephemeral position data is persisted.
function Plugin:FlushTrackedSpatial(specID)
    if not specID or not OrbitEngine.PositionManager then return end
    if not Orbit.db.SpecData then Orbit.db.SpecData = {} end
    if not Orbit.db.SpecData[specID] then Orbit.db.SpecData[specID] = {} end
    local function Flush(frame, systemIndex)
        if not frame then return end
        local pos = OrbitEngine.PositionManager:GetPosition(frame)
        local anch = OrbitEngine.PositionManager:GetAnchor(frame)
        if not Orbit.db.SpecData[specID][systemIndex] then Orbit.db.SpecData[specID][systemIndex] = {} end
        if anch and anch.target then
            Orbit.db.SpecData[specID][systemIndex]["Anchor"] = anch
            Orbit.db.SpecData[specID][systemIndex]["Position"] = nil
        elseif pos and pos.point then
            Orbit.db.SpecData[specID][systemIndex]["Position"] = pos
            Orbit.db.SpecData[specID][systemIndex]["Anchor"] = false
        end
    end
    local viewerMap = self.viewerMap
    if viewerMap then
        local entry = viewerMap[TRACKED_INDEX]
        if entry and entry.anchor then Flush(entry.anchor, TRACKED_INDEX) end
    end
    for _, childData in pairs(self.activeChildren or {}) do
        if childData.frame then Flush(childData.frame, childData.frame.systemIndex) end
    end
    if self.chargeBarAnchor then Flush(self.chargeBarAnchor, CHARGE_BAR_INDEX) end
    for _, childData in pairs(self.activeChargeChildren or {}) do
        if childData.frame then Flush(childData.frame, childData.frame.systemIndex) end
    end
end

Plugin.defaults = {
    ComponentPositions = {
        BuffBarName  = { anchorX = "LEFT",  anchorY = "CENTER", offsetX = 5, offsetY = 0, justifyH = "LEFT" },
        BuffBarTimer = { anchorX = "RIGHT", anchorY = "CENTER", offsetX = 5, offsetY = 0, justifyH = "RIGHT" },
    },
}

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    self:MigrateSpecData()
    self:SeedAllSpecSpatialData()
    self._lastSpecID = self:GetCurrentSpecID()
    self.essentialAnchor = self:CreateAnchor("OrbitEssentialCooldowns", ESSENTIAL_INDEX, "Essential Cooldowns")
    self.utilityAnchor = self:CreateAnchor("OrbitUtilityCooldowns", UTILITY_INDEX, "Utility Cooldowns")
    self.buffIconAnchor = self:CreateAnchor("OrbitBuffIconCooldowns", BUFFICON_INDEX, "Buff Icons")
    self.buffBarAnchor = self:CreateAnchor("OrbitBuffBarCooldowns", BUFFBAR_INDEX, "Buff Bars",
        { horizontal = false, vertical = true, syncScale = true, syncDimensions = true, mergeBorders = true })
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

    self:RestoreChildFrames()
    self:HookBlizzardViewers()
    self:StartTrackedUpdateTicker()
    self:RegisterCursorWatcher()
    self:SetupEditModeHooks()
    self:RegisterSpellCastWatcher()
    self:RestoreChargeBars()

    SetCVar("cooldownViewerEnabled", "1")

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", self.OnPlayerEnteringWorld, self)
    self:RegisterVisibilityEvents()

    -- Reload tracked abilities and charge bars after a profile switch completes.
    Orbit.EventBus:On("ORBIT_PROFILE_CHANGED", function()
        local newSpec = self:GetCurrentSpecID()
        if self._lastSpecID and self._lastSpecID ~= newSpec then
            self:FlushTrackedSpatial(self._lastSpecID)
        end
        self._lastSpecID = newSpec
        self:ReloadTrackedForSpec()
        self:ReparseActiveDurations()
        C_Timer.After(0.15, function()
            if Orbit.Engine.FrameAnchor then
                Orbit.Engine.FrameAnchor:RepairAllChains()
            end
        end)
    end, self)

    -- Reload spec-scoped data (tracked/charge bars) on spec change even without a profile mapping.
    Orbit.EventBus:On("PLAYER_SPECIALIZATION_CHANGED", function()
        local newSpec = self:GetCurrentSpecID()
        if self._lastSpecID == newSpec then
            return
        end
        self:FlushTrackedSpatial(self._lastSpecID)
        self._lastSpecID = newSpec
        C_Timer.After(0.15, function()
            self:ReloadTrackedForSpec()
            self:ReparseActiveDurations()
            self:ReapplyParentage()
            self:ApplyAll()
            if Orbit.ViewerInjection then Orbit.ViewerInjection:OnSpecChanged() end
            if Orbit.Engine.FrameAnchor then
                Orbit.Engine.FrameAnchor:RepairAllChains()
            end
        end)
    end, self)

    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        for systemIndex, data in pairs(VIEWER_MAP) do
            local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
            if data.viewer then
                if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(data.viewer, self, systemIndex, "OutOfCombatFade", enableHover) end
            end
            if (data.isTracked or data.isChargeBar) and data.anchor then
                if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(data.anchor, self, systemIndex, "OutOfCombatFade", enableHover) end
            end
            for _, childData in pairs(self.activeChildren or {}) do
                if childData.frame then
                    local csi = childData.frame.systemIndex
                    local hover = self:GetSetting(csi, "ShowOnMouseover") ~= false
                    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(childData.frame, self, csi, "OutOfCombatFade", hover) end
                end
            end
            -- Also apply to charge bar children
            for _, childData in pairs(self.activeChargeChildren or {}) do
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
    local shouldHide = (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player"))
        or (Orbit.MountedVisibility:ShouldHide())
    for _, data in pairs(VIEWER_MAP) do
        if data.anchor then
            local sysIdx = data.anchor.systemIndex
            local alpha = shouldHide and 0 or ((self:GetSetting(sysIdx, "Opacity") or 100) / 100)
            data.anchor.orbitMountedSuppressed = shouldHide or nil
            data.anchor:SetAlpha(alpha)
        end
    end
    for _, childData in pairs(self.activeChildren or {}) do
        if childData.frame then
            local csi = childData.frame.systemIndex
            local alpha = shouldHide and 0 or ((self:GetSetting(csi, "Opacity") or 100) / 100)
            childData.frame.orbitMountedSuppressed = shouldHide or nil
            childData.frame:SetAlpha(alpha)
        end
    end
    for _, childData in pairs(self.activeChargeChildren or {}) do
        if childData.frame then
            local csi = childData.frame.systemIndex
            local alpha = shouldHide and 0 or ((self:GetSetting(csi, "Opacity") or 100) / 100)
            childData.frame.orbitMountedSuppressed = shouldHide or nil
            childData.frame:SetAlpha(alpha)
        end
    end
    if not shouldHide then
        for _, data in pairs(VIEWER_MAP) do
            if data.anchor then self:ProcessChildren(data.anchor) end
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
    frame.anchorOptions = overrideOptions or { horizontal = true, vertical = true, syncScale = true, syncDimensions = false, useRowDimension = true, mergeBorders = true }
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
    if self._oocThrottleTimer then
        self._oocThrottleTimer:Cancel()
        self._oocThrottleTimer = nil
    end
end
