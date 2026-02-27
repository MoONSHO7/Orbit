-- [ ORBIT NUDGE REPEAT ]----------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

local NudgeRepeat = {}
Engine.NudgeRepeat = NudgeRepeat

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local REPEAT_DELAY = 0.4
local REPEAT_RATE = 0.05

-- [ STATE ]-----------------------------------------------------------------------------------------

local repeatTimer = nil
local currentCallback = nil

-- [ API ]-------------------------------------------------------------------------------------------

function NudgeRepeat:Start(callback, checkActive)
    self:Stop()
    currentCallback = callback
    repeatTimer = C_Timer.NewTimer(REPEAT_DELAY, function()
        if checkActive and checkActive() then
            repeatTimer = C_Timer.NewTicker(REPEAT_RATE, function()
                if checkActive and checkActive() then
                    if currentCallback then currentCallback() end
                else
                    NudgeRepeat:Stop()
                end
            end)
        end
    end)
end

function NudgeRepeat:Stop()
    if repeatTimer then
        repeatTimer:Cancel()
        repeatTimer = nil
    end
    currentCallback = nil
end
