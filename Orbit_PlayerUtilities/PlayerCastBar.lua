---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Player Cast Bar", "Orbit_PlayerCastBar", {
    defaults = {
        CastBarColor = { r = 1, g = 0.7, b = 0 },
        CastBarColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0, a = 1 } } } },
        NonInterruptibleColor = { r = 0.7, g = 0.7, b = 0.7 },
        NonInterruptibleColorCurve = { pins = { { position = 0, color = { r = 0.7, g = 0.7, b = 0.7, a = 1 } } } },
        CastBarText = true,
        CastBarIcon = true,
        CastBarTimer = true,
        CastBarHeight = 35,
        CastBarWidth = 300,
        CastBarTextSize = 10,
        CastBarScale = 100,
        ShowLatency = true,
        SparkColor = { r = 1, g = 1, b = 1, a = 1 },
        SparkColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } },
    },
})

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local INTERRUPT_FLASH_DURATION = Orbit.Constants.Timing.FlashDuration
local EMPOWER_STAGE_COLORS = Orbit.Colors.EmpowerStage
local CASTBAR_FRAME_LEVEL = 10
local SPARK_HEIGHT_PADDING = 4
local SCALE_DIVISOR = 100
local PREVIEW_ICON_ID = 136243
local PREVIEW_CAST_DURATION = 3
local PREVIEW_CAST_PROGRESS = 1.5
local CastBar

-- [ HELPERS ]---------------------------------------------------------------------------------------
local function DisableBlizzardCastBar()
    if not PlayerCastingBarFrame then return end
    OrbitEngine.NativeFrame:Disable(PlayerCastingBarFrame, { unregisterEvents = true })
end

local function GetAnchorAxis(frame) return OrbitEngine.Frame:GetAnchorAxis(frame) end
local function SnapToPixel(value, scale) return OrbitEngine.Pixel:Snap(value, scale) end

local function CalculateSparkPos(bar, value, maxValue)
    local orbitBar = bar.orbitBar or bar
    local pos = (maxValue > 0) and ((value / maxValue) * orbitBar:GetWidth()) or 0
    return SnapToPixel(pos, bar:GetEffectiveScale())
end

local function SampleColorCurve(curveData, position)
    return OrbitEngine.WidgetLogic:SampleColorCurve(curveData, position)
