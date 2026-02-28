-- [ CANVAS MODE - ICON FRAME CREATOR ]--------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local CC = CanvasMode.CreatorConstants
local GetSourceSize = CanvasMode.GetSourceSize

-- [ CREATOR ]---------------------------------------------------------------------------------------

local function Create(container, preview, key, source, data)
    local iconTexture = source.Icon
    local hasFlipbook = iconTexture and iconTexture.orbitPreviewTexCoord
    local visual

    if hasFlipbook then
        visual = container:CreateTexture(nil, "OVERLAY")
        visual:SetAllPoints(container)
        local atlasName = iconTexture.GetAtlas and iconTexture:GetAtlas()
        if atlasName then visual:SetAtlas(atlasName, false)
        elseif iconTexture:GetTexture() then visual:SetTexture(iconTexture:GetTexture()) end
        local tc = iconTexture.orbitPreviewTexCoord
        visual:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    else
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetAllPoints(container)
        btn:EnableMouse(false)
        btn.Icon = btn:CreateTexture(nil, "ARTWORK")
        btn.Icon:SetAllPoints()
        btn.icon = btn.Icon

        local texturePath = iconTexture and iconTexture:GetTexture()
        local StatusMixin = Orbit.StatusIconMixin
        if texturePath then
            btn.Icon:SetTexture(texturePath)
        elseif StatusMixin and key == "DefensiveIcon" then
            btn.Icon:SetTexture(StatusMixin:GetDefensiveTexture())
        elseif StatusMixin and key == "CrowdControlIcon" then
            btn.Icon:SetTexture(StatusMixin:GetCrowdControlTexture())
        elseif StatusMixin and key == "PrivateAuraAnchor" then
            btn.Icon:SetTexture(StatusMixin:GetPrivateAuraTexture())
        else
            local previewAtlases = Orbit.IconPreviewAtlases or {}
            if previewAtlases[key] then btn.Icon:SetAtlas(previewAtlases[key], false)
            else btn.Icon:SetColorTexture(CC.FALLBACK_GRAY[1], CC.FALLBACK_GRAY[2], CC.FALLBACK_GRAY[3], CC.FALLBACK_GRAY[4]) end
        end

        local scale = btn:GetEffectiveScale() or 1
        local globalBorder = Orbit.db.GlobalSettings.BorderSize or Orbit.Engine.Pixel:DefaultBorderSize(scale)
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons:ApplyCustom(btn, { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false })
        end

        visual = btn
        container.isIconFrame = true
    end

    local w, h = GetSourceSize(source, CC.DEFAULT_ICON_SIZE, CC.DEFAULT_ICON_SIZE)
    container:SetSize(w, h)

    return visual
end

CanvasMode:RegisterCreator("IconFrame", Create)
