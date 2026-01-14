local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local ResourceMixin = Orbit.ResourceBarMixin

-- Compatibility for 12.0 / Native Smoothing
local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function SafeUnitPowerPercent(unit, resource)
    if type(UnitPowerPercent) == "function" then
        local ok, pct
        if CurveConstants and CurveConstants.ScaleTo100 then
            ok, pct = pcall(UnitPowerPercent, unit, resource, false, CurveConstants.ScaleTo100)
        else
            ok, pct = pcall(UnitPowerPercent, unit, resource, false, true)
        end

        if not ok or pct == nil then
            ok, pct = pcall(UnitPowerPercent, unit, resource, false)
        end

        if ok and pct ~= nil then
            return pct
        end
    end

    if UnitPower and UnitPowerMax then
        local cur = UnitPower(unit, resource)
        local max = UnitPowerMax(unit, resource)
        if cur and max and max > 0 then
            return (cur / max) * 100
        end
    end
    return nil
end

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerResources"
local SYSTEM_INDEX = 1

local Plugin = Orbit:RegisterPlugin("Player Resources", SYSTEM_ID, {
    defaults = {
        Hidden = false,
        Width = Orbit.Constants.PlayerResources.DefaultWidth,
        Height = Orbit.Constants.PlayerResources.DefaultHeight,
        ShowText = true,
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

-- Frame reference (created in OnLoad)
local Frame

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    if not Frame then
        return
    end

    local systemIndex = SYSTEM_INDEX
    local WL = OrbitEngine.WidgetLogic

    if dialog.Title then
        dialog.Title:SetText("Player Resources")
    end

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil

    -- Linked Visibility (Managed by Player Frame)
    -- "Hidden" checkbox removed in favor of Player Frame > Enable Player Resource

    -- Width (only when not anchored)
    if not isAnchored then
        WL:AddSizeSettings(
            self,
            schema,
            systemIndex,
            systemFrame,
            { default = Orbit.Constants.PlayerResources.DefaultWidth },
            nil,
            nil
        )
    end

    -- Height
    WL:AddSizeSettings(
        self,
        schema,
        systemIndex,
        systemFrame,
        nil,
        { min = 5, max = 20, default = Orbit.Constants.PlayerResources.DefaultHeight },
        nil
    )

    -- Show Text
    table.insert(schema.controls, {
        type = "checkbox",
        key = "ShowText",
        label = "Show Text",
        default = true,
        onChange = function(val)
            self:SetSetting(systemIndex, "ShowText", val)
            self:ApplySettings()
            if OrbitEngine.Frame and OrbitEngine.Frame.ForceUpdateSelection then
                OrbitEngine.Frame:ForceUpdateSelection(Frame)
            end
        end,
    })

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Register standard events (Handle PEW, EditMode -> ApplySettings)
    self:RegisterStandardEvents()

    -- Create frame ONLY when plugin is enabled (OnLoad is only called for enabled plugins)
    Frame = OrbitEngine.FrameFactory:CreateButtonContainer("PlayerResources", self, {
        width = Orbit.Constants.PlayerResources.DefaultWidth,
        height = Orbit.Constants.PlayerResources.DefaultHeight,
        y = Orbit.Constants.PlayerResources.DefaultY,
        systemIndex = SYSTEM_INDEX,
        anchorOptions = { horizontal = false, vertical = true, mergeBorders = true }, -- Vertical stacking only
    })

    -- Text overlay (must be on a high frame level to be above buttons)
    if not Frame.Overlay then
        Frame.Overlay = CreateFrame("Frame", nil, Frame)
        Frame.Overlay:SetAllPoints()
        Frame.Overlay:SetFrameLevel(Frame:GetFrameLevel() + 20)
    end

    OrbitEngine.FrameFactory:AddText(
        Frame,
        { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = -2, useOverlay = true }
    )
    if Frame.Text then
        Frame.Text:SetParent(Frame.Overlay)
    end

    -- Create StatusBar container for continuous resources (Stagger, Soul Fragments, Ebon Might)
    if not Frame.StatusBarContainer then
        -- Container with backdrop for border
        Frame.StatusBarContainer = CreateFrame("Frame", nil, Frame, "BackdropTemplate")
        Frame.StatusBarContainer:SetAllPoints()
        Frame.StatusBarContainer:Hide()

        -- Background
        local bg = Frame.StatusBarContainer:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()

        local color = self:GetSetting(SYSTEM_INDEX, "BackdropColour")
        if color then
            bg:SetColorTexture(color.r, color.g, color.b, color.a or 0.9)
        else
            local c = Orbit.Colors.Background
            bg:SetColorTexture(c.r, c.g, c.b, c.a or 0.9)
        end
        Frame.StatusBarContainer.bg = bg

        -- StatusBar itself
        Frame.StatusBar = CreateFrame("StatusBar", nil, Frame.StatusBarContainer)
        Frame.StatusBar:SetPoint("TOPLEFT", 1, -1)
        Frame.StatusBar:SetPoint("BOTTOMRIGHT", -1, 1)
        Frame.StatusBar:SetMinMaxValues(0, 1)
        Frame.StatusBar:SetValue(0)
        Frame.StatusBar:SetStatusBarTexture(LSM:Fetch("statusbar", "Melli"))

        -- Add SetBorder helper to container
        Frame.StatusBarContainer.SetBorder = function(self, size)
            -- Use Pixel Engine
            local pixelScale = (Orbit.Engine.Pixel and Orbit.Engine.Pixel:GetScale())
                or (768.0 / (select(2, GetPhysicalScreenSize()) or 768.0))

            local scale = self:GetEffectiveScale()
            if not scale or scale < 0.01 then
                scale = 1
            end

            local mult = pixelScale / scale
            local pixelSize = (size or 1) * mult

            -- Create borders if needed
            if not self.Borders then
                self.Borders = {}
                local function CreateLine()
                    local t = self:CreateTexture(nil, "BORDER")
                    t:SetColorTexture(0, 0, 0, 1)
                    return t
                end
                self.Borders.Top = CreateLine()
                self.Borders.Bottom = CreateLine()
                self.Borders.Left = CreateLine()
                self.Borders.Right = CreateLine()
            end

            local b = self.Borders

            -- Non-overlapping Layout
            -- Top/Bottom: Full Width
            b.Top:ClearAllPoints()
            b.Top:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
            b.Top:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
            b.Top:SetHeight(pixelSize)

            b.Bottom:ClearAllPoints()
            b.Bottom:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
            b.Bottom:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
            b.Bottom:SetHeight(pixelSize)

            -- Left/Right: Inset by Top/Bottom height
            b.Left:ClearAllPoints()
            b.Left:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -pixelSize)
            b.Left:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, pixelSize)
            b.Left:SetWidth(pixelSize)

            b.Right:ClearAllPoints()
            b.Right:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -pixelSize)
            b.Right:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, pixelSize)
            b.Right:SetWidth(pixelSize)

            -- Inset the StatusBar
            Frame.StatusBar:ClearAllPoints()
            Frame.StatusBar:SetPoint("TOPLEFT", pixelSize, -pixelSize)
            Frame.StatusBar:SetPoint("BOTTOMRIGHT", -pixelSize, pixelSize)
        end

        -- Apply default border
        Frame.StatusBarContainer:SetBorder(1)
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
    -- Note: PLAYER_ENTERING_WORLD handled by StandardEvents, but we keep the debounce init for power logic
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Frame:RegisterEvent("UNIT_POWER_UPDATE")
    Frame:RegisterEvent("UNIT_MAXPOWER")
    Frame:RegisterEvent("UNIT_DISPLAYPOWER")
    Frame:RegisterEvent("RUNE_POWER_UPDATE")
    Frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    Frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
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
        elseif
            event == "UNIT_DISPLAYPOWER"
            or event == "UPDATE_SHAPESHIFT_FORM"
            or event == "PLAYER_SPECIALIZATION_CHANGED"
        then
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
            if self.continuousResource == "STAGGER" then
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

    self:UpdatePowerType()
    self:UpdatePower()
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    if not Frame then
        return
    end

    local systemIndex = SYSTEM_INDEX

    -- Visibility
    local hidden = self:GetSetting(systemIndex, "Hidden")
    local isEditMode = EditModeManagerFrame
        and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive()

    if hidden and not isEditMode then
        Frame:Hide()
        return
    end
    Frame:Show()

    -- Get settings (defaults handled by PluginMixin)
    local width = self:GetSetting(systemIndex, "Width")
    local height = self:GetSetting(systemIndex, "Height")
    local borderSize = self:GetSetting(systemIndex, "BorderSize")
    local spacing = borderSize or 1
    local texture = self:GetSetting(systemIndex, "Texture")
    local fontName = self:GetSetting(systemIndex, "Font")
    local showText = self:GetSetting(systemIndex, "ShowText")

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
    -- Font & Text
    local fontPath = LSM:Fetch("font", fontName)

    if showText ~= false then
        Frame.Text:Show()
        local textSize = Orbit.Skin:GetAdaptiveTextSize(height, 18, 26, 1)
        Frame.Text:SetFont(fontPath, textSize, "OUTLINE")

        Frame.Text:ClearAllPoints()
        if height > textSize then
            Frame.Text:SetPoint("CENTER", Frame.Overlay, "CENTER", 0, 0)
        else
            Frame.Text:SetPoint("BOTTOM", Frame.Overlay, "BOTTOM", 0, -2)
        end
    else
        Frame.Text:Hide()
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

    -- [ NEW ] Apply Visuals to Single Bar Container
    if Frame.StatusBarContainer and Frame.StatusBarContainer:IsShown() then
        Orbit.Skin:SkinStatusBar(Frame.StatusBar, texture)
        Frame.StatusBarContainer:SetBorder(borderSize)
    end

    -- 2. Restore Position (must happen AFTER layout for anchored frames)
    OrbitEngine.Frame:RestorePosition(Frame, self, systemIndex)

    -- 3. Update Visuals (Skinning Buttons)
    self:ApplyButtonVisuals()

    -- 4. Update Power (Refresh Logic & Spacer Positions)
    self:UpdatePower()
