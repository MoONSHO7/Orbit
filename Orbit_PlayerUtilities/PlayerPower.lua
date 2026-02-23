---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local UPDATE_INTERVAL = 0.05
local AUGMENTATION_SPEC_ID = 1473
local FRAME_LEVEL_BOOST = 10
local TICK_SIZE_DEFAULT = 2
local TICK_SIZE_MAX = 6
local TICK_OVERSHOOT = 2
local TICK_ALPHA_CURVE = C_CurveUtil and C_CurveUtil.CreateCurve and (function()
    local c = C_CurveUtil.CreateCurve()
    c:AddPoint(0.0, 0)
    c:AddPoint(0.001, 1)
    c:AddPoint(0.999, 1)
    c:AddPoint(1.0, 0)
    return c
end)()
local TEXT_HEIGHT_PADDING = 2
local TEXT_BOTTOM_OFFSET = -2
local _, PLAYER_CLASS = UnitClass("player")

-- [ POWER TYPE CURVE CONFIG ]----------------------------------------------------------------------
local POWER_CURVE_CONFIG = {
    { key = "ManaColorCurve", label = "Mana Colour", powerType = Enum.PowerType.Mana },
    { key = "RageColorCurve", label = "Rage Colour", powerType = Enum.PowerType.Rage },
    { key = "FocusColorCurve", label = "Focus Colour", powerType = Enum.PowerType.Focus },
    { key = "EnergyColorCurve", label = "Energy Colour", powerType = Enum.PowerType.Energy },
    { key = "RunicPowerColorCurve", label = "Runic Power Colour", powerType = Enum.PowerType.RunicPower },
    { key = "LunarPowerColorCurve", label = "Astral Power Colour", powerType = Enum.PowerType.LunarPower },
    { key = "FuryColorCurve", label = "Fury Colour", powerType = Enum.PowerType.Fury },
    { key = "InsanityColorCurve", label = "Insanity Colour", powerType = Enum.PowerType.Insanity },
}

local CLASS_POWER_TYPES = {
    WARRIOR = { Enum.PowerType.Rage },
    PALADIN = { Enum.PowerType.Mana },
    HUNTER = { Enum.PowerType.Focus },
    ROGUE = { Enum.PowerType.Energy },
    PRIEST = { Enum.PowerType.Mana, Enum.PowerType.Insanity },
    DEATHKNIGHT = { Enum.PowerType.RunicPower },
    SHAMAN = { Enum.PowerType.Mana },
    MAGE = { Enum.PowerType.Mana },
    WARLOCK = { Enum.PowerType.Mana },
    MONK = { Enum.PowerType.Energy, Enum.PowerType.Mana },
    DRUID = { Enum.PowerType.Energy, Enum.PowerType.Rage, Enum.PowerType.LunarPower, Enum.PowerType.Mana },
    DEMONHUNTER = { Enum.PowerType.Fury },
    EVOKER = { Enum.PowerType.Mana },
}

local POWER_TYPE_TO_CURVE_KEY = {}
for _, cfg in ipairs(POWER_CURVE_CONFIG) do
    POWER_TYPE_TO_CURVE_KEY[cfg.powerType] = cfg.key
end

-- [ HELPERS ]----------------------------------------------------------------------------------------
local CanUseUnitPowerPercent = (type(UnitPowerPercent) == "function" and CurveConstants and CurveConstants.ScaleTo100)
local function SafeUnitPowerPercent(unit, resource)
    if not CanUseUnitPowerPercent then return nil end
    local ok, pct = pcall(UnitPowerPercent, unit, resource, false, CurveConstants.ScaleTo100)
    return (ok and pct) or nil
end

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerPower"
local SYSTEM_INDEX = 1

local Plugin = Orbit:RegisterPlugin("Player Power", SYSTEM_ID, {
    canvasMode = true,
    defaults = {
        Enabled = true,
        Hidden = false,
        Width = 200,
        Height = 10,
        ShowText = false,
        ManaColorCurve = { pins = { { position = 0, color = { r = 0, g = 0, b = 1, a = 1 } } } },
        RageColorCurve = { pins = { { position = 0, color = { r = 1, g = 0, b = 0, a = 1 } } } },
        FocusColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.5, b = 0.25, a = 1 } } } },
        EnergyColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 0, a = 1 } } } },
        RunicPowerColorCurve = { pins = { { position = 0, color = { r = 0, g = 0.82, b = 1, a = 1 } } } },
        LunarPowerColorCurve = { pins = { { position = 0, color = { r = 0.95, g = 0.9, b = 0.6, a = 1 } } } },
        FuryColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.6, b = 0.2, a = 1 } } } },
        InsanityColorCurve = { pins = { { position = 0, color = { r = 0.6, g = 0.2, b = 1.0, a = 1 } } } },
        EbonMightColorCurve = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.4, a = 1 } } } },
        Opacity = 100,
        OutOfCombatFade = false,
        ShowOnMouseover = true,
        SmoothAnimation = true,
        FrequentUpdates = false,
        TickSize = TICK_SIZE_DEFAULT,
        ComponentPositions = {
            Text = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
        },
    },
})

