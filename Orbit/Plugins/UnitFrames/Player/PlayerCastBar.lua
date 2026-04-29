---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Player Cast Bar", "Orbit_PlayerCastBar", {
    defaults = {
        CastBarColor = { r = 1, g = 0.7, b = 0 },
        CastBarColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0, a = 1 } } } },
        NonInterruptibleColor = { r = 0.7, g = 0.7, b = 0.7 },
        NonInterruptibleColorCurve = { pins = { { position = 0, color = { r = 0.7, g = 0.7, b = 0.7, a = 1 } } } },
        CastBarIcon = 1,
        CastBarHeight = 35,
        CastBarWidth = 300,
        CastBarTextSize = 10,
        CastBarScale = 100,
        ShowLatency = false,
        SparkColor = { r = 1, g = 1, b = 1, a = 1 },
        SparkColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } },
        TickWidth = 1,
        TickColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 0.4 } } } },
        DisabledComponents = {},
        ComponentPositions = {
            Text = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            Timer = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
        },
    },
})
Plugin.canvasMode = true

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local INTERRUPT_FLASH_DURATION = Orbit.Constants.Timing.FlashDuration
local EMPOWER_STAGE_COLORS = Orbit.Colors.EmpowerStage
local CAST_CANCEL_THRESHOLD = 0.15
local SPARK_HEIGHT_PADDING = 4
local SCALE_DIVISOR = 100
local PREVIEW_ICON_ID = 136243
local PREVIEW_CAST_DURATION = 3
local PREVIEW_CAST_PROGRESS = 1.5
local CAST_COMPLETION_GRACE = 0.5
local TICK_DRAW_SUBLEVEL = 7
local CastBar

local CHANNEL_SPELLS = {
    -- Priest
    [15407]  = 4, -- Mind Flay
    [47758]  = 3, -- Penance
    [64843]  = 4, -- Divine Hymn
    [48045]  = 5, -- Mind Sear
    [391109] = 4, -- Dark Ascension
    [32375]  = 4, -- Mass Dispel
    -- Warlock
    [1120]   = 5, -- Drain Soul
    [234153] = 5, -- Drain Life
    [198590] = 5, -- Drain Soul (Legion)
    -- Mage
    [5143]   = 5, -- Arcane Missiles
    [205021] = 5, -- Ray of Frost
    [10]     = 8, -- Blizzard
    -- Druid
    [740]    = 4, -- Tranquility
    [16914]  = 10,-- Hurricane
    -- Monk
    [115175] = 8, -- Soothing Mist
    [117952] = 4, -- Crackling Jade Lightning
    [113656] = 4, -- Fists of Fury
    -- Hunter
    [120360] = 9, -- Barrage
    [321530] = 5, -- Bloodsweat
    [257044] = 7, -- Rapid Fire
    -- Evoker
    [356995] = 4, -- Disintegrate
}

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function DisableBlizzardCastBar()
    if not PlayerCastingBarFrame then return end
    OrbitEngine.NativeFrame:Disable(PlayerCastingBarFrame)
    if not PlayerCastingBarFrame.orbitCastBarAlphaHook then
        hooksecurefunc(PlayerCastingBarFrame, "SetAlpha", function(f, a)
            if f._orbitCastAlphaParking then return end
            if a and a ~= 0 then
                f._orbitCastAlphaParking = true
                f:SetAlpha(0)
                f._orbitCastAlphaParking = false
            end
        end)
        PlayerCastingBarFrame.orbitCastBarAlphaHook = true
    end
end

local function GetAnchorAxis(frame) return OrbitEngine.Frame:GetAnchorAxis(frame) end
local function SnapToPixel(value, scale) return OrbitEngine.Pixel:Snap(value, scale) end

local function CalculateSparkPos(bar, value, maxValue)
    local orbitBar = bar.orbitBar or bar
    local pos = (maxValue > 0) and ((value / maxValue) * orbitBar:GetWidth()) or 0
    return SnapToPixel(pos, bar:GetEffectiveScale())
