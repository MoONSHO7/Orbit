local _, addonTable = ...
local Orbit = addonTable
---@class OrbitSkin
Orbit.Skin = {}
local Skin = Orbit.Skin
local Engine = Orbit.Engine -- Added Engine reference
local LSM = LibStub("LibSharedMedia-3.0")
local Constants = Orbit.Constants

-- -------------------------------------------------------------------------- --
-- Utilities
-- -------------------------------------------------------------------------- --

function Skin:GetPixelScale()
    return Engine.Pixel:GetScale()
end

-- -------------------------------------------------------------------------- --
-- Icon Skinning
-- -------------------------------------------------------------------------- --

function Skin:SkinIcon(icon, settings)
    if not icon then
        return
    end
    if not icon.SetTexCoord then
        return
    end -- Safety check

    local zoom = settings.zoom or 0
    local trim = Constants.Texture.BlizzardIconBorderTrim
    trim = trim + ((zoom / 100) / 2)

    local left, right, top, bottom = trim, 1 - trim, trim, 1 - trim
    icon:SetTexCoord(left, right, top, bottom)
end

-- -------------------------------------------------------------------------- --
-- Border Skinning
-- -------------------------------------------------------------------------- --

function Skin:CreateBackdrop(frame, name)
    local backdrop = CreateFrame("Frame", name, frame, "BackdropTemplate")
    backdrop:SetAllPoints(frame)
    return backdrop
end

function Skin:SkinBorder(frame, backdrop, size, color, horizontal)
    if not frame or not backdrop then
        return
    end

    local targetSize = size or 1

    -- Handle Hidden/Zero Border
    if targetSize <= 0 then
        if backdrop.Borders then
            for _, border in pairs(backdrop.Borders) do
                border:Hide()
            end
        end
        return true
    end

    local pixelScale = self:GetPixelScale()
    local scale = frame:GetEffectiveScale()
    if not scale or scale < 0.01 then
        scale = 1
    end

    local mult = pixelScale / scale
    local pixelSize = targetSize * mult
    frame.borderPixelSize = pixelSize -- Store for Anchor:ApplyAnchorPosition

    -- Create borders if needed
    if not backdrop.Borders then
        backdrop.Borders = {}
        local function CreateLine()
            local t = backdrop:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(1, 1, 1, 1) -- Set white initially, tinted by color arg
            return t
        end
        backdrop.Borders.Top = CreateLine()
        backdrop.Borders.Bottom = CreateLine()
        backdrop.Borders.Left = CreateLine()
        backdrop.Borders.Right = CreateLine()
    end

    -- Attach SetBorderHidden to the owner frame if missing
    -- This allows the Anchor engine to toggle border visibility during merging
    if not frame.SetBorderHidden then
        frame.SetBorderHidden = function(self, edge, hidden)
            local b = backdrop.Borders
            if b and b[edge] then
                b[edge]:SetShown(not hidden)
            end
        end
    end

    local c = color or { r = 0, g = 0, b = 0, a = 1 }
    for _, t in pairs(backdrop.Borders) do
        t:SetColorTexture(c.r, c.g, c.b, c.a)
        t:Show() -- Ensure visible
    end

    local b = backdrop.Borders

    -- Non-overlapping Layout
    -- horizontal = true: Top/Bottom full width (for horizontal arrangements like icon → bar)
    -- horizontal = false/nil: Left/Right full height (for vertical stacking like health → power)
    if horizontal then
        -- Top/Bottom: Full Width (Priority for horizontal merging)
        b.Top:ClearAllPoints()
        b.Top:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
        b.Top:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
        b.Top:SetHeight(pixelSize)

        b.Bottom:ClearAllPoints()
        b.Bottom:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
        b.Bottom:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        b.Bottom:SetHeight(pixelSize)

        -- Left/Right: Inset by Top/Bottom height
        b.Left:ClearAllPoints()
        b.Left:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, -pixelSize)
        b.Left:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, pixelSize)
        b.Left:SetWidth(pixelSize)

        b.Right:ClearAllPoints()
        b.Right:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, -pixelSize)
        b.Right:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, pixelSize)
        b.Right:SetWidth(pixelSize)
    else
        -- Left/Right: Full Height (Priority for vertical stacking)
        b.Left:ClearAllPoints()
        b.Left:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
        b.Left:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
        b.Left:SetWidth(pixelSize)

        b.Right:ClearAllPoints()
        b.Right:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
        b.Right:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        b.Right:SetWidth(pixelSize)

        -- Top/Bottom: Inset by Left/Right width
        b.Top:ClearAllPoints()
        b.Top:SetPoint("TOPLEFT", backdrop, "TOPLEFT", pixelSize, 0)
        b.Top:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -pixelSize, 0)
        b.Top:SetHeight(pixelSize)

        b.Bottom:ClearAllPoints()
        b.Bottom:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", pixelSize, 0)
        b.Bottom:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -pixelSize, 0)
        b.Bottom:SetHeight(pixelSize)
    end
    return false
