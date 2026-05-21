local _, addonTable = ...
local Orbit = addonTable
---@class OrbitSkin
Orbit.Skin = {}
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local Constants = Orbit.Constants

local SHADOW_OFFSET_X = 2
local SHADOW_OFFSET_Y = -2

-- Per-overlay blend mode + alpha. tile = true repeats the texture at native pixel size instead
-- of stretching it, so detail keeps a constant on-screen scale as the bar grows; Gloss is a pure
-- gradient with nothing to distort, so it stretches. An unrecognised pick (e.g. a user routing a
-- plain bar fill through the Overlay control) falls back to OVERLAY_DEFAULT's neutral sheen.
local OVERLAY_RENDER = {
    ["Orbit Gloss Overlay"]  = { blend = "ADD",   alpha = 1.0 },
    ["Orbit Frost Overlay"]  = { blend = "BLEND", alpha = 1.0, tile = true },
    ["Orbit Galaxy Overlay"] = { blend = "BLEND", alpha = 1.0, tile = true },
    ["Orbit Starfield Overlay"] = { blend = "BLEND", alpha = 1.0, tile = true },
}
local OVERLAY_DEFAULT = { blend = "ADD", alpha = 0.5 }

local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"

-- Statusbar fill textures that must TILE rather than stretch -- their patterns (stripes, hex
-- cells) shear when a statusbar stretches its fill. ApplyAbsorbTexture renders these as a
-- clip-masked tiled pattern instead; see UnitButton.lua's TotalAbsorbPattern.
local TILING_FILLS = {
    ["Orbit Absorb"]           = true,
    ["Orbit Honeycomb Absorb"] = true,
}

-- [ LSM BORDER RECONCILIATION ] ---------------------------------------------------------------------
local lsmPendingRefresh
local function RefreshBordersIfNeeded()
    if lsmPendingRefresh then return end
    local gs = Orbit.db and Orbit.db.GlobalSettings
    if not gs then return end
    local needsRefresh = false
    -- Only LibSharedMedia borders can resolve late (sibling addon registers after us);
    -- the built-in Orbit style always resolves.
    for _, key in ipairs({ "BorderStyle", "IconBorderStyle" }) do
        local v = gs[key]
        if v and v:match("^lsm:") and not Skin:ResolveStyle(key) then
            needsRefresh = true
        end
    end
    if not needsRefresh then return end
    lsmPendingRefresh = true
    C_Timer.After(0.2, function()
        lsmPendingRefresh = nil
        for _, plugin in ipairs(Engine.systems) do
            if plugin.ApplyAll then plugin:ApplyAll()
            elseif plugin.ApplySettings then plugin:ApplySettings() end
        end
        Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
    end)
end

LSM.RegisterCallback(Orbit, "LibSharedMedia_Registered", function(_, mediaType, key)
    if mediaType ~= "border" then return end
    local gs = Orbit.db and Orbit.db.GlobalSettings
    if not gs then return end
    if (gs.BorderStyle == "lsm:" .. key) or (gs.IconBorderStyle == "lsm:" .. key) then
        RefreshBordersIfNeeded()
    end
end)

-- Deferred one-shot: all addons are loaded by PLAYER_ENTERING_WORLD; reconcile if borders are stale.
C_Timer.After(0, function()
    Orbit.EventBus:On("ORBIT_PLAYER_ENTERING_WORLD", function()
        C_Timer.After(1, RefreshBordersIfNeeded)
    end)
end)

-- [ ICON SKINNING ]----------------------------------------------------------------------------------
function Skin:SkinIcon(icon, settings)
    if not icon then
        return
    end
    if not icon.SetTexCoord then return end

    local zoom = settings.zoom or 0
    local trim = Constants.Texture.BlizzardIconBorderTrim
    trim = trim + ((zoom / 100) / 2)

    local left, right, top, bottom = trim, 1 - trim, trim, 1 - trim
    icon:SetTexCoord(left, right, top, bottom)
end

