---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local Helpers = nil -- Loaded from BossFrameHelpers.lua

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_BOSS_FRAMES = 5
local POWER_BAR_HEIGHT_RATIO = 0.2

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_BossFrames"

local Plugin = Orbit:RegisterPlugin("Boss Frames", SYSTEM_ID, {
    defaults = {
        Width = 120,
        Height = 25,
        Scale = 100,
        DebuffPosition = "Left",
        CastBarPosition = "Below",
        DebuffSize = 32,
        MaxDebuffs = 4,
        CastBarHeight = 18,
        CastBarWidth = 120,
        CastBarIcon = false,
        ReactionColour = true,
        PandemicGlowType = Orbit.Constants.PandemicGlow.DefaultType,
        PandemicGlowColor = Orbit.Constants.PandemicGlow.DefaultColor,
        PandemicGlowColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } },
        DisabledComponents = {},
        CastBarColor = { r = 1, g = 0.7, b = 0 },
        CastBarColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0, a = 1 } } } },
        NonInterruptibleColor = { r = 0.7, g = 0.7, b = 0.7 },
        NonInterruptibleColorCurve = { pins = { { position = 0, color = { r = 0.7, g = 0.7, b = 0.7, a = 1 } } } },
        CastBarText = true,
        CastBarTimer = true,
    },
})

Mixin(Plugin, Orbit.UnitFrameMixin, Orbit.BossFramePreviewMixin, Orbit.AuraMixin)

-- [ POWER BAR ]--------------------------------------------------------------------------------------
local function UpdateFrameLayout(frame, borderSize)
    Plugin:UpdateFrameLayout(frame, borderSize, { powerBarRatio = POWER_BAR_HEIGHT_RATIO })
end

local function CreatePowerBar(parent, unit, plugin)
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
    if not frame.Power then
        return
    end
    local unit = frame.unit
    if not UnitExists(unit) then
        return
    end

    local power, maxPower, powerType = UnitPower(unit), UnitPowerMax(unit), UnitPowerType(unit)
    frame.Power:SetMinMaxValues(0, maxPower)
    frame.Power:SetValue(power)
    local color = Orbit.Constants.Colors:GetPowerColor(powerType)
    frame.Power:SetStatusBarColor(color.r, color.g, color.b)
end

-- [ DEBUFF DISPLAY ]---------------------------------------------------------------------------------
local function UpdateDebuffs(frame, plugin)
    if not frame.debuffContainer then
        return
    end
    local position = plugin:GetSetting(1, "DebuffPosition")
    if position == "Disabled" then
        frame.debuffContainer:Hide()
        frame.debuffContainer:SetSize(0, 0)
        frame.debuffContainer:ClearAllPoints()
        return
    end
    local unit = frame.unit
    if not UnitExists(unit) then
        frame.debuffContainer:Hide()
        frame.debuffContainer:SetSize(0, 0)
        return
    end

    local isHorizontal = (position == "Above" or position == "Below")
    local frameHeight = frame:GetHeight()
    local frameWidth = frame:GetWidth()
    local maxDebuffs = plugin:GetSetting(1, "MaxDebuffs") or 4

    if not Helpers then
        Helpers = Orbit.BossFrameHelpers
    end
    local spacing = Helpers.LAYOUT.Spacing
    local iconSize, xOffsetStep = Helpers:CalculateDebuffLayout(isHorizontal, frameWidth, frameHeight, maxDebuffs, spacing)

    if not frame.debuffPool then
        frame.debuffPool = CreateFramePool("Button", frame.debuffContainer, "BackdropTemplate")
    end
    frame.debuffPool:ReleaseAll()
    local debuffs = plugin:FetchAuras(unit, "HARMFUL|PLAYER", maxDebuffs)
    if #debuffs == 0 then
        frame.debuffContainer:Hide()
        frame.debuffContainer:SetSize(0, 0)
        return
    end

    local castBarPos = plugin:GetSetting(1, "CastBarPosition")
    local castBarHeight = plugin:GetSetting(1, "CastBarHeight") or 14
    Helpers:PositionDebuffContainer(frame.debuffContainer, frame, position, #debuffs, iconSize, spacing, castBarPos, castBarHeight)

    local globalBorder, Constants = Orbit.db.GlobalSettings.BorderSize, Orbit.Constants
    local skinSettings = {
        zoom = 0,
        borderStyle = 1,
        borderSize = globalBorder,
        showTimer = true,
        enablePandemic = true,
        pandemicGlowType = plugin:GetSetting(1, "PandemicGlowType") or Constants.PandemicGlow.DefaultType,
        pandemicGlowColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(plugin:GetSetting(1, "PandemicGlowColorCurve"))
            or plugin:GetSetting(1, "PandemicGlowColor")
            or Constants.PandemicGlow.DefaultColor,
    }

    local currentX = 0
    for i, aura in ipairs(debuffs) do
        local icon = frame.debuffPool:Acquire()
        icon:SetSize(iconSize, iconSize)

        currentX = Helpers:PositionDebuffIcon(icon, frame.debuffContainer, isHorizontal, position, currentX, iconSize, xOffsetStep, spacing)
        plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)
        plugin:SetupAuraTooltip(icon, aura, unit, "HARMFUL|PLAYER")
    end
    frame.debuffContainer:Show()
    if not InCombatLockdown() then
        plugin:PositionFrames()
    end
