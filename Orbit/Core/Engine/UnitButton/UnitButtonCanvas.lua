-- [ UNIT BUTTON - CANVAS MODULE ]-------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local FALLBACK_HEIGHT = 40
local DEFAULT_FONT_HEIGHT = 12
local TEXT_PADDING = 5
local HEALTH_TEXT_WIDTH_MULTIPLIER = 3
local TIGHT_FIT_MARGIN = 2

-- The rogue mapped out which components can be pickpocketed to new positions
local COMPONENT_POSITION_MAP = {
    { key = "Name",             parentKey = "TextFrame" },
    { key = "HealthText",       parentKey = "TextFrame" },
    { key = "LevelText",        parentKey = nil },
    { key = "RareEliteIcon",    parentKey = nil },
    { key = "CombatIcon",       parentKey = nil },
    { key = "DefensiveIcon",    parentKey = nil },
    { key = "ImportantIcon",    parentKey = nil },
    { key = "CrowdControlIcon", parentKey = nil },
}

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ CANVAS MIXIN ]----------------------------------------------------------------------------------

local CanvasMixin = {}

function CanvasMixin:SetBorderHidden(edge, hidden)
    local borders = (self._borderFrame and self._borderFrame.Borders) or self.Borders
    if not borders then return end
    local border = borders[edge]
    if border then border:SetShown(not hidden) end
    if not self._mergedEdges then self._mergedEdges = {} end
    self._mergedEdges[edge] = hidden or nil

    if self.UpdateBarInsets then
        self:UpdateBarInsets()
    end
end

function CanvasMixin:UpdateTextLayout()
    if not self.Name or not self.HealthText or not self.TextFrame then
        return
    end

    -- Canvas Mode is the single source of truth for component positions
    if self.orbitPlugin and self.orbitPlugin.GetSetting then
        local positions = self.orbitPlugin:GetSetting(self.systemIndex or 1, "ComponentPositions")
        if positions and (positions.Name or positions.HealthText) then return end
    end

    -- The wizard casts Comprehend Layout on the cramped parchment
    local height = self:GetHeight()
    if issecretvalue and issecretvalue(height) then height = FALLBACK_HEIGHT end
    local _, fontHeight = self.Name:GetFont()
    fontHeight = fontHeight or DEFAULT_FONT_HEIGHT
    if issecretvalue and issecretvalue(fontHeight) then fontHeight = DEFAULT_FONT_HEIGHT end

    local nameRightOffset = (fontHeight * HEALTH_TEXT_WIDTH_MULTIPLIER) + TEXT_PADDING + TEXT_PADDING
    local anchorV = height < (fontHeight + TIGHT_FIT_MARGIN) and "BOTTOM" or ""

    self.Name:ClearAllPoints()
    self.Name:SetPoint(anchorV .. "LEFT", self.TextFrame, anchorV .. "LEFT", TEXT_PADDING, 0)
    self.Name:SetPoint(anchorV .. "RIGHT", self.TextFrame, anchorV .. "RIGHT", -nameRightOffset, 0)

    self.HealthText:ClearAllPoints()
    self.HealthText:SetPoint(anchorV .. "RIGHT", self.TextFrame, anchorV .. "RIGHT", -TEXT_PADDING, 0)
end

-- [ COMPONENT POSITIONS ]---------------------------------------------------------------------------

function CanvasMixin:ApplyComponentPositions()
    if not self.orbitPlugin or not self.orbitPlugin.GetSetting then return end

    local systemIndex = self.systemIndex or 1
    local positions = self.orbitPlugin:GetSetting(systemIndex, "ComponentPositions")
    local defaults = self.orbitPlugin.defaults and self.orbitPlugin.defaults.ComponentPositions

    if defaults then
        positions = positions or {}
        for key, defaultPos in pairs(defaults) do
            if not positions[key] or not positions[key].anchorX then positions[key] = defaultPos end
        end
    end

    if not positions or not next(positions) then return end

    local width, height = self:GetWidth(), self:GetHeight()
    if issecretvalue and (issecretvalue(width) or issecretvalue(height)) then return end
    if width <= 0 or height <= 0 then return end

    local ApplyTextPosition = Engine.PositionUtils and Engine.PositionUtils.ApplyTextPosition
    if not ApplyTextPosition then return end

    for _, entry in ipairs(COMPONENT_POSITION_MAP) do
        local pos = positions[entry.key]
        local element = self[entry.key]
        if pos and element then
            ApplyTextPosition(element, entry.parentKey and self[entry.parentKey] or self, pos)
        end
    end

    self:ApplyStyleOverrides(positions)
