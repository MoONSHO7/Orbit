-- [ UNIT BUTTON - PORTRAIT MODULE ]-----------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local PORTRAIT_DEFAULT_SIZE = 32
local PORTRAIT_LEVEL_OFFSET = 15
local PORTRAIT_MIN_SCALE = 50
local PORTRAIT_MAX_SCALE = 200
local PORTRAIT_3D_MIRROR_FACING = -1.05
local PORTRAIT_3D_MIRROR_OFFSET = 0.3
local PORTRAIT_3D_MIRROR_VERT = -0.05
local PORTRAIT_3D_MIRROR_ZOOM = 0.85

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

    container.bg = container:CreateTexture(nil, "BACKGROUND")
    container.bg:SetAllPoints()

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

    local scale = (plugin:GetSetting(systemIndex, "PortraitScale") or 120) / 100
    local style = plugin:GetSetting(systemIndex, "PortraitStyle") or "3d"
    local mirror = plugin:GetSetting(systemIndex, "PortraitMirror") or false
    local showBorder = plugin:GetSetting(systemIndex, "PortraitBorder")
    if showBorder == nil then showBorder = true end

    local size = PORTRAIT_DEFAULT_SIZE * scale
    portrait:SetSize(size, size)

    self:ApplyPortraitBorder(showBorder)
    self:ApplyPortraitContent(style, unit, mirror)
    self:ApplyPortraitBackdrop()
    portrait:Show()
end

function PortraitMixin:ApplyPortraitContent(style, unit, mirror)
    local portrait = self.Portrait
    if not portrait.Model then
        portrait.Model = CreateFrame("PlayerModel", nil, portrait)
        portrait.Model:SetAllPoints()
    end
    if style == "3d" then
        portrait.StaticTexture:Hide()
        portrait.Model:Show()
        portrait.Model:SetUnit(unit)
        portrait.Model:SetPortraitZoom(mirror and PORTRAIT_3D_MIRROR_ZOOM or 1)
        portrait.Model:SetFacing(mirror and PORTRAIT_3D_MIRROR_FACING or 0)
        portrait.Model:SetPosition(mirror and PORTRAIT_3D_MIRROR_OFFSET or 0, 0, mirror and PORTRAIT_3D_MIRROR_VERT or 0)
    else
        portrait.Model:Hide()
        portrait.StaticTexture:Show()
        SetPortraitTexture(portrait.StaticTexture, unit)
        if mirror then
            portrait.StaticTexture:SetTexCoord(1, 0, 0, 1)
        else
            portrait.StaticTexture:SetTexCoord(0, 1, 0, 1)
        end
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

function PortraitMixin:ApplyPortraitBackdrop()
    local portrait = self.Portrait
    if not portrait or not portrait.bg then return end
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(portrait, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)
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
        default = "3d",
        onChange = function(val)
            plugin:SetSetting(systemIndex, "PortraitStyle", val)
            plugin:ApplySettings()
        end,
    })
    table.insert(schema.controls, {
        type = "slider", key = "PortraitScale", label = "Portrait Scale",
        min = PORTRAIT_MIN_SCALE, max = PORTRAIT_MAX_SCALE, step = 1,
        formatter = function(v) return v .. "%" end,
        default = 120,
        onChange = function(val)
            plugin:SetSetting(systemIndex, "PortraitScale", val)
            plugin:ApplySettings()
        end,
    })
    table.insert(schema.controls, {
        type = "checkbox", key = "PortraitBorder", label = "Portrait Border",
        default = true,
        onChange = function(val)
            plugin:SetSetting(systemIndex, "PortraitBorder", val)
            plugin:ApplySettings()
        end,
    })
    table.insert(schema.controls, {
        type = "checkbox", key = "PortraitMirror", label = "Mirror",
        default = false,
        onChange = function(val)
            plugin:SetSetting(systemIndex, "PortraitMirror", val)
            plugin:ApplySettings()
        end,
    })
end

UnitButton.PortraitMixin = PortraitMixin
