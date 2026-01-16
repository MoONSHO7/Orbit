-- [ ORBIT CAST BAR MIXIN ]--------------------------------------------------------------------------
-- Shared functionality for PlayerCastBar, TargetCastBar, FocusCastBar

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

---@class OrbitCastBarMixin
Orbit.CastBarMixin = {}
local Mixin = Orbit.CastBarMixin

-- Default settings shared by all cast bars
Mixin.sharedDefaults = {
    CastBarColor = { r = 1, g = 0.7, b = 0 },
    CastBarText = true,
    CastBarIcon = true,
    CastBarTimer = true,
    CastBarHeight = 18,
    CastBarWidth = 200,
    CastBarScale = 100,
}

-- Keys that Target/Focus cast bars inherit from Player Cast Bar
Mixin.INHERITED_KEYS = {
    CastBarColor = true,
    NonInterruptibleColor = true,
    CastBarText = true,
    CastBarIcon = true,
    CastBarText = true,
    CastBarTimer = true,
    SparkColor = true,
}

-- [ SETTINGS INHERITANCE ]--------------------------------------------------------------------------
-- Override GetSetting to inherit specific keys from Player Cast Bar
-- This is mixed into Target/Focus cast bars to avoid code duplication
function Mixin:GetInheritedSetting(systemIndex, key)
    if self.INHERITED_KEYS[key] then
        local playerPlugin = Orbit:GetPlugin("Orbit_PlayerCastBar")
        if playerPlugin then
            return playerPlugin:GetSetting(1, key)
        end
    end
    return Orbit.PluginMixin.GetSetting(self, systemIndex, key)
end

-- [ SHARED UTILITIES ]------------------------------------------------------------------------------

-- Determine anchor axis for conditional settings display
function Mixin:GetAnchorAxis(frame)
    return OrbitEngine.Frame:GetAnchorAxis(frame)
end

-- [ FRAME CREATION ]--------------------------------------------------------------------------------

function Mixin:CreateCastBarFrame(name, config)
    config = config or {}

    local bar = CreateFrame("StatusBar", name, UIParent)
    bar:SetSize(
        config.width or Orbit.Constants.PlayerCastBar.DefaultWidth or 200,
        config.height or Orbit.Constants.PlayerCastBar.DefaultHeight or 18
    )
    bar:SetPoint("CENTER", 0, config.yOffset or Orbit.Constants.PlayerCastBar.DefaultY or -150)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(100)
    bar:SetStatusBarTexture("") -- Handled by Skin
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    -- Edit Mode metadata
    bar.systemIndex = 1
    bar.orbitName = config.editModeName or name
    bar.editModeName = config.editModeName or name
    bar.orbitPlugin = self

    -- Cast state
    bar.casting = false
    bar.channeling = false
    bar.empowering = false
    bar.numStages = 0
    bar.currentStage = 0
    bar.stageDurations = {}
    bar.startTime = 0
    bar.endTime = 0
    bar.maxValue = 1
    bar.value = 0
    bar.preview = false

    -- Frame options
    bar.anchorOptions = config.anchorOptions
        or { horizontal = false, vertical = true, syncScale = true, syncDimensions = true }

    -- Attach to Frame system
    OrbitEngine.Frame:AttachSettingsListener(bar, self, 1)

    return bar
end

-- [ SKIN INITIALIZATION ]---------------------------------------------------------------------------

function Mixin:InitializeSkin(bar)
    if not Orbit.Skin.CastBar then
        return
    end

    local skinned = Orbit.Skin.CastBar:Create(bar)
    bar.orbitBar = skinned
    bar.Text = skinned.Text
    bar.Timer = skinned.Timer
    bar.Icon = skinned.Icon
    bar.Spark = skinned.Spark
    bar.Border = skinned.Border
    bar.Latency = skinned.Latency
    bar.InterruptOverlay = skinned.InterruptOverlay
    bar.InterruptAnim = skinned.InterruptAnim
    bar.SparkGlow = skinned.SparkGlow

    return skinned
