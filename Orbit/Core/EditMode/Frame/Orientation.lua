-- [ ORBIT FRAME ORIENTATION ]----------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameOrientation = {}
local Orientation = Engine.FrameOrientation

-- [ STATE ]-----------------------------------------------------------------------------------------
Orientation.callbacks = {} -- frame -> callback function
Orientation.lastOrientation = {} -- frame -> last detected orientation
Orientation.trackedFrames = {} -- frames currently being tracked during drag

-- [ ORIENTATION DETECTION ]------------------------------------------------------------------------
function Orientation:DetectOrientation(frame)
    if not frame or not frame.GetLeft then return "LEFT" end

    local left, bottom = frame:GetLeft(), frame:GetBottom()
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not left or not bottom or not width or not height then return "LEFT" end

    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
    local frameCenterX = left + (width / 2)
    local frameCenterY = bottom + (height / 2)

    local distToLeft = frameCenterX
    local distToRight = screenWidth - frameCenterX
    local distToTop = screenHeight - frameCenterY
    local distToBottom = frameCenterY

    local minDist = math.min(distToLeft, distToRight, distToTop, distToBottom)

    if minDist == distToLeft then return "LEFT"
    elseif minDist == distToRight then return "RIGHT"
    elseif minDist == distToTop then return "TOP"
    else return "BOTTOM" end
end

-- [ CALLBACK REGISTRATION ]------------------------------------------------------------------------
function Orientation:RegisterCallback(frame, callback)
    if not frame or not callback then return end
    self.callbacks[frame] = callback
    self.lastOrientation[frame] = self:DetectOrientation(frame)
end

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

function Orientation:StartTracking(frame)
    if not frame then return end
    self.trackedFrames[frame] = true
    self.lastOrientation[frame] = self:DetectOrientation(frame)
    local uf = EnsureUpdateFrame()
    uf:SetScript("OnUpdate", OnDragUpdate)
    uf:Show()
end

function Orientation:StopTracking(frame)
    if not frame then return end
    self.trackedFrames[frame] = nil
    if not next(self.trackedFrames) and updateFrame then
        updateFrame:SetScript("OnUpdate", nil)
        updateFrame:Hide()
    end
end

-- [ HELPERS ]--------------------------------------------------------------------------------------
function Orientation:IsHorizontal(orientation)
    return orientation == "TOP" or orientation == "BOTTOM"
end

function Orientation:IsVertical(orientation)
    return orientation == "LEFT" or orientation == "RIGHT"
end
