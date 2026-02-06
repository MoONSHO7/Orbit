---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local ResourceMixin = Orbit.ResourceBarMixin

-- Local defaults (decoupled from Core Constants)
local DEFAULTS = {
    Width = 200,
    Height = 30,
    Y = -200,
}
local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

-- [ HELPERS ]--------------------------------------------------------------------------------------
local function SafeUnitPowerPercent(unit, resource)
    if type(UnitPowerPercent) ~= "function" or not CurveConstants or not CurveConstants.ScaleTo100 then
        return nil
    end
    local ok, pct = pcall(UnitPowerPercent, unit, resource, false, CurveConstants.ScaleTo100)
    return (ok and pct) or nil
end

-- [ PLUGIN REGISTRATION ]--------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerResources"
local SYSTEM_INDEX = 1

local Plugin = Orbit:RegisterPlugin("Player Resources", SYSTEM_ID, {
    canvasMode = true,
    defaults = {
        Hidden = false,
        Width = DEFAULTS.Width,
        Height = DEFAULTS.Height,
        UseCustomColor = false,
        BarColor = { r = 1, g = 1, b = 1, a = 1 },
        BarColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } },
        -- Stagger (Brewmaster Monk) - Green→Yellow→Red gradient
        StaggerColorCurve = { pins = {
            { position = 0, color = { r = 0.52, g = 1.0, b = 0.52, a = 1 } },
            { position = 0.5, color = { r = 1.0, g = 0.98, b = 0.72, a = 1 } },
            { position = 1, color = { r = 1.0, g = 0.42, b = 0.42, a = 1 } },
        } },
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
    },
}, Orbit.Constants.PluginGroups.CooldownManager)

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

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
    -- Width (only when not anchored)
    if not isAnchored then
        WL:AddSizeSettings(self, schema, systemIndex, systemFrame, { default = DEFAULTS.Width }, nil, nil)
    end

    -- Height
    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, { min = 5, max = 20, default = DEFAULTS.Height }, nil)

    -- Opacity (resting alpha when visible)
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })

    -- Out of Combat Fade
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
            OrbitEngine.Layout:Reset(dialog)
            self:AddSettings(dialog, systemFrame)
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

    -- Custom Color Toggle
    table.insert(schema.controls, {
        type = "checkbox",
        key = "UseCustomColor",
        label = "Use Custom Color",
        default = false,
        onChange = function(val)
            self:SetSetting(systemIndex, "UseCustomColor", val)
            self:ApplyButtonVisuals()
            self:UpdatePower()
            -- Refresh settings panel to show/hide Bar Color picker
            OrbitEngine.Layout:Reset(dialog)
            self:AddSettings(dialog, systemFrame)
        end,
    })

    -- Bar Color Picker (only show if UseCustomColor is enabled)
    local useCustomColor = self:GetSetting(systemIndex, "UseCustomColor")
    if useCustomColor then
        table.insert(schema.controls, {
            type = "colorcurve",
            key = "BarColorCurve",
            label = "Bar Color",
            default = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } },
            onChange = function(curveData)
                self:SetSetting(systemIndex, "BarColorCurve", curveData)
                self:ApplyButtonVisuals()
                self:UpdatePower()
            end,
        })
    end

    -- Stagger Color Curve (Brewmaster Monk)
    if self.continuousResource == "STAGGER" then
        table.insert(schema.controls, {
            type = "colorcurve",
            key = "StaggerColorCurve",
            label = "Stagger Colour",
            tooltip = "Color gradient from low (left) to heavy (right) stagger",
            default = { pins = {
                { position = 0, color = { r = 0.52, g = 1.0, b = 0.52, a = 1 } },
                { position = 0.5, color = { r = 1.0, g = 0.98, b = 0.72, a = 1 } },
                { position = 1, color = { r = 1.0, g = 0.42, b = 0.42, a = 1 } },
            } },
            onChange = function(curveData)
                self:SetSetting(systemIndex, "StaggerColorCurve", curveData)
                self:UpdatePower()
            end,
        })
    end

    -- Soul Fragments Color Curve (Demon Hunter)
    if self.continuousResource == "SOUL_FRAGMENTS" then
        table.insert(schema.controls, {
            type = "colorcurve",
            key = "SoulFragmentsColorCurve",
            label = "Soul Fragments Colour",
            tooltip = "Color gradient from empty (left) to full (right)",
            default = { pins = { { position = 0, color = { r = 0.278, g = 0.125, b = 0.796, a = 1 } } } },
            onChange = function(curveData)
                self:SetSetting(systemIndex, "SoulFragmentsColorCurve", curveData)
                self:UpdatePower()
            end,
        })
    end

    -- Ebon Might Color Curve (Augmentation Evoker)
    if self.continuousResource == "EBON_MIGHT" then
        table.insert(schema.controls, {
            type = "colorcurve",
            key = "EbonMightColorCurve",
            label = "Ebon Might Colour",
            tooltip = "Color gradient from empty (left) to full (right)",
            default = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.4, a = 1 } } } },
            onChange = function(curveData)
                self:SetSetting(systemIndex, "EbonMightColorCurve", curveData)
                self:UpdatePower()
            end,
        })
    end

    -- Mana Color Curve (Shadow Priest, Ele Shaman, Balance Druid)
    if self.continuousResource == "MANA" then
        table.insert(schema.controls, {
            type = "colorcurve",
            key = "ManaColorCurve",
            label = "Mana Colour",
            tooltip = "Color gradient from empty (left) to full (right)",
            default = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } },
            onChange = function(curveData)
                self:SetSetting(systemIndex, "ManaColorCurve", curveData)
                self:UpdatePower()
            end,
        })
    end

    -- Maelstrom Weapon Color Curve (Enhancement Shaman)
    if self.continuousResource == "MAELSTROM_WEAPON" then
        table.insert(schema.controls, {
            type = "colorcurve",
            key = "MaelstromWeaponColorCurve",
            label = "Maelstrom Colour",
            tooltip = "Color gradient from empty (left) to full (right)",
            default = { pins = { { position = 0, color = { r = 0.0, g = 0.5, b = 1.0, a = 1 } } } },
            onChange = function(curveData)
                self:SetSetting(systemIndex, "MaelstromWeaponColorCurve", curveData)
                self:UpdatePower()
            end,
        })
    end

    -- Note: Show Text is now controlled via Canvas Mode (drag Text to disabled dock)

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
    self.frame = Frame -- Expose for PluginMixin compatibility

    -- [ CANVAS PREVIEW ] -------------------------------------------------------------------------------
    function Frame:CreateCanvasPreview(options)
        local scale = options.scale or 1
        local borderSize = options.borderSize or 1

        -- Base container
        local preview = OrbitEngine.Preview.Frame:CreateBasePreview(self, scale, options.parent, borderSize)

        -- Generate representative buttons (e.g. 5 combo points)
        local buttonCount = 5
        local textureName = Plugin:GetSetting(SYSTEM_INDEX, "Texture")
        local spacing = borderSize * scale
        local totalSpacing = (buttonCount - 1) * spacing

        -- Calculate dimensions inside the border
        local totalWidth = preview:GetWidth()
        local height = preview:GetHeight()
        local btnWidth = (totalWidth - totalSpacing) / buttonCount

        -- Texture path
        local texturePath = "Interface\\Buttons\\WHITE8x8"
        if textureName and LSM then
            texturePath = LSM:Fetch("statusbar", textureName) or texturePath
        end

        -- Get Class Color
        local _, class = UnitClass("player")
        local color = Orbit.Colors.PlayerResources[class] or { r = 1, g = 0.8, b = 0 }

        -- Create dummy buttons
        for i = 1, buttonCount do
            local btn = CreateFrame("Frame", nil, preview, "BackdropTemplate")
            btn:SetSize(btnWidth, height)

            -- Position
            if i == 1 then
                btn:SetPoint("LEFT", preview, "LEFT", 0, 0)
            else
                btn:SetPoint("LEFT", preview.buttons[i - 1], "RIGHT", spacing, 0)
            end

            -- Skin it
            local bar = btn:CreateTexture(nil, "ARTWORK")
            bar:SetAllPoints()
            bar:SetTexture(texturePath)
            bar:SetVertexColor(color.r, color.g, color.b)

            -- Border
            if Orbit.Skin and Orbit.Skin.ClassBar then
                local scaledBorder = borderSize * scale
                if scaledBorder > 0 then
                    btn:SetBackdrop({
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = scaledBorder,
                    })
                    btn:SetBackdropBorderColor(0, 0, 0, 1)
                else
                    btn:SetBackdrop(nil)
                end

                -- Inset the bar to show border
                local inset = borderSize * scale
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", inset, -inset)
                bar:SetPoint("BOTTOMRIGHT", -inset, inset)
            end

            if not preview.buttons then
                preview.buttons = {}
            end
            preview.buttons[i] = btn
        end

        return preview
    end

    if not Frame.Overlay then
        Frame.Overlay = CreateFrame("Frame", nil, Frame)
        Frame.Overlay:SetAllPoints()
        Frame.Overlay:SetFrameLevel(Frame:GetFrameLevel() + 20)
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

        -- Apply Pixel Perfect
        if OrbitEngine.Pixel then
            OrbitEngine.Pixel:Enforce(Frame)
            OrbitEngine.Pixel:Enforce(Frame.StatusBarContainer)
            OrbitEngine.Pixel:Enforce(Frame.StatusBar)
        end
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

    -- OnUpdate for smooth rune/essence timer updates
    Frame:SetScript("OnUpdate", function(_, elapsed)
        Frame.elapsed = (Frame.elapsed or 0) + elapsed
        if Frame.elapsed >= 0.05 then
            Frame.elapsed = 0
            if self.powerType == Enum.PowerType.Runes or self.powerType == Enum.PowerType.Essence then
                self:UpdatePower()
            elseif self.continuousResource then
                self:UpdatePower()
            end
        end
    end)

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
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
    if hidden and not isEditMode then
        Frame:Hide()
        return
    end

    -- Get settings (defaults handled by PluginMixin)
    local width = self:GetSetting(systemIndex, "Width")
    local height = self:GetSetting(systemIndex, "Height")
    local borderSize = self:GetSetting(systemIndex, "BorderSize")
    if not borderSize and Orbit.db.GlobalSettings then
        borderSize = Orbit.db.GlobalSettings.BorderSize
    end
    borderSize = borderSize or 1
    local spacing = borderSize
    local texture = self:GetSetting(systemIndex, "Texture")
    local fontName = self:GetSetting(systemIndex, "Font")

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
    -- Font & Text
    local fontPath = LSM:Fetch("font", fontName)

    if OrbitEngine.ComponentDrag:IsDisabled(Frame.Text) then
        Frame.Text:Hide()
    else
        Frame.Text:Show()

        local positions = self:GetSetting(SYSTEM_INDEX, "ComponentPositions")
        local textSize = (positions and positions.Text and positions.Text.overrides and positions.Text.overrides.FontSize)
            or Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)

        Frame.Text:SetFont(fontPath, textSize, "OUTLINE")

        Frame.Text:ClearAllPoints()
        if height > textSize then
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
        local bgColor = self:GetSetting(systemIndex, "BackdropColour")
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
    OrbitEngine.Frame:RestorePosition(Frame, self, systemIndex)

    -- Restore component positions (Canvas Mode)
    local savedPositions = self:GetSetting(systemIndex, "ComponentPositions")
    if savedPositions and OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:RestoreFramePositions(Frame, savedPositions)
    end

    -- 3. Update Visuals (Skinning Buttons)
    self:ApplyButtonVisuals()

    -- 4. Update Power (Refresh Logic & Spacer Positions)
    self:UpdatePower()

    -- 5. Apply Out of Combat Fade (with hover detection based on setting)
    if Orbit.OOCFadeMixin then
        local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(Frame, self, systemIndex, "OutOfCombatFade", enableHover)
    end