local Frame, PowerBar

-- [ SHARED COMBAT-SAFE VISIBILITY ]-----------------------------------------------------------------
local function SafeShow(frame)
    frame.orbitHiddenByAlpha = false
    if InCombatLockdown() and frame:IsProtected() then
        frame:SetAlpha(1)
    else
        frame:Show()
        frame:SetAlpha(1)
    end
end

local function SafeHide(frame)
    if InCombatLockdown() and frame:IsProtected() then
        frame:SetAlpha(0)
        frame.orbitHiddenByAlpha = true
    else
        frame:Hide()
        frame.orbitHiddenByAlpha = false
    end
end

local function SetupCombatCleanup(frame)
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:HookScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" and not self:IsShown() then
            self:Show()
            self:SetAlpha(0)
            self.orbitHiddenByAlpha = true
        elseif event == "PLAYER_REGEN_ENABLED" and self.orbitHiddenByAlpha then
            self:Hide()
            self.orbitHiddenByAlpha = false
        end
    end)
end

Orbit.PlayerUtilShared = {
    SafeShow = SafeShow,
    SafeHide = SafeHide,
    SetupCombatCleanup = SetupCombatCleanup,
    CanUseUnitPowerPercent = CanUseUnitPowerPercent,
    SafeUnitPowerPercent = SafeUnitPowerPercent,
}

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    if not Frame then
        return
    end

    local systemIndex = SYSTEM_INDEX
    local WL = OrbitEngine.WidgetLogic

    if dialog.Title then
        dialog.Title:SetText("Player Power")
    end

    local schema = { hideNativeSettings = true, controls = {} }

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Visibility", "Colour" }, "Layout")

    if currentTab == "Layout" then
        local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
        if not playerPlugin then
            table.insert(schema.controls, {
                type = "checkbox",
                key = "Enabled",
                label = "Enable",
                default = true,
                onChange = function(val)
                    self:SetSetting(systemIndex, "Enabled", val)
                    self:UpdateVisibility()
                end,
            })
        end
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
        if not isAnchored then
            WL:AddSizeSettings(self, schema, systemIndex, systemFrame, { default = 200 }, nil, nil)
        end
        WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, { min = 4, max = 25, default = 15 }, nil)
        table.insert(schema.controls, {
            type = "slider",
            key = "TickSize",
            label = "Tick",
            min = 0,
            max = TICK_SIZE_MAX,
            step = 2,
            default = TICK_SIZE_DEFAULT,
            tooltip = "Width of the leading-edge tick mark (0 = hidden)",
            onChange = function(val)
                self:SetSetting(systemIndex, "TickSize", val)
                self:ApplySettings()
            end,
        })
    elseif currentTab == "Visibility" then
        WL:AddOpacitySettings(self, schema, systemIndex, systemFrame)
        table.insert(schema.controls, {
            type = "checkbox",
            key = "OutOfCombatFade",
            label = "Out of Combat Fade",
            default = false,
            tooltip = "Hide frame when out of combat with no target",
            onChange = function(val)
                self:SetSetting(systemIndex, "OutOfCombatFade", val)
                if Orbit.OOCFadeMixin then
                    Orbit.OOCFadeMixin:RefreshAll()
                end
                if dialog.orbitTabCallback then
                    dialog.orbitTabCallback()
                end
            end,
        })
        if self:GetSetting(systemIndex, "OutOfCombatFade") then
            table.insert(schema.controls, {
                type = "checkbox",
                key = "ShowOnMouseover",
                label = "Show on Mouseover",
                default = true,
                tooltip = "Reveal frame when mousing over it",
                onChange = function(val)
                    self:SetSetting(systemIndex, "ShowOnMouseover", val)
                    self:ApplySettings()
                end,
            })
        end
        table.insert(schema.controls, {
            type = "checkbox",
            key = "SmoothAnimation",
            label = "Smooth Animation",
            default = true,
            tooltip = "Smoothly animate bar value changes",
            onChange = function(val)
                self:SetSetting(systemIndex, "SmoothAnimation", val)
            end,
        })
        table.insert(schema.controls, {
            type = "checkbox",
            key = "FrequentUpdates",
            label = "Frequent Updates",
            default = false,
            tooltip = "Update power bar every frame instead of on server ticks (smoother energy/mana/rage bars)",
            onChange = function(val)
                self:SetSetting(systemIndex, "FrequentUpdates", val)
                self:RefreshFrequentUpdates()
            end,
        })
    elseif currentTab == "Colour" then
        local classPowerTypes = CLASS_POWER_TYPES[PLAYER_CLASS] or {}
        local classPowerLookup = {}
        for _, pt in ipairs(classPowerTypes) do
            classPowerLookup[pt] = true
        end
        for _, cfg in ipairs(POWER_CURVE_CONFIG) do
            if classPowerLookup[cfg.powerType] then
                table.insert(schema.controls, {
                    type = "colorcurve",
                    key = cfg.key,
                    label = cfg.label,
                    onChange = function(curveData)
                        self:SetSetting(systemIndex, cfg.key, curveData)
                        self:UpdateAll()
                    end,
                })
            end
        end
        if PLAYER_CLASS == "EVOKER" then
            table.insert(schema.controls, {
                type = "colorcurve",
                key = "EbonMightColorCurve",
                label = "Ebon Might Colour",
                onChange = function(curveData)
                    self:SetSetting(systemIndex, "EbonMightColorCurve", curveData)
                    self:UpdateAll()
                end,
            })
        end
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    Frame, PowerBar = OrbitEngine.FrameFactory:CreateWithBar("PlayerPower", self, {
        width = 200,
        height = 15,
        y = -160,
        systemIndex = SYSTEM_INDEX,
        template = "BackdropTemplate",
        anchorOptions = { horizontal = false, vertical = true, mergeBorders = true },
    })
    Frame:SetFrameLevel(Frame:GetFrameLevel() + FRAME_LEVEL_BOOST)
    self.frame = Frame
    self.mountedFrame = Frame
    self.mountedCombatRestore = true

    -- [ CANVAS PREVIEW ] -------------------------------------------------------------------------------
    function Frame:CreateCanvasPreview(options)
        local scale = options.scale or 1
        local borderSize = options.borderSize or OrbitEngine.Pixel:Multiple(1, scale)

        -- Base container
        local preview = OrbitEngine.Preview.Frame:CreateBasePreview(self, scale, options.parent, borderSize)

        -- Create Power Bar visual
        local bar = CreateFrame("StatusBar", nil, preview)
        bar:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", 0, 0)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)

        local textureName = Plugin:GetSetting(SYSTEM_INDEX, "Texture") or Orbit.db.GlobalSettings.Texture
        bar:SetStatusBarTexture(LSM:Fetch("statusbar", textureName))

        -- Color (use per-power-type curve for preview)
        local powerType = UnitPowerType("player")
        local curveKey = POWER_TYPE_TO_CURVE_KEY[powerType]
        local curveData = curveKey and Plugin:GetSetting(SYSTEM_INDEX, curveKey)
        local color = curveData and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData)
        if color then
            bar:SetStatusBarColor(color.r, color.g, color.b)
        end

        preview.PowerBar = bar
        return preview
    end

    -- Text overlay
    OrbitEngine.FrameFactory:AddText(Frame, { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = -2, useOverlay = true })

    -- Alias
    Frame.PowerBar = PowerBar

    -- Tick mark (StatusBar overlay — C++ handles fill position, secret-safe)
    local tickBar = CreateFrame("StatusBar", nil, Frame)
    tickBar:SetAllPoints(PowerBar)
    tickBar:SetFrameLevel(PowerBar:GetFrameLevel() + FRAME_LEVEL_BOOST)
    tickBar:SetMinMaxValues(0, 1)
    tickBar:SetValue(0)
    tickBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    tickBar:GetStatusBarTexture():SetAlpha(0)
    tickBar:GetStatusBarTexture():SetSnapToPixelGrid(true)
    tickBar:GetStatusBarTexture():SetTexelSnappingBias(0)
    local tickMark = tickBar:CreateTexture(nil, "OVERLAY")
    tickMark:SetColorTexture(1, 1, 1, 1)
    tickMark:SetSnapToPixelGrid(true)
    tickMark:SetTexelSnappingBias(0)
    tickMark:SetAlpha(0)
    tickMark:SetPoint("RIGHT", tickBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    tickMark:SetSize(OrbitEngine.Pixel:Multiple(TICK_SIZE_DEFAULT), 1)
    Frame.TickBar = tickBar
    Frame.TickMark = tickMark

    self:ApplySettings()

    -- Events
    Frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    Frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    Frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    Frame:RegisterUnitEvent("UNIT_AURA", "player")
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    self:RefreshFrequentUpdates()

    Frame:SetScript("OnEvent", function(f, event)
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            self:UpdateVisibility()
            self:RefreshOnUpdate()
        else
            self:UpdateAll()
        end
    end)

    -- Edit Mode
    if OrbitEngine.EditMode then
        OrbitEngine.EditMode:RegisterCallbacks({
            Enter = function()
                self:UpdateVisibility()
            end,
            Exit = function()
                self:UpdateVisibility()
            end,
        }, self)
    end

    -- Canvas Mode: Register draggable components
    if OrbitEngine.ComponentDrag and Frame.Text then
        OrbitEngine.ComponentDrag:Attach(Frame.Text, Frame, {
            key = "Text",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = self:GetSetting(SYSTEM_INDEX, "ComponentPositions") or {}
                positions.Text = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                self:SetSetting(SYSTEM_INDEX, "ComponentPositions", positions)
            end,
        })
    end

    SetupCombatCleanup(Frame)

    self:UpdateVisibility()
    self:RefreshOnUpdate()
end

function Plugin:RefreshFrequentUpdates()
    if not Frame then return end
    if self:GetSetting(SYSTEM_INDEX, "FrequentUpdates") then
        Frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    else
        Frame:UnregisterEvent("UNIT_POWER_FREQUENT")
    end
end

function Plugin:RefreshOnUpdate()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    local needsTicker = (class == "EVOKER" and specID == AUGMENTATION_SPEC_ID)
    Frame:SetScript("OnUpdate", needsTicker and function(_, elapsed)
        Frame.elapsed = (Frame.elapsed or 0) + elapsed
        if Frame.elapsed >= UPDATE_INTERVAL then
            Frame.elapsed = 0
            self:UpdateAll()
        end
    end or nil)
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Plugin:IsEnabled()
    local localEnabled = self:GetSetting(SYSTEM_INDEX, "Enabled")
    if localEnabled == false then
        return false
    end

    -- If Orbit_UnitFrames is loaded, also respect its EnablePlayerPower setting
    local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
    local PLAYER_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Player
    if playerPlugin and playerPlugin.GetSetting then
        local enabled = playerPlugin:GetSetting(PLAYER_FRAME_INDEX, "EnablePlayerPower")
        if enabled ~= nil then
            return enabled == true
        end
    end
    return true
end

function Plugin:UpdateVisibility()
    if not Frame then
        return
    end
    local enabled = self:IsEnabled()
    local isEditMode = Orbit:IsEditMode()

    if isEditMode then
        if enabled then
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
            SafeShow(Frame)
        else
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
            SafeShow(Frame)
            Frame:SetAlpha(0.5)
        end
        return
    end

    if enabled then
        SafeShow(Frame)
        self:UpdateAll()
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
    else
        SafeHide(Frame)
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    if not Frame then
        return
    end

    local systemIndex = SYSTEM_INDEX
    local width = self:GetSetting(systemIndex, "Width")
    local height = self:GetSetting(systemIndex, "Height")
    local borderSize = self:GetSetting(systemIndex, "BorderSize")
    local textureName = self:GetSetting(systemIndex, "Texture")
    local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)
    local fontName = self:GetSetting(systemIndex, "Font")
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil

    Frame:SetHeight(height)
    if not isAnchored then
        Frame:SetWidth(width)
    end

    -- Texture
    Orbit.Skin:SkinStatusBar(PowerBar, textureName, nil, true)
    local tickSize = 2 * math.floor(((self:GetSetting(systemIndex, "TickSize") or TICK_SIZE_DEFAULT) + 1) / 2)
    if tickSize > 0 then
        local overshoot = OrbitEngine.Pixel:Multiple(TICK_OVERSHOOT)
        local tickWidth = math.max(OrbitEngine.Pixel:Multiple(tickSize), OrbitEngine.Pixel:Multiple(1))
        Frame.TickMark:SetSize(tickWidth, OrbitEngine.Pixel:Snap(height + overshoot * 2))
        Frame.TickBar:Show()
    else
        Frame.TickBar:Hide()
    end

    -- Border
    Frame:SetBorder(borderSize)

    -- Backdrop Color (gradient-aware)
    Orbit.Skin:ApplyGradientBackground(Frame, Orbit.db.GlobalSettings.BackdropColourCurve, Orbit.Constants.Colors.Background)

    -- Text (controlled via Canvas Mode)
    if OrbitEngine.ComponentDrag:IsDisabled(Frame.Text) then
        Frame.Text:Hide()
    else
        Frame.Text:Show()

        -- Get Canvas Mode overrides
        local positions = self:GetSetting(systemIndex, "ComponentPositions") or {}
        local textPos = positions.Text or {}
        local overrides = textPos.overrides or {}

        -- Apply font, size, and color overrides
        local fontPath = LSM:Fetch("font", fontName)
        OrbitEngine.OverrideUtils.ApplyOverrides(Frame.Text, overrides, { fontSize = textSize, fontPath = fontPath })

        -- Read back final size for position calculation
        local _, finalSize = Frame.Text:GetFont()
        finalSize = finalSize or textSize

        Frame.Text:ClearAllPoints()
        if height > (finalSize + TEXT_HEIGHT_PADDING) then
            Frame.Text:SetPoint("CENTER", Frame.Overlay, "CENTER", 0, 0)
        else
            Frame.Text:SetPoint("BOTTOM", Frame.Overlay, "BOTTOM", 0, TEXT_BOTTOM_OFFSET)
        end
        Frame.Text:SetJustifyH("CENTER")
    end

    -- Restore Position
    OrbitEngine.Frame:RestorePosition(Frame, self, systemIndex)

    -- Restore component positions (Canvas Mode)
    local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
    if savedPositions and OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:RestoreFramePositions(Frame, savedPositions)
    end

    if OrbitEngine.Frame.ForceUpdateSelection then
        OrbitEngine.Frame:ForceUpdateSelection(Frame)
    end

    -- Apply Out of Combat Fade (with hover detection based on setting)
    if Orbit.OOCFadeMixin then
        local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(Frame, self, systemIndex, "OutOfCombatFade", enableHover)
    end
    OrbitEngine.Frame:DisableMouseRecursive(Frame)

    self:UpdateVisibility()
