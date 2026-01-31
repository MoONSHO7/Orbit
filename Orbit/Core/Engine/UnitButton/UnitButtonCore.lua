-- [ UNIT BUTTON - CORE MODULE ]---------------------------------------------------------------------
-- Core UnitButtonMixin: OnLoad, OnEvent, UpdateAll, CreateCanvasPreview
-- Composes functionality from Health, Text, Prediction, and Canvas sub-modules

local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- Ensure UnitButton namespace exists
Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- Compatibility for 12.0 / Native Smoothing
local SMOOTH_ANIM = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

-- [ CORE MIXIN ]------------------------------------------------------------------------------------
-- Base mixin with lifecycle and event handling

local CoreMixin = {}

function CoreMixin:OnLoad()
    self:RegisterForClicks("AnyUp")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_MAXHEALTH")
    self:RegisterEvent("UNIT_HEALTH")
    self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
    self:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
    self:RegisterEvent("UNIT_HEAL_PREDICTION")
    self:RegisterEvent("UNIT_PET")

    self:UpdateAll()
end

function CoreMixin:CreateCanvasPreview(options)
    options = options or {}
    local scale = options.scale or 1
    local borderSize = options.borderSize or 2
    local parent = options.parent or UIParent
    
    -- Use Preview.Frame:CreateBasePreview for the container
    local preview = Engine.Preview.Frame:CreateBasePreview(self, scale, parent, borderSize)
    if not preview then return nil end
    
    -- Create a single health bar preview to represent the unit button
    local bar = CreateFrame("StatusBar", nil, preview)
    bar:SetPoint("TOPLEFT", borderSize * scale, -borderSize * scale)
    bar:SetPoint("BOTTOMRIGHT", -borderSize * scale, borderSize * scale)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.75) -- Show as 75% health for preview
    
    -- Apply texture from options or global settings
    local textureName = options.textureName or Orbit.db.GlobalSettings.Texture
    local texturePath = LSM:Fetch("statusbar", textureName)
    bar:SetStatusBarTexture(texturePath)
    
    -- Apply color based on global UseClassColors setting (same logic as live frames)
    local globalSettings = Orbit.db.GlobalSettings or {}
    local useClassColors = globalSettings.UseClassColors ~= false -- Default true
    local globalBarColor = globalSettings.BarColor or { r = 0.2, g = 0.8, b = 0.2 }
    
    if useClassColors then
        -- Use class color for player
        local _, playerClass = UnitClass("player")
        local classColor = C_ClassColor.GetClassColor(playerClass)
        if classColor then
            bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
        else
            bar:SetStatusBarColor(globalBarColor.r, globalBarColor.g, globalBarColor.b, 1)
        end
    else
        -- Use global Health Color
        bar:SetStatusBarColor(globalBarColor.r, globalBarColor.g, globalBarColor.b, 1)
    end
    
    preview.Health = bar
    
    return preview
end

function CoreMixin:OnEvent(event, unit)
    if unit and unit ~= self.unit then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        self:UpdateAll()
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        self:UpdateHealth()
        self:UpdateHealthText()
    elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_PREDICTION" then
        self:UpdateHealPrediction()
    elseif event == "UNIT_PET" then
        if self.unit == "pet" then
            self:UpdateAll()
        end
    end
end

function CoreMixin:UpdateAll()
    self:UpdateHealth()
    self:UpdateHealthText()
    self:UpdatePower()
    self:UpdateName()
    self:UpdateAbsorbs()
    self:UpdateHealPrediction()
    self:UpdateTextLayout()
end

-- Stub - overridden by consuming plugins if needed
function CoreMixin:UpdatePower() end

-- Export for composition
UnitButton.CoreMixin = CoreMixin
