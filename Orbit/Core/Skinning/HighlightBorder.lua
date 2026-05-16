-- [ ORBIT HIGHLIGHT BORDER ]-------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local Constants = Orbit.Constants

-- Every highlight overlay ever built, weak-keyed so it follows frame GC. Highlight borders are
-- state-driven — applied on aggro/selection/dispel events, never on settings-apply — so a border
-- style change must rebuild the visible ones from here (see the ORBIT_BORDER_SIZE_CHANGED hook).
local activeHighlights = setmetatable({}, { __mode = "k" })

local function RecordHighlight(overlay, frame, storageKey, color, levelOffset)
    overlay._hlFrame = frame
    overlay._hlStorageKey = storageKey
    overlay._hlColor = color
    overlay._hlLevelOffset = levelOffset
    activeHighlights[overlay] = true
end

-- Captures everything the rendered outline depends on. The cache key needs this because pathType
-- alone can't tell Square from Round (both resolve to "modern") — without it a roundness change
-- would hit the cache and keep the stale corner texture.
local function StyleSignature(pathType, nineSliceStyle, gs)
    if pathType == "modern" then
        local hlThickness = math.max(nineSliceStyle.thickness or 1, Constants.BorderStyle.Thickness.Slim)
        return nineSliceStyle.baseEdgeFile .. "_" .. nineSliceStyle.roundness .. "_" .. hlThickness
    elseif pathType == "legacy" then
        return (nineSliceStyle.edgeFile or "") .. ":" .. ((gs and gs.BorderEdgeSize) or Constants.BorderStyle.EdgeSize)
    end
    return "pixel:" .. math.max(1, (gs and gs.BorderSize) or 1)
end

