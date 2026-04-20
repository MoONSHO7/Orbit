-- [ ORBIT HIGHLIGHT BORDER ]------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local Constants = Orbit.Constants

-- [ HIGHLIGHT BORDER ]------------------------------------------------------------------------------
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

    local overlay = frame[storageKey]

    -- Fast path: overlay exists, backdrop unchanged, just update color
    if overlay and overlay._hlCacheValid and overlay._hlBlendMode == (blendMode or "BLEND") then
        local gbo = frame._groupBorderActive and (frame._groupBorderRoot or frame)._groupBorderOverlay
        local anchorTarget = (gbo and gbo:IsShown()) and gbo or nil
        if overlay._hlAnchorTarget == anchorTarget then
            overlay:SetBackdropBorderColor(r, g, b, a)
            if anchorTarget then
                local off = (levelOffset or (Constants.Levels.Border + 1)) - Constants.Levels.Border
                overlay:SetFrameLevel(anchorTarget:GetFrameLevel() + off)
            else
                overlay:SetFrameLevel(frame:GetFrameLevel() + (levelOffset or (Constants.Levels.Border + 1)))
            end
            overlay:Show()
            return
        end
    end

    if not overlay then
        overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        overlay:EnableMouse(false)
        frame[storageKey] = overlay
    end

    local gs = Orbit.db and Orbit.db.GlobalSettings
    local nineSliceStyle = self:GetActiveBorderStyle()

    local gbo = frame._groupBorderActive and (frame._groupBorderRoot or frame)._groupBorderOverlay
    if frame._groupBorderActive and (not gbo or not gbo:IsShown()) then
        nineSliceStyle = nil
    end

    local ownScale = frame:GetScale() or 1
    if ownScale < 0.01 then ownScale = 1 end
    local backdrop
    if nineSliceStyle and nineSliceStyle.edgeFile then
        local edgeSize = (gs and gs.BorderEdgeSize) or Constants.BorderStyle.EdgeSize
        backdrop = { edgeFile = nineSliceStyle.edgeFile, edgeSize = edgeSize / ownScale }
    else
        local scale = frame:GetEffectiveScale()
        if not scale or scale < 0.01 then scale = 1 end
        local borderSize = math.max(1, (gs and gs.BorderSize) or 1)
        backdrop = { edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = Engine.Pixel:Multiple(borderSize, scale) }
    end

    local anchorTarget = (gbo and gbo:IsShown()) and gbo or nil
    if anchorTarget then
        local off = (levelOffset or (Constants.Levels.Border + 1)) - Constants.Levels.Border
        overlay:SetFrameLevel(anchorTarget:GetFrameLevel() + off)
        overlay:ClearAllPoints()
        overlay:SetAllPoints(anchorTarget)
    else
        overlay:SetFrameLevel(frame:GetFrameLevel() + (levelOffset or (Constants.Levels.Border + 1)))
        overlay:ClearAllPoints()
        if nineSliceStyle and nineSliceStyle.edgeFile then
            local hlScale = frame:GetEffectiveScale()
            if not hlScale or hlScale < 0.01 then hlScale = 1 end
            local borderOffset = (gs and gs.BorderOffset) or 0
            local outset = Engine.Pixel:Snap((backdrop.edgeSize / 2) + (borderOffset / ownScale), hlScale)
            overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
            overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
        else
            overlay:SetAllPoints(frame)
        end
    end
    overlay:SetBackdrop(backdrop)
    overlay:SetBackdropBorderColor(r, g, b, a)
    local mode = blendMode or "BLEND"
    for _, region in pairs({ overlay:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetBlendMode(mode) end
    end
    overlay:Show()

    -- Cache state for fast path
    overlay._hlCacheValid = true
    overlay._hlBlendMode = mode
    overlay._hlAnchorTarget = anchorTarget
end

function Skin:ClearHighlightBorder(frame, storageKey)
    if not frame or not storageKey then return end
    local overlay = frame[storageKey]
    if overlay then overlay:Hide() end
end

-- Invalidate highlight caches when border settings change
function Skin:InvalidateHighlightCaches(frame)
    if not frame then return end
    for _, key in ipairs({ "_selectionBorderOverlay", "_aggroHighlightOverlay", "_aggroBorderOverlay" }) do
        local overlay = frame[key]
        if overlay then overlay._hlCacheValid = nil end
    end
end