end

-- [ BUTTON VISUAL APPLICATION ]---------------------------------------------------------------------
function Plugin:ApplyButtonVisuals()
    if not Frame or not Frame.buttons then
        return
    end

    local borderSize = self:GetSetting(SYSTEM_INDEX, "BorderSize")
    local texture = self:GetSetting(SYSTEM_INDEX, "Texture")

    local _, class = UnitClass("player")
    local color = self:GetResourceColor()

    -- Determine visual max (count of active buttons)
    local max = Frame.maxPower or #Frame.buttons
    if max < 1 then
        max = 1
    end

    for i, btn in ipairs(Frame.buttons) do
        if btn:IsShown() then
            if Orbit.Skin.ClassBar then
                Orbit.Skin.ClassBar:SkinButton(btn, {
                    borderSize = borderSize,
                    texture = texture,
                })
            end

            if color and btn.orbitBar then
                btn.orbitBar:SetVertexColor(color.r, color.g, color.b)

                -- Continuous Texture Mapping (Atlas Effect)
                -- Map the texture 0..1 across the buttons 1..max
                -- Button i gets slice: (i-1)/max to i/max
                if i <= max then
                    local minU = (i - 1) / max
                    local maxU = i / max
                    btn.orbitBar:SetTexCoord(minU, maxU, 0, 1)
                end

                -- Ensure overlay exists on the filled bar (btn.orbitBar is a Texture, not StatusBar)
                -- We treat the button frame as the container and anchor overlay to orbitBar
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
            local barColor = { r = color.r * 0.5, g = color.g * 0.5, b = color.b * 0.5 }
            Orbit.Skin:SkinStatusBar(btn.progressBar, texture, barColor)
        end
    end
