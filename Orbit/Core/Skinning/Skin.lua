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
local NINESLICE_LEVEL_OFFSET = Constants.Levels.Border or 3

function Skin:ApplyNineSliceBorder(frame, styleEntry)
    if not frame or not styleEntry then return end
    local offset = styleEntry.offset or Constants.BorderStyle.Offset

    if styleEntry.layoutName then
        if frame._singleSliceOverlay then frame._singleSliceOverlay:Hide() end
        local layout = NineSliceUtil.GetLayout(styleEntry.layoutName)
        if not layout then return end
        
        if not frame._nineSliceOverlay then
            local overlay = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
            overlay:SetFrameLevel(frame:GetFrameLevel() + NINESLICE_LEVEL_OFFSET)
            overlay.layoutTextureLayer = "OVERLAY"
            
            -- Prevent native atlas sizes from overflowing on small frames without ruining aspect ratio
            overlay:SetScript("OnSizeChanged", function(self, width, height)
                if width <= 0 or height <= 0 then return end
                
                -- Discover native layout dimensions from the corner textures
                local topH = (self.TopLeftCorner and self.TopLeftCorner:GetHeight()) or 32
                local botH = (self.BottomLeftCorner and self.BottomLeftCorner:GetHeight()) or 32
                local leftW = (self.TopLeftCorner and self.TopLeftCorner:GetWidth()) or 32
                local rightW = (self.TopRightCorner and self.TopRightCorner:GetWidth()) or 32
                
                local reqH = topH + botH
                local reqW = leftW + rightW
                if reqH <= 0 then reqH = 64 end
                if reqW <= 0 then reqW = 64 end
                
                -- Determine required physical scale to prevent corner overlap
                local physW = width * self:GetScale()
                local physH = height * self:GetScale()
                
                local scaleW = physW / reqW
                local scaleH = physH / reqH
                
                local scale = math.min(scaleW, scaleH)
                scale = math.max(0.1, scale) -- avoid making it microscopically invisible
                
                -- Only update scale if meaningfully different
                if math.abs(self:GetScale() - scale) > 0.01 then
                    self:SetScale(scale)
                end
            end)
            
            frame._nineSliceOverlay = overlay
        end
        
        local overlay = frame._nineSliceOverlay
        overlay.baseThickness = styleEntry.thickness or 16
        
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
        overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
        
        NineSliceUtil.ApplyLayout(overlay, layout, styleEntry.textureKit)
        
        -- Force an immediate size update
        local w, h = overlay:GetSize()
        if w > 0 and h > 0 then
            overlay:GetScript("OnSizeChanged")(overlay, w, h)
        end
        
        overlay:Show()
        NineSliceUtil.ShowLayout(overlay)

    elseif styleEntry.path or styleEntry.atlasSlice then
        if frame._nineSliceOverlay then
            NineSliceUtil.HideLayout(frame._nineSliceOverlay)
            frame._nineSliceOverlay:Hide()
        end
        if not frame._singleSliceOverlay then
            local overlay = CreateFrame("Frame", nil, frame)
            overlay:SetFrameLevel(frame:GetFrameLevel() + NINESLICE_LEVEL_OFFSET)
            overlay.tex = overlay:CreateTexture(nil, "OVERLAY")
            overlay.tex:SetAllPoints()
            frame._singleSliceOverlay = overlay
        end
        
        local overlay = frame._singleSliceOverlay
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
        overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
        
        local margin = styleEntry.margin or 64
        if styleEntry.path then
            overlay.tex:SetTexture(styleEntry.path)
        else
            overlay.tex:SetAtlas(styleEntry.atlasSlice, false)
        end
        overlay.tex:SetTextureSliceMargins(margin, margin, margin, margin)
        overlay.tex:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
        overlay:Show()
    end
end

function Skin:ClearNineSliceBorder(frame)
    if not frame then return end
    if frame._nineSliceOverlay then
        NineSliceUtil.HideLayout(frame._nineSliceOverlay)
        frame._nineSliceOverlay:Hide()
    end
    if frame._singleSliceOverlay then
        frame._singleSliceOverlay:Hide()
    end
end

function Skin:GetActiveBorderStyle()
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local styleKey = gs and gs.BorderStyle
    if not styleKey or styleKey == Constants.BorderStyle.Default then return nil end
    local builtIn = Constants.BorderStyle.Lookup[styleKey]
    if builtIn then return builtIn end
    -- Resolve LibSharedMedia border entries (stored as "lsm:Name")
    local lsmName = styleKey:match("^lsm:(.+)$")
    if lsmName then
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local path = LSM and LSM:Fetch("border", lsmName)
        if path and path ~= "" then return { path = path, margin = 64 } end
    end
    return nil
end

function Skin:SkinBorder(frame, backdrop, size, color, horizontal)
    if not frame or not backdrop then
        return
    end

    -- Route to NineSlice for unit frames (non-horizontal callers only)
    if not horizontal then
        local nineSliceStyle = self:GetActiveBorderStyle()
        if nineSliceStyle then
            -- Hide flat borders
            if backdrop.Borders then
                for _, border in pairs(backdrop.Borders) do border:Hide() end
            end
            self:ApplyNineSliceBorder(frame, nineSliceStyle)
            frame.borderPixelSize = 0
            return true
        end
        -- Flat mode: clear any leftover NineSlice overlay
        self:ClearNineSliceBorder(frame)
    end

    -- The paladin's aura must shine ABOVE the rogue's cloak
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
            if not self._mergedEdges then self._mergedEdges = {} end
            self._mergedEdges[edge] = hidden or nil
        end
    end

    if not color then
        local gs = Orbit.db and Orbit.db.GlobalSettings
        color = gs and gs.BorderColor
    end
    local c = color or { r = 0, g = 0, b = 0, a = 1 }
    local merged = frame._mergedEdges
    for edge, t in pairs(backdrop.Borders) do
        t:SetColorTexture(c.r, c.g, c.b, c.a)
        if not (merged and merged[edge]) then t:Show() end
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