end

-- [ CAST BAR ]--------------------------------------------------------------------------------------
local function ResolveCastBarColor(plugin)
    return OrbitEngine.WidgetLogic:GetFirstColorFromCurve(plugin:GetSetting(1, "CastBarColorCurve"))
        or plugin:GetSetting(1, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
end

local function ResolveNonInterruptibleColor(plugin)
    return OrbitEngine.WidgetLogic:GetFirstColorFromCurve(plugin:GetSetting(1, "NonInterruptibleColorCurve"))
        or plugin:GetSetting(1, "NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
end

local function CreateBossCastBar(parent, bossIndex, plugin)
    local bar = CreateFrame("StatusBar", "OrbitBoss" .. bossIndex .. "CastBar", parent)
    bar:SetSize(150, 14)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    bar:SetStatusBarColor(1, 0.7, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(bar, globalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)

    bar.SetBorder = function(self, size)
        Orbit.Skin:SkinBorder(self, self, size, nil, true)
    end

    bar:SetBorder(1)

    bar.Icon = bar:CreateTexture(nil, "ARTWORK", nil, Orbit.Constants.Layers.Icon)
    bar.Icon:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Icon)
    bar.Icon:SetSize(14, 14)
    bar.Icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    bar.Icon:Hide()

    bar.IconBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.IconBorder:SetAllPoints(bar.Icon)
    bar.IconBorder:SetFrameLevel(bar:GetFrameLevel() + Orbit.Constants.Levels.Border)
    Orbit.Skin:SkinBorder(bar, bar.IconBorder, 1, { r = 0, g = 0, b = 0, a = 1 }, true)
    bar.IconBorder:Hide()

    bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Text:SetPoint("LEFT", 4, 0)
    bar.Text:SetJustifyH("LEFT")
    bar.Text:SetShadowColor(0, 0, 0, 1)
    bar.Text:SetShadowOffset(1, -1)

    bar.Timer = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Timer:SetPoint("RIGHT", -4, 0)
    bar.Timer:SetJustifyH("RIGHT")
    bar.Timer:SetShadowColor(0, 0, 0, 1)
    bar.Timer:SetShadowOffset(1, -1)

    bar.bossIndex = bossIndex
    bar.unit = "boss" .. bossIndex
    bar.plugin = plugin

    return bar
end

function Plugin:PositionCastBar(castBar, parent, position)
    castBar:ClearAllPoints()
    if position == "Above" then
        castBar:SetPoint("BOTTOM", parent, "TOP", 0, 2)
    else -- Below
        castBar:SetPoint("TOP", parent, "BOTTOM", 0, -2)
    end
end

local function SetupCastBarHooks(castBar, unit)
    local nativeSpellbar = _G["Boss" .. castBar.bossIndex .. "TargetFrameSpellBar"]
    if not nativeSpellbar then
        return
    end
    local plugin = castBar.plugin

    nativeSpellbar:HookScript("OnShow", function(nativeBar)
        if not castBar then
            return
        end

        local showIcon = plugin:GetSetting(1, "CastBarIcon")
        local castBarHeight = castBar:GetHeight()
        local iconOffset = 0

        local iconTexture
        if nativeBar.Icon then
            iconTexture = nativeBar.Icon:GetTexture()
        end
        if not iconTexture and C_Spell.GetSpellTexture and nativeBar.spellID then
            iconTexture = C_Spell.GetSpellTexture(nativeBar.spellID)
        end

        if castBar.Icon then
            if showIcon then
                castBar.Icon:SetTexture(iconTexture or 136243)
                castBar.Icon:SetSize(castBarHeight, castBarHeight)
                castBar.Icon:Show()
                iconOffset = castBarHeight
                if castBar.IconBorder then
                    castBar.IconBorder:Show()
                end

                if castBar.Borders and castBar.Borders.Left then
                    castBar.Borders.Left:Hide()
                end
            else
                castBar.Icon:Hide()
                if castBar.IconBorder then
                    castBar.IconBorder:Hide()
                end

                if castBar.Borders and castBar.Borders.Left then
                    castBar.Borders.Left:Show()
                end
            end
        end

        local statusBarTexture = castBar:GetStatusBarTexture()
        if statusBarTexture then
            statusBarTexture:ClearAllPoints()
            statusBarTexture:SetPoint("TOPLEFT", castBar, "TOPLEFT", iconOffset, 0)
            statusBarTexture:SetPoint("BOTTOMLEFT", castBar, "BOTTOMLEFT", iconOffset, 0)
            statusBarTexture:SetPoint("TOPRIGHT", castBar, "TOPRIGHT", 0, 0)
            statusBarTexture:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
        end

        if castBar.bg then
            castBar.bg:ClearAllPoints()
            castBar.bg:SetPoint("TOPLEFT", castBar, "TOPLEFT", iconOffset, 0)
            castBar.bg:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
        end

        local showText = plugin:GetSetting(1, "CastBarText")
        if castBar.Text then
            castBar.Text:ClearAllPoints()
            if showText then
                castBar.Text:Show()
                if showIcon and castBar.Icon then
                    castBar.Text:SetPoint("LEFT", castBar.Icon, "RIGHT", 4, 0)
                else
                    castBar.Text:SetPoint("LEFT", castBar, "LEFT", 4, 0)
                end
                if nativeBar.Text then
                    castBar.Text:SetText(nativeBar.Text:GetText() or "Casting...")
                end
            else
                castBar.Text:Hide()
            end
        end

        local showTimer = plugin:GetSetting(1, "CastBarTimer")
        if castBar.Timer then
            castBar.Timer:SetShown(showTimer)
        end

        local min, max = nativeBar:GetMinMaxValues()
        if min and max then
            castBar:SetMinMaxValues(min, max)
            castBar:SetValue(nativeBar:GetValue() or 0)
        end

        local color = nativeBar.notInterruptible and ResolveNonInterruptibleColor(plugin) or ResolveCastBarColor(plugin)
        castBar:SetStatusBarColor(color.r, color.g, color.b)

        castBar:Show()
    end)

    nativeSpellbar:HookScript("OnHide", function()
        if castBar then
            castBar:Hide()
        end
    end)

    local timerThrottle, timerInterval = 0, 1 / 30
    nativeSpellbar:HookScript("OnUpdate", function(nativeBar, elapsed)
        if not castBar or not castBar:IsShown() then return end

        local progress = nativeBar:GetValue()
        local min, max = nativeBar:GetMinMaxValues()
        if not progress or not max then return end
        castBar:SetMinMaxValues(min, max)
        castBar:SetValue(progress)

        timerThrottle = timerThrottle + elapsed
        if timerThrottle < timerInterval then return end
        timerThrottle = 0
        if not castBar.Timer or not castBar.Timer:IsShown() then return end

        local getDurationFn = nativeBar.channeling and UnitChannelDuration or UnitCastingDuration
        if not getDurationFn then return end
        local ok, dur = pcall(getDurationFn, unit)
        if not ok or not dur then return end
        local getter = dur.GetRemainingDuration or dur.GetRemaining
        if not getter then return end
        local okR, remaining = pcall(getter, dur)
        if okR and remaining then
            castBar.Timer:SetFormattedText("%.1f", remaining)
        end
    end)

    nativeSpellbar:HookScript("OnEvent", function(nativeBar, event, eventUnit)
        if eventUnit ~= unit or not castBar or not castBar:IsShown() then
            return
        end

        local color
        if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            castBar:SetStatusBarColor(1, 0, 0)
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            color = ResolveNonInterruptibleColor(plugin)
            castBar:SetStatusBarColor(color.r, color.g, color.b)
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            color = ResolveCastBarColor(plugin)
            castBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    end)
end

-- [ BOSS FRAME CREATION ]----------------------------------------------------------------------------
local function CreateBossFrame(bossIndex, plugin)
    local unit = "boss" .. bossIndex
    local frameName = "OrbitBossFrame" .. bossIndex

    local frame = OrbitEngine.UnitButton:Create(UIParent, unit, frameName)
    if frame.HealthDamageBar then
        frame.HealthDamageBar:Hide()
        if frame.HealthDamageTexture then frame.HealthDamageTexture:Hide() end
        frame.HealthDamageBar = nil
    end
    frame.editModeName = "Boss Frame " .. bossIndex
    frame.systemIndex = 1
    frame.bossIndex = bossIndex

    local width = plugin:GetSetting(1, "Width") or 150
    local height = plugin:GetSetting(1, "Height") or 40
    frame:SetSize(width, height)

    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(50 + bossIndex)

    UpdateFrameLayout(frame, Orbit.db.GlobalSettings.BorderSize)

    frame.Power = CreatePowerBar(frame, unit, plugin)

    frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)

    frame:SetScript("OnShow", function(self)
        self:UpdateAll()
        UpdatePowerBar(self)
        UpdateFrameLayout(self, Orbit.db.GlobalSettings.BorderSize)
        UpdateDebuffs(self, plugin)
    end)

    frame.debuffContainer = CreateFrame("Frame", nil, frame)
    frame.debuffContainer:SetSize(100, 20)

    frame:RegisterUnitEvent("UNIT_AURA", unit)

    frame.CastBar = CreateBossCastBar(frame, bossIndex, plugin)
    plugin:PositionCastBar(frame.CastBar, frame, "Below")

    local originalOnEvent = frame:GetScript("OnEvent")
    frame:SetScript("OnEvent", function(f, event, eventUnit, ...)
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            if eventUnit == unit then
                UpdatePowerBar(f)
            end
            return
        elseif event == "UNIT_AURA" then
            if eventUnit == unit then
                UpdateDebuffs(f, plugin)
            end
            return
        end

        if originalOnEvent then
            originalOnEvent(f, event, eventUnit, ...)
        end
    end)

    frame.healthTextEnabled = true
    if frame.SetAbsorbsEnabled then
        frame:SetAbsorbsEnabled(true)
    end
    if frame.SetHealAbsorbsEnabled then
        frame:SetHealAbsorbsEnabled(true)
    end

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
            bossFrame:SetAlpha(0)
            bossFrame:SetScale(0.001)
            bossFrame:EnableMouse(false)

            if not bossFrame.orbitSetPointHooked then
                hooksecurefunc(bossFrame, "SetPoint", function(self)
                    if InCombatLockdown() then
                        return
                    end
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
    local systemIndex = 1
    local WL = OrbitEngine.WidgetLogic

    local schema = { hideNativeSettings = true, controls = {} }

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Auras" }, "Layout")

    if currentTab == "Layout" then
        table.insert(schema.controls, { type = "slider", key = "Width", label = "Width", min = 50, max = 400, step = 1, default = 150 })
        table.insert(schema.controls, { type = "slider", key = "Height", label = "Height", min = 10, max = 100, step = 1, default = 40 })
        table.insert(schema.controls, {
            type = "dropdown",
            key = "CastBarPosition",
            label = "Cast Bar",
            options = { { label = "Above", value = "Above" }, { label = "Below", value = "Below" } },
            default = "Below",
        })
        table.insert(schema.controls, { type = "slider", key = "CastBarHeight", label = "Cast Bar Height", min = 15, max = 35, step = 1, default = 14 })
        table.insert(schema.controls, { type = "checkbox", key = "CastBarIcon", label = "Show Cast Bar Icon", default = true })
    elseif currentTab == "Auras" then
        table.insert(schema.controls, {
            type = "dropdown",
            key = "DebuffPosition",
            label = "Debuffs",
            options = {
                { label = "Disabled", value = "Disabled" },
                { label = "Left", value = "Left" },
                { label = "Right", value = "Right" },
                { label = "Above", value = "Above" },
                { label = "Below", value = "Below" },
            },
            default = "Right",
        })
        table.insert(schema.controls, { type = "slider", key = "MaxDebuffs", label = "Max Debuffs", min = 2, max = 8, step = 1, default = 4 })
        local GlowType = Orbit.Constants.PandemicGlow.Type
        table.insert(schema.controls, {
            type = "dropdown",
            key = "PandemicGlowType",
            label = "Pandemic Glow",
            options = {
                { text = "None", value = GlowType.None },
                { text = "Pixel Glow", value = GlowType.Pixel },
                { text = "Proc Glow", value = GlowType.Proc },
                { text = "Autocast Shine", value = GlowType.Autocast },
                { text = "Button Glow", value = GlowType.Button },
            },
            default = Orbit.Constants.PandemicGlow.DefaultType,
        })
        WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "PandemicGlowColorCurve",
            label = "Pandemic Colour",
            default = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } },
            singleColor = true,
        })
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
        RegisterUnitWatch(self.frames[i])
        local bossIndex = i
        Orbit:SafeAction(function()
            if self.frames[bossIndex] and self.frames[bossIndex].CastBar then
                SetupCastBarHooks(self.frames[bossIndex].CastBar, "boss" .. bossIndex)
            end
        end)
    end

    self.frame = self.container
    self.frame.anchorOptions = { horizontal = false, vertical = false, noAnchor = true }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, 1)

    if not self.container:GetPoint() then
        self.container:SetPoint("RIGHT", UIParent, "RIGHT", -100, 100)
    end

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

        if
            event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT"
            or event == "PLAYER_REGEN_DISABLED"
            or event == "PLAYER_REGEN_ENABLED"
            or event == "UNIT_TARGETABLE_CHANGED"
        then
            for i, frame in ipairs(self.frames) do
                if frame.UpdateAll then
                    frame:UpdateAll()
                    UpdatePowerBar(frame)
                    UpdateDebuffs(frame, self)
                end
            end
        end

        if not InCombatLockdown() then
            self:UpdateContainerSize()
        end
    end)

    self:RegisterStandardEvents()

    if EventRegistry and not self.editModeCallbacksRegistered then
        self.editModeCallbacksRegistered = true

        EventRegistry:RegisterCallback("EditMode.Enter", function()

            if not InCombatLockdown() then
                UnregisterStateDriver(self.container, "visibility")
                self.container:Show()
                self:UpdateContainerSize()
            end

            self:ShowPreview()
            self:ApplySettings()
        end, self)

        EventRegistry:RegisterCallback("EditMode.Exit", function()
            self:HidePreview()

            if not InCombatLockdown() then
                UpdateVisibilityDriver()
                self:UpdateContainerSize()
            end
        end, self)
    end

    if not InCombatLockdown() then
        self:UpdateContainerSize()
    end
