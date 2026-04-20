-- [ ORBIT CAST BAR MIXIN ]--------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local L = Orbit.L
local OrbitEngine = Orbit.Engine

---@class OrbitCastBarMixin
Orbit.CastBarMixin = {}
local Mixin = Orbit.CastBarMixin

local CAST_BAR_CANCEL_THRESHOLD = 0.15
local SPARK_OVERFLOW = 4
local DEFAULT_CAST_COLOR = { r = 1, g = 0.7, b = 0 }
local DEFAULT_PROTECTED_COLOR = { r = 0.7, g = 0.7, b = 0.7 }

Mixin.sharedDefaults = {
    CastBarColor = { r = 1, g = 0.7, b = 0 },
    CastBarColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0, a = 1 } } } },
    NonInterruptibleColor = { r = 0.7, g = 0.7, b = 0.7 },
    NonInterruptibleColorCurve = { pins = { { position = 0, color = { r = 0.7, g = 0.7, b = 0.7, a = 1 } } } },
    CastBarText = true,
    CastBarIcon = 1,
    CastBarTimer = true,
    CastBarHeight = 18,
    CastBarWidth = 200,
    CastBarTextSize = 10,
    CastBarScale = 100,
}

-- [ SHARED UTILITIES ]------------------------------------------------------------------------------

function Mixin:GetAnchorAxis(frame)
    return OrbitEngine.Frame:GetAnchorAxis(frame)
end

function Mixin:ResolveProtectedColor()
    local curveData = self:GetSetting(1, "NonInterruptibleColorCurve")
    return OrbitEngine.ColorCurve:GetFirstColorFromCurve(curveData) or self:GetSetting(1, "NonInterruptibleColor") or DEFAULT_PROTECTED_COLOR
end

function Mixin:ApplyCastColor(bar, state)
    if not bar or not bar.orbitBar then return end
    local color
    if state == "NON_INTERRUPTIBLE" then
        color = self:ResolveProtectedColor()
    else
        local curveData = self:GetSetting(1, "CastBarColorCurve")
        color = OrbitEngine.ColorCurve:GetFirstColorFromCurve(curveData) or self:GetSetting(1, "CastBarColor") or DEFAULT_CAST_COLOR
    end
    bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
end

function Mixin:UpdateInterruptState(bar, notInterruptible)
    if not bar then return end
    bar.notInterruptible = notInterruptible
    self:ApplyCastColor(bar, notInterruptible and "NON_INTERRUPTIBLE" or "INTERRUPTIBLE")
end

-- [ FRAME CREATION ]--------------------------------------------------------------------------------

function Mixin:CreateCastBarFrame(name, config)
    config = config or {}

    local bar = CreateFrame("StatusBar", name, UIParent)
    bar:SetSize(config.width or Orbit.Constants.PlayerCastBar.DefaultWidth or 200, config.height or Orbit.Constants.PlayerCastBar.DefaultHeight or 18)
    bar:SetPoint("CENTER", 0, config.yOffset or Orbit.Constants.PlayerCastBar.DefaultY or -150)
    bar:SetFrameStrata(Orbit.Constants.Strata.HUD)
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
    bar.orbitResizeBounds = { minW = 100, maxW = 600, minH = 5, maxH = 40, widthKey = "CastBarWidth", heightKey = "CastBarHeight" }

    -- Attach to Frame system
    OrbitEngine.Frame:AttachSettingsListener(bar, self, 1)

    return bar
end

-- [ SKIN INITIALIZATION ]---------------------------------------------------------------------------

