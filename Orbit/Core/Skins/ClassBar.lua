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

        -- Background (Inactive/Empty)
        btn.orbitBg = btn:CreateTexture(nil, "BACKGROUND")
        btn.orbitBg:SetAllPoints(btn)
        local bg = Orbit.Constants.Colors.Background
        btn.orbitBg:SetColorTexture(bg.r, bg.g, bg.b, bg.a) -- Standard Background

        -- Foreground (Active/Filled)
        btn.orbitBar = btn:CreateTexture(nil, "BORDER")
        btn.orbitBar:SetAllPoints(btn)

        -- Backdrop Frame for Border
        btn.orbitBackdrop = Skin:CreateBackdrop(btn, nil)
        btn.orbitBackdrop:SetFrameLevel(btn:GetFrameLevel() + 5) -- High level for border
    end

    -- Update Backdrop (Dynamic Size)
    local borderSize = settings.borderSize or 1
    Skin:SkinBorder(btn, btn.orbitBackdrop, borderSize, { r = 0, g = 0, b = 0, a = 1 })

    -- Setup Textures
    local texture = LSM:Fetch("statusbar", settings.texture or "Blizzard")
    btn.orbitBar:SetTexture(texture)
    local bg = Orbit.Constants.Colors.Background
    btn.orbitBg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    btn.orbitBar:SetVertexColor(1, 1, 1)

    -- HIDE NATIVE ART
    for _, region in ipairs({ btn:GetRegions() }) do
        if region ~= btn.orbitBg and region ~= btn.orbitBar and region ~= btn.orbitBackdrop then
            if region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
            end
        end
    end

    -- HANDLE NATIVE COOLDOWN (Runes)
    if btn.Cooldown then
        btn.Cooldown:SetAlpha(1)
        if btn.Cooldown.SetFrameLevel then
            btn.Cooldown:SetFrameLevel(btn:GetFrameLevel() + 2)
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

        -- Background (Inactive/Empty) - Applied to Container
        if not container.orbitBg then
            container.orbitBg = container:CreateTexture(nil, "BACKGROUND")
            container.orbitBg:SetAllPoints(container)
        end

        -- Backdrop Frame for Border
        if not container.orbitBackdrop then
            container.orbitBackdrop = Skin:CreateBackdrop(container, nil)
            container.orbitBackdrop:SetFrameLevel(container:GetFrameLevel() + 5)
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

    -- Background Color
    local bg = Orbit.Constants.Colors.Background
    if settings.backColor then
        bg = settings.backColor
    end
    container.orbitBg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)

    -- Ensure Bar Fills Container (No Inset)
    bar:ClearAllPoints()
    bar:SetAllPoints(container)
end
