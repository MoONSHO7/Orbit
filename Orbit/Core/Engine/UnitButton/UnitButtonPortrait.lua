-- [ UNIT BUTTON - PORTRAIT MODULE ]-----------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local PORTRAIT_DEFAULT_SIZE = 32
local PORTRAIT_LEVEL_OFFSET = 15
local PORTRAIT_MIN_SCALE = 50
local PORTRAIT_MAX_SCALE = 200
local CIRCLE_MASK_PATH = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ PORTRAIT MIXIN ]--------------------------------------------------------------------------------

local PortraitMixin = {}

function PortraitMixin:CreatePortrait()
    if self.Portrait then return end

    local container = CreateFrame("Frame", nil, self.OverlayFrame or self)
    container:SetSize(PORTRAIT_DEFAULT_SIZE, PORTRAIT_DEFAULT_SIZE)
    container:SetPoint("RIGHT", self, "LEFT", -4, 0)
    container:SetFrameLevel(self:GetFrameLevel() + PORTRAIT_LEVEL_OFFSET)

    container.StaticTexture = container:CreateTexture(nil, "ARTWORK")
    container.StaticTexture:SetAllPoints()
    container.orbitOriginalWidth = PORTRAIT_DEFAULT_SIZE
    container.orbitOriginalHeight = PORTRAIT_DEFAULT_SIZE

    container.CircleMask = container:CreateMaskTexture()
    container.CircleMask:SetAllPoints()
    container.CircleMask:SetTexture(CIRCLE_MASK_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    container.CircleMask:Hide()

    self.Portrait = container
end

function PortraitMixin:UpdatePortrait()
    local portrait = self.Portrait
    if not portrait then return end

    local plugin = self.orbitPlugin
    if not plugin then return end
    local systemIndex = self.systemIndex or 1

    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("Portrait") then
        portrait:Hide()
        return
    end

    if self.orbitMountedSuppressed then
        portrait:Hide()
        return
    end

    local unit = self.unit
    if not unit or not UnitExists(unit) then
        portrait:Hide()
        return
    end

    local scale = (plugin:GetSetting(systemIndex, "PortraitScale") or 100) / 100
    local shape = plugin:GetSetting(systemIndex, "PortraitShape") or "square"
    local style = plugin:GetSetting(systemIndex, "PortraitStyle") or "2d"
    local showBorder = plugin:GetSetting(systemIndex, "PortraitBorder")
    if showBorder == nil then showBorder = true end

    local size = PORTRAIT_DEFAULT_SIZE * scale
    portrait:SetSize(size, size)

    self:ApplyPortraitShape(shape)
    self:ApplyPortraitBorder(shape ~= "circle" and showBorder)
    self:ApplyPortraitContent(style, unit)
    portrait:Show()
end

function PortraitMixin:ApplyPortraitContent(style, unit)
    local portrait = self.Portrait
    if not portrait.Model then
        portrait.Model = CreateFrame("PlayerModel", nil, portrait)
        portrait.Model:SetAllPoints()
    end
    if style == "3d" then
        portrait.StaticTexture:Hide()
        portrait.Model:Show()
        portrait.Model:SetUnit(unit)
        portrait.Model:SetPortraitZoom(1)
    else
        portrait.Model:Hide()
        portrait.StaticTexture:Show()
        SetPortraitTexture(portrait.StaticTexture, unit)
    end
end

function PortraitMixin:ApplyPortraitShape(shape)
    local portrait = self.Portrait
    if shape == "circle" then
        portrait.StaticTexture:AddMaskTexture(portrait.CircleMask)
        portrait.CircleMask:Show()
    else
        portrait.StaticTexture:RemoveMaskTexture(portrait.CircleMask)
        portrait.CircleMask:Hide()
    end
end

function PortraitMixin:ApplyPortraitBorder(showBorder)
    local portrait = self.Portrait
    if showBorder then
        local borderSize = Orbit.db.GlobalSettings.BorderSize or 0
        Orbit.Skin:SkinBorder(portrait, portrait, borderSize)
    else
        Orbit.Skin:SkinBorder(portrait, portrait, 0)
    end
end

-- [ SETTINGS HELPERS ]------------------------------------------------------------------------------

PortraitMixin.PORTRAIT_MIN_SCALE = PORTRAIT_MIN_SCALE
PortraitMixin.PORTRAIT_MAX_SCALE = PORTRAIT_MAX_SCALE

function PortraitMixin.AddPortraitSettings(plugin, schema, systemIndex, dialog)
    table.insert(schema.controls, {
        type = "dropdown", key = "PortraitStyle", label = "Portrait Style",
        options = {
            { text = "2D", value = "2d" },
            { text = "3D", value = "3d" },
        },
        default = "2d",
        onChange = function(val)
            plugin:SetSetting(systemIndex, "PortraitStyle", val)
            plugin:ApplySettings()
        end,
    })
    table.insert(schema.controls, {
        type = "slider", key = "PortraitScale", label = "Portrait Scale",
        min = PORTRAIT_MIN_SCALE, max = PORTRAIT_MAX_SCALE, step = 1,
        formatter = function(v) return v .. "%" end,
        default = 100,
        onChange = function(val)
            plugin:SetSetting(systemIndex, "PortraitScale", val)
            plugin:ApplySettings()
        end,
    })
    table.insert(schema.controls, {
        type = "dropdown", key = "PortraitShape", label = "Portrait Shape",
        options = {
            { text = "Square", value = "square" },
            { text = "Circle", value = "circle" },
        },
        default = "square",
        onChange = function(val)
            plugin:SetSetting(systemIndex, "PortraitShape", val)
            plugin:ApplySettings()
            if dialog and dialog.orbitTabCallback then dialog.orbitTabCallback() end
        end,
    })
    if (plugin:GetSetting(systemIndex, "PortraitShape") or "square") ~= "circle" then
        table.insert(schema.controls, {
            type = "checkbox", key = "PortraitBorder", label = "Portrait Border",
            default = true,
            onChange = function(val)
                plugin:SetSetting(systemIndex, "PortraitBorder", val)
                plugin:ApplySettings()
            end,
        })
    end
end

UnitButton.PortraitMixin = PortraitMixin
