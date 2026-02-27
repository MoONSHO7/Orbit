local _, addonTable = ...
local Orbit = addonTable
---@class OrbitSkin
Orbit.Skin = {}
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local Constants = Orbit.Constants
local math_max, math_min = math.max, math.min

-- [ NINESLICE BORDER REGISTRY ]---------------------------------------------------------------------
local NINESLICE_CORNER_SIZE = 16
local NINESLICE_EDGE_THICKNESS = 3
local NINESLICE_CORNER_OVERHANG = 1
local LSM_BORDER_EDGE_SIZE = 12

local NINESLICE_SETS = {
    Dragonflight = {
        TopLeft     = "dragonflight-nineslice-cornertopleft",
        TopRight    = "dragonflight-nineslice-cornertopright",
        BottomLeft  = "dragonflight-nineslice-cornerbottomleft",
        BottomRight = "dragonflight-nineslice-cornerbottomright",
        Top         = "_dragonflight-nineslice-edgetop",
        Bottom      = "_dragonflight-nineslice-edgebottom",
        Left        = "!dragonflight-nineslice-edgeleft",
        Right       = "!dragonflight-nineslice-edgeright",
    },
    Plunderstorm = {
        TopLeft     = "plunderstorm-nineslice-cornertopleft",
        TopRight    = "plunderstorm-nineslice-cornertopright",
        BottomLeft  = "plunderstorm-nineslice-cornerbottomleft",
        BottomRight = "plunderstorm-nineslice-cornerbottomright",
        Top         = "_plunderstorm-nineslice-edgetop",
        Bottom      = "_plunderstorm-nineslice-edgebottom",
        Left        = "!plunderstorm-nineslice-edgeleft",
        Right       = "!plunderstorm-nineslice-edgeright",
    },
    DiamondMetal = {
        TopLeft     = "ui-frame-diamondmetal-cornertopleft-2x",
        TopRight    = "ui-frame-diamondmetal-cornertopright-2x",
        BottomLeft  = "ui-frame-diamondmetal-cornerbottomleft-2x",
        BottomRight = "ui-frame-diamondmetal-cornerbottomright-2x",
        Top         = "_ui-frame-diamondmetal-edgetop-2x",
        Bottom      = "_ui-frame-diamondmetal-edgebottom-2x",
        Left        = "!ui-frame-diamondmetal-edgeleft-2x",
        Right       = "!ui-frame-diamondmetal-edgeright-2x",
    },
    GenericMetal = {
        TopLeft     = "GenericMetal2-NineSlice-CornerTopLeft",
        TopRight    = "GenericMetal2-NineSlice-CornerTopRight",
        BottomLeft  = "GenericMetal2-NineSlice-CornerBottomLeft",
        BottomRight = "GenericMetal2-NineSlice-CornerBottomRight",
        Top         = "_GenericMetal2-NineSlice-EdgeTop",
        Bottom      = "_GenericMetal2-NineSlice-EdgeBottom",
        Left        = "!GenericMetal2-NineSlice-EdgeLeft",
        Right       = "!GenericMetal2-NineSlice-EdgeRight",
    },
    Oribos = {
        TopLeft     = "UI-Frame-Oribos-CornerTopLeft",
        TopRight    = "UI-Frame-Oribos-CornerTopRight",
        BottomLeft  = "UI-Frame-Oribos-CornerBottomLeft",
        BottomRight = "UI-Frame-Oribos-CornerBottomRight",
        Top         = "_UI-Frame-Oribos-TileTop",
        Bottom      = "_UI-Frame-Oribos-TileBottom",
        Left        = "!UI-Frame-Oribos-TileLeft",
        Right       = "!UI-Frame-Oribos-TileRight",
    },
}

-- Register Orbit's overlay texture with LibSharedMedia
local ORBIT_OVERLAY_PATH = "Interface\\AddOns\\Orbit\\Core\\assets\\Statusbar\\orbit-left-right.tga"
LSM:Register("statusbar", "Orbit Gradient", ORBIT_OVERLAY_PATH)

-- [ UTILITIES ]-------------------------------------------------------------------------------------

function Skin:GetPixelScale()
    return Engine.Pixel:GetScale()
end

-- [ ICON SKINNING ]---------------------------------------------------------------------------------

