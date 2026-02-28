---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local ResourceMixin = Orbit.ResourceBarMixin
local ContinuousRenderer = Orbit.ContinuousBarRenderer
local DiscreteRenderer = Orbit.DiscreteBarRenderer

local DEFAULTS = { Width = 200, Height = 12, Y = -200 }
local SMOOTH_ANIM = Enum.StatusBarInterpolation.ExponentialEaseOut
local UPDATE_INTERVAL = 0.05
local MAX_SPACER_COUNT = 10
local FRAME_LEVEL_BOOST = 10
local DIVIDER_SIZE_DEFAULT = 2
local INACTIVE_DIM_FACTOR = 0.5
local PARTIAL_DIM_FACTOR = 0.7
local OVERLAY_LEVEL_OFFSET = 20
local PREVIEW_BAR_FILL = 0.65
local TICK_SIZE_DEFAULT = OrbitEngine.TickMixin.TICK_SIZE_DEFAULT
local TICK_SIZE_MAX = OrbitEngine.TickMixin.TICK_SIZE_MAX
local TICK_ALPHA_CURVE = OrbitEngine.TickMixin.TICK_ALPHA_CURVE
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

local CONTINUOUS_RESOURCE_CONFIG = ContinuousRenderer.CONFIG

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
        -- Stagger (Brewmaster Monk) - Greenâ†’Yellowâ†’Red gradient
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
        FrequentUpdates = false,
        TickSize = TICK_SIZE_DEFAULT,
        ComponentPositions = {
            Text = { anchorX = "CENTER", offsetX = 0, anchorY = "CENTER", offsetY = 0, justifyH = "CENTER" },
        },
    },
})

-- Frame reference (created in OnLoad)
local Frame

-- Settings UI: see PlayerResourceSettings.lua

-- [ LIFECYCLE ]------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Register standard events (Handle PEW, EditMode -> ApplySettings)
    self:RegisterStandardEvents()

    -- Listen for master plugin state changes (PlayerFrame enabled/disabled via Addon Manager)
    Orbit.EventBus:On("ORBIT_PLUGIN_STATE_CHANGED", function(pluginName, enabled)
        if pluginName == "Player Frame" then
            self:UpdateVisibility()
        end
    end)

    Orbit.EventBus:On("ORBIT_GLOBAL_BACKDROP_CHANGED", function()
        self:ApplySettings()
    end, self)

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
    self.mountedConfig = { frame = Frame }

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

        local bgColor = OrbitEngine.ColorCurve:GetFirstColorFromCurve(Orbit.db.GlobalSettings.BackdropColourCurve) or Orbit.Constants.Colors.Background

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
                    local color = OrbitEngine.ColorCurve:SampleColorCurve(curveData, PREVIEW_BAR_FILL)
                    if color then
                        bar:SetStatusBarColor(color.r, color.g, color.b)
                    end
                end

                local divMax = MAX_SPACER_COUNT
                local logicalGap = OrbitEngine.Pixel:Multiple(spacing, scale)
                local exactWidth = (width - (logicalGap * (divMax - 1))) / divMax
                local snappedWidth = OrbitEngine.Pixel:Snap(exactWidth, scale)

                local currentLeft = 0

                for i = 1, divMax - 1 do
                    currentLeft = currentLeft + snappedWidth

                    local sp = bar:CreateTexture(nil, "OVERLAY", nil, 7)
                    sp:SetColorTexture(0, 0, 0, 1)
                    sp:SetSize(logicalGap, height)
                    
                    local logicalLeft = OrbitEngine.Pixel:Snap(currentLeft, scale)
                    sp:SetPoint("LEFT", container, "LEFT", logicalLeft, 0)
                    
                    OrbitEngine.Pixel:Enforce(sp)
                    currentLeft = currentLeft + logicalGap
                end
            end
        else
            local max = self.maxPower or 5
            local snappedHeight = OrbitEngine.Pixel:Snap(height, scale)
            local previewActive = math.max(1, max - 1)

            local logicalGap = OrbitEngine.Pixel:Multiple(spacing, scale)
            local exactWidth = (width - (logicalGap * (max - 1))) / max
            local snappedWidth = OrbitEngine.Pixel:Snap(exactWidth, scale)

            local currentLeft = 0

            preview.buttons = {}
            for i = 1, max do
                local logicalLeft = OrbitEngine.Pixel:Snap(currentLeft, scale)

                local btn = CreateFrame("Frame", nil, preview)
                btn:SetPoint("LEFT", preview, "LEFT", logicalLeft, 0)
                btn:SetSize(snappedWidth, height)
                
                Orbit.Skin.ClassBar:SkinButton(btn, { borderSize = borderSize, texture = texture, backColor = bgColor })
                
                OrbitEngine.Pixel:Enforce(btn)
                currentLeft = currentLeft + snappedWidth + logicalGap

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
        Frame.StatusBarContainer = CreateFrame("Frame", nil, Frame)
        Frame.StatusBarContainer:SetAllPoints()

        Frame.StatusBar = CreateFrame("StatusBar", nil, Frame.StatusBarContainer)
        Frame.StatusBar:SetPoint("TOPLEFT")
        Frame.StatusBar:SetPoint("BOTTOMRIGHT")
        Frame.StatusBar:SetMinMaxValues(0, 1)
        Frame.StatusBar:SetValue(0)
        Frame.StatusBar:SetStatusBarTexture(LSM:Fetch("statusbar", "Melli"))
        Frame.orbitBar = Frame.StatusBar

        if not Frame.bg then
            Frame.bg = Frame:CreateTexture(nil, "BACKGROUND")
            Frame.bg:SetAllPoints()
            local c = Orbit.Constants.Colors.Background
            Frame.bg:SetColorTexture(c.r, c.g, c.b, c.a or 0.9)
        end

        OrbitEngine.Pixel:Enforce(Frame)
        OrbitEngine.Pixel:Enforce(Frame.StatusBar)

        Frame.Spacers = {}
        for i = 1, MAX_SPACER_COUNT do
            Frame.Spacers[i] = Frame.StatusBar:CreateTexture(nil, "OVERLAY", nil, 7)
            Frame.Spacers[i]:SetColorTexture(0, 0, 0, 1)
            Frame.Spacers[i]:Hide()
        end
    end

    -- Tick mark (geometry-clipped, secret-safe)
    if not Frame.TickBar then
        OrbitEngine.TickMixin:Create(Frame, Frame.StatusBar)
    end

    Frame:HookScript("OnSizeChanged", function()
        Orbit.Async:Debounce("PlayerResources_SpacerLayout", function()
            if Frame.maxPower then Plugin:RepositionSpacers(Frame.maxPower) end
        end, 0.05)
    end)



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

    self:RefreshFrequentUpdates()

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
        elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT") and unit == "player" then
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
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, SYSTEM_INDEX, "Text"),
        })
    end

    self:UpdatePowerType()
    self:UpdatePower()
