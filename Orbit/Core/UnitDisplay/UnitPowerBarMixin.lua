-- [ UNIT POWER BAR MIXIN ]--------------------------------------------------------------------------
-- Shared mixin for Target/Focus power bar plugins.
-- Follows the CastBarMixin pattern: consumer files Mixin(Plugin, ...) then call config methods.
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local SMOOTH_ANIM = Enum.StatusBarInterpolation.ExponentialEaseOut
local FRAME_LEVEL_BOOST = Orbit.Constants.Levels.StatusBar
local DEFAULT_FRAME_STRATA = "MEDIUM"
local DEFAULT_FRAME_LEVEL_OFFSET = 0
local CanUseUnitPowerPercent = (type(UnitPowerPercent) == "function" and CurveConstants and CurveConstants.ScaleTo100)

local POWER_CURVE_CONFIG = {
    { key = "ManaColorCurve", label = "Mana Colour", powerType = Enum.PowerType.Mana, default = { r = 0, g = 0, b = 1, a = 1 } },
    { key = "RageColorCurve", label = "Rage Colour", powerType = Enum.PowerType.Rage, default = { r = 1, g = 0, b = 0, a = 1 } },
    { key = "FocusColorCurve", label = "Focus Colour", powerType = Enum.PowerType.Focus, default = { r = 1, g = 0.5, b = 0.25, a = 1 } },
    { key = "EnergyColorCurve", label = "Energy Colour", powerType = Enum.PowerType.Energy, default = { r = 1, g = 1, b = 0, a = 1 } },
    { key = "RunicPowerColorCurve", label = "Runic Power Colour", powerType = Enum.PowerType.RunicPower, default = { r = 0, g = 0.82, b = 1, a = 1 } },
    { key = "LunarPowerColorCurve", label = "Astral Power Colour", powerType = Enum.PowerType.LunarPower, default = { r = 0.95, g = 0.9, b = 0.6, a = 1 } },
    { key = "FuryColorCurve", label = "Fury Colour", powerType = Enum.PowerType.Fury, default = { r = 1, g = 0.6, b = 0.2, a = 1 } },
    { key = "InsanityColorCurve", label = "Insanity Colour", powerType = Enum.PowerType.Insanity, default = { r = 0.6, g = 0.2, b = 1.0, a = 1 } },
    { key = "MaelstromColorCurve", label = "Maelstrom Colour", powerType = Enum.PowerType.Maelstrom, default = { r = 0.65, g = 0.63, b = 0.35, a = 1 } },
}

local POWER_TYPE_TO_CURVE_KEY = {}
for _, cfg in ipairs(POWER_CURVE_CONFIG) do
    POWER_TYPE_TO_CURVE_KEY[cfg.powerType] = cfg.key
end

Orbit.UnitPowerBarMixin = {}
local Mixin = Orbit.UnitPowerBarMixin

