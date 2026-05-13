-- [ UNIT BUTTON - CANVAS MODULE ]--------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local FALLBACK_HEIGHT = 40
local DEFAULT_FONT_HEIGHT = 12
local TEXT_PADDING = 5
local TIGHT_FIT_MARGIN = 2

local COMPONENT_POSITION_MAP = {
    { key = "Name",             parentKey = "TextFrame" },
    { key = "HealthText",       parentKey = "TextFrame" },
    { key = "LevelText",        parentKey = nil },
    { key = "RareEliteIcon",    parentKey = nil },
    { key = "CombatIcon",       parentKey = nil },
    { key = "DefensiveIcon",    parentKey = nil, isAura = true },
    { key = "CrowdControlIcon", parentKey = nil, isAura = true },
    { key = "Portrait",         parentKey = nil },
    { key = "MarkerIcon",       parentKey = nil },
    { key = "CastBar",          parentKey = nil },
    { key = "PvpIcon",          parentKey = nil },
    { key = "LeaderIcon",       parentKey = nil },
    { key = "GroupPositionText",parentKey = nil },
    { key = "ReadyCheckIcon",   parentKey = nil },
    { key = "RestingIcon",      parentKey = nil },
}

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ CANVAS MIXIN ]-----------------------------------------------------------------------------------
local CanvasMixin = {}

function CanvasMixin:SetBorderHidden(hidden) Orbit.Skin.DefaultSetBorderHidden(self, hidden) end

function CanvasMixin:UpdateTextLayout()
    if not self.Name or not self.HealthText or not self.TextFrame then
        return
    end

    -- The Dungeon Master's word is law; canvas positions override everything
    if self.orbitPlugin and self.orbitPlugin.GetSetting then
        local positions = self.orbitPlugin:GetSetting(self.systemIndex or 1, "ComponentPositions")
        if positions and (positions.Name or positions.HealthText) then return end
    end

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

-- [ COMPONENT POSITIONS ]----------------------------------------------------------------------------
function CanvasMixin:ApplyComponentPositions()
    if not self.orbitPlugin or not self.orbitPlugin.GetSetting then return end

    local systemIndex = self.systemIndex or 1
    local positions = self.orbitPlugin:GetComponentPositions(systemIndex)
    local defaults = self.orbitPlugin.defaults and self.orbitPlugin.defaults.ComponentPositions

    if defaults then
        positions = positions or {}
        for key, defaultPos in pairs(defaults) do
            if not positions[key] then
                positions[key] = defaultPos
            else
                -- Merge default fields and sub-tables (like 'overrides') without overwriting existing data
                local existing = positions[key]
                for k, v in pairs(defaultPos) do
                    if type(v) == "table" then
                        existing[k] = existing[k] or {}
                        for subK, subV in pairs(v) do
                            if existing[k][subK] == nil then existing[k][subK] = subV end
                        end
                    elseif existing[k] == nil then 
                        existing[k] = v 
                    end
                end
            end
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

-- [ STYLE OVERRIDES ]--------------------------------------------------------------------------------
function CanvasMixin:ApplyStyleOverrides(positions)
    if not positions then return end
    local ApplyOverrides = Engine.OverrideUtils and Engine.OverrideUtils.ApplyOverrides

    for key, pos in pairs(positions) do
        if pos.overrides and ApplyOverrides and self[key] then
            ApplyOverrides(self[key], pos.overrides, nil, self.unit, self.previewClassFile)
        end
    end
end

-- [ BORDER MANAGEMENT ]------------------------------------------------------------------------------
function CanvasMixin:SetBorder(size)
    Orbit.Skin:SkinBorder(self, self, size)
    -- Borders are now outset — no insets needed
end

UnitButton.CanvasMixin = CanvasMixin