end

function Plugin:RefreshFrequentUpdates()
    if not Frame then return end
    if self:GetSetting(SYSTEM_INDEX, "FrequentUpdates") then
        Frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    else
        Frame:UnregisterEvent("UNIT_POWER_FREQUENT")
    end
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
    DiscreteRenderer:UpdateLayout(Frame)

    -- Apply Visuals to Single Bar Container
    if Frame.StatusBarContainer and Frame.StatusBarContainer:IsShown() then
        local bgColor = self:GetSetting(SYSTEM_INDEX, "BackdropColour")
        if not bgColor and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BackdropColourCurve then
            bgColor = OrbitEngine.ColorCurve:GetFirstColorFromCurve(Orbit.db.GlobalSettings.BackdropColourCurve)
        end

        Orbit.Skin:SkinStatusBar(Frame.StatusBar, texture, nil, true)
        Frame:SetBorder(borderSize)
        Orbit.Skin:ApplyGradientBackground(Frame, Orbit.db.GlobalSettings.BackdropColourCurve, bgColor or Orbit.Constants.Colors.Background)
    end

    local tickSize = self:GetSetting(SYSTEM_INDEX, "TickSize") or TICK_SIZE_DEFAULT
    OrbitEngine.TickMixin:Apply(Frame, tickSize, height)

    -- 2. Restore Position (must happen AFTER layout for anchored frames)
    OrbitEngine.Frame:RestorePosition(Frame, self, SYSTEM_INDEX)

    -- Restore component positions (Canvas Mode)
    local savedPositions = self:GetSetting(SYSTEM_INDEX, "ComponentPositions")
    if savedPositions and OrbitEngine.ComponentDrag then
        OrbitEngine.ComponentDrag:RestoreFramePositions(Frame, savedPositions)
    end

    -- 3. Update Visuals (Skinning Buttons)
    DiscreteRenderer:ApplyButtonVisuals(self, Frame, SYSTEM_INDEX)

    -- 4. Update Power (Refresh Logic & Spacer Positions)
    self:UpdatePower()

    -- 5. Apply Out of Combat Fade (with hover detection based on setting)
    local enableHover = self:GetSetting(SYSTEM_INDEX, "ShowOnMouseover") ~= false
    Orbit.OOCFadeMixin:ApplyOOCFade(Frame, self, SYSTEM_INDEX, "OutOfCombatFade", enableHover)
