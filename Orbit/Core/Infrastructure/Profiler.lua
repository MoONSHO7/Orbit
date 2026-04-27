local _, addonTable = ...
local Orbit = addonTable

-- [ TITLE ] -----------------------------------------------------------------------------------------
-- Orbit Opt-In CPU Profiler
-- Measures millisecond-precision execution time of framework events.
-- Zero overhead when disabled.

Orbit.Profiler = {}
local Profiler = Orbit.Profiler

Profiler.active = false
Profiler.records = {}

function Profiler:IsActive()
    return self.active
end

function Profiler:Start()
    if self.active then
        Orbit:Print("[Profiler] Already active.")
        return
    end
    self.active = true
    self.records = {}
    Orbit:Print("[Profiler] Started. Tracking EventBus cycles...")
end

-- Returns start-tick if profiler is active, nil otherwise. Pair with Profiler:Stop(context, name, start).
function Profiler:Begin()
    if not self.active then return nil end
    return debugprofilestop()
end

-- Pairs with :Begin(). No-op when start is nil (profiler off when work began).
function Profiler:End(context, sourceName, start)
    if not start or not self.active then return end
    self:RecordContext(context, sourceName, debugprofilestop() - start)
end

function Profiler:RecordContext(context, sourceName, elapsedMs)
    if not self.active or not context then return end
    
    local pluginName = type(context) == "table" and (context.name or context.SYSTEM_ID or "Core/Other") or tostring(context)
    
    local record = self.records[pluginName]
    if not record then
        record = {
            totalMs = 0,
            calls = 0,
            maxSpike = 0,
        }
        self.records[pluginName] = record
    end
    
    record.totalMs = record.totalMs + elapsedMs
    record.calls = record.calls + 1
    if elapsedMs > record.maxSpike then
        record.maxSpike = elapsedMs
    end
end

function Profiler:Stop()
    if not self.active then
        Orbit:Print("[Profiler] Not currently running.")
        return
    end
    self.active = false
    
    Orbit:Print("[Profiler] Results:")
    
    local sorted = {}
    for name, data in pairs(self.records) do
        table.insert(sorted, { name = name, data = data })
    end
    table.sort(sorted, function(a, b) return a.data.totalMs > b.data.totalMs end)
    
    if #sorted == 0 then
        Orbit:Print("  No data recorded.")
        return
    end
    
    for i, entry in ipairs(sorted) do
        local name = entry.name
        local d = entry.data
        local color = d.totalMs > 100 and "|cFFFF0000" or (d.totalMs > 20 and "|cFFFFFF00" or "|cFF00FF00")
        Orbit:Print(string.format("  [%d] %s%s|r: %.1fms (Max: %.2fms) | Calls: %d", 
            i, color, name, d.totalMs, d.maxSpike, d.calls))
    end
end

-- [ SLASH COMMAND ] ---------------------------------------------------------------------------------
_G.SLASH_ORBITPERF1 = "/orbitperf"
SlashCmdList["ORBITPERF"] = function(msg)
    local cmd = string.lower(strtrim(msg))
    if cmd == "start" then
        Profiler:Start()
    elseif cmd == "stop" then
        Profiler:Stop()
    else
        Orbit:Print("Usage: /orbitperf start | stop")
    end
end
