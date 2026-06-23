local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local LSM = LibStub("LibSharedMedia-3.0")

-- tile = true: repeats at native pixel size so detail holds a constant on-screen scale; omit for gradients (Gloss).
local OVERLAY_RENDER = {
    ["Orbit Gloss Overlay"]  = { blend = "ADD",   alpha = 1.0 },
    ["Orbit Frost Overlay"]  = { blend = "BLEND", alpha = 1.0, tile = true },
    ["Orbit Galaxy Overlay"] = { blend = "BLEND", alpha = 1.0, tile = true },
    ["Orbit Starfield Overlay"] = { blend = "BLEND", alpha = 1.0, tile = true },
}
local OVERLAY_DEFAULT = { blend = "ADD", alpha = 0.5 }

local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"

local TILING_FILLS = {}

-- [ STATUSBAR SKINNING ]-----------------------------------------------------------------------------
function Skin:SkinStatusBar(bar, textureName, color)
    if not bar then
        return
    end

    local texture = LSM:Fetch("statusbar", textureName or "Blizzard")
    bar:SetStatusBarTexture(texture)

    if color then
        bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    end

    -- Overlay logic

    -- Get overlay texture from settings
    local overlayTextureName = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.OverlayTexture or "None"
    if overlayTextureName == "None" then
        if bar.Overlay then bar.Overlay:Hide() end
        return
    end
    local overlayPath = LSM:Fetch("statusbar", overlayTextureName)
    if not overlayPath then
        if bar.Overlay then bar.Overlay:Hide() end
        return
    end
    local render = OVERLAY_RENDER[overlayTextureName] or OVERLAY_DEFAULT
    self:AddOverlay(bar, overlayPath, render.blend, render.alpha, render.tile)
end

function Skin:AddOverlay(bar, texturePath, blendMode, alpha, tile)
    if not bar then
        return
    end

    if not bar.Overlay then
        bar.Overlay = bar:CreateTexture(nil, "OVERLAY")
        bar.Overlay:SetAllPoints(bar)
    end

    -- No path: just ensure the overlay texture exists (so a caller can mask-register it), hidden.
    if not texturePath then
        bar.Overlay:Hide()
        return
    end

    local overlay = bar.Overlay
    -- Overlay is reused: tiling sets REPEAT + SetHoriz/VertTile; non-tiling must reset BOTH and restore SetTexCoord(0,1,0,1) or stale texcoords linger and the next overlay samples only a sliver.
    if tile then
        overlay:SetTexture(texturePath, "REPEAT", "REPEAT")
        overlay:SetHorizTile(true)
        overlay:SetVertTile(true)
    else
        overlay:SetHorizTile(false)
        overlay:SetVertTile(false)
        overlay:SetTexture(texturePath)
        overlay:SetTexCoord(0, 1, 0, 1)
    end
    overlay:SetBlendMode(blendMode or "BLEND")
    overlay:SetAlpha(alpha or 1)
    overlay:Show()
end

-- TILING_FILLS textures draw via the bar's TiledPattern (clip-masked, MOD-blended over a white fill SetStatusBarColor tints) instead of stretching — same render math, no pattern shearing.
function Skin:ApplyAbsorbTexture(bar, textureName)
    if not bar then
        return
    end

    if TILING_FILLS[textureName] and bar.TiledPattern then
        bar:SetStatusBarTexture(WHITE8x8)
        local pat = bar.TiledPattern
        -- UV-repeat tiling (REPEAT wrap + TexCoord > 1), NOT SetHorizTile, so the pattern stays maskable and rounds under a rounded border.
        pat:SetTexture(LSM:Fetch("statusbar", textureName), "REPEAT", "REPEAT")
        if pat.tileCoordX then
            pat:SetTexCoord(0, pat.tileCoordX, 0, pat.tileCoordY)
        end
        pat:Show()
    else
        bar:SetStatusBarTexture(LSM:Fetch("statusbar", textureName or "Blizzard") or LSM:Fetch("statusbar", "Blizzard"))
        if bar.TiledPattern then
            bar.TiledPattern:Hide()
        end
    end
end