end

-- [ STYLE OVERRIDES ]-------------------------------------------------------------------------------

function CanvasMixin:ApplyStyleOverrides(positions)
    if not positions then return end
    local ApplyOverrides = Engine.OverrideUtils and Engine.OverrideUtils.ApplyOverrides

    for key, pos in pairs(positions) do
        if pos.overrides and ApplyOverrides and self[key] then
            ApplyOverrides(self[key], pos.overrides, nil, self.unit)
        end
    end
end

-- [ BORDER MANAGEMENT ]-----------------------------------------------------------------------------

function CanvasMixin:UpdateBarInsets()
    local oldBorderSize = self.borderPixelSize
    if not oldBorderSize or oldBorderSize <= 0 then
        if self.Health then
            self.Health:ClearAllPoints()
            self.Health:SetPoint("TOPLEFT", 0, 0)
            self.Health:SetPoint("BOTTOMRIGHT", 0, 0)
        end
        if self.HealthDamageBar then
            self.HealthDamageBar:ClearAllPoints()
            self.HealthDamageBar:SetPoint("TOPLEFT", self.Health, "TOPLEFT", 0, 0)
            self.HealthDamageBar:SetPoint("BOTTOMRIGHT", self.Health, "BOTTOMRIGHT", 0, 0)
        end
        if self.HealthBlocker then
            self.HealthBlocker:ClearAllPoints()
            self.HealthBlocker:SetPoint("TOPLEFT", self.Health, "TOPLEFT", 0, 0)
            self.HealthBlocker:SetPoint("BOTTOMRIGHT", self.Health, "BOTTOMRIGHT", 0, 0)
        end
        return
    end

    local iL, iT, iR, iB = oldBorderSize, oldBorderSize, oldBorderSize, oldBorderSize
    if self._barInsets then
        iL, iT, iR, iB = self._barInsets.x1, self._barInsets.y1, self._barInsets.x2, self._barInsets.y2
    end

    if self._mergedEdges then
        if self._mergedEdges.Left then iL = 0 end
        if self._mergedEdges.Right then iR = 0 end
        if self._mergedEdges.Top then iT = 0 end
        if self._mergedEdges.Bottom then iB = 0 end
    end

    if self.Health then
        self.Health:ClearAllPoints()
        self.Health:SetPoint("TOPLEFT", iL, -iT)
        self.Health:SetPoint("BOTTOMRIGHT", -iR, iB)
    end
    if self.HealthDamageBar then
        self.HealthDamageBar:ClearAllPoints()
        self.HealthDamageBar:SetPoint("TOPLEFT", self.Health, "TOPLEFT", 0, 0)
        self.HealthDamageBar:SetPoint("BOTTOMRIGHT", self.Health, "BOTTOMRIGHT", 0, 0)
    end
    if self.HealthBlocker then
        self.HealthBlocker:ClearAllPoints()
        self.HealthBlocker:SetPoint("TOPLEFT", self.Health, "TOPLEFT", 0, 0)
        self.HealthBlocker:SetPoint("BOTTOMRIGHT", self.Health, "BOTTOMRIGHT", 0, 0)
    end
end

function CanvasMixin:SetBorder(size)
    local oldBorderSize = self.borderPixelSize
    if Orbit.Skin:SkinBorder(self, self, size) then
        self._barInsets = nil
        self.borderPixelSize = 0
        self:UpdateBarInsets()
        return
    end

    local pixelSize = self.borderPixelSize
    if oldBorderSize ~= pixelSize then self._barInsets = nil end

    self:UpdateBarInsets()
end

UnitButton.CanvasMixin = CanvasMixin
