-- [ ORBIT COLOR CURVE ENGINE ]----------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local ipairs, type = ipairs, type
local math_max, math_min = math.max, math.min
local tinsert, tsort = table.insert, table.sort

Engine.ColorCurve = {}
local CCE = Engine.ColorCurve

local CC = Engine.ClassColor
local nativeCurveCache = setmetatable({}, { __mode = "v" })

-- [ SORTED PIN CACHE ]------------------------------------------------------------------------------
local function GetSortedPins(curveData)
    if curveData._sorted then return curveData._sorted end
    local sorted = {}
    for _, p in ipairs(curveData.pins) do sorted[#sorted + 1] = p end
    tsort(sorted, function(a, b) return a.position < b.position end)
    curveData._sorted = sorted
    return sorted
end

function CCE:CurveHasClassPin(curveData)
    if not curveData or not curveData.pins then return false end
    for _, pin in ipairs(curveData.pins) do
        if pin.type == "class" then return true end
    end
    return false
end

function CCE:SampleColorCurve(curveData, position)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    local pins = curveData.pins
    if #pins == 1 then return CC:ResolveClassColorPin(pins[1]) end
    local sorted = GetSortedPins(curveData)
    position = math_max(0, math_min(1, position))
    local first, last = sorted[1], sorted[#sorted]
    if position <= first.position then return CC:ResolveClassColorPin(first) end
    if position >= last.position then return CC:ResolveClassColorPin(last) end
    local left, right = first, last
    for i = 1, #sorted - 1 do
        if sorted[i].position <= position and sorted[i + 1].position >= position then
            left, right = sorted[i], sorted[i + 1]
            break
        end
    end
    local leftColor = CC:ResolveClassColorPin(left)
    local rightColor = CC:ResolveClassColorPin(right)
    local range = right.position - left.position
    local t = (range > 0) and math_max(0, math_min(1, (position - left.position) / range)) or 0
    return {
        r = leftColor.r + (rightColor.r - leftColor.r) * t,
        g = leftColor.g + (rightColor.g - leftColor.g) * t,
        b = leftColor.b + (rightColor.b - leftColor.b) * t,
        a = (leftColor.a or 1) + ((rightColor.a or 1) - (leftColor.a or 1)) * t,
    }
end

function CCE:GetFirstColorFromCurve(curveData)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    return CC:ResolveClassColorPin(GetSortedPins(curveData)[1])
end

function CCE:GetFontColorForNonUnit(curveData)
    local WHITE = { r = 1, g = 1, b = 1, a = 1 }
    if not curveData or not curveData.pins or #curveData.pins == 0 then return WHITE end
    if self:CurveHasClassPin(curveData) then return WHITE end
    return self:GetFirstColorFromCurve(curveData) or WHITE
end

function CCE:GetFirstColorFromCurveForUnit(curveData, unit)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    return CC:ResolveClassColorPinForUnit(GetSortedPins(curveData)[1], unit)
end

function CCE:ToNativeColorCurveForUnit(curveData, unit)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return nil end
    local curve = C_CurveUtil.CreateColorCurve()
    for _, pin in ipairs(curveData.pins) do
        local color = CC:ResolveClassColorPinForUnit(pin, unit)
        curve:AddPoint(pin.position, CreateColor(color.r, color.g, color.b, color.a or 1))
    end
    return curve
end

-- [ NATIVE COLORCURVE CONVERSION ]------------------------------------------------------------------
function CCE:ToNativeColorCurve(curveData)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return nil end
    local hasClassPin = self:CurveHasClassPin(curveData)
    if not hasClassPin and nativeCurveCache[curveData] then return nativeCurveCache[curveData] end
    local curve = C_CurveUtil.CreateColorCurve()
    for _, pin in ipairs(curveData.pins) do
        local color = CC:ResolveClassColorPin(pin)
        curve:AddPoint(pin.position, CreateColor(color.r, color.g, color.b, color.a or 1))
    end
    if not hasClassPin then nativeCurveCache[curveData] = curve end
    return curve
end

function CCE:FromNativeColorCurve(nativeCurve)
    if not nativeCurve or not nativeCurve.GetPoints then return nil end
    local pins = {}
    for _, point in ipairs(nativeCurve:GetPoints()) do
        local color = point.y
        tinsert(pins, { position = point.x, color = { r = color.r, g = color.g, b = color.b, a = color.a or 1 } })
    end
    return { pins = pins }
end

function CCE:InvalidateNativeCurveCache(curveData)
    if curveData then
        nativeCurveCache[curveData] = nil
        curveData._sorted = nil
    end
end
