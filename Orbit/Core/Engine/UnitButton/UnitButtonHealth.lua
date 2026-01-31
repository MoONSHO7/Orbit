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
    
    -- Global UseClassColors setting controls both class colors AND reaction colors
    local globalUseClassColors = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.UseClassColors
    local globalBarColor = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BarColor
    
    -- Determine effective setting (global takes precedence, fallback to per-frame)
    local useAdvancedColors = false
    if globalUseClassColors == false then
        useAdvancedColors = false
    elseif globalUseClassColors == true then
        useAdvancedColors = true
    else
        -- Global not set (nil) - fall back to per-frame classColour flag
        useAdvancedColors = self.classColour or false
    end
    
    -- When Class Color Health is enabled:
    -- - Players get class colors
    -- - NPCs get reaction colors
    if useAdvancedColors then
        -- Class color for players
        if UnitIsPlayer(self.unit) then
            local _, class = UnitClass(self.unit)
            if class then
                local color = C_ClassColor.GetClassColor(class)
                if color then
                    self.Health:SetStatusBarColor(color.r, color.g, color.b)
                    return
                end
            end
        end
        
        -- Reaction color for non-players (NPCs, bosses, pets)
        local reaction = UnitReaction(self.unit, "player")
        if reaction then
            local color = FACTION_BAR_COLORS[reaction]
            if color then
                self.Health:SetStatusBarColor(color.r, color.g, color.b)
                return
            end
        end
        
        -- Fallback for units with no reaction (friendly pets, etc.) - use green
        self.Health:SetStatusBarColor(0, 1, 0)
        return
    end

    -- When Class Color Health is disabled:
    -- ALL frames use the Health Color setting
    if globalBarColor then
        self.Health:SetStatusBarColor(globalBarColor.r, globalBarColor.g, globalBarColor.b)
    else
        self.Health:SetStatusBarColor(0, 1, 0) -- Default green
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

-- Export for composition
UnitButton.HealthMixin = HealthMixin
