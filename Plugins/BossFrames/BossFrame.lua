local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MAX_BOSS_FRAMES = 5
local POWER_BAR_HEIGHT_RATIO = 0.2 -- 20% of frame height

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_BossFrames"

local Plugin = Orbit:RegisterPlugin("Boss Frames", SYSTEM_ID, {
    defaults = {
        Width = 140,
        Height = 40,
        Scale = 100,
        DebuffPosition = "Above", -- "Disabled", "Left", "Right", "Above"
        CastBarPosition = "Below", -- "Above", "Below"
        DebuffSize = 32,
        MaxDebuffs = 4,
        CastBarHeight = 15,
        CastBarWidth = 140,
        CastBarIcon = true,
        ReactionColour = true, -- Enable reaction color by default
    },
}, Orbit.Constants.PluginGroups.BossFrames)

-- Mixin Preview Logic
Mixin(Plugin, Orbit.BossFramePreviewMixin, Orbit.AuraMixin)

-- Helper to get global settings from Player Frame
function Plugin:GetPlayerSetting(key)
    local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
    if playerPlugin and playerPlugin.GetSetting then
        return playerPlugin:GetSetting(1, key)
    end
    return nil
end

-- Helper to get settings from Player Cast Bar
function Plugin:GetCastBarSetting(key)
    local castBarPlugin = Orbit:GetPlugin("Orbit_PlayerCastBar")
    if castBarPlugin and castBarPlugin.GetSetting then
        return castBarPlugin:GetSetting(1, key)
    end
    return nil
end

-- [ HELPERS ]---------------------------------------------------------------------------------------

-- Use centralized power colors from Constants
local function GetPowerColor(powerType)
    return Orbit.Constants.Colors.PowerType[powerType] or { r = 0.5, g = 0.5, b = 0.5 }
end

-- [ POWER BAR CREATION & UPDATE ]-------------------------------------------------------------------

local function UpdateFrameLayout(frame, borderSize)
    local height = frame:GetHeight()
    if height < 1 then
        return
    end -- Guard against uninitialized height

    local powerHeight = height * (POWER_BAR_HEIGHT_RATIO or 0.2)
    local inset = math.max(1, borderSize) -- Ensure minimal inset

    if frame.Power then
        frame.Power:ClearAllPoints()
        -- Inset by border size to ensure main border is visible around it
        frame.Power:SetPoint("BOTTOMLEFT", inset, inset)
        frame.Power:SetPoint("BOTTOMRIGHT", -inset, inset)
        frame.Power:SetHeight(powerHeight)
        -- Ensure Power is above Health
        frame.Power:SetFrameLevel(frame:GetFrameLevel() + 3)
    end

    if frame.Health then
        frame.Health:ClearAllPoints()
        frame.Health:SetPoint("TOPLEFT", inset, -inset)
        -- Ensure Health is below Power
        frame.Health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, powerHeight + inset)
        frame.Health:SetFrameLevel(frame:GetFrameLevel() + 2)

        -- Sync HealthDamageBar to Health position so red damage chunk appears correctly behind Health
        if frame.HealthDamageBar then
            frame.HealthDamageBar:ClearAllPoints()
            frame.HealthDamageBar:SetAllPoints(frame.Health)
            frame.HealthDamageBar:SetFrameLevel(frame:GetFrameLevel() + 1)
        end
    end
end

local function CreatePowerBar(parent, unit, plugin)
    local power = CreateFrame("StatusBar", nil, parent)
    power:SetPoint("BOTTOMLEFT", 1, 1)
    power:SetPoint("BOTTOMRIGHT", -1, 1)
    power:SetHeight(parent:GetHeight() * POWER_BAR_HEIGHT_RATIO)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")

    power:SetMinMaxValues(0, 1)
    power:SetValue(0)
    power.unit = unit

    -- Background
    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()

    local color = plugin:GetSetting(1, "BackdropColour")
    if color then
        power.bg:SetColorTexture(color.r, color.g, color.b, color.a or 0.5)
    else
        local bg = Orbit.Constants.Colors.Background
        power.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    end

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

    -- Get power values - pass directly to SetValue (no arithmetic)
    local power = UnitPower(unit)
    local maxPower = UnitPowerMax(unit)
    local powerType = UnitPowerType(unit)

    frame.Power:SetMinMaxValues(0, maxPower)
    frame.Power:SetValue(power) -- Safe: SetValue accepts secret values

    -- Update color based on power type (powerType is safe to read)
    local color = GetPowerColor(powerType)
    frame.Power:SetStatusBarColor(color.r, color.g, color.b)
