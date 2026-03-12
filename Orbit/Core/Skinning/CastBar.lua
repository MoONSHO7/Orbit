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

    -- Spell Name Text
    bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.Text:SetPoint("LEFT", bar, "LEFT", TEXT_H_PADDING, 0)

    -- Timer Text
    bar.Timer = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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

    -- Icon Border (visual divider between icon and bar)
    bar.IconBorder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar.IconBorder:SetAllPoints(bar.Icon)
    bar.IconBorder:SetFrameLevel(bar:GetFrameLevel() + 2)
    Skin:SkinBorder(bar.IconBorder, bar.IconBorder, 1, nil, true)

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
        if Orbit.Skin:SkinBorder(self, self, size, nil, true) then
            self.borderPixelSize = 0
            self:UpdateBarInsets()
            return
        end
        self:UpdateBarInsets()
    end

    parent.SetBorderHidden = function(self, edge, hidden)
        local borders = (self._borderFrame and self._borderFrame.Borders) or self.Borders
        if not borders then return end
        local border = borders[edge]
        if border then border:SetShown(not hidden) end
        if not self._mergedEdges then self._mergedEdges = {} end
        self._mergedEdges[edge] = hidden or nil
        self:UpdateBarInsets()
    end

    parent.UpdateBarInsets = function(self)
        local bs = self.borderPixelSize or 0
        local iL, iT, iR, iB = bs, bs, bs, bs
        if self._mergedEdges then
            if self._mergedEdges.Left then iL = 0 end
            if self._mergedEdges.Right then iR = 0 end
            if self._mergedEdges.Top then iT = 0 end
            if self._mergedEdges.Bottom then iB = 0 end
        end
        local b = self.orbitBar
        if not b then return end
        local height = self:GetHeight()
        local scale = self:GetEffectiveScale()
        local showIcon = b.Icon and b.Icon:IsShown()
        local iconSize = showIcon and Pixel:Snap(height - iT - iB, scale) or 0
        if b.Icon then
            b.Icon:ClearAllPoints()
            b.Icon:SetSize(iconSize, iconSize)
            b.Icon:SetPoint("TOPLEFT", self, "TOPLEFT", iL, -iT)
        end
        if b.IconBorder then
            b.IconBorder:ClearAllPoints()
            b.IconBorder:SetAllPoints(b.Icon)
        end
        b.iconOffset = iconSize
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self, "TOPLEFT", iL + iconSize, -iT)
        b:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -iR, iB)
    end

    parent:HookScript("OnSizeChanged", function(self) self:UpdateBarInsets() end)

    return bar
end

function CastBar:Apply(bar, settings)
    if not bar then return end
    local parent = bar:GetParent()

    -- Skin StatusBar (Texture & Color)
    Skin:SkinStatusBar(bar, settings.texture, settings.color)

    -- Icon visibility (must be set before UpdateBarInsets since it affects layout)
    if bar.Icon then
        if settings.showIcon then
            bar.Icon:Show()
            bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
            if bar.IconBorder and settings.borderSize and settings.borderSize > 0 then
                bar.IconBorder:Show()
                Skin:SkinBorder(bar.IconBorder, bar.IconBorder, settings.borderSize, nil, true)
            elseif bar.IconBorder then
                bar.IconBorder:Hide()
            end
        else
            bar.Icon:Hide()
            if bar.IconBorder then bar.IconBorder:Hide() end
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

    -- Skin Text
    if bar.Text then
        if settings.showText then
            bar.Text:Show()
            bar.Text:ClearAllPoints()
            bar.Text:SetPoint("LEFT", bar, "LEFT", TEXT_H_PADDING, 0)
            Skin:SkinText(bar.Text, settings)
        else
            bar.Text:Hide()
        end
    end

    -- Skin Timer
    if bar.Timer then
        if settings.showTimer then
            bar.Timer:Show()
            Skin:SkinText(bar.Timer, settings)
        else
            bar.Timer:Hide()
        end
    end
end