function Mixin:InitializeSkin(bar)
    if not Orbit.Skin.CastBar then return end
    local skinned = Orbit.Skin.CastBar:Create(bar)
    bar.orbitBar, bar.Text, bar.Timer, bar.Icon = skinned, skinned.Text, skinned.Timer, skinned.Icon
    bar.Latency, bar.InterruptOverlay, bar.InterruptAnim = skinned.Latency, skinned.InterruptOverlay, skinned.InterruptAnim
    if skinned.Spark then skinned.Spark:Hide() end
    if skinned.SparkGlow then skinned.SparkGlow:Hide() end
    -- Protected overlay: mirrors orbitBar but with the protected color.
    -- SetAlphaFromBoolean drives visibility from the secret notInterruptible value.
    local overlay = CreateFrame("StatusBar", nil, skinned)
    overlay:SetAllPoints(skinned)
    overlay:SetMinMaxValues(0, 1)
    overlay:SetValue(0)
    overlay:SetFrameLevel(skinned:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
    overlay:SetAlpha(0)
    bar.protectedOverlay = overlay
    -- Raise text above the protected overlay so it isn't obscured
    local textContainer = CreateFrame("Frame", nil, skinned)
    textContainer:SetAllPoints(skinned)
    textContainer:SetFrameLevel(overlay:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
    textContainer:EnableMouse(false)
    if skinned.Text then skinned.Text:SetParent(textContainer) end
    if skinned.Timer then skinned.Timer:SetParent(textContainer) end
    return skinned
end

-- [ EDIT MODE & EVENTS ] ----------------------------------------------------------------------------

function Mixin:RegisterEditModeCallbacks(bar)
    if not EventRegistry or bar.orbitEditModeCallbacksRegistered then
        return
    end
    bar.orbitEditModeCallbacksRegistered = true
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        self:ApplySettings()
        -- Defer preview teardown to next frame so it runs AFTER Tour:EndTour()
        -- restores all hidden frames (HookScript fires after EventRegistry).
        C_Timer.After(0, function()
            bar.preview = false
            if not bar.casting and not bar.channeling then
                bar:Hide()
            end
        end)
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
    Orbit.EventBus:On("MOUNTED_VISIBILITY_CHANGED", function() self:UpdateVisibility() end, self)
end

function Mixin:RestorePositionDebounced(bar, debounceKey)
    Orbit.Async:Debounce(debounceKey .. "_LoadPosition", function()
        OrbitEngine.Frame:RestorePosition(bar, self, 1)
    end, 0.1)
end

-- [ SETTINGS UI (SHARED SCHEMA BUILDER) ] -----------------------------------------------------------

function Mixin:AddCastBarSettings(dialog, systemFrame)
    local bar = self.CastBar
    if not bar then
        return
    end

    local systemIndex = systemFrame.systemIndex or 1
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Colour" }, "Layout")

    if currentTab == "Layout" then
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(bar) ~= nil
        local anchorAxis = isAnchored and self:GetAnchorAxis(bar) or nil
        if not (isAnchored and anchorAxis == "x") then
            SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, {
                key = "CastBarHeight",
                label = "Height",
                min = 5,
                max = 40,
                default = 18,
            })
        end
        if not (isAnchored and anchorAxis == "y") then
            table.insert(schema.controls, {
                type = "slider",
                key = "CastBarWidth",
                label = "Width",
                min = 100,
                max = 600,
                step = 10,
                default = 200,
            })
        end
        table.insert(schema.controls, { type = "checkbox", key = "CastBarText", label = "Show Spell Name", default = true })
        -- Migrate legacy boolean CastBarIcon (true = Left/1, false = Off/2) to numeric slider value.
        local storedIconPos = self:GetSetting(systemIndex, "CastBarIcon")
        if type(storedIconPos) == "boolean" then
            self:SetSetting(systemIndex, "CastBarIcon", storedIconPos and 1 or 2)
        end
        table.insert(schema.controls, {
            type = "slider", key = "CastBarIcon", label = L.CMN_ICON_POSITION,
            min = 1, max = 3, step = 1, default = 1,
            formatter = function(v)
                if v == 1 then return L.CMN_ICON_LEFT end
                if v == 3 then return L.CMN_ICON_RIGHT end
                return L.CMN_ICON_OFF
            end,
            onChange = function(val)
                self:SetSetting(systemIndex, "CastBarIcon", val)
                self:ApplySettings(systemFrame)
            end,
        })
        table.insert(schema.controls, { type = "checkbox", key = "CastBarTimer", label = "Show Timer", default = true })
    elseif currentTab == "Colour" then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "CastBarColorCurve",
            label = "Normal",
            default = { pins = { { position = 0, color = DEFAULT_CAST_COLOR } } },
            singleColor = true,
        })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "NonInterruptibleColorCurve",
            label = "Protected",
            default = { pins = { { position = 0, color = DEFAULT_PROTECTED_COLOR } } },
            singleColor = true,
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ APPLY SETTINGS (SHARED) ] -----------------------------------------------------------------------

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
    local iconPos = self:GetSetting(systemIndex, "CastBarIcon")
    -- Back-compat: legacy boolean, nil → Left default.
    if type(iconPos) == "boolean" then iconPos = iconPos and 1 or 2 end
    if type(iconPos) ~= "number" then iconPos = 1 end
    local showIcon = iconPos ~= 2
    local textSize = 10
    local showTimer = self:GetSetting(systemIndex, "CastBarTimer")
    local curveData = self:GetSetting(systemIndex, "CastBarColorCurve")
    local color = OrbitEngine.ColorCurve:GetFirstColorFromCurve(curveData) or self:GetSetting(systemIndex, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
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
            iconAtEnd = iconPos == 3,
            showTimer = showTimer,
            font = fontName,
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            backdropColor = backdropColor,
            sparkColor = sparkColor,
        })
    end
    -- Sync protected overlay texture and color
    if bar.protectedOverlay then
        local LSM = LibStub("LibSharedMedia-3.0")
        local texPath = LSM:Fetch("statusbar", texture or "Blizzard")
        bar.protectedOverlay:SetStatusBarTexture(texPath)
        local pColor = self:ResolveProtectedColor()
        bar.protectedOverlay:SetStatusBarColor(pColor.r, pColor.g, pColor.b)
    end
    if bar.casting or bar.channeling then
        self:ApplyCastColor(bar, bar.notInterruptible and "NON_INTERRUPTIBLE" or "INTERRUPTIBLE")
    end
    if Orbit:IsEditMode() and not self._previewShownThisFrame then
        self._previewShownThisFrame = true
        C_Timer.After(0, function() self._previewShownThisFrame = nil end)
        self:ShowPreview()
    end

    local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(bar, self, systemIndex, "OutOfCombatFade", enableHover) end
