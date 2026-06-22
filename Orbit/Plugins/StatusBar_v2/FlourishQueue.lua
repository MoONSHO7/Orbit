---@type Orbit
local Orbit = Orbit
local Plugin = Orbit:GetPlugin("Status Bar v2")

-- [ FLOURISH QUEUE ]---------------------------------------------------------------------------------
-- The single serialization point for every centre flourish (vault / social / mail / loot / milestones).
-- Events ENQUEUE requests instead of playing immediately, so they never overwrite each other. Timing:
--   * each flourish holds the centre for at least BUFFER seconds,
--   * if nothing is waiting it extends to IDLE_HOLD (the extra time IS the "end animation" / linger),
--   * the end animation never plays while a request is queued — the next one hard-cuts in at BUFFER.
-- A request = { kind, render = function(plugin), selfPaced = bool? }. selfPaced flourishes (the loot
-- reel) run their own internal sequence and call _FqBurstDone() when their content is finished.
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

-- Enqueue a flourish. Plays now if idle; if the current one is in its idle linger, cut it and advance
-- (an end animation must never run while something waits).
function Plugin:Enqueue(req)
    if self._disabled or not self.frame then return end   -- a live-disabled orb plays no centre flourishes
    self._fqQueue = self._fqQueue or {}
    self._fqQueue[#self._fqQueue + 1] = req
    if not self._fqActive then
        self:_FqAdvance()
    elseif self._fqPhase == "linger" or self._fqPhase == "fadeout" then
        -- Cut the end animation (linger or the 0.5s dissolve) the instant something waits: _FqAdvance cancels
        -- the FADE timer + stops FlourishTextOut, and _EnterEvent restores the centre alpha, so it's clean.
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

-- BUFFER reached (or selfPaced content done): advance immediately if anything waits, else linger to
-- IDLE_HOLD then play the end animation (text fade) and advance (which, empty, exits).
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
