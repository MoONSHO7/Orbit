-- [ ORBIT PREVIEW HANDLE ]-------------------------------------------------------------------------
-- Drag handles for preview components in Canvas Mode.
-- Uses HandleCore for shared infrastructure.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.Preview = Engine.Preview or {}
local Preview = Engine.Preview

local PreviewHandle = {}
Preview.Handle = PreviewHandle

-- Import shared infrastructure
local HandleCore = Engine.HandleCore

-- [ CREATE HANDLE ]-----------------------------------------------------------------------------

-- Create or acquire a drag handle for a preview component
-- @param container: The component container
-- @param callbacks: { onDragStart, onDragUpdate, onDragStop, onHover, onLeave }
-- @return handle frame
function PreviewHandle:Create(container, callbacks)
    if not container then return nil end
    
    -- Try pool first, then create new
    local handle = HandleCore:AcquireFromPool()
    if not handle then
        handle = HandleCore:CreateFrame()
    end
    
    handle.container = container
    handle.callbacks = callbacks or {}
    handle.isDragging = false
    
    -- Enable mouse
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    
    -- Size and position
    HandleCore:PositionOverComponent(handle, container)
    
    -- Update size helper
    function handle:UpdateSize()
        HandleCore:PositionOverComponent(self, self.container)
    end
    
    -- Mouse scripts
    handle:SetScript("OnEnter", function(self)
        if not self.isDragging then
            self:ApplyColorPreset(HandleCore.Colors.HOVER)
        end
        if self.callbacks.onHover then
            self.callbacks.onHover(self.container)
        end
    end)
    
    handle:SetScript("OnLeave", function(self)
        if not self.isDragging then
            self:ApplyColorPreset(HandleCore.Colors.IDLE)
        end
        if self.callbacks.onLeave then
            self.callbacks.onLeave(self.container)
        end
    end)
    
    handle:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:ApplyColorPreset(HandleCore.Colors.DRAG)
        if self.callbacks.onDragStart then
            self.callbacks.onDragStart(self.container)
        end
    end)
    
    handle:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:ApplyColorPreset(HandleCore.Colors.IDLE)
        if self.callbacks.onDragStop then
            self.callbacks.onDragStop(self.container)
        end
    end)
    
    -- Store reference on container
    container.handle = handle
    
    return handle
end

-- Release a handle back to the pool
function PreviewHandle:Release(handle)
    HandleCore:ReturnToPool(handle)
end

-- Clear all pooled handles
function PreviewHandle:ClearPool()
    HandleCore:ClearPool()
end
