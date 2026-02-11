-- [ UNIT BUTTON - CANVAS MODULE ]-------------------------------------------------------------------
-- Canvas Mode integration: component positions, style overrides, layout, borders
-- This module extends UnitButtonMixin with Canvas Mode functionality

local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local DAMAGE_BAR_VERTICAL_INSET = 1

-- Ensure UnitButton namespace exists
Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ CANVAS MIXIN ]---------------------------------------------------------------------------------
-- Partial mixin for Canvas Mode and layout functionality

local CanvasMixin = {}

function CanvasMixin:SetBorderHidden(edge, hidden)
    if not self.Borders then
        return
    end

    local border = self.Borders[edge]
    if border then
        border:SetShown(not hidden)
    end
end

function CanvasMixin:UpdateTextLayout()
    if not self.Name or not self.HealthText or not self.TextFrame then
        return
    end

    -- Canvas Mode is the single source of truth for component positions
    -- If ComponentPositions exists (from defaults or user customization), skip this entirely
    -- ApplyComponentPositions() will handle positioning instead
    if self.orbitPlugin and self.orbitPlugin.GetSetting then
        local systemIndex = self.systemIndex or 1
        local savedPositions = self.orbitPlugin:GetSetting(systemIndex, "ComponentPositions")
        if savedPositions and (savedPositions.Name or savedPositions.HealthText) then
            return -- Skip - positions will be applied by ApplyComponentPositions
        end
    end

    -- Fallback for frames without ComponentPositions (legacy or non-Canvas Mode frames)
    local height = self:GetHeight()
    if issecretvalue and issecretvalue(height) then
        height = 40
    end
    local fontName, fontHeight, fontFlags = self.Name:GetFont()
    fontHeight = fontHeight or 12
    if issecretvalue and issecretvalue(fontHeight) then
        fontHeight = 12
    end

    local padding = 5
    local estimatedHealthTextWidth = fontHeight * 3
    local nameRightOffset = estimatedHealthTextWidth + padding + 5

    self.Name:ClearAllPoints()
    if height < (fontHeight + 2) then
        self.Name:SetPoint("BOTTOMLEFT", self.TextFrame, "BOTTOMLEFT", padding, 0)
        self.Name:SetPoint("BOTTOMRIGHT", self.TextFrame, "BOTTOMRIGHT", -nameRightOffset, 0)
    else
        self.Name:SetPoint("LEFT", self.TextFrame, "LEFT", padding, 0)
        self.Name:SetPoint("RIGHT", self.TextFrame, "RIGHT", -nameRightOffset, 0)
    end

    self.HealthText:ClearAllPoints()
    if height < (fontHeight + 2) then
        self.HealthText:SetPoint("BOTTOMRIGHT", self.TextFrame, "BOTTOMRIGHT", -padding, 0)
    else
        self.HealthText:SetPoint("RIGHT", self.TextFrame, "RIGHT", -padding, 0)
    end
end

-- [ COMPONENT POSITIONS ]---------------------------------------------------------------------------
-- Apply component positions from saved percentages
-- Called on resize to recalculate pixel positions