end

-- [ DEBUFF DISPLAY ]--------------------------------------------------------------------------------

local function UpdateDebuffs(frame, plugin)
    if not frame.debuffContainer then
        return
    end

    local position = plugin:GetSetting(1, "DebuffPosition")
    if position == "Disabled" then
        frame.debuffContainer:Hide()
        -- Reset size for spacing calculations
        frame.debuffContainer:SetSize(0, 0)
        -- Reset anchor for spacing
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
    local spacing = 2

    -- Calculate Size & Layout
    local iconSize, xOffsetStep, yOffsetStep
    if isHorizontal then
        -- Dynamic sizing: Fit columns within Frame Width
        -- Width = (N * Size) + ((N-1) * Spacing)
        -- Size = (Width - ((N-1) * Spacing)) / N
        local totalSpacing = (maxDebuffs - 1) * spacing
        iconSize = (frameWidth - totalSpacing) / maxDebuffs

        -- Clamp max size to reasonable limit if needed, but for now trusting dynamic
        xOffsetStep = iconSize + spacing
        yOffsetStep = 0
    else
        -- Side positioning: Match Frame Height (legacy behavior)
        iconSize = frameHeight
        xOffsetStep = 0
        yOffsetStep = 0 -- Not used for side growth logic below
    end

    -- Initialize pool if needed
    if not frame.debuffPool then
        -- Use generic Button instead of CompactAuraTemplate to ensure full control over cooldown frame settings
        frame.debuffPool = CreateFramePool("Button", frame.debuffContainer, "BackdropTemplate")
    end
    frame.debuffPool:ReleaseAll()

    -- Collect player-applied debuffs
    local debuffs = plugin:FetchAuras(unit, "HARMFUL|PLAYER", maxDebuffs)

    if #debuffs == 0 then
        frame.debuffContainer:Hide()
        frame.debuffContainer:SetSize(0, 0)
        return
    end

    -- Position container based on setting & collisions
    frame.debuffContainer:ClearAllPoints()

    local castBarPos = plugin:GetSetting(1, "CastBarPosition")
    local castBarHeight = plugin:GetSetting(1, "CastBarHeight") or 14
    local castBarGap = 4 -- Gap between frame and castbar
    local elementGap = 4 -- Gap between elements

    if position == "Left" then
        frame.debuffContainer:SetPoint("RIGHT", frame, "LEFT", -4, 0)
        frame.debuffContainer:SetSize((#debuffs * iconSize) + ((#debuffs - 1) * spacing), iconSize)
    elseif position == "Right" then
        frame.debuffContainer:SetPoint("LEFT", frame, "RIGHT", 4, 0)
        frame.debuffContainer:SetSize((#debuffs * iconSize) + ((#debuffs - 1) * spacing), iconSize)
    elseif position == "Above" then
        -- Check collision with CastBar
        local yOffset = elementGap
        if castBarPos == "Above" then
            yOffset = yOffset + castBarHeight + castBarGap
        end
        frame.debuffContainer:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, yOffset)
        frame.debuffContainer:SetSize(frameWidth, iconSize)
    elseif position == "Below" then
        -- Check collision with CastBar
        local yOffset = -elementGap
        if castBarPos == "Below" then
            yOffset = yOffset - castBarHeight - castBarGap
        end
        frame.debuffContainer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, yOffset)
        frame.debuffContainer:SetSize(frameWidth, iconSize)
    end

    -- Prepare Skin Settings
    local globalBorder = plugin:GetPlayerSetting("BorderSize")
    local skinSettings = {
        zoom = 0, -- Inherit/Default
        borderStyle = 1, -- Pixel Perfect
        borderSize = globalBorder,
        showTimer = true,
    }

    -- Layout icons
    local currentX = 0
    for i, aura in ipairs(debuffs) do
        local icon = frame.debuffPool:Acquire()
        icon:ClearAllPoints()

        if isHorizontal then
            -- Grow Right
            icon:SetPoint("TOPLEFT", frame.debuffContainer, "TOPLEFT", currentX, 0)
            currentX = currentX + xOffsetStep
        elseif position == "Left" then
            -- Grow Left: First icon at Right edge
            icon:SetPoint("TOPRIGHT", frame.debuffContainer, "TOPRIGHT", -currentX, 0)
            currentX = currentX + iconSize + spacing
        else -- Right
            -- Grow Right: First icon at Left edge
            icon:SetPoint("TOPLEFT", frame.debuffContainer, "TOPLEFT", currentX, 0)
            currentX = currentX + iconSize + spacing
        end

        -- Use Mixin for setup (Icon, Cooldown, Count, Skin)
        plugin:SetupAuraIcon(icon, aura, iconSize, unit, skinSettings)

        -- Use Mixin for Tooltip (Edge-aware)
        -- Explicitly pass "HARMFUL|PLAYER" as filter since we used GetDebuffDataByIndex with "PLAYER"
        plugin:SetupAuraTooltip(icon, aura, unit, "HARMFUL|PLAYER")
    end

    frame.debuffContainer:Show()

    -- Notify parent to update layout spacing if container visibility/size changed
    -- (Only if not in combat, PositionFrames is protected-ish)
    if not InCombatLockdown() then
        -- We can't call PositionFrames directly recursively efficiently, but we can trigger it.
        -- Optimization: Trigger only if size materially affects layout (TODO)
        plugin:PositionFrames()
    end
end

-- [ CAST BAR ]--------------------------------------------------------------------------------------

local function CreateBossCastBar(parent, bossIndex, plugin)
    local bar = CreateFrame("StatusBar", "OrbitBoss" .. bossIndex .. "CastBar", parent)
    bar:SetSize(150, 14)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    bar:SetStatusBarColor(1, 0.7, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()

    -- Background
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()

    local color = plugin:GetSetting(1, "BackdropColour")
    if color then
        bar.bg:SetColorTexture(color.r, color.g, color.b, color.a or 0.5)
    else
        local bg = Orbit.Constants.Colors.Background
        bar.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    end

    -- Pixel-perfect SetBorder helper (horizontal layout for icon merging)
    bar.SetBorder = function(self, size)
        Orbit.Skin:SkinBorder(self, self, size, nil, true)
    end

    -- Apply default border
    bar:SetBorder(1)

    -- Icon (Inside bar, left aligned)
    bar.Icon = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    bar.Icon:SetDrawLayer("OVERLAY", 1)
    bar.Icon:SetSize(14, 14) -- Will be resized in ApplySettings
    bar.Icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    bar.Icon:Hide() -- Hidden by default, shown based on setting

    -- Icon Border
    bar.IconBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.IconBorder:SetAllPoints(bar.Icon)
    bar.IconBorder:SetFrameLevel(bar:GetFrameLevel() + 2)
    Orbit.Skin:SkinBorder(bar, bar.IconBorder, 1, { r = 0, g = 0, b = 0, a = 1 }, true)
    bar.IconBorder:Hide()

    -- Text (will be repositioned based on icon visibility)
    bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Text:SetPoint("LEFT", 4, 0)
    bar.Text:SetJustifyH("LEFT")
    bar.Text:SetShadowColor(0, 0, 0, 1)
    bar.Text:SetShadowOffset(1, -1)

    -- Timer
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
        castBar:SetPoint("BOTTOM", parent, "TOP", 0, 4)
    else -- Below
        castBar:SetPoint("TOP", parent, "BOTTOM", 0, -4)
    end
end

local function SetupCastBarHooks(castBar, unit)
    local nativeSpellbar = _G["Boss" .. castBar.bossIndex .. "TargetFrameSpellBar"]
    if not nativeSpellbar then
        return
    end
    local plugin = castBar.plugin

    -- Hook OnShow
    nativeSpellbar:HookScript("OnShow", function(nativeBar)
        if not castBar then
            return
        end

        -- Get CastBarIcon setting (from Boss Frames, not Player Cast Bar)
        local showIcon = plugin:GetSetting(1, "CastBarIcon")
        local castBarHeight = castBar:GetHeight()
        local iconOffset = 0

        -- Sync Icon
        local iconTexture
        if nativeBar.Icon then
            iconTexture = nativeBar.Icon:GetTexture()
        end
        if not iconTexture and C_Spell and C_Spell.GetSpellTexture and nativeBar.spellID then
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
                -- Hide cast bar's left border edge to merge with icon's right border
                if castBar.Borders and castBar.Borders.Left then
                    castBar.Borders.Left:Hide()
                end
            else
                castBar.Icon:Hide()
                if castBar.IconBorder then
                    castBar.IconBorder:Hide()
                end
                -- Show cast bar's left border edge when icon is hidden
                if castBar.Borders and castBar.Borders.Left then
                    castBar.Borders.Left:Show()
                end
            end
        end

        -- Adjust StatusBar texture to start after icon
        local statusBarTexture = castBar:GetStatusBarTexture()
        if statusBarTexture then
            statusBarTexture:ClearAllPoints()
            statusBarTexture:SetPoint("TOPLEFT", castBar, "TOPLEFT", iconOffset, 0)
            statusBarTexture:SetPoint("BOTTOMLEFT", castBar, "BOTTOMLEFT", iconOffset, 0)
            statusBarTexture:SetPoint("TOPRIGHT", castBar, "TOPRIGHT", 0, 0)
            statusBarTexture:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
        end

        -- Adjust background to start after icon
        if castBar.bg then
            castBar.bg:ClearAllPoints()
            castBar.bg:SetPoint("TOPLEFT", castBar, "TOPLEFT", iconOffset, 0)
            castBar.bg:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, 0)
        end

        -- Sync Text (repositioned based on icon)
        local showText = plugin:GetCastBarSetting("CastBarText")
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

        -- Sync Timer Visibility
        local showTimer = plugin:GetCastBarSetting("CastBarTimer")
        if castBar.Timer then
            castBar.Timer:SetShown(showTimer)
        end

        -- Sync Values
        local min, max = nativeBar:GetMinMaxValues()
        if min and max then
            castBar:SetMinMaxValues(min, max)
            castBar:SetValue(nativeBar:GetValue() or 0)
        end

        -- Color based on interruptible
        if nativeBar.notInterruptible then
            local color = plugin:GetCastBarSetting("NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
            castBar:SetStatusBarColor(color.r, color.g, color.b)
        else
            local color = plugin:GetCastBarSetting("CastBarColor") or { r = 1, g = 0.7, b = 0 }
            castBar:SetStatusBarColor(color.r, color.g, color.b)
        end

        castBar:Show()
    end)

    -- Hook OnHide
    nativeSpellbar:HookScript("OnHide", function()
        if castBar then
            castBar:Hide()
        end
    end)

    -- Hook OnUpdate
    local lastUpdate = 0
    local updateThrottle = 1 / 60
    nativeSpellbar:HookScript("OnUpdate", function(nativeBar, elapsed)
        if not castBar or not castBar:IsShown() then
            return
        end

        lastUpdate = lastUpdate + elapsed
        if lastUpdate < updateThrottle then
            return
        end
        lastUpdate = 0

        local progress = nativeBar:GetValue()
        local min, max = nativeBar:GetMinMaxValues()

        if progress and max then
            castBar:SetMinMaxValues(min, max)
            castBar:SetValue(progress)

            -- Safe update for Timer and Spark
            local function SafeUpdateVisuals()
                if max <= 0 then
                    return
                end

                -- Timer
                if castBar.Timer and castBar.Timer:IsShown() then
                    local timeLeft = nativeBar.channeling and progress or (max - progress)
                    castBar.Timer:SetText(string.format("%.1f", timeLeft))
                end
            end

            pcall(SafeUpdateVisuals)
        end
    end)

    -- Hook OnEvent for interrupt state
    nativeSpellbar:HookScript("OnEvent", function(nativeBar, event, eventUnit)
        if eventUnit ~= unit then
            return
        end
        if not castBar or not castBar:IsShown() then
            return
        end

        if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            -- Note: InterruptedColor might not be exposed in PlayerCastBar public settings unless we add it
            -- For now defaulting to red, or checking if InterruptedColor exists
            castBar:SetStatusBarColor(1, 0, 0)
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            local color = plugin:GetCastBarSetting("NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
            castBar:SetStatusBarColor(color.r, color.g, color.b)
        elseif
            event == "UNIT_SPELLCAST_INTERRUPTIBLE"
            or event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_CHANNEL_START"
        then
            local color = plugin:GetCastBarSetting("CastBarColor") or { r = 1, g = 0.7, b = 0 }
            castBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    end)
end

-- [ BOSS FRAME CREATION ]-------------------------------------------------------------------------

local function CreateBossFrame(bossIndex, plugin)
    local unit = "boss" .. bossIndex
    local frameName = "OrbitBossFrame" .. bossIndex

    -- Create base unit button
    local frame = OrbitEngine.UnitButton:Create(UIParent, unit, frameName)
    frame.editModeName = "Boss Frame " .. bossIndex
    frame.systemIndex = 1
    frame.bossIndex = bossIndex

    -- IMPORTANT: Set initial size BEFORE creating child components
    local width = plugin:GetSetting(1, "Width") or 150
    local height = plugin:GetSetting(1, "Height") or 40
    frame:SetSize(width, height)

    -- Set frame strata/level for visibility
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(50 + bossIndex)

    UpdateFrameLayout(frame, plugin:GetPlayerSetting("BorderSize"))

    -- Create power bar
    frame.Power = CreatePowerBar(frame, unit, plugin)

    -- Register power events
    frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)

    -- Update Loop
    frame:SetScript("OnShow", function(self)
        self:UpdateAll()
        UpdatePowerBar(self)
        UpdateFrameLayout(self, plugin:GetPlayerSetting("BorderSize")) -- Ensure layout is correct on show
        UpdateDebuffs(self, plugin)
    end)

    -- Create debuff container (start shown for preview)
    frame.debuffContainer = CreateFrame("Frame", nil, frame)
    frame.debuffContainer:SetSize(100, 20)

    frame:RegisterUnitEvent("UNIT_AURA", unit)

    -- Create cast bar
    frame.CastBar = CreateBossCastBar(frame, bossIndex, plugin)
    plugin:PositionCastBar(frame.CastBar, frame, "Below")

    -- Extended OnEvent handler
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

    -- UnitWatch handles visibility state securely (works in combat)
    -- We only unregister it temporarily for Preview mode

    -- Enable health text display
    frame.healthTextEnabled = true

    -- Enable advanced health bar features (Absorbs, Heal Absorbs, Predictions)
    if frame.SetAbsorbsEnabled then
        frame:SetAbsorbsEnabled(true)
    end
    if frame.SetHealAbsorbsEnabled then
        frame:SetHealAbsorbsEnabled(true)
    end

    return frame
end

-- [ NATIVE FRAME HIDING ]-------------------------------------------------------------------------

local function HideNativeBossFrames()
    -- Hide container
    if BossTargetFrameContainer then
        BossTargetFrameContainer:ClearAllPoints()
        BossTargetFrameContainer:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -10000, 10000)
        BossTargetFrameContainer:SetAlpha(0)
        BossTargetFrameContainer:SetScale(0.001)
        BossTargetFrameContainer:EnableMouse(false)
    end

    -- Hide individual frames
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

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------

function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = 1
    local WL = OrbitEngine.WidgetLogic

    local schema = {
        hideNativeSettings = true,
        controls = {
            { type = "slider", key = "Width", label = "Width", min = 120, max = 300, step = 5, default = 150 },
            { type = "slider", key = "Height", label = "Height", min = 20, max = 60, step = 5, default = 40 },
            {
                type = "dropdown",
                key = "CastBarPosition",
                label = "Cast Bar",
                options = {
                    { label = "Above", value = "Above" },
                    { label = "Below", value = "Below" },
                },
                default = "Below",
            },
            {
                type = "slider",
                key = "CastBarHeight",
                label = "Cast Bar Height",
                min = 15,
                max = 35,
                step = 1,
                default = 14,
            },
            {
                type = "checkbox",
                key = "CastBarIcon",
                label = "Show Cast Bar Icon",
                default = true,
            },
            {
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
            },
            { type = "slider", key = "MaxDebuffs", label = "Max Debuffs", min = 2, max = 8, step = 1, default = 4 },
        },
    }

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------

function Plugin:OnLoad()
    -- Hide native boss frames
    HideNativeBossFrames()

    -- Create container frame for all boss frames (for Edit Mode selection highlight)
    -- Must be SecureHandlerStateTemplate to handle visibility safely in combat
    self.container = CreateFrame("Frame", "OrbitBossContainer", UIParent, "SecureHandlerStateTemplate")
    self.container.editModeName = "Boss Frames"
    self.container.systemIndex = 1
    self.container:SetFrameStrata("MEDIUM")
    self.container:SetFrameLevel(49)
    self.container:SetClampedToScreen(true) -- Prevent dragging off-screen

    -- Create boss frames (parented to container)
    self.frames = {}
    for i = 1, MAX_BOSS_FRAMES do
        self.frames[i] = CreateBossFrame(i, self)
        self.frames[i]:SetParent(self.container)

        -- Setup cast bar hooks (combat-safe deferred - native spellbars may not exist yet)
        local bossIndex = i -- Capture for closure
        Orbit:SafeAction(function()
            if self.frames[bossIndex] and self.frames[bossIndex].CastBar then
                SetupCastBarHooks(self.frames[bossIndex].CastBar, "boss" .. bossIndex)
            end
        end)
    end

    -- Container is the selectable frame for Edit Mode
    -- This ensures highlight covers all boss frames together
    self.frame = self.container
    self.frame.anchorOptions = { horizontal = false, vertical = false, noAnchor = true }
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, 1)

    -- Set default container position (right side of screen)
    if not self.container:GetPoint() then
        self.container:SetPoint("RIGHT", UIParent, "RIGHT", -100, 100)
    end

    -- Register secure visibility driver for the container
    -- This handles Showing/Hiding the container (and thus all boss frames) securely in combat
    local visibilityDriver =
        "[petbattle] hide; [@boss1,exists] show; [@boss2,exists] show; [@boss3,exists] show; [@boss4,exists] show; [@boss5,exists] show; hide"
    RegisterAttributeDriver(self.container, "state-visibility", visibilityDriver)

    -- Position frames (stacked vertically)
    self:PositionFrames()

    -- Apply initial settings
    self:ApplySettings()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_TARGETABLE_CHANGED")

    eventFrame:SetScript("OnEvent", function(_, event)
        -- Update on Engage (Start), Regen Disabled (Combat Start), Regen Enabled (Combat End/Death), Targetable Change (Phasing)
        if
            event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT"
            or event == "PLAYER_REGEN_DISABLED"
            or event == "PLAYER_REGEN_ENABLED"
            or event == "UNIT_TARGETABLE_CHANGED"
        then
            for i, frame in ipairs(self.frames) do
                if frame.UpdateAll and not frame.preview then -- Check if UpdateAll exists and not in preview
                    frame:UpdateAll()
                    UpdatePowerBar(frame)
                    UpdateDebuffs(frame, self)
                end
            end
        end

        -- Update container size if out of combat (resizing in combat is protected if it moves anchors)
        if not InCombatLockdown() then
            self:UpdateContainerSize()
        end
    end)

    self:RegisterStandardEvents()

    -- Edit Mode callbacks (guard against duplicate registration)
    if EventRegistry and not self.editModeCallbacksRegistered then
        self.editModeCallbacksRegistered = true
        
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            self:ShowPreview()
            self:ApplySettings()
        end, self)

        EventRegistry:RegisterCallback("EditMode.Exit", function()
            self:HidePreview()
            -- Sync size on exit if safe
            if not InCombatLockdown() then
                self:UpdateContainerSize()
            end
        end, self)
    end

    -- Initial update
    if not InCombatLockdown() then
        self:UpdateContainerSize()
    end
