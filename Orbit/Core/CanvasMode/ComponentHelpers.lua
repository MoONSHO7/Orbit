-- [ ORBIT COMPONENT HELPERS ]------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

Engine.ComponentHelpers = {}
local Helpers = Engine.ComponentHelpers

-- [ CONFIGURATION ] ---------------------------------------------------------------------------------
Helpers.PADDING = 25 -- Drag boundary padding
local DEFAULT_MIN_WIDTH = 40
local DEFAULT_MIN_HEIGHT = 16
local IsSecret = issecretvalue or function() return false end

-- [ SAFE SIZE ACCESSOR ] ----------------------------------------------------------------------------
-- IsSecret filters secret returns before any comparison; plain region getters do not throw.
local function IsUsable(val)
    return val and not IsSecret(val) and type(val) == "number" and val > 0
end

local function SafeDimension(val, region, fallbackGetter)
    if not IsUsable(val) and fallbackGetter then
        val = fallbackGetter(region)
    end
    if IsUsable(val) then return val end
    return nil
end

local function GetRegionWidth(region) return region:GetWidth() end
local function GetRegionHeight(region) return region:GetHeight() end

function Helpers.SafeGetSize(region)
    if not region then
        return DEFAULT_MIN_WIDTH, DEFAULT_MIN_HEIGHT
    end

    -- For FontStrings, prefer GetStringWidth/GetStringHeight for actual text bounds
    local isFontString = region.GetStringWidth ~= nil

    local w
    if isFontString then
        w = SafeDimension(region:GetStringWidth(), region, region.GetWidth and GetRegionWidth)
    else
        w = SafeDimension(region:GetWidth(), region, nil)
    end

    local h
    if isFontString then
        h = SafeDimension(region:GetStringHeight(), region, region.GetHeight and GetRegionHeight)
    else
        h = SafeDimension(region:GetHeight(), region, nil)
    end

    return w or DEFAULT_MIN_WIDTH, h or DEFAULT_MIN_HEIGHT
end

-- [ SAFE NUMBER ACCESSOR ] --------------------------------------------------------------------------
function Helpers.SafeGetNumber(val, default)
    if val == nil then
        return default
    end
    if issecretvalue and issecretvalue(val) then
        return default
    end
    if type(val) ~= "number" then
        return default
    end
    return val
end

