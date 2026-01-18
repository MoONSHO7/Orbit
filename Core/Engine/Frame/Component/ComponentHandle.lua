-- [ ORBIT COMPONENT HANDLE ]------------------------------------------------------------------------
-- Creates and manages drag handles for component editing on real frames.
-- Uses HandleCore for shared infrastructure.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.ComponentHandle = {}
local Handle = Engine.ComponentHandle

-- Import shared infrastructure
local HandleCore = Engine.HandleCore
local Helpers = Engine.ComponentHelpers
local SafeGetNumber = Helpers.SafeGetNumber

-- [ CREATE HANDLE ]-----------------------------------------------------------------------------

function Handle:Create(component, parent, callbacks)
    if not component then return nil end
    
    callbacks = callbacks or {}
    
    -- Try pool first, then create new
    local handle = HandleCore:AcquireFromPool()
    if not handle then
        handle = HandleCore:CreateFrame()
    end
    
    -- Store references
    handle.component = component
    handle.parent = parent
    handle.callbacks = callbacks
    handle.isDragging = false
    
    -- Size update function
    local function UpdateHandleSize()
        HandleCore:PositionOverComponent(handle, component)
    end
    
    handle.UpdateSize = UpdateHandleSize
    UpdateHandleSize()
    
    -- Enable mouse
    handle:EnableMouse(true)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")
    
    -- Hover scripts
    handle:SetScript("OnEnter", function(self)
        local colors = HandleCore.Colors
        if callbacks.isSelected and callbacks.isSelected(component) then
            self:ApplyColorPreset(colors.SELECTED)
            self:SetHandleColor(colors.SELECTED.r, colors.SELECTED.g, colors.SELECTED.b, 0.1, 0.6)
        else
            self:ApplyColorPreset(colors.HOVER)
        end
        SetCursor("Interface\\CURSOR\\UI-Cursor-Move")
        if callbacks.onEnter then callbacks.onEnter(component) end
    end)
    
    handle:SetScript("OnLeave", function(self)
        local colors = HandleCore.Colors
        if not self.isDragging then
            if callbacks.isSelected and callbacks.isSelected(component) then
                self:ApplyColorPreset(colors.SELECTED)
            else
                self:ApplyColorPreset(colors.IDLE)
            end
        end
        ResetCursor()
        if callbacks.onLeave then callbacks.onLeave(component) end
    end)
    
    -- Mouse down - select and start drag
    handle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if callbacks.onSelect then callbacks.onSelect(component) end
            
            self.isDragging = true
            self:ApplyColorPreset(HandleCore.Colors.DRAG)
            
            -- Store drag offset
            local cursorX, cursorY = GetCursorPosition()
            local compScale = SafeGetNumber(component:GetEffectiveScale(), 1)
            cursorX, cursorY = cursorX / compScale, cursorY / compScale
            
            local compWidth, compHeight = HandleCore:SafeGetSize(component)
            local compLeft = SafeGetNumber(component:GetLeft(), 0)
            local compBottom = SafeGetNumber(component:GetBottom(), 0)
            local compCenterX = compLeft + compWidth / 2
            local compCenterY = compBottom + compHeight / 2
            
            self.dragOffsetX = compCenterX - cursorX
            self.dragOffsetY = compCenterY - cursorY
            
            -- Drag update loop
            self:SetScript("OnUpdate", function(self)
                if not IsMouseButtonDown("LeftButton") then
                    self.isDragging = false
                    self:ApplyColorPreset(HandleCore.Colors.SELECTED)
                    self:SetScript("OnUpdate", nil)
                    if callbacks.onDragStop then callbacks.onDragStop(component, self) end
                    return
                end
                if callbacks.onDragUpdate then callbacks.onDragUpdate(component, self) end
            end)
        end
    end)
    
    -- Mouse up backup
    handle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isDragging then
            self.isDragging = false
            self:ApplyColorPreset(HandleCore.Colors.SELECTED)
            self:SetScript("OnUpdate", nil)
            if callbacks.onDragStop then callbacks.onDragStop(component, self) end
        end
    end)
    
    -- Hook SetText for FontStrings
    if component.SetText then
        hooksecurefunc(component, "SetText", function()
            C_Timer.After(0, UpdateHandleSize)
        end)
    end
    
    handle:Hide()
    return handle
end

-- [ RELEASE HANDLE ]----------------------------------------------------------------------------

function Handle:Release(handle)
    HandleCore:ReturnToPool(handle)
end

-- [ CLEAR POOL ]------------------------------------------------------------------------------

function Handle:ClearPool()
    HandleCore:ClearPool()
end
