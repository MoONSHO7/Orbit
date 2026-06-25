---@type Orbit
local Orbit = Orbit
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ FLOURISH QUEUE ]---------------------------------------------------------------------------------
local BUFFER = 3
local IDLE_HOLD = 5
local FADE = 0.5   -- text fade-out (the linger's tail); kept in lockstep with FlourishTextOut's duration

function Plugin:_FqTimer(delay, fn)
    self:_FqCancelTimer()
    self._fqTimer = C_Timer.NewTimer(delay, fn)
end

function Plugin:_FqCancelTimer()
    if self._fqTimer then self._fqTimer:Cancel(); self._fqTimer = nil end
end

function Plugin:Enqueue(req)
    if self._disabled or not self.frame then return end   -- a live-disabled orb plays no centre flourishes
    if self:_MPlusSilencing() and req.kind ~= "shatter" then return end   -- silence toasts in a key, but never the durability warning
    self._fqQueue = self._fqQueue or {}
    self._fqQueue[#self._fqQueue + 1] = req
    if not self._fqActive then
        self:_FqAdvance()
    elseif self._fqPhase == "linger" or self._fqPhase == "fadeout" then
        -- Cut the end animation the instant something waits; _FqAdvance cancels the FADE timer and _EnterEvent restores the centre alpha.
        self:_FqAdvance()
    end
end

-- Pop and play the next request, or end the run (conceal) when the queue drains.
function Plugin:_FqAdvance()
    self:_FqCancelTimer()
    self.frame.FlourishTextOut:Stop()
    local req = self._fqQueue and table.remove(self._fqQueue, 1)
    if not req then
        self._fqActive, self._fqPhase = nil, nil
        self:_ExitEvent()
        return
    end
    self._fqActive, self._fqPhase = req, "burst"
    self:_EnterEvent(req.kind)
    req.render(self)
    if not req.selfPaced then
        self:_FqTimer(BUFFER, function() self:_FqBufferElapsed() end)
    end
end

-- A selfPaced flourish (loot reel) hands timing back here when its content finishes.
function Plugin:_FqBurstDone()
    if self._fqPhase == "burst" then self:_FqBufferElapsed() end
end

function Plugin:_FqBufferElapsed()
    self:_FqCancelTimer()
    if self._fqQueue and #self._fqQueue > 0 then
        self:_FqAdvance()
        return
    end
    self._fqPhase = "linger"
    self:_FqTimer(IDLE_HOLD - BUFFER, function()
        self._fqPhase = "fadeout"
        self.frame.FlourishTextOut:Play()
        self.frame.CenterFadeOut:Play()   -- fade the whole centre (vignette + icon + FX) WITH the text
        self:_FqTimer(FADE, function() self:_FqAdvance() end)
    end)
end