function Skin:SkinIcon(icon, settings)
    if not icon then return end
    if not icon.SetTexCoord then return end

    local zoom = settings.zoom or 0
    local trim = Constants.Texture.BlizzardIconBorderTrim
    trim = trim + ((zoom / 100) / 2)

    local left, right, top, bottom = trim, 1 - trim, trim, 1 - trim
    icon:SetTexCoord(left, right, top, bottom)
end

-- [ BORDER SKINNING ]-------------------------------------------------------------------------------

function Skin:CreateBackdrop(frame, name)
    local backdrop = CreateFrame("Frame", name, frame, "BackdropTemplate")
    backdrop:SetAllPoints(frame)
    return backdrop
end

function Skin:SkinBorder(frame, backdrop, size, color, horizontal)
    if not frame or not backdrop then return end

    if frame == backdrop then
        if not frame._borderFrame then
            frame._borderFrame = CreateFrame("Frame", nil, frame)
            frame._borderFrame:SetAllPoints(frame)
            frame._borderFrame:SetFrameLevel(frame:GetFrameLevel() + (Orbit.Constants.Levels.Border or 3))
        end
        backdrop = frame._borderFrame
    end

    local targetSize = size or 1

    if targetSize <= 0 then
        frame.borderPixelSize = 0
        if backdrop.Borders then
            for _, border in pairs(backdrop.Borders) do
                border:Hide()
            end
        end
        return true
    end

    local scale = frame:GetEffectiveScale()
    if not scale or scale < 0.01 then scale = 1 end

    local pixelSize = Engine.Pixel:Multiple(targetSize, scale)
    frame.borderPixelSize = pixelSize

    if not backdrop.Borders then
        backdrop.Borders = {}
        local function CreateLine()
            local t = backdrop:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(1, 1, 1, 1)
            return t
        end
        backdrop.Borders.Top = CreateLine()
        backdrop.Borders.Bottom = CreateLine()
        backdrop.Borders.Left = CreateLine()
        backdrop.Borders.Right = CreateLine()
    end

    if not frame.SetBorderHidden then
        frame.SetBorderHidden = function(self, edge, hidden)
            local b = backdrop.Borders
            if b and b[edge] then
                b[edge]:SetShown(not hidden)
            end
            if not self._mergedEdges then self._mergedEdges = {} end
            self._mergedEdges[edge] = hidden or nil
        end
    end

    local c = color or { r = 0, g = 0, b = 0, a = 1 }
    local merged = frame._mergedEdges
    for edge, t in pairs(backdrop.Borders) do
        t:SetColorTexture(c.r, c.g, c.b, c.a)
        if not (merged and merged[edge]) then t:Show() end
    end

    local b = backdrop.Borders

    if horizontal then
        b.Top:ClearAllPoints()
        b.Top:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
        b.Top:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
        b.Top:SetHeight(pixelSize)

        b.Bottom:ClearAllPoints()
        b.Bottom:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
        b.Bottom:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        b.Bottom:SetHeight(pixelSize)

        b.Left:ClearAllPoints()
        b.Left:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, -pixelSize)
        b.Left:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, pixelSize)
        b.Left:SetWidth(pixelSize)

        b.Right:ClearAllPoints()
        b.Right:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, -pixelSize)
        b.Right:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, pixelSize)
        b.Right:SetWidth(pixelSize)
    else
        b.Left:ClearAllPoints()
        b.Left:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
        b.Left:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
        b.Left:SetWidth(pixelSize)

        b.Right:ClearAllPoints()
        b.Right:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
        b.Right:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        b.Right:SetWidth(pixelSize)

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

-- [ NINESLICE BORDER ]------------------------------------------------------------------------------

