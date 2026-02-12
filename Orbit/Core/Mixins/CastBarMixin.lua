-- [ ORBIT CAST BAR MIXIN ]--------------------------------------------------------------------------
-- Shared functionality for PlayerCastBar, TargetCastBar, FocusCastBar

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

---@class OrbitCastBarMixin
Orbit.CastBarMixin = {}
local Mixin = Orbit.CastBarMixin

local CAST_BAR_FRAME_LEVEL = 100
local SPARK_OVERFLOW = 4
local DEFAULT_CAST_COLOR = { r = 1, g = 0.7, b = 0 }
local DEFAULT_PROTECTED_COLOR = { r = 0.7, g = 0.7, b = 0.7 }
local DEFAULT_INTERRUPTED_COLOR = { r = 1, g = 0, b = 0 }

Mixin.sharedDefaults = {
    CastBarColor = { r = 1, g = 0.7, b = 0 },
    CastBarColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0, a = 1 } } } },
    CastBarText = true,
    CastBarIcon = true,
    CastBarTimer = true,
    CastBarHeight = 18,
    CastBarWidth = 200,
    CastBarScale = 100,
}

-- [ SHARED UTILITIES ]------------------------------------------------------------------------------

function Mixin:GetAnchorAxis(frame)
    return OrbitEngine.Frame:GetAnchorAxis(frame)
end

function Mixin:ApplyCastColor(bar, state)
    if not bar or not bar.orbitBar then
        return
    end
    local color
    if state == "INTERRUPTED" then
        color = self:GetSetting(1, "InterruptedColor") or DEFAULT_INTERRUPTED_COLOR
    elseif state == "NON_INTERRUPTIBLE" then
        local curveData = self:GetSetting(1, "NonInterruptibleColorCurve")
        color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData) or self:GetSetting(1, "NonInterruptibleColor") or DEFAULT_PROTECTED_COLOR
    else
        local curveData = self:GetSetting(1, "CastBarColorCurve")
        color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData) or self:GetSetting(1, "CastBarColor") or DEFAULT_CAST_COLOR
    end
    if color then
        bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
    end
end

-- Update interrupt state (called by UNIT_SPELLCAST_INTERRUPTIBLE / NOT_INTERRUPTIBLE events)
-- In WoW 12.0+, notInterruptible from API returns can be a "secret boolean" for enemy units in combat,
-- so we only set interrupt state via the dedicated events which pass explicit true/false values.
function Mixin:UpdateInterruptState(bar, notInterruptible)
    if not bar then
        return
    end
    bar.notInterruptible = notInterruptible
    self:ApplyCastColor(bar, notInterruptible and "NON_INTERRUPTIBLE" or "INTERRUPTIBLE")
end

-- [ FRAME CREATION ]--------------------------------------------------------------------------------

function Mixin:CreateCastBarFrame(name, config)
    config = config or {}

    local bar = CreateFrame("StatusBar", name, UIParent)
    bar:SetSize(config.width or Orbit.Constants.PlayerCastBar.DefaultWidth or 200, config.height or Orbit.Constants.PlayerCastBar.DefaultHeight or 18)
    bar:SetPoint("CENTER", 0, config.yOffset or Orbit.Constants.PlayerCastBar.DefaultY or -150)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(CAST_BAR_FRAME_LEVEL)
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
    bar.anchorOptions = config.anchorOptions or { horizontal = false, vertical = true, syncScale = true, syncDimensions = true }

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
    bar.orbitBar, bar.Text, bar.Timer, bar.Icon = skinned, skinned.Text, skinned.Timer, skinned.Icon
    bar.Border, bar.Latency, bar.InterruptOverlay, bar.InterruptAnim = skinned.Border, skinned.Latency, skinned.InterruptOverlay, skinned.InterruptAnim
    if skinned.Spark then
        skinned.Spark:Hide()
    end
    if skinned.SparkGlow then
        skinned.SparkGlow:Hide()
    end
    return skinned
end

-- [ EDIT MODE & EVENTS ]---------------------------------------------------------------------------

function Mixin:RegisterEditModeCallbacks(bar)
    if not EventRegistry or bar.orbitEditModeCallbacksRegistered then
        return
    end
    bar.orbitEditModeCallbacksRegistered = true
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
            if not (Orbit:IsEditMode()) and not bar.casting and not bar.channeling then
                bar:Hide()
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

