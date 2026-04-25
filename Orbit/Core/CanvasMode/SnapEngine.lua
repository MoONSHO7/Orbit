-- [ CANVAS MODE - SNAP ENGINE ]----------------------------------------------------------------------
-- Unified edge-magnet and grid-round logic for component positioning.
-- Used by ComponentRegistry, CanvasModeDrag, and CastBarCreator.

local _, Orbit = ...
local Engine = Orbit.Engine
local CanvasMode = Engine.CanvasMode

CanvasMode.SnapEngine = {}
local Snap = CanvasMode.SnapEngine

local SNAP_SIZE = 5
local EDGE_THRESHOLD = SNAP_SIZE

-- [ EDGE MAGNET ]------------------------------------------------------------------------------------
-- Snap component edge flush to parent edge when within threshold.
-- Returns snapped position and guide hint, or nil if no magnet.
local function EdgeMagnet(relPos, halfParent, compHalf, threshold)
    local distPositive = math.abs((relPos + compHalf) - halfParent)
    local distNegative = math.abs((relPos - compHalf) + halfParent)
    if distPositive <= threshold then return halfParent - compHalf, true end
    if distNegative <= threshold then return -halfParent + compHalf, true end
    if math.abs(relPos) <= threshold then return 0, true end
    return relPos, false
end

-- [ GRID ROUND ]-------------------------------------------------------------------------------------
local function GridRound(value, gridSize) return math.floor(value / gridSize + 0.5) * gridSize end

-- [ SNAP AXIS ]--------------------------------------------------------------------------------------
-- Performs edge-magnet then grid-round on a single axis.
-- Returns: snappedValue, guideHint ("LEFT"/"RIGHT"/"CENTER"/"TOP"/"BOTTOM" or nil)
local GUIDE_X = { [true] = { pos = "RIGHT", neg = "LEFT", center = "CENTER" } }
local GUIDE_Y = { [true] = { pos = "TOP", neg = "BOTTOM", center = "CENTER" } }

function Snap:SnapAxis(relPos, halfParent, compHalf, guideMap, options)
    if options and options.precisionMode then return relPos, nil end
    local threshold = (options and options.edgeThreshold) or EDGE_THRESHOLD
    local gridSize = options and options.gridSize
    local snapped, magnetted = EdgeMagnet(relPos, halfParent, compHalf, threshold)
    if magnetted then
        local guide = guideMap and guideMap[true]
        if not guide then return snapped, nil end
        if snapped > 0 then return snapped, guide.pos
        elseif snapped < 0 then return snapped, guide.neg
        else return snapped, guide.center end
    end
    if gridSize then snapped = GridRound(snapped, gridSize) end
    return snapped, nil
end

-- [ SNAP POSITION ]----------------------------------------------------------------------------------
-- Full 2-axis snap: edge-magnet + grid-round.
-- @param relX, relY: center-relative position
-- @param halfW, halfH: half parent dimensions
-- @param compHalfW, compHalfH: half component dimensions
-- @param options: { precisionMode, edgeThreshold, gridSize, edgeOnly }
-- @return snappedX, snappedY, guideX, guideY
function Snap:Calculate(relX, relY, halfW, halfH, compHalfW, compHalfH, options)
    local snapX, guideX = self:SnapAxis(relX, halfW, compHalfW, GUIDE_X, options)
    local snapY, guideY = self:SnapAxis(relY, halfH, compHalfH, GUIDE_Y, options)
    return snapX, snapY, guideX, guideY
end

-- [ CONSTANTS ACCESS ]-------------------------------------------------------------------------------
Snap.EDGE_THRESHOLD = EDGE_THRESHOLD
Snap.SNAP_SIZE = SNAP_SIZE
