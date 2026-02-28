---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local Helpers = nil
local CB = Orbit.BossFrameCastBar

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_BOSS_FRAMES = 5
local POWER_BAR_HEIGHT_RATIO = 0.2
local DEFAULT_DEBUFF_ICON_SIZE = 25
local DEFAULT_BUFF_ICON_SIZE = 20
local MARKER_ICON_SIZE = 16

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_BossFrames"

local Plugin = Orbit:RegisterPlugin("Boss Frames", SYSTEM_ID, {
    defaults = {
        Width = 120, Height = 25, Scale = 100, Spacing = 40,
        CastBarHeight = 18, CastBarWidth = 120, CastBarIcon = false,
        ReactionColour = true,
        PandemicGlowType = Orbit.Constants.PandemicGlow.DefaultType,
        PandemicGlowColor = Orbit.Constants.PandemicGlow.DefaultColor,
        PandemicGlowColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } },
        DisabledComponents = {},
        ComponentPositions = {
            Name = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT", posX = -55, posY = 0 },
            HealthText = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT", posX = 55, posY = 0 },
            Debuffs = { anchorX = "LEFT", anchorY = "CENTER", offsetX = -2, offsetY = 0, posX = -95, posY = 0, overrides = { MaxIcons = 4, IconSize = 25, MaxRows = 1 } },
            Buffs = { anchorX = "RIGHT", anchorY = "CENTER", offsetX = -2, offsetY = 0, posX = 95, posY = 0, overrides = { MaxIcons = 3, IconSize = 20, MaxRows = 1 } },
            CastBar = { anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 2, posX = 0, posY = -15, subComponents = { Text = { anchorX = "LEFT", anchorY = "CENTER", offsetX = 4, offsetY = 0, justifyH = "LEFT" }, Timer = { anchorX = "RIGHT", anchorY = "CENTER", offsetX = 4, offsetY = 0, justifyH = "RIGHT" } } },
        },
        CastBarColor = { r = 1, g = 0.7, b = 0 },
        CastBarColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0, a = 1 } } } },
        NonInterruptibleColor = { r = 0.7, g = 0.7, b = 0.7 },
        NonInterruptibleColorCurve = { pins = { { position = 0, color = { r = 0.7, g = 0.7, b = 0.7, a = 1 } } } },
        CastBarText = true, CastBarTimer = true,
    },
})

Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.BossFramePreviewMixin, Orbit.AuraMixin, Orbit.StatusIconMixin)
Plugin.canvasMode = true

-- [ CAST BAR FACADE ]-------------------------------------------------------------------------------
function Plugin:PositionCastBar(castBar, parent) CB:Position(castBar, parent, self) end

-- [ POWER BAR ]--------------------------------------------------------------------------------------
local function UpdateFrameLayout(frame, borderSize)
    Plugin:UpdateFrameLayout(frame, borderSize, { powerBarRatio = POWER_BAR_HEIGHT_RATIO })
end

local function CreatePowerBar(parent, unit)
    local power = CreateFrame("StatusBar", nil, parent)
    power:SetPoint("BOTTOMLEFT", 0, 0)
    power:SetPoint("BOTTOMRIGHT", 0, 0)
    power:SetHeight(parent:GetHeight() * POWER_BAR_HEIGHT_RATIO)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    power:SetMinMaxValues(0, 1)
    power:SetValue(0)
    power.unit = unit
    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(power, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)
    return power
end

local function UpdatePowerBar(frame)
    if not frame.Power or not UnitExists(frame.unit) then return end
    local power, maxPower, powerType = UnitPower(frame.unit), UnitPowerMax(frame.unit), UnitPowerType(frame.unit)
    frame.Power:SetMinMaxValues(0, maxPower)
    frame.Power:SetValue(power)
    local color = Orbit.Constants.Colors:GetPowerColor(powerType)
    frame.Power:SetStatusBarColor(color.r, color.g, color.b)
end