end

function Plugin:CalculateFrameSpacing(index)
    -- Calculate height required by "Extras" (CastBar, Debuffs) to ensure no overlap
    -- Returns: topPadding, bottomPadding

    local castBarPos = self:GetSetting(1, "CastBarPosition") or "Below"
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or 14
    local castBarGap = 4

    local debuffPos = self:GetSetting(1, "DebuffPosition") or "Right"
    local maxDebuffs = self:GetSetting(1, "MaxDebuffs") or 4
    local frameWidth = self:GetSetting(1, "Width") or 150
    local spacing = 2
    local iconSize = 0

    -- Calculate icon size for horizontal layout
    if debuffPos == "Above" or debuffPos == "Below" then
        local totalSpacing = (maxDebuffs - 1) * spacing
        iconSize = (frameWidth - totalSpacing) / maxDebuffs
    else
        -- Side positioning doesn't affect vertical spacing
        iconSize = 0
    end

    local topPadding = 0
    local bottomPadding = 0
    local elementGap = 4

    -- Cast Bar Spacing
    if castBarPos == "Above" then
        topPadding = topPadding + castBarHeight + castBarGap
    elseif castBarPos == "Below" then
        bottomPadding = bottomPadding + castBarHeight + castBarGap
    end

    -- Debuff Spacing
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

    local baseSpacing = 20 -- Base visual gap between "Occupied Areas" of units
    local frameHeight = self:GetSetting(1, "Height") or 40

    -- Calculate total height for container update
    local totalHeight = 0

    for i, frame in ipairs(self.frames) do
        frame:ClearAllPoints()

        -- Get padding requirements for this specifc frame configuration
        -- (Currently uniform, but function supports per-frame if we ever go fully modular)
        local topPadding, bottomPadding = self:CalculateFrameSpacing(i)

        -- Store for container sizing
        frame.layoutHeight = frameHeight + topPadding + bottomPadding

        if i == 1 then
            -- First frame: Anchor to container top, offset by its top padding
            frame:SetPoint("TOP", self.container, "TOP", 0, -topPadding)
        else
            -- Subsequent frames: Anchor to previous frame's BOTTOM
            -- Gap = Previous Bottom Padding + Base Spacing + Current Top Padding
            -- BUT: frame points are relative to the *Frame Body*, not the extras.
            -- So we anchor Frame[i] TOP to Frame[i-1] BOTTOM.
            -- Offset Y = -(PrevBottomPadding + BaseSpacing + CurrentTopPadding)

            local prevTop, prevBottom = self:CalculateFrameSpacing(i - 1)
            local offset = -(prevBottom + baseSpacing + topPadding)

            frame:SetPoint("TOP", self.frames[i - 1], "BOTTOM", 0, offset)
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
    local baseSpacing = 20

    -- Count visible frames
    local visibleCount = 0
    local lastVisibleIndex = 0
    for i, frame in ipairs(self.frames) do
        if frame:IsShown() or frame.preview then
            visibleCount = visibleCount + 1
            lastVisibleIndex = i
        end
    end

    if visibleCount == 0 then
        visibleCount = 2
        lastVisibleIndex = 2
    end -- Preview default

    -- Sum heights
    local totalHeight = 0
    -- Note: This is an estimation for the container frame (Edit Mode highlight box)
    -- It should encompass the visual bounds of all visible frames + their spacing

    local topPaddingFirst, _ = self:CalculateFrameSpacing(1)

    -- Start with Top Padding of first frame (since frame is anchored -TopPadding down)
    totalHeight = topPaddingFirst

    for i = 1, lastVisibleIndex do
        -- Add Frame Body
        local fHeight = self.frames[i]:GetHeight()
        totalHeight = totalHeight + fHeight

        -- Add Frame Padding
        local t, b = self:CalculateFrameSpacing(i)
        -- We already added Top Padding for first frame. The calculated loop for others handles the gap.

        -- Gap between frames
        if i < lastVisibleIndex then
            local _, prevB = self:CalculateFrameSpacing(i)
            local nextT, _ = self:CalculateFrameSpacing(i + 1)
            totalHeight = totalHeight + prevB + baseSpacing + nextT
        else
            -- Last frame: just add its bottom padding
            totalHeight = totalHeight + b
        end
    end

    self.container:SetSize(width, totalHeight)
    self.container:SetScale(scale)
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------

