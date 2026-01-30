local _, addonTable = ...
local Orbit = addonTable

---@class OrbitEventBus
Orbit.EventBus = {}
local EventBus = Orbit.EventBus

-- Event listeners storage
EventBus.listeners = {}

-- Event frame (singleton)
local eventFrame = CreateFrame("Frame")

--- Register a listener for a WoW event
-- @param event (string): The event name (e.g., "PLAYER_ENTERING_WORLD")
-- @param callback (function): Function to call when event fires
-- @param context (table): Optional 'self' context for the callback
-- @return listener (table): The listener object (for later removal)
function EventBus:On(event, callback, context)
    if not self.listeners[event] then
        self.listeners[event] = {}
        -- Try to register as native event, ignore failure (custom events)
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end

    local listener = {
        callback = callback,
        context = context,
    }

    table.insert(self.listeners[event], listener)
    return listener
end

--- Unregister a specific listener
-- @param event (string): The event name
-- @param callback (function): The callback to remove
-- @return boolean: True if listener was found and removed
function EventBus:Off(event, callback)
    if not self.listeners[event] then
        return false
    end

    for i = #self.listeners[event], 1, -1 do
        if self.listeners[event][i].callback == callback then
            table.remove(self.listeners[event], i)

            -- Unregister event if no listeners remain
            if #self.listeners[event] == 0 then
                eventFrame:UnregisterEvent(event)
                self.listeners[event] = nil
            end

            return true
        end
    end

    return false
end

--- Unregister all listeners for a context
-- Useful for cleanup when a module is disabled
-- @param context (table): The context to remove listeners for
function EventBus:OffContext(context)
    for event, listeners in pairs(self.listeners) do
        for i = #listeners, 1, -1 do
            if listeners[i].context == context then
                table.remove(listeners, i)
            end
        end

        -- Unregister event if no listeners remain
        if #listeners == 0 then
            eventFrame:UnregisterEvent(event)
            self.listeners[event] = nil
        end
    end
end

--- Fire an event to all listeners (internal use, also callable for custom events)
-- @param event (string): The event name
-- @param ...: Arguments to pass to listeners
function EventBus:Fire(event, ...)
    local listeners = self.listeners[event]
    if not listeners then
        return
    end

    -- Snapshot the listener count to avoid issues if listeners are added/removed during iteration
    -- Iterate backwards to safely handle removals during iteration
    for i = #listeners, 1, -1 do
        local listener = listeners[i]
        if listener then
            local success, err
            
            -- Direct vararg passthrough - no table allocation needed
            if listener.context then
                success, err = pcall(listener.callback, listener.context, ...)
            else
                success, err = pcall(listener.callback, ...)
            end

            if not success then
                Orbit:Print("|cFFFF0000EventBus Error|r in", event, ":", tostring(err))
            end
        end
    end
end

--- Check if there are any listeners for an event
-- @param event (string): The event name
-- @return boolean: True if there are listeners
function EventBus:HasListeners(event)
    return self.listeners[event] ~= nil and #self.listeners[event] > 0
end

--- Get count of listeners for an event
-- @param event (string): The event name
-- @return number: Number of listeners
function EventBus:GetListenerCount(event)
    if not self.listeners[event] then
        return 0
    end
    return #self.listeners[event]
end

--- Unregister all listeners (for cleanup)
function EventBus:Clear()
    for event in pairs(self.listeners) do
        eventFrame:UnregisterEvent(event)
    end
    self.listeners = {}
end

-- Event handler
eventFrame:SetScript("OnEvent", function(self, event, ...)
    EventBus:Fire(event, ...)
end)