function Mixin:AddCastBarSettings(dialog, systemFrame)
    local bar = self.CastBar
    if not bar then
        return
    end

    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic
    local schema = { hideNativeSettings = true, controls = {} }

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Colour" }, "Layout")

    if currentTab == "Layout" then
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(bar) ~= nil
        local anchorAxis = isAnchored and self:GetAnchorAxis(bar) or nil
        if not (isAnchored and anchorAxis == "x") then
            WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, {
                key = "CastBarHeight",
                label = "Height",
                min = 15,
                max = 35,
                default = 18,
            })
        end
        if not (isAnchored and anchorAxis == "y") then
            table.insert(schema.controls, {
                type = "slider",
                key = "CastBarWidth",
                label = "Width",
                min = 120,
                max = 350,
                step = 10,
                default = 200,
            })
        end
        table.insert(schema.controls, { type = "checkbox", key = "CastBarText", label = "Show Spell Name", default = true })
        table.insert(schema.controls, { type = "checkbox", key = "CastBarIcon", label = "Show Icon", default = true })
        table.insert(schema.controls, { type = "checkbox", key = "CastBarTimer", label = "Show Timer", default = true })
    elseif currentTab == "Colour" then
        WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "CastBarColorCurve",
            label = "Normal",
            default = { pins = { { position = 0, color = DEFAULT_CAST_COLOR } } },
            singleColor = true,
        })
        WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "NonInterruptibleColorCurve",
            label = "Protected",
            default = { pins = { { position = 0, color = DEFAULT_PROTECTED_COLOR } } },
            singleColor = true,
        })
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
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
    local curveData = self:GetSetting(systemIndex, "CastBarColorCurve")
    local color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData) or self:GetSetting(systemIndex, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
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
            bar.Spark:SetHeight(height + SPARK_OVERFLOW)
        end

        -- Latency height
        if bar.Latency then
            bar.Latency:SetHeight(height)
        end
    end)

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
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            backdropColor = backdropColor,
            sparkColor = sparkColor,
        })
    end
    if Orbit:IsEditMode() then
        self:ShowPreview()
    end
end

-- [ PREVIEW ]---------------------------------------------------------------------------------------

function Mixin:ShowPreview()
    local bar = self.CastBar
    if not bar then
        return
    end
    bar.preview, bar.casting, bar.channeling = true, false, false
    local targetBar = bar.orbitBar or bar
    targetBar:SetMinMaxValues(0, 3)
    targetBar:SetValue(1.5)
    if bar.Text then
        bar.Text:SetText(self.previewText or "Preview Cast")
    end
    if bar.Icon then
        bar.Icon:SetTexture(136243)
    end
    if bar.Timer then
        bar.Timer:SetText("1.5")
    end
    bar:Show()
end

-- [ STANDALONE EVENT-DRIVEN CAST BAR (Target/Focus) ]----------------------------------------------

local TIMER_THROTTLE_INTERVAL = 0.1
local INTERRUPT_FLASH_DURATION = Orbit.Constants.Timing.FlashDuration