end

-- [ RESOURCE COLOR HELPER ]-------------------------------------------------------------------------
function Plugin:GetResourceColor(index, isCharged)
    local _, class = UnitClass("player")
    local colors = Orbit.Colors.PlayerResources

    -- Charged combo point
    if isCharged then
        return colors.ChargedComboPoint or colors[class]
    end

    -- Death Knight rune colors by spec
    if class == "DEATHKNIGHT" then
        local spec = GetSpecialization()
        local specID = spec and GetSpecializationInfo(spec)
        if specID == 250 then
            return colors.RuneBlood or colors[class]
        elseif specID == 251 then
            return colors.RuneFrost or colors[class]
        elseif specID == 252 then
            return colors.RuneUnholy or colors[class]
        end
    end

    return colors[class] or { r = 1, g = 1, b = 1 }
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Plugin:IsEnabled()
    -- Read EnablePlayerResource setting from PlayerFrame plugin
    local playerPlugin = Orbit:GetPlugin("Orbit_PlayerFrame")
    local pfIndex = (Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Player) or 1

    if playerPlugin and playerPlugin.GetSetting then
        local enabled = playerPlugin:GetSetting(pfIndex, "EnablePlayerResource")
        if enabled == nil then
            return true
        end
        return enabled == true
    end

    -- Fallback to DB check if plugin not ready? Match PlayerPower logic which relies on Plugin availability
    return true