end

-- [ BUTTON VISUAL APPLICATION ]--------------------------------------------------------------------
function Plugin:ApplyButtonVisuals()
    if not Frame or not Frame.buttons then
        return
    end

    local borderSize = (Frame.settings and Frame.settings.borderSize) or 1
    local texture = self:GetSetting(SYSTEM_INDEX, "Texture")

    local _, class = UnitClass("player")
    local max = math.max(1, Frame.maxPower or #Frame.buttons)
    local globalBgColor = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BackdropColourCurve
        and OrbitEngine.WidgetLogic and OrbitEngine.WidgetLogic:GetFirstColorFromCurve(Orbit.db.GlobalSettings.BackdropColourCurve)
    local bgColor = globalBgColor or { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }

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

                local overlayPath = "Interface\\AddOns\\Orbit\\Core\\assets\\Statusbar\\orbit-left-right.tga"
                if not btn.Overlay then
                    btn.Overlay = btn:CreateTexture(nil, "OVERLAY")
                    btn.Overlay:SetAllPoints(btn.orbitBar)
                    btn.Overlay:SetTexture(overlayPath)
                    btn.Overlay:SetBlendMode("BLEND")
                    btn.Overlay:SetAlpha(0.3)
                end
                -- Sync visibility with orbitBar
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

            -- Apply visuals (Texture, Color, Overlay)
            if color then
                local barColor = { r = color.r * 0.5, g = color.g * 0.5, b = color.b * 0.5 }
                Orbit.Skin:SkinStatusBar(btn.progressBar, texture, barColor)
            end
        end
    end
end

-- [ RESOURCE COLOR HELPER ]-------------------------------------------------------------------------
function Plugin:GetResourceColor(index, maxResources, isCharged)
    local _, class = UnitClass("player")
    local colors = Orbit.Colors.PlayerResources
    local fallback = colors[class] or { r = 1, g = 1, b = 1 }
    
    local useCustomColor = self:GetSetting(SYSTEM_INDEX, "UseCustomColor")
    local curveData = self:GetSetting(SYSTEM_INDEX, "BarColorCurve")

    if useCustomColor and curveData then
        local curveColor
        if index and maxResources and maxResources > 1 then
            local position = (index - 1) / (maxResources - 1)
            curveColor = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, position)
        else
            curveColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(curveData)
        end
        return curveColor or fallback
    end

    if isCharged then return colors.ChargedComboPoint or fallback end

    if class == "DEATHKNIGHT" then
        local spec = GetSpecialization()
        local specID = spec and GetSpecializationInfo(spec)
        if specID == 250 then return colors.RuneBlood or fallback
        elseif specID == 251 then return colors.RuneFrost or fallback
        elseif specID == 252 then return colors.RuneUnholy or fallback
        end
    end

    return fallback
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
        self:UpdateMaxPower()
    else
        Frame:Hide()
    end