-- [ AURA DISPLAY CONFIG ]---------------------------------------------------------------------------
local function BossDebuffSkin(plugin)
    local Constants = Orbit.Constants
    return {
        zoom = 0, borderStyle = 1, borderSize = 1, showTimer = true, enablePandemic = true,
        pandemicGlowType = plugin:GetSetting(1, "PandemicGlowType") or Constants.PandemicGlow.DefaultType,
        pandemicGlowColor = OrbitEngine.ColorCurve:GetFirstColorFromCurve(plugin:GetSetting(1, "PandemicGlowColorCurve"))
            or plugin:GetSetting(1, "PandemicGlowColor") or Constants.PandemicGlow.DefaultColor,
    }
end

local BOSS_BUFF_SKIN = { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = true }
local BOSS_DEBUFF_CFG = { componentKey = "Debuffs", fetchFilter = "HARMFUL|PLAYER", tooltipFilter = "HARMFUL|PLAYER", defaultMaxIcons = 4, skinSettings = BossDebuffSkin, defaultAnchorX = "LEFT", defaultJustifyH = "LEFT", helpers = function() return Orbit.BossFrameHelpers end }
local BOSS_BUFF_CFG = { componentKey = "Buffs", fetchFilter = "HELPFUL", tooltipFilter = "HELPFUL", defaultMaxIcons = 3, skinSettings = BOSS_BUFF_SKIN, defaultAnchorX = "RIGHT", defaultJustifyH = "RIGHT", helpers = function() return Orbit.BossFrameHelpers end }

local function UpdateDebuffs(frame, plugin) plugin:UpdateAuraContainer(frame, plugin, "debuffContainer", "debuffPool", BOSS_DEBUFF_CFG) end
local function UpdateBuffs(frame, plugin) plugin:UpdateAuraContainer(frame, plugin, "buffContainer", "buffPool", BOSS_BUFF_CFG) end

-- [ BOSS FRAME CREATION ]----------------------------------------------------------------------------
local function CreateBossFrame(bossIndex, plugin)
    local unit = "boss" .. bossIndex
    local frame = OrbitEngine.UnitButton:Create(UIParent, unit, "OrbitBossFrame" .. bossIndex)
    if frame.HealthDamageBar then
        frame.HealthDamageBar:Hide()
        if frame.HealthDamageTexture then frame.HealthDamageTexture:Hide() end
        frame.HealthDamageBar = nil
    end
    frame.editModeName = "Boss Frame " .. bossIndex
    frame.systemIndex, frame.bossIndex = 1, bossIndex
    frame:SetSize(plugin:GetSetting(1, "Width") or 150, plugin:GetSetting(1, "Height") or 40)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(50 + bossIndex)
    UpdateFrameLayout(frame, Orbit.db.GlobalSettings.BorderSize)
    frame.Power = CreatePowerBar(frame, unit)
    frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)
    frame:SetScript("OnShow", function(self)
        self:UpdateAll(); UpdatePowerBar(self); UpdateFrameLayout(self, Orbit.db.GlobalSettings.BorderSize)
        UpdateDebuffs(self, plugin); UpdateBuffs(self, plugin); plugin:UpdateMarkerIcon(self, plugin)
    end)
    frame.debuffContainer = CreateFrame("Frame", nil, frame); frame.debuffContainer:SetSize(100, 20)
    frame.buffContainer = CreateFrame("Frame", nil, frame); frame.buffContainer:SetSize(100, 20)
    frame.StatusOverlay = CreateFrame("Frame", nil, frame)
    frame.StatusOverlay:SetAllPoints()
    frame.StatusOverlay:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Text)
    frame.MarkerIcon = frame.StatusOverlay:CreateTexture(nil, "OVERLAY")
    frame.MarkerIcon:SetSize(MARKER_ICON_SIZE, MARKER_ICON_SIZE)
    frame.MarkerIcon.orbitOriginalWidth, frame.MarkerIcon.orbitOriginalHeight = MARKER_ICON_SIZE, MARKER_ICON_SIZE
    frame.MarkerIcon:SetPoint("TOP", frame, "TOP", 0, -2)
    frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    frame.MarkerIcon:Hide()
    frame:RegisterUnitEvent("UNIT_AURA", unit)
    frame:RegisterEvent("RAID_TARGET_UPDATE")
    frame.CastBar = CB:Create(frame, bossIndex, plugin)
    CB:Position(frame.CastBar, frame, plugin)
    local originalOnEvent = frame:GetScript("OnEvent")
    frame:SetScript("OnEvent", function(f, event, eventUnit, ...)
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then if eventUnit == unit then UpdatePowerBar(f) end; return
        elseif event == "UNIT_AURA" then if eventUnit == unit then UpdateDebuffs(f, plugin); UpdateBuffs(f, plugin) end; return
        elseif event == "RAID_TARGET_UPDATE" then plugin:UpdateMarkerIcon(f, plugin); return end
        if originalOnEvent then originalOnEvent(f, event, eventUnit, ...) end
    end)
    frame.healthTextEnabled = true
    if frame.SetAbsorbsEnabled then frame:SetAbsorbsEnabled(true) end
    if frame.SetHealAbsorbsEnabled then frame:SetHealAbsorbsEnabled(true) end
    return frame