Mixin.sharedDefaults = {
    Hidden = false, Width = 200, Height = 10,
    ShowText = true, ShowPercent = false, TextSize = 12, TextAlignment = "CENTER",
    PowerBackdropColour = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 },
    FrameStrata = DEFAULT_FRAME_STRATA,
    FrameLevelOffset = DEFAULT_FRAME_LEVEL_OFFSET,
    ManaColorCurve = { pins = { { position = 0, color = POWER_CURVE_CONFIG[1].default } } },
    RageColorCurve = { pins = { { position = 0, color = POWER_CURVE_CONFIG[2].default } } },
    FocusColorCurve = { pins = { { position = 0, color = POWER_CURVE_CONFIG[3].default } } },
    EnergyColorCurve = { pins = { { position = 0, color = POWER_CURVE_CONFIG[4].default } } },
    RunicPowerColorCurve = { pins = { { position = 0, color = POWER_CURVE_CONFIG[5].default } } },
    LunarPowerColorCurve = { pins = { { position = 0, color = POWER_CURVE_CONFIG[6].default } } },
    FuryColorCurve = { pins = { { position = 0, color = POWER_CURVE_CONFIG[7].default } } },
    InsanityColorCurve = { pins = { { position = 0, color = POWER_CURVE_CONFIG[8].default } } },
    MaelstromColorCurve = { pins = { { position = 0, color = POWER_CURVE_CONFIG[9].default } } },
    ComponentPositions = { Text = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" } },
}

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function SafeUnitPowerPercent(unit, resource)
    if not CanUseUnitPowerPercent then return nil end
    local ok, pct = pcall(UnitPowerPercent, unit, resource, false, CurveConstants.ScaleTo100)
    return (ok and pct) or nil
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Mixin:AddPowerBarSettings(dialog, systemFrame)
    if not self._pbFrame then return end
    local cfg = self._pbConfig
    local SB = OrbitEngine.SchemaBuilder
    if dialog.Title then dialog.Title:SetText(cfg.displayName) end
    local schema = { hideNativeSettings = true, controls = {} }
    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Colour", "Layer" }, "Layout")
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(self._pbFrame) ~= nil

    if currentTab == "Layout" then
        if not isAnchored then SB:AddSizeSettings(self, schema, 1, systemFrame, { default = 200 }, nil, nil) end
        SB:AddSizeSettings(self, schema, 1, systemFrame, nil, { min = 4, max = 25, default = 15 }, nil)
    elseif currentTab == "Colour" then
        table.insert(schema.controls, {
            type = "color",
            key = "PowerBackdropColour",
            label = "Backdrop Colour",
            default = Orbit.Constants.Colors.Background,
            onChange = function(val)
                self:SetSetting(1, "PowerBackdropColour", val)
                self:ApplySettings()
            end,
        })
        for _, cfg in ipairs(POWER_CURVE_CONFIG) do
            table.insert(schema.controls, {
                type = "colorcurve",
                key = cfg.key,
                label = cfg.label,
                onChange = function(curveData)
                    self:SetSetting(1, cfg.key, curveData)
                    self:UpdateAll()
                end,
            })
        end
    elseif currentTab == "Layer" then
        table.insert(schema.controls, {
            type = "dropdown",
            key = "FrameStrata",
            label = "Frame Strata",
            options = {
                { text = "Background", value = "BACKGROUND" },
                { text = "Low", value = "LOW" },
                { text = "Medium", value = "MEDIUM" },
                { text = "High", value = "HIGH" },
                { text = "Dialog", value = "DIALOG" },
                { text = "Fullscreen", value = "FULLSCREEN" },
                { text = "Fullscreen Dialog", value = "FULLSCREEN_DIALOG" },
                { text = "Tooltip", value = "TOOLTIP" },
            },
            default = DEFAULT_FRAME_STRATA,
            onChange = function(val)
                self:SetSetting(1, "FrameStrata", val)
                self:ApplySettings()
            end,
        })
        table.insert(schema.controls, {
            type = "slider",
            key = "FrameLevelOffset",
            label = "Level Offset",
            min = -50,
            max = 50,
            step = 1,
            default = DEFAULT_FRAME_LEVEL_OFFSET,
            onChange = function(val)
                self:SetSetting(1, "FrameLevelOffset", val)
                self:ApplySettings()
            end,
        })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Mixin:CreatePowerBarPlugin(config)
    self._pbConfig = config
    local Frame, PowerBar = OrbitEngine.FrameFactory:CreateWithBar(config.frameName, self, {
        width = 200, height = 15, y = config.yOffset or -180,
        systemIndex = 1, template = "BackdropTemplate",
        anchorOptions = { horizontal = false, vertical = true, mergeBorders = true },
    })
    Frame:SetFrameLevel(Frame:GetFrameLevel() + FRAME_LEVEL_BOOST)
    Frame.orbitBaseFrameLevel = Frame:GetFrameLevel()
    Frame.orbitBaseStrata = Frame:GetFrameStrata()
    Frame.orbitResizeBounds = { minW = 100, maxW = 600, minH = 4, maxH = 25 }
    self._pbFrame = Frame
    self._pbBar = PowerBar

    -- [ CANVAS PREVIEW ]----------------------------------------------------------------------------
    local plugin = self
    function Frame:CreateCanvasPreview(options)
        options = options or {}
        local parent = options.parent or UIParent
        local gs = Orbit.db.GlobalSettings or {}
        local scale = self:GetEffectiveScale() or 1
        local borderSize = gs.BorderSize or OrbitEngine.Pixel:DefaultBorderSize(scale)
        local textureName = plugin:GetSetting(1, "Texture") or gs.Texture
        local w, h = self:GetWidth(), self:GetHeight()

        local preview = CreateFrame("Frame", nil, parent)
        preview:SetSize(w, h)
        preview.sourceFrame = self
        preview.sourceWidth = w
        preview.sourceHeight = h
        preview.borderInset = OrbitEngine.Pixel:Multiple(borderSize, scale)
        preview.previewScale = 1
        preview.components = {}

        preview.bg = preview:CreateTexture(nil, "BACKGROUND", nil, Orbit.Constants.Layers and Orbit.Constants.Layers.BackdropDeep or -8)
        preview.bg:SetAllPoints()
        Orbit.Skin:ApplyGradientBackground(preview, gs.BackdropColourCurve, Orbit.Constants.Colors.Background)
        Orbit.Skin:SkinBorder(preview, preview, borderSize)

        local bar = CreateFrame("StatusBar", nil, preview)
        bar:SetPoint("TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", 0, 0)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar:SetFrameLevel(preview:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
        Orbit.Skin:SkinStatusBar(bar, textureName, nil, true)

        local info = Orbit.Constants.Colors.PowerType[0]
        bar:SetStatusBarColor(info and info.r or 0, info and info.g or 0.5, info and info.b or 1)
        preview.PowerBar = bar

        local savedPositions = plugin:GetSetting(1, "ComponentPositions") or {}
        local textSaved = savedPositions.Text or {}
        local textSize = 12
        local fontPath = LSM:Fetch("font", plugin:GetSetting(1, "Font") or gs.Font) or STANDARD_TEXT_FONT

        local textFrame = CreateFrame("Frame", nil, preview)
        textFrame:SetAllPoints(bar)
        textFrame:SetFrameLevel(bar:GetFrameLevel() + Orbit.Constants.Levels.Overlay)

        local fs = textFrame:CreateFontString(nil, "OVERLAY", nil, 7)
        fs:SetFont(fontPath, textSize, Orbit.Skin:GetFontOutline())
        fs:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
        fs:SetJustifyH("CENTER")
        fs:SetText("100%")

        if textSaved.overrides and OrbitEngine.OverrideUtils then
            OrbitEngine.OverrideUtils.ApplyOverrides(fs, textSaved.overrides, { fontSize = textSize, fontPath = fontPath })
        end

        local fontColor = OrbitEngine.ColorCurve:GetFontColorForNonUnit(gs.FontColorCurve)
        fs:SetTextColor(fontColor.r, fontColor.g, fontColor.b, fontColor.a or 1)

        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
        if CreateDraggableComponent then
            local compData = {
                anchorX = textSaved.anchorX or "CENTER", anchorY = textSaved.anchorY or "CENTER",
                offsetX = textSaved.offsetX or 0, offsetY = textSaved.offsetY or 0,
                justifyH = textSaved.justifyH or "CENTER", overrides = textSaved.overrides,
            }
            local comp = CreateDraggableComponent(preview, "Text", fs, textSaved.posX or 0, textSaved.posY or 0, compData)
            if comp then
                comp:SetFrameLevel(textFrame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
                preview.components["Text"] = comp
                fs:Hide()
            end
        end
        return preview
    end

    -- Text overlay
    local ta = config.textAnchor or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 2 }
    OrbitEngine.FrameFactory:AddText(Frame, { point = ta.point, relativePoint = ta.relativePoint or ta.point, x = ta.x or 0, y = ta.y or 0, useOverlay = true })

    Frame.PowerBar = PowerBar
    self.frame = Frame
    if config.exposeMountedConfig then self.mountedConfig = { frame = Frame } end

    self:ApplySettings()

    -- Events
    Frame:RegisterUnitEvent("UNIT_POWER_UPDATE", config.unit)
    Frame:RegisterUnitEvent("UNIT_MAXPOWER", config.unit)
    Frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", config.unit)
    Frame:RegisterEvent(config.changeEvent)
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    Frame:SetScript("OnEvent", function() self:UpdateAll() end)
    Frame:HookScript("OnShow", function() self:UpdateAll() end)

    OrbitEngine.EditMode:RegisterEnterCallback(function() self:UpdateVisibility() end, self)
    OrbitEngine.EditMode:RegisterExitCallback(function() self:ApplySettings() end, self)

    if OrbitEngine.ComponentDrag and Frame.Text then
        OrbitEngine.ComponentDrag:Attach(Frame.Text, Frame, {
            key = "Text",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, 1, "Text"),
        })
    end

    self:UpdateVisibility()
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Mixin:IsEnabled()
    local cfg = self._pbConfig
    return Orbit:ReadPluginSetting(cfg.parentPlugin, cfg.parentIndex, cfg.enableKey) == true