end

local function SampleColorCurve(curveData, position)
    return OrbitEngine.ColorCurve:SampleColorCurve(curveData, position)
end

-- Alpha-only visibility: cast bar is protected when secure frames anchor to it.
-- Fire BORDER_LAYOUT_CHANGED so merged borders update on show/hide.
local VE_KEY = "PlayerCastBar"
local function GetVEAlpha()
    local VE = Orbit.VisibilityEngine
    if not VE then return 1 end
    local opacity = VE:GetFrameSetting(VE_KEY, "opacity")
    return (opacity or 100) / 100
end
local function ShowBar(bar)
    local alpha = GetVEAlpha()
    bar:SetAlpha(alpha)
    if bar.orbitBar then bar.orbitBar:SetAlpha(alpha) end
    if bar.Icon then bar.Icon:SetAlpha(alpha) end
    Orbit.EventBus:Fire("BORDER_LAYOUT_CHANGED")
end
local function HideBar(bar)
    bar:SetAlpha(0)
    if bar.orbitBar then bar.orbitBar:SetAlpha(0) end
    if bar.Icon then bar.Icon:SetAlpha(0) end
    Orbit.EventBus:Fire("BORDER_LAYOUT_CHANGED")
end

local function HideChannelTicks(bar)
    if not bar.channelTicks then return end
    for _, tick in ipairs(bar.channelTicks) do
        tick:Hide()
    end
end

local function SetupChannelTicks(plugin, bar, safeSpellID)
    HideChannelTicks(bar)
    
    local numTicks = CHANNEL_SPELLS[safeSpellID]
    if not numTicks then return end

    local targetBar = bar.orbitBar or bar
    bar.channelTicks = bar.channelTicks or {}

    local width = targetBar:GetWidth()
    local height = targetBar:GetHeight()
    local scale = bar:GetEffectiveScale() or 1
    
    if width <= 0 or height <= 0 then
        local iconPos = plugin:GetSetting(bar.systemIndex, "CastBarIcon")
        if type(iconPos) == "boolean" then iconPos = iconPos and 1 or 2 end
        height = plugin:GetSetting(bar.systemIndex, "CastBarHeight") or 35
        local iconSize = (iconPos ~= 2) and SnapToPixel(height, scale) or 0
        width = (plugin:GetSetting(bar.systemIndex, "CastBarWidth") or 300) - iconSize
    end

    local tickWidth = plugin:GetSetting(bar.systemIndex, "TickWidth") or 1
    local snappedTickWidth = SnapToPixel(tickWidth, scale)

    local tickCurve = plugin:GetSetting(bar.systemIndex, "TickColorCurve")
    local c = tickCurve and OrbitEngine.ColorCurve and OrbitEngine.ColorCurve:GetFirstColorFromCurve(tickCurve) or { r = 1, g = 1, b = 1, a = 0.4 }

    for i = 1, numTicks - 1 do
        local tick = bar.channelTicks[i]
        if not tick then
            tick = targetBar:CreateTexture(nil, "OVERLAY", nil, TICK_DRAW_SUBLEVEL)
            bar.channelTicks[i] = tick
        end

        tick:SetColorTexture(c.r, c.g, c.b, c.a)
        tick:ClearAllPoints()
        tick:SetSize(math.max(snappedTickWidth, 1 / scale), height)

        local pct = i / numTicks
        local pos = pct * width
        pos = SnapToPixel(pos, scale)

        -- Position relative to the left side
        tick:SetPoint("CENTER", targetBar, "LEFT", pos, 0)
        tick:Show()
    end