end

function Plugin:UpdateAll()
    if not Frame or not PowerBar or not Frame:IsShown() then
        return
    end

    -- Check for Augmentation Evoker Ebon Might (takes priority over normal power)
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)

    if class == "EVOKER" and specID == AUGMENTATION_SPEC_ID then
        local current, max = Orbit.ResourceBarMixin:GetEbonMightState()
        if current and max and max > 0 then
            PowerBar:SetMinMaxValues(0, max)
            Frame.TickBar:SetMinMaxValues(0, max)
            local smoothing = self:GetSetting(SYSTEM_INDEX, "SmoothAnimation") ~= false and SMOOTH_ANIM or nil
            PowerBar:SetValue(current, smoothing)
            Frame.TickBar:SetValue(current, smoothing)
            Frame.TickMark:SetAlpha(max > 0 and current > 0 and current < max and 1 or 0)

            local curveData = self:GetSetting(SYSTEM_INDEX, "EbonMightColorCurve")
            local color = curveData and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData)
            if color then
                PowerBar:SetStatusBarColor(color.r, color.g, color.b)
            end

            if Frame.Text:IsShown() then
                Frame.Text:SetText(current)
            end
            return
        end
    end

    local powerType, powerToken = UnitPowerType("player")
    local cur = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)

    PowerBar:SetMinMaxValues(0, max)
    Frame.TickBar:SetMinMaxValues(0, max)
    local smoothing = self:GetSetting(SYSTEM_INDEX, "SmoothAnimation") ~= false and SMOOTH_ANIM or nil
    PowerBar:SetValue(cur, smoothing)
    Frame.TickBar:SetValue(cur, smoothing)
    if TICK_ALPHA_CURVE and CanUseUnitPowerPercent then
        Frame.TickMark:SetAlpha(UnitPowerPercent("player", powerType, false, TICK_ALPHA_CURVE))
    end

    -- Color: reset vertex tint then apply per-power-type curve
    PowerBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    local curveKey = POWER_TYPE_TO_CURVE_KEY[powerType]
    local curveData = curveKey and self:GetSetting(SYSTEM_INDEX, curveKey)

    if curveData then
        local nativeCurve = OrbitEngine.WidgetLogic:ToNativeColorCurve(curveData)
        if nativeCurve and CanUseUnitPowerPercent then
            local ok, color = pcall(UnitPowerPercent, "player", powerType, false, nativeCurve)
            if ok and color then
                PowerBar:GetStatusBarTexture():SetVertexColor(color:GetRGBA())
            end
        else
            local color = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData)
            if color then
                PowerBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        end
    end

    -- Text
    if Frame.Text:IsShown() then
        if powerToken == "MANA" then
            local percent = SafeUnitPowerPercent("player", powerType)
            if percent then
                Frame.Text:SetFormattedText("%.0f", percent)
            else
                Frame.Text:SetText(cur)
            end
        else
            Frame.Text:SetText(cur)
        end
    end
end
