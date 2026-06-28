-- [ ANCHOR LINES ] ----------------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local C = Orbit.Constants

Engine.AnchorLines = Engine.AnchorLines or {}
local AnchorLines = Engine.AnchorLines

local ANCHOR_ALIGN_COLORS = {
    LEFT = { 1.0, 0.55, 0.15 },
    RIGHT = { 0.8, 0.4, 1.0 },
    TOP = { 1.0, 0.55, 0.15 },
    BOTTOM = { 0.8, 0.4, 1.0 },
    CENTER = { 0.2, 0.9, 0.85 },
}
local DEFAULT_ANCHOR_COLOR = { 0, 1, 0 }

-- Build the two-halves-per-edge gradient textures on host once (idempotent). Container covers host; halves anchor to host so they render on its edges in screen space.
function AnchorLines:Ensure(host)
    if not host or host.AnchorLines then return end
    local lineThickness = C.Selection.AnchorLineThickness
    local container = CreateFrame("Frame", nil, host)
    container:SetFrameLevel(host:GetFrameLevel() + 10)
    container:SetAllPoints(host)
    host.AnchorLineFrame = container
    local function MakeHalf(p1, rp1, x1, y1, p2, rp2, x2, y2)
        local t = container:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetPoint(p1, host, rp1, x1, y1)
        t:SetPoint(p2, host, rp2, x2, y2)
        t.isAnchorLine = true
        t:Hide()
        return t
    end
    host.AnchorLines = {
        TOP    = { MakeHalf("TOPLEFT", "TOPLEFT", 0, lineThickness, "BOTTOMRIGHT", "TOP", 0, 0),
                   MakeHalf("TOPLEFT", "TOP", 0, lineThickness, "BOTTOMRIGHT", "TOPRIGHT", 0, 0) },
        BOTTOM = { MakeHalf("BOTTOMLEFT", "BOTTOMLEFT", 0, -lineThickness, "TOPRIGHT", "BOTTOM", 0, 0),
                   MakeHalf("TOPLEFT", "BOTTOM", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, -lineThickness) },
        LEFT   = { MakeHalf("TOPLEFT", "TOPLEFT", -lineThickness, 0, "BOTTOMRIGHT", "LEFT", 0, 0),
                   MakeHalf("TOPLEFT", "LEFT", -lineThickness, 0, "BOTTOMRIGHT", "BOTTOMLEFT", 0, 0) },
        RIGHT  = { MakeHalf("TOPRIGHT", "TOPRIGHT", lineThickness, 0, "BOTTOMLEFT", "RIGHT", 0, 0),
                   MakeHalf("TOPRIGHT", "RIGHT", lineThickness, 0, "BOTTOMLEFT", "BOTTOMRIGHT", 0, 0) },
    }
end

function AnchorLines:Hide(host)
    if not host or not host.AnchorLines then return end
    for _, pair in pairs(host.AnchorLines) do
        pair[1]:Hide()
        pair[2]:Hide()
    end
    if host.AnchorLineFrame then host.AnchorLineFrame:Hide() end
end

-- Tint + reveal the gradient bar on one edge of host; side=nil hides all. align selects colour + fade direction.
function AnchorLines:ShowOn(host, side, align)
    if not host or not host.AnchorLines then return end
    if not side then
        self:Hide(host)
        return
    end
    for _, pair in pairs(host.AnchorLines) do
        pair[1]:Hide()
        pair[2]:Hide()
    end
    local pair = host.AnchorLines[side]
    if not pair then return end
    local c = (align and ANCHOR_ALIGN_COLORS[align]) or DEFAULT_ANCHOR_COLOR
    local orient = (side == "TOP" or side == "BOTTOM") and "HORIZONTAL" or "VERTICAL"
    local a1s, a1e, a2s, a2e
    if orient == "HORIZONTAL" then
        if align == "LEFT" then
            a1s, a1e, a2s, a2e = 1, 0.7, 0.7, 0.15
        elseif align == "RIGHT" then
            a1s, a1e, a2s, a2e = 0.15, 0.7, 0.7, 1
        else
            a1s, a1e, a2s, a2e = 0.15, 1, 1, 0.15
        end
    else
        if align == "TOP" then
            a1s, a1e, a2s, a2e = 0.7, 1, 0.15, 0.7
        elseif align == "BOTTOM" then
            a1s, a1e, a2s, a2e = 0.7, 0.15, 1, 0.7
        else
            a1s, a1e, a2s, a2e = 1, 0.15, 0.15, 1
        end
    end
    pair[1]:SetGradient(orient, CreateColor(c[1], c[2], c[3], a1s), CreateColor(c[1], c[2], c[3], a1e))
    pair[2]:SetGradient(orient, CreateColor(c[1], c[2], c[3], a2s), CreateColor(c[1], c[2], c[3], a2e))
    if host.AnchorLineFrame then host.AnchorLineFrame:Show() end
    pair[1]:Show()
    pair[2]:Show()
end
