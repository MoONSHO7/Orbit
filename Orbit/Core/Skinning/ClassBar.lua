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

    -- 1. Create Layers if missing
    if not btn.orbitRg then
        -- Mark as skinned
        btn.orbitRg = true

        -- Background (Inactive/Empty) - use deep sublayer like Icons.lua
        btn.orbitBg = btn:CreateTexture(nil, "BACKGROUND", nil, Orbit.Constants.Layers.BackdropDeep)
        btn.orbitBg:SetAllPoints(btn)

        -- Foreground (Active/Filled)
        btn.orbitBar = btn:CreateTexture(nil, "BORDER")
        btn.orbitBar:SetAllPoints(btn)

        -- Legacy orbitBackdrop no longer needed — SkinBorder creates _borderFrame
    end

    -- Hide stale backdrop from prior skin pass
    if btn.orbitBackdrop then btn.orbitBackdrop:Hide() end

    -- Update Border (Dynamic Size)
    local scale = btn:GetEffectiveScale() or 1
    local borderSize = settings.borderSize or Orbit.Engine.Pixel:DefaultBorderSize(scale)
    Skin:SkinBorder(btn, btn, borderSize)

    -- Setup Textures
    local texture = LSM:Fetch("statusbar", settings.texture or "Blizzard")
    btn.orbitBar:SetTexture(texture)

    -- Background Color - use provided backColor or fallback to constant
    local bg = Orbit.Constants.Colors.Background
    if settings.backColor then
        bg = settings.backColor
    end
    -- Ensure deep sublayer on every update (like Icons.lua)
    btn.orbitBg:SetDrawLayer("BACKGROUND", Orbit.Constants.Layers.BackdropDeep)
    btn.orbitBg:SetColorTexture(bg.r, bg.g, bg.b, bg.a or 1)
    btn.orbitBar:SetVertexColor(1, 1, 1)

    -- HIDE NATIVE ART
    for _, region in ipairs({ btn:GetRegions() }) do
        if region ~= btn.orbitBg and region ~= btn.orbitBar and region ~= btn.orbitBackdrop then
            if region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
            end
        end
    end

    -- Clear any backdrop on the button itself (blocks alpha transparency)
    if btn.SetBackdrop then
        btn:SetBackdrop(nil)
    end
    if btn.SetBackdropColor then
        btn:SetBackdropColor(0, 0, 0, 0)
    end

    -- HANDLE NATIVE COOLDOWN (Runes)
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

    -- 1. Create Layers if missing
    if not container.orbitRg then
        container.orbitRg = true

        -- Background (Inactive/Empty) - Applied to Container with deep sublayer like SkinButton
        if not container.orbitBg then
            container.orbitBg = container:CreateTexture(nil, "BACKGROUND", nil, Orbit.Constants.Layers.BackdropDeep)
            container.orbitBg:SetAllPoints(container)
        end

        -- Legacy orbitBackdrop no longer needed — SkinBorder creates _borderFrame
    end

    -- Hide stale backdrop from prior skin pass
    if container.orbitBackdrop then container.orbitBackdrop:Hide() end

    -- Update Border (Dynamic Size)
    local scale = container:GetEffectiveScale() or 1
    local borderSize = settings.borderSize or Orbit.Engine.Pixel:DefaultBorderSize(scale)
    Skin:SkinBorder(container, container, borderSize)

    -- Setup Textures
    if settings.texture then
        local texture = LSM:Fetch("statusbar", settings.texture)
        bar:SetStatusBarTexture(texture)
    end

    -- Background Color (gradient-aware)
    container.bg = container.orbitBg
    local globalSettings = Orbit.db.GlobalSettings or {}
    local fallback = settings.backColor or Orbit.Constants.Colors.Background
    Skin:ApplyGradientBackground(container, globalSettings.BackdropColourCurve, fallback)

    -- Ensure Bar Fills Container (No Inset)
    bar:ClearAllPoints()
    bar:SetAllPoints(container)
end
