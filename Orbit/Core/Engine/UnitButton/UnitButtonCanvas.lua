-- [ UNIT BUTTON - CANVAS MODULE ]-------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local FALLBACK_HEIGHT = 40
local DEFAULT_FONT_HEIGHT = 12
local TEXT_PADDING = 5
local TIGHT_FIT_MARGIN = 2

-- The rogue mapped out which components can be pickpocketed to new positions
local COMPONENT_POSITION_MAP = {
    { key = "Name",             parentKey = "TextFrame" },
    { key = "HealthText",       parentKey = "TextFrame" },
    { key = "LevelText",        parentKey = nil },
    { key = "RareEliteIcon",    parentKey = nil },
    { key = "CombatIcon",       parentKey = nil },
    { key = "DefensiveIcon",    parentKey = nil },
    { key = "CrowdControlIcon", parentKey = nil },
    { key = "Portrait",         parentKey = nil },
    { key = "MarkerIcon",       parentKey = nil },
    { key = "CastBar",          parentKey = nil },
    { key = "Buffs",             parentKey = nil, isAura = true },
    { key = "Debuffs",           parentKey = nil, isAura = true },
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

    -- The Dungeon Master's word is law; canvas positions override everything
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

    local anchorV = height < (fontHeight + TIGHT_FIT_MARGIN) and "BOTTOM" or ""

    self.Name:ClearAllPoints()
    self.Name:SetPoint(anchorV .. "LEFT", self.TextFrame, anchorV .. "LEFT", TEXT_PADDING, 0)

    self.HealthText:ClearAllPoints()
    self.HealthText:SetPoint(anchorV .. "RIGHT", self.TextFrame, anchorV .. "RIGHT", -TEXT_PADDING, 0)

    if self.ConstrainNameWidth then self:ConstrainNameWidth() end
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
        if pos and element and entry.key ~= "CastBar" then
            ApplyTextPosition(element, entry.parentKey and self[entry.parentKey] or self, pos, nil, nil, nil, entry.isAura)
        end
    end

    self:ApplyStyleOverrides(positions)

    if self.ConstrainNameWidth then self:ConstrainNameWidth() end
end

-- [ STYLE OVERRIDES ]-------------------------------------------------------------------------------

function CanvasMixin:ApplyStyleOverrides(positions)
    if not positions then return end
    local ApplyOverrides = Engine.OverrideUtils and Engine.OverrideUtils.ApplyOverrides

    for key, pos in pairs(positions) do
        if pos.overrides and ApplyOverrides and self[key] then
            ApplyOverrides(self[key], pos.overrides, nil, self.unit, self.previewClassFile)
        end
    end
end

-- [ BORDER MANAGEMENT ]-----------------------------------------------------------------------------

-- The party's formation shifts to match the dungeon walls
local function SetBarPoints(bar, parent, tl, br)
    if not bar then return end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", tl, -br)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -tl, br)
end

function CanvasMixin:UpdateBarInsets()
    local borderSize = self.borderPixelSize
    if not borderSize or borderSize <= 0 then
        if self.Health then
            self.Health:ClearAllPoints()
            self.Health:SetPoint("TOPLEFT", 0, 0)
            self.Health:SetPoint("BOTTOMRIGHT", 0, 0)
        end
        SetBarPoints(self.HealthDamageBar, self.Health, 0, 0)
        SetBarPoints(self.HealthBlocker, self.Health, 0, 0)
        return
    end

    local iL, iT, iR, iB = borderSize, borderSize, borderSize, borderSize

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
    SetBarPoints(self.HealthDamageBar, self.Health, 0, 0)
    SetBarPoints(self.HealthBlocker, self.Health, 0, 0)
end

function CanvasMixin:SetBorder(size)
    if self._nineSliceStyle then
        Orbit.Skin:SkinBorder(self, self, 0)
        Orbit.Skin:ApplyGraphicalBorder(self, self._nineSliceStyle)
        self.borderPixelSize = 0
        self:UpdateBarInsets()
        return
    end

    Orbit.Skin:ApplyGraphicalBorder(self, nil)
    if Orbit.Skin:SkinBorder(self, self, size) then
        self.borderPixelSize = 0
        self:UpdateBarInsets()
        return
    end
    self:UpdateBarInsets()
end

UnitButton.CanvasMixin = CanvasMixin
