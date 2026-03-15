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
    local outset = Engine.Pixel:Snap((edgeSize / 2) + borderOffset, scale)
    frame.borderPixelSize = outset
    local fw, fh = frame:GetWidth(), frame:GetHeight()
    if fw == 0 or fh == 0 or issecretvalue(fw) or issecretvalue(fh) then return end
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
    overlay:SetSize(Engine.Pixel:Snap(fw + 2 * outset, scale), Engine.Pixel:Snap(fh + 2 * outset, scale))
    overlay:SetBackdrop({ edgeFile = styleEntry.edgeFile, edgeSize = edgeSize })
    local c = styleEntry.color
    if c then overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
    else overlay:SetBackdropBorderColor(1, 1, 1, 1) end
    overlay:SetShown(not frame._groupBorderActive)
end

function Skin:ClearNineSliceBorder(frame)
    if not frame then return end
    if frame._edgeBorderOverlay then frame._edgeBorderOverlay:Hide() end
end

-- [ HIGHLIGHT BORDER ]------------------------------------------------------------------------------
-- Tinted border overlay for aggro/selection. Optional ADD blend for glow effect.
-- When borders are merged, anchors to the group border overlay instead of the individual frame.

function Skin:ApplyHighlightBorder(frame, storageKey, color, levelOffset, blendMode)
    if not frame or not storageKey or not color then return end
    local overlay = frame[storageKey]
    if not overlay then
        overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        overlay:EnableMouse(false)
        frame[storageKey] = overlay
    end
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local nineSliceStyle = self:GetActiveBorderStyle()
    local backdrop
    if nineSliceStyle and nineSliceStyle.edgeFile then
        local edgeSize = (gs and gs.BorderEdgeSize) or Constants.BorderStyle.EdgeSize
        backdrop = { edgeFile = nineSliceStyle.edgeFile, edgeSize = edgeSize }
    else
        local scale = frame:GetEffectiveScale()
        if not scale or scale < 0.01 then scale = 1 end
        local borderSize = math.max(1, (gs and gs.BorderSize) or 1)
        backdrop = { edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = Engine.Pixel:Multiple(borderSize, scale) }
    end
    local gbo = frame._groupBorderActive and (frame._groupBorderRoot or frame)._groupBorderOverlay
    if gbo and gbo:IsShown() then
        local off = (levelOffset or (Constants.Levels.Border + 1)) - Constants.Levels.Border
        overlay:SetFrameLevel(gbo:GetFrameLevel() + off)
        overlay:ClearAllPoints()
        overlay:SetAllPoints(gbo)
    else
        overlay:SetFrameLevel(frame:GetFrameLevel() + (levelOffset or (Constants.Levels.Border + 1)))
        overlay:ClearAllPoints()
        if nineSliceStyle and nineSliceStyle.edgeFile then
            local hlScale = frame:GetEffectiveScale()
            if not hlScale or hlScale < 0.01 then hlScale = 1 end
            local borderOffset = (gs and gs.BorderOffset) or 0
            local outset = Engine.Pixel:Snap((backdrop.edgeSize / 2) + borderOffset, hlScale)
            overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
            overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
        else
            local outset = backdrop.edgeSize
            overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
            overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
        end
    end
    overlay:SetBackdrop(backdrop)
    overlay:SetBackdropBorderColor(color.r, color.g, color.b, color.a or 1)
    local mode = blendMode or "BLEND"
    for _, region in pairs({ overlay:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetBlendMode(mode) end
    end
    overlay:Show()
end

function Skin:ClearHighlightBorder(frame, storageKey)
    if not frame or not storageKey then return end
    local overlay = frame[storageKey]
    if overlay then overlay:Hide() end
end

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
    self:ClearNineSliceBorder(container)
end

-- [ GROUP BORDER ]-----------------------------------------------------------------------------------
-- Creates a single wrapper border around all merged frames in an anchor chain.

function Skin:UpdateGroupBorder(rootFrame)
    if not rootFrame then return end

    local FrameAnchor = Orbit.Engine.FrameAnchor
    local GetFrameOptions = FrameAnchor.GetFrameOptions

    local topLeft, bottomRight = rootFrame, rootFrame
    local allFrames = { rootFrame }
    local hasMerge = false

    local function walk(frame)
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do
            local a = FrameAnchor.anchors[child]
            if a and a.padding == 0 then
                local pOpts = GetFrameOptions(frame)
                local cOpts = GetFrameOptions(child)
                local merged = pOpts.mergeBorders and cOpts.mergeBorders
                    and child:IsShown() and child:GetAlpha() > 0
                if merged then
                    hasMerge = true
                    allFrames[#allFrames + 1] = child
                    if a.edge == "BOTTOM" or a.edge == "RIGHT" then bottomRight = child end
                    if a.edge == "TOP" or a.edge == "LEFT" then topLeft = child end
                    walk(child)
                end
            end
        end
    end
    walk(rootFrame)

    if not hasMerge then
        self:ClearGroupBorder(rootFrame)
        return
    end

    -- Icon containers are explicitly flagged via ApplyIconGroupBorder;
    -- check ALL frames in the chain — any icon container makes the whole group icon-styled
    local isIconStyle = false
    for _, frame in ipairs(allFrames) do
        if frame._isIconContainer then isIconStyle = true; break end
    end

    -- Mark all merged frames and hide their individual borders
    for _, frame in ipairs(allFrames) do
        frame._groupBorderActive = true
        frame._groupBorderRoot = rootFrame
        if frame._edgeBorderOverlay and frame._edgeBorderOverlay:IsShown() then
            frame._edgeBorderOverlay:Hide()
            frame._groupBorderHiddenNineSlice = true
        end
        if frame ~= rootFrame and frame._groupBorderOverlay then frame._groupBorderOverlay:Hide() end
        if frame._borderFrame and frame._borderFrame:IsShown() then
            frame._borderFrame:Hide()
            frame._groupBorderHiddenPixels = true
        end
    end

    -- Determine border mode: NineSlice texture or pixel flat
    local isPixelMode = false
    local styleEntry
    if isIconStyle then styleEntry = self:GetActiveIconBorderStyle()
    else styleEntry = self:GetActiveBorderStyle() end
    if not styleEntry or not styleEntry.edgeFile then
        isPixelMode = true
    end

    -- Icon containers: boost above the highest child button level.
    -- Unit frames: border sits just above status textures (root level + Border offset),
    -- leaving canvas components (text, status icons) above the border.
    local overlayLevel
    if isIconStyle then
        local maxLevel = rootFrame:GetFrameLevel()
        for _, frame in ipairs(allFrames) do
            local fl = frame:GetFrameLevel()
            if fl > maxLevel then maxLevel = fl end
        end
        overlayLevel = maxLevel + Constants.Levels.IconOverlay
    else
        overlayLevel = rootFrame:GetFrameLevel() + NINESLICE_LEVEL_OFFSET
    end

    if not rootFrame._groupBorderOverlay then
        rootFrame._groupBorderOverlay = CreateFrame("Frame", nil, rootFrame, "BackdropTemplate")
        rootFrame._groupBorderOverlay:EnableMouse(false)
    end
    rootFrame._groupBorderOverlay:SetFrameLevel(overlayLevel)

    local overlay = rootFrame._groupBorderOverlay
    local gs = Orbit.db and Orbit.db.GlobalSettings

    -- Calculate bounding box from anchor edge data (deterministic, no screen coords needed).
    -- Each frame's position relative to rootFrame TOPLEFT is derived from its anchor edge.
    local positions = {}
    positions[rootFrame] = { x = 0, y = 0 }
    local function computePositions(frame)
        local pos = positions[frame]
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do
            if not positions[child] then
                local a = FrameAnchor.anchors[child]
                if a and a.padding == 0 then
                    local cx, cy = pos.x, pos.y
                    if a.edge == "BOTTOM" then cy = pos.y + frame:GetHeight()
                    elseif a.edge == "TOP" then cy = pos.y - child:GetHeight()
                    elseif a.edge == "RIGHT" then cx = pos.x + frame:GetWidth()
                    elseif a.edge == "LEFT" then cx = pos.x - child:GetWidth()
                    end
                    positions[child] = { x = cx, y = cy }
                    computePositions(child)
                end
            end
        end
    end
    computePositions(rootFrame)

    local minX, maxX = 0, rootFrame:GetWidth()
    local minY, maxY = 0, rootFrame:GetHeight()
    for i = 2, #allFrames do
        local frame = allFrames[i]
        local pos = positions[frame]
        if pos then
            local r = pos.x + frame:GetWidth()
            local b = pos.y + frame:GetHeight()
            if pos.x < minX then minX = pos.x end
            if r > maxX then maxX = r end
            if pos.y < minY then minY = pos.y end
            if b > maxY then maxY = b end
        end
    end
    local totalW = maxX - minX
    local totalH = maxY - minY
    local offsetX = -minX
    local offsetY = -minY

    if isPixelMode then
        -- Pixel-style group overlay: use WHITE8x8 with pixel-snapped sizing
        local scale = rootFrame:GetEffectiveScale()
        if not scale or scale < 0.01 then scale = 1 end
        local borderSize = isIconStyle and (gs and gs.IconBorderSize or 2) or (gs and gs.BorderSize or 2)
        if borderSize <= 0 then overlay:Hide(); return end
        local pixelSize = Engine.Pixel:Multiple(borderSize, scale)
        local outset = pixelSize
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", -outset - offsetX, outset + offsetY)
        overlay:SetSize(totalW + 2 * outset, totalH + 2 * outset)
        overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = pixelSize })
        local colorKey = isIconStyle and "IconBorderColor" or "BorderColor"
        local c = (gs and gs[colorKey]) or { r = 0, g = 0, b = 0, a = 1 }
        overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    else
        -- NineSlice-style group overlay
        local edgeSize, borderOffset
        if isIconStyle then
            local iconStyle = self:BuildIconStyle(styleEntry)
            edgeSize = iconStyle.edgeSize
            borderOffset = iconStyle.borderOffset
        else
            edgeSize = (gs and gs.BorderEdgeSize) or Constants.BorderStyle.EdgeSize
            borderOffset = (gs and gs.BorderOffset) or 0
        end
        local grpScale = rootFrame:GetEffectiveScale()
        if not grpScale or grpScale < 0.01 then grpScale = 1 end
        local outset = Engine.Pixel:Snap((edgeSize / 2) + borderOffset, grpScale)
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", -outset - offsetX, outset + offsetY)
        overlay:SetSize(Engine.Pixel:Snap(totalW + 2 * outset, grpScale), Engine.Pixel:Snap(totalH + 2 * outset, grpScale))
        overlay:SetBackdrop({ edgeFile = styleEntry.edgeFile, edgeSize = edgeSize })
        overlay:SetBackdropBorderColor(1, 1, 1, 1)
    end
    overlay:Show()

    -- Hook visibility changes so merges update immediately when frames show/hide
    -- (e.g. target frame via RegisterUnitWatch). Hooks are persistent and debounced.
    for _, frame in ipairs(allFrames) do
        if not frame._mergeVisHooked then
            frame:HookScript("OnShow", function() Skin:DeferGroupBorderRefresh() end)
            frame:HookScript("OnHide", function() Skin:DeferGroupBorderRefresh() end)
            frame._mergeVisHooked = true
        end
    end
end

function Skin:ClearGroupBorder(rootFrame)
    if not rootFrame then return end
    local function restoreFrame(frame)
        frame._groupBorderActive = nil
        frame._groupBorderRoot = nil
        if frame._groupBorderOverlay then frame._groupBorderOverlay:Hide() end
        if frame._groupBorderHiddenNineSlice then
            frame._groupBorderHiddenNineSlice = nil
            if frame._edgeBorderOverlay then frame._edgeBorderOverlay:Show() end
        end
        if frame._groupBorderHiddenPixels then
            frame._groupBorderHiddenPixels = nil
            if frame._borderFrame then frame._borderFrame:Show() end
        end
    end
    restoreFrame(rootFrame)
    local FrameAnchor = Orbit.Engine.FrameAnchor
    local function walk(frame)
        restoreFrame(frame)
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do walk(child) end
    end
    walk(rootFrame)
end

function Skin:RefreshAllGroupBorders()
    local FrameAnchor = Orbit.Engine.FrameAnchor
    if not FrameAnchor or not FrameAnchor.anchors then return end

    -- Phase 1: Collect all current merge roots (including non-anchored parents)
    local visited = {}
    local mergeRoots = {}
    for child in pairs(FrameAnchor.anchors) do
        local mergeRoot = child
        while true do
            local pa = FrameAnchor.anchors[mergeRoot]
            if not pa or pa.padding ~= 0 then break end
            local pO = FrameAnchor.GetFrameOptions(pa.parent)
            local cO = FrameAnchor.GetFrameOptions(mergeRoot)
            if not (pO.mergeBorders and cO.mergeBorders) then break end
            mergeRoot = pa.parent
        end
        if not visited[mergeRoot] then
            visited[mergeRoot] = true
            mergeRoots[#mergeRoots + 1] = mergeRoot
        end
        -- Clean stale overlays on parents that aren't merge roots
        local a = FrameAnchor.anchors[child]
        if a and a.parent and not visited[a.parent] and a.parent._groupBorderOverlay then
            a.parent._groupBorderOverlay:Hide()
            a.parent._groupBorderActive = nil
            a.parent._groupBorderRoot = nil
        end
    end

    -- Phase 2: Clear all existing group borders via ClearGroupBorder (proper cleanup)
    for _, root in ipairs(mergeRoots) do
        self:ClearGroupBorder(root)
    end

    -- Phase 3: Re-evaluate all merges from clean state
    for _, root in ipairs(mergeRoots) do
        self:UpdateGroupBorder(root)
    end
end

function Skin:DeferGroupBorderRefresh()
    Orbit.EventBus:Fire("BORDER_LAYOUT_CHANGED")
end

-- Debounced listener: coalesces all border layout events into a single refresh
Orbit.EventBus:On("BORDER_LAYOUT_CHANGED", function()
    Orbit.Async:Debounce("GroupBorderRefresh", function()
        Skin:RefreshAllGroupBorders()
    end, 0)
end)

-- Refresh group borders after plugins finish loading
Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
    Orbit.Async:Debounce("GroupBorderRefresh", function()
        Skin:RefreshAllGroupBorders()
    end, 1)
end)

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
    bf:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Border)

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
    frame.borderPixelSize = pixelSize

    -- Outset border frame by FULL pixelSize so the BackdropTemplate edge
    -- (which renders INSIDE the frame boundary) lands entirely outside the content.
    local outset = pixelSize
    local fw, fh = frame:GetWidth(), frame:GetHeight()
    if fw == 0 or fh == 0 or issecretvalue(fw) or issecretvalue(fh) then return end
    bf:ClearAllPoints()
    bf:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
    bf:SetSize(fw + 2 * outset, fh + 2 * outset)

    -- Apply solid pixel border via BackdropTemplate
    bf:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = pixelSize })

    if not color then
        local gs = Orbit.db and Orbit.db.GlobalSettings
        color = isIcon and (gs and gs.IconBorderColor) or (gs and gs.BorderColor)
    end
    local c = color or { r = 0, g = 0, b = 0, a = 1 }
    bf:SetBackdropBorderColor(c.r, c.g, c.b, c.a)

    if frame._groupBorderActive then
        bf:Hide()
    else
        bf:Show()
    end

    -- Attach whole-frame SetBorderHidden if missing
    if not frame.SetBorderHidden then
        frame.SetBorderHidden = function(self, hidden)
            if hidden then
                if self._borderFrame then self._borderFrame:Hide() end
                if self._edgeBorderOverlay then self._edgeBorderOverlay:Hide() end
            elseif self._activeBorderMode == "nineslice" then
                if self._edgeBorderOverlay then self._edgeBorderOverlay:Show() end
            else
                if self._borderFrame then self._borderFrame:Show() end
            end
        end
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
