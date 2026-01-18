-- [ ORBIT COMPONENT HELPERS ]-----------------------------------------------------------------------
-- Shared utility functions for component positioning and sizing.
-- Handles WoW 12.0+ secret values safely.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.ComponentHelpers = {}
local Helpers = Engine.ComponentHelpers

-- [ CONFIGURATION ]-----------------------------------------------------------------------------

Helpers.PADDING = 25  -- Drag boundary padding

-- [ SAFE SIZE ACCESSOR ]------------------------------------------------------------------------

-- For FontStrings, uses GetStringWidth/GetStringHeight which return actual text bounds
function Helpers.SafeGetSize(region)
    if not region then
        return 40, 16 -- Default minimum size
    end
    
    local width, height = 40, 16 -- Defaults
    
    -- For FontStrings, prefer GetStringWidth/GetStringHeight for actual text bounds
    local isFontString = region.GetStringWidth ~= nil
    
    -- Try to get width
    local ok, w = pcall(function()
        local val
        if isFontString then
            val = region:GetStringWidth()
            if (not val or val <= 0) and region.GetWidth then
                val = region:GetWidth()
            end
        else
            val = region:GetWidth()
        end
        if issecretvalue and issecretvalue(val) then
            return nil
        end
        return val
    end)
    if ok and w and type(w) == "number" and w > 0 then
        width = w
    end
    
    -- Try to get height
    local ok2, h = pcall(function()
        local val
        if isFontString then
            val = region:GetStringHeight()
            if (not val or val <= 0) and region.GetHeight then
                val = region:GetHeight()
            end
        else
            val = region:GetHeight()
        end
        if issecretvalue and issecretvalue(val) then
            return nil
        end
        return val
    end)
    if ok2 and h and type(h) == "number" and h > 0 then
        height = h
    end
    
    return width, height
end

-- [ SAFE NUMBER ACCESSOR ]----------------------------------------------------------------------

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

-- [ CLAMP POSITION ]----------------------------------------------------------------------------

function Helpers.ClampPosition(x, y, parentWidth, parentHeight)
    x = Helpers.SafeGetNumber(x, 0)
    y = Helpers.SafeGetNumber(y, 0)
    parentWidth = Helpers.SafeGetNumber(parentWidth, 100)
    parentHeight = Helpers.SafeGetNumber(parentHeight, 40)
    
    local PADDING = Helpers.PADDING
    local clampedX = math.max(-PADDING, math.min(x, parentWidth + PADDING))
    local clampedY = math.max(-PADDING, math.min(y, parentHeight + PADDING))
    return clampedX, clampedY
end