end
local SafeShow = Orbit.PlayerUtilShared.SafeShow
local SafeHide = Orbit.PlayerUtilShared.SafeHide

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame, forceAnchorMode)
    if not CastBar then
        return
    end

    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic
    local schema = { hideNativeSettings = true, controls = {} }

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Colour" }, "Layout")

    if currentTab == "Layout" then
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(CastBar) ~= nil
        local anchorAxis = isAnchored and GetAnchorAxis(CastBar) or nil
        if not (isAnchored and anchorAxis == "x") then
            WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, {
                key = "CastBarHeight", label = "Height",
                min = 15, max = 35, default = Orbit.Constants.PlayerCastBar.DefaultHeight,
            })
        end
        if not (isAnchored and anchorAxis == "y") then
            table.insert(schema.controls, {
                type = "slider", key = "CastBarWidth", label = "Width",
                min = 120, max = 350, step = 10, default = Orbit.Constants.PlayerCastBar.DefaultWidth,
            })
        end
        table.insert(schema.controls, { type = "checkbox", key = "CastBarText", label = "Show Spell Name", default = true })
        table.insert(schema.controls, { type = "checkbox", key = "CastBarIcon", label = "Show Icon", default = true })
        table.insert(schema.controls, { type = "checkbox", key = "CastBarTimer", label = "Show Timer", default = true })
        table.insert(schema.controls, { type = "checkbox", key = "ShowLatency", label = "Show Latency", default = true })
    elseif currentTab == "Colour" then
        WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "CastBarColorCurve", label = "Normal",
            default = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0, a = 1 } } } },
        })
        WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "NonInterruptibleColorCurve", label = "Protected",
            default = { pins = { { position = 0, color = { r = 0.7, g = 0.7, b = 0.7, a = 1 } } } },
            singleColor = true,
        })
        WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "SparkColorCurve", label = "Spark / Glow",
            default = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } },
            singleColor = true,
        })
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create frame ONLY when plugin is enabled (OnLoad is only called for enabled plugins)
    CastBar = CreateFrame("StatusBar", "OrbitCastBar", UIParent)
    CastBar:SetSize(Orbit.Constants.PlayerCastBar.DefaultWidth, Orbit.Constants.PlayerCastBar.DefaultHeight)
    CastBar:SetPoint("CENTER", 0, Orbit.Constants.PlayerCastBar.DefaultY)
    OrbitEngine.Pixel:Enforce(CastBar)
    CastBar:SetFrameStrata("MEDIUM")
    CastBar:SetFrameLevel(CASTBAR_FRAME_LEVEL)
    CastBar:SetStatusBarTexture("")
    CastBar:SetMinMaxValues(0, 1)
    CastBar:SetValue(0)

    -- Edit Mode metadata
    CastBar.systemIndex = 1
    CastBar.orbitName = "Player Cast Bar"
    CastBar.editModeName = "Player Cast Bar"
    CastBar.orbitPlugin = self

    -- Cast state
    CastBar.casting = false
    CastBar.channeling = false
    CastBar.empowering = false
    CastBar.numStages = 0
    CastBar.currentStage = 0
    CastBar.stageDurations = {}
    CastBar.startTime = 0
    CastBar.endTime = 0
    CastBar.maxValue = 1
    CastBar.value = 0
    CastBar.castGUID = nil

    -- Attach to Frame system
    -- Configure frame options: Only Y stacking, sync dimensions/spacing scale
    CastBar.anchorOptions = { horizontal = false, vertical = true, syncScale = true, syncDimensions = true, mergeBorders = true }
    OrbitEngine.Frame:AttachSettingsListener(CastBar, self, 1)

    -- Restore position (debounced)
    Orbit.Async:Debounce("CastBar_LoadPosition", function()
        OrbitEngine.Frame:RestorePosition(CastBar, self, 1)
    end, 0.1)

    self.CastBar = CastBar
    self.Frame = CastBar

    -- Initialize Skin & Alias Regions
    if Orbit.Skin.CastBar then
        local skinned = Orbit.Skin.CastBar:Create(CastBar)
        -- Alias regions so event handlers work without modification
        CastBar.orbitBar = skinned -- Keep reference
        CastBar.Text = skinned.Text
        CastBar.Timer = skinned.Timer
        CastBar.Spark = skinned.Spark
        CastBar.Border = skinned.Border
        CastBar.Latency = skinned.Latency
        CastBar.InterruptOverlay = skinned.InterruptOverlay
        CastBar.InterruptAnim = skinned.InterruptAnim
        CastBar.SparkGlow = skinned.SparkGlow
    end

    -- Disable Blizzard's cast bar
    DisableBlizzardCastBar()

    -- Register cast events
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")

    -- Empower Events (Evoker spells)
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
    CastBar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")

    -- Event Handler
    CastBar:SetScript("OnEvent", function(frame, event, unit, castGUID, spellID)
        self:OnCastEvent(event, unit, castGUID, spellID)
    end)

    -- OnUpdate for progress
    CastBar:SetScript("OnUpdate", function(frame, elapsed)
        self:OnUpdate(elapsed)
    end)

    -- Edit Mode exits: hide bar if not casting
    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            CastBar.preview = false
            if not CastBar.casting and not CastBar.channeling then
                SafeHide(CastBar)
            end
            self:ApplySettings()
        end, self)
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            self:ShowPreview()
            self:ApplySettings()
        end, self)
    end

    -- Apply settings on login
    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        Orbit.Async:Debounce("CastBar_Init", function()
            self:ApplySettings()
            -- Hide bar until needed (not in Edit Mode)
            if not (Orbit:IsEditMode()) then
                if not CastBar.casting and not CastBar.channeling then
                    SafeHide(CastBar)
                end
            end
        end, 0.5)
    end, self)
end