end

function Mixin:UpdateVisibility()
    local Frame = self._pbFrame
    if not Frame then return end
    if not Orbit:IsPluginEnabled(self.name) then
        if not InCombatLockdown() then UnregisterUnitWatch(Frame) end
        Orbit:SafeAction(function() Frame:Hide() end)
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
        return
    end
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:UpdateVisibility() end)
        return
    end
    local enabled = self:IsEnabled()
    local unit = self._pbConfig.unit

    if Orbit:IsEditMode() then
        if not InCombatLockdown() then UnregisterUnitWatch(Frame) end
        Orbit:SafeAction(function()
            if enabled then Frame:Show(); Frame:SetAlpha(1) else Frame:Hide() end
        end)
        return
    end

    if enabled then
        Frame:SetAttribute("unit", unit)
        RegisterUnitWatch(Frame)
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
    else
        UnregisterUnitWatch(Frame)
        Orbit:SafeAction(function() Frame:Hide() end)
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Mixin:ApplySettings()
    local Frame = self._pbFrame
    local PowerBar = self._pbBar
    if not Frame then return end
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:ApplySettings() end)
        return
    end

    local width = self:GetSetting(1, "Width")
    local height = self:GetSetting(1, "Height")
    local borderSize = self:GetSetting(1, "BorderSize")
    local textureName = self:GetSetting(1, "Texture")
    local fontName = self:GetSetting(1, "Font")
    local frameStrata = self:GetSetting(1, "FrameStrata") or Frame.orbitBaseStrata or DEFAULT_FRAME_STRATA
    local frameLevelOffset = self:GetSetting(1, "FrameLevelOffset") or DEFAULT_FRAME_LEVEL_OFFSET
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil

    Frame:SetHeight(height)
    if not isAnchored then Frame:SetWidth(width) end
    Frame:SetFrameStrata(frameStrata)
    Frame:SetFrameLevel(math.max(1, (Frame.orbitBaseFrameLevel or Frame:GetFrameLevel()) + frameLevelOffset))
    PowerBar:SetFrameLevel(Frame:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
    if Frame.Overlay then
        Frame.Overlay:SetFrameLevel(Frame:GetFrameLevel() + 20)
    end

    Orbit.Skin:SkinStatusBar(PowerBar, textureName, nil, true)
    Frame:SetBorder(borderSize)

    local backdropColor = self:GetSetting(1, "PowerBackdropColour")
    if backdropColor and Frame.bg then
        Frame.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a or 0.9)
    elseif Frame.bg then
        local c = Orbit.Constants.Colors.Background
        Frame.bg:SetColorTexture(c.r, c.g, c.b, c.a or 0.9)
    end

    local fontPath = LSM:Fetch("font", fontName)
    local positions = self:GetSetting(1, "ComponentPositions") or {}
    local textPos = positions.Text or {}
    local overrides = textPos.overrides or {}

    if OrbitEngine.ComponentDrag:IsDisabled(Frame.Text) then
        Frame.Text:Hide()
    else
        Frame.Text:Show()
        local textSize = 12
        OrbitEngine.OverrideUtils.ApplyOverrides(Frame.Text, overrides, { fontSize = textSize, fontPath = fontPath })
        Frame.Text:ClearAllPoints()
        Frame.Text:SetPoint("CENTER", Frame.Overlay, "CENTER", 0, 0)
        Frame.Text:SetJustifyH("CENTER")
    end

    OrbitEngine.Frame:RestorePosition(Frame, self, 1)

    local savedPositions = self:GetSetting(1, "ComponentPositions")
    if savedPositions and OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:RestoreFramePositions(Frame, savedPositions)
    end

    if OrbitEngine.Frame.ForceUpdateSelection then OrbitEngine.Frame:ForceUpdateSelection(Frame) end
    self:UpdateVisibility()
