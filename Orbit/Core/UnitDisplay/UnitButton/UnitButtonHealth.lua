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
    local useGradientTexture = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.UnitHealthUseGradient
    local hasClassPin = Engine.ColorCurve:CurveHasClassPin(globalBarCurve)
    local isGradient = #globalBarCurve.pins > 1
    local tex = self.Health:GetStatusBarTexture()

    if useGradientTexture and isGradient then
        if tex then
            local leftPin = globalBarCurve.pins[1]
            local rightPin = globalBarCurve.pins[1]
            for _, pin in ipairs(globalBarCurve.pins) do
                if pin.position < leftPin.position then leftPin = pin end
                if pin.position > rightPin.position then rightPin = pin end
            end
            
            local leftColor = Engine.ClassColor:ResolveClassColorPinForUnit(leftPin, self.unit)
            local rightColor = Engine.ClassColor:ResolveClassColorPinForUnit(rightPin, self.unit)
            
            tex:SetVertexColor(1, 1, 1, 1) -- Clear tint first
            tex:SetGradient("HORIZONTAL", CreateColor(leftColor.r, leftColor.g, leftColor.b, leftColor.a or 1), CreateColor(rightColor.r, rightColor.g, rightColor.b, rightColor.a or 1))
        end
        return
    end

    -- Clear spatial gradient if reverting back
    if tex and tex.SetGradient then
        tex:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1))
    end

    if isGradient then
        local nativeCurve = hasClassPin
            and Engine.ColorCurve:ToNativeColorCurveForUnit(globalBarCurve, self.unit)
            or  Engine.ColorCurve:ToNativeColorCurve(globalBarCurve)

        if nativeCurve and UnitHealthPercent and self.unit and UnitExists(self.unit) then
            if tex then
                local ok, color = pcall(UnitHealthPercent, self.unit, true, nativeCurve)
                if ok and color and color.GetRGBA then
                    tex:SetVertexColor(color:GetRGBA())
                    return
                end
            end
        end
    end

    local staticColor = hasClassPin
        and Engine.ColorCurve:GetFirstColorFromCurveForUnit(globalBarCurve, self.unit)
        or  Engine.ColorCurve:GetFirstColorFromCurve(globalBarCurve)
    
    if staticColor then
        if tex then
            tex:SetVertexColor(staticColor.r, staticColor.g, staticColor.b, staticColor.a or 1)
        else
            self.Health:SetStatusBarColor(staticColor.r, staticColor.g, staticColor.b, staticColor.a or 1)
        end
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