-- [ MOUNTED VISIBILITY ]----------------------------------------------------------------------------
function Plugin:UpdateVisibility()
    local bar = self.CastBar
    if not bar then return end
    if Orbit.MountedVisibility and Orbit.MountedVisibility:ShouldHide() then
        bar.casting, bar.channeling, bar.empowering = false, false, false
        SafeHide(bar)
    end
end

-- [ SKINNING LOGIC ]---------------------------------------------------------------------------------

function Plugin:OnCastEvent(event, unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end
    local bar = self.CastBar
    if not bar then
        return
    end

    if event == "UNIT_SPELLCAST_START" then
        local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("player")
        if name then
            bar.casting = true
            bar.channeling = false
            bar.startTime = startTime / 1000
            bar.endTime = endTime / 1000
            bar.maxValue = bar.endTime - bar.startTime
            bar.notInterruptible = notInterruptible
            bar.castGUID = castGUID
            bar.castTimestamp = GetTime()

            local targetBar = bar.orbitBar or bar
            targetBar:SetMinMaxValues(0, bar.maxValue)
            targetBar:SetValue(0)
            self:ApplyColor() -- Ensure color is reset from potential interrupt state
            if bar.Text then
                bar.Text:SetText(name)
            end
            if bar.Icon then
                bar.Icon:SetTexture(texture)
            end

            -- Latency
            if bar.Latency then
                bar.Latency:Hide()
            end
            local showLatency = self:GetSetting(bar.systemIndex or 1, "ShowLatency")
            local _, _, _, latency = GetNetStats()
            if showLatency and bar.Latency and latency and bar.maxValue > 0 then
                local width = math.min(latency / 1000 / bar.maxValue, 1) * bar:GetWidth()
                width = SnapToPixel(width, bar:GetEffectiveScale())
                bar.Latency:ClearAllPoints()
                bar.Latency:SetWidth(math.max(width, 1))
                bar.Latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
                bar.Latency:SetHeight(bar:GetHeight())
                bar.Latency:Show()
            end

            SafeShow(bar)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo("player")
        if name then
            bar.casting = false
            bar.channeling = true
            bar.startTime = startTime / 1000
            bar.endTime = endTime / 1000
            bar.maxValue = bar.endTime - bar.startTime
            bar.notInterruptible = notInterruptible
            bar.castTimestamp = GetTime() -- For safe C_Timer callbacks

            local targetBar = bar.orbitBar or bar
            targetBar:SetMinMaxValues(0, bar.maxValue)
            targetBar:SetValue(bar.maxValue)
            self:ApplyColor() -- Ensure color is reset from potential interrupt state
            if bar.Text then
                bar.Text:SetText(name)
            end
            if bar.Icon then
                bar.Icon:SetTexture(texture)
            end

            -- Latency for channels (left side for "safe to clip")
            if bar.Latency then
                bar.Latency:Hide()
            end
            local showLatency = self:GetSetting(bar.systemIndex or 1, "ShowLatency")
            local _, _, _, latency = GetNetStats()
            if showLatency and bar.Latency and latency and bar.maxValue > 0 then
                local width = math.min(latency / 1000 / bar.maxValue, 1) * bar:GetWidth()
                width = SnapToPixel(width, bar:GetEffectiveScale())
                bar.Latency:ClearAllPoints()
                bar.Latency:SetWidth(math.max(width, 1))
                bar.Latency:SetPoint("LEFT", bar, "LEFT", 0, 0)
                bar.Latency:SetHeight(bar:GetHeight())
                bar.Latency:Show()
            end

            SafeShow(bar)
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        bar.casting = false
        bar.channeling = false
        if bar.Latency then
            bar.Latency:Hide()
        end
        SafeHide(bar)
    elseif event == "UNIT_SPELLCAST_FAILED" then
        if bar.castGUID == castGUID then
            bar.casting = false
            bar.channeling = false
            if bar.Latency then
                bar.Latency:Hide()
            end
            local failTimestamp = bar.castTimestamp
            if bar.Text then
                bar.Text:SetText(FAILED)
            end
            C_Timer.After(INTERRUPT_FLASH_DURATION, function()
                -- Only hide if no new cast has started
                if bar.castTimestamp == failTimestamp and not bar.casting and not bar.channeling then
                    SafeHide(bar)
                end
            end)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        bar.casting = false
        bar.channeling = false
        if bar.Latency then
            bar.Latency:Hide()
        end
        local interruptTimestamp = bar.castTimestamp
        if bar.Text then
            bar.Text:SetText(INTERRUPTED)
        end

        -- Interrupt Animation
        if bar.InterruptAnim then
            bar.InterruptAnim:Play()
        end

        -- Red flash
        if bar.orbitBar then
            bar.orbitBar:SetStatusBarColor(1, 0, 0)
        end

        C_Timer.After(INTERRUPT_FLASH_DURATION, function()
            -- Only hide/restore if no new cast has started
            if bar.castTimestamp == interruptTimestamp and not bar.casting and not bar.channeling then
                SafeHide(bar)
                self:ApplyColor() -- Restore color
            end
        end)
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        local name, text, texture, startTime, endTime = UnitCastingInfo("player")
        if name then
            bar.startTime = startTime / 1000
            bar.endTime = endTime / 1000
            bar.maxValue = bar.endTime - bar.startTime
            local targetBar = bar.orbitBar or bar
            targetBar:SetMinMaxValues(0, bar.maxValue)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local name, text, texture, startTime, endTime = UnitChannelInfo("player")
        if name then
            bar.startTime = startTime / 1000
            bar.endTime = endTime / 1000
            bar.maxValue = bar.endTime - bar.startTime
            local targetBar = bar.orbitBar or bar
            targetBar:SetMinMaxValues(0, bar.maxValue)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        bar.notInterruptible = false
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        bar.notInterruptible = true

    -- EMPOWER EVENTS
    elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
        local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, numStages = UnitChannelInfo("player")
        if name and numStages then
            bar.casting = false
            bar.channeling = false
            bar.empowering = true
            bar.startTime = startTime / 1000
            bar.endTime = endTime / 1000
            bar.maxValue = bar.endTime - bar.startTime
            bar.numStages = numStages
            bar.currentStage = 0
            bar.castTimestamp = GetTime()

            -- Calculate stage durations
            bar.stageDurations = {}
            local totalDuration = 0
            for i = 1, numStages do
                local stageDuration = GetUnitEmpowerStageDuration("player", i - 1) / 1000 -- Convert ms to seconds
                totalDuration = totalDuration + stageDuration
                bar.stageDurations[i] = totalDuration
            end

            local targetBar = bar.orbitBar or bar
            targetBar:SetMinMaxValues(0, bar.maxValue)
            targetBar:SetValue(0)

            -- Apply Stage 1 color
            local color = EMPOWER_STAGE_COLORS[1]
            if color then
                targetBar:SetStatusBarColor(color.r, color.g, color.b)
            end

            if bar.Text then
                bar.Text:SetText(name)
            end
            if bar.Icon then
                bar.Icon:SetTexture(texture)
            end

            -- Setup stage markers
            self:SetupEmpowerMarkers(bar, numStages)

            -- Hide Latency for empower
            if bar.Latency then
                bar.Latency:Hide()
            end

            SafeShow(bar)
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, numStages = UnitChannelInfo("player")
        if name then
            bar.startTime = startTime / 1000
            bar.endTime = endTime / 1000
            bar.maxValue = bar.endTime - bar.startTime
            local targetBar = bar.orbitBar or bar
            targetBar:SetMinMaxValues(0, bar.maxValue)
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        bar.casting = false
        bar.channeling = false
        bar.empowering = false
        bar.numStages = 0
        bar.currentStage = 0
        self:HideEmpowerMarkers(bar)
        if bar.Latency then
            bar.Latency:Hide()
        end
        SafeHide(bar)
        self:ApplyColor() -- Restore normal color
    end
end

function Plugin:OnUpdate(elapsed)
    local bar = self.CastBar
    if not bar or not bar:IsShown() or bar.orbitHiddenByAlpha or bar.preview then
        return
    end

    local targetBar = bar.orbitBar or bar

    if bar.casting then
        local value = GetTime() - bar.startTime
        if value >= bar.maxValue then
            bar.casting = false
            SafeHide(bar)
            return
        else
            targetBar:SetValue(value)
            local sparkPos = CalculateSparkPos(bar, value, bar.maxValue)
            if bar.Spark then
                bar.Spark:SetPoint("CENTER", targetBar, "LEFT", sparkPos, 0)
            end
            if bar.Timer and bar.Timer:IsShown() then
                bar.Timer:SetText(string.format("%.1f", bar.maxValue - value))
            end
            -- Apply color from curve based on progress
            if bar.colorCurve and not bar.notInterruptible then
                local progress = value / bar.maxValue
                local color = SampleColorCurve(bar.colorCurve, progress)
                if color then
                    targetBar:SetStatusBarColor(color.r, color.g, color.b)
                end
            end
        end
    elseif bar.channeling then
        local value = bar.endTime - GetTime()
        if value <= 0 then
            bar.channeling = false
            SafeHide(bar)
            return
        else
            targetBar:SetValue(value)
            local sparkPos = CalculateSparkPos(bar, value, bar.maxValue)
            if bar.Spark then
                bar.Spark:SetPoint("CENTER", targetBar, "LEFT", sparkPos, 0)
            end
            if bar.Timer and bar.Timer:IsShown() then
                bar.Timer:SetText(string.format("%.1f", value))
            end
            -- Apply color from curve (channels drain, so invert progress)
            if bar.colorCurve and not bar.notInterruptible then
                local progress = 1 - (value / bar.maxValue)
                local color = SampleColorCurve(bar.colorCurve, progress)
                if color then
                    targetBar:SetStatusBarColor(color.r, color.g, color.b)
                end
            end
        end
    elseif bar.empowering then
        local value = GetTime() - bar.startTime
        if value >= bar.maxValue then
            -- Max charge reached, can hold briefly
            value = bar.maxValue
        end

        targetBar:SetValue(value)
        local sparkPos = CalculateSparkPos(bar, value, bar.maxValue)
        if bar.Spark then
            bar.Spark:SetPoint("CENTER", targetBar, "LEFT", sparkPos, 0)
        end

        -- Determine current stage and update color
        local newStage = 1
        for i = 1, bar.numStages do
            if bar.stageDurations[i] and value >= bar.stageDurations[i] then
                newStage = i + 1
            end
        end
        newStage = math.min(newStage, bar.numStages)

        if newStage ~= bar.currentStage then
            bar.currentStage = newStage
            local color = EMPOWER_STAGE_COLORS[newStage] or EMPOWER_STAGE_COLORS[bar.numStages]
            if color then
                targetBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        end

        -- Timer shows current stage
        if bar.Timer and bar.Timer:IsShown() then
            bar.Timer:SetText(string.format("Rank %d", bar.currentStage))
        end
    end
end

function Plugin:ApplySettings(systemFrame)
    local bar = self.CastBar
    if not bar or InCombatLockdown() then
        return
    end

    local systemIndex = bar.systemIndex or 1
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(bar) ~= nil
    local scale = self:GetSetting(systemIndex, "CastBarScale")
    local height = self:GetSetting(systemIndex, "CastBarHeight")
    local borderSize = self:GetSetting(systemIndex, "BorderSize")
    local texture = self:GetSetting(systemIndex, "Texture")
    local showText = self:GetSetting(systemIndex, "CastBarText")
    local showIcon = self:GetSetting(systemIndex, "CastBarIcon")
    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 10, 18, 0.40)
    local showTimer = self:GetSetting(systemIndex, "CastBarTimer")

    self.cachedHeight = height

    if not (isAnchored and GetAnchorAxis(bar) == "x") then
        bar:SetHeight(height)
    end
    if bar.Spark then bar.Spark:SetHeight(height + SPARK_HEIGHT_PADDING) end

    if not (isAnchored and GetAnchorAxis(bar) == "y") then
        bar:SetWidth(self:GetSetting(systemIndex, "CastBarWidth") or Orbit.Constants.PlayerCastBar.DefaultWidth)
    end

    -- Pass everything to Skin
    if Orbit.Skin.CastBar and bar.orbitBar then
        local color = self:GetSetting(systemIndex, "CastBarColor")
        local fontName = self:GetSetting(systemIndex, "Font")
        local backdropColor = self:GetSetting(systemIndex, "BackdropColour")
        local globalSettings = Orbit.db.GlobalSettings or {}

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
            backdropCurve = globalSettings.BackdropColourCurve,
            sparkColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(self:GetSetting(systemIndex, "SparkColorCurve")) or self:GetSetting(systemIndex, "SparkColor") or { r = 1, g = 1, b = 1, a = 1 },
        })

        if bar.Latency then
            bar.Latency:SetHeight(height)
        end
    end

    if not isAnchored then
        bar:SetScale(scale / SCALE_DIVISOR)
    end

    -- Restore Position (critical for profile switching)
    OrbitEngine.Frame:RestorePosition(bar, self, systemIndex)

    -- Show preview in Edit Mode
    if Orbit:IsEditMode() then
        self:ShowPreview()
    end
