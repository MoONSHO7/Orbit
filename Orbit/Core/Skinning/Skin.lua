local _, addonTable = ...
local Orbit = addonTable
---@class OrbitSkin
Orbit.Skin = {}
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local Constants = Orbit.Constants

-- [ LSM BORDER RECONCILIATION ] ---------------------------------------------------------------------
local lsmPendingRefresh
local function RefreshBordersIfNeeded()
    if lsmPendingRefresh then return end
    local gs = Orbit.db and Orbit.db.GlobalSettings
    if not gs then return end
    local needsRefresh = false
    -- LSM borders resolve late if a sibling addon registers after us.
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

-- Rounds the cooldown swipe by using the style's white rounded-rect mask as the swipe fill; nil for flat/LSM.
function Skin:GetRoundedSwipeTexture(isIcon)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local styleKey = (gs and gs[isIcon and "IconBorderStyle" or "BorderStyle"]) or Constants.BorderStyle.Default
    local rounded = Constants.BorderStyle.Rounded[styleKey]
    return rounded and rounded.mask
end

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

-- One mask per surface (tex._orbitRoundedMask) — remove the previous before adding so stale masks never stack.
function Skin:_SetSurfaceMask(tex, mask)
    if not tex.AddMaskTexture then return end
    local prev = tex._orbitRoundedMask
    if prev == mask then return end
    if prev and tex.RemoveMaskTexture then tex:RemoveMaskTexture(prev) end
    if mask then tex:AddMaskTexture(mask) end
    tex._orbitRoundedMask = mask
end

function Skin:ApplyRoundedMaskToSurfaces(frame, styleEntry)
    if not frame then return end
    if not frame._maskedSurfaces then return end
    if not (styleEntry and styleEntry.mask) then
        self:ClearRoundedMaskFromSurfaces(frame)
        return
    end
    local mask = self:EnsureSliceMask(frame, "_roundedMask", styleEntry, function(m) m:SetAllPoints(frame) end)
    for _, tex in ipairs(frame._maskedSurfaces) do
        self:_SetSurfaceMask(tex, mask)
    end
end

-- Only clears surfaces owned by `mask` — a surface shared with another owner (icon + container) keeps the other owner's mask.
function Skin:ClearMaskFromSurfaces(surfaces, mask)
    if not surfaces or not mask then return end
    for _, tex in ipairs(surfaces) do
        if tex._orbitRoundedMask == mask then
            self:_SetSurfaceMask(tex, nil)
        end
    end
end

function Skin:ClearRoundedMaskFromSurfaces(frame)
    if not frame then return end
    self:ClearMaskFromSurfaces(frame._maskedSurfaces, frame._roundedMask)
end

-- For frames built outside the SkinBorder lifecycle (e.g. canvas-mode previews) where surfaces register after the border dispatch ran.
function Skin:UpdateRoundedMask(frame, isIcon)
    self:ApplyRoundedMaskToSurfaces(frame, isIcon and self:GetActiveIconBorderStyle() or self:GetActiveBorderStyle())
end

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
    color = color or { r = 1, g = 1, b = 1, a = 1 }   -- nil tint = "no tint" -> natural art
    tex:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    if blendMode then tex:SetBlendMode(blendMode) end
    tex:Show()
    return tex
end

-- Hides without tearing down — used when a reused frame switches border modes.
function Skin:HideSliceTexture(overlay)
    if overlay._sliceTexture then overlay._sliceTexture:Hide() end
end

-- `color` overrides the resolved border color (SkinBorder's explicit-color path).
function Skin:ApplyPixelBackdrop(overlay, pixelSize, isIcon, color)
    overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = pixelSize })
    local c = color or self:ResolveBorderColor(isIcon)
    overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
end

-- [ EDGE-FILE BORDER ]-------------------------------------------------------------------------------
-- Shared edge-file geometry: authored sizes divide by the frame's own scale; outset is pixel-snapped at the caller's snapScale. Used by SkinBorder, GroupBorder, and HighlightBorder so the formula lives in one place.
function Skin:ComputeBorderOutset(frame, edgeSize, borderOffset, snapScale)
    local ownScale = frame:GetScale() or 1
    if ownScale < 0.01 then ownScale = 1 end
    local adjEdge = edgeSize / ownScale
    return Engine.Pixel:Snap((adjEdge / 2) + (borderOffset / ownScale), snapScale), adjEdge
end

