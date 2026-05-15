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
local SPARK_WIDTH = 8
local SPARK_HEIGHT = 20
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
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetIgnoreParentAlpha(true)
    bar:SetClipsChildren(true)

    parent.bg = parent:CreateTexture(nil, "BACKGROUND")
    parent.bg:SetAllPoints()
    local bg = Constants.Colors.Background
    parent.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    Skin:RegisterMaskedSurface(parent, parent.bg)
    Skin:RegisterMaskedSurface(parent, bar:GetStatusBarTexture())

    bar.TextFrame = CreateFrame("Frame", nil, parent)
    bar.TextFrame:SetAllPoints(bar)
    bar.TextFrame:SetFrameLevel(bar:GetFrameLevel() + Constants.Levels.Overlay)

    local barScale = bar:GetEffectiveScale()
    bar.Text = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.Text:SetPoint("LEFT", bar, "LEFT", Pixel:Multiple(TEXT_H_PADDING, barScale), 0)

    bar.Timer = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.Timer:SetPoint("RIGHT", bar, "RIGHT", Pixel:Multiple(-TEXT_H_PADDING, barScale), 0)

    bar.Spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
    bar.Spark:SetAtlas("ui-castingbar-pip")
    bar.Spark:SetSize(Pixel:Snap(SPARK_WIDTH, barScale), Pixel:Snap(SPARK_HEIGHT, barScale))
    bar.Spark:SetAlpha(0)
    Skin:RegisterMaskedSurface(parent, bar.Spark)

    bar.SparkGlow = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    bar.SparkGlow:SetAtlas("cast_standard_pipglow")
    bar.SparkGlow:SetBlendMode("ADD")
    bar.SparkGlow:SetAlpha(SPARK_GLOW_ALPHA)
    bar.SparkGlow:SetPoint("RIGHT", bar.Spark, "CENTER", 0, 0)
    Skin:RegisterMaskedSurface(parent, bar.SparkGlow)

    bar.Latency = bar:CreateTexture(nil, "ARTWORK")
    bar.Latency:SetColorTexture(1, 0, 0, LATENCY_ALPHA)
    bar.Latency:Hide()
    Skin:RegisterMaskedSurface(parent, bar.Latency)

    bar.InterruptOverlay = bar:CreateTexture(nil, "OVERLAY")
    bar.InterruptOverlay:SetAllPoints()
    bar.InterruptOverlay:SetColorTexture(1, 1, 1, INTERRUPT_FLASH_ALPHA)
    bar.InterruptOverlay:SetBlendMode("ADD")
    bar.InterruptOverlay:SetAlpha(0)
    Skin:RegisterMaskedSurface(parent, bar.InterruptOverlay)

    local animGroup = bar.InterruptOverlay:CreateAnimationGroup()
    local alpha = animGroup:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(INTERRUPT_FADE_DURATION)
    alpha:SetSmoothing("OUT")
    bar.InterruptAnim = animGroup

    bar.Icon = parent:CreateTexture(nil, "ARTWORK", nil, Orbit.Constants.Layers.Icon)
    bar.Icon:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Icon)
    bar.Icon:SetSize(Pixel:Snap(ICON_DEFAULT_SIZE, barScale), Pixel:Snap(ICON_DEFAULT_SIZE, barScale))
    bar.Icon:SetPoint("LEFT", parent, "LEFT", 0, 0)
    bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    Skin:RegisterMaskedSurface(parent, bar.Icon)

    bar.stageMarkers = {}
    for i = 1, 4 do
        local marker = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        marker:SetColorTexture(0, 0, 0, 1)
        marker:SetSize(Pixel:Multiple(EMPOWER_MARKER_WIDTH, barScale), Pixel:Multiple(1, barScale))
        marker:Hide()
        bar.stageMarkers[i] = marker
    end

    parent.orbitBar = bar
    parent.Latency = bar.Latency
    parent.InterruptOverlay = bar.InterruptOverlay
    parent.InterruptAnim = bar.InterruptAnim
    parent.Icon = bar.Icon

    -- [ BORDER MANAGEMENT ]------------------------------------------------------------------------
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

    Skin:SkinStatusBar(bar, settings.texture, settings.color)

    -- iconAtEnd must be set before UpdateBarInsets — drives bar/icon anchor side.
    bar._iconAtEnd = settings.iconAtEnd and true or false
    if bar.Icon then
        if settings.showIcon then
            bar.Icon:Show()
            bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        else
            bar.Icon:Hide()
        end
    end

    parent:SetBorder(settings.borderSize or 0)

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

    if settings.backdropCurve then
        Skin:ApplyGradientBackground(parent, settings.backdropCurve, settings.backdropColor or Constants.Colors.Background)
    elseif parent.bg then
        local backdropColor = settings.backdropColor or Constants.Colors.Background
        parent.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a or 0.5)
    end

    if bar.Text then
        Skin:SkinText(bar.Text, settings)
    end

    if bar.Timer then
        Skin:SkinText(bar.Timer, settings)
    end
end
