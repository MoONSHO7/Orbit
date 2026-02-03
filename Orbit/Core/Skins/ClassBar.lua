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

        -- Backdrop Frame for Border (just for line borders, NO background)
        btn.orbitBackdrop = Skin:CreateBackdrop(btn, nil)
        btn.orbitBackdrop:SetFrameLevel(btn:GetFrameLevel() + Orbit.Constants.Levels.Highlight)
        -- Clear any backdrop that might come from BackdropTemplate
        if btn.orbitBackdrop.SetBackdrop then
            btn.orbitBackdrop:SetBackdrop(nil)
        end
    end

    -- Update Backdrop (Dynamic Size)
    local borderSize = settings.borderSize or 1
    Skin:SkinBorder(btn, btn.orbitBackdrop, borderSize, { r = 0, g = 0, b = 0, a = 1 })

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
            btn.Cooldown:SetFrameLevel(btn:GetFrameLevel() + Orbit.Constants.Levels.Cooldown)
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

        -- Backdrop Frame for Border (just for line borders, NO background)
        if not container.orbitBackdrop then
            container.orbitBackdrop = Skin:CreateBackdrop(container, nil)
            container.orbitBackdrop:SetFrameLevel(container:GetFrameLevel() + Orbit.Constants.Levels.Highlight)
            -- Clear any backdrop that might come from BackdropTemplate
            if container.orbitBackdrop.SetBackdrop then
                container.orbitBackdrop:SetBackdrop(nil)
            end
        end
    end

    -- Update Backdrop (Dynamic Size)
    local borderSize = settings.borderSize or 1
    Skin:SkinBorder(container, container.orbitBackdrop, borderSize, { r = 0, g = 0, b = 0, a = 1 })

    -- Setup Textures
    if settings.texture then
        local texture = LSM:Fetch("statusbar", settings.texture)
        bar:SetStatusBarTexture(texture)
    end

    -- Background Color - use provided backColor or fallback to constant
    local bg = Orbit.Constants.Colors.Background
    if settings.backColor then
        bg = settings.backColor
    end
    -- Ensure deep sublayer on every update (like SkinButton)
    container.orbitBg:SetDrawLayer("BACKGROUND", Orbit.Constants.Layers.BackdropDeep)
    container.orbitBg:SetColorTexture(bg.r, bg.g, bg.b, bg.a or 1)

    -- Ensure Bar Fills Container (No Inset)
    bar:ClearAllPoints()
    bar:SetAllPoints(container)
end
