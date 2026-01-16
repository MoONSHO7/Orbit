local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local CastBar = {}
Skin.CastBar = CastBar
local Constants = Orbit.Constants

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
    bar.Text:SetPoint("LEFT", bar, "LEFT", 5, 0)

    -- Timer Text
    bar.Timer = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.Timer:SetPoint("RIGHT", bar, "RIGHT", -5, 0)

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
    bar.SparkGlow:SetAlpha(0.4) -- Reduced opacity for subtler effect
    bar.SparkGlow:SetPoint("RIGHT", bar.Spark, "CENTER", 0, 0)
    -- Size will be set dynamically based on bar height in Apply

    -- Latency
    bar.Latency = bar:CreateTexture(nil, "ARTWORK")
    bar.Latency:SetColorTexture(1, 0, 0, 0.5)
    bar.Latency:Hide()

    -- Interrupt Overlay (White Flash)
    bar.InterruptOverlay = bar:CreateTexture(nil, "OVERLAY")
    bar.InterruptOverlay:SetAllPoints()
    bar.InterruptOverlay:SetColorTexture(1, 1, 1, 0.5)
    bar.InterruptOverlay:SetBlendMode("ADD")
    bar.InterruptOverlay:SetAlpha(0)

    -- Interrupt Animation
    local animGroup = bar.InterruptOverlay:CreateAnimationGroup()
    local alpha = animGroup:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(0.5)
    alpha:SetSmoothing("OUT")
    bar.InterruptAnim = animGroup

    -- Icon (Inside bar, left aligned)
    bar.Icon = bar:CreateTexture(nil, "ARTWORK", nil, 1) -- Sublevel 1 to sit above bar texture if needed, but usually bar texture is Border/Artwork. StatusBar texture is drawn at 'ARTWORK' usually.
    -- Wait, StatusBar texture is usually drawn at layer set by SetDrawLayer or default (ARTWORK).
    -- We want Icon ON TOP of StatusBar texture. OVERLAY?
    bar.Icon:SetDrawLayer("OVERLAY", 1)
    bar.Icon:SetSize(20, 20)
    bar.Icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    -- Icon Border
    bar.IconBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.IconBorder:SetAllPoints(bar.Icon)
    bar.IconBorder:SetFrameLevel(bar:GetFrameLevel() + 2) -- Ensure above bar border
    Skin:SkinBorder(bar, bar.IconBorder, 1, { r = 0, g = 0, b = 0, a = 1 })

    -- Empower Stage Markers (pool of dividers)
    bar.stageMarkers = {}
    for i = 1, 4 do -- Max 4 stages typically
        local marker = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        marker:SetColorTexture(0, 0, 0, 1)
        marker:SetSize(2, 1) -- Width 2px, height set dynamically
        marker:Hide()
        bar.stageMarkers[i] = marker
    end

    parent.orbitBar = bar
    parent.Latency = bar.Latency
    parent.InterruptOverlay = bar.InterruptOverlay
    parent.InterruptAnim = bar.InterruptAnim
    parent.Icon = bar.Icon
    return bar
end

function CastBar:Apply(bar, settings)
    if not bar then
        return
    end

    -- Calculate icon offset for bar fill
    local iconOffset = 0
    if settings.showIcon and bar.Icon then
        local height = bar:GetHeight()
        iconOffset = height -- Icon is square, width = height
    end

    -- Skin StatusBar (Texture & Color)
    Skin:SkinStatusBar(bar, settings.texture, settings.color)

    -- Adjust StatusBar texture to start after icon
    local statusBarTexture = bar:GetStatusBarTexture()
    if statusBarTexture then
        statusBarTexture:ClearAllPoints()
        statusBarTexture:SetPoint("TOPLEFT", bar, "TOPLEFT", iconOffset, 0)
        statusBarTexture:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", iconOffset, 0)
    end

    -- Skin Border
    if settings.borderSize and settings.borderSize > 0 then
        bar.Border:Show()
        Skin:SkinBorder(bar, bar.Border, settings.borderSize, { r = 0, g = 0, b = 0, a = 1 })
    else
        bar.Border:Hide()
    end

    -- Size SparkGlow based on bar height
    if bar.SparkGlow then
        local height = bar:GetHeight()
        bar.SparkGlow:SetSize(height * 2.5, height)
        
        if settings.sparkColor then
            local c = settings.sparkColor
            bar.SparkGlow:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        else
             bar.SparkGlow:SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Skin Background (also offset to not cover icon)
    if bar.bg then
        local backdropColor = settings.backdropColor or Constants.Colors.Background
        bar.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a or 0.5)
        bar.bg:ClearAllPoints()
        bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", iconOffset, 0)
        bar.bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    end

    -- Skin Text
    if bar.Text then
        if settings.showText then
            bar.Text:Show()
            bar.Text:ClearAllPoints()
            if settings.showIcon and bar.Icon then
                bar.Text:SetPoint("LEFT", bar.Icon, "RIGHT", 5, 0)
            else
                bar.Text:SetPoint("LEFT", bar, "LEFT", 5, 0)
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

    -- Skin Icon
    if bar.Icon then
        if settings.showIcon then
            bar.Icon:Show()
            local height = bar:GetHeight()
            bar.Icon:SetSize(height, height)
            
            if bar.IconBorder then
                bar.IconBorder:Show()
                if settings.borderSize and settings.borderSize > 0 then
                    Skin:SkinBorder(bar, bar.IconBorder, settings.borderSize, { r = 0, g = 0, b = 0, a = 1 })
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
