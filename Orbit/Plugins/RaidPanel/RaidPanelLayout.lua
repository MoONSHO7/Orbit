-- RaidPanelLayout.lua: Pure arc-wrap and edge-fade math with per-icon variable sizes.

local _, Orbit = ...

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local MIN_FADE_ALPHA  = 0.05
local FADE_CURVE_UNIT = 20

local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_sin = math.sin
local math_cos = math.cos
local math_pi  = math.pi

Orbit.RaidPanelLayout = {}
local Layout = Orbit.RaidPanelLayout

function Layout.ComputeLayout(sizes, spacing, compactness)
    local count = #sizes
    local axialAt = {}
    for i = 1, count do
        if i == 1 then
            axialAt[i] = sizes[1] / 2
        else
            axialAt[i] = axialAt[i - 1] + sizes[i - 1] / 2 + spacing + sizes[i] / 2
        end
    end

    local zeros = {}
    for i = 1, count do zeros[i] = 0 end

    if compactness <= 0.001 or count < 2 then
        local totalAxial = axialAt[count] + sizes[count] / 2
        return axialAt, zeros, totalAxial, 0
    end

    local arcLength = axialAt[count] - axialAt[1]
    local thetaMax = compactness * 2 * math_pi * (count - 1) / count
    local halfTheta = thetaMax / 2
    local radius = arcLength / thetaMax

    local xMin = halfTheta > math_pi / 2 and -radius or radius * (-math_sin(halfTheta))
    local cosHalf = math_cos(halfTheta)

    local axialPositions = {}
    local arcOffsets = {}
    for i = 1, count do
        local relArc = axialAt[i] - axialAt[1]
        local t = arcLength > 0 and (relArc / arcLength) or 0
        local theta = (2 * t - 1) * halfTheta
        local x = radius * math_sin(theta)
        local y = radius * (math_cos(theta) - cosHalf)
        axialPositions[i] = (x - xMin) + sizes[1] / 2
        arcOffsets[i] = y
    end

    local maxAxial, maxPerp = 0, 0
    for i = 1, count do
        local edge = axialPositions[i] + sizes[i] / 2
        if edge > maxAxial then maxAxial = edge end
        if arcOffsets[i] > maxPerp then maxPerp = arcOffsets[i] end
    end
    return axialPositions, arcOffsets, maxAxial, maxPerp
end

function Layout.EdgeAlphaForIndex(iconIndex, count, fadeAmount)
    if not fadeAmount or fadeAmount <= 0 then return 1 end
    local visualCenterIndex = (count + 1) / 2
    local distFromVisualCenter = math_abs((iconIndex + 1) - visualCenterIndex)
    local halfSpan = math_max(1, (count - 1) / 2)
    local normDist = math_max(0, math_min(1, distFromVisualCenter / halfSpan))
    local base = math_cos(normDist * math_pi / 2)
    local power = fadeAmount / FADE_CURVE_UNIT
    return math_max(MIN_FADE_ALPHA, base ^ power)
end
