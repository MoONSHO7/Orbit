local _, Orbit = ...
local Engine = Orbit.Engine

Engine.Pixel = Engine.Pixel or {}
local Pixel = Engine.Pixel

-- [ STATE ]-----------------------------------------------------------------------------------------
local SCREEN_SCALE = 1

-- [ MATH ]------------------------------------------------------------------------------------------

local function UpdateScreenScale()
    local physicalWidth, physicalHeight = GetPhysicalScreenSize()
    if not physicalHeight or physicalHeight == 0 then
        SCREEN_SCALE = 768.0 / 1080.0
    else
        SCREEN_SCALE = 768.0 / physicalHeight
    end
    
    if Orbit.EventBus then
        Orbit.EventBus:Fire("ORBIT_DISPLAY_SIZE_CHANGED", SCREEN_SCALE)
    end
end

-- Hook event frame to update scale when resolution changes
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", UpdateScreenScale)
-- Initialize immediately
UpdateScreenScale()

--- Get the number of Logical Units per Physical Pixel
-- @return number: Scale factor (cached)
function Pixel:GetScale()
    return SCREEN_SCALE
end

--- Snap a value to the nearest Physical Pixel
-- @param value number: The logical size to snap
-- @param scale number: (Optional) Frame Effective Scale. Defaults to 1.
-- @return number: The snapped value
function Pixel:Snap(value, scale)
    if not value then
        return 0
    end

    -- optimization: cache access
    local pixelScale = SCREEN_SCALE
    local frameScale = scale or 1
    if frameScale < 0.01 then
        frameScale = 1
    end

    local step = pixelScale / frameScale
    return math.floor(value / step + 0.5) * step
end

-- [ ENFORCEMENT ]-----------------------------------------------------------------------------------

--- Enforce pixel-perfect sizing on a frame
-- Hooks SetWidth, SetHeight, SetSize to auto-snap inputs
-- @param frame Frame: The frame to enforce
function Pixel:Enforce(frame)
    if not frame then
        return
    end

    if not frame.OrbitNativeSetWidth then
        frame.OrbitNativeSetWidth = frame.SetWidth
        frame.SetWidth = function(self, width)
            local snapped = Pixel:Snap(width, self:GetEffectiveScale())
            self:OrbitNativeSetWidth(snapped)
        end
    end

    if not frame.OrbitNativeSetHeight then
        frame.OrbitNativeSetHeight = frame.SetHeight
        frame.SetHeight = function(self, height)
            local snapped = Pixel:Snap(height, self:GetEffectiveScale())
            self:OrbitNativeSetHeight(snapped)
        end
    end

    if not frame.OrbitNativeSetSize then
        frame.OrbitNativeSetSize = frame.SetSize
        frame.SetSize = function(self, width, height)
            local scale = self:GetEffectiveScale()
            local snappedW = Pixel:Snap(width, scale)
            local snappedH = Pixel:Snap(height, scale)
            self:OrbitNativeSetSize(snappedW, snappedH)
        end
    end

    -- Initial Snap (if dimensions exist)
    local w, h = frame:GetSize()
    if w and h then
        frame:SetSize(w, h)
    end
end
