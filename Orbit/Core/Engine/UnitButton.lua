-- [ UNIT BUTTON ]-----------------------------------------------------------------------------------
-- Main entry point for UnitButton system
-- Composes modular mixins and provides Create factory function
--
-- Architecture:
-- - Sub-modules export partial mixins to Engine.UnitButton namespace
-- - This file combines them into UnitButtonMixin and provides Create factory
-- - Sub-modules are loaded first via TOC file order
--
-- Sub-modules (in Core/Engine/UnitButton/):
-- - UnitButtonCore.lua    - Lifecycle: OnLoad, OnEvent, UpdateAll
-- - UnitButtonHealth.lua  - Health bar updates and coloring  
-- - UnitButtonText.lua    - HealthText and Name text formatting
-- - UnitButtonPrediction.lua - Heal prediction and absorbs
-- - UnitButtonCanvas.lua  - Canvas Mode component positions

local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- Compatibility for 12.0 / Native Smoothing
local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

-- [ COMPOSE MIXIN ]---------------------------------------------------------------------------------
-- Combine all sub-mixins into the main UnitButtonMixin

local UnitButtonMixin = {}

-- Compose from sub-modules (loaded before this file via TOC)
if UnitButton.CoreMixin then
    Mixin(UnitButtonMixin, UnitButton.CoreMixin)
end
if UnitButton.HealthMixin then
    Mixin(UnitButtonMixin, UnitButton.HealthMixin)
end
if UnitButton.TextMixin then
    Mixin(UnitButtonMixin, UnitButton.TextMixin)
end
if UnitButton.PredictionMixin then
    Mixin(UnitButtonMixin, UnitButton.PredictionMixin)
end
if UnitButton.CanvasMixin then
    Mixin(UnitButtonMixin, UnitButton.CanvasMixin)
end

-- Export composed mixin
UnitButton.Mixin = UnitButtonMixin

-- [ FACTORY ]----------------------------------------------------------------------------------------
-- Create a new UnitButton frame

