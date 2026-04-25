local _, Orbit = ...
local Engine = Orbit.Engine

Engine.Pixel = Engine.Pixel or {}
local Pixel = Engine.Pixel

-- [ STATE ]------------------------------------------------------------------------------------------
local WOW_REFERENCE_HEIGHT = 768
local SCREEN_SCALE = 1

-- [ MATH ]-------------------------------------------------------------------------------------------
local function UpdateScreenScale()
    local physicalWidth, physicalHeight = GetPhysicalScreenSize()
    if not physicalHeight or physicalHeight == 0 then
        SCREEN_SCALE = WOW_REFERENCE_HEIGHT / 1080
    else
        SCREEN_SCALE = WOW_REFERENCE_HEIGHT / physicalHeight
    end

    Orbit.EventBus:Fire("ORBIT_DISPLAY_SIZE_CHANGED", SCREEN_SCALE)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", UpdateScreenScale)
UpdateScreenScale()

function Pixel:GetScale()
    return SCREEN_SCALE
end

function Pixel:Snap(value, scale)
    if not value then
        return 0
    end

    local pixelScale = SCREEN_SCALE
    local frameScale = scale or 1
    -- Clamp non-positive scales to 1; division-by-near-zero would explode the snap.
    if frameScale < 0.01 then
        frameScale = 1
    end

    local step = pixelScale / frameScale
    return math.floor(value / step + 0.5) * step
end

-- Logical size that renders as exactly `count` physical pixels.
function Pixel:Multiple(count, scale)
    local n = count or 0
    if n == 0 then return 0 end
    local sign = n > 0 and 1 or -1
    local abs = math.abs(n)
    local frameScale = scale or 1
    if frameScale < 0.01 then frameScale = 1 end
    local step = SCREEN_SCALE / frameScale
    return sign * math.max(math.floor(abs + 0.5), 1) * step
end

-- Prefer SkinBorder's cached borderPixelSize over recomputing — keeps inset stable across re-skins.
function Pixel:BorderInset(frame, fallbackSize)
    if frame and frame.borderPixelSize then return frame.borderPixelSize end
    return self:Multiple(fallbackSize or 0, frame:GetEffectiveScale())
end

function Pixel:DefaultBorderSize(scale)
    return self:Multiple(1, scale)
end

-- Center-anchored points snap relative to the center, not the edge — otherwise width/height drift after Snap.
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

-- [ ENFORCEMENT ]------------------------------------------------------------------------------------
-- Hooks SetWidth/SetHeight/SetSize on a frame so all caller inputs auto-snap to physical pixels.
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

    local w, h = frame:GetSize()
    if w and h then
        frame:SetSize(w, h)
    end
end