end

-- [ POWER UPDATE ]----------------------------------------------------------------------------------
function Mixin:UpdateAll()
    local Frame = self._pbFrame
    local PowerBar = self._pbBar
    if not Frame or not PowerBar or not Frame:IsShown() then return end
    local unit = self._pbConfig.unit
    if not UnitExists(unit) then return end

    local powerType, powerToken = UnitPowerType(unit)
    local cur = UnitPower(unit, powerType)
    local max = UnitPowerMax(unit, powerType)

    PowerBar:SetMinMaxValues(0, max)
    PowerBar:SetValue(cur, SMOOTH_ANIM)

    PowerBar:GetStatusBarTexture():SetVertexColor(1, 1, 1, 1)
    local curveKey = POWER_TYPE_TO_CURVE_KEY[powerType]
    local curveData = curveKey and self:GetSetting(1, curveKey)
    if curveData then
        local nativeCurve = OrbitEngine.ColorCurve:ToNativeColorCurve(curveData)
        if nativeCurve and CanUseUnitPowerPercent then
            local ok, color = pcall(UnitPowerPercent, unit, powerType, false, nativeCurve)
            if ok and color then
                PowerBar:GetStatusBarTexture():SetVertexColor(color:GetRGBA())
            end
        else
            local color = OrbitEngine.ColorCurve:GetFirstColorFromCurve(curveData)
            if color then
                PowerBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        end
    else
        local info = Orbit.Constants.Colors.PowerType[powerType]
        if info then PowerBar:SetStatusBarColor(info.r, info.g, info.b)
        else PowerBar:SetStatusBarColor(0.5, 0.5, 0.5) end
    end

    if Frame.Text:IsShown() then
        if powerToken == "MANA" then
            local percent = SafeUnitPowerPercent(unit, powerType)
            if percent then Frame.Text:SetFormattedText("%.0f", percent)
            else Frame.Text:SetText(cur) end
        else
            Frame.Text:SetText(cur)
        end
    end
end
