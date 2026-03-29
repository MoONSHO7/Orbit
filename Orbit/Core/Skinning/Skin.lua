local _, addonTable = ...
local Orbit = addonTable
---@class OrbitSkin
Orbit.Skin = {}
local Skin = Orbit.Skin
local Engine = Orbit.Engine -- Added Engine reference
local LSM = LibStub("LibSharedMedia-3.0")
local Constants = Orbit.Constants
local math_max, math_min = math.max, math.min

-- Register Orbit's overlay texture with LibSharedMedia
local ORBIT_OVERLAY_PATH = "Interface\\AddOns\\Orbit\\Core\\assets\\Statusbar\\orbit-left-right.tga"
LSM:Register("statusbar", "Orbit Gradient", ORBIT_OVERLAY_PATH)

-- [ UTILITIES ]-------------------------------------------------------------------------------------

function Skin:GetPixelScale()
    return Engine.Pixel:GetScale()
end

-- [ ICON SKINNING ]---------------------------------------------------------------------------------

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

-- [ BORDER SKINNING ]-------------------------------------------------------------------------------

function Skin:CreateBackdrop(frame, name)
    local backdrop = CreateFrame("Frame", name, frame, "BackdropTemplate")
    backdrop:SetAllPoints(frame)
    return backdrop
end

-- [ NINESLICE BORDER ]------------------------------------------------------------------------------
local NINESLICE_LEVEL_OFFSET = Constants.Levels.Border

function Skin:ApplyNineSliceBorder(frame, styleEntry)
    if not frame or not styleEntry then return end
    if not styleEntry.edgeFile then return end
    if not frame._edgeBorderOverlay then
        frame._edgeBorderOverlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    frame._edgeBorderOverlay:SetFrameLevel(frame:GetFrameLevel() + NINESLICE_LEVEL_OFFSET)
    local overlay = frame._edgeBorderOverlay
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local edgeSize = styleEntry.edgeSize or (gs and gs.BorderEdgeSize) or 16
    local borderOffset = styleEntry.borderOffset or (gs and gs.BorderOffset) or 0
    local scale = frame:GetEffectiveScale()
    if not scale or scale < 0.01 then scale = 1 end
    local ownScale = frame:GetScale() or 1
    if ownScale < 0.01 then ownScale = 1 end
    local adjEdge = edgeSize / ownScale
    local adjOffset = borderOffset / ownScale
    local outset = Engine.Pixel:Snap((adjEdge / 2) + adjOffset, scale)
    frame.borderPixelSize = outset
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
    overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
    overlay:SetBackdrop({ edgeFile = styleEntry.edgeFile, edgeSize = adjEdge })
    local c = styleEntry.color
    if c then overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
    else overlay:SetBackdropBorderColor(1, 1, 1, 1) end
    overlay:SetShown(not frame._groupBorderActive)
end

function Skin:ClearNineSliceBorder(frame)
    if not frame then return end
    if frame._edgeBorderOverlay then frame._edgeBorderOverlay:Hide() end
end

-- Highlight border functions → HighlightBorder.lua

-- [ ICON GROUP BORDER ]------------------------------------------------------------------------------
-- Wraps an icon container in a single NineSlice/edge border when Icon Padding = 0.
function Skin:ApplyIconGroupBorder(container, styleEntry)
    if not container then return end
    if container._groupBorderActive then return end
    container._isIconContainer = true
    if styleEntry then
        container._activeBorderMode = "nineslice"
        if container._borderFrame then container._borderFrame:Hide() end
        self:ApplyNineSliceBorder(container, self:BuildIconStyle(styleEntry))
        local overlay = container._edgeBorderOverlay
        if overlay then overlay:SetFrameLevel(container:GetFrameLevel() + Constants.Levels.IconOverlay) end
    else
        -- Pixel mode: flat border on container
        self:ClearNineSliceBorder(container)
        local gs = Orbit.db and Orbit.db.GlobalSettings
        local borderSize = gs and gs.IconBorderSize or 2
        self:SkinBorder(container, container, borderSize, nil, true, true)
        if container._borderFrame then
            container._borderFrame:SetFrameLevel(container:GetFrameLevel() + Constants.Levels.IconOverlay)
        end
    end
end

function Skin:ClearIconGroupBorder(container)
    if not container then return end
    -- NOTE: _isIconContainer is NOT cleared here — it reflects frame type, not border style.
    -- Clear _activeBorderMode so ClearGroupBorder → SetBorderHidden(false) won't re-show stale borders.
    container._activeBorderMode = nil
    self:ClearNineSliceBorder(container)
    if container._borderFrame then container._borderFrame:Hide() end
end


-- Group border functions → GroupBorder.lua

function Skin:ResolveStyle(settingsKey)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local styleKey = gs and gs[settingsKey]
    if not styleKey or styleKey == Constants.BorderStyle.Default then return nil end
    local builtIn = Constants.BorderStyle.Lookup[styleKey]
    if builtIn then return builtIn end
    local lsmName = styleKey:match("^lsm:(.+)$")
    if lsmName then
        local edgeFile = LSM:Fetch("border", lsmName)
        if edgeFile and edgeFile ~= "" then return { edgeFile = edgeFile } end
    end
    return nil
