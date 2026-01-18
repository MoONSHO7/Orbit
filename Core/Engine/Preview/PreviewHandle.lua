-- [ ORBIT PREVIEW HANDLE ]-------------------------------------------------------------------------
-- Reusable drag handle component for preview components.
-- Provides hover/select visuals and mouse interaction routing.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.Preview = Engine.Preview or {}
local Preview = Engine.Preview

local PreviewHandle = {}
Preview.Handle = PreviewHandle

-------------------------------------------------
-- CONFIGURATION
-------------------------------------------------

local MIN_HANDLE_WIDTH = 50
local MIN_HANDLE_HEIGHT = 20
local BORDER_SIZE = 1

-- Colors
local COLOR_IDLE = { r = 0.3, g = 0.8, b = 0.3, a = 0 }       -- Invisible
local COLOR_HOVER = { r = 0.3, g = 0.8, b = 0.3, a = 0.3 }    -- Light green
local COLOR_DRAG = { r = 0.5, g = 0.9, b = 0.3, a = 0.4 }     -- Brighter green

-------------------------------------------------
-- HANDLE POOL
-------------------------------------------------

local handlePool = {}

local function AcquireHandle()
    local handle = table.remove(handlePool)
    if handle then
        handle:Show()
        return handle
    end
    return nil
end

local function ReleaseHandle(handle)
    if handle then
        handle:Hide()
        handle:ClearAllPoints()
        handle.container = nil
        handle.callbacks = nil
        table.insert(handlePool, handle)
    end
end

-------------------------------------------------
-- CREATE HANDLE
-------------------------------------------------

local function CreateHandleFrame()
    local handle = CreateFrame("Frame", nil, UIParent)
    handle:SetFrameStrata("FULLSCREEN_DIALOG")
    handle:SetFrameLevel(200)
    
    -- Background
    handle.bg = handle:CreateTexture(nil, "BACKGROUND")
    handle.bg:SetAllPoints()
    handle.bg:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.a)
    
    -- Border textures
    handle.borderTop = handle:CreateTexture(nil, "BORDER")
    handle.borderTop:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.a)
    handle.borderTop:SetPoint("TOPLEFT", 0, 0)
    handle.borderTop:SetPoint("TOPRIGHT", 0, 0)
    handle.borderTop:SetHeight(BORDER_SIZE)
    
    handle.borderBottom = handle:CreateTexture(nil, "BORDER")
    handle.borderBottom:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.a)
    handle.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    handle.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    handle.borderBottom:SetHeight(BORDER_SIZE)
    
    handle.borderLeft = handle:CreateTexture(nil, "BORDER")
    handle.borderLeft:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.a)
    handle.borderLeft:SetPoint("TOPLEFT", 0, 0)
    handle.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    handle.borderLeft:SetWidth(BORDER_SIZE)
    
    handle.borderRight = handle:CreateTexture(nil, "BORDER")
    handle.borderRight:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.a)
    handle.borderRight:SetPoint("TOPRIGHT", 0, 0)
    handle.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    handle.borderRight:SetWidth(BORDER_SIZE)
    
    -- Helper to set colors
    function handle:SetHandleColor(r, g, b, bgAlpha, borderAlpha)
        self.bg:SetColorTexture(r, g, b, bgAlpha)
        self.borderTop:SetColorTexture(r, g, b, borderAlpha)
        self.borderBottom:SetColorTexture(r, g, b, borderAlpha)
        self.borderLeft:SetColorTexture(r, g, b, borderAlpha)
        self.borderRight:SetColorTexture(r, g, b, borderAlpha)
    end
    
    -- Helper to update size/position
    function handle:UpdateSize()
        local container = self.container
        if not container then return end
        
        local width = container:GetWidth()
        local height = container:GetHeight()
        
        -- Enforce minimum size
        width = math.max(width, MIN_HANDLE_WIDTH)
        height = math.max(height, MIN_HANDLE_HEIGHT)
        
        self:SetSize(width, height)
        self:ClearAllPoints()
        self:SetPoint("CENTER", container, "CENTER", 0, 0)
    end
    
    return handle
end

-------------------------------------------------
-- PUBLIC API
-------------------------------------------------

-- Create or acquire a drag handle for a component
-- @param container: The component container
-- @param callbacks: { onDragStart, onDragUpdate, onDragStop, onHover, onLeave }
-- @return handle frame
function PreviewHandle:Create(container, callbacks)
    if not container then return nil end
    
    -- Try to acquire from pool
    local handle = AcquireHandle()
    if not handle then
        handle = CreateHandleFrame()
    end
    
    handle.container = container
    handle.callbacks = callbacks or {}
    handle.isDragging = false
    
    -- Enable mouse
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    
    -- Size and position
    handle:UpdateSize()
    
    -- Mouse scripts
    handle:SetScript("OnEnter", function(self)
        if not self.isDragging then
            self:SetHandleColor(COLOR_HOVER.r, COLOR_HOVER.g, COLOR_HOVER.b, COLOR_HOVER.a, 0.5)
        end
        if self.callbacks.onHover then
            self.callbacks.onHover(self.container)
        end
    end)
    
    handle:SetScript("OnLeave", function(self)
        if not self.isDragging then
            self:SetHandleColor(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.a, 0)
        end
        if self.callbacks.onLeave then
            self.callbacks.onLeave(self.container)
        end
    end)
    
    handle:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:SetHandleColor(COLOR_DRAG.r, COLOR_DRAG.g, COLOR_DRAG.b, COLOR_DRAG.a, 0.6)
        if self.callbacks.onDragStart then
            self.callbacks.onDragStart(self.container)
        end
    end)
    
    handle:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetHandleColor(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.a, 0)
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
    if handle then
        handle:SetScript("OnEnter", nil)
        handle:SetScript("OnLeave", nil)
        handle:SetScript("OnDragStart", nil)
        handle:SetScript("OnDragStop", nil)
        ReleaseHandle(handle)
    end
end

-- Destroy all pooled handles (cleanup)
function PreviewHandle:ClearPool()
    for _, handle in ipairs(handlePool) do
        handle:SetParent(nil)
    end
    wipe(handlePool)
end
