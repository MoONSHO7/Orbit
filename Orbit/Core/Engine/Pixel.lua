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

--- Convert a Physical Pixel count to Logical Units
-- @param count number: Physical pixels (e.g. BorderSize=2 means 2 screen pixels)
-- @param scale number: (Optional) Frame Effective Scale. Defaults to 1.
-- @return number: Logical size that renders as exactly `count` physical pixels
function Pixel:Multiple(count, scale)
    local n = count or 0
    if n <= 0 then return 0 end
    local frameScale = scale or 1
    if frameScale < 0.01 then frameScale = 1 end
    local step = SCREEN_SCALE / frameScale
    return math.max(math.floor(n + 0.5), 1) * step
end

--- Resolve the pixel-snapped border inset for a frame
-- Returns cached borderPixelSize from SkinBorder when available, otherwise computes via Multiple.
-- @param frame Frame: The frame to query
-- @param fallbackSize number: (Optional) Border size in physical pixels if cache miss. Defaults to 0.
-- @return number: Logical size for the border inset
function Pixel:BorderInset(frame, fallbackSize)
    if frame and frame.borderPixelSize then return frame.borderPixelSize end
    return self:Multiple(fallbackSize or 0, frame:GetEffectiveScale())
end

--- Snap X/Y for a given anchor point, accounting for center alignment
-- @param x number: Raw X position
-- @param y number: Raw Y position
-- @param point string: Anchor point (e.g. "TOPLEFT", "CENTER")
-- @param width number: Frame width
-- @param height number: Frame height
-- @param scale number: Frame effective scale
-- @return number, number: Snapped x, y
function Pixel:SnapPosition(x, y, point, width, height, scale)
    if point:find("LEFT", 1, true) or point:find("RIGHT", 1, true) then
        x = self:Snap(x, scale)
    else
        x = self:Snap(x - (width / 2), scale) + (width / 2)
    end
    if point:find("TOP", 1, true) or point:find("BOTTOM", 1, true) then
        y = self:Snap(y, scale)
    else
        y = self:Snap(y - (height / 2), scale) + (height / 2)
    end
    return x, y
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
