local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local CastBar = {}
Skin.CastBar = CastBar
local Constants = Orbit.Constants
local Pixel = Orbit.Engine.Pixel

local EMPOWER_MARKER_WIDTH = 2
local SPARK_GLOW_ALPHA = 0.4
local ICON_DEFAULT_SIZE = 20
local TEXT_H_PADDING = 5
local INTERRUPT_FLASH_ALPHA = 0.5
local LATENCY_ALPHA = 0.5
local SPARK_GLOW_WIDTH_RATIO = 2.5
local INTERRUPT_FADE_DURATION = 0.5

local LSM = LibStub("LibSharedMedia-3.0")

function CastBar:Create(parent)
    if not parent then return end
    if parent.orbitBar then return parent.orbitBar end

    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetAllPoints(parent) -- Repositioned by UpdateBarInsets
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetIgnoreParentAlpha(true)
    bar:SetClipsChildren(true)

    -- Background on parent (fills behind borders, icon, and bar)
    parent.bg = parent:CreateTexture(nil, "BACKGROUND")
    parent.bg:SetAllPoints()
    local bg = Constants.Colors.Background
    parent.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)

    -- Text overlay frame (tracks inner bar — text coordinates are relative to content area after icon)
    bar.TextFrame = CreateFrame("Frame", nil, parent)
    bar.TextFrame:SetAllPoints(bar)
    bar.TextFrame:SetFrameLevel(bar:GetFrameLevel() + Constants.Levels.Overlay)

    -- Spell Name Text
    bar.Text = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.Text:SetPoint("LEFT", bar, "LEFT", TEXT_H_PADDING, 0)

    -- Timer Text
    bar.Timer = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.Timer:SetPoint("RIGHT", bar, "RIGHT", -TEXT_H_PADDING, 0)

    -- Spark (progress indicator pip)
    bar.Spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
    bar.Spark:SetAtlas("ui-castingbar-pip")
    bar.Spark:SetSize(8, 20)
    bar.Spark:SetAlpha(0)

    -- SparkGlow (Blizzard-style pip glow)
    bar.SparkGlow = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    bar.SparkGlow:SetAtlas("cast_standard_pipglow")
    bar.SparkGlow:SetBlendMode("ADD")
    bar.SparkGlow:SetAlpha(SPARK_GLOW_ALPHA)
    bar.SparkGlow:SetPoint("RIGHT", bar.Spark, "CENTER", 0, 0)

    -- Latency
    bar.Latency = bar:CreateTexture(nil, "ARTWORK")
    bar.Latency:SetColorTexture(1, 0, 0, LATENCY_ALPHA)
    bar.Latency:Hide()

    -- Interrupt Overlay (White Flash)
    bar.InterruptOverlay = bar:CreateTexture(nil, "OVERLAY")
    bar.InterruptOverlay:SetAllPoints()
    bar.InterruptOverlay:SetColorTexture(1, 1, 1, INTERRUPT_FLASH_ALPHA)
    bar.InterruptOverlay:SetBlendMode("ADD")
    bar.InterruptOverlay:SetAlpha(0)

    -- Interrupt Animation
    local animGroup = bar.InterruptOverlay:CreateAnimationGroup()
    local alpha = animGroup:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(INTERRUPT_FADE_DURATION)
    alpha:SetSmoothing("OUT")
    bar.InterruptAnim = animGroup

    -- Icon (on parent, positioned by UpdateBarInsets)
    bar.Icon = parent:CreateTexture(nil, "ARTWORK", nil, Orbit.Constants.Layers.Icon)
    bar.Icon:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Icon)
    bar.Icon:SetSize(ICON_DEFAULT_SIZE, ICON_DEFAULT_SIZE)
    bar.Icon:SetPoint("LEFT", parent, "LEFT", 0, 0)
    bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)



    -- Empower Stage Markers
    bar.stageMarkers = {}
    for i = 1, 4 do
        local marker = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        marker:SetColorTexture(0, 0, 0, 1)
        marker:SetSize(Pixel:Multiple(EMPOWER_MARKER_WIDTH), 1)
        marker:Hide()
        bar.stageMarkers[i] = marker
    end

    parent.orbitBar = bar
    parent.Latency = bar.Latency
    parent.InterruptOverlay = bar.InterruptOverlay
    parent.InterruptAnim = bar.InterruptAnim
    parent.Icon = bar.Icon

    -- [ BORDER MANAGEMENT (matches UnitButtonCanvas pattern) ]---------------------------------------
    parent.SetBorder = function(self, size)
        Orbit.Skin:SkinBorder(self, self, size)
        self:UpdateBarInsets()
    end

    parent.SetBorderHidden = Orbit.Skin.DefaultSetBorderHidden

    parent.UpdateBarInsets = function(self)
        local b = self.orbitBar
        if not b then return end
        local height = self:GetHeight()
        local scale = self:GetEffectiveScale()
        local showIcon = b.Icon and b.Icon:IsShown()
        local iconSize = showIcon and Pixel:Snap(height, scale) or 0
        local iconAtEnd = b._iconAtEnd
        if b.Icon then
            b.Icon:ClearAllPoints()
            b.Icon:SetSize(iconSize, iconSize)
            b.Icon:SetPoint(iconAtEnd and "TOPRIGHT" or "TOPLEFT", self, iconAtEnd and "TOPRIGHT" or "TOPLEFT", 0, 0)
        end

        b.iconOffset = iconSize
        b:ClearAllPoints()
        if iconAtEnd then
            b:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
            b:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -iconSize, 0)
        else
            b:SetPoint("TOPLEFT", self, "TOPLEFT", iconSize, 0)
            b:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
        end
    end

    parent:HookScript("OnSizeChanged", function(self) self:UpdateBarInsets() end)

    return bar
end

function CastBar:Apply(bar, settings)
    if not bar then return end
    local parent = bar:GetParent()

    -- Skin StatusBar (Texture & Color)
    Skin:SkinStatusBar(bar, settings.texture, settings.color)

    -- Icon visibility and side (must be set before UpdateBarInsets since it affects layout)
    bar._iconAtEnd = settings.iconAtEnd and true or false
    if bar.Icon then
        if settings.showIcon then
            bar.Icon:Show()
            bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        else
            bar.Icon:Hide()
        end
    end

    -- Apply borders on parent frame and inset content
    parent:SetBorder(settings.borderSize or 0)

    -- SparkGlow sizing (based on inner bar height after insets)
    if bar.SparkGlow then
        local barHeight = bar:GetHeight()
        local scale = parent:GetEffectiveScale()
        bar.SparkGlow:SetSize(Pixel:Snap(barHeight * SPARK_GLOW_WIDTH_RATIO, scale), barHeight)
        if settings.sparkColor then
            local c = settings.sparkColor
            bar.SparkGlow:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        else
            bar.SparkGlow:SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Skin Background
    if settings.backdropCurve then
        Skin:ApplyGradientBackground(parent, settings.backdropCurve, settings.backdropColor or Constants.Colors.Background)
    elseif parent.bg then
        local backdropColor = settings.backdropColor or Constants.Colors.Background
        parent.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a or 0.5)
    end

    -- Skin Text (visibility controlled by Canvas Mode)
    if bar.Text then
        Skin:SkinText(bar.Text, settings)
    end

    -- Skin Timer (visibility controlled by Canvas Mode)
    if bar.Timer then
        Skin:SkinText(bar.Timer, settings)
    end
end
