-- [ UNIT BUTTON - HEALTH MODULE ]-------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

local DEFAULT_BAR_COLOR = { r = 0, g = 1, b = 0 }

-- [ HEALTH MIXIN ]----------------------------------------------------------------------------------
local HealthMixin = {}

function HealthMixin:UpdateHealth()
    if not self.Health then return end
    if not self.unit or not UnitExists(self.unit) then return end

    local health = UnitHealth(self.unit)
    local maxHealth = UnitHealthMax(self.unit)

    self.Health:SetMinMaxValues(0, maxHealth)

    if self.HealthDamageBar then self.HealthDamageBar:SetMinMaxValues(0, maxHealth) end

    self.Health:SetValue(health)

    -- The barbarian rages and the damage bar slowly fades like their HP
    if self.HealthDamageBar then
        self.lastHealthUpdate = GetTime()
        if self.DamageBarOnUpdate then self:SetScript("OnUpdate", self.DamageBarOnUpdate) end
    end

    self:ApplyHealthColor()
end

function HealthMixin:ApplyHealthColor()
    if not self.Health then return end

    local globalBarCurve = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BarColorCurve
    if not globalBarCurve or not globalBarCurve.pins or #globalBarCurve.pins == 0 then
        self.Health:SetStatusBarColor(DEFAULT_BAR_COLOR.r, DEFAULT_BAR_COLOR.g, DEFAULT_BAR_COLOR.b)
        return
    end

    -- The paladin casts Detect Magic to determine the bar's true color
    local hasClassPin = Engine.WidgetLogic:CurveHasClassPin(globalBarCurve)
    local nativeCurve = hasClassPin
        and Engine.WidgetLogic:ToNativeColorCurveForUnit(globalBarCurve, self.unit)
        or  Engine.WidgetLogic:ToNativeColorCurve(globalBarCurve)

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

    local staticColor = hasClassPin
        and Engine.WidgetLogic:GetFirstColorFromCurveForUnit(globalBarCurve, self.unit)
        or  Engine.WidgetLogic:GetFirstColorFromCurve(globalBarCurve)
    if staticColor then
        self.Health:SetStatusBarColor(staticColor.r, staticColor.g, staticColor.b)
    end
end

function HealthMixin:SetReactionColour(enabled)
    self.reactionColour = enabled
    self:UpdateHealth()
end

function HealthMixin:SetClassColour(enabled)
    self.classColour = enabled
    self:UpdateHealth()
end

UnitButton.HealthMixin = HealthMixin