end

-- [ NATIVE FRAME HIDING ]----------------------------------------------------------------------------
local function HideNativeBossFrames()
    if BossTargetFrameContainer then
        BossTargetFrameContainer:ClearAllPoints()
        BossTargetFrameContainer:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
        BossTargetFrameContainer:SetAlpha(0)
        BossTargetFrameContainer:SetScale(0.001)
        BossTargetFrameContainer:EnableMouse(false)
    end
    for i = 1, MAX_BOSS_FRAMES do
        local bossFrame = _G["Boss" .. i .. "TargetFrame"]
        if bossFrame then
            bossFrame:ClearAllPoints()
            bossFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
            bossFrame:SetAlpha(0); bossFrame:SetScale(0.001); bossFrame:EnableMouse(false)
            if not bossFrame.orbitSetPointHooked then
                hooksecurefunc(bossFrame, "SetPoint", function(self)
                    if InCombatLockdown() then return end
                    if not self.isMovingOffscreen then
                        self.isMovingOffscreen = true
                        self:ClearAllPoints()
                        self:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
                        self.isMovingOffscreen = false
                    end
                end)
                bossFrame.orbitSetPointHooked = true
            end
        end
    end
end

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }
    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Auras" }, "Layout")
    if currentTab == "Layout" then
        table.insert(schema.controls, { type = "slider", key = "Width", label = "Width", min = 50, max = 400, step = 1, default = 150 })
        table.insert(schema.controls, { type = "slider", key = "Height", label = "Height", min = 10, max = 100, step = 1, default = 40 })
        table.insert(schema.controls, { type = "slider", key = "Spacing", label = "Spacing", min = 20, max = 100, step = 1, default = 40, formatter = function(v) return v .. "px" end })
    elseif currentTab == "Auras" then
        local GlowType = Orbit.Constants.PandemicGlow.Type
        table.insert(schema.controls, { type = "dropdown", key = "PandemicGlowType", label = "Pandemic Glow", options = { { text = "None", value = GlowType.None }, { text = "Pixel Glow", value = GlowType.Pixel }, { text = "Proc Glow", value = GlowType.Proc }, { text = "Autocast Shine", value = GlowType.Autocast }, { text = "Button Glow", value = GlowType.Button } }, default = Orbit.Constants.PandemicGlow.DefaultType })
        SB:AddColorCurveSettings(self, schema, 1, systemFrame, { key = "PandemicGlowColorCurve", label = "Pandemic Colour", default = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } }, singleColor = true })
    end
    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    HideNativeBossFrames()
    self.container = CreateFrame("Frame", "OrbitBossContainer", UIParent, "SecureHandlerStateTemplate")
    self.container.editModeName, self.container.systemIndex = "Boss Frames", 1
    self.container:SetFrameStrata("MEDIUM")
    self.container:SetFrameLevel(49)
    self.container:SetClampedToScreen(true)
    self.frames = {}
    for i = 1, MAX_BOSS_FRAMES do
        self.frames[i] = CreateBossFrame(i, self)
        self.frames[i]:SetParent(self.container)
        self.frames[i].orbitPlugin = self
        RegisterUnitWatch(self.frames[i])
        local bossIndex = i
        Orbit:SafeAction(function()
            if self.frames[bossIndex] and self.frames[bossIndex].CastBar then CB:SetupHooks(self.frames[bossIndex].CastBar, "boss" .. bossIndex) end
        end)
    end
    local pluginRef = self
    local firstFrame = self.frames[1]
    if OrbitEngine.ComponentDrag and firstFrame then
        for _, key in ipairs({ "Name", "HealthText" }) do
            local element = firstFrame[key]
            if element then OrbitEngine.ComponentDrag:Attach(element, self.container, { key = key, onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(pluginRef, 1, key) }) end
        end
        if not firstFrame.debuffContainer then firstFrame.debuffContainer = CreateFrame("Frame", nil, firstFrame); firstFrame.debuffContainer:SetSize(DEFAULT_DEBUFF_ICON_SIZE, DEFAULT_DEBUFF_ICON_SIZE) end
        OrbitEngine.ComponentDrag:Attach(firstFrame.debuffContainer, self.container, { key = "Debuffs", isAuraContainer = true, onPositionChange = OrbitEngine.ComponentDrag:MakeAuraPositionCallback(pluginRef, 1, "Debuffs") })
    end
    self.frame = self.container
    self.frame.anchorOptions = { horizontal = false, vertical = false, noAnchor = true }
    self.container.orbitCanvasFrame = self.frames[1]
    self.container.orbitCanvasTitle = "Boss Frame"
    if OrbitEngine.ComponentDrag and firstFrame then
        if not firstFrame.buffContainer then firstFrame.buffContainer = CreateFrame("Frame", nil, firstFrame); firstFrame.buffContainer:SetSize(DEFAULT_BUFF_ICON_SIZE, DEFAULT_BUFF_ICON_SIZE) end
        OrbitEngine.ComponentDrag:Attach(firstFrame.buffContainer, self.container, { key = "Buffs", isAuraContainer = true, onPositionChange = OrbitEngine.ComponentDrag:MakeAuraPositionCallback(pluginRef, 1, "Buffs") })
        if firstFrame.MarkerIcon then OrbitEngine.ComponentDrag:Attach(firstFrame.MarkerIcon, self.container, { key = "MarkerIcon", onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(pluginRef, 1, "MarkerIcon") }) end
        if firstFrame.CastBar then
            OrbitEngine.ComponentDrag:Attach(firstFrame.CastBar, self.container, {
                key = "CastBar",
                onPositionChange = function(comp, anchorX, anchorY, offsetX, offsetY, justifyH)
                    local positions = pluginRef:GetSetting(1, "ComponentPositions") or {}
                    local existingSubs = positions.CastBar and positions.CastBar.subComponents
                    positions.CastBar = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH, subComponents = existingSubs }
                    local compParent = comp:GetParent()
                    if compParent then
                        local cx, cy = comp:GetCenter()
                        local px, py = compParent:GetCenter()
                        if cx and px then positions.CastBar.posX = cx - px end
                        if cy and py then positions.CastBar.posY = cy - py end
                    end
                    pluginRef:SetSetting(1, "ComponentPositions", positions)
                end,
            })
        end
    end
    local dialog = OrbitEngine.CanvasModeDialog or Orbit.CanvasModeDialog
    if dialog and not self.canvasModeHooked then
        self.canvasModeHooked = true
        local originalOpen = dialog.Open
        dialog.Open = function(dlg, frame, plugin, systemIndex)
            if frame == self.container or frame == self.frames[1] then self:PrepareIconsForCanvasMode() end
            return originalOpen(dlg, frame, plugin, systemIndex)
        end
    end
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, 1)
    if not self.container:GetPoint() then self.container:SetPoint("RIGHT", UIParent, "RIGHT", -100, 100) end
    local BOSS_BASE_DRIVER = "[petbattle] hide; [@boss1,exists] show; [@boss2,exists] show; [@boss3,exists] show; [@boss4,exists] show; [@boss5,exists] show; hide"
    local function UpdateVisibilityDriver()
        if InCombatLockdown() or Orbit:IsEditMode() then return end
        local mv = Orbit.MountedVisibility
        local driver = (mv and mv:ShouldHide() and not IsMounted()) and "hide" or (mv and mv:GetMountedDriver(BOSS_BASE_DRIVER) or BOSS_BASE_DRIVER)
        RegisterStateDriver(self.container, "visibility", driver)
    end
    self.UpdateVisibilityDriver = function() UpdateVisibilityDriver() end
    UpdateVisibilityDriver()
    self.container:Show()
    self.container:SetSize(self:GetSetting(1, "Width") or 150, 100)
    self:PositionFrames()
    self:ApplySettings()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_TARGETABLE_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "UNIT_TARGETABLE_CHANGED" then
            for _, frame in ipairs(self.frames) do if frame.UpdateAll then frame:UpdateAll(); UpdatePowerBar(frame); UpdateDebuffs(frame, self) end end
        end
        if not InCombatLockdown() then self:UpdateContainerSize() end
    end)
    self:RegisterStandardEvents()
    if EventRegistry and not self.editModeCallbacksRegistered then
        self.editModeCallbacksRegistered = true
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            if not InCombatLockdown() then UnregisterStateDriver(self.container, "visibility"); self.container:Show(); self:UpdateContainerSize() end
            self:ShowPreview(); self:ApplySettings()
        end, self)
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            self:HidePreview()
            if not InCombatLockdown() then UpdateVisibilityDriver(); self:UpdateContainerSize() end
        end, self)
    end
    if not InCombatLockdown() then self:UpdateContainerSize() end