end

function Plugin:CalculateFrameSpacing(index)
    local castBarPos = self:GetSetting(1, "CastBarPosition") or "Below"
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or 14
    local castBarGap = 2

    local debuffPos = self:GetSetting(1, "DebuffPosition") or "Right"
    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 4
    local frameWidth = self:GetSetting(1, "Width") or 150
    local spacing = 2
    local iconSize = 0

    if debuffPos == "Above" or debuffPos == "Below" then
        local totalSpacing = (maxDebuffs - 1) * spacing
        iconSize = (frameWidth - totalSpacing) / maxDebuffs
    else
        -- Side positioning doesn't affect vertical spacing
        iconSize = 0
    end

    local topPadding = 0
    local bottomPadding = 0
    local elementGap = 2

    if castBarPos == "Above" then
        topPadding = topPadding + castBarHeight + castBarGap
    elseif castBarPos == "Below" then
        bottomPadding = bottomPadding + castBarHeight + castBarGap
    end

    if debuffPos == "Above" then
        topPadding = topPadding + iconSize + elementGap
    elseif debuffPos == "Below" then
        bottomPadding = bottomPadding + iconSize + elementGap
    end

    return topPadding, bottomPadding
end

function Plugin:PositionFrames()
    if not self.frames or not self.container then
        return
    end
    local baseSpacing = 2
    local frameHeight = self:GetSetting(1, "Height") or 40

    for i, frame in ipairs(self.frames) do
        frame:ClearAllPoints()
        local topPadding, bottomPadding = self:CalculateFrameSpacing(i)
        frame.layoutHeight = frameHeight + topPadding + bottomPadding

        if i == 1 then
            frame:SetPoint("TOP", self.container, "TOP", 0, -topPadding)
        else
            local prevTop, prevBottom = self:CalculateFrameSpacing(i - 1)
            frame:SetPoint("TOP", self.frames[i - 1], "BOTTOM", 0, -(prevBottom + baseSpacing + topPadding))
        end
    end

    self:UpdateContainerSize()