-- [ HIGHLIGHT BORDER ]-------------------------------------------------------------------------------
-- When borders are merged, anchors to the group border overlay instead of the per-frame border.
function Skin:ApplyHighlightBorder(frame, storageKey, color, levelOffset, blendMode)
    if not frame or not storageKey or type(color) ~= "table" then return end

    local r, g, b, a = 1, 1, 1, 1
    if color.r then
        r, g, b, a = color.r, color.g or 1, color.b or 1, color.a or 1
    elseif color[1] then
        r, g, b, a = color[1], color[2] or 1, color[3] or 1, color[4] or 1
    elseif color.pins then
        local firstPin = color._sorted and color._sorted[1] or color.pins[1]
        if firstPin and firstPin.color then
            local pColor = firstPin.color
            r = pColor.r or pColor[1] or 1
            g = pColor.g or pColor[2] or 1
            b = pColor.b or pColor[3] or 1
            a = pColor.a or pColor[4] or 1
        end
    end

    local mode = blendMode or "BLEND"
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local nineSliceStyle = self:GetActiveBorderStyle()
    local gbo = frame._groupBorderActive and (frame._groupBorderRoot or frame)._groupBorderOverlay
    if frame._groupBorderActive and (not gbo or not gbo:IsShown()) then nineSliceStyle = nil end
    local anchorTarget = (gbo and gbo:IsShown()) and gbo or nil

    local pathType
    if nineSliceStyle and nineSliceStyle.sliceMargin then pathType = "modern"
    elseif nineSliceStyle and nineSliceStyle.edgeFile then pathType = "legacy"
    else pathType = "pixel" end

    local styleSig = StyleSignature(pathType, nineSliceStyle, gs)

    local overlay = frame[storageKey]
    if overlay
        and overlay._hlBlendMode == mode
        and overlay._hlPathType == pathType
        and overlay._hlStyleSig == styleSig
        and overlay._hlAnchorTarget == anchorTarget then
        if pathType == "modern" then
            if overlay._sliceTexture then overlay._sliceTexture:SetVertexColor(r, g, b, a) end
        else
            overlay:SetBackdropBorderColor(r, g, b, a)
        end
        if anchorTarget then
            local off = (levelOffset or (Constants.Levels.Border + 1)) - Constants.Levels.Border
            overlay:SetFrameLevel(anchorTarget:GetFrameLevel() + off)
        else
            overlay:SetFrameLevel(frame:GetFrameLevel() + (levelOffset or (Constants.Levels.Border + 1)))
        end
        if pathType == "modern" then self:_PinBorderScale(overlay, frame) else overlay:SetScale(1) end
        RecordHighlight(overlay, frame, storageKey, color, levelOffset)
        overlay:Show()
        return
    end

    if not overlay then
        overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        overlay:EnableMouse(false)
        frame[storageKey] = overlay
    end
    -- Modern nine-slice highlight renders at the fixed pixel scale (matching the border it sits
    -- on); legacy/pixel highlights stay at scale 1 (their geometry is in frame-local units).
    if pathType == "modern" then self:_PinBorderScale(overlay, frame) else overlay:SetScale(1) end

    if anchorTarget then
        local off = (levelOffset or (Constants.Levels.Border + 1)) - Constants.Levels.Border
        overlay:SetFrameLevel(anchorTarget:GetFrameLevel() + off)
    else
        overlay:SetFrameLevel(frame:GetFrameLevel() + (levelOffset or (Constants.Levels.Border + 1)))
    end

    local ownScale = frame:GetScale() or 1
    if ownScale < 0.01 then ownScale = 1 end
    local hlScale = frame:GetEffectiveScale()
    if not hlScale or hlScale < 0.01 then hlScale = 1 end
    local borderOffset = (gs and gs.BorderOffset) or 0

    if pathType == "modern" then
        -- The highlight always shows a border even when the cosmetic Border Thickness is None,
        -- so it builds its own slice entry at the active roundness and at least a Slim outline.
        local roundness = nineSliceStyle.roundness
        local tier = Constants.BorderStyle.RoundedTiers[roundness]
        local hlThickness = math.max(nineSliceStyle.thickness or 1, Constants.BorderStyle.Thickness.Slim)
        local hlStyle = {
            edgeFile = nineSliceStyle.baseEdgeFile .. "_" .. roundness .. "_" .. hlThickness,
            sliceMargin = tier.margin,
        }
        self:_RenderSliceTexture(overlay, hlStyle, { r = r, g = g, b = b, a = a }, mode)
        overlay:ClearAllPoints()
        overlay:SetAllPoints(anchorTarget or frame)
    elseif pathType == "legacy" then
        if overlay._sliceTexture then overlay._sliceTexture:Hide() end
        local edgeSize = (gs and gs.BorderEdgeSize) or Constants.BorderStyle.EdgeSize
        local adjEdge = edgeSize / ownScale
        overlay:ClearAllPoints()
        if anchorTarget then
            overlay:SetAllPoints(anchorTarget)
        else
            local outset = Engine.Pixel:Snap((adjEdge / 2) + (borderOffset / ownScale), hlScale)
            overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
            overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
        end
        overlay:SetBackdrop({ edgeFile = nineSliceStyle.edgeFile, edgeSize = adjEdge })
        overlay:SetBackdropBorderColor(r, g, b, a)
        for _, region in pairs({ overlay:GetRegions() }) do
            if region:IsObjectType("Texture") then region:SetBlendMode(mode) end
        end
    else
        if overlay._sliceTexture then overlay._sliceTexture:Hide() end
        local borderSize = math.max(1, (gs and gs.BorderSize) or 1)
        overlay:ClearAllPoints()
        if anchorTarget then
            overlay:SetAllPoints(anchorTarget)
        else
            overlay:SetAllPoints(frame)
        end
        overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = Engine.Pixel:Multiple(borderSize, hlScale) })
        overlay:SetBackdropBorderColor(r, g, b, a)
        for _, region in pairs({ overlay:GetRegions() }) do
            if region:IsObjectType("Texture") then region:SetBlendMode(mode) end
        end
    end
    overlay:Show()

    overlay._hlBlendMode = mode
    overlay._hlAnchorTarget = anchorTarget
    overlay._hlPathType = pathType
    overlay._hlStyleSig = styleSig
    RecordHighlight(overlay, frame, storageKey, color, levelOffset)
end

function Skin:ClearHighlightBorder(frame, storageKey)
    if not frame or not storageKey then return end
    local overlay = frame[storageKey]
    if overlay then overlay:Hide() end
end

-- A border style / thickness / roundness change must rebuild every visible highlight border:
-- their callers only re-run on unit state events, so without this they keep the old corner
-- shape until the unit's aggro/selection/dispel state next changes.
Orbit.EventBus:On("ORBIT_BORDER_SIZE_CHANGED", function()
    for overlay in pairs(activeHighlights) do
        if overlay._hlFrame and overlay:IsShown() then
            Skin:ApplyHighlightBorder(overlay._hlFrame, overlay._hlStorageKey, overlay._hlColor,
                overlay._hlLevelOffset, overlay._hlBlendMode)
        end
    end
end)