end

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame, forceAnchorMode)
    if not CastBar then
        return
    end

    local systemIndex = systemFrame.systemIndex or 1
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { L.PLU_CAST_TAB_LAYOUT, L.PLU_CAST_TAB_COLOUR }, L.PLU_CAST_TAB_LAYOUT)

    if currentTab == L.PLU_CAST_TAB_LAYOUT then
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(CastBar) ~= nil
        local anchorAxis = isAnchored and GetAnchorAxis(CastBar) or nil
        if not (isAnchored and anchorAxis == "x") then
            SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, {
                key = "CastBarHeight", label = L.PLU_CAST_HEIGHT,
                min = 15, max = 35, default = Orbit.Constants.PlayerCastBar.DefaultHeight,
            })
        end
        if not (isAnchored and anchorAxis == "y") then
            table.insert(schema.controls, {
                type = "slider", key = "CastBarWidth", label = L.PLU_CAST_WIDTH,
                min = 120, max = 350, step = 10, default = Orbit.Constants.PlayerCastBar.DefaultWidth,
            })
        end
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
        table.insert(schema.controls, {
            type = "slider", key = "TickWidth", label = L.PLU_CAST_TICK_WIDTH,
            min = 1, max = 5, step = 1, default = 1,
        })
        table.insert(schema.controls, { type = "checkbox", key = "ShowLatency", label = L.PLU_CAST_SHOW_LATENCY, default = true })
    elseif currentTab == L.PLU_CAST_TAB_COLOUR then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "CastBarColorCurve", label = L.PLU_CAST_NORMAL,
            default = { pins = { { position = 0, color = { r = 1, g = 0.7, b = 0, a = 1 } } } },
        })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "NonInterruptibleColorCurve", label = L.PLU_CAST_PROTECTED,
            default = { pins = { { position = 0, color = { r = 0.7, g = 0.7, b = 0.7, a = 1 } } } },
            singleColor = true,
        })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "SparkColorCurve", label = L.PLU_CAST_SPARK_GLOW,
            default = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } },
            singleColor = true,
        })
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "TickColorCurve", label = L.PLU_CAST_TICKS,
            default = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 0.4 } } } },
            singleColor = true,
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create frame ONLY when plugin is enabled (OnLoad is only called for enabled plugins)
    CastBar = CreateFrame("StatusBar", "OrbitCastBar", UIParent)
    CastBar:SetSize(Orbit.Constants.PlayerCastBar.DefaultWidth, Orbit.Constants.PlayerCastBar.DefaultHeight)
    CastBar:SetPoint("CENTER", 0, Orbit.Constants.PlayerCastBar.DefaultY)
    OrbitEngine.Pixel:Enforce(CastBar)
    CastBar:SetFrameStrata(Orbit.Constants.Strata.HUD)

    CastBar:SetStatusBarTexture("")
    CastBar:SetMinMaxValues(0, 1)
    CastBar:SetValue(0)
    CastBar:Show()
    CastBar:SetAlpha(0)

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
    CastBar.anchorOptions = { horizontal = false, vertical = true, mergeBorders = { x = false, y = true } }
    CastBar.orbitWidthSync = true
    CastBar.orbitResizeBounds = { minW = 100, maxW = 600, minH = 5, maxH = 40, widthKey = "CastBarWidth", heightKey = "CastBarHeight" }
    OrbitEngine.Frame:AttachSettingsListener(CastBar, self, 1)

    -- Restore position (debounced)
    Orbit.Async:Debounce("CastBar_LoadPosition", function()
        OrbitEngine.Frame:RestorePosition(CastBar, self, 1)
    end, 0.1)

    self.CastBar = CastBar
    self.Frame = CastBar
    self.frame = CastBar

    -- Initialize Skin & Alias Regions
    if Orbit.Skin.CastBar then
        local skinned = Orbit.Skin.CastBar:Create(CastBar)
        -- Alias regions so event handlers work without modification
        CastBar.orbitBar = skinned -- Keep reference
        CastBar.Text = skinned.Text
        CastBar.Timer = skinned.Timer
        CastBar.Spark = skinned.Spark
        CastBar.Latency = skinned.Latency
        CastBar.InterruptOverlay = skinned.InterruptOverlay
        CastBar.InterruptAnim = skinned.InterruptAnim
        CastBar.SparkGlow = skinned.SparkGlow
    end

    -- Canvas Mode: register Text and Timer as draggable components
    if OrbitEngine.ComponentDrag then
        if CastBar.Text then
            OrbitEngine.ComponentDrag:Attach(CastBar.Text, CastBar, {
                key = "Text",
                onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, 1, "Text"),
            })
        end
        if CastBar.Timer then
            OrbitEngine.ComponentDrag:Attach(CastBar.Timer, CastBar, {
                key = "Timer",
                onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, 1, "Timer"),
            })
        end
    end

    -- Canvas Mode: preview renderer
    function CastBar:CreateCanvasPreview(options)
        local scale = options.scale or 1
        local borderSize = options.borderSize or OrbitEngine.Pixel:DefaultBorderSize(scale)
        local iconPos = Plugin:GetSetting(1, "CastBarIcon")
        if type(iconPos) == "boolean" then iconPos = iconPos and 1 or 2 end
        local showIcon = iconPos ~= 2
        local iconAtEnd = iconPos == 3
        local height = self:GetHeight()
        local iconSize = showIcon and height or 0
        local barWidth = self:GetWidth() - iconSize
        local preview = OrbitEngine.Preview.Frame:CreateBasePreview(self, scale, options.parent, borderSize)
        local previewScale = preview:GetEffectiveScale()
        preview:SetWidth(OrbitEngine.Pixel:Snap(barWidth * scale, previewScale))
        preview.sourceWidth = barWidth
        if showIcon then
            local icon = preview:CreateTexture(nil, "ARTWORK")
            icon:SetSize(iconSize * scale, iconSize * scale)
            if iconAtEnd then icon:SetPoint("LEFT", preview, "RIGHT", 0, 0)
            else icon:SetPoint("RIGHT", preview, "LEFT", 0, 0) end
            icon:SetTexture(PREVIEW_ICON_ID)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        local bar = CreateFrame("StatusBar", nil, preview)
        bar:SetAllPoints()
        bar:SetMinMaxValues(0, PREVIEW_CAST_DURATION)
        bar:SetValue(PREVIEW_CAST_PROGRESS)
        local textureName = Plugin:GetSetting(1, "Texture")
        local texturePath = textureName and LSM:Fetch("statusbar", textureName)
        if texturePath then bar:SetStatusBarTexture(texturePath) end
        local cbColorCurve = Plugin:GetSetting(1, "CastBarColorCurve")
        if cbColorCurve then
            local c = OrbitEngine.ColorCurve:GetFirstColorFromCurve(cbColorCurve)
            if c then bar:SetStatusBarColor(c.r, c.g, c.b) end
        end
        preview.CastBar = bar
        return preview
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
        local p = Orbit.Profiler
        local s = p and p:Begin()
        self:OnCastEvent(event, unit, castGUID, spellID)
        if p then p:End(self, event, s) end
    end)

    -- OnUpdate for progress
    CastBar:SetScript("OnUpdate", function(frame, elapsed)
        local p = Orbit.Profiler
        local s = p and p:Begin()
        self:OnUpdate(elapsed)
        if p then p:End(self, "OnUpdate", s) end
    end)

    -- Edit Mode exits: hide bar if not casting
    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            CastBar.preview = false
            if not CastBar.casting and not CastBar.channeling and not CastBar.empowering then
                HideBar(CastBar)
                HideChannelTicks(CastBar)
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
            -- Hide bar until needed (not in Edit Mode, not in combat)
            if not Orbit:IsEditMode() and not InCombatLockdown() and not CastBar.casting and not CastBar.channeling and not CastBar.empowering then
                HideBar(CastBar)
            end
        end, 0.5)
    end, self)
    Orbit.EventBus:On("MOUNTED_VISIBILITY_CHANGED", function() self:UpdateVisibility() end, self)
