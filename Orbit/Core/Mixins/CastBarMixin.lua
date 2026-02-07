-- [ ORBIT CAST BAR MIXIN ]--------------------------------------------------------------------------
-- Shared functionality for PlayerCastBar, TargetCastBar, FocusCastBar

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

---@class OrbitCastBarMixin
Orbit.CastBarMixin = {}
local Mixin = Orbit.CastBarMixin

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

-- Keys that Target/Focus cast bars inherit from Player Cast Bar
Mixin.INHERITED_KEYS = {
    CastBarColor = true,
    CastBarColorCurve = true,
    NonInterruptibleColor = true,
    InterruptedColor = true,
    CastBarText = true,
    CastBarIcon = true,
    CastBarTimer = true,
    SparkColor = true,
}

-- Override GetSetting to inherit specific keys from Player Cast Bar
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

function Mixin:GetAnchorAxis(frame)
    return OrbitEngine.Frame:GetAnchorAxis(frame)
end

function Mixin:ApplyCastColor(bar, state)
    if not bar or not bar.orbitBar then return end
    local color
    if state == "INTERRUPTED" then
        color = self:GetSetting(1, "InterruptedColor") or { r = 1, g = 0, b = 0 }
    elseif state == "NON_INTERRUPTIBLE" then
        color = self:GetSetting(1, "NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
    else
        local curveData = self:GetSetting(1, "CastBarColorCurve")
        color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData) or self:GetSetting(1, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
    end
    if color then bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b) end
end

-- [ FRAME CREATION ]--------------------------------------------------------------------------------

function Mixin:CreateCastBarFrame(name, config)
    config = config or {}

    local bar = CreateFrame("StatusBar", name, UIParent)
    bar:SetSize(config.width or Orbit.Constants.PlayerCastBar.DefaultWidth or 200, config.height or Orbit.Constants.PlayerCastBar.DefaultHeight or 18)
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
            if not (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()) and not bar.casting and not bar.channeling then
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
    table.insert(schema.controls, { type = "checkbox", key = "CastBarText", label = "Show Spell Name", default = true })
    table.insert(schema.controls, { type = "checkbox", key = "CastBarTimer", label = "Show Timer", default = true })
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

-- [ HOOK-BASED CAST BAR HELPERS (Target/Focus) ]---------------------------------------------------

function Mixin:SetupSpellbarHooks(nativeSpellbar, unit)
    if not nativeSpellbar then
        return
    end
    local bar = self.CastBar
    bar.orbitUnit = unit

    local function SyncCastData(nativeBar)
        if not bar or not nativeBar then
            return
        end
        local iconTexture = nativeBar.Icon and nativeBar.Icon:GetTexture()
            or (C_Spell.GetSpellTexture and nativeBar.spellID and C_Spell.GetSpellTexture(nativeBar.spellID))
        if bar.Icon then
            bar.Icon:SetTexture(iconTexture or 136243)
        end
        if nativeBar.Text and bar.Text then
            bar.Text:SetText(nativeBar.Text:GetText() or "Casting...")
        end
        local min, max = nativeBar:GetMinMaxValues()
        if min and max then
            local targetBar = bar.orbitBar or bar
            targetBar:SetMinMaxValues(min, max)
            targetBar:SetValue(nativeBar:GetValue() or 0)
        end
        self:UpdateInterruptState(nativeBar, bar, unit)
    end

    nativeSpellbar:HookScript("OnShow", function(nativeBar)
        if not bar then
            return
        end
        SyncCastData(nativeBar)
        bar:Show()
    end)
    nativeSpellbar:HookScript("OnHide", function()
        if bar and not bar.preview then
            bar:Hide()
        end
    end)

    local changeEvent = (unit == "target") and "PLAYER_TARGET_CHANGED" or "PLAYER_FOCUS_CHANGED"
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent(changeEvent)
    eventFrame:SetScript("OnEvent", function()
        if not bar then
            return
        end
        if nativeSpellbar:IsShown() then
            SyncCastData(nativeSpellbar)
        elseif not bar.preview then
            bar:Hide()
        end
    end)

    nativeSpellbar:HookScript("OnEvent", function(nativeBar, event, eventUnit)
        if eventUnit ~= unit or not bar or not bar:IsShown() then
            return
        end
        if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
            self:ApplyCastColor(bar, "INTERRUPTED")
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            self:ApplyCastColor(bar, "NON_INTERRUPTIBLE")
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            self:ApplyCastColor(bar, "INTERRUPTIBLE")
        elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            self:UpdateInterruptState(nativeBar, bar, unit)
        end
    end)

    local lastUpdate, updateThrottle = 0, 1 / 60
    nativeSpellbar:HookScript("OnUpdate", function(nativeBar, elapsed)
        if not bar or not bar:IsShown() then return end
        lastUpdate = lastUpdate + elapsed
        if lastUpdate < updateThrottle then return end
        lastUpdate = 0
        local progress = nativeBar:GetValue()
        local min, max = nativeBar:GetMinMaxValues()
        local targetBar = bar.orbitBar or bar
        if progress and max then
            targetBar:SetMinMaxValues(min, max)
            targetBar:SetValue(progress)
            
            -- Apply color from ColorCurve (if interruptible)
            -- Note: Target/Focus use secret values, so we use static first color (dynamic sampling fails)
            if not bar.notInterruptible then
                local curveData = self:GetSetting(1, "CastBarColorCurve")
                if curveData then
                    local color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData)
                    if color then targetBar:SetStatusBarColor(color.r, color.g, color.b) end
                end
            end
            
            pcall(function()
                if max <= 0 then return end
                if bar.Timer and bar.Timer:IsShown() then
                    bar.Timer:SetText(string.format("%.1f", nativeBar.channeling and progress or (max - progress)))
                end
            end)
        end
    end)
end

-- Check interrupt state via native BorderShield visibility (avoids secret value taint)
function Mixin:UpdateInterruptState(nativeBar, bar, unit)
    local notInterruptible = false
    if nativeBar and nativeBar.BorderShield then
        local ok, result = pcall(function()
            return nativeBar.BorderShield:IsShown()
        end)
        if ok then
            notInterruptible = result
        end
    end
    local color
    if notInterruptible then
        color = self:GetSetting(1, "NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
    else
        local curveData = self:GetSetting(1, "CastBarColorCurve")
        color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData) or self:GetSetting(1, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
    end
    if bar.orbitBar and color then bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b) end
end