function Plugin:ApplySettings()
    if not self.frames then
        return
    end
    if InCombatLockdown() then
        return
    end

    local scale = self:GetSetting(1, "Scale") or 100
    local width = self:GetSetting(1, "Width") or 150
    local height = self:GetSetting(1, "Height") or 40
    local castBarPosition = self:GetSetting(1, "CastBarPosition") or "Below"
    local castBarHeight = self:GetSetting(1, "CastBarHeight") or 14

    -- Global Fallbacks
    local borderSize = self:GetSetting(1, "BorderSize") or self:GetPlayerSetting("BorderSize") or 1
    local textureName = self:GetSetting(1, "Texture") or self:GetPlayerSetting("Texture")
    local fontName = self:GetSetting(1, "Font") or self:GetPlayerSetting("Font")
    local reactionColour = self:GetSetting(1, "ReactionColour")

    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 12, 24, 0.25)

    local texturePath = LSM:Fetch("statusbar", textureName)

    for i, frame in ipairs(self.frames) do
        -- Store border size for OnShow
        frame.borderSize = borderSize

        -- Size
        frame:SetSize(width, height)
        frame:SetScale(scale / 100)

        -- Default Colors
        if frame.SetReactionColour then
            frame:SetReactionColour(reactionColour)
        end
        if frame.SetClassColour then
            frame:SetClassColour(not reactionColour) -- Prioritize reaction color
        end

        -- Border (must come BEFORE Layout Update because SetBorder resets anchors)
        frame:SetBorder(borderSize)

        -- Adjust layout (Correct order: SetBorder -> UpdateFrameLayout)
        UpdateFrameLayout(frame, borderSize)

        if frame.Health and textureName then
            Orbit.Skin:SkinStatusBar(frame.Health, textureName)
        end
        if frame.Power and textureName then
            Orbit.Skin:SkinStatusBar(frame.Power, textureName)
            if frame.Power.bg then
                frame.Power.bg:SetColorTexture(0, 0, 0, 0.5)
            end
        end

        -- Fonts
        Orbit.Skin:ApplyUnitFrameText(frame.Name, "LEFT", nil, textSize)
        Orbit.Skin:ApplyUnitFrameText(frame.HealthText, "RIGHT", nil, textSize)

        if frame.CastBar then
            frame.CastBar:SetSize(width, castBarHeight)
            self:PositionCastBar(frame.CastBar, frame, castBarPosition)

            -- Apply pixel-perfect border
            if frame.CastBar.SetBorder then
                frame.CastBar:SetBorder(borderSize)
            end

            if textureName then
                Orbit.Skin:SkinStatusBar(frame.CastBar, textureName)
            end

            local cbTextSize = Orbit.Skin:GetAdaptiveTextSize(castBarHeight, 10, 18, 0.40)
            local fontPath = LSM:Fetch("font", fontName)
            if frame.CastBar.Text then
                frame.CastBar.Text:SetFont(fontPath, cbTextSize, "OUTLINE")
            end
            if frame.CastBar.Timer then
                frame.CastBar.Timer:SetFont(fontPath, cbTextSize, "OUTLINE")
            end
        end

        -- Skip visual updates for preview frames (ApplyPreviewVisuals handles those)
        if not frame.preview then
            frame:UpdateAll()
            UpdatePowerBar(frame)
            UpdateDebuffs(frame, self)
        end
    end

    -- Reposition frames within container
    self:PositionFrames()

    -- Restore position for container (the selectable frame)
    OrbitEngine.Frame:RestorePosition(self.container, self, 1)

    -- Re-apply preview visuals if any frame is in preview mode (debounced)
    local anyPreview = false
    for i, frame in ipairs(self.frames) do
        if frame.preview then
            anyPreview = true
            break
        end
    end
    if anyPreview then
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