end

-- [ CANVAS MODE PREP ]-------------------------------------------------------------------------------
function Plugin:PrepareIconsForCanvasMode()
    local frame = self.frames[1]
    if not frame then return end
    if frame.MarkerIcon then
        frame.MarkerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        local SPRITE_INDEX, COLS, ROWS = 8, 4, 4
        local col = (SPRITE_INDEX - 1) % COLS
        local row = math.floor((SPRITE_INDEX - 1) / COLS)
        local w, h = 1 / COLS, 1 / ROWS
        frame.MarkerIcon:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
        frame.MarkerIcon:Show()
    end
    if frame.CastBar then
        local castBarHeight = self:GetSetting(1, "CastBarHeight") or 18
        local castBarWidth = self:GetSetting(1, "CastBarWidth") or 120
        local showIcon = self:GetSetting(1, "CastBarIcon")
        local iconOffset = 0
        frame.CastBar:SetSize(castBarWidth, castBarHeight)
        local textureName = self:GetSetting(1, "Texture") or self:GetPlayerSetting("Texture")
        local texturePath = textureName and LSM:Fetch("statusbar", textureName)
        if texturePath then frame.CastBar:SetStatusBarTexture(texturePath) end
        frame.CastBar:SetMinMaxValues(0, 2.0)
        frame.CastBar:SetValue(1.2)
        frame.CastBar.unit = "preview"
        if frame.CastBar.Icon then
            if showIcon then
                frame.CastBar.Icon:SetTexture(136243); frame.CastBar.Icon:SetSize(castBarHeight, castBarHeight); frame.CastBar.Icon:Show(); iconOffset = castBarHeight
                if frame.CastBar.IconBorder then frame.CastBar.IconBorder:Show() end
            else frame.CastBar.Icon:Hide(); if frame.CastBar.IconBorder then frame.CastBar.IconBorder:Hide() end end
        end
        local statusBarTexture = frame.CastBar:GetStatusBarTexture()
        if statusBarTexture then
            statusBarTexture:ClearAllPoints()
            statusBarTexture:SetPoint("TOPLEFT", frame.CastBar, "TOPLEFT", iconOffset, 0)
            statusBarTexture:SetPoint("BOTTOMLEFT", frame.CastBar, "BOTTOMLEFT", iconOffset, 0)
            statusBarTexture:SetPoint("TOPRIGHT", frame.CastBar, "TOPRIGHT", 0, 0)
            statusBarTexture:SetPoint("BOTTOMRIGHT", frame.CastBar, "BOTTOMRIGHT", 0, 0)
        end
        if frame.CastBar.bg then
            frame.CastBar.bg:ClearAllPoints()
            frame.CastBar.bg:SetPoint("TOPLEFT", frame.CastBar, "TOPLEFT", iconOffset, 0)
            frame.CastBar.bg:SetPoint("BOTTOMRIGHT", frame.CastBar, "BOTTOMRIGHT", 0, 0)
        end
        if frame.CastBar.Text then
            frame.CastBar.Text:ClearAllPoints()
            if showIcon and frame.CastBar.Icon then frame.CastBar.Text:SetPoint("LEFT", frame.CastBar.Icon, "RIGHT", 4, 0)
            else frame.CastBar.Text:SetPoint("LEFT", frame.CastBar, "LEFT", 4, 0) end
            frame.CastBar.Text:SetText("Boss Ability")
        end
        if frame.CastBar.Timer then frame.CastBar.Timer:SetText("1.5") end
        frame.CastBar:Show()
    end
