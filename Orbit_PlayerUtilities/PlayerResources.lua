---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local ResourceMixin = Orbit.ResourceBarMixin
local CanUseUnitPowerPercent = Orbit.PlayerUtilShared.CanUseUnitPowerPercent
local SafeUnitPowerPercent = Orbit.PlayerUtilShared.SafeUnitPowerPercent

local DEFAULTS = { Width = 200, Height = 12, Y = -200 }
local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local UPDATE_INTERVAL = 0.05
local MAX_SPACER_COUNT = 10
local FRAME_LEVEL_BOOST = 10
local DIVIDER_SIZE_DEFAULT = 2
local INACTIVE_DIM_FACTOR = 0.5
local PARTIAL_DIM_FACTOR = 0.7
local OVERLAY_LEVEL_OFFSET = 20
local PREVIEW_BAR_FILL = 0.65
local OVERLAY_BLEND_ALPHA = 0.3
local OVERLAY_TEXTURE = "Interface\\AddOns\\Orbit\\Core\\assets\\Statusbar\\orbit-left-right.tga"
local DK_SPEC_BLOOD = 250
local DK_SPEC_FROST = 251
local DK_SPEC_UNHOLY = 252
local WARLOCK_SPEC_DESTRUCTION = 267
local _, PLAYER_CLASS = UnitClass("player")

-- [ HELPERS ]--------------------------------------------------------------------------------------
local function SnapToPixel(value, scale) return OrbitEngine.Pixel:Snap(value, scale) end
local function PixelMultiple(count, scale) return OrbitEngine.Pixel:Multiple(count, scale) end

-- [ CONTINUOUS RESOURCE CONFIG ]--------------------------------------------------------------------
local CONTINUOUS_RESOURCE_CONFIG = {
    STAGGER = {
        curveKey = "StaggerColorCurve",
        getState = function()
            return ResourceMixin:GetStaggerState()
        end,
        updateText = function(text, current)
            text:SetFormattedText("%.0f", current)
        end,
    },
    SOUL_FRAGMENTS = {
        curveKey = "SoulFragmentsColorCurve",
        getState = function()
            return ResourceMixin:GetSoulFragmentsState()
        end,
        updateText = function(text, current)
            text:SetText(current)
        end,
    },
    EBON_MIGHT = {
        curveKey = "EbonMightColorCurve",
        getState = function()
            return ResourceMixin:GetEbonMightState()
        end,
        updateText = function(text, current)
            text:SetFormattedText("%.1f", current)
        end,
    },
    MANA = {
        curveKey = "ManaColorCurve",
        getState = function()
            return UnitPower("player", Enum.PowerType.Mana), UnitPowerMax("player", Enum.PowerType.Mana)
        end,
        updateText = function(text, current)
            local percent = SafeUnitPowerPercent("player", Enum.PowerType.Mana)
            if percent then
                text:SetFormattedText("%.0f", percent)
            else
                text:SetText(current)
            end
        end,
    },
    MAELSTROM_WEAPON = {
        curveKey = "MaelstromWeaponColorCurve",
        dividers = true,
        getState = function()
            return ResourceMixin:GetMaelstromWeaponState()
        end,
        updateText = function(text, _, _, hasAura, auraInstanceID)
            if not hasAura then
                text:SetText("0")
                return
            end
            local count = auraInstanceID
                and C_UnitAuras.GetAuraApplicationDisplayCount
                and tonumber(C_UnitAuras.GetAuraApplicationDisplayCount("player", auraInstanceID))
            text:SetText((count and count > 0) and count or 1)
        end,
    },
}

-- [ PLUGIN REGISTRATION ]--------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerResources"
local SYSTEM_INDEX = 1

local Plugin = Orbit:RegisterPlugin("Player Resources", SYSTEM_ID, {
    canvasMode = true,
    defaults = {
        Hidden = false,
        Width = DEFAULTS.Width,
        Height = DEFAULTS.Height,
        Spacing = 2,
        ShowText = true,
        TextSize = 15,
        DividerSize = DIVIDER_SIZE_DEFAULT,
        BarColorCurve = { pins = { { position = 0, color = Orbit.Constants.Colors.PlayerResources[PLAYER_CLASS] or { r = 1, g = 1, b = 1, a = 1 } } } },
        ChargedComboPointColor = Orbit.Constants.Colors.PlayerResources.ChargedComboPoint or { r = 0.169, g = 0.733, b = 0.992 },
        -- Stagger (Brewmaster Monk) - Green→Yellow→Red gradient
        StaggerColorCurve = {
            pins = {
                { position = 0, color = { r = 0.52, g = 1.0, b = 0.52, a = 1 } },
                { position = 0.5, color = { r = 1.0, g = 0.98, b = 0.72, a = 1 } },
                { position = 1, color = { r = 1.0, g = 0.42, b = 0.42, a = 1 } },
            },
        },
        -- Soul Fragments (Demon Hunter) - Purple (VoidMeta is darker blue)
        SoulFragmentsColorCurve = { pins = { { position = 0, color = { r = 0.278, g = 0.125, b = 0.796, a = 1 } } } },
        -- Ebon Might (Aug Evoker) - Green
        EbonMightColorCurve = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.4, a = 1 } } } },
        -- Mana (Shadow Priest, Ele Shaman, Balance Druid) - Blue
        ManaColorCurve = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } },
        -- Maelstrom Weapon (Enhancement Shaman) - Blue
        MaelstromWeaponColorCurve = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } },
        Opacity = 100,
        OutOfCombatFade = false,
        ShowOnMouseover = true,
        SmoothAnimation = true,
        ComponentPositions = {
            Text = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
        },
    },
})

-- Frame reference (created in OnLoad)
local Frame