end

function Plugin:UpdateVisibility()
    if not Frame then
        return
    end

    local enabled = self:IsEnabled()
    local isEditMode = EditModeManagerFrame
        and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive()

    if not enabled then
        Frame:Hide()
        Frame.orbitDisabled = true
        return
    end

    Frame.orbitDisabled = false
    -- If enabled, we delegate to UpdatePowerType to decide if we valid resources to show
    self:UpdatePowerType()

    -- If UpdatePowerType decided we should show, ensure we are shown
    -- UpdatePowerType handles the :Show() / :Hide() based on resource availability
end

-- [ POWER LOGIC ]----------------------------------------------------------------------------------
function Plugin:UpdatePowerType()
    if not Frame then
        return
    end

    -- If disabled globally via setting, stay hidden (Double check, though UpdateVisibility handles entry)
    if not self:IsEnabled() then
        Frame:Hide()
        return
    end

    -- Hide in Pet Battle
    if C_PetBattles and C_PetBattles.IsInBattle() then
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

-- [ CONTINUOUS/DISCRETE MODE SWITCHING ]------------------------------------------------------------
function Plugin:SetContinuousMode(isContinuous)
    if not Frame then
        return
    end

    if isContinuous then
        -- Show StatusBar container, hide discrete buttons
        if Frame.StatusBarContainer then
            Frame.StatusBarContainer:Show()

            -- Apply texture
            -- Apply texture
            local texture = self:GetSetting(SYSTEM_INDEX, "Texture")
            Orbit.Skin:SkinStatusBar(Frame.StatusBar, texture)

            -- Apply border
            local borderSize = self:GetSetting(SYSTEM_INDEX, "BorderSize") or 1
            Frame.StatusBarContainer:SetBorder(borderSize)
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

    local max
    if self.powerType == Enum.PowerType.Runes then
        max = 6 -- Runes are always 6
    else
        max = UnitPowerMax("player", self.powerType)
    end

    Frame.maxPower = max

    -- [ SINGLE BAR SETUP ] -----------------------------------------------------------------------------
    -- Ensure we have the main status bar for single-bar mode (shared with continuous)
    if not Frame.StatusBar then
        Frame.StatusBarContainer = CreateFrame("Frame", nil, Frame, "BackdropTemplate")
        Frame.StatusBarContainer:SetAllPoints()

        Frame.StatusBar = CreateFrame("StatusBar", nil, Frame.StatusBarContainer)
        Frame.StatusBar:SetAllPoints()
        Frame.StatusBar:SetMinMaxValues(0, 1)
        Frame.StatusBar:SetValue(0)
    end

    -- Ensure we have Spacers (Up to 10)
    if not Frame.Spacers then
        Frame.Spacers = {}
    end
    for i = 1, 10 do
        if not Frame.Spacers[i] then
            local sp = Frame.StatusBar:CreateTexture(nil, "OVERLAY", nil, 7)
            sp:SetColorTexture(0, 0, 0, 1)
            Frame.Spacers[i] = sp
        end
        Frame.Spacers[i]:Hide()
    end

    -- [ MULTI BAR BUTTONS ] ----------------------------------------------------------------------------
    if not Frame.buttons then
        Frame.buttons = {}
    end

    -- Create buttons as needed
    for i = 1, max do
        if not Frame.buttons[i] then
            local btn = CreateFrame("Frame", nil, Frame)
            btn:SetScript("OnEnter", function() end)
            Frame.buttons[i] = btn

            btn.SetActive = function(self, active)
                self.isActive = active
                if self.orbitBar then
                    if active then
                        self.orbitBar:Show()
                        if self.Overlay then
                            self.Overlay:Show()
                        end
                    else
                        self.orbitBar:Hide()
                        if self.Overlay then
                            self.Overlay:Hide()
                        end
                    end
                end
            end

            btn.SetFraction = function(self, fraction)
                if self.progressBar then
                    if fraction > 0 and fraction < 1 then
                        self.progressBar:SetValue(fraction, SMOOTH_ANIM)
                        self.progressBar:Show()
                    else
                        self.progressBar:Hide()
                    end
                end
            end
        end
        -- Visibility managed by UpdatePower
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
    local totalSpacing = (max - 1) * spacing
    local btnWidth = (totalWidth - totalSpacing) / max

    -- Physical Updates
    Frame:SetHeight(height)

    for i = 1, max do
        local btn = buttons[i]
        if btn then
            btn:SetSize(btnWidth, height)
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("LEFT", Frame, "LEFT", 0, 0)
            else
                btn:SetPoint("LEFT", buttons[i - 1], "RIGHT", spacing, 0)
            end
        end
    end