end

function Plugin:SetContinuousMode(isContinuous)
    if not Frame then
        return
    end

    if isContinuous then
        -- Show StatusBar container, hide discrete buttons
        if Frame.StatusBarContainer then
            Frame.StatusBarContainer:Show()

            -- Apply texture and border using ClassBar skin
            local texture = self:GetSetting(SYSTEM_INDEX, "Texture")
            local borderSize = (Frame.settings and Frame.settings.borderSize) or 1

            Orbit.Skin.ClassBar:SkinStatusBar(Frame.StatusBarContainer, Frame.StatusBar, {
                borderSize = borderSize,
                texture = texture,
            })
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
    for i = 1, 10 do
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

function Plugin:UpdateLayout(frame)
    if not Frame then
        return
    end
    local buttons = Frame.buttons
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

    -- Pixel snapping helpers
    local scale = Frame:GetEffectiveScale() or 1
    local function SnapToPixel(value)
        if OrbitEngine.Pixel then
            return OrbitEngine.Pixel:Snap(value, scale)
        end
        return math.floor(value * scale + 0.5) / scale
    end

    -- Snap values
    local snappedTotalWidth = SnapToPixel(totalWidth)
    local snappedHeight = SnapToPixel(height)
    local snappedSpacing = SnapToPixel(spacing)

    -- Physical Updates
    Frame:SetHeight(snappedHeight)
    local usableWidth = snappedTotalWidth - ((max - 1) * snappedSpacing)

    for i = 1, max do
        local btn = buttons[i]
        if btn then
            local btnUsableWidth = usableWidth / max
            local leftPos = SnapToPixel((i - 1) * (btnUsableWidth + snappedSpacing))
            local rightPos
            if i == max then
                rightPos = snappedTotalWidth
            else
                rightPos = SnapToPixel(i * (btnUsableWidth + snappedSpacing) - snappedSpacing)
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
end