end

-- [ RESOURCE COLOR (DELEGATE) ]---------------------------------------------------------------------
function Plugin:GetResourceColor(index, maxResources, isCharged)
    return DiscreteRenderer:GetResourceColor(self, SYSTEM_INDEX, index, maxResources, isCharged)
end

function Plugin:IsEnabled()
    if Orbit.IsPluginEnabled and not Orbit:IsPluginEnabled("Player Frame") then return true end
    local enabled = Orbit:ReadPluginSetting("Orbit_PlayerFrame", Enum.EditModeUnitFrameSystemIndices.Player, "EnablePlayerResource")
    return enabled == nil or enabled == true
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

        local cfg = CONTINUOUS_RESOURCE_CONFIG[continuousResource]
        Frame.maxPower = (cfg and cfg.maxDividers) or 0

        ContinuousRenderer:SetContinuousMode(Frame, true)
        Frame:SetScript("OnUpdate", Frame.onUpdateHandler)
        Frame.orbitDisabled = false
        Frame:Show()
        self:ApplySettings()
        return
    end

    -- Otherwise, check for discrete resources
    self.continuousResource = nil
    ContinuousRenderer:SetContinuousMode(Frame, false)

    local powerType, powerTypeName = ResourceMixin:GetResourceForPlayer()

    self.powerType = powerType
    self.powerTypeName = powerTypeName

    if self.powerType then
        Frame:Show()
        Frame.orbitDisabled = false
        local needsOnUpdate = (self.powerType == Enum.PowerType.Runes or self.powerType == Enum.PowerType.Essence)
        Frame:SetScript("OnUpdate", needsOnUpdate and Frame.onUpdateHandler or nil)
        DiscreteRenderer:UpdateMaxPower(self, Frame, SYSTEM_INDEX)
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

-- [ SPACER REPOSITIONING ]-------------------------------------------------------------------------
function Plugin:RepositionSpacers(max, edges)
    if not Frame or not Frame.Spacers then return end

    local spacerWidth = (Frame.settings and Frame.settings.spacing) or 0
    if not max or max <= 1 or spacerWidth <= 0 then
        for _, s in ipairs(Frame.Spacers) do s:Hide() end
        return
    end

    local scale = Frame:GetEffectiveScale()
    if not scale or scale < 0.01 then scale = 1 end

    local totalWidth = Frame:GetWidth()
    if totalWidth < 10 then totalWidth = (Frame.settings and Frame.settings.width) or 200 end

    local logicalGap = PixelMultiple(spacerWidth, scale)
    local exactWidth = (totalWidth - (logicalGap * (max - 1))) / max
    local snappedWidth = SnapToPixel(exactWidth, scale)

    local currentLeft = 0
    local edges = {}
    for i = 1, max - 1 do
        currentLeft = currentLeft + snappedWidth
        edges[i] = SnapToPixel(currentLeft, scale)
        currentLeft = currentLeft + logicalGap
    end

    for i = 1, MAX_SPACER_COUNT do
        local sp = Frame.Spacers[i]
        if sp then
            if i < max and edges[i] then
                sp:Show()
                sp:ClearAllPoints()
                sp:SetSize(logicalGap, Frame:GetHeight())
                -- Draw the overlay exactly at the mathematically perfect left border map:
                sp:SetPoint("LEFT", Frame, "LEFT", edges[i], 0)
                OrbitEngine.Pixel:Enforce(sp)
            else
                sp:Hide()
            end
        end
    end
end

function Plugin:UpdatePower()
    if not Frame then return end
    local textEnabled = not OrbitEngine.ComponentDrag:IsDisabled(Frame.Text)
    if self.continuousResource then
        ContinuousRenderer:UpdatePower(self, Frame, SYSTEM_INDEX, textEnabled)
    else
        DiscreteRenderer:UpdatePower(self, Frame, SYSTEM_INDEX, textEnabled)
    end
end