end

function Plugin:UpdateContainerSize()
    if not self.container or not self.frames then
        return
    end
    local width = self:GetSetting(1, "Width") or 150
    local scale = (self:GetSetting(1, "Scale") or 100) / 100
    local baseSpacing = 2
    local isEditMode = Orbit:IsEditMode()
    local isPreviewActive = self.isPreviewActive
    local visibleCount, lastVisibleIndex = 0, 0
    if isPreviewActive or isEditMode then
        visibleCount, lastVisibleIndex = MAX_BOSS_FRAMES, MAX_BOSS_FRAMES
    else
        for i, frame in ipairs(self.frames) do
            if frame:IsShown() then
                visibleCount, lastVisibleIndex = visibleCount + 1, i
            end
        end
    end
    if visibleCount == 0 then
        visibleCount, lastVisibleIndex = MAX_BOSS_FRAMES, MAX_BOSS_FRAMES
    end
    local topPaddingFirst, _ = self:CalculateFrameSpacing(1)
    local totalHeight = topPaddingFirst

    for i = 1, lastVisibleIndex do
        totalHeight = totalHeight + self.frames[i]:GetHeight()
        local _, b = self:CalculateFrameSpacing(i)
        if i < lastVisibleIndex then
            local _, prevB = self:CalculateFrameSpacing(i)
            local nextT, _ = self:CalculateFrameSpacing(i + 1)
            totalHeight = totalHeight + prevB + baseSpacing + nextT
        else
            totalHeight = totalHeight + b
        end
    end

    self.container:SetSize(width, totalHeight)
    self.container:SetScale(scale)