end

-- [ MOUNTED VISIBILITY ]----------------------------------------------------------------------------

function Mixin:UpdateVisibility()
    local bar = self.CastBar
    if not bar then return end
    if not InCombatLockdown() then
        if Orbit.VisibilityEngine and Orbit.VisibilityEngine:IsFrameMountedHidden(self.name, 1) then
            if bar.StopCast then bar:StopCast() end
            return
        end
    end
    if not bar.casting and not bar.channeling and not bar.preview then
        if bar.StopCast then bar:StopCast() end
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
    if bar.protectedOverlay then bar.protectedOverlay:SetAlpha(0) end
    if bar.Text then bar.Text:SetText(self.previewText or "Preview Cast") end
    if bar.Icon then bar.Icon:SetTexture(136243) end
    if bar.Timer then bar.Timer:SetText("1.5") end
    bar:Show()
end

-- [ STANDALONE EVENT-DRIVEN CAST BAR (Target/Focus) ] -----------------------------------------------

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
    -- WoW does not fire UNIT_SPELLCAST_STOP when the caster dies; use UNIT_HEALTH to detect death.
    bar:RegisterUnitEvent("UNIT_HEALTH", unit)
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

    function bar:Cast()
        if unit ~= "player" and not InCombatLockdown() then
            if Orbit.VisibilityEngine and Orbit.VisibilityEngine:IsFrameMountedHidden(plugin.name, 1) then return end
        end
        local targetBar = self.orbitBar or self
        local name, text, texture, startMs, endMs, _, _, notInterruptible = UnitCastingInfo(unit)
        local isChanneled = false
        if not name then
            name, text, texture, startMs, endMs, _, notInterruptible = UnitChannelInfo(unit)
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
        -- Build a curve mapping remaining-percent [0,1] -> remaining-seconds [0, totalSec]
        -- so OnUpdate can read a formatted timer via durObj:EvaluateRemainingPercent without
        -- Lua arithmetic. startMs/endMs can be secret for enemy units in combat; when they
        -- are, we skip the curve and the timer text simply stays blank for that cast.
        self.timerSecondsCurve = nil
        if C_CurveUtil and C_CurveUtil.CreateCurve and startMs and endMs
            and not issecretvalue(startMs) and not issecretvalue(endMs) then
            local totalSec = (endMs - startMs) / 1000
            if totalSec > 0 then
                local curve = C_CurveUtil.CreateCurve()
                curve:AddPoint(0, 0)
                curve:AddPoint(1, totalSec)
                self.timerSecondsCurve = curve
            end
        end
        -- Engine-driven: let SetTimerDuration animate the bar (direction: 0=fill, 1=drain)
        local direction = isChanneled and 1 or 0
        if targetBar.SetTimerDuration then
            pcall(targetBar.SetTimerDuration, targetBar, durationObj, 0, direction)
        end
        -- Protected overlay: secret-value-safe interrupt color via SetAlphaFromBoolean.
        -- notInterruptible is a secret boolean in combat for enemy units (WoW 12.0+).
        local overlay = self.protectedOverlay
        if overlay and notInterruptible ~= nil then
            if overlay.SetTimerDuration then
                pcall(overlay.SetTimerDuration, overlay, durationObj, 0, direction)
            end
            overlay:SetAlphaFromBoolean(notInterruptible, 1, 0)
        elseif overlay then
            overlay:SetAlpha(0)
        end
        -- Non-secret fallback for out-of-combat / event-driven state
        if notInterruptible ~= nil and not issecretvalue(notInterruptible) then
            self.notInterruptible = notInterruptible
        end
        plugin:ApplyCastColor(self, self.notInterruptible and "NON_INTERRUPTIBLE" or "INTERRUPTIBLE")
        if self.Text then self.Text:SetText(name) end
        if self.Icon then self.Icon:SetTexture(texture or 136243) end
        if InCombatLockdown() and self:IsProtected() then
            self:SetAlpha(1)
            if self.orbitBar then self.orbitBar:SetAlpha(1) end
        else
            self:Show()
        end
    end

    -- StopCast: clear state and hide
    function bar:StopCast()
        self.casting = false
        self.channeling = false
        self.durationObj = nil
        self.timerSecondsCurve = nil
        if self.Timer then self.Timer:SetText("") end
        if self.protectedOverlay then self.protectedOverlay:SetAlpha(0) end
        if not self.preview then
            if InCombatLockdown() and self:IsProtected() then
                self:SetAlpha(0)
                if self.orbitBar then self.orbitBar:SetAlpha(0) end
            else
                self:Hide()
            end
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
            bar.notInterruptible = false
            bar:Cast()
        end,
        PLAYER_FOCUS_CHANGED = function()
            bar.notInterruptible = false
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
            bar:StopCast()
        end,
        UNIT_SPELLCAST_INTERRUPTIBLE = function()
            bar.notInterruptible = false
            plugin:ApplyCastColor(bar, "INTERRUPTIBLE")
        end,
        UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function()
            bar.notInterruptible = true
            plugin:ApplyCastColor(bar, "NON_INTERRUPTIBLE")
        end,
        UNIT_HEALTH = function()
            if (bar.casting or bar.channeling) and UnitIsDeadOrGhost(unit) then
                bar:StopCast()
            end
        end,
    }

    bar:SetScript("OnEvent", function(_, event)
        local handler = dispatch[event]
        if handler then
            local profilerActive = Orbit.Profiler and Orbit.Profiler:IsActive()
            local start = profilerActive and debugprofilestop() or nil
            handler()
            if start then
                Orbit.Profiler:RecordContext(plugin.system or plugin.name or "Orbit_CastBar", event, debugprofilestop() - start)
            end
        end
    end)

    -- Pre-show at alpha=0 on combat enter so alpha-toggle works for protected frames
    bar:RegisterEvent("PLAYER_REGEN_DISABLED")
    bar:RegisterEvent("PLAYER_REGEN_ENABLED")
    bar:HookScript("OnEvent", function(self, event)
        if not self:IsProtected() then return end
        if event == "PLAYER_REGEN_DISABLED" and not self:IsShown() then
            self:Show()
            self:SetAlpha(0)
            if self.orbitBar then self.orbitBar:SetAlpha(0) end
            self.orbitHiddenByAlpha = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            if not self.casting and not self.channeling and not self.preview then
                self:Hide()
            end
            self.orbitHiddenByAlpha = false
        end
    end)
