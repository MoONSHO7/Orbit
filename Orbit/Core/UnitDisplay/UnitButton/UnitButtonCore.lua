-- [ UNIT BUTTON - CORE MODULE ]---------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

local SMOOTH_ANIM = Enum.StatusBarInterpolation.ExponentialEaseOut
local PREVIEW_HEALTH_VALUE = 0.75
local HEALTH_BAR_LEVEL_OFFSET = 2
local _, PLAYER_CLASS = UnitClass("player")

-- [ CORE MIXIN ]------------------------------------------------------------------------------------

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

    if Orbit.EventBus then
        Orbit.EventBus:On("ORBIT_NICKNAME_UPDATED", function() self:UpdateName() end)
    end

    self:UpdateAll()
end

function CoreMixin:CreateCanvasPreview(options)
    options = options or {}
    local parent = options.parent or UIParent
    local globalSettings = Orbit.db.GlobalSettings
    local borderSize = globalSettings.BorderSize or 0
    local textureName = options.textureName or globalSettings.Texture
    local width = self:GetWidth()
    local height = self:GetHeight()

    -- [ CONTAINER ]-------------------------------------------------------------------------------------
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetSize(width, height)
    preview.sourceFrame = self
    preview.sourceWidth = width
    preview.sourceHeight = height
    preview.previewScale = 1
    preview.components = {}

    -- [ BACKGROUND ]------------------------------------------------------------------------------------
    preview.bg = preview:CreateTexture(nil, "BACKGROUND", nil, Orbit.Constants.Layers.BackdropDeep)
    preview.bg:SetAllPoints()
    Orbit.Skin:ApplyGradientBackground(preview, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)

    -- [ BORDERS ]----------------------------------------------------------------------------------------
    Orbit.Skin:SkinBorder(preview, preview, borderSize)

    -- [ HEALTH BAR ]-------------------------------------------------------------------------------------
    local bar = CreateFrame("StatusBar", nil, preview)
    bar:SetPoint("TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(PREVIEW_HEALTH_VALUE)
    bar:SetFrameLevel(preview:GetFrameLevel() + HEALTH_BAR_LEVEL_OFFSET)
    Orbit.Skin:SkinStatusBar(bar, textureName, nil, true)

    -- The cleric inspects the health bar's aura for class-colored enchantments
    local barCurve = globalSettings.BarColorCurve
    local barColor
    if barCurve and barCurve.pins and #barCurve.pins > 0 then
        local hasClassPin = Engine.ColorCurve:CurveHasClassPin(barCurve)
        if hasClassPin then
            local classColor = RAID_CLASS_COLORS[PLAYER_CLASS]
            if classColor then barColor = { r = classColor.r, g = classColor.g, b = classColor.b } end
        end
    end
    barColor = barColor or Engine.ColorCurve:GetFirstColorFromCurve(barCurve)
    if barColor then bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 1) end
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

-- The fighter shouts "I check EVERYTHING" at the start of every encounter
function CoreMixin:UpdatePower() end

UnitButton.CoreMixin = CoreMixin
