-- [ ORBIT SELECTION OUTLINE ]------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Engine = Orbit.Engine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local OVERSHOOT = 2
local THICKNESS = 2
local EDGES = { "top", "bottom", "left", "right" }
Skin.SELECTION_ACCENT = { 0.40, 1.0, 0.50, 1.0 }

-- [ GEOMETRY ]---------------------------------------------------------------------------------------
-- Overshoot offset and edge thickness route through the pixel engine so the outline stays crisp at any scale.
local function ApplyGeometry(edges, frame)
    local scale = frame:GetEffectiveScale()
    local o = Engine.Pixel:Multiple(OVERSHOOT, scale)
    local t = Engine.Pixel:Multiple(THICKNESS, scale)
    edges.top:ClearAllPoints()
    edges.top:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o)
    edges.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", o, o)
    edges.top:SetHeight(t)
    edges.bottom:ClearAllPoints()
    edges.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -o, -o)
    edges.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o)
    edges.bottom:SetHeight(t)
    edges.left:ClearAllPoints()
    edges.left:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o)
    edges.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -o, -o)
    edges.left:SetWidth(t)
    edges.right:ClearAllPoints()
    edges.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", o, o)
    edges.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o)
    edges.right:SetWidth(t)
end

-- [ API ]--------------------------------------------------------------------------------------------
-- Flat pixel-perfect outline overshooting the frame, stored at frame[storageKey]; shared by Canvas Mode selection and the datatext highlight.
function Skin:ApplySelectionOutline(frame, storageKey, color)
    if not frame or not storageKey then return end
    local edges = frame[storageKey]
    if not edges then
        edges = {}
        for _, name in ipairs(EDGES) do
            edges[name] = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        end
        frame[storageKey] = edges
    end
    color = color or self.SELECTION_ACCENT
    ApplyGeometry(edges, frame)
    for _, name in ipairs(EDGES) do
        local e = edges[name]
        e:SetColorTexture(color[1], color[2], color[3], color[4])
        e:Show()
    end
end

function Skin:ClearSelectionOutline(frame, storageKey)
    if not frame or not storageKey then return end
    local edges = frame[storageKey]
    if not edges then return end
    for _, name in ipairs(EDGES) do edges[name]:Hide() end
end