end

-- [ EDIT MODE & EVENTS ]---------------------------------------------------------------------------

function Mixin:RegisterEditModeCallbacks(bar, debounceKey)
    if not EventRegistry then
        return
    end

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        bar.preview = false
        if not bar.casting and not bar.channeling then
            bar:Hide()
        end
        self:ApplySettings()
    end, self)

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        self:ShowPreview()
        self:ApplySettings()
    end, self)
end

function Mixin:RegisterWorldEvent(bar, debounceKey)
    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        Orbit.Async:Debounce(debounceKey .. "_Init", function()
            self:ApplySettings()
            if not (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()) then
                if not bar.casting and not bar.channeling then
                    bar:Hide()
                end
            end
        end, 0.5)
    end, self)
end

function Mixin:RestorePositionDebounced(bar, debounceKey)
    Orbit.Async:Debounce(debounceKey .. "_LoadPosition", function()
        OrbitEngine.Frame:RestorePosition(bar, self, 1)
    end, 0.1)
end

-- [ SETTINGS UI (SHARED SCHEMA BUILDER) ]----------------------------------------------------------

function Mixin:BuildBaseSchema(bar, systemIndex, options)
    options = options or {}
    local WL = OrbitEngine.WidgetLogic

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(bar) ~= nil
    local anchorAxis = isAnchored and self:GetAnchorAxis(bar) or nil

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- 1. Height (Hide if X-anchored)
    if not (isAnchored and anchorAxis == "x") then
        WL:AddSizeSettings(
            self,
            schema,
            systemIndex,
            nil,
            nil,
            { key = "CastBarHeight", label = "Height", min = 15, max = 35, default = options.defaultHeight or 18 }
        )
    end

    -- 2. Width (Hide if Y-anchored)
    if not (isAnchored and anchorAxis == "y") then
        table.insert(schema.controls, {
            type = "slider",
            key = "CastBarWidth",
            label = "Width",
            min = 120,
            max = 350,
            step = 10,
            default = options.defaultWidth or 200,
        })
    end

    return schema, isAnchored, anchorAxis
end

function Mixin:AddTextSettings(schema, systemIndex)
    -- Show Spell Name
    table.insert(schema.controls, {
        type = "checkbox",
        key = "CastBarText",
        label = "Show Spell Name",
        default = true,
    })

    -- Show Timer
    table.insert(schema.controls, {
        type = "checkbox",
        key = "CastBarTimer",
        label = "Show Timer",
        default = true,
    })

    -- Text Size (Conditional)
    -- Now adaptive
    -- local showText = self:GetSetting(systemIndex, "CastBarText")
    -- local showTimer = self:GetSetting(systemIndex, "CastBarTimer")
end

-- [ APPLY SETTINGS (SHARED) ]----------------------------------------------------------------------

