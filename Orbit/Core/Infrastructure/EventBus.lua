local _, addonTable = ...
local Orbit = addonTable

---@class OrbitEventBus
Orbit.EventBus = {}
local EventBus = Orbit.EventBus
EventBus.listeners = {}
local eventFrame = CreateFrame("Frame")
local customEvents = {}

local function IsWoWEvent(event)
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if ok then eventFrame:UnregisterEvent(event) end
    return ok
end

function EventBus:On(event, callback, context)
    if not self.listeners[event] then
        self.listeners[event] = {}
        if customEvents[event] == nil then customEvents[event] = not IsWoWEvent(event) end
        if not customEvents[event] then eventFrame:RegisterEvent(event) end
    end
    local listener = { callback = callback, context = context }
    table.insert(self.listeners[event], listener)
    return listener
end

function EventBus:Off(event, callback)
    if not self.listeners[event] then
        return false
    end
    for i = #self.listeners[event], 1, -1 do
        if self.listeners[event][i].callback == callback then
            table.remove(self.listeners[event], i)
            if #self.listeners[event] == 0 then
                if not customEvents[event] then eventFrame:UnregisterEvent(event) end
                self.listeners[event] = nil
            end
            return true
        end
    end
    return false
end

function EventBus:OffContext(context)
    for event, listeners in pairs(self.listeners) do
        for i = #listeners, 1, -1 do
            if listeners[i].context == context then
                table.remove(listeners, i)
            end
        end
        if #listeners == 0 then
            if not customEvents[event] then eventFrame:UnregisterEvent(event) end
            self.listeners[event] = nil
        end
    end
end

function EventBus:Fire(event, ...)
    local listeners = self.listeners[event]
    if not listeners then
        return
    end
    -- Snapshot before dispatch — guards against double-fire on error path and listener-re-visit when a callback runs Off/OffContext mid-fire.
    local n = #listeners
    local snapshot = {}
    for i = 1, n do snapshot[i] = listeners[i] end
    local profilerActive = Orbit.Profiler and Orbit.Profiler:IsActive()
    for i = 1, n do
        local listener = snapshot[i]
        local start = profilerActive and debugprofilestop() or nil
        local ok, err
        if listener.context then
            ok, err = pcall(listener.callback, listener.context, ...)
        else
            ok, err = pcall(listener.callback, ...)
        end
        if start then
            Orbit.Profiler:RecordContext(listener.context, event, debugprofilestop() - start)
        end
        if not ok then
            Orbit:Print("|cFFFF0000EventBus Error|r in", event, ":", tostring(err))
            if Orbit.ErrorHandler then
                Orbit.ErrorHandler:LogError("EventBus", event, err)
            end
        end
    end
end

function EventBus:HasListeners(event)
    return self.listeners[event] ~= nil and #self.listeners[event] > 0
end

function EventBus:GetListenerCount(event)
    return self.listeners[event] and #self.listeners[event] or 0
end

function EventBus:Clear()
    for event in pairs(self.listeners) do
        if not customEvents[event] then eventFrame:UnregisterEvent(event) end
    end
    self.listeners = {}
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    EventBus:Fire(event, ...)
end)