end

function Plugin:UpdatePower()
    if not Frame then
        return
    end

    local showText = self:GetSetting(SYSTEM_INDEX, "ShowText")
    local colors = Orbit.Colors.PlayerResources

    -- [ CONTINUOUS RESOURCES ]--------------------------------------------------------------------------
    if self.continuousResource then
        -- ----------------------------------------
        -- STAGGER (Brewmaster Monk)
        -- ----------------------------------------
        if self.continuousResource == "STAGGER" then
            local stagger, maxHealth, percent, level = ResourceMixin:GetStaggerState()

            if Frame.StatusBar then
                Frame.StatusBar:SetMinMaxValues(0, maxHealth)
                Frame.StatusBar:SetValue(stagger, SMOOTH_ANIM)

                -- Dynamic color based on stagger level
                local color = colors["Stagger" .. level:sub(1, 1) .. level:sub(2):lower()] or colors.StaggerLow
                Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
            end

            if Frame.Text and showText then
                Frame.Text:SetFormattedText("%.0f", percent)
            end
            return
        end

        -- ----------------------------------------
        -- SOUL FRAGMENTS (Demon Hunter)
        -- ----------------------------------------
        if self.continuousResource == "SOUL_FRAGMENTS" then
            local current, max, isVoidMeta = ResourceMixin:GetSoulFragmentsState()

            if current and max and Frame.StatusBar then
                Frame.StatusBar:SetMinMaxValues(0, max)
                Frame.StatusBar:SetValue(current, SMOOTH_ANIM)

                local color = isVoidMeta and colors.SoulFragmentsVoidMeta or colors.SoulFragments
                Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b)

                if Frame.Text and showText then
                    Frame.Text:SetText(current)
                end
            elseif Frame.StatusBar then
                -- Native bar not available, hide
                Frame.StatusBar:SetValue(0)
            end
            return
        end

        -- ----------------------------------------
        -- EBON MIGHT (Augmentation Evoker)
        -- ----------------------------------------
        if self.continuousResource == "EBON_MIGHT" then
            local current, max = ResourceMixin:GetEbonMightState()

            if current and max and Frame.StatusBar then
                Frame.StatusBar:SetMinMaxValues(0, max)
                Frame.StatusBar:SetValue(current, SMOOTH_ANIM)

                local color = colors.EbonMight
                Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b)

                if Frame.Text and showText then
                    Frame.Text:SetFormattedText("%.0f", current)
                end
            elseif Frame.StatusBar then
                -- Native bar not available, hide
                Frame.StatusBar:SetValue(0)
            end
            return
        end

        -- ----------------------------------------
        -- MANA (Shadow Priest, Ele/Enh Shaman, Balance Druid)
        -- ----------------------------------------
        if self.continuousResource == "MANA" then
            local current = UnitPower("player", Enum.PowerType.Mana)
            local max = UnitPowerMax("player", Enum.PowerType.Mana)

            if Frame.StatusBar then
                Frame.StatusBar:SetMinMaxValues(0, max)
                Frame.StatusBar:SetValue(current, SMOOTH_ANIM)

                -- Use standard Mana color
                local color = { r = 0.0, g = 0.5, b = 1.0 } -- Default Orbit/WoW Blue
                if Orbit.Colors.Power and Orbit.Colors.Power.Mana then
                    color = Orbit.Colors.Power.Mana
                end

                Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
            end

            if Frame.Text and showText then
                local percent = SafeUnitPowerPercent("player", Enum.PowerType.Mana)
                if percent then
                    Frame.Text:SetFormattedText("%.0f", percent)
                else
                    Frame.Text:SetText(current)
                end
            end
            return
        end

        return -- Unknown continuous resource
    end

    -- [ DISCRETE RESOURCES ]----------------------------------------------------------------------------
    if not self.powerType then
        return
    end

    -- [ RUNES ]-----------------------------------------------------------------------------------------
    if self.powerType == Enum.PowerType.Runes then
        -- Cleanup Single Bar elements
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
        local color = self:GetResourceColor()

        for pos, runeData in ipairs(sortedRunes) do
            local btn = Frame.buttons[pos]
            if btn then
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

    -- [ ESSENCE ]---------------------------------------------------------------------------------------
    if self.powerType == Enum.PowerType.Essence then
        -- Cleanup Single Bar elements
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
        local color = self:GetResourceColor()

        for i = 1, max do
            local btn = Frame.buttons[i]
            if btn then
                local state, remaining, fraction = ResourceMixin:GetEssenceState(i, current, max)

                if state == "full" then
                    btn:SetActive(true)
                    btn:SetFraction(0)

                    if btn.orbitBar then
                        btn.orbitBar:SetVertexColor(color.r, color.g, color.b)
                    end
                elseif state == "partial" then
                    btn:SetActive(false)
                    btn:SetFraction(fraction)

                    if btn.progressBar then
                        btn.progressBar:SetStatusBarColor(color.r * 0.5, color.g * 0.5, color.b * 0.5)
                    end
                else
                    btn:SetActive(false)
                    btn:SetFraction(0)
                end
            end
        end

        if Frame.Text and Frame.Text:IsShown() then
            Frame.Text:SetText(current)
        end
        return
    end

    -- [ SINGLE BAR DISCRETE RESOURCES (Combo Points, Shards, Holy, etc) ]-----------------------------
    -- Switch to Single Bar Mode
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

    -- Normalize Logic:
    -- UnitPower(..., true) returns raw precision values (e.g. 30 for 3 shards).
    -- UnitPowerMax(...) usually returns logical max (e.g. 5).
    -- We need to scale cur down to logical range for the bar (0..5) and text.

    local mod = UnitPowerDisplayMod(self.powerType)
    if mod and mod > 0 then
        cur = cur / mod
    end

    -- Handle Combo Points Charged State (Coloring)
    -- If we have charged points, use the charged color for the whole bar
    local color = self:GetResourceColor()
    if self.powerType == Enum.PowerType.ComboPoints then
        local chargedPoints = GetUnitChargedPowerPoints("player")
        if chargedPoints and #chargedPoints > 0 then
            color = self:GetResourceColor(nil, true)
        end
    end

    if Frame.StatusBar then
        Frame.StatusBar:SetMinMaxValues(0, Frame.maxPower or 5)
        Frame.StatusBar:SetValue(cur, SMOOTH_ANIM)
        if color then
            Frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b)
        end
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
        return math.floor(value * scale + 0.5) / scale
    end

    -- Calculate segment width (simple division of total width)
    local btnWidth = totalWidth / max
    local snappedSpacerWidth = SnapToPixel(spacerWidth)

    if Frame.Spacers then
        for i = 1, 10 do
            local sp = Frame.Spacers[i]
            if sp then
                if i < max then
                    sp:Show()
                    sp:ClearAllPoints()
                    sp:SetWidth(snappedSpacerWidth)
                    sp:SetHeight(Frame:GetHeight())

                    -- Position: Snap to exact pixel boundary based on percentage
                    -- We center the spacer on the boundary to overlap nicely with the fill
                    local centerPos = i * btnWidth
                    local xPos = SnapToPixel(centerPos - (spacerWidth / 2))

                    sp:SetPoint("LEFT", Frame, "LEFT", xPos, 0)
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