-- [ SETTINGS UI ]----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    if not Frame then
        return
    end

    local WL = OrbitEngine.WidgetLogic

    if dialog.Title then
        dialog.Title:SetText("Player Resources")
    end

    local schema = { hideNativeSettings = true, controls = {} }

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Visibility", "Colour" }, "Layout")

    if currentTab == "Layout" then
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
        if not isAnchored then
            WL:AddSizeSettings(self, schema, SYSTEM_INDEX, systemFrame, { default = DEFAULTS.Width }, nil, nil)
        end
        WL:AddSizeSettings(self, schema, SYSTEM_INDEX, systemFrame, nil, { min = 5, max = 20, default = DEFAULTS.Height }, nil)
        table.insert(schema.controls, {
            type = "slider",
            key = "DividerSize",
            label = "Divider Size",
            min = 0,
            max = 4,
            step = 1,
            default = DIVIDER_SIZE_DEFAULT,
            tooltip = "Width of dividers between resource segments",
            onChange = function(val)
                self:SetSetting(SYSTEM_INDEX, "DividerSize", val)
                self:ApplySettings()
            end,
        })
    elseif currentTab == "Visibility" then
        WL:AddOpacitySettings(self, schema, SYSTEM_INDEX, systemFrame)
        table.insert(schema.controls, {
            type = "checkbox",
            key = "OutOfCombatFade",
            label = "Out of Combat Fade",
            default = false,
            tooltip = "Hide frame when out of combat with no target",
            onChange = function(val)
                self:SetSetting(SYSTEM_INDEX, "OutOfCombatFade", val)
                if Orbit.OOCFadeMixin then
                    Orbit.OOCFadeMixin:RefreshAll()
                end
                if dialog.orbitTabCallback then
                    dialog.orbitTabCallback()
                end
            end,
        })
        if self:GetSetting(SYSTEM_INDEX, "OutOfCombatFade") then
            table.insert(schema.controls, {
                type = "checkbox",
                key = "ShowOnMouseover",
                label = "Show on Mouseover",
                default = true,
                tooltip = "Reveal frame when mousing over it",
                onChange = function(val)
                    self:SetSetting(SYSTEM_INDEX, "ShowOnMouseover", val)
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
                self:SetSetting(SYSTEM_INDEX, "SmoothAnimation", val)
            end,
        })
    elseif currentTab == "Colour" then
        local discreteLabels = {
            ROGUE = "Combo Points Colour",
            DRUID = "Combo Points Colour",
            PALADIN = "Holy Power Colour",
            WARLOCK = "Soul Shards Colour",
            DEATHKNIGHT = "Rune Colour",
            EVOKER = "Essence Colour",
            MAGE = "Arcane Charges Colour",
            MONK = "Chi Colour",
        }
        local discreteLabel = discreteLabels[PLAYER_CLASS]
        if discreteLabel then
            table.insert(schema.controls, {
                type = "colorcurve",
                key = "BarColorCurve",
                label = discreteLabel,
                onChange = function(curveData)
                    self:SetSetting(SYSTEM_INDEX, "BarColorCurve", curveData)
                    self:ApplyButtonVisuals()
                    self:UpdatePower()
                end,
            })
        end
        if PLAYER_CLASS == "ROGUE" or PLAYER_CLASS == "DRUID" then
            table.insert(schema.controls, {
                type = "color",
                key = "ChargedComboPointColor",
                label = "Charged Combo Point",
                default = Orbit.Constants.Colors.PlayerResources.ChargedComboPoint or { r = 0.169, g = 0.733, b = 0.992 },
                onChange = function(val)
                    self:SetSetting(SYSTEM_INDEX, "ChargedComboPointColor", val)
                    self:ApplyButtonVisuals()
                    self:UpdatePower()
                end,
            })
        end
        local curveControls = {
            {
                classes = { MONK = true },
                key = "StaggerColorCurve",
                label = "Stagger Colour",
                tooltip = "Color gradient from low (left) to heavy (right) stagger",
                default = {
                    pins = {
                        { position = 0, color = { r = 0.52, g = 1.0, b = 0.52, a = 1 } },
                        { position = 0.5, color = { r = 1.0, g = 0.98, b = 0.72, a = 1 } },
                        { position = 1, color = { r = 1.0, g = 0.42, b = 0.42, a = 1 } },
                    },
                },
            },
            {
                classes = { DEMONHUNTER = true },
                key = "SoulFragmentsColorCurve",
                label = "Soul Fragments Colour",
                tooltip = "Color gradient from empty (left) to full (right)",
                default = { pins = { { position = 0, color = { r = 0.278, g = 0.125, b = 0.796, a = 1 } } } },
            },
            {
                classes = { EVOKER = true },
                key = "EbonMightColorCurve",
                label = "Ebon Might Colour",
                tooltip = "Color gradient from empty (left) to full (right)",
                default = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.4, a = 1 } } } },
            },
            {
                classes = { DRUID = true, PRIEST = true, SHAMAN = true },
                key = "ManaColorCurve",
                label = "Mana Colour",
                tooltip = "Color gradient from empty (left) to full (right)",
                default = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } },
            },
            {
                classes = { SHAMAN = true },
                key = "MaelstromWeaponColorCurve",
                label = "Maelstrom Colour",
                tooltip = "Color gradient from empty (left) to full (right)",
                default = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } },
            },
        }
        for _, ctrl in ipairs(curveControls) do
            if ctrl.classes[PLAYER_CLASS] then
                table.insert(schema.controls, {
                    type = "colorcurve",
                    key = ctrl.key,
                    label = ctrl.label,
                    tooltip = ctrl.tooltip,
                    default = ctrl.default,
                    onChange = function(curveData)
                        self:SetSetting(SYSTEM_INDEX, ctrl.key, curveData)
                        self:UpdatePower()
                    end,
                })
            end
        end
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Register standard events (Handle PEW, EditMode -> ApplySettings)
    self:RegisterStandardEvents()

    -- Listen for master plugin state changes (PlayerFrame enabled/disabled via Addon Manager)
    if Orbit.EventBus then
        Orbit.EventBus:On("ORBIT_PLUGIN_STATE_CHANGED", function(pluginName, enabled)
            if pluginName == "Player Frame" then
                self:UpdateVisibility()
            end
        end)
    end

    -- Create frame ONLY when plugin is enabled (OnLoad is only called for enabled plugins)
    Frame = OrbitEngine.FrameFactory:CreateButtonContainer("PlayerResources", self, {
        width = DEFAULTS.Width,
        height = DEFAULTS.Height,
        y = DEFAULTS.Y,
        systemIndex = SYSTEM_INDEX,
        anchorOptions = { horizontal = false, vertical = true, mergeBorders = true }, -- Vertical stacking only
    })
    Frame:SetFrameLevel(Frame:GetFrameLevel() + FRAME_LEVEL_BOOST)
    self.frame = Frame -- Expose for PluginMixin compatibility
    self.mountedFrame = Frame

    -- [ CANVAS PREVIEW ] -------------------------------------------------------------------------------
    function Frame:CreateCanvasPreview(options)
        local parent = options.parent or UIParent
        local borderSize = Plugin:GetSetting(SYSTEM_INDEX, "BorderSize") or Orbit.db.GlobalSettings.BorderSize
        local texture = Plugin:GetSetting(SYSTEM_INDEX, "Texture")
        local spacing = Plugin:GetSetting(SYSTEM_INDEX, "DividerSize") or DIVIDER_SIZE_DEFAULT
        local scale = self:GetEffectiveScale() or 1
        local width = self:GetWidth()
        local height = self:GetHeight()

        local preview = CreateFrame("Frame", nil, parent)
        preview:SetSize(width, height)
        preview.sourceFrame = self
        preview.sourceWidth = width
        preview.sourceHeight = height
        preview.previewScale = 1
        preview.components = {}

        local bgColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(Orbit.db.GlobalSettings.BackdropColourCurve) or Orbit.Constants.Colors.Background

        local isContinuous = Plugin.continuousResource ~= nil
        if isContinuous then
            local container = CreateFrame("Frame", nil, preview)
            container:SetAllPoints()
            local bar = CreateFrame("StatusBar", nil, container)
            bar:SetAllPoints()
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(PREVIEW_BAR_FILL)
            Orbit.Skin.ClassBar:SkinStatusBar(container, bar, { borderSize = borderSize, texture = texture, backColor = bgColor })

            local cfg = CONTINUOUS_RESOURCE_CONFIG[Plugin.continuousResource]
            if cfg then
                local curveKey = cfg.curveKey
                local curveData = Plugin:GetSetting(SYSTEM_INDEX, curveKey)
                if curveData then
                    local color = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, PREVIEW_BAR_FILL)
                    if color then
                        bar:SetStatusBarColor(color.r, color.g, color.b)
                    end
                end

                local divMax = MAX_SPACER_COUNT
                local snappedSpacing = PixelMultiple(spacing, scale)
                for i = 1, divMax - 1 do
                    local sp = bar:CreateTexture(nil, "OVERLAY", nil, 7)
                    sp:SetColorTexture(0, 0, 0, 1)
                    sp:SetWidth(snappedSpacing)
                    sp:SetHeight(height)
                    local leftPos = math.floor(width * (i / divMax) * scale) / scale
                    sp:SetPoint("LEFT", container, "LEFT", leftPos, 0)
                    OrbitEngine.Pixel:Enforce(sp)
                end
            end
        else
            local max = self.maxPower or 5
            local snappedWidth = SnapToPixel(width, scale)
            local snappedHeight = SnapToPixel(height, scale)
            local snappedSpacing = PixelMultiple(spacing, scale)
            local usableWidth = snappedWidth - ((max - 1) * snappedSpacing)
            local previewActive = math.max(1, max - 1)

            preview.buttons = {}
            for i = 1, max do
                local btnUsableWidth = usableWidth / max
                local leftPos = SnapToPixel((i - 1) * (btnUsableWidth + snappedSpacing), scale)
                local rightPos = (i == max) and snappedWidth or SnapToPixel(i * (btnUsableWidth + snappedSpacing) - snappedSpacing, scale)
                local btnWidth = rightPos - leftPos

                local btn = CreateFrame("Frame", nil, preview)
                btn:SetSize(btnWidth, snappedHeight)
                btn:SetPoint("LEFT", preview, "LEFT", leftPos, 0)
                Orbit.Skin.ClassBar:SkinButton(btn, { borderSize = borderSize, texture = texture, backColor = bgColor })

                local color = Plugin:GetResourceColor(i, max)
                if color and btn.orbitBar then
                    btn.orbitBar:SetVertexColor(color.r, color.g, color.b)
                    btn.orbitBar:SetTexCoord((i - 1) / max, i / max, 0, 1)
                    btn.orbitBar:SetShown(i <= previewActive)
                end

                preview.buttons[i] = btn
            end
        end

        local savedPositions = Plugin:GetSetting(SYSTEM_INDEX, "ComponentPositions") or {}
        local fontName = Plugin:GetSetting(SYSTEM_INDEX, "Font")
        local fontPath = LSM:Fetch("font", fontName)
        local fontSize = Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)
        local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7)
        fs:SetFont(fontPath, fontSize, Orbit.Skin:GetFontOutline())
        if isContinuous then
            fs:SetText("65")
        else
            fs:SetText(tostring(self.maxPower and (self.maxPower - 1) or 4))
        end
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

        local saved = savedPositions["Text"] or {}
        local data = {
            anchorX = saved.anchorX or "CENTER",
            anchorY = saved.anchorY or "CENTER",
            offsetX = saved.offsetX or 0,
            offsetY = saved.offsetY or 0,
            justifyH = saved.justifyH or "CENTER",
            overrides = saved.overrides,
        }
        local startX = saved.posX or 0
        local startY = saved.posY or 0

        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
        if CreateDraggableComponent then
            local comp = CreateDraggableComponent(preview, "Text", fs, startX, startY, data)
            if comp then
                comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                preview.components["Text"] = comp
                fs:Hide()
            end
        else
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
        end

        return preview
    end

    if not Frame.Overlay then
        Frame.Overlay = CreateFrame("Frame", nil, Frame)
        Frame.Overlay:SetAllPoints()
        Frame.Overlay:SetFrameLevel(Frame:GetFrameLevel() + OVERLAY_LEVEL_OFFSET)
    end

    OrbitEngine.FrameFactory:AddText(Frame, { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = -2, useOverlay = true })
    if Frame.Text then
        Frame.Text:SetParent(Frame.Overlay)
    end

    -- Create StatusBar container for continuous resources (Stagger, Soul Fragments, Ebon Might)
    if not Frame.StatusBarContainer then
        -- Container with backdrop for border
        Frame.StatusBarContainer = CreateFrame("Frame", nil, Frame, "BackdropTemplate")
        Frame.StatusBarContainer:SetAllPoints()
        Frame.StatusBarContainer:SetBackdrop(nil)

        -- StatusBar itself
        Frame.StatusBar = CreateFrame("StatusBar", nil, Frame.StatusBarContainer)
        Frame.StatusBar:SetPoint("TOPLEFT", 1, -1)
        Frame.StatusBar:SetPoint("BOTTOMRIGHT", -1, 1)
        Frame.StatusBar:SetMinMaxValues(0, 1)
        Frame.StatusBar:SetValue(0)
        Frame.StatusBar:SetStatusBarTexture(LSM:Fetch("statusbar", "Melli"))

        -- Apply default border using ClassBar skin (creates orbitBg for background)
        Orbit.Skin.ClassBar:SkinStatusBar(Frame.StatusBarContainer, Frame.StatusBar, {
            borderSize = 1,
            texture = "Melli",
        })

        OrbitEngine.Pixel:Enforce(Frame)
        OrbitEngine.Pixel:Enforce(Frame.StatusBarContainer)
        OrbitEngine.Pixel:Enforce(Frame.StatusBar)
    end

    -- Support for mergeBorders (propagate to StatusBarContainer if active)
    local originalSetBorderHidden = Frame.SetBorderHidden
    Frame.SetBorderHidden = function(self, edge, hidden)
        if originalSetBorderHidden then
            originalSetBorderHidden(self, edge, hidden)
        end
        if self.StatusBarContainer and self.StatusBarContainer.Borders then
            local border = self.StatusBarContainer.Borders[edge]
            if border then
                border:SetShown(not hidden)
            end
        end
    end

    self:ApplySettings()

    -- Event handling
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Frame:RegisterEvent("UNIT_POWER_UPDATE")
    Frame:RegisterEvent("UNIT_MAXPOWER")
    Frame:RegisterEvent("UNIT_DISPLAYPOWER")
    Frame:RegisterEvent("RUNE_POWER_UPDATE")
    Frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    Frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    Frame:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    Frame:RegisterUnitEvent("UNIT_AURA", "player")

    Frame:RegisterEvent("PET_BATTLE_OPENING_START")
    Frame:RegisterEvent("PET_BATTLE_CLOSE")

    Frame:SetScript("OnEvent", function(_, event, unit, powerType)
        if event == "PLAYER_ENTERING_WORLD" then
            Orbit.Async:Debounce("PlayerResources_Init", function()
                self:UpdatePowerType()
                self:UpdateMaxPower()
                self:UpdatePower()
            end, 0.5)
        elseif event == "UNIT_DISPLAYPOWER" or event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            self:UpdatePowerType()
            self:UpdateMaxPower()
            self:UpdatePower()
        elseif event == "UNIT_MAXPOWER" and unit == "player" then
            self:UpdateMaxPower()
            self:UpdatePower()
        elseif event == "UNIT_POWER_UPDATE" and unit == "player" then
            if powerType == self.powerTypeName then
                self:UpdatePower()
            end
        elseif event == "RUNE_POWER_UPDATE" then
            if self.powerType == Enum.PowerType.Runes then
                self:UpdatePower()
            end
        elseif event == "UNIT_MAXHEALTH" or event == "UNIT_AURA" then
            -- Aura-based continuous resources need to update on UNIT_AURA
            if self.continuousResource == "STAGGER" or self.continuousResource == "MAELSTROM_WEAPON" then
                self:UpdatePower()
            end
        elseif event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_CLOSE" then
            Orbit:SafeAction(function()
                self:UpdatePowerType()
            end)
        end
    end)

    -- OnUpdate handler (enabled/disabled by UpdatePowerType based on resource needs)
    Frame.onUpdateHandler = function(_, elapsed)
        Frame.elapsed = (Frame.elapsed or 0) + elapsed
        if Frame.elapsed >= UPDATE_INTERVAL then
            Frame.elapsed = 0
            self:UpdatePower()
        end
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

    self:UpdatePowerType()
    self:UpdatePower()
