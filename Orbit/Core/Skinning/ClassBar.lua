local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local ClassBar = {}
Skin.ClassBar = ClassBar

local LSM = LibStub("LibSharedMedia-3.0")

function ClassBar:SkinButton(btn, settings)
    if not btn then
        return
    end

    if not btn.orbitRg then
        btn.orbitRg = true
        btn.orbitBg = btn:CreateTexture(nil, "BACKGROUND", nil, Orbit.Constants.Layers.BackdropDeep)
        btn.orbitBg:SetAllPoints(btn)
        btn.orbitBar = btn:CreateTexture(nil, "BORDER")
        btn.orbitBar:SetAllPoints(btn)
    end

    if btn.orbitBackdrop then btn.orbitBackdrop:Hide() end

    local scale = btn:GetEffectiveScale() or 1
    local borderSize = settings.borderSize or Orbit.Engine.Pixel:DefaultBorderSize(scale)
    Skin:SkinBorder(btn, btn, borderSize)

    local texture = LSM:Fetch("statusbar", settings.texture or "Blizzard")
    btn.orbitBar:SetTexture(texture)

    local bg = Orbit.Constants.Colors.Background
    if settings.backColor then
        bg = settings.backColor
    end
    btn.orbitBg:SetDrawLayer("BACKGROUND", Orbit.Constants.Layers.BackdropDeep)
    btn.orbitBg:SetColorTexture(bg.r, bg.g, bg.b, bg.a or 1)
    btn.orbitBar:SetVertexColor(1, 1, 1)

    for _, region in ipairs({ btn:GetRegions() }) do
        if region ~= btn.orbitBg and region ~= btn.orbitBar and region ~= btn.orbitBackdrop then
            if region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
            end
        end
    end

    -- Native button backdrop blocks alpha transparency; nuke it.
    if btn.SetBackdrop then
        btn:SetBackdrop(nil)
    end
    if btn.SetBackdropColor then
        btn:SetBackdropColor(0, 0, 0, 0)
    end

    if btn.Cooldown then
        btn.Cooldown:SetAlpha(1)
        if btn.Cooldown.SetFrameLevel then
            btn.Cooldown:SetFrameLevel(btn:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
        end
    end
end

function ClassBar:SkinStatusBar(container, bar, settings)
    if not container or not bar then
        return
    end

    if not container.orbitRg then
        container.orbitRg = true
        if not container.orbitBg then
            container.orbitBg = container:CreateTexture(nil, "BACKGROUND", nil, Orbit.Constants.Layers.BackdropDeep)
            container.orbitBg:SetAllPoints(container)
        end
    end

    if container.orbitBackdrop then container.orbitBackdrop:Hide() end

    local scale = container:GetEffectiveScale() or 1
    local borderSize = settings.borderSize or Orbit.Engine.Pixel:DefaultBorderSize(scale)
    Skin:SkinBorder(container, container, borderSize)

    if settings.texture then
        local texture = LSM:Fetch("statusbar", settings.texture)
        bar:SetStatusBarTexture(texture)
    end

    container.bg = container.orbitBg
    local globalSettings = Orbit.db.GlobalSettings or {}
    local fallback = settings.backColor or Orbit.Constants.Colors.Background
    Skin:ApplyGradientBackground(container, globalSettings.UnitFrameBackdropColourCurve, fallback)

    bar:ClearAllPoints()
    bar:SetAllPoints(container)
end