-- [ BORDER SKINNING ]--------------------------------------------------------------------------------
function Skin:CreateBackdrop(frame, name)
    local backdrop = CreateFrame("Frame", name, frame, "BackdropTemplate")
    backdrop:SetAllPoints(frame)
    return backdrop
end

-- [ ROUNDED MASK REGISTRY ]--------------------------------------------------------------------------
function Skin:RegisterMaskedSurface(frame, texture)
    if not frame or not texture then return end
    frame._maskedSurfaces = frame._maskedSurfaces or {}
    for _, t in ipairs(frame._maskedSurfaces) do
        if t == texture then return end
    end
    table.insert(frame._maskedSurfaces, texture)
end

-- No active border style produces a corner-clip mask any more — the flat "Orbit" border and
-- LibSharedMedia edge-file borders are both rectangular. Kept callable: ~24 sites resolve a
-- swipe texture through this; nil routes the cooldown swipe to its default rectangular asset.
function Skin:GetRoundedSwipeTexture(isIcon)
    return nil
end

-- Lazily builds host[cacheKey] as a slice MaskTexture from `styleEntry`, then hands it to
-- `anchorFn` for placement. No built-in style carries a `.mask`/`.sliceMargin` any more, so the
-- masked-surface callers never reach this — kept defined for call-site compatibility.
function Skin:EnsureSliceMask(host, cacheKey, styleEntry, anchorFn)
    local mask = host[cacheKey]
    if not mask then
        mask = host:CreateMaskTexture(nil, "BACKGROUND")
        host[cacheKey] = mask
        if Engine.Pixel then Engine.Pixel:Enforce(mask) end
    end
    local m = styleEntry.sliceMargin
    mask:SetTexture(styleEntry.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if m then mask:SetTextureSliceMargins(m, m, m, m) end
    mask:ClearAllPoints()
    anchorFn(mask)
    return mask
end

-- A surface holds at most one Orbit rounded mask, tracked as tex._orbitRoundedMask; this
-- removes whatever is present before adding, so stale per-frame/ex-group masks never stack.
function Skin:_SetSurfaceMask(tex, mask)
    if not tex.AddMaskTexture then return end
    local prev = tex._orbitRoundedMask
    if prev == mask then return end
    if prev and tex.RemoveMaskTexture then tex:RemoveMaskTexture(prev) end
    if mask then tex:AddMaskTexture(mask) end
    tex._orbitRoundedMask = mask
end

-- Inert since the border-system collapse: the flat "Orbit" border and LibSharedMedia edge-file
-- borders are rectangular, so no style ever yields a corner-clip mask. Kept callable for the
-- ~24 sites that drive the masked-surface model; it now only clears any stale mask.
function Skin:ApplyRoundedMaskToSurfaces(frame, styleEntry)
    if not frame or not frame._maskedSurfaces then return end
    self:ClearRoundedMaskFromSurfaces(frame)
end

-- Detaches `mask` from every surface that currently carries it, leaving surfaces owned by a
-- different mask untouched. A surface can be registered on both an icon and its container,
-- sharing one mask slot, so an owner-blind clear would clobber the other owner on merge/unmerge.
function Skin:ClearMaskFromSurfaces(surfaces, mask)
    if not surfaces or not mask then return end
    for _, tex in ipairs(surfaces) do
        if tex._orbitRoundedMask == mask then
            self:_SetSurfaceMask(tex, nil)
        end
    end
end

-- Releases ONLY this frame's own rounded mask.
function Skin:ClearRoundedMaskFromSurfaces(frame)
    if not frame then return end
    self:ClearMaskFromSurfaces(frame._maskedSurfaces, frame._roundedMask)
end

-- For frames built outside the SkinBorder lifecycle (e.g. canvas-mode previews) where surfaces
-- are registered after the border dispatch ran. Uses the same style the border uses.
function Skin:UpdateRoundedMask(frame, isIcon)
    self:ApplyRoundedMaskToSurfaces(frame, isIcon and self:GetActiveIconBorderStyle() or self:GetActiveBorderStyle())
end

-- Renders a sliced edge-file texture onto `overlay`. With the border-system collapse no built-in
-- style carries `sliceMargin`, so callers only reach this when a style table explicitly supplies
-- one — kept callable for those sites; the margin is applied only when present.
function Skin:_RenderSliceTexture(overlay, styleEntry, color, blendMode)
    overlay:SetBackdrop(nil)
    if not overlay._sliceTexture then
        overlay._sliceTexture = overlay:CreateTexture(nil, "OVERLAY")
        overlay._sliceTexture:SetAllPoints(overlay)
    end
    local tex = overlay._sliceTexture
    local margin = styleEntry.sliceMargin
    tex:SetTexture(styleEntry.edgeFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if margin then tex:SetTextureSliceMargins(margin, margin, margin, margin) end
    tex:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    if blendMode then tex:SetBlendMode(blendMode) end
    tex:Show()
    return tex
end

-- Hides a frame's slice-outline texture without tearing it down -- used when a border mode
-- switches away from the slice outline (pixel/legacy) on a reused frame.
function Skin:HideSliceTexture(overlay)
    if overlay._sliceTexture then overlay._sliceTexture:Hide() end
end

-- Flat WHITE8x8 pixel border, the shared pixel-mode primitive. `color` overrides the resolved
-- border color when a caller supplies one (SkinBorder's explicit-color path).
function Skin:ApplyPixelBackdrop(overlay, pixelSize, isIcon, color)
    overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = pixelSize })
    local c = color or self:ResolveBorderColor(isIcon)
    overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
end

-- [ EDGE-FILE BORDER ]-------------------------------------------------------------------------------
-- The only non-nil style ResolveStyle yields is a LibSharedMedia `{ edgeFile = ... }` border;
-- the built-in flat "Orbit" border resolves to nil and renders through SkinBorder's pixel path.
-- Kept named ApplyNineSliceBorder/ClearNineSliceBorder for the ~24 external call sites.
function Skin:ApplyNineSliceBorder(frame, styleEntry)
    if not frame or not styleEntry or not styleEntry.edgeFile then return end
    if not frame._edgeBorderOverlay then
        frame._edgeBorderOverlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    local overlay = frame._edgeBorderOverlay
    local borderLevel = styleEntry.isIcon and Constants.Levels.IconBorder or Constants.Levels.Border
    overlay:SetFrameLevel(frame:GetFrameLevel() + borderLevel)
    self:HideSliceTexture(overlay)
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
    self:ClearRoundedMaskFromSurfaces(frame)
end

-- Highlight border functions → HighlightBorder.lua

-- [ ICON GROUP BORDER ] -----------------------------------------------------------------------------
-- iconsList: optional. Required when icons are not direct children of `container` (e.g.
-- CooldownManager parents icons to Blizzard's viewer, separate from the Orbit anchor frame).
function Skin:ApplyIconGroupBorder(container, styleEntry, iconsList)
    if not container then return end
    if container._groupBorderActive then return end
    container._isIconContainer = true
    if iconsList then
        for _, icon in ipairs(iconsList) do
            local tex = icon.Icon or icon.icon
            if tex and tex.AddMaskTexture then
                self:RegisterMaskedSurface(container, tex)
            end
            if icon._maskedSurfaces then
                for _, surface in ipairs(icon._maskedSurfaces) do
                    if surface.AddMaskTexture then self:RegisterMaskedSurface(container, surface) end
                end
            end
        end
    end
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
        local borderSize = gs and gs.IconBorderSize or Constants.Settings.BorderSize.Default
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

-- Resolves the configured border style to a render directive:
--   • nil           — the built-in flat "Orbit" border. A nil styleEntry is the pipeline-wide
--                      signal for pixel mode (SkinBorder's flat path, GroupBorder's isPixelMode,
--                      HighlightBorder's "pixel" path, ApplyIconGroupBorder's else branch).
--   • { edgeFile }  — a LibSharedMedia edge-file border.
function Skin:ResolveStyle(settingsKey)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local bs = Constants.BorderStyle
    local styleKey = (gs and gs[settingsKey]) or bs.Default
    if bs.Lookup[styleKey] then return nil end
    local lsmName = styleKey:match("^lsm:(.+)$")
    if lsmName then
        local edgeFile = LSM:Fetch("border", lsmName)
        if edgeFile and edgeFile ~= "" then return { edgeFile = edgeFile } end
    end
    return nil
end

function Skin:GetActiveBorderStyle() return self:ResolveStyle("BorderStyle") end
function Skin:GetActiveIconBorderStyle() return self:ResolveStyle("IconBorderStyle") end

-- Resolves the configured frame/icon border color, honoring class-color markers and curve shapes.
function Skin:ResolveBorderColor(isIcon)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local raw = isIcon and (gs and gs.IconBorderColor) or (gs and gs.BorderColor)
    if raw and raw.type == "class" then
        local c = Engine.ClassColor:GetCurrentClassColor()
        c.a = raw.a or 1
        return c
    end
    return (Engine.ColorCurve and Engine.ColorCurve:GetFirstColorFromCurve(raw)) or raw or { r = 0, g = 0, b = 0, a = 1 }
end

function Skin:BuildIconStyle(baseStyle)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local style = {}
    for k, v in pairs(baseStyle) do style[k] = v end
    style.edgeSize = (gs and gs.IconBorderEdgeSize) or Constants.BorderStyle.EdgeSize
    style.borderOffset = (gs and gs.IconBorderOffset) or 0
    style.isIcon = true
    return style
end

-- forceSquare is retained for call-site compatibility but is now inert: the only non-pixel
-- style is a LibSharedMedia edge-file border, which is already rectangular.
function Skin:SkinBorder(frame, backdrop, size, color, isIcon, forcePixel, forceSquare)
    if not frame or not backdrop then
        return
    end

    -- Route to the edge-file path when a LibSharedMedia border is active (unless forced pixel).
    local edgeStyle
    if not forcePixel then
        if isIcon then edgeStyle = self:GetActiveIconBorderStyle()
        else edgeStyle = self:GetActiveBorderStyle() end
    end
    if edgeStyle then
        if frame._borderFrame then frame._borderFrame:Hide() end
        if not frame.SetBorderHidden then frame.SetBorderHidden = Skin.DefaultSetBorderHidden end
        frame._activeBorderMode = "nineslice"
        local styleEntry = isIcon and self:BuildIconStyle(edgeStyle) or edgeStyle
        self:ApplyNineSliceBorder(frame, styleEntry)
        -- Hide individual border if frame is part of a merge group
        if frame._groupBorderActive and frame._edgeBorderOverlay then
            frame._edgeBorderOverlay:Hide()
        end
        return true
    end
    -- Flat mode: clear any leftover edge-file overlay
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
    local targetSize = isIcon and (gs and gs.IconBorderSize or Constants.Settings.BorderSize.Default) or (size or 1)
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

    self:ApplyPixelBackdrop(bf, pixelSize, isIcon, color)

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

-- [ SHARED BORDER VISIBILITY ]-----------------------------------------------------------------------
-- Canonical implementation — assigned to frames by SkinBorder, CastBar, CooldownLayout, etc.
function Skin.DefaultSetBorderHidden(self, hidden)
    -- Group-merged frames defer all visibility to the wrapper overlay, regardless of caller intent.
    if hidden or self._groupBorderActive then
        if self._borderFrame then self._borderFrame:Hide() end
        if self._edgeBorderOverlay then self._edgeBorderOverlay:Hide() end
    elseif self._activeBorderMode == "nineslice" then
        if self._edgeBorderOverlay then self._edgeBorderOverlay:Show() end
    elseif self._activeBorderMode == "flat" then
        if self._borderFrame then self._borderFrame:Show() end
    end
end

-- [ STATUSBAR SKINNING ]-----------------------------------------------------------------------------
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
    -- bar.Overlay is reused across overlay-texture changes, so each mode must fully re-establish
    -- its own texcoord state. A tiling overlay loads with REPEAT wrap; SetHoriz/VertTile then
    -- repeat it at native pixel size by rewriting the texcoords. A non-tiling overlay must clear
    -- tiling AND restore standard texcoords -- otherwise a previous tiling overlay's texcoords
    -- linger and the stretched overlay samples only a sliver of its texture (e.g. just the
    -- bright top glint of the gloss sheen, making it render far too bright).
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

-- Applies an absorb-bar fill texture. A seamless tiling texture ("Orbit Absorb") cannot be a
-- stretched statusbar fill without shearing its diagonal stripes, so it draws via the bar's
-- TiledPattern -- a clip-masked horizTile/vertTile texture MOD-blended over a plain white fill
-- that SetStatusBarColor still tints. That is mathematically identical to a tinted stretched
-- fill, minus the distortion. Any other texture is a normal stretched fill, pattern hidden.
function Skin:ApplyAbsorbTexture(bar, textureName)
    if not bar then
        return
    end

    if TILING_FILLS[textureName] and bar.TiledPattern then
        bar:SetStatusBarTexture(WHITE8x8)
        local pat = bar.TiledPattern
        pat:SetTexture(LSM:Fetch("statusbar", textureName), "REPEAT", "REPEAT")
        pat:SetHorizTile(true)
        pat:SetVertTile(true)
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

-- [ FONT SKINNING ]----------------------------------------------------------------------------------
function Skin:GetFontOutline()
    return Orbit.db.GlobalSettings.FontOutline or "OUTLINE"
end

function Skin:GetFontShadow()
    return Orbit.db.GlobalSettings.FontShadow or false
end

function Skin:ApplyFontShadow(fontString)
    if not fontString then return end
    if self:GetFontShadow() then
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(SHADOW_OFFSET_X, SHADOW_OFFSET_Y)
    else
        fontString:SetShadowOffset(0, 0)
    end
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
    self:ApplyFontShadow(fontString)

    if settings.textColor then
        local c = settings.textColor
        fontString:SetTextColor(c.r, c.g, c.b, c.a or 1)
    end
end

-- [ UNITFRAME TEXT STYLING ]-------------------------------------------------------------------------
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

    fontString:SetFont(fontPath, textSize, self:GetFontOutline())
    fontString:ClearAllPoints()

    local fsScale = fontString:GetEffectiveScale()
    if alignment == "LEFT" then
        fontString:SetPoint("LEFT", Engine.Pixel:Multiple(padding, fsScale), 0)
        fontString:SetJustifyH("LEFT")
    else
        fontString:SetPoint("RIGHT", Engine.Pixel:Multiple(-padding, fsScale), 0)
        fontString:SetJustifyH("RIGHT")
    end

    self:ApplyFontShadow(fontString)
end

-- [ GRADIENT BACKGROUND ] ---------------------------------------------------------------------------
-- Resolves the global "Background" colour (Textures tab → UnitFrameBackdropColourCurve) to a flat
-- colour. Use for solid backdrop surfaces that can't take a gradient; frames with a `.bg` texture
-- should prefer ApplyGradientBackground so a multi-pin Background curve renders as a gradient.
function Skin:GetBackgroundColor()
    local gs = Orbit.db and Orbit.db.GlobalSettings
    return (gs and Engine.ColorCurve:GetFirstColorFromCurve(gs.UnitFrameBackdropColourCurve))
        or Constants.Colors.Background
end

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
    local gradColorL = CreateColor(1, 1, 1, 1)
    local gradColorR = CreateColor(1, 1, 1, 1)
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
        gradColorL:SetRGBA(lc.r, lc.g, lc.b, lc.a or 0.5)
        gradColorR:SetRGBA(rc.r, rc.g, rc.b, rc.a or 0.5)
        seg:SetGradient("HORIZONTAL", gradColorL, gradColorR)
        seg:Show()
    end

    for i = segCount + 1, #frame._gradientSegments do
        frame._gradientSegments[i]:Hide()
    end
end