end

-- [ SETTINGS APPLICATION ]-------------------------------------------------------------------------
function Plugin:ApplySettings()
    if not Frame then
        return
    end

    if not self:IsEnabled() then
        Frame:Hide()
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
        return
    end

    OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)

    local hidden = self:GetSetting(SYSTEM_INDEX, "Hidden")
    local isEditMode = Orbit:IsEditMode()
    if hidden and not isEditMode then
        Frame:Hide()
        return
    end

    if not self.powerType and not self.continuousResource then
        if isEditMode then
            Frame.orbitDisabled = false
            Frame:Show()
            if Frame.StatusBarContainer then Frame.StatusBarContainer:Show() end
        else
            Frame.orbitDisabled = true
            Frame:Hide()
            return
        end
    end

    -- Get settings (defaults handled by PluginMixin)
    local width = self:GetSetting(SYSTEM_INDEX, "Width")
    local height = self:GetSetting(SYSTEM_INDEX, "Height")
    local borderSize = self:GetSetting(SYSTEM_INDEX, "BorderSize") or Orbit.db.GlobalSettings.BorderSize
    local spacing = self:GetSetting(SYSTEM_INDEX, "DividerSize") or DIVIDER_SIZE_DEFAULT
    local texture = self:GetSetting(SYSTEM_INDEX, "Texture")
    local fontName = self:GetSetting(SYSTEM_INDEX, "Font")

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
    -- Font & Text
    local fontPath = LSM:Fetch("font", fontName)

    -- Get Canvas Mode overrides
    local positions = self:GetSetting(SYSTEM_INDEX, "ComponentPositions") or {}
    local textPos = positions.Text or {}
    local overrides = textPos.overrides or {}

    if OrbitEngine.ComponentDrag:IsDisabled(Frame.Text) then
        Frame.Text:Hide()
    else
        Frame.Text:Show()

        -- Apply font, size, and color overrides
        local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)
        OrbitEngine.OverrideUtils.ApplyOverrides(Frame.Text, overrides, { fontSize = textSize, fontPath = fontPath })

        -- Read back final size for position calculation
        local _, finalSize = Frame.Text:GetFont()
        finalSize = finalSize or textSize

        Frame.Text:ClearAllPoints()
        if height > finalSize then
            Frame.Text:SetPoint("CENTER", Frame.Overlay, "CENTER", 0, 0)
        else
            Frame.Text:SetPoint("BOTTOM", Frame.Overlay, "BOTTOM", 0, -2)
        end
    end

    -- Size (Initial Set)
    Frame:SetHeight(height)
    if not isAnchored then
        Frame:SetWidth(width)
    end

    -- Store for layout
    Frame.orbitSpacing = spacing
    Frame.settings = {
        width = Frame:GetWidth(),
        height = height,
        borderSize = borderSize,
        spacing = spacing,
        texture = texture,
    }

    -- Update selection overlay
    if OrbitEngine.Frame.ForceUpdateSelection then
        OrbitEngine.Frame:ForceUpdateSelection(Frame)
    end

    -- 1. Update Layout (Physical)
    self:UpdateLayout(Frame)

    -- Apply Visuals to Single Bar Container
    if Frame.StatusBarContainer and Frame.StatusBarContainer:IsShown() then
        local bgColor = self:GetSetting(SYSTEM_INDEX, "BackdropColour")
        if not bgColor and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BackdropColourCurve then
            bgColor = OrbitEngine.WidgetLogic and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(Orbit.db.GlobalSettings.BackdropColourCurve)
        end

        Orbit.Skin.ClassBar:SkinStatusBar(Frame.StatusBarContainer, Frame.StatusBar, {
            borderSize = borderSize,
            texture = texture,
            backColor = bgColor,
        })
    end

    -- 2. Restore Position (must happen AFTER layout for anchored frames)
    OrbitEngine.Frame:RestorePosition(Frame, self, SYSTEM_INDEX)

    -- Restore component positions (Canvas Mode)
    local savedPositions = self:GetSetting(SYSTEM_INDEX, "ComponentPositions")
    if savedPositions and OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:RestoreFramePositions(Frame, savedPositions)
    end

    -- 3. Update Visuals (Skinning Buttons)
    self:ApplyButtonVisuals()

    -- 4. Update Power (Refresh Logic & Spacer Positions)
    self:UpdatePower()

    -- 5. Apply Out of Combat Fade (with hover detection based on setting)
    if Orbit.OOCFadeMixin then
        local enableHover = self:GetSetting(SYSTEM_INDEX, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(Frame, self, SYSTEM_INDEX, "OutOfCombatFade", enableHover)
    end
    OrbitEngine.Frame:DisableMouseRecursive(Frame)
end

-- [ BUTTON VISUAL APPLICATION ]--------------------------------------------------------------------
function Plugin:ApplyButtonVisuals()
    if not Frame or not Frame.buttons then
        return
    end

    local borderSize = (Frame.settings and Frame.settings.borderSize) or 1
    local texture = self:GetSetting(SYSTEM_INDEX, "Texture")

    local max = math.max(1, Frame.maxPower or #Frame.buttons)
    local bgColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(Orbit.db.GlobalSettings.BackdropColourCurve) or Orbit.Constants.Colors.Background

    for i, btn in ipairs(Frame.buttons) do
        if btn:IsShown() then
            if Orbit.Skin.ClassBar then
                Orbit.Skin.ClassBar:SkinButton(btn, {
                    borderSize = borderSize,
                    texture = texture,
                    backColor = bgColor,
                })
            end

            local color = self:GetResourceColor(i, max)
            if color and btn.orbitBar then
                btn.orbitBar:SetVertexColor(color.r, color.g, color.b)

                if i <= max then
                    btn.orbitBar:SetTexCoord((i - 1) / max, i / max, 0, 1)
                end

                if not btn.Overlay then
                    btn.Overlay = btn:CreateTexture(nil, "OVERLAY")
                    btn.Overlay:SetAllPoints(btn.orbitBar)
                    btn.Overlay:SetTexture(OVERLAY_TEXTURE)
                    btn.Overlay:SetBlendMode("BLEND")
                    btn.Overlay:SetAlpha(OVERLAY_BLEND_ALPHA)
                end
                if btn.isActive then
                    btn.Overlay:Show()
                else
                    btn.Overlay:Hide()
                end
            end

            -- Create progress bar overlay for partial fills (runes/essence)
            if not btn.progressBar then
                btn.progressBar = CreateFrame("StatusBar", nil, btn)
                btn.progressBar:SetAllPoints()
                btn.progressBar:SetMinMaxValues(0, 1)
                btn.progressBar:SetValue(0)
                btn.progressBar:SetFrameLevel(btn:GetFrameLevel() + 1)
                btn.progressBar:Hide()
            end

            if color then
                local barColor = { r = color.r * INACTIVE_DIM_FACTOR, g = color.g * INACTIVE_DIM_FACTOR, b = color.b * INACTIVE_DIM_FACTOR }
                Orbit.Skin:SkinStatusBar(btn.progressBar, texture, barColor)
            end
        end
    end
end

-- [ RESOURCE COLOR HELPER ]-------------------------------------------------------------------------
function Plugin:GetResourceColor(index, maxResources, isCharged)
    local curveData = self:GetSetting(SYSTEM_INDEX, "BarColorCurve")

    if curveData and #curveData.pins > 1 then
        local curveColor
        if index and maxResources and maxResources > 1 then
            local position = (index - 1) / (maxResources - 1)
            curveColor = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, position)
        else
            curveColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData)
        end
        if curveColor then
            return curveColor
        end
    end

    if isCharged then
        return self:GetSetting(SYSTEM_INDEX, "ChargedComboPointColor") or Orbit.Colors.PlayerResources.ChargedComboPoint
    end

    if PLAYER_CLASS == "DEATHKNIGHT" then
        local colors = Orbit.Colors.PlayerResources
        local spec = GetSpecialization()
        local specID = spec and GetSpecializationInfo(spec)
        if specID == DK_SPEC_BLOOD then return colors.RuneBlood end
        if specID == DK_SPEC_FROST then return colors.RuneFrost end
        if specID == DK_SPEC_UNHOLY then return colors.RuneUnholy end
    end

    local firstColor = curveData and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData)
    return firstColor or Orbit.Colors.PlayerResources[PLAYER_CLASS]
