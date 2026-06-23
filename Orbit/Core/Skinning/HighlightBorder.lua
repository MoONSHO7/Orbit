-- [ ORBIT HIGHLIGHT BORDER ]-------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local Constants = Orbit.Constants

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

    -- Rounded → tinted slice border; LSM edge-file → "legacy"; flat "Orbit" (nil style) → "pixel" WHITE8x8 backdrop.
    local pathType
    if nineSliceStyle and nineSliceStyle.rounded then pathType = "rounded"
    elseif nineSliceStyle and nineSliceStyle.edgeFile then pathType = "legacy"
    else pathType = "pixel" end
    -- soft vs rounded share pathType but differ in slice texture — cache it so a swap rebuilds, not just re-tints.
    local roundedFile = (pathType == "rounded") and nineSliceStyle.edgeFile or nil

    local ownScale = frame:GetScale() or 1
    if ownScale < 0.01 then ownScale = 1 end
    local borderSize = math.max(1, (gs and gs.BorderSize) or 1)
    local edgeSize = (gs and gs.BorderEdgeSize) or Constants.BorderStyle.EdgeSize
    local borderOffset = (gs and gs.BorderOffset) or 0

    local overlay = frame[storageKey]
    if overlay and overlay._hlCacheValid
        and overlay._hlBlendMode == mode
        and overlay._hlPathType == pathType
        and overlay._hlAnchorTarget == anchorTarget
        and overlay._hlBorderSize == borderSize
        and overlay._hlEdgeSize == edgeSize
        and overlay._hlBorderOffset == borderOffset
        and overlay._hlOwnScale == ownScale
        and overlay._hlRoundedFile == roundedFile then
        if pathType == "rounded" then
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
        overlay:Show()
        return
    end

    if not overlay then
        overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        overlay:EnableMouse(false)
        frame[storageKey] = overlay
    end

    if anchorTarget then
        local off = (levelOffset or (Constants.Levels.Border + 1)) - Constants.Levels.Border
        overlay:SetFrameLevel(anchorTarget:GetFrameLevel() + off)
    else
        overlay:SetFrameLevel(frame:GetFrameLevel() + (levelOffset or (Constants.Levels.Border + 1)))
    end

    local hlScale = frame:GetEffectiveScale()
    if not hlScale or hlScale < 0.01 then hlScale = 1 end

    if pathType == "rounded" then
        overlay:ClearAllPoints()
        if anchorTarget then overlay:SetAllPoints(anchorTarget) else overlay:SetAllPoints(frame) end
        self:_RenderSliceTexture(overlay, nineSliceStyle, { r = r, g = g, b = b, a = a }, mode)
    elseif pathType == "legacy" then
        self:HideSliceTexture(overlay)
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
        self:HideSliceTexture(overlay)
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

    overlay._hlCacheValid = true
    overlay._hlBlendMode = mode
    overlay._hlAnchorTarget = anchorTarget
    overlay._hlPathType = pathType
    overlay._hlBorderSize = borderSize
    overlay._hlEdgeSize = edgeSize
    overlay._hlBorderOffset = borderOffset
    overlay._hlOwnScale = ownScale
    overlay._hlRoundedFile = roundedFile
end

function Skin:ClearHighlightBorder(frame, storageKey)
    if not frame or not storageKey then return end
    local overlay = frame[storageKey]
    if overlay then overlay:Hide() end
end