end

-- Setup OnUpdate handler for engine-driven cast bars (timer text only, no progress arithmetic)
function Mixin:SetupCastBarOnUpdate(bar)
    bar:SetScript("OnUpdate", function(self, elapsed)
        local profilerActive = Orbit.Profiler and Orbit.Profiler:IsActive()
        local start = profilerActive and debugprofilestop() or nil

        if not self:IsShown() or self.preview then
            if start then Orbit.Profiler:RecordContext(self.orbitPlugin and (self.orbitPlugin.system or self.orbitPlugin.name) or "Orbit_CastBar", "OnUpdate", debugprofilestop() - start) end
            return
        end
        if not self.casting and not self.channeling then
            if start then Orbit.Profiler:RecordContext(self.orbitPlugin and (self.orbitPlugin.system or self.orbitPlugin.name) or "Orbit_CastBar", "OnUpdate", debugprofilestop() - start) end
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
        if not self.durationObj or not self.timerSecondsCurve then
            return
        end
        -- Evaluate remaining seconds via curve (no Lua arithmetic). EvaluateRemainingPercent
        -- can return a secret when the cast source is secret; string.format would throw, so
        -- only format in the non-secret path. Omitting the update leaves the previous value
        -- visible, which is acceptable since the bar itself is engine-driven.
        local remaining = self.durationObj:EvaluateRemainingPercent(self.timerSecondsCurve)
        if not issecretvalue(remaining) and type(remaining) == "number" then
            if remaining < 0 then remaining = 0 end
            self.Timer:SetFormattedText("%.1f", remaining)
        end
        
        if start then
            Orbit.Profiler:RecordContext(self.orbitPlugin and (self.orbitPlugin.system or self.orbitPlugin.name) or "Orbit_CastBar", "OnUpdate", debugprofilestop() - start)
        end
    end)
end