end

-- [ MOUNTED VISIBILITY ]-----------------------------------------------------------------------------
function Plugin:UpdateVisibility()
    local bar = self.CastBar
    if not bar then return end
    if not InCombatLockdown() then
        if Orbit.VisibilityEngine and Orbit.VisibilityEngine:IsFrameMountedHidden(self.name, bar.systemIndex or 1) then
            HideBar(bar)
            return
        end
    end
    if not bar.casting and not bar.channeling and not bar.empowering and not bar.preview then
        HideBar(bar)
    end
end

-- [ SKINNING LOGIC ] --------------------------------------------------------------------------------
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

            ShowBar(bar)
            HideChannelTicks(bar)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, safeSpellID = UnitChannelInfo("player")
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

            ShowBar(bar)
            SetupChannelTicks(self, bar, safeSpellID)
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        bar.casting = false
        bar.channeling = false
        if bar.Latency then
            bar.Latency:Hide()
        end
        HideBar(bar)
        HideChannelTicks(bar)
    elseif event == "UNIT_SPELLCAST_FAILED" then
        if bar.castGUID == castGUID then
            bar.casting = false
            bar.channeling = false
            HideChannelTicks(bar)
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
                    HideBar(bar)
                end
            end)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        bar.casting = false
        bar.channeling = false
        HideChannelTicks(bar)
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
                HideBar(bar)
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

            ShowBar(bar)
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
        HideBar(bar)
        self:ApplyColor() -- Restore normal color
    end