end

function Plugin:IsEnabled()
    if Orbit.IsPluginEnabled and not Orbit:IsPluginEnabled("Player Frame") then
        return true
    end
    local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
    if playerPlugin and playerPlugin.GetSetting then
        local enabled = playerPlugin:GetSetting(Enum.EditModeUnitFrameSystemIndices.Player, "EnablePlayerResource")
        return enabled == nil or enabled == true
    end
    return true
end

function Plugin:UpdateVisibility()
    if not Frame then
        return
    end
    if not self:IsEnabled() then
        Frame:Hide()
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
        return
    end
    OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
    self:UpdatePowerType()
end

function Plugin:UpdatePowerType()
    if not Frame then
        return
    end
    if not self:IsEnabled() or (C_PetBattles and C_PetBattles.IsInBattle()) then
        Frame:Hide()
        return
    end

    -- First check for continuous resources (takes priority)
    local continuousResource = ResourceMixin:GetContinuousResourceForPlayer()

    if continuousResource then
        self.continuousResource = continuousResource
        self.powerType = nil
        self.powerTypeName = nil

        -- Switch to continuous mode
        self:SetContinuousMode(true)
        Frame:SetScript("OnUpdate", Frame.onUpdateHandler)
        Frame.orbitDisabled = false
        Frame:Show()
        return
    end

    -- Otherwise, check for discrete resources
    self.continuousResource = nil
    self:SetContinuousMode(false)

    local powerType, powerTypeName = ResourceMixin:GetResourceForPlayer()

    self.powerType = powerType
    self.powerTypeName = powerTypeName

    if self.powerType then
        Frame:Show()
        Frame.orbitDisabled = false
        local needsOnUpdate = (self.powerType == Enum.PowerType.Runes or self.powerType == Enum.PowerType.Essence)
        Frame:SetScript("OnUpdate", needsOnUpdate and Frame.onUpdateHandler or nil)
        self:UpdateMaxPower()
    else
        Frame:SetScript("OnUpdate", nil)
        if Orbit:IsEditMode() then
            Frame.orbitDisabled = false
            Frame:Show()
            if Frame.StatusBarContainer then Frame.StatusBarContainer:Show() end
        else
            Frame:Hide()
            Frame.orbitDisabled = true
        end
    end