end

-- [ POSITIONING ]------------------------------------------------------------------------------------
function Plugin:PositionFrames()
    if not self.frames or not self.container then return end
    local spacing = self:GetSetting(1, "Spacing") or 40
    for i, frame in ipairs(self.frames) do
        frame:ClearAllPoints()
        if i == 1 then frame:SetPoint("TOP", self.container, "TOP", 0, 0)
        else frame:SetPoint("TOP", self.frames[i - 1], "BOTTOM", 0, -spacing) end
    end
    self:UpdateContainerSize()
end

function Plugin:UpdateContainerSize()
    if not self.container or not self.frames then return end
    local width = self:GetSetting(1, "Width") or 150
    local scale = (self:GetSetting(1, "Scale") or 100) / 100
    local spacing = self:GetSetting(1, "Spacing") or 40
    local visibleCount = 0
    if self.isPreviewActive or Orbit:IsEditMode() then visibleCount = MAX_BOSS_FRAMES
    else for _, frame in ipairs(self.frames) do if frame:IsShown() then visibleCount = visibleCount + 1 end end end
    if visibleCount == 0 then visibleCount = MAX_BOSS_FRAMES end
    local frameHeight = self:GetSetting(1, "Height") or 40
    self.container:SetSize(width, visibleCount * frameHeight + (visibleCount - 1) * spacing)
    self.container:SetScale(scale)
