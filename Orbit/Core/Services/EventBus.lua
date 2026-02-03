local _, addonTable = ...
local Orbit = addonTable

---@class OrbitEventBus
Orbit.EventBus = {}
local EventBus = Orbit.EventBus
EventBus.listeners = {}
local eventFrame = CreateFrame("Frame")

function EventBus:On(event, callback, context)
    if not self.listeners[event] then
        self.listeners[event] = {}
        pcall(eventFrame.RegisterEvent, eventFrame, event)
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
                eventFrame:UnregisterEvent(event)
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
            eventFrame:UnregisterEvent(event)
            self.listeners[event] = nil
        end
    end
end

function EventBus:Fire(event, ...)
    local listeners = self.listeners[event]
    if not listeners then
        return
    end
    for i = #listeners, 1, -1 do
        local listener = listeners[i]
        if listener then
            local ok, err = listener.context and pcall(listener.callback, listener.context, ...) or pcall(listener.callback, ...)
            if not ok then
                Orbit:Print("|cFFFF0000EventBus Error|r in", event, ":", tostring(err))
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
        eventFrame:UnregisterEvent(event)
    end
    self.listeners = {}
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    EventBus:Fire(event, ...)
end)