function Plugin:UpdatePower()
    if not Frame then
        return
    end

    local textEnabled = not OrbitEngine.ComponentDrag:IsDisabled(Frame.Text)

    -- CONTINUOUS RESOURCES
    if self.continuousResource then
        -- STAGGER (Brewmaster Monk)
        if self.continuousResource == "STAGGER" then
            local stagger, maxHealth, level = ResourceMixin:GetStaggerState()

            if Frame.StatusBar then
                Frame.StatusBar:SetMinMaxValues(0, maxHealth)
                Frame.StatusBar:SetValue(stagger, SMOOTH_ANIM)

                -- Sample color from StaggerColorCurve based on stagger percentage
                local staggerPercent = (maxHealth > 0) and (stagger / maxHealth) or 0
                local curveData = self:GetSetting(SYSTEM_INDEX, "StaggerColorCurve")
                local color = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, staggerPercent)
                if color then Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b) end
            end

            if Frame.Text and textEnabled then
                Frame.Text:SetText("")
            end
            return
        end

        -- SOUL FRAGMENTS (Demon Hunter)
        if self.continuousResource == "SOUL_FRAGMENTS" then
            local current, max, isVoidMeta = ResourceMixin:GetSoulFragmentsState()

            if current and max and Frame.StatusBar then
                Frame.StatusBar:SetMinMaxValues(0, max)
                Frame.StatusBar:SetValue(current, SMOOTH_ANIM)

                local curveData = self:GetSetting(SYSTEM_INDEX, "SoulFragmentsColorCurve")
                local progress = (max > 0) and (current / max) or 0
                local color = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, progress)
                if color then Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b) end

                if Frame.Text and textEnabled then
                    Frame.Text:SetText(current)
                end
            elseif Frame.StatusBar then
                Frame.StatusBar:SetValue(0)
            end
            return
        end

        -- EBON MIGHT (Augmentation Evoker)
        if self.continuousResource == "EBON_MIGHT" then
            local current, max = ResourceMixin:GetEbonMightState()

            if current and max and Frame.StatusBar then
                Frame.StatusBar:SetMinMaxValues(0, max)
                Frame.StatusBar:SetValue(current, SMOOTH_ANIM)

                local curveData = self:GetSetting(SYSTEM_INDEX, "EbonMightColorCurve")
                local progress = (max > 0) and (current / max) or 0
                local color = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, progress)
                if color then Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b) end

                if Frame.Text and textEnabled then
                    Frame.Text:SetFormattedText("%.0f", current)
                end
            elseif Frame.StatusBar then
                Frame.StatusBar:SetValue(0)
            end
            return
        end

        -- MANA (Shadow Priest, Ele/Enh Shaman, Balance Druid)
        if self.continuousResource == "MANA" then
            local current = UnitPower("player", Enum.PowerType.Mana)
            local max = UnitPowerMax("player", Enum.PowerType.Mana)

            if Frame.StatusBar then
                Frame.StatusBar:SetMinMaxValues(0, max)
                Frame.StatusBar:SetValue(current, SMOOTH_ANIM)

                local curveData = self:GetSetting(SYSTEM_INDEX, "ManaColorCurve")
                local progress = (max > 0) and (current / max) or 0
                local color = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, progress)
                if color then Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b) end
            end

            if Frame.Text and textEnabled then
                local percent = SafeUnitPowerPercent("player", Enum.PowerType.Mana)
                if percent then
                    Frame.Text:SetFormattedText("%.0f", percent)
                else
                    Frame.Text:SetText(current)
                end
            end
            return
        end

        -- MAELSTROM WEAPON (Enhancement Shaman)
        if self.continuousResource == "MAELSTROM_WEAPON" then
            local applications, maxStacks, hasAura, auraInstanceID = ResourceMixin:GetMaelstromWeaponState()

            if Frame.StatusBar then
                Frame.StatusBar:SetMinMaxValues(0, maxStacks)
                Frame.StatusBar:SetValue(applications, SMOOTH_ANIM)

                local curveData = self:GetSetting(SYSTEM_INDEX, "MaelstromWeaponColorCurve")
                local progress = (maxStacks > 0) and (applications / maxStacks) or 0
                local color = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, progress)
                if color then Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b) end
            end

            if Frame.Text and textEnabled then
                if hasAura and auraInstanceID and C_UnitAuras.GetAuraApplicationDisplayCount then
                    local displayCount = C_UnitAuras.GetAuraApplicationDisplayCount("player", auraInstanceID)
                    Frame.Text:SetText(displayCount)
                elseif not hasAura then
                    Frame.Text:SetText("")
                end
            end
            return
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
                        btn.progressBar:SetStatusBarColor(color.r * 0.5, color.g * 0.5, color.b * 0.5)
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
                        btn.orbitBar:SetVertexColor(color.r * 0.5, color.g * 0.5, color.b * 0.5)
                    end
                    if btn.Overlay then btn.Overlay:Hide() end
                    btn:SetFraction(fraction)
                    if btn.progressBar then
                        btn.progressBar:SetStatusBarColor(color.r * 0.7, color.g * 0.7, color.b * 0.7)
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
    if mod and mod > 0 then cur = cur / mod end
    
    local useCustomColor = self:GetSetting(SYSTEM_INDEX, "UseCustomColor")
    local curveData = self:GetSetting(SYSTEM_INDEX, "BarColorCurve")
    local color
    
    if useCustomColor and curveData then
        local progress = (max > 0) and (cur / max) or 0
        color = OrbitEngine.WidgetLogic:SampleColorCurve(curveData, progress)
    elseif self.powerType == Enum.PowerType.ComboPoints then
        local chargedPoints = GetUnitChargedPowerPoints("player")
        if chargedPoints and #chargedPoints > 0 then
            color = self:GetResourceColor(nil, nil, true)
        end
    end
    color = color or self:GetResourceColor(nil, nil, false)

    if Frame.StatusBar then
        Frame.StatusBar:SetMinMaxValues(0, max)
        Frame.StatusBar:SetValue(cur, SMOOTH_ANIM)
        if color then Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b) end
    end

    -- Update Spacers (Pixel-Perfect)
    local spacerWidth = 2
    if Frame.settings and Frame.settings.spacing then
        spacerWidth = Frame.settings.spacing
    end
    local max = Frame.maxPower or 5
    local totalWidth = Frame:GetWidth()

    -- If width is invalid, use setting default
    if totalWidth < 10 and Frame.settings and Frame.settings.width then
        totalWidth = Frame.settings.width
    end

    -- Calculate pixel scale for snapping to physical pixels
    local scale = Frame:GetEffectiveScale()
    if not scale or scale < 0.01 then
        scale = 1
    end

    -- Snap helper: rounds position to nearest physical pixel
    local function SnapToPixel(value)
        if OrbitEngine.Pixel then
            return OrbitEngine.Pixel:Snap(value, scale)
        end
        return math.floor(value * scale + 0.5) / scale
    end

    -- Snap spacer width
    local snappedSpacerWidth = SnapToPixel(spacerWidth)
    local snappedTotalWidth = SnapToPixel(totalWidth)

    if Frame.Spacers then
        for i = 1, 10 do
            local sp = Frame.Spacers[i]
            if sp then
                if i < max and snappedSpacerWidth > 0 then
                    sp:Show()
                    sp:ClearAllPoints()
                    sp:SetWidth(snappedSpacerWidth)
                    sp:SetHeight(Frame:GetHeight())

                    local boundaryPercent = i / max
                    local centerPos = SnapToPixel(snappedTotalWidth * boundaryPercent)
                    local xPos = SnapToPixel(centerPos - (snappedSpacerWidth / 2))

                    sp:SetPoint("LEFT", Frame, "LEFT", xPos, 0)

                    -- Apply Pixel:Enforce if available
                    if OrbitEngine.Pixel then
                        OrbitEngine.Pixel:Enforce(sp)
                    end
                else
                    sp:Hide()
                end
            end
        end
    end

    if Frame.Text and Frame.Text:IsShown() then
        Frame.Text:SetText(math.floor(cur))
    end
    return
end