end

-- [ SETTINGS APPLICATION ]---------------------------------------------------------------------------
function Plugin:ApplySettings()
    if not self.frames or InCombatLockdown() then return end
    local scale = self:GetSetting(1, "Scale") or 100
    local width = self:GetSetting(1, "Width") or 150
    local height = self:GetSetting(1, "Height") or 40
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or 14
    local castBarWidth = self:GetSetting(1, "CastBarWidth") or width
    local borderSize = self:GetSetting(1, "BorderSize") or self:GetPlayerSetting("BorderSize") or (Orbit.Engine.Pixel:Multiple(1, UIParent:GetEffectiveScale() or 1) or 1)
    local textureName = self:GetSetting(1, "Texture") or self:GetPlayerSetting("Texture")
    local fontName = self:GetSetting(1, "Font") or self:GetPlayerSetting("Font")
    local reactionColour = self:GetSetting(1, "ReactionColour")
    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 24, 0.25)
    for _, frame in ipairs(self.frames) do
        frame.borderSize = borderSize
        frame:SetSize(width, height)
        frame:SetScale(scale / 100)
        if frame.SetReactionColour then frame:SetReactionColour(reactionColour) end
        if frame.SetClassColour then frame:SetClassColour(not reactionColour) end
        frame:SetBorder(borderSize)
        UpdateFrameLayout(frame, borderSize)
        if frame.Health and textureName then Orbit.Skin:SkinStatusBar(frame.Health, textureName, nil, true) end
        if frame.Power and textureName then Orbit.Skin:SkinStatusBar(frame.Power, textureName, nil, true); if frame.Power.bg then frame.Power.bg:SetColorTexture(0, 0, 0, 0.5) end end
        Orbit.Skin:ApplyUnitFrameText(frame.Name, "LEFT", nil, textSize)
        Orbit.Skin:ApplyUnitFrameText(frame.HealthText, "RIGHT", nil, textSize)
        if frame.ApplyComponentPositions then frame:ApplyComponentPositions() end
        if frame.CastBar then
            local castBarDisabled = self.IsComponentDisabled and self:IsComponentDisabled("CastBar")
            if castBarDisabled then frame.CastBar:Hide()
            else
                frame.CastBar:SetSize(castBarWidth, castBarHeight)
                CB:Position(frame.CastBar, frame, self)
                if frame.CastBar.SetBorder then frame.CastBar:SetBorder(borderSize) end
                if textureName then Orbit.Skin:SkinStatusBar(frame.CastBar, textureName, nil, true) end
                local cbTextSize = Orbit.Skin:GetAdaptiveTextSize(castBarHeight, 10, 18, 0.40)
                local fontPath = LSM:Fetch("font", fontName)
                if frame.CastBar.Text then frame.CastBar.Text:SetFont(fontPath, cbTextSize, Orbit.Skin:GetFontOutline()) end
                if frame.CastBar.Timer then frame.CastBar.Timer:SetFont(fontPath, cbTextSize, Orbit.Skin:GetFontOutline()) end
                local componentPositions = self:GetSetting(1, "ComponentPositions") or {}
                local castData = componentPositions.CastBar or {}
                local subComps = castData.subComponents or {}
                local function ApplySubPos(element, subPos, defaultJustify)
                    if not element or not subPos then return end
                    element:ClearAllPoints()
                    local aX = subPos.anchorX or defaultJustify
                    local aY = subPos.anchorY or "CENTER"
                    local oX = subPos.offsetX or 4
                    local oY = subPos.offsetY or 0
                    local jH = subPos.justifyH or defaultJustify
                    local anchor = OrbitEngine.PositionUtils.BuildAnchorPoint(aX, aY)
                    local selfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor(true, false, aY, jH)
                    local fX, fY = oX, oY
                    if aX == "RIGHT" then fX = -fX end
                    if aY == "TOP" then fY = -fY end
                    element:SetPoint(selfAnchor, frame.CastBar, anchor, fX, fY)
                    element:SetJustifyH(jH)
                end
                ApplySubPos(frame.CastBar.Text, subComps.Text or { anchorX = "LEFT", anchorY = "CENTER", offsetX = 4, offsetY = 0, justifyH = "LEFT" }, "LEFT")
                ApplySubPos(frame.CastBar.Timer, subComps.Timer or { anchorX = "RIGHT", anchorY = "CENTER", offsetX = 4, offsetY = 0, justifyH = "RIGHT" }, "RIGHT")
                if frame.CastBar.Text then frame.CastBar.Text:SetShown(not (self.IsComponentDisabled and self:IsComponentDisabled("CastBar.Text"))) end
                if frame.CastBar.Timer then frame.CastBar.Timer:SetShown(not (self.IsComponentDisabled and self:IsComponentDisabled("CastBar.Timer"))) end
            end
        end
        frame:UpdateAll(); UpdatePowerBar(frame); UpdateDebuffs(frame, self); UpdateBuffs(frame, self); self:UpdateMarkerIcon(frame, self)
    end
    self:PositionFrames()
    OrbitEngine.Frame:RestorePosition(self.container, self, 1)
    if self.isPreviewActive then self:SchedulePreviewUpdate() end
end

function Plugin:UpdateVisuals()
    if not self.frames then return end
    for _, frame in ipairs(self.frames) do
        if not frame.preview and frame.unit and frame.UpdateAll then frame:UpdateAll(); UpdatePowerBar(frame); UpdateDebuffs(frame, self); UpdateBuffs(frame, self); self:UpdateMarkerIcon(frame, self) end
    end
end
