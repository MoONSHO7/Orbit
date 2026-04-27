-- [ ORBIT AXIS ]-------------------------------------------------------------------------------------
-- First-class orientation primitive. Edge + accessor pairs live here so anchor code is axis-agnostic.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.Axis = Engine.Axis or {}
local Axis = Engine.Axis

-- [ MIN SYNC SIZES ] --------------------------------------------------------------------------------
local MIN_SYNC_HEIGHT = 5
local MIN_SYNC_WIDTH = 10

-- [ AXIS TABLES ] -----------------------------------------------------------------------------------
-- forward  = edge in the direction of increasing screen coordinate (RIGHT/TOP)
-- backward = opposite edge (LEFT/BOTTOM)
-- getSize/setSize = along-axis dimension (width for horizontal, height for vertical)
-- getMin/getMax   = screen-space frame edge coordinates on this axis
-- rowDim          = frame field for explicit per-axis dimension override (useRowDimension path)
-- independentFlag = anchorOption key that gates cross-axis sync when anchoring perpendicular
-- syncFlag        = frame field that opts the frame into cross-axis size sync from its parent
Axis.horizontal = {
    name            = "horizontal",
    edges           = { LEFT = true, RIGHT = true },
    forward         = "RIGHT",
    backward        = "LEFT",
    getSize         = function(f) return f:GetWidth() end,
    setSize         = function(f, v) f:SetWidth(v) end,
    getMin          = function(f) return f:GetLeft() end,
    getMax          = function(f) return f:GetRight() end,
    minSize         = MIN_SYNC_WIDTH,
    rowDim          = "orbitColumnWidth",
    independentFlag = "independentWidth",
    syncFlag        = "orbitWidthSync",
}

Axis.vertical = {
    name            = "vertical",
    edges           = { TOP = true, BOTTOM = true },
    forward         = "TOP",
    backward        = "BOTTOM",
    getSize         = function(f) return f:GetHeight() end,
    setSize         = function(f, v) f:SetHeight(v) end,
    getMin          = function(f) return f:GetBottom() end,
    getMax          = function(f) return f:GetTop() end,
    minSize         = MIN_SYNC_HEIGHT,
    rowDim          = "orbitRowHeight",
    independentFlag = "independentHeight",
    syncFlag        = "orbitHeightSync",
}

Axis.horizontal.perpendicular = Axis.vertical
Axis.vertical.perpendicular = Axis.horizontal

-- [ EDGE LOOKUP ] -----------------------------------------------------------------------------------
local EDGE_TO_AXIS = {
    LEFT = Axis.horizontal, RIGHT = Axis.horizontal,
    TOP  = Axis.vertical,   BOTTOM = Axis.vertical,
}

function Axis.ForEdge(edge) return EDGE_TO_AXIS[edge] end

-- [ AXIS SYNC FLAG RESOLVER ] -----------------------------------------------------------------------
-- Reads the per-axis boolean frame flag (orbitWidthSync for horizontal, orbitHeightSync for vertical).
function Axis.SyncEnabled(frame, axis)
    return frame[axis.syncFlag] == true
end
