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
    
    -- Class color takes priority
    if self.classColour then
        local _, class = UnitClass(self.unit)
        if class and UnitIsPlayer(self.unit) then
            local color = C_ClassColor.GetClassColor(class)
            if color then
                self.Health:SetStatusBarColor(color.r, color.g, color.b)
                return
            end
        end
    end

    -- Reaction color for NPCs
    if self.reactionColour then
        local reaction = UnitReaction(self.unit, "player")
        if reaction then
            local color = FACTION_BAR_COLORS[reaction]
            if color then
                self.Health:SetStatusBarColor(color.r, color.g, color.b)
                return
            end
        end
    end

    -- Default green
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