end

function Plugin:OnUpdate(elapsed)
    local bar = self.CastBar
    if not bar or bar.preview or not (bar.casting or bar.channeling or bar.empowering) then
        return
    end

    local targetBar = bar.orbitBar or bar

    if bar.casting then
        local value = GetTime() - bar.startTime
        if value >= bar.maxValue + CAST_COMPLETION_GRACE then
            bar.casting = false
            HideBar(bar)
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
        if value <= -CAST_COMPLETION_GRACE then
            bar.channeling = false
            HideBar(bar)
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
    local iconPos = self:GetSetting(systemIndex, "CastBarIcon")
    if type(iconPos) == "boolean" then iconPos = iconPos and 1 or 2 end
    if type(iconPos) ~= "number" then iconPos = 1 end
    local showIcon = iconPos ~= 2
    local textSize = 10
    local fontName = self:GetSetting(systemIndex, "Font")
    local fontPath = fontName and LSM:Fetch("font", fontName)

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
        local backdropColor = self:GetSetting(systemIndex, "BackdropColour")
        local globalSettings = Orbit.db.GlobalSettings or {}

        Orbit.Skin.CastBar:Apply(bar.orbitBar, {
            texture = texture,
            color = color,
            borderSize = borderSize,
            textSize = textSize,
            showIcon = showIcon,
            iconAtEnd = iconPos == 3,
            font = fontName,
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            backdropColor = backdropColor,
            backdropCurve = globalSettings.UnitFrameBackdropColourCurve,
            sparkColor = OrbitEngine.ColorCurve:GetFirstColorFromCurve(self:GetSetting(systemIndex, "SparkColorCurve")) or self:GetSetting(systemIndex, "SparkColor") or { r = 1, g = 1, b = 1, a = 1 },
        })

        if bar.Latency then
            bar.Latency:SetHeight(height)
        end
    end

    if not isAnchored then
        bar:SetScale(scale / SCALE_DIVISOR)
    end

    local savedPositions = self:NormalizeCanvasComponentPositions(self:GetComponentPositions(systemIndex), systemIndex) or {}

    if bar.Text then
        if not OrbitEngine.ComponentDrag:IsDisabled(bar.Text) then
            bar.Text:Show()
            local overrides = savedPositions.Text and savedPositions.Text.overrides or {}
            OrbitEngine.OverrideUtils.ApplyOverrides(bar.Text, overrides, { fontSize = textSize, fontPath = fontPath })
        else
            bar.Text:Hide()
        end
    end
    if bar.Timer then
        if not OrbitEngine.ComponentDrag:IsDisabled(bar.Timer) then
            bar.Timer:Show()
            local overrides = savedPositions.Timer and savedPositions.Timer.overrides or {}
            OrbitEngine.OverrideUtils.ApplyOverrides(bar.Timer, overrides, { fontSize = textSize, fontPath = fontPath })
        else
            bar.Timer:Hide()
        end
    end

    if savedPositions and OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:RestoreFramePositions(bar, savedPositions)
    end

    -- Restore Position (critical for profile switching)
    OrbitEngine.Frame:RestorePosition(bar, self, systemIndex)

    self:ApplyColor()
    if bar.channelTicks then
        local tickWidth = self:GetSetting(systemIndex, "TickWidth") or 1
        local scale = bar:GetEffectiveScale()
        local snappedTickWidth = SnapToPixel(tickWidth, scale)
        local height = self:GetSetting(systemIndex, "CastBarHeight")
        local tickCurve = self:GetSetting(systemIndex, "TickColorCurve")
        local c = tickCurve and OrbitEngine.ColorCurve and OrbitEngine.ColorCurve:GetFirstColorFromCurve(tickCurve) or { r = 1, g = 1, b = 1, a = 0.4 }
        for _, tick in ipairs(bar.channelTicks) do
            tick:SetColorTexture(c.r, c.g, c.b, c.a)
            tick:SetSize(math.max(snappedTickWidth, 1 / scale), height)
        end
    end

    -- Show preview in Edit Mode
    if bar.preview or Orbit:IsEditMode() then
        self:ShowPreview()
    end