function Mixin:ApplyBaseSettings(bar, systemIndex, isAnchored)
    if not bar then
        return
    end

    local axis = isAnchored and self:GetAnchorAxis(bar)

    -- Get settings
    local scale = self:GetSetting(systemIndex, "CastBarScale") or 100
    local height = self:GetSetting(systemIndex, "CastBarHeight") or 18
    local width = self:GetSetting(systemIndex, "CastBarWidth") or 200
    local borderSize = self:GetSetting(systemIndex, "BorderSize")
    local texture = self:GetSetting(systemIndex, "Texture")
    local showText = self:GetSetting(systemIndex, "CastBarText")
    local showIcon = self:GetSetting(systemIndex, "CastBarIcon")
    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 10, 18, 0.40)
    local showTimer = self:GetSetting(systemIndex, "CastBarTimer")
    local color = self:GetSetting(systemIndex, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
    local fontName = self:GetSetting(systemIndex, "Font")
    local backdropColor = self:GetSetting(systemIndex, "BackdropColour")
    local sparkColor = self:GetSetting(systemIndex, "SparkColor")

    Orbit:SafeAction(function()
        -- Height
        if not (isAnchored and axis == "x") then
            bar:SetHeight(height)
        end

        -- Width
        if not (isAnchored and axis == "y") then
            bar:SetWidth(width)
        end

        -- Scale (only when NOT anchored)
        if not isAnchored then
            bar:SetScale(scale / 100)
        end

        -- Spark height
        if bar.Spark then
            bar.Spark:SetHeight(height + 4)
        end

        -- Latency height
        if bar.Latency then
            bar.Latency:SetHeight(height)
        end
    end)

    -- Apply skin
    if Orbit.Skin.CastBar and bar.orbitBar then
        Orbit.Skin.CastBar:Apply(bar.orbitBar, {
            texture = texture,
            color = color,
            borderSize = borderSize,
            textSize = textSize,
            showText = showText,
            showIcon = showIcon,
            showTimer = showTimer,
            font = fontName,
            font = fontName,
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            backdropColor = backdropColor,
            sparkColor = sparkColor,
        })
    end

    -- Show preview in Edit Mode
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
        self:ShowPreview()
    end
end

-- [ PREVIEW ]---------------------------------------------------------------------------------------

function Mixin:ShowPreview()
    local bar = self.CastBar
    if not bar then
        return
    end

    -- Prevent protected function calls in combat (OrbitTargetCastBar is secure/protected)
    if InCombatLockdown() then
        return
    end

    bar.preview = true
    bar.casting = false
    bar.channeling = false

    local targetBar = bar.orbitBar or bar
    targetBar:SetMinMaxValues(0, 3)
    targetBar:SetValue(1.5)

    if bar.Text then
        bar.Text:SetText(self.previewText or "Preview Cast")
    end
    if bar.Icon then
        bar.Icon:SetTexture(136243) -- Hearthstone icon
    end
    if bar.Timer then
        bar.Timer:SetText("1.5")
    end

    bar:Show()
end

-- [ HOOK-BASED CAST BAR HELPERS (Target/Focus) ]---------------------------------------------------

function Mixin:SetupSpellbarHooks(nativeSpellbar, unit)
    if not nativeSpellbar then
        return
    end

    local bar = self.CastBar
    bar.orbitUnit = unit -- Store unit for UpdateInterruptState

    -- Register unit events DIRECTLY on the Orbit cast bar for interruptibility changes
    bar:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)

    bar:HookScript("OnEvent", function(frame, event, eventUnit)
        if eventUnit ~= unit then
            return
        end
        if not bar:IsShown() then
            return
        end

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            -- Update interrupt state on cast start
            self:UpdateInterruptState(nativeSpellbar, bar, unit)
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            local color = self:GetSetting(1, "NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
            if bar.orbitBar then
                bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            local color = self:GetSetting(1, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
            if bar.orbitBar then
                bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            local color = self:GetSetting(1, "InterruptedColor") or { r = 1, g = 0, b = 0 }
            if bar.orbitBar then
                bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        end
    end)

    -- 1. Hook OnShow
    nativeSpellbar:HookScript("OnShow", function(nativeBar)
        if not bar then
            return
        end

        -- Sync Icon
        local iconTexture
        if nativeBar.Icon then
            iconTexture = nativeBar.Icon:GetTexture()
        end
        if not iconTexture and C_Spell and C_Spell.GetSpellTexture and nativeBar.spellID then
            iconTexture = C_Spell.GetSpellTexture(nativeBar.spellID)
        end

        if bar.Icon then
            bar.Icon:SetTexture(iconTexture or 136243)
        end

        -- Sync Text
        if nativeBar.Text and bar.Text then
            bar.Text:SetText(nativeBar.Text:GetText() or "Casting...")
        end

        -- Sync Values
        local min, max = nativeBar:GetMinMaxValues()
        if min and max then
            local targetBar = bar.orbitBar or bar
            targetBar:SetMinMaxValues(min, max)
            targetBar:SetValue(nativeBar:GetValue() or 0)
        end

        -- Sync Interrupt State
        self:UpdateInterruptState(nativeBar, bar, unit)

        bar:Show()
    end)

    -- 2. Hook OnHide
    nativeSpellbar:HookScript("OnHide", function()
        if bar and not bar.preview then
            bar:Hide()
        end
    end)

    -- 3. Hook OnEvent (Interrupts/State)
    nativeSpellbar:HookScript("OnEvent", function(nativeBar, event, eventUnit)
        if eventUnit ~= unit then
            return
        end
        if not bar or not bar:IsShown() then
            return
        end

        if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            local color = self:GetSetting(1, "InterruptedColor") or { r = 1, g = 0, b = 0 }
            if bar.orbitBar then
                bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            local color = self:GetSetting(1, "NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
            if bar.orbitBar then
                bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        elseif
            event == "UNIT_SPELLCAST_INTERRUPTIBLE"
            or event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_CHANNEL_START"
        then
            local color = self:GetSetting(1, "CastBarColor")
            if bar.orbitBar then
                bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        end
    end)

    -- 4. Hook OnUpdate (Sync Progress)
    local lastUpdate = 0
    local updateThrottle = 1 / 60
    nativeSpellbar:HookScript("OnUpdate", function(nativeBar, elapsed)
        if not bar or not bar:IsShown() then
            return
        end

        lastUpdate = lastUpdate + elapsed
        if lastUpdate < updateThrottle then
            return
        end
        lastUpdate = 0

        local progress = nativeBar:GetValue()
        local min, max = nativeBar:GetMinMaxValues()

        local targetBar = bar.orbitBar or bar
        if progress and max then
            targetBar:SetMinMaxValues(min, max)
            targetBar:SetValue(progress)

            -- Guarded update for Timer and Spark
            local function SafeUpdateVisuals()
                if max <= 0 then
                    return
                end

                -- Timer
                if bar.Timer and bar.Timer:IsShown() then
                    local timeLeft = nativeBar.channeling and progress or (max - progress)
                    bar.Timer:SetText(string.format("%.1f", timeLeft))
                end

                -- Spark positioning - use orbitBar (targetBar) for dimensions
                if bar.Spark and targetBar:GetWidth() > 0 then
                    local sparkPos = (progress / max) * targetBar:GetWidth()
                    bar.Spark:ClearAllPoints()
                    bar.Spark:SetPoint("CENTER", targetBar, "LEFT", sparkPos, 0)
                end
            end

            local success = pcall(SafeUpdateVisuals)
            if not success then
                if bar.Timer and bar.Timer:IsShown() then
                    bar.Timer:SetFormattedText("%.1f", progress)
                end
            end
        end
    end)
end

function Mixin:UpdateInterruptState(nativeBar, bar, unit)
    -- In WoW 12.0, notInterruptible from UnitCastingInfo/UnitChannelInfo is a secret value
    -- that cannot be used in boolean tests from addon code during combat.
    --
    -- SOLUTION: Check if the native spellbar's BorderShield is visible.
    -- Blizzard shows this shield for non-interruptible casts, and IsShown()
    -- returns a regular boolean, not a secret value.

    local notInterruptible = false

    -- Check the native spellbar's BorderShield visibility
    if nativeBar and nativeBar.BorderShield then
        -- BorderShield:IsShown() returns a regular boolean, safe to use
        local success, result = pcall(function()
            return nativeBar.BorderShield:IsShown()
        end)
        if success then
            notInterruptible = result
        end
    end

    local color
    if notInterruptible then
        color = self:GetSetting(1, "NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
    else
        color = self:GetSetting(1, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
    end

    if bar.orbitBar and color then
        bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
    end
end
