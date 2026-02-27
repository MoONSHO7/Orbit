-- [ ORBIT ICON MONITOR ]----------------------------------------------------------------------------
local _, Orbit = ...
local Skin = Orbit.Skin
local Constants = Orbit.Constants
Skin.IconMonitor = {}
local IM = Skin.IconMonitor

IM.tickers = setmetatable({}, { __mode = "k" })
IM.monitoredFrames = setmetatable({}, { __mode = "k" })

function IM:Start(frame, skinCallback)
    if not frame then return end
    if self.tickers[frame] then self.tickers[frame]:Cancel(); self.tickers[frame] = nil end
    local lastIconCount = 0
    self.tickers[frame] = C_Timer.NewTicker(Constants.Timing.IconMonitorInterval, function()
        if InCombatLockdown() then return end
        if not frame or not frame:IsShown() then
            if not frame then self:Stop(frame) end
            return
        end
        local icons = frame.GetLayoutChildren and frame:GetLayoutChildren() or { frame:GetChildren() }
        local currentCount = #icons
        if currentCount ~= lastIconCount then
            skinCallback(frame)
            lastIconCount = currentCount
        end
    end)
    self.monitoredFrames[frame] = true
end

function IM:Stop(frame)
    if self.tickers[frame] then self.tickers[frame]:Cancel(); self.tickers[frame] = nil end
end

function IM:IsMonitored(frame) return self.monitoredFrames[frame] end
