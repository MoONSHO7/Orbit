-- [ DROP ZONE GLOW ] --------------------------------------------------------------------------------
-- 9-slice atlas glow that wraps a drop-zone frame to signal droppability.
-- Used by CooldownManager viewer injection, TrackedContainer drop zones, and
-- TrackedBar drop hint. Visibility is gated by a shared ticker on
-- `IsDraggingCooldownAbility()` AND the zone frame being visible — drop zones
-- that show for non-drag reasons (edit mode, settings panel) do not light the
-- glow. Glow is at Background strata / level 0 so it always renders beneath
-- the drop-zone's own textures.
local _, Orbit = ...

---@class OrbitDropZoneGlow
Orbit.DropZoneGlow = {}
local DropZoneGlow = Orbit.DropZoneGlow

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local GLOW_ATLAS = "GenericWidgetBar-Spell-Glow"
local GLOW_SIZE = 12
local GLOW_SLICE_START = 0.33
local GLOW_SLICE_END = 0.67
local DEFAULT_OUTSET = 8
local GATE_POLL_INTERVAL = 0.1

-- [ HELPERS ] ---------------------------------------------------------------------------------------
local function CreateGlowCorner(parent, point, l, r, t, b, cr, cg, cb)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas(GLOW_ATLAS)
    tex:SetTexCoord(l, r, t, b)
    tex:SetSize(GLOW_SIZE, GLOW_SIZE)
    tex:SetPoint(point, parent, point)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(cr, cg, cb)
end

local function CreateGlowEdge(parent, point1, point2, isVertical, l, r, t, b, cr, cg, cb)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas(GLOW_ATLAS)
    tex:SetTexCoord(l, r, t, b)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(cr, cg, cb)
    if isVertical then
        tex:SetWidth(GLOW_SIZE)
        tex:SetPoint("TOPLEFT", parent, point1, point1 == "TOPLEFT" and 0 or -GLOW_SIZE, -GLOW_SIZE)
        tex:SetPoint("BOTTOMRIGHT", parent, point2, point2 == "BOTTOMRIGHT" and 0 or GLOW_SIZE, GLOW_SIZE)
    else
        tex:SetHeight(GLOW_SIZE)
        tex:SetPoint("TOPLEFT", parent, point1, GLOW_SIZE, point1 == "TOPLEFT" and 0 or GLOW_SIZE)
        tex:SetPoint("BOTTOMRIGHT", parent, point2, -GLOW_SIZE, point2 == "BOTTOMRIGHT" and 0 or -GLOW_SIZE)
    end
end

-- [ SHARED VISIBILITY GATE ] ------------------------------------------------------------------------
-- Weak-keyed so a garbage-collected glow falls out of the registry; gateTicker
-- stays alive once started (one ticker for every glow in the session).
local gatedGlows = setmetatable({}, { __mode = "k" })
local gateTicker

local function UpdateGatedGlows()
    local DragDrop = Orbit.CooldownDragDrop
    local dragging = DragDrop and DragDrop:IsDraggingCooldownAbility() or false
    for glow, zone in pairs(gatedGlows) do
        local shouldShow = dragging and zone:IsVisible()
        if shouldShow and not glow:IsShown() then
            glow:Show()
        elseif not shouldShow and glow:IsShown() then
            glow:Hide()
        end
    end
end

-- [ PUBLIC API ] ------------------------------------------------------------------------------------
-- `outset` is either a number (static) or a function returning a number (re-evaluated on every
-- glow Show, so callers can depend on live settings like GlobalSettings.BorderSize).
function DropZoneGlow:Attach(zoneFrame, r, g, b, outset)
    local glow = CreateFrame("Frame", nil, UIParent)
    glow:SetFrameStrata(Orbit.Constants.Strata.Background)
    glow:SetFrameLevel(0)
    CreateGlowCorner(glow, "TOPLEFT", 0, GLOW_SLICE_START, 0, GLOW_SLICE_START, r, g, b)
    CreateGlowCorner(glow, "TOPRIGHT", GLOW_SLICE_END, 1, 0, GLOW_SLICE_START, r, g, b)
    CreateGlowCorner(glow, "BOTTOMLEFT", 0, GLOW_SLICE_START, GLOW_SLICE_END, 1, r, g, b)
    CreateGlowCorner(glow, "BOTTOMRIGHT", GLOW_SLICE_END, 1, GLOW_SLICE_END, 1, r, g, b)
    CreateGlowEdge(glow, "TOPLEFT", "TOPRIGHT", false, GLOW_SLICE_START, GLOW_SLICE_END, 0, GLOW_SLICE_START, r, g, b)
    CreateGlowEdge(glow, "BOTTOMLEFT", "BOTTOMRIGHT", false, GLOW_SLICE_START, GLOW_SLICE_END, GLOW_SLICE_END, 1, r, g, b)
    CreateGlowEdge(glow, "TOPLEFT", "BOTTOMLEFT", true, 0, GLOW_SLICE_START, GLOW_SLICE_START, GLOW_SLICE_END, r, g, b)
    CreateGlowEdge(glow, "TOPRIGHT", "BOTTOMRIGHT", true, GLOW_SLICE_END, 1, GLOW_SLICE_START, GLOW_SLICE_END, r, g, b)

    local function applyPosition()
        local o = type(outset) == "function" and outset() or (outset or DEFAULT_OUTSET)
        local Pixel = Orbit.Engine and Orbit.Engine.Pixel
        local onePx = Pixel and Pixel:Multiple(1, glow:GetEffectiveScale()) or 1
        local inner = o - onePx
        glow:ClearAllPoints()
        PixelUtil.SetPoint(glow, "TOPLEFT", zoneFrame, "TOPLEFT", -inner, inner)
        PixelUtil.SetPoint(glow, "BOTTOMRIGHT", zoneFrame, "BOTTOMRIGHT", inner, -inner)
    end

    glow:Hide()
    glow:SetScript("OnShow", applyPosition)

    gatedGlows[glow] = zoneFrame
    if not gateTicker then gateTicker = C_Timer.NewTicker(GATE_POLL_INTERVAL, UpdateGatedGlows) end

    return glow
end