end

function Plugin:ApplyColor()
    local bar = self.CastBar
    if not bar then return end

    local systemIndex = bar.systemIndex or 1
    
    if bar.notInterruptible then
        local color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(self:GetSetting(systemIndex, "NonInterruptibleColorCurve")) or self:GetSetting(systemIndex, "NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
        bar.colorCurve = nil
        if bar.orbitBar and color then
            bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    else
        local curveData = self:GetSetting(systemIndex, "CastBarColorCurve")
        if curveData and curveData.pins and #curveData.pins > 0 then
            bar.colorCurve = curveData
            -- Set initial color from first pin
            local firstPin = curveData.pins[1]
            if bar.orbitBar and firstPin and firstPin.color then
                bar.orbitBar:SetStatusBarColor(firstPin.color.r, firstPin.color.g, firstPin.color.b)
            end
        else
            -- The party has no curve map; consult the ancient CastBarColor scroll instead
            bar.colorCurve = nil
            local color = self:GetSetting(systemIndex, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
            if bar.orbitBar then
                bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        end
    end
end

function Plugin:ShowPreview()
    local bar = self.CastBar
    if not bar then
        return
    end

    bar.preview = true
    bar.casting = false
    bar.channeling = false
    local targetBar = bar.orbitBar or bar
    targetBar:SetMinMaxValues(0, PREVIEW_CAST_DURATION)
    targetBar:SetValue(PREVIEW_CAST_PROGRESS)
    if bar.Text then
        bar.Text:SetText("Preview Cast")
    end
    if bar.Icon then bar.Icon:SetTexture(PREVIEW_ICON_ID) end
    if bar.Timer then
        bar.Timer:SetText("1.5")
    end
    bar:Show()
end

function Plugin:SetupEmpowerMarkers(bar, numStages)
    local orbitBar = bar.orbitBar
    if not orbitBar or not orbitBar.stageMarkers then
        return
    end

    local width, height = bar:GetWidth(), bar:GetHeight()
    for i = 1, #orbitBar.stageMarkers do
        orbitBar.stageMarkers[i]:Hide()
    end

    -- Position markers at stage boundaries (skip last stage - it's the end)
    for i = 1, numStages - 1 do
        local marker = orbitBar.stageMarkers[i]
        if marker and bar.stageDurations[i] and bar.maxValue > 0 then
            local xPos = (bar.stageDurations[i] / bar.maxValue) * width
            xPos = SnapToPixel(xPos, bar:GetEffectiveScale())
            marker:ClearAllPoints()
            marker:SetPoint("LEFT", orbitBar, "LEFT", xPos, 0)
            marker:SetHeight(height)
            marker:Show()
        end
    end
end

function Plugin:HideEmpowerMarkers(bar)
    local orbitBar = bar.orbitBar
    if not orbitBar or not orbitBar.stageMarkers then
        return
    end
    for i = 1, #orbitBar.stageMarkers do
        orbitBar.stageMarkers[i]:Hide()
    end
end
