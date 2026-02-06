-- [ UNIT BUTTON - HEALTH MODULE ]-------------------------------------------------------------------
-- Health bar updates, coloring, and damage bar animation
-- This module extends UnitButtonMixin with health-related functionality

local _, Orbit = ...
local Engine = Orbit.Engine

-- Ensure UnitButton namespace exists
Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- Partial mixin for health functionality (will be merged into UnitButtonMixin)
local HealthMixin = {}

function HealthMixin:UpdateHealth()
    if not self.Health then
        return
    end

    -- Guard against nil unit (frames can exist before being assigned a unit)
    if not self.unit or not UnitExists(self.unit) then
        return
    end

    local health = UnitHealth(self.unit)
    local maxHealth = UnitHealthMax(self.unit)

    -- Set main health bar min/max
    self.Health:SetMinMaxValues(0, maxHealth)

    -- Update damage bar min/max to match
    if self.HealthDamageBar then
        self.HealthDamageBar:SetMinMaxValues(0, maxHealth)
    end

    -- Set main health bar value INSTANTLY
    self.Health:SetValue(health)

    -- Trigger slide animation for damage bar
    -- The DamageBar stays where it is, OnUpdate will slide it down after a delay
    if self.HealthDamageBar then
        self.lastHealthUpdate = GetTime()
        -- Enable OnUpdate handler only when animation is needed (saves CPU)
        if self.DamageBarOnUpdate then
            self:SetScript("OnUpdate", self.DamageBarOnUpdate)
        end
    end

    -- Apply color based on settings
    self:ApplyHealthColor()
end

function HealthMixin:ApplyHealthColor()
    if not self.Health then return end

    local globalBarCurve = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BarColorCurve

    if globalBarCurve and globalBarCurve.pins and #globalBarCurve.pins > 0 then
        -- Check if curve has class color pins
        local hasClassPin = Engine.WidgetLogic:CurveHasClassPin(globalBarCurve)
        
        if hasClassPin then
            -- Build unit-specific native curve (resolves class pins for this unit)
            local nativeCurve = Engine.WidgetLogic:ToNativeColorCurveForUnit(globalBarCurve, self.unit)
            if nativeCurve and UnitHealthPercent and self.unit and UnitExists(self.unit) then
                local tex = self.Health:GetStatusBarTexture()
                if tex then
                    local ok, color = pcall(UnitHealthPercent, self.unit, true, nativeCurve)
                    if ok and color and color.GetRGBA then
                        tex:SetVertexColor(color:GetRGBA())
                        return
                    end
                end
            end
            -- Fallback to first color if native curve fails
            local staticColor = Engine.WidgetLogic:GetFirstColorFromCurveForUnit(globalBarCurve, self.unit)
            if staticColor then
                self.Health:SetStatusBarColor(staticColor.r, staticColor.g, staticColor.b)
                return
            end
        else
            -- No class pins - can use cached native curve for gradient
            local nativeCurve = Engine.WidgetLogic:ToNativeColorCurve(globalBarCurve)
            if nativeCurve and UnitHealthPercent and self.unit and UnitExists(self.unit) then
                local tex = self.Health:GetStatusBarTexture()
                if tex then
                    local ok, color = pcall(UnitHealthPercent, self.unit, true, nativeCurve)
                    if ok and color and color.GetRGBA then
                        tex:SetVertexColor(color:GetRGBA())
                        return
                    end
                end
            end
            local staticColor = Engine.WidgetLogic:GetFirstColorFromCurve(globalBarCurve)
            if staticColor then
                self.Health:SetStatusBarColor(staticColor.r, staticColor.g, staticColor.b)
                return
            end
        end
    end

    self.Health:SetStatusBarColor(0, 1, 0)
end

function HealthMixin:SetReactionColour(enabled)
    self.reactionColour = enabled
    self:UpdateHealth()
end

function HealthMixin:SetClassColour(enabled)
    self.classColour = enabled
    self:UpdateHealth()
end

-- Export for composition
UnitButton.HealthMixin = HealthMixin
