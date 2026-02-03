-- [ ORBIT FRAME ORIENTATION ]----------------------------------------------------------------------
-- Detects frame orientation based on screen position and provides real-time
-- orientation tracking during Edit Mode dragging.
--
-- Usage:
--   frame.orbitAutoOrient = true  -- Enable auto-orientation tracking
--   OrbitEngine.Frame:RegisterOrientationCallback(frame, function(orientation)
--       -- Handle orientation change: "LEFT", "RIGHT", "TOP", "BOTTOM"
--   end)

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameOrientation = {}
local Orientation = Engine.FrameOrientation

-- [ STATE ]-----------------------------------------------------------------------------------------

Orientation.callbacks = {} -- frame -> callback function
Orientation.lastOrientation = {} -- frame -> last detected orientation
Orientation.trackedFrames = {} -- frames currently being tracked during drag

-- [ ORIENTATION DETECTION ]------------------------------------------------------------------------

--- Detect orientation based on frame position relative to screen edges
---@param frame Frame The frame to detect orientation for
---@return string orientation "LEFT", "RIGHT", "TOP", or "BOTTOM"
function Orientation:DetectOrientation(frame)
    if not frame or not frame.GetLeft then
        return "LEFT"
    end

    local left, bottom = frame:GetLeft(), frame:GetBottom()
    local width, height = frame:GetWidth(), frame:GetHeight()

    if not left or not bottom or not width or not height then
        return "LEFT"
    end

    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
    local frameCenterX = left + (width / 2)
    local frameCenterY = bottom + (height / 2)

    -- Calculate distances to each edge
    local distToLeft = frameCenterX
    local distToRight = screenWidth - frameCenterX
    local distToTop = screenHeight - frameCenterY
    local distToBottom = frameCenterY

    -- Find the minimum distance
    local minDist = math.min(distToLeft, distToRight, distToTop, distToBottom)

    -- Return orientation based on nearest edge
    if minDist == distToLeft then
        return "LEFT" -- Vertical, arc curves right (toward center)
    elseif minDist == distToRight then
        return "RIGHT" -- Vertical, arc curves left (toward center)
    elseif minDist == distToTop then
        return "TOP" -- Horizontal, arc curves down (toward center)
    else
        return "BOTTOM" -- Horizontal, arc curves up (toward center)
    end
end

-- [ CALLBACK REGISTRATION ]------------------------------------------------------------------------

--- Register a callback for orientation changes
---@param frame Frame The frame to track
---@param callback function Called with (orientation) when orientation changes
function Orientation:RegisterCallback(frame, callback)
    if not frame or not callback then
        return
    end
    self.callbacks[frame] = callback
    self.lastOrientation[frame] = self:DetectOrientation(frame)
end

--- Unregister orientation callback for a frame
---@param frame Frame The frame to stop tracking
function Orientation:UnregisterCallback(frame)
    self.callbacks[frame] = nil
    self.lastOrientation[frame] = nil
end

-- [ DRAG TRACKING ]--------------------------------------------------------------------------------

local function OnDragUpdate(self, elapsed)
    local Orientation = Engine.FrameOrientation

    for frame in pairs(Orientation.trackedFrames) do
        local newOrientation = Orientation:DetectOrientation(frame)
        local lastOrientation = Orientation.lastOrientation[frame]

        if newOrientation ~= lastOrientation then
            Orientation.lastOrientation[frame] = newOrientation

            local callback = Orientation.callbacks[frame]
            if callback then
                callback(newOrientation)
            end
        end
    end
end

-- Hidden frame for OnUpdate during drag
local updateFrame = nil

local function EnsureUpdateFrame()
    if not updateFrame then
        updateFrame = CreateFrame("Frame")
        updateFrame:Hide()
    end
    return updateFrame
end

--- Start tracking orientation changes during drag
---@param frame Frame The frame being dragged
function Orientation:StartTracking(frame)
    if not frame then
        return
    end

    self.trackedFrames[frame] = true
    self.lastOrientation[frame] = self:DetectOrientation(frame)

    local uf = EnsureUpdateFrame()
    uf:SetScript("OnUpdate", OnDragUpdate)
    uf:Show()
end

--- Stop tracking orientation changes
---@param frame Frame The frame that stopped dragging
function Orientation:StopTracking(frame)
    if not frame then
        return
    end

    self.trackedFrames[frame] = nil

    -- Check if any frames are still being tracked
    local hasTracked = false
    for _ in pairs(self.trackedFrames) do
        hasTracked = true
        break
    end

    if not hasTracked and updateFrame then
        updateFrame:SetScript("OnUpdate", nil)
        updateFrame:Hide()
    end
end

-- [ HELPERS ]--------------------------------------------------------------------------------------

--- Check if an orientation is horizontal
---@param orientation string The orientation to check
---@return boolean isHorizontal True if TOP or BOTTOM
function Orientation:IsHorizontal(orientation)
    return orientation == "TOP" or orientation == "BOTTOM"
end

--- Check if an orientation is vertical
---@param orientation string The orientation to check
---@return boolean isVertical True if LEFT or RIGHT
function Orientation:IsVertical(orientation)
    return orientation == "LEFT" or orientation == "RIGHT"
end