function Skin:ApplyNineSlice(frame, setKey)
    if not frame then return end

    if not setKey then
        if frame._nineSliceFrame then frame._nineSliceFrame:Hide() end
        return
    end

    local atlasSet = NINESLICE_SETS[setKey]
    if not atlasSet then
        if frame._nineSliceFrame then frame._nineSliceFrame:Hide() end
        return
    end

    if not frame._nineSliceFrame then
        local ns = CreateFrame("Frame", nil, frame)
        ns:SetAllPoints()
        ns:SetFrameLevel(frame:GetFrameLevel() + (Orbit.Constants.Levels.Border or 3))
        ns.pieces = {}

        local keys = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Top", "Bottom", "Left", "Right" }
        for _, key in ipairs(keys) do
            ns.pieces[key] = ns:CreateTexture(nil, "OVERLAY")
        end

        local p = ns.pieces
        local cs = NINESLICE_CORNER_SIZE
        local et = NINESLICE_EDGE_THICKNESS
        local oh = NINESLICE_CORNER_OVERHANG

        p.TopLeft:SetSize(cs, cs)
        p.TopLeft:SetPoint("TOPLEFT", -oh, oh)

        p.TopRight:SetSize(cs, cs)
        p.TopRight:SetPoint("TOPRIGHT", oh, oh)

        p.BottomLeft:SetSize(cs, cs)
        p.BottomLeft:SetPoint("BOTTOMLEFT", -oh, -oh)

        p.BottomRight:SetSize(cs, cs)
        p.BottomRight:SetPoint("BOTTOMRIGHT", oh, -oh)

        p.Top:SetHeight(et)
        p.Top:SetPoint("TOPLEFT", p.TopLeft, "TOPRIGHT", 0, 0)
        p.Top:SetPoint("TOPRIGHT", p.TopRight, "TOPLEFT", 0, 0)

        p.Bottom:SetHeight(et)
        p.Bottom:SetPoint("BOTTOMLEFT", p.BottomLeft, "BOTTOMRIGHT", 0, 0)
        p.Bottom:SetPoint("BOTTOMRIGHT", p.BottomRight, "BOTTOMLEFT", 0, 0)

        p.Left:SetWidth(et)
        p.Left:SetPoint("TOPLEFT", p.TopLeft, "BOTTOMLEFT", 0, 0)
        p.Left:SetPoint("BOTTOMLEFT", p.BottomLeft, "TOPLEFT", 0, 0)

        p.Right:SetWidth(et)
        p.Right:SetPoint("TOPRIGHT", p.TopRight, "BOTTOMRIGHT", 0, 0)
        p.Right:SetPoint("BOTTOMRIGHT", p.BottomRight, "TOPRIGHT", 0, 0)

        frame._nineSliceFrame = ns
    end

    if frame._nineSliceFrame._activeSet ~= setKey then
        for key, tex in pairs(frame._nineSliceFrame.pieces) do
            tex:SetAtlas(atlasSet[key], false)
        end
        frame._nineSliceFrame._activeSet = setKey
    end

    frame._nineSliceFrame:Show()
end

-- [ LSM BORDER ]------------------------------------------------------------------------------------

function Skin:ApplyLSMBorder(frame, borderName)
    if not frame then return end

    if not borderName then
        if frame._lsmBorderFrame then frame._lsmBorderFrame:Hide() end
        return
    end

    local borderPath = LSM:Fetch("border", borderName)
    if not borderPath then
        if frame._lsmBorderFrame then frame._lsmBorderFrame:Hide() end
        return
    end

    if not frame._lsmBorderFrame then
        frame._lsmBorderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame._lsmBorderFrame:SetAllPoints()
        frame._lsmBorderFrame:SetFrameLevel(frame:GetFrameLevel() + (Orbit.Constants.Levels.Border or 3))
    end

    frame._lsmBorderFrame:SetBackdrop({ edgeFile = borderPath, edgeSize = LSM_BORDER_EDGE_SIZE })
    frame._lsmBorderFrame:SetBackdropBorderColor(1, 1, 1, 1)
    frame._lsmBorderFrame:Show()
end

-- [ UNIFIED GRAPHICAL BORDER ]----------------------------------------------------------------------

function Skin:ApplyGraphicalBorder(frame, style)
    if not frame then return end

    if not style then
        self:ApplyNineSlice(frame, nil)
        self:ApplyLSMBorder(frame, nil)
        return
    end

    if NINESLICE_SETS[style] then
        self:ApplyLSMBorder(frame, nil)
        self:ApplyNineSlice(frame, style)
    else
        self:ApplyNineSlice(frame, nil)
        self:ApplyLSMBorder(frame, style)
    end
end

