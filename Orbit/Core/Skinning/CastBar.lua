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
    if not parent then
        return
    end

    if parent.orbitBar then
        return parent.orbitBar
    end

    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetAllPoints(parent)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetIgnoreParentAlpha(true)
    bar:SetClipsChildren(true) -- Clip SparkGlow so it doesn't extend outside bar

    -- Background
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    local bg = Constants.Colors.Background
    bar.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)

    -- Spell Name Text
    bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.Text:SetPoint("LEFT", bar, "LEFT", TEXT_H_PADDING, 0)

    -- Timer Text
    bar.Timer = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.Timer:SetPoint("RIGHT", bar, "RIGHT", -TEXT_H_PADDING, 0)

    -- Border
    bar.Border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.Border:SetAllPoints()
    bar.Border:SetFrameLevel(bar:GetFrameLevel() + 1)

    -- Spark (progress indicator pip - hidden, used as anchor for SparkGlow)
    bar.Spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
    bar.Spark:SetAtlas("ui-castingbar-pip")
    bar.Spark:SetSize(8, 20)
    bar.Spark:SetAlpha(0) -- Hidden - only used as anchor point for SparkGlow
    -- Note: Position is set dynamically in OnUpdate via SetPoint("CENTER", bar, "LEFT", sparkPos, 0)

    -- SparkGlow (Blizzard-style pip glow - trails behind the spark)
    bar.SparkGlow = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    bar.SparkGlow:SetAtlas("cast_standard_pipglow")
    bar.SparkGlow:SetBlendMode("ADD")
    bar.SparkGlow:SetAlpha(SPARK_GLOW_ALPHA)
    bar.SparkGlow:SetPoint("RIGHT", bar.Spark, "CENTER", 0, 0)
    -- Size will be set dynamically based on bar height in Apply

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

    -- Icon (Created on PARENT, positioned at parent's left edge - stays fixed while orbitBar moves)
    bar.Icon = parent:CreateTexture(nil, "ARTWORK", nil, Orbit.Constants.Layers.Icon)
    bar.Icon:SetDrawLayer("ARTWORK", Orbit.Constants.Layers.Icon)
    bar.Icon:SetSize(ICON_DEFAULT_SIZE, ICON_DEFAULT_SIZE)
    bar.Icon:SetPoint("LEFT", parent, "LEFT", 0, 0)
    bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    -- Icon Border (also on parent)
    bar.IconBorder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar.IconBorder:SetAllPoints(bar.Icon)
    bar.IconBorder:SetFrameLevel(bar:GetFrameLevel() + 2) -- Ensure above bar border
    Skin:SkinBorder(bar.IconBorder, bar.IconBorder, 1, { r = 0, g = 0, b = 0, a = 1 }, true)

    -- Empower Stage Markers (pool of dividers)
    bar.stageMarkers = {}
    for i = 1, 4 do -- Max 4 stages typically
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

    -- Hook parent's OnSizeChanged to update icon/bar positioning when dimensions change
    -- This is needed for anchor system dimension sync to properly update the icon size
    parent:HookScript("OnSizeChanged", function(self)
        local height = self:GetHeight()
        local scale = self:GetEffectiveScale()
        local snappedHeight = height
        if Orbit.Engine.Pixel then
            snappedHeight = Orbit.Engine.Pixel:Snap(height, scale)
        end

        if bar.Icon then
            bar.Icon:SetSize(snappedHeight, snappedHeight)
        end
        bar.iconOffset = snappedHeight

        bar:ClearAllPoints()
        if bar.Icon and bar.Icon:IsShown() then
            bar:SetPoint("TOPLEFT", self, "TOPLEFT", snappedHeight, 0)
            bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
        else
            bar:SetAllPoints(self)
        end
    end)

    return bar
end

function CastBar:Apply(bar, settings)
    if not bar then
        return
    end

    -- Calculate icon offset for bar fill (use parent's height since orbitBar may not have it yet)
    local parent = bar:GetParent()
    local iconOffset = 0
    if settings.showIcon and bar.Icon then
        local height = parent:GetHeight()
        local scale = parent:GetEffectiveScale()
        iconOffset = (Orbit.Engine.Pixel and Orbit.Engine.Pixel:Snap(height, scale)) or height
    end
    bar.iconOffset = iconOffset -- Store for spark position calculations

    -- Reposition the StatusBar itself to start after the icon
    -- WoW's StatusBar internally manages fill texture positioning, so we can't just offset the texture
    -- Instead, we resize/reposition the StatusBar to not overlap the icon area
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", bar:GetParent(), "TOPLEFT", iconOffset, 0)
    bar:SetPoint("BOTTOMRIGHT", bar:GetParent(), "BOTTOMRIGHT", 0, 0)

    -- Skin StatusBar (Texture & Color)
    Skin:SkinStatusBar(bar, settings.texture, settings.color)

    -- Skin Border (use horizontal layout since icon is to the left)
    if settings.borderSize and settings.borderSize > 0 then
        bar.Border:Show()
        Skin:SkinBorder(bar, bar.Border, settings.borderSize, { r = 0, g = 0, b = 0, a = 1 }, true)
    else
        bar.Border:Hide()
    end

    -- Size SparkGlow based on parent height
    if bar.SparkGlow then
        local height = parent:GetHeight()
        local scale = parent:GetEffectiveScale()
        bar.SparkGlow:SetSize(Orbit.Engine.Pixel:Snap(height * SPARK_GLOW_WIDTH_RATIO, scale), height)

        if settings.sparkColor then
            local c = settings.sparkColor
            bar.SparkGlow:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        else
            bar.SparkGlow:SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Skin Background (gradient-aware)
    if settings.backdropCurve then
        Skin:ApplyGradientBackground(bar, settings.backdropCurve, settings.backdropColor or Constants.Colors.Background)
    elseif bar.bg then
        local backdropColor = settings.backdropColor or Constants.Colors.Background
        bar.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a or 0.5)
        bar.bg:ClearAllPoints()
        bar.bg:SetAllPoints(bar)
    end

    -- Skin Text
    if bar.Text then
        if settings.showText then
            bar.Text:Show()
            bar.Text:ClearAllPoints()
            if settings.showIcon and bar.Icon then
                bar.Text:SetPoint("LEFT", bar.Icon, "RIGHT", TEXT_H_PADDING, 0)
            else
                bar.Text:SetPoint("LEFT", bar, "LEFT", TEXT_H_PADDING, 0)
            end
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

    -- Skin Icon (icon is on parent, so use parent height)
    if bar.Icon then
        if settings.showIcon then
            bar.Icon:Show()
            local height = parent:GetHeight()
            -- Snap icon size to pixel grid for crisp rendering
            local scale = parent:GetEffectiveScale()
            local snappedHeight = height
            if Orbit.Engine.Pixel then
                snappedHeight = Orbit.Engine.Pixel:Snap(height, scale)
            end
            bar.Icon:SetSize(snappedHeight, snappedHeight)

            if bar.IconBorder then
                bar.IconBorder:Show()
                if settings.borderSize and settings.borderSize > 0 then
                    -- Use horizontal layout for icon border (Top/Bottom full-width for horizontal merging)
                    Skin:SkinBorder(bar.IconBorder, bar.IconBorder, settings.borderSize, { r = 0, g = 0, b = 0, a = 1 }, true)
                    -- Hide cast bar's left border edge to merge with icon's right border
                    if bar.Border.Borders and bar.Border.Borders.Left then
                        bar.Border.Borders.Left:Hide()
                    end
                else
                    bar.IconBorder:Hide()
                end
            end
        else
            bar.Icon:Hide()
            if bar.IconBorder then
                bar.IconBorder:Hide()
            end
        end
    end
end
