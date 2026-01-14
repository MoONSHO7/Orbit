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
    return bar
end

function CastBar:Apply(bar, settings)
    if not bar then
        return
    end

    -- Skin StatusBar (Texture & Color)
    Skin:SkinStatusBar(bar, settings.texture, settings.color)

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
    end

    -- Skin Background
    if bar.bg then
        local backdropColor = settings.backdropColor or Constants.Colors.Background
        bar.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a or 0.5)
    end

    -- Skin Text
    if bar.Text then
        if settings.showText then
            bar.Text:Show()
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
