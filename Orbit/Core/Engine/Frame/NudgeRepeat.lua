-- [ ORBIT NUDGE REPEAT ]----------------------------------------------------------------------------
-- Shared nudge repeat timer logic for frame and component nudging

local _, Orbit = ...
local Engine = Orbit.Engine

local NudgeRepeat = {}
Engine.NudgeRepeat = NudgeRepeat

-------------------------------------------------
-- CONFIGURATION
-------------------------------------------------

local REPEAT_DELAY = 0.4 -- Initial delay before repeat starts
local REPEAT_RATE = 0.05 -- Rate of repeat (20 nudges/sec)

-------------------------------------------------
-- STATE
-------------------------------------------------

local repeatTimer = nil
local currentCallback = nil

-------------------------------------------------
-- API
-------------------------------------------------

-- Start repeat nudging with a callback
-- @param callback: function() called on each repeat tick
-- @param checkActive: function() returns true if nudging should continue
function NudgeRepeat:Start(callback, checkActive)
    self:Stop()

    currentCallback = callback

    repeatTimer = C_Timer.NewTimer(REPEAT_DELAY, function()
        if checkActive and checkActive() then
            repeatTimer = C_Timer.NewTicker(REPEAT_RATE, function()
                if checkActive and checkActive() then
                    if currentCallback then
                        currentCallback()
                    end
                else
                    NudgeRepeat:Stop()
                end
            end)
        end
    end)
end

-- Stop repeat nudging
function NudgeRepeat:Stop()
    if repeatTimer then
        repeatTimer:Cancel()
        repeatTimer = nil
    end
    currentCallback = nil
end