function CanvasMixin:ApplyComponentPositions()
    if not self.orbitPlugin or not self.orbitPlugin.GetSetting then
        return
    end

    local systemIndex = self.systemIndex or 1
    local positions = self.orbitPlugin:GetSetting(systemIndex, "ComponentPositions")

    -- Also get defaults for fallback
    local defaults = self.orbitPlugin.defaults and self.orbitPlugin.defaults.ComponentPositions

    -- Merge positions with defaults - use defaults for any missing component
    if defaults then
        positions = positions or {}
        for key, defaultPos in pairs(defaults) do
            if not positions[key] or not positions[key].anchorX then
                positions[key] = defaultPos
            end
        end
    end

    if not positions or not next(positions) then
        return
    end

    local width, height = self:GetWidth(), self:GetHeight()
    if issecretvalue and (issecretvalue(width) or issecretvalue(height)) then
        return
    end
    if width <= 0 or height <= 0 then
        return
    end

    local ApplyTextPosition = Engine.PositionUtils and Engine.PositionUtils.ApplyTextPosition
    if not ApplyTextPosition then
        return
    end

    -- Apply Name position if saved
    if positions.Name and self.Name then
        ApplyTextPosition(self.Name, self.TextFrame, positions.Name)
    end

    -- Apply HealthText position if saved
    if positions.HealthText and self.HealthText then
        ApplyTextPosition(self.HealthText, self.TextFrame, positions.HealthText)
    end

    -- Apply LevelText position if saved (TargetFrame, FocusFrame)
    if positions.LevelText and self.LevelText then
        ApplyTextPosition(self.LevelText, self, positions.LevelText)
    end

    -- Apply RareEliteIcon position if saved (TargetFrame, FocusFrame)
    if positions.RareEliteIcon and self.RareEliteIcon then
        ApplyTextPosition(self.RareEliteIcon, self, positions.RareEliteIcon)
    end

    -- Apply CombatIcon position if saved (PlayerFrame)
    if positions.CombatIcon and self.CombatIcon then
        ApplyTextPosition(self.CombatIcon, self, positions.CombatIcon)
    end

    -- Apply DefensiveIcon position if saved (PartyFrame)
    if positions.DefensiveIcon and self.DefensiveIcon then
        ApplyTextPosition(self.DefensiveIcon, self, positions.DefensiveIcon)
    end

    -- Apply ImportantIcon position if saved (PartyFrame)
    if positions.ImportantIcon and self.ImportantIcon then
        ApplyTextPosition(self.ImportantIcon, self, positions.ImportantIcon)
    end

    -- Apply CrowdControlIcon position if saved (PartyFrame)
    if positions.CrowdControlIcon and self.CrowdControlIcon then
        ApplyTextPosition(self.CrowdControlIcon, self, positions.CrowdControlIcon)
    end

    -- Apply style overrides for ALL components with overrides in saved positions
    self:ApplyStyleOverrides(positions)
end

-- [ STYLE OVERRIDES ]-------------------------------------------------------------------------------
-- Apply Canvas Mode style overrides (font, color, scale)

function CanvasMixin:ApplyStyleOverrides(positions)
    if not positions then
        return
    end

    local ApplyOverrides = Engine.OverrideUtils and Engine.OverrideUtils.ApplyOverrides

    -- Dynamically handles any component (RoleIcon, LeaderIcon, Name, HealthText, etc.)
    for key, pos in pairs(positions) do
        if pos.overrides and ApplyOverrides then
            local element = self[key]
            if element then
                ApplyOverrides(element, pos.overrides)
            end
        end
    end
end

-- [ BORDER MANAGEMENT ]-----------------------------------------------------------------------------

function CanvasMixin:SetBorder(size)
    -- Delegate to Skin Engine
    if Orbit.Skin:SkinBorder(self, self, size) then
        self.borderPixelSize = 0
        if self.Health then
            self.Health:ClearAllPoints()
            self.Health:SetPoint("TOPLEFT", 0, 0)
            self.Health:SetPoint("BOTTOMRIGHT", 0, 0)
        end
        if self.HealthDamageBar then
            self.HealthDamageBar:ClearAllPoints()
            self.HealthDamageBar:SetPoint("TOPLEFT", self.Health, "TOPLEFT", 0, -DAMAGE_BAR_VERTICAL_INSET)
            self.HealthDamageBar:SetPoint("BOTTOMRIGHT", self.Health, "BOTTOMRIGHT", 0, DAMAGE_BAR_VERTICAL_INSET)
        end
        return
    end

    local pixelSize = self.borderPixelSize

    if self.Health then
        self.Health:ClearAllPoints()
        self.Health:SetPoint("TOPLEFT", pixelSize, -pixelSize)
        self.Health:SetPoint("BOTTOMRIGHT", -pixelSize, pixelSize)
    end

    -- DamageBar always follows Health (power bar may shrink Health below full frame)
    if self.HealthDamageBar then
        self.HealthDamageBar:ClearAllPoints()
        self.HealthDamageBar:SetPoint("TOPLEFT", self.Health, "TOPLEFT", 0, -DAMAGE_BAR_VERTICAL_INSET)
        self.HealthDamageBar:SetPoint("BOTTOMRIGHT", self.Health, "BOTTOMRIGHT", 0, DAMAGE_BAR_VERTICAL_INSET)
    end
end

-- Export for composition
UnitButton.CanvasMixin = CanvasMixin