function Skin:SkinStatusBar(bar, textureName, color, isUnitFrame)
    if not bar then
        return
    end

    local texture = LSM:Fetch("statusbar", textureName or "Blizzard")
    bar:SetStatusBarTexture(texture)

    if color then
        bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    end

    -- Overlay logic: check OverlayAllFrames setting
    local overlayAllFrames = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.OverlayAllFrames

    -- If this is a unit frame, only add overlay if OverlayAllFrames is enabled
    if isUnitFrame and not overlayAllFrames then
        -- Hide overlay if it exists
        if bar.Overlay then
            bar.Overlay:Hide()
        end
        return
    end

    -- Get overlay texture from settings
    local overlayTextureName = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.OverlayTexture or "Orbit Gradient"
    local overlayPath = LSM:Fetch("statusbar", overlayTextureName) or ORBIT_OVERLAY_PATH

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
    bar.Overlay:Show()
end

-- [ FONT SKINNING ]---------------------------------------------------------------------------------

function Skin:GetFontOutline()
    return Orbit.db.GlobalSettings.FontOutline or "OUTLINE"
end

function Skin:SkinText(fontString, settings)
    if not fontString then
        return
    end

    local size = settings.textSize or 12

    local font = "Fonts\\FRIZQT__.TTF"
    if settings.font then
        font = LSM:Fetch("font", settings.font) or font
    end

    fontString:SetFont(font, size, self:GetFontOutline())

    if settings.textColor then
        local c = settings.textColor
        fontString:SetTextColor(c.r, c.g, c.b, c.a or 1)
    end
end

-- [ UNITFRAME TEXT STYLING ]------------------------------------------------------------------------

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

    local size = math_max(minSize, targetSize)
    if maxSize then
        size = math_min(size, maxSize)
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

    fontString:SetFont(fontPath, textSize, self:GetFontOutline())
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

-- [ GRADIENT BACKGROUND ]--------------------------------------------------------------------------
local function ResolvePinColor(pin)
    if pin.type == "class" then
        local _, classFile = UnitClass("player")
        local cc = classFile and RAID_CLASS_COLORS[classFile]
        if cc then return { r = cc.r, g = cc.g, b = cc.b, a = pin.color and pin.color.a or 1 } end
    end
    return pin.color
end

function Skin:ApplyGradientBackground(frame, curveData, fallbackColor)
    if not frame then return end
    local WL = Engine.WidgetLogic
    local pins = curveData and curveData.pins
    local pinCount = pins and #pins or 0

    if pinCount <= 1 then
        local c = (pinCount == 1 and WL and WL:GetFirstColorFromCurve(curveData)) or fallbackColor or Constants.Colors.Background
        if frame.bg then frame.bg:SetColorTexture(c.r or 0, c.g or 0, c.b or 0, c.a or 0.5) end
        if frame._gradientSegments then
            for _, seg in ipairs(frame._gradientSegments) do seg:Hide() end
        end
        return
    end

    if frame.bg then frame.bg:SetColorTexture(0, 0, 0, 0) end

    frame._gradientSegments = frame._gradientSegments or {}
    local sorted = {}
    for _, p in ipairs(pins) do sorted[#sorted + 1] = p end
    table.sort(sorted, function(a, b) return a.position < b.position end)
    if sorted[1].position > 0 then table.insert(sorted, 1, { position = 0, color = ResolvePinColor(sorted[1]), type = sorted[1].type }) end
    if sorted[#sorted].position < 1 then sorted[#sorted + 1] = { position = 1, color = ResolvePinColor(sorted[#sorted]), type = sorted[#sorted].type } end

    local segCount = #sorted - 1
    for i = 1, segCount do
        local seg = frame._gradientSegments[i]
        if not seg then
            seg = frame:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers and Constants.Layers.BackdropDeep or -8)
            frame._gradientSegments[i] = seg
        end
        local lc = ResolvePinColor(sorted[i])
        local rc = ResolvePinColor(sorted[i + 1])

        seg:ClearAllPoints()
        local width = frame:GetWidth()
        local scale = frame:GetEffectiveScale()
        seg:SetPoint("TOPLEFT", frame, "TOPLEFT", Engine.Pixel:Snap(width * sorted[i].position, scale), 0)
        seg:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", Engine.Pixel:Snap(width * sorted[i + 1].position, scale), -frame:GetHeight())
        seg:SetTexture("Interface\\BUTTONS\\WHITE8x8")
        seg:SetGradient("HORIZONTAL", CreateColor(lc.r, lc.g, lc.b, lc.a or 0.5), CreateColor(rc.r, rc.g, rc.b, rc.a or 0.5))
        seg:Show()
    end

    for i = segCount + 1, #frame._gradientSegments do
        frame._gradientSegments[i]:Hide()
    end
end