function UnitButton:Create(parent, unit, name)
    local f = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate,BackdropTemplate")

    -- Enforce Pixel Perfection on Sizing
    if Engine.Pixel then
        Engine.Pixel:Enforce(f)
    end
    f:SetClampedToScreen(true) -- Prevent dragging off-screen

    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")

    f.unit = unit

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    local bg = Orbit.Constants.Colors.Background
    f.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)

    -- Damage Bar (Red) - Behind the Health bar, shows "damage taken" chunk
    -- NOTE: Initial insets are 0. Consuming plugins MUST call frame:SetBorder(size) to apply proper insets.
    f.HealthDamageBar = CreateFrame("StatusBar", nil, f)
    f.HealthDamageBar:SetPoint("TOPLEFT", 0, 0)
    f.HealthDamageBar:SetPoint("BOTTOMRIGHT", 0, 0)
    f.HealthDamageBar:SetMinMaxValues(0, 1)
    f.HealthDamageBar:SetValue(1)
    f.HealthDamageBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    f.HealthDamageBar:SetStatusBarColor(0.8, 0.1, 0.1, 0.4) -- Dark Red, Reduced Opacity
    f.HealthDamageBar:SetFrameLevel(f:GetFrameLevel() + 1) -- Behind Health

    -- Animation state for smooth interpolation
    f.damageBarTarget = 0
    f.damageBarAnimating = false

    -- NOTE: Initial insets are 0. Consuming plugins MUST call frame:SetBorder(size) to apply proper insets.
    f.Health = CreateFrame("StatusBar", nil, f)
    f.Health:SetPoint("TOPLEFT", 0, 0)
    f.Health:SetPoint("BOTTOMRIGHT", 0, 0)
    f.Health:SetMinMaxValues(0, 1)
    f.Health:SetValue(1)
    f.Health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    f.Health:SetStatusBarColor(0, 1, 0)
    f.Health:SetClipsChildren(true) -- Clip children to prevent heal absorb shadow leaks at 0 value
    f.Health:SetFrameLevel(f:GetFrameLevel() + 2) -- Above DamageBar

    -- Apply Overlay
    local overlayPath = "Interface\\AddOns\\Orbit\\Core\\assets\\Statusbar\\orbit-left-right.tga"
    Orbit.Skin:AddOverlay(f.Health, overlayPath, "BLEND", 0.3)

    -----------------------------------------------------------------------
    -- Incoming Heals (Hidden by default)
    -----------------------------------------------------------------------

    -- 1. My Incoming Heal
    f.MyIncomingHealBar = CreateFrame("StatusBar", nil, f.Health)
    f.MyIncomingHealBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    f.MyIncomingHealBar:SetStatusBarColor(0.66, 1, 0.66, 0.6) -- Light Green, semi-transparent
    f.MyIncomingHealBar:SetMinMaxValues(0, 1)
    f.MyIncomingHealBar:SetValue(0)
    -- Same level as health, drawn after/next to it.
    f.MyIncomingHealBar:SetFrameLevel(f.Health:GetFrameLevel())
    f.MyIncomingHealBar:Hide()

    -- 2. Other Incoming Heal
    f.OtherIncomingHealBar = CreateFrame("StatusBar", nil, f.Health)
    f.OtherIncomingHealBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    f.OtherIncomingHealBar:SetStatusBarColor(0.66, 1, 0.66, 0.6) -- Light Green
    f.OtherIncomingHealBar:SetMinMaxValues(0, 1)
    f.OtherIncomingHealBar:SetValue(0)
    f.OtherIncomingHealBar:SetFrameLevel(f.Health:GetFrameLevel())
    f.OtherIncomingHealBar:Hide()

    -----------------------------------------------------------------------
    -- Total Absorbs (Shields) - Replaces AbsorbOverlay
    -----------------------------------------------------------------------
    f.TotalAbsorbBar = CreateFrame("StatusBar", nil, f.Health)
    -- Use a solid texture for the bar itself, and the pattern for the overlay.
    f.TotalAbsorbBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    -- Magic Blue color for the shield (Whitey/Pale Blue)
    f.TotalAbsorbBar:SetStatusBarColor(0.5, 0.8, 1.0, 0.35)
    f.TotalAbsorbBar:SetMinMaxValues(0, 1)
    f.TotalAbsorbBar:SetValue(0)
    f.TotalAbsorbBar:SetFrameLevel(f.Health:GetFrameLevel()) -- Same level
    f.TotalAbsorbBar:Hide()

    -- Shield Overlay Pattern
    f.TotalAbsorbOverlay = f.TotalAbsorbBar:CreateTexture(nil, "OVERLAY")
    f.TotalAbsorbOverlay:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
    f.TotalAbsorbOverlay:SetAllPoints(f.TotalAbsorbBar)
    f.TotalAbsorbOverlay:SetHorizTile(true)
    f.TotalAbsorbOverlay:SetVertTile(true)
    f.TotalAbsorbOverlay:SetBlendMode("ADD")
    f.TotalAbsorbOverlay:SetVertexColor(0.7, 0.9, 1.0, 1.0) -- Pale blue tint for overlay

    -----------------------------------------------------------------------
    -- Heal Absorbs (Necrotic) - "HealMe" Pattern
    -----------------------------------------------------------------------
    f.HealAbsorbBar = CreateFrame("StatusBar", nil, f.Health)
    f.HealAbsorbBar:SetReverseFill(true)
    -- Anchors set in Update function

    -- 1. Base Layer
    local healthTexture = f.Health:GetStatusBarTexture():GetTexture()
    f.HealAbsorbBar:SetStatusBarTexture(healthTexture or "Interface\\Buttons\\WHITE8x8")
    local c = Orbit.Constants.Colors.Background
    f.HealAbsorbBar:SetStatusBarColor(c.r, c.g, c.b, c.a) -- Matches PlayerResources Backdrop
    f.HealAbsorbBar:SetMinMaxValues(0, 1)
    f.HealAbsorbBar:SetValue(0)
    f.HealAbsorbBar:SetFrameLevel(f.Health:GetFrameLevel() + 2) -- Higher than health to overlay it
    f.HealAbsorbBar:Hide()

    -- 2. Overlay Layer (Mask + Pattern)
    f.HealAbsorbMask = CreateFrame("Frame", nil, f.HealAbsorbBar)
    f.HealAbsorbMask:SetClipsChildren(true)
    f.HealAbsorbMask:SetFrameLevel(f.HealAbsorbBar:GetFrameLevel() + 1)
    f.HealAbsorbMask:SetPoint("TOPLEFT", f.HealAbsorbBar:GetStatusBarTexture(), "TOPLEFT", 0, 0)
    f.HealAbsorbMask:SetPoint("BOTTOMRIGHT", f.HealAbsorbBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)

    f.HealAbsorbPattern = f.HealAbsorbMask:CreateTexture(nil, "ARTWORK")
    f.HealAbsorbPattern:SetSize(3200, 3200) -- Massive square
    f.HealAbsorbPattern:SetPoint("TOPLEFT", f.HealAbsorbMask, "TOPLEFT", 0, 0)

    f.HealAbsorbPattern:SetTexture(
        "Interface\\AddOns\\Orbit\\Core\\Assets\\Statusbar\\necrotic.tga",
        "REPEAT",
        "REPEAT"
    )
    f.HealAbsorbPattern:SetHorizTile(true)
    f.HealAbsorbPattern:SetVertTile(true)
    f.HealAbsorbPattern:SetTexCoord(0, 100, 0, 100)
    f.HealAbsorbPattern:SetBlendMode("BLEND")
    f.HealAbsorbPattern:SetAlpha(0.15)

    -- Sync Visibility
    hooksecurefunc(f.HealAbsorbBar, "Show", function()
        f.HealAbsorbMask:Show()
    end)
    hooksecurefunc(f.HealAbsorbBar, "Hide", function()
        f.HealAbsorbMask:Hide()
    end)

    -- Divider removed by user request.
    -- Text Frame to ensure text sits ABOVE absorbs
    f.TextFrame = CreateFrame("Frame", nil, f)
    f.TextFrame:SetAllPoints(f.Health)
    f.TextFrame:SetFrameLevel(f.Health:GetFrameLevel() + 10)

    f.Name = f.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Name:SetPoint("LEFT", 5, 0)
    -- Note: RIGHT point is set dynamically by UpdateTextLayout based on HealthText width
    f.Name:SetJustifyH("LEFT")
    f.Name:SetShadowOffset(1, -1)
    f.Name:SetShadowColor(0, 0, 0, 1)
    f.Name:SetWordWrap(false)
    f.Name:SetNonSpaceWrap(false)
    f.Name:SetText("Unit Name")

    f.HealthText = f.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.HealthText:SetPoint("RIGHT", -5, 0)
    f.HealthText:SetJustifyH("RIGHT")
    f.HealthText:SetShadowOffset(1, -1)
    f.HealthText:SetShadowColor(0, 0, 0, 1)
    f.HealthText:SetText("100%")

    -- Register components for drag behavior (Component Edit mode)
    -- Positions are saved as edge-relative (anchorX/Y, offsetX/Y) for resize compatibility
    if Engine.ComponentDrag then
        Engine.ComponentDrag:Attach(f.Name, f, {
            key = "Name",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)

                -- Save edge-relative position to plugin settings
                if f.orbitPlugin and f.orbitPlugin.SetSetting then
                    local systemIndex = f.systemIndex or 1
                    local positions = f.orbitPlugin:GetSetting(systemIndex, "ComponentPositions") or {}
                    positions.Name = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                    f.orbitPlugin:SetSetting(systemIndex, "ComponentPositions", positions)
                end
            end
        })
        Engine.ComponentDrag:Attach(f.HealthText, f, {
            key = "HealthText",
            onPositionChange = function(component, anchorX, anchorY, offsetX, offsetY, justifyH)

                if f.orbitPlugin and f.orbitPlugin.SetSetting then
                    local systemIndex = f.systemIndex or 1
                    local positions = f.orbitPlugin:GetSetting(systemIndex, "ComponentPositions") or {}
                    positions.HealthText = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                    f.orbitPlugin:SetSetting(systemIndex, "ComponentPositions", positions)
                end
            end
        })
    end

    Mixin(f, UnitButtonMixin)
    f:SetScript("OnEvent", f.OnEvent)
    f:OnLoad()

    f:SetScript("OnEnter", function(self)
        self:SetMouseOver(true)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(self)
        self:SetMouseOver(false)
        GameTooltip:Hide()
    end)

    f:HookScript("OnSizeChanged", function(self)
        self:UpdateTextLayout()
        -- Recalculate component positions from percentages on resize
        self:ApplyComponentPositions()
    end)

    -- OnUpdate for damage bar animation (simple time-delayed snap)
    -- Shows the red chunk for DELAY seconds, then snaps to current health
    -- NOTE: This script is only SET when animation starts (in UpdateHealth)
    --       and CLEARED when animation completes (saves CPU when not animating)
    local DAMAGE_BAR_DELAY = 0.3 -- Show red chunk for this long before snapping
    
    local function DamageBarOnUpdate(self, elapsed)
        if not self.HealthDamageBar then
            self:SetScript("OnUpdate", nil)
            return
        end

        local now = GetTime()
        local timeSinceChange = now - (self.lastHealthUpdate or 0)

        if timeSinceChange < DAMAGE_BAR_DELAY then
            -- Still in delay period, red chunk is visible
            return
        end

        -- After delay, sync DamageBar to Health bar's current value
        local healthValue = self.Health:GetValue()
        self.HealthDamageBar:SetValue(healthValue, SMOOTH_ANIM)
        
        -- Animation complete - remove OnUpdate handler to save CPU
        self:SetScript("OnUpdate", nil)
    end
    
    -- Store the function on the frame for use in UpdateHealth
    f.DamageBarOnUpdate = DamageBarOnUpdate

    RegisterUnitWatch(f)

    -- Force update when shown (Fixes 'fresh summon' empty bars)
    f:SetScript("OnShow", function(self)
        self:UpdateAll()
    end)

    return f
end