end

-- [ SETTINGS APPLICATION ]---------------------------------------------------------------------------
function Plugin:ApplySettings()
    if not self.frames or InCombatLockdown() then
        return
    end

    local scale = self:GetSetting(1, "Scale") or 100
    local width = self:GetSetting(1, "Width") or 150
    local height = self:GetSetting(1, "Height") or 40
    local castBarPosition = self:GetSetting(1, "CastBarPosition") or "Below"
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or 14

    local borderSize = self:GetSetting(1, "BorderSize") or self:GetPlayerSetting("BorderSize") or (Orbit.Engine.Pixel and Orbit.Engine.Pixel:Multiple(1, UIParent:GetEffectiveScale() or 1) or 1)
    local textureName = self:GetSetting(1, "Texture") or self:GetPlayerSetting("Texture")
    local fontName = self:GetSetting(1, "Font") or self:GetPlayerSetting("Font")
    local reactionColour = self:GetSetting(1, "ReactionColour")

    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 24, 0.25)

    local texturePath = LSM:Fetch("statusbar", textureName)

    for i, frame in ipairs(self.frames) do

        frame.borderSize = borderSize

        frame:SetSize(width, height)
        frame:SetScale(scale / 100)

        if frame.SetReactionColour then
            frame:SetReactionColour(reactionColour)
        end
        if frame.SetClassColour then
            frame:SetClassColour(not reactionColour)
        end

        frame:SetBorder(borderSize)

        UpdateFrameLayout(frame, borderSize)

        if frame.Health and textureName then
            Orbit.Skin:SkinStatusBar(frame.Health, textureName, nil, true)
        end
        if frame.Power and textureName then
            Orbit.Skin:SkinStatusBar(frame.Power, textureName, nil, true)
            if frame.Power.bg then
                frame.Power.bg:SetColorTexture(0, 0, 0, 0.5)
            end
        end

        Orbit.Skin:ApplyUnitFrameText(frame.Name, "LEFT", nil, textSize)
        Orbit.Skin:ApplyUnitFrameText(frame.HealthText, "RIGHT", nil, textSize)

        if frame.CastBar then
            frame.CastBar:SetSize(width, castBarHeight)
            self:PositionCastBar(frame.CastBar, frame, castBarPosition)

            if frame.CastBar.SetBorder then
                frame.CastBar:SetBorder(borderSize)
            end

            if textureName then
                Orbit.Skin:SkinStatusBar(frame.CastBar, textureName, nil, true)
            end

            local cbTextSize = Orbit.Skin:GetAdaptiveTextSize(castBarHeight, 10, 18, 0.40)
            local fontPath = LSM:Fetch("font", fontName)
            if frame.CastBar.Text then
                frame.CastBar.Text:SetFont(fontPath, cbTextSize, Orbit.Skin:GetFontOutline())
            end
            if frame.CastBar.Timer then
                frame.CastBar.Timer:SetFont(fontPath, cbTextSize, Orbit.Skin:GetFontOutline())
            end
        end

        frame:UpdateAll()
        UpdatePowerBar(frame)
        UpdateDebuffs(frame, self)
    end

    self:PositionFrames()

    OrbitEngine.Frame:RestorePosition(self.container, self, 1)

    if self.isPreviewActive then
        self:SchedulePreviewUpdate()
    end
end

function Plugin:UpdateVisuals()
    if not self.frames then
        return
    end

    for i, frame in ipairs(self.frames) do
        if frame.UpdateAll then
            frame:UpdateAll()
        end
        UpdatePowerBar(frame)
        UpdateDebuffs(frame, self)
    end
end