end

function Plugin:SetContinuousMode(isContinuous)
    if not Frame then
        return
    end

    if isContinuous then
        -- Show StatusBar container, hide discrete buttons (skinning handled by ApplySettings)
        if Frame.StatusBarContainer then
            Frame.StatusBarContainer:Show()
        end

        for _, btn in ipairs(Frame.buttons or {}) do
            btn:Hide()
        end

        -- Hide spacers for continuous mode
        if Frame.Spacers then
            for _, s in ipairs(Frame.Spacers) do
                s:Hide()
            end
        end
    else
        -- Hide StatusBar container, show discrete buttons
        if Frame.StatusBarContainer then
            Frame.StatusBarContainer:Hide()
        end
        -- Buttons will be shown by UpdateMaxPower
    end
end

function Plugin:UpdateMaxPower()
    if not Frame or not self.powerType then
        return
    end
    local max = self.powerType == Enum.PowerType.Runes and 6 or UnitPowerMax("player", self.powerType)
    Frame.maxPower = max

    if not Frame.StatusBar then
        Frame.StatusBarContainer = CreateFrame("Frame", nil, Frame, "BackdropTemplate")
        Frame.StatusBarContainer:SetAllPoints()
        Frame.StatusBarContainer:SetBackdrop(nil)
        Frame.StatusBar = CreateFrame("StatusBar", nil, Frame.StatusBarContainer)
        Frame.StatusBar:SetAllPoints()
        Frame.StatusBar:SetMinMaxValues(0, 1)
        Frame.StatusBar:SetValue(0)
    end

    Frame.Spacers = Frame.Spacers or {}
    for i = 1, MAX_SPACER_COUNT do
        if not Frame.Spacers[i] then
            Frame.Spacers[i] = Frame.StatusBar:CreateTexture(nil, "OVERLAY", nil, 7)
            Frame.Spacers[i]:SetColorTexture(0, 0, 0, 1)
        end
        Frame.Spacers[i]:Hide()
    end

    Frame.buttons = Frame.buttons or {}

    -- Create buttons as needed
    for i = 1, max do
        if not Frame.buttons[i] then
            local btn = CreateFrame("Frame", nil, Frame)
            btn:SetScript("OnEnter", function() end)
            Frame.buttons[i] = btn

            btn.SetActive = function(self, active)
                self.isActive = active
                if self.orbitBar then
                    self.orbitBar:SetShown(active)
                end
                if self.Overlay then
                    self.Overlay:SetShown(active)
                end
                if active and self.progressBar then
                    self.progressBar:Hide()
                end
            end

            btn.SetFraction = function(self, fraction)
                if self.progressBar then
                    if fraction > 0 and fraction < 1 then
                        self.progressBar:SetValue(fraction)
                        self.progressBar:Show()
                    else
                        self.progressBar:Hide()
                    end
                end
            end
        end
    end

    for i = max + 1, #Frame.buttons do
        if Frame.buttons[i] then
            Frame.buttons[i]:Hide()
        end
    end
    for i = 1, max do
        if Frame.buttons[i] then
            Frame.buttons[i]:Show()
        end
    end

    self:ApplySettings()