-- Register all cast events directly on the bar frame for a given unit
function Mixin:RegisterUnitCastEvents(bar, unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
    if unit == "target" then
        bar:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif unit == "focus" then
        bar:RegisterEvent("PLAYER_FOCUS_CHANGED")
    end
end

-- Setup a standalone cast bar with direct event handling
function Mixin:SetupUnitCastBar(bar, unit, nativeSpellbar)
    bar.orbitUnit = unit
    bar.nativeSpellbar = nativeSpellbar
    local plugin = self

    -- Cast: query APIs and use SetTimerDuration for engine-driven animation
    function bar:Cast()
        local targetBar = self.orbitBar or self
        local name, text, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
        local isChanneled = false
        if not name then
            name, text, texture, _, _, _, notInterruptible = UnitChannelInfo(unit)
            if name then
                isChanneled = true
            end
        end
        if not name then
            self:StopCast()
            return
        end
        -- Get duration object for engine-driven animation (WoW 12.0+)
        local getDurationFn = isChanneled and UnitChannelDuration or UnitCastingDuration
        local durationObj = nil
        if type(getDurationFn) == "function" then
            local ok, dur = pcall(getDurationFn, unit)
            if ok then
                durationObj = dur
            end
        end
        if not durationObj then
            self:StopCast()
            return
        end
        self.casting = not isChanneled
        self.channeling = isChanneled
        self.castTimestamp = GetTime()
        self.durationObj = durationObj
        self.timerThrottle = 0
        -- Engine-driven: let SetTimerDuration animate the bar (direction: 0=fill, 1=drain)
        local direction = isChanneled and 1 or 0
        if targetBar.SetTimerDuration then
            pcall(targetBar.SetTimerDuration, targetBar, durationObj, 0, direction)
        end
        -- Safely check notInterruptible (may be a secret boolean for enemy units in combat).
        -- pcall catches the taint error if it's secret; events will correct it in that case.
        local ok, isProtected = pcall(function()
            return notInterruptible and true or false
        end)
        if ok and isProtected then
            self.notInterruptible = true
            plugin:ApplyCastColor(self, "NON_INTERRUPTIBLE")
        else
            self.notInterruptible = false
            plugin:ApplyCastColor(self, "INTERRUPTIBLE")
        end
        if self.Text then
            self.Text:SetText(name)
        end
        if self.Icon then
            self.Icon:SetTexture(texture or 136243)
        end
        self:Show()
    end

    -- StopCast: clear state and hide
    function bar:StopCast()
        self.casting = false
        self.channeling = false
        self.durationObj = nil
        if not self.preview then
            self:Hide()
        end
    end

    -- Event dispatch table
    local dispatch = {
        UNIT_SPELLCAST_START = function()
            bar:Cast()
        end,
        UNIT_SPELLCAST_CHANNEL_START = function()
            bar:Cast()
        end,
        UNIT_SPELLCAST_DELAYED = function()
            bar:Cast()
        end,
        UNIT_SPELLCAST_CHANNEL_UPDATE = function()
            bar:Cast()
        end,
        PLAYER_TARGET_CHANGED = function()
            bar:Cast()
        end,
        PLAYER_FOCUS_CHANGED = function()
            bar:Cast()
        end,
        UNIT_SPELLCAST_STOP = function()
            bar:StopCast()
        end,
        UNIT_SPELLCAST_CHANNEL_STOP = function()
            bar:StopCast()
        end,
        UNIT_SPELLCAST_FAILED = function()
            if UnitChannelInfo(unit) or UnitCastingInfo(unit) then
                return
            end
            local failTimestamp = bar.castTimestamp
            bar.casting = false
            bar.channeling = false
            bar.durationObj = nil
            if bar.Text then
                bar.Text:SetText(FAILED)
            end
            C_Timer.After(INTERRUPT_FLASH_DURATION, function()
                if bar.castTimestamp == failTimestamp and not bar.casting and not bar.channeling then
                    bar:StopCast()
                end
            end)
        end,
        UNIT_SPELLCAST_INTERRUPTED = function()
            local interruptTimestamp = bar.castTimestamp
            bar.casting = false
            bar.channeling = false
            bar.durationObj = nil
            if bar.Text then
                bar.Text:SetText(INTERRUPTED)
            end
            if bar.InterruptAnim then
                bar.InterruptAnim:Play()
            end
            if bar.orbitBar then
                bar.orbitBar:SetStatusBarColor(1, 0, 0)
            end
            C_Timer.After(INTERRUPT_FLASH_DURATION, function()
                if bar.castTimestamp == interruptTimestamp and not bar.casting and not bar.channeling then
                    bar:StopCast()
                    plugin:ApplyCastColor(bar, "INTERRUPTIBLE")
                end
            end)
        end,
        UNIT_SPELLCAST_INTERRUPTIBLE = function()
            bar.notInterruptible = false
            plugin:ApplyCastColor(bar, "INTERRUPTIBLE")
        end,
        UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function()
            bar.notInterruptible = true
            plugin:ApplyCastColor(bar, "NON_INTERRUPTIBLE")
        end,
    }

    bar:SetScript("OnEvent", function(_, event)
        local handler = dispatch[event]
        if handler then
            handler()
        end
    end)
end

-- Setup OnUpdate handler for engine-driven cast bars (timer text only, no progress arithmetic)
function Mixin:SetupCastBarOnUpdate(bar)
    bar:SetScript("OnUpdate", function(self, elapsed)
        if not self:IsShown() or self.preview then
            return
        end
        if not self.casting and not self.channeling then
            return
        end
        -- Timer text: read remaining from durationObj (SetText accepts secrets as a sink)
        self.timerThrottle = (self.timerThrottle or 0) + elapsed
        if self.timerThrottle < TIMER_THROTTLE_INTERVAL then
            return
        end
        self.timerThrottle = 0
        if not self.Timer or not self.Timer:IsShown() then
            return
        end
        if not self.durationObj then
            return
        end
        local getter = self.durationObj.GetRemainingDuration or self.durationObj.GetRemaining
        if getter then
            local ok, remaining = pcall(getter, self.durationObj)
            if ok and remaining then
                self.Timer:SetFormattedText("%.1f", remaining)
            end
        end
    end)
end