end

-- -------------------------------------------------------------------------- --
-- StatusBar Skinning
-- -------------------------------------------------------------------------- --

function Skin:SkinStatusBar(bar, textureName, color)
    if not bar then
        return
    end

    local texture = LSM:Fetch("statusbar", textureName or "Blizzard")
    bar:SetStatusBarTexture(texture)

    if color then
        bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    end

    local overlayPath = "Interface\\AddOns\\Orbit\\Core\\assets\\Statusbar\\orbit-left-right.tga"
    self:AddOverlay(bar, overlayPath, "BLEND", 0.5)
end

function Skin:AddOverlay(bar, texturePath, blendMode, alpha)
    if not bar then
        return
    end

    if not bar.Overlay then
        bar.Overlay = bar:CreateTexture(nil, "OVERLAY")
        -- If it's a StatusBar, anchor to the status bar texture so it only covers the fill
        if bar.GetStatusBarTexture then
            local statusTexture = bar:GetStatusBarTexture()
            if statusTexture then
                bar.Overlay:SetAllPoints(statusTexture)
            else
                bar.Overlay:SetAllPoints(bar)
            end
        else
            bar.Overlay:SetAllPoints(bar)
        end
    end

    bar.Overlay:SetTexture(texturePath)
    bar.Overlay:SetBlendMode(blendMode or "BLEND")
    bar.Overlay:SetAlpha(alpha or 1)
end

-- -------------------------------------------------------------------------- --
-- Font Skinning
-- -------------------------------------------------------------------------- --

function Skin:SkinText(fontString, settings)
    if not fontString then
        return
    end

    local size = settings.textSize or 12

    local font = "Fonts\\FRIZQT__.TTF"
    if settings.font then
        font = LSM:Fetch("font", settings.font) or font
    end

    fontString:SetFont(font, size, "OUTLINE")

    if settings.textColor then
        local c = settings.textColor
        fontString:SetTextColor(c.r, c.g, c.b, c.a or 1)
    end
end

-- -------------------------------------------------------------------------- --
-- UnitFrame Text Styling (DRY helper for common unit frame text setup)
-- -------------------------------------------------------------------------- --

function Skin:GetAdaptiveTextSize(height, minSize, maxSize, ratio)
    minSize = minSize or Constants.UI.UnitFrameTextSize
    if not height then
        return minSize
    end

    -- Apply ratio if provided (e.g. 0.6 = 60% of height)
    local targetSize = height
    if ratio then
        targetSize = height * ratio
    end

    -- Global Multiplier
    local globalScale = 1.0
    local s = Orbit.db.GlobalSettings.TextScale
    if s == "Small" then
        globalScale = 0.85
    elseif s == "Large" then
        globalScale = 1.15
    elseif s == "ExtraLarge" then
        globalScale = 1.30
    end

    targetSize = targetSize * globalScale

    -- Also scale min/max constraints to allow "Small" to actually go below the hard floor
    if minSize then
        minSize = minSize * globalScale
    end
    if maxSize then
        maxSize = maxSize * globalScale
    end

    local size = math.max(minSize, targetSize)
    if maxSize then
        size = math.min(size, maxSize)
    end
    return size
end

function Skin:ApplyUnitFrameText(fontString, alignment, fontPath, textSize)
    if not fontString then
        return
    end

    -- Get font from global settings or fallback
    if not fontPath then
        local globalFontName = Orbit.db.GlobalSettings.Font
        fontPath = LSM:Fetch("font", globalFontName) or Constants.Settings.Font.FallbackPath
    end

    textSize = textSize or Constants.UI.UnitFrameTextSize
    local padding = Constants.UnitFrame.TextPadding
    local shadow = Constants.UnitFrame.ShadowOffset

    fontString:SetFont(fontPath, textSize, "OUTLINE")
    fontString:ClearAllPoints()

    if alignment == "LEFT" then
        fontString:SetPoint("LEFT", padding, 0)
        fontString:SetJustifyH("LEFT")
    else
        fontString:SetPoint("RIGHT", -padding, 0)
        fontString:SetJustifyH("RIGHT")
    end

    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(shadow.x, shadow.y)
end