end

-- [ SPACER REPOSITIONING ]-------------------------------------------------------------------------
function Plugin:RepositionSpacers(max)
    if not Frame or not Frame.Spacers then
        return
    end

    local spacerWidth = (Frame.settings and Frame.settings.spacing) or 0
    local hideAll = (not max or max <= 1 or spacerWidth <= 0)

    if hideAll then
        for _, s in ipairs(Frame.Spacers) do
            s:Hide()
        end
        return
    end

    local totalWidth = Frame:GetWidth()
    if totalWidth < 10 and Frame.settings then
        totalWidth = Frame.settings.width or 200
    end

    local scale = Frame:GetEffectiveScale()
    if not scale or scale < 0.01 then
        scale = 1
    end

    local snappedSpacerWidth = PixelMultiple(spacerWidth, scale)
    local snappedTotalWidth = SnapToPixel(totalWidth, scale)

    for i = 1, MAX_SPACER_COUNT do
        local sp = Frame.Spacers[i]
        if sp then
            if i < max then
                sp:Show()
                sp:ClearAllPoints()
                sp:SetWidth(snappedSpacerWidth)
                sp:SetHeight(Frame:GetHeight())
                local leftPos = math.floor(snappedTotalWidth * (i / max) * scale) / scale
                sp:SetPoint("LEFT", Frame, "LEFT", leftPos, 0)
                if OrbitEngine.Pixel then
                    OrbitEngine.Pixel:Enforce(sp)
                end
            else
                sp:Hide()
            end
        end
    end