end

function Skin:GetActiveBorderStyle() return self:ResolveStyle("BorderStyle") end
function Skin:GetActiveIconBorderStyle() return self:ResolveStyle("IconBorderStyle") end

function Skin:BuildIconStyle(baseStyle)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local style = {}
    for k, v in pairs(baseStyle) do style[k] = v end
    style.edgeSize = (gs and gs.IconBorderEdgeSize) or Constants.BorderStyle.EdgeSize
    style.borderOffset = (gs and gs.IconBorderOffset) or 0
    return style
end

function Skin:SkinBorder(frame, backdrop, size, color, isIcon, forcePixel)
    if not frame or not backdrop then
        return
    end

    -- Route to NineSlice when a border style is active (unless forced pixel)
    local nineSliceStyle
    if not forcePixel then
        if isIcon then nineSliceStyle = self:GetActiveIconBorderStyle()
        else nineSliceStyle = self:GetActiveBorderStyle() end
    end
    if nineSliceStyle then
        if frame._borderFrame then frame._borderFrame:Hide() end
        frame._activeBorderMode = "nineslice"
        local styleEntry = isIcon and self:BuildIconStyle(nineSliceStyle) or nineSliceStyle
        self:ApplyNineSliceBorder(frame, styleEntry)
        -- Hide individual border if frame is part of a merge group
        if frame._groupBorderActive and frame._edgeBorderOverlay then
            frame._edgeBorderOverlay:Hide()
        end
        return true
    end
    -- Flat mode: clear any leftover NineSlice overlay
    frame._activeBorderMode = "flat"
    self:ClearNineSliceBorder(frame)

    -- Create or reuse the border frame (sits above content at Border level)
    if not frame._borderFrame then
        frame._borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    local bf = frame._borderFrame
    local borderLevel = isIcon and Orbit.Constants.Levels.IconBorder or Orbit.Constants.Levels.Border
    bf:SetFrameLevel(frame:GetFrameLevel() + borderLevel)

    -- For icons, use the icon-specific border size setting
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local targetSize = isIcon and (gs and gs.IconBorderSize or 2) or (size or 1)
    if targetSize <= 0 then
        frame.borderPixelSize = 0
        bf:Hide()
        return true
    end

    local scale = frame:GetEffectiveScale()
    if not scale or scale < 0.01 then scale = 1 end

    local pixelSize = Engine.Pixel:Multiple(targetSize, scale)
    frame.borderPixelSize = 0

    -- Pixel borders render inside the frame boundary (inset).
    bf:ClearAllPoints()
    bf:SetAllPoints(frame)

    -- Apply solid pixel border via BackdropTemplate
    bf:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = pixelSize })

    if not color then
        local gs = Orbit.db and Orbit.db.GlobalSettings
        local raw = isIcon and (gs and gs.IconBorderColor) or (gs and gs.BorderColor)
        color = Engine.ColorCurve and Engine.ColorCurve:GetFirstColorFromCurve(raw) or raw
    end
    local c = color or { r = 0, g = 0, b = 0, a = 1 }
    bf:SetBackdropBorderColor(c.r, c.g, c.b, c.a)

    if frame._groupBorderActive then
        bf:Hide()
    else
        bf:Show()
    end

    if not frame.SetBorderHidden then
        frame.SetBorderHidden = Skin.DefaultSetBorderHidden
    end

    return false
end

-- [ SHARED BORDER VISIBILITY ]----------------------------------------------------------------------
-- Canonical implementation — assigned to frames by SkinBorder, CastBar, CooldownLayout, etc.
function Skin.DefaultSetBorderHidden(self, hidden)
    if hidden then
        if self._borderFrame then self._borderFrame:Hide() end
        if self._edgeBorderOverlay then self._edgeBorderOverlay:Hide() end
    elseif self._activeBorderMode == "nineslice" then
        if self._edgeBorderOverlay then self._edgeBorderOverlay:Show() end
    elseif self._activeBorderMode == "flat" then
        if self._borderFrame then self._borderFrame:Show() end
    end
end

-- [ STATUSBAR SKINNING ]----------------------------------------------------------------------------

function Skin:SkinStatusBar(bar, textureName, color, isUnitFrame)
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
    local overlayPath = LSM:Fetch("statusbar", overlayTextureName) or ORBIT_OVERLAY_PATH
    self:AddOverlay(bar, overlayPath, "BLEND", 0.5)
end

function Skin:AddOverlay(bar, texturePath, blendMode, alpha)
    if not bar then
        return
    end

    if not bar.Overlay then
        bar.Overlay = bar:CreateTexture(nil, "OVERLAY")
        bar.Overlay:SetAllPoints(bar)
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
    local pins = curveData and curveData.pins
    local pinCount = pins and #pins or 0

    if pinCount <= 1 then
        local c = (pinCount == 1 and Engine.ColorCurve:GetFirstColorFromCurve(curveData)) or fallbackColor or Constants.Colors.Background
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