function Skin:ApplyNineSliceBorder(frame, styleEntry)
    if not frame or not styleEntry or not styleEntry.edgeFile then return end
    -- Rounded styles share the edge-file field but draw a slice border — delegate so every caller handles rounded for free.
    if styleEntry.rounded then return self:ApplyRoundedBorder(frame, styleEntry) end
    -- Centralised mask clear so direct callers (Icons, CooldownLayout) that don't pre-clear are covered, not just SkinBorder.
    self:ClearRoundedMaskFromSurfaces(frame)
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
    local outset, adjEdge = self:ComputeBorderOutset(frame, edgeSize, borderOffset, scale)
    frame.borderPixelSize = outset
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
    overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
    overlay:SetBackdrop({ edgeFile = styleEntry.edgeFile, edgeSize = adjEdge })
    -- Edge-file borders are grayscale; tint by Border Color (vertex multiply), or render natural art when "none".
    local c = styleEntry.color or self:ResolveBorderTint(styleEntry.isIcon)
    if c then
        overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
    else
        overlay:SetBackdropBorderColor(1, 1, 1, 1)
    end
    overlay:SetShown(not frame._groupBorderActive)
end

function Skin:ClearNineSliceBorder(frame)
    if not frame then return end
    if frame._edgeBorderOverlay then frame._edgeBorderOverlay:Hide() end
    self:ClearRoundedMaskFromSurfaces(frame)
end

-- [ ROUNDED PIXEL BORDER ]---------------------------------------------------------------------------
-- Merged frames defer the border + mask to the group overlay (GroupBorder owns them).
function Skin:ApplyRoundedBorder(frame, styleEntry)
    if not frame or not styleEntry then return end
    if not frame._edgeBorderOverlay then
        frame._edgeBorderOverlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end
    local overlay = frame._edgeBorderOverlay
    local borderLevel = styleEntry.isIcon and Constants.Levels.IconBorder or Constants.Levels.Border
    overlay:SetFrameLevel(frame:GetFrameLevel() + borderLevel)
    overlay:ClearAllPoints()
    overlay:SetAllPoints(frame)
    self:_RenderSliceTexture(overlay, styleEntry, self:ResolveBorderTint(styleEntry.isIcon))
    overlay:SetShown(not frame._groupBorderActive)
    if not frame._groupBorderActive then
        self:ApplyRoundedMaskToSurfaces(frame, styleEntry)
    end
end

-- Highlight border functions → HighlightBorder.lua

-- [ ICON GROUP BORDER ] -----------------------------------------------------------------------------
-- iconsList is required when icons are not direct children of `container` (e.g. CooldownManager parents to Blizzard's viewer).
function Skin:ApplyIconGroupBorder(container, styleEntry, iconsList)
    if not container then return end
    container._isIconContainer = true
    -- Register the icon surfaces BEFORE the merged early-return, so a born-merged container's icons are known to the group mask.
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
    if container._groupBorderActive then return end   -- merged: the group (not this container) draws the border + mask
    if styleEntry then
        container._activeBorderMode = "nineslice"
        if container._borderFrame then container._borderFrame:Hide() end
        local entry = self:BuildIconStyle(styleEntry)
        if entry.rounded then
            self:ApplyRoundedBorder(container, entry)
        else
            self:ClearRoundedMaskFromSurfaces(container)   -- drop any leftover rounded mask before the edge-file border
            self:ApplyNineSliceBorder(container, entry)
        end
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
    -- _isIconContainer reflects frame type, not border style; only _activeBorderMode clears so SetBorderHidden(false) doesn't re-show stale borders.
    container._activeBorderMode = nil
    self:ClearNineSliceBorder(container)
    if container._borderFrame then container._borderFrame:Hide() end
end


-- Group border functions → GroupBorder.lua

function Skin:ResolveStyle(settingsKey)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local bs = Constants.BorderStyle
    local styleKey = (gs and gs[settingsKey]) or bs.Default
    local rounded = bs.Rounded and bs.Rounded[styleKey]
    if rounded then return rounded end          -- slice border + mask
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

-- A `{ none = true }` value resolves to black so solid-fill borders (pixel WHITE8x8) that always need a colour keep their look.
function Skin:ResolveBorderColor(isIcon)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local raw = isIcon and (gs and gs.IconBorderColor) or (gs and gs.BorderColor)
    if not raw or raw.none then return { r = 0, g = 0, b = 0, a = 1 } end
    if raw.type == "class" then
        local c = Engine.ClassColor:GetCurrentClassColor()
        c.a = raw.a or 1
        return c
    end
    return (Engine.ColorCurve and Engine.ColorCurve:GetFirstColorFromCurve(raw)) or raw or { r = 0, g = 0, b = 0, a = 1 }
end

-- Like ResolveBorderColor but returns nil for the "no tint" state, so grayscale texture borders render natural art (white vertex).
function Skin:ResolveBorderTint(isIcon)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local raw = isIcon and (gs and gs.IconBorderColor) or (gs and gs.BorderColor)
    if not raw or raw.none then return nil end
    return self:ResolveBorderColor(isIcon)
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

-- forceSquare kept for call-site compatibility — inert now that the only non-pixel style is a rectangular LSM edge-file border.
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
        if styleEntry.rounded then
            self:ApplyRoundedBorder(frame, styleEntry)
        else
            self:ClearRoundedMaskFromSurfaces(frame)
            self:ApplyNineSliceBorder(frame, styleEntry)
        end
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