end

function Plugin:UpdateLayout(frame)
    if not Frame then
        return
    end
    local buttons = Frame.buttons or {}
    local max = Frame.maxPower or 5
    if max == 0 then
        return
    end

    local settings = Frame.settings or {}

    -- When anchored, Width is set by Anchor engine, so we use current width
    local totalWidth = Frame:GetWidth()

    -- If effectively zero or hidden, use settings default for initial calc
    if totalWidth < 10 then
        totalWidth = settings.width or 200
    end

    local height = settings.height or 15
    local spacing = settings.spacing or 2

    -- Pixel snapping
    local scale = Frame:GetEffectiveScale() or 1

    -- Snap values
    local snappedTotalWidth = SnapToPixel(totalWidth, scale)
    local snappedHeight = SnapToPixel(height, scale)
    local snappedSpacing = PixelMultiple(spacing, scale)

    -- Physical Updates
    Frame:SetHeight(snappedHeight)
    local usableWidth = snappedTotalWidth - ((max - 1) * snappedSpacing)

    for i = 1, max do
        local btn = buttons[i]
        if btn then
            local btnUsableWidth = usableWidth / max
            local leftPos = SnapToPixel((i - 1) * (btnUsableWidth + snappedSpacing), scale)
            local rightPos
            if i == max then
                rightPos = snappedTotalWidth
            else
                rightPos = SnapToPixel(i * (btnUsableWidth + snappedSpacing) - snappedSpacing, scale)
            end

            local btnWidth = rightPos - leftPos

            btn:SetSize(btnWidth, snappedHeight)
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", Frame, "LEFT", leftPos, 0)

            -- Apply Pixel:Enforce
            if OrbitEngine.Pixel then
                OrbitEngine.Pixel:Enforce(btn)
            end
        end
    end

    self:RepositionSpacers(max)
end

function Plugin:UpdateContinuousBar(curveKey, current, max)
    if not Frame.StatusBar then
        return
    end
    Frame.StatusBar:SetMinMaxValues(0, max)
    local smoothing = self:GetSetting(SYSTEM_INDEX, "SmoothAnimation") ~= false and SMOOTH_ANIM or nil
    Frame.StatusBar:SetValue(current, smoothing)
    local curveData = self:GetSetting(SYSTEM_INDEX, curveKey)
    if not curveData then
        return
    end

    -- MANA: use UnitPowerPercent + native ColorCurve (fully secret-safe)
    if self.continuousResource == "MANA" then
        local nativeCurve = OrbitEngine.WidgetLogic:ToNativeColorCurve(curveData)
        if nativeCurve and CanUseUnitPowerPercent then
            local color = UnitPowerPercent("player", Enum.PowerType.Mana, false, nativeCurve)
            if color then
                Frame.StatusBar:GetStatusBarTexture():SetVertexColor(color:GetRGBA())
                return
            end
        end
    end

    if issecretvalue and (issecretvalue(current) or issecretvalue(max)) then
        return
    end
    local progress = (max > 0) and (current / max) or 0
    local color = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, progress)
    if color then
        Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
    end
end

function Plugin:UpdateContinuousSpacers(cfg, max)
    if not Frame or not Frame.StatusBar then
        return
    end
    if not cfg.dividers or max <= 1 then
        if Frame.Spacers then
            for _, s in ipairs(Frame.Spacers) do
                s:Hide()
            end
        end
        return
    end

    -- Lazy-create spacers (UpdateMaxPower is never called for continuous resources)
    Frame.Spacers = Frame.Spacers or {}
    for i = 1, MAX_SPACER_COUNT do
        if not Frame.Spacers[i] then
            Frame.Spacers[i] = Frame.StatusBar:CreateTexture(nil, "OVERLAY", nil, 7)
            Frame.Spacers[i]:SetColorTexture(0, 0, 0, 1)
        end
    end

    self:RepositionSpacers(max)
end