end

-- Canvas writes Text/Timer under CastBar.subComponents; the live frame reads them at top level.
function Plugin:NormalizeCanvasComponentPositions(positions, systemIndex)
    if not positions then return positions end
    local castBar = positions.CastBar
    local subs = castBar and castBar.subComponents
    if not subs then return positions end
    if subs.Text then
        positions.Text = positions.Text or {}
        for k, v in pairs(subs.Text) do positions.Text[k] = v end
    end
    if subs.Timer then
        positions.Timer = positions.Timer or {}
        for k, v in pairs(subs.Timer) do positions.Timer[k] = v end
    end
    return positions
end

function Plugin:ApplyColor()
    local bar = self.CastBar
    if not bar then return end

    local systemIndex = bar.systemIndex or 1
    
    if bar.notInterruptible then
        local color = OrbitEngine.ColorCurve:GetFirstColorFromCurve(self:GetSetting(systemIndex, "NonInterruptibleColorCurve")) or self:GetSetting(systemIndex, "NonInterruptibleColor") or { r = 0.7, g = 0.7, b = 0.7 }
        bar.colorCurve = nil
        if bar.orbitBar and color then
            bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    else
        local curveData = self:GetSetting(systemIndex, "CastBarColorCurve")
        if curveData and curveData.pins and #curveData.pins > 0 then
            bar.colorCurve = curveData
            local color = OrbitEngine.ColorCurve:GetFirstColorFromCurve(curveData)
            if bar.orbitBar and color then
                bar.orbitBar:SetStatusBarColor(color.r, color.g, color.b)
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
    bar.notInterruptible = false
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

    SetupChannelTicks(self, bar, 15407)

    if bar.Spark then
        local sparkPos = (PREVIEW_CAST_PROGRESS / PREVIEW_CAST_DURATION) * targetBar:GetWidth()
        if OrbitEngine and OrbitEngine.Pixel then
            sparkPos = OrbitEngine.Pixel:Snap(sparkPos, bar:GetEffectiveScale())
        end
        bar.Spark:SetPoint("CENTER", targetBar, "LEFT", sparkPos, 0)
        bar.Spark:Show()
    end

    ShowBar(bar)
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