function Plugin:UpdatePower()
    if not Frame then
        return
    end

    local textEnabled = not OrbitEngine.ComponentDrag:IsDisabled(Frame.Text)

    -- CONTINUOUS RESOURCES
    if self.continuousResource then
        local cfg = CONTINUOUS_RESOURCE_CONFIG[self.continuousResource]
        if cfg then
            local current, max, extra1, extra2 = cfg.getState()
            if current and max then
                self:UpdateContinuousBar(cfg.curveKey, current, max)
                self:UpdateContinuousSpacers(cfg, max)
                if Frame.Text and textEnabled then
                    cfg.updateText(Frame.Text, current, max, extra1, extra2)
                end
            elseif Frame.StatusBar then
                Frame.StatusBar:SetValue(0)
            end
        end
        return
    end

    if not self.powerType then
        return
    end

    if self.powerType == Enum.PowerType.Runes then
        if Frame.StatusBarContainer then
            Frame.StatusBarContainer:Hide()
        end
        if Frame.Spacers then
            for _, s in ipairs(Frame.Spacers) do
                s:Hide()
            end
        end

        local sortedRunes = ResourceMixin:GetSortedRuneOrder()
        local readyCount = 0
        local maxRunes = #sortedRunes

        for pos, runeData in ipairs(sortedRunes) do
            local btn = Frame.buttons[pos]
            if btn then
                local color = self:GetResourceColor(pos, maxRunes)
                if runeData.ready then
                    readyCount = readyCount + 1
                    btn:SetActive(true)
                    btn:SetFraction(0)

                    if btn.orbitBar then
                        btn.orbitBar:SetVertexColor(color.r, color.g, color.b)
                    end
                else
                    btn:SetActive(false)
                    btn:SetFraction(runeData.fraction)

                    if btn.progressBar then
                        btn.progressBar:SetStatusBarColor(color.r * INACTIVE_DIM_FACTOR, color.g * INACTIVE_DIM_FACTOR, color.b * INACTIVE_DIM_FACTOR)
                    end
                end
            end
        end

        if Frame.Text and Frame.Text:IsShown() then
            Frame.Text:SetText(readyCount)
        end
        return
    end

    if self.powerType == Enum.PowerType.Essence then
        if Frame.StatusBarContainer then
            Frame.StatusBarContainer:Hide()
        end
        if Frame.Spacers then
            for _, s in ipairs(Frame.Spacers) do
                s:Hide()
            end
        end

        local current = UnitPower("player", self.powerType)
        local max = Frame.maxPower or 5

        for i = 1, max do
            local btn = Frame.buttons[i]
            if btn then
                local color = self:GetResourceColor(i, max)
                local state, remaining, fraction = ResourceMixin:GetEssenceState(i, current, max)

                if state == "full" then
                    if btn.orbitBar then
                        btn.orbitBar:Show()
                        btn.orbitBar:SetVertexColor(color.r, color.g, color.b)
                    end
                    if btn.Overlay then btn.Overlay:Show() end
                    if btn.progressBar then btn.progressBar:Hide() end
                elseif state == "partial" then
                    if btn.orbitBar then
                        btn.orbitBar:Show()
                        btn.orbitBar:SetVertexColor(color.r * INACTIVE_DIM_FACTOR, color.g * INACTIVE_DIM_FACTOR, color.b * INACTIVE_DIM_FACTOR)
                    end
                    if btn.Overlay then btn.Overlay:Hide() end
                    btn:SetFraction(fraction)
                    if btn.progressBar then
                        btn.progressBar:SetStatusBarColor(color.r * PARTIAL_DIM_FACTOR, color.g * PARTIAL_DIM_FACTOR, color.b * PARTIAL_DIM_FACTOR)
                    end
                else
                    if btn.orbitBar then btn.orbitBar:Hide() end
                    if btn.Overlay then btn.Overlay:Hide() end
                    if btn.progressBar then btn.progressBar:Hide() end
                end
            end
        end

        if Frame.Text and Frame.Text:IsShown() then
            Frame.Text:SetText(current)
        end
        return
    end

    if Frame.buttons then
        for _, btn in ipairs(Frame.buttons) do
            btn:Hide()
        end
    end
    if Frame.StatusBarContainer then
        Frame.StatusBarContainer:Show()
    end

    local cur = UnitPower("player", self.powerType, true)
    local max = Frame.maxPower or 5
    local mod = UnitPowerDisplayMod(self.powerType)
    if mod and mod > 0 then
        cur = cur / mod
    end

    local curveData = self:GetSetting(SYSTEM_INDEX, "BarColorCurve")
    local color

    if curveData and #curveData.pins > 1 then
        local progress = (max > 0) and (cur / max) or 0
        color = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, progress)
    end
    color = color or self:GetResourceColor(nil, nil, false)

    if Frame.StatusBar then
        Frame.StatusBar:SetMinMaxValues(0, max)
        local smoothing = self:GetSetting(SYSTEM_INDEX, "SmoothAnimation") ~= false and SMOOTH_ANIM or nil
        Frame.StatusBar:SetValue(cur, smoothing)
        if color then
            Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    end

    self:RepositionSpacers(max)

    -- Charged combo point overlays (secret-safe: StatusBars handle fill in C++)
    Frame.ChargedOverlays = Frame.ChargedOverlays or {}
    if self.powerType == Enum.PowerType.ComboPoints then
        local chargedPoints = GetUnitChargedPowerPoints("player")
        local chargedLookup = {}
        if chargedPoints then
            for _, idx in ipairs(chargedPoints) do
                chargedLookup[idx] = true
            end
        end
        local chargedColor = self:GetSetting(SYSTEM_INDEX, "ChargedComboPointColor")
            or Orbit.Colors.PlayerResources.ChargedComboPoint
        local texture = self:GetSetting(SYSTEM_INDEX, "Texture")
        local texturePath = LSM:Fetch("statusbar", texture)
        local overlayScale = Frame:GetEffectiveScale() or 1
        local overlayTotalWidth = SnapToPixel(Frame:GetWidth(), overlayScale)
        local spacerWidth = (Frame.settings and Frame.settings.spacing) or 0
        local overlaySpacerWidth = PixelMultiple(spacerWidth, overlayScale)

        for i = 1, max do
            local overlay = Frame.ChargedOverlays[i]
            if not overlay then
                overlay = CreateFrame("StatusBar", nil, Frame.StatusBarContainer)
                overlay:SetFrameLevel(Frame.StatusBar:GetFrameLevel() + 1)
                Frame.ChargedOverlays[i] = overlay
            end
            if chargedLookup[i] then
                local segLeft = math.floor(overlayTotalWidth * ((i - 1) / max) * overlayScale) / overlayScale
                local segRight = math.floor(overlayTotalWidth * (i / max) * overlayScale) / overlayScale
                local left = (i > 1) and (segLeft + overlaySpacerWidth) or 0
                local right = (i < max) and segRight or overlayTotalWidth

                overlay:ClearAllPoints()
                overlay:SetPoint("TOPLEFT", Frame.StatusBarContainer, "TOPLEFT", left, 0)
                overlay:SetPoint("BOTTOMRIGHT", Frame.StatusBarContainer, "TOPLEFT", right, -Frame:GetHeight())
                overlay:SetStatusBarTexture(texturePath)
                overlay:SetStatusBarColor(chargedColor.r, chargedColor.g, chargedColor.b)
                overlay:SetMinMaxValues(i - 1, i)
                overlay:SetValue(cur)
                overlay:Show()
            else
                overlay:Hide()
            end
        end
        for i = max + 1, #Frame.ChargedOverlays do
            Frame.ChargedOverlays[i]:Hide()
        end
    else
        for _, overlay in ipairs(Frame.ChargedOverlays) do
            overlay:Hide()
        end
    end

    if Frame.Text and Frame.Text:IsShown() then
        local spec = GetSpecialization()
        local specID = spec and GetSpecializationInfo(spec)
        if PLAYER_CLASS == "WARLOCK" and specID == WARLOCK_SPEC_DESTRUCTION then
            Frame.Text:SetFormattedText("%.1f", cur)
        else
            Frame.Text:SetText(math.floor(cur))
        end
    end
end
