-- [ ORBIT COMPONENT DRAG ]--------------------------------------------------------------------------
-- Enables dragging of internal frame components (Name, HealthText, Level, etc.)
-- when the parent frame is in "Component Edit" mode.
--
-- Usage:
--   Engine.ComponentDrag:Attach(component, parentFrame, {
--       key = "Name",
--       onPositionChange = function(component, alignment, x, y) end
--   })

local _, Orbit = ...
local Engine = Orbit.Engine
local C = Orbit.Constants

Engine.ComponentDrag = Engine.ComponentDrag or {}
local ComponentDrag = Engine.ComponentDrag

-- [ STATE ]-----------------------------------------------------------------------------------------

local registeredComponents = {} -- { [component] = { parent, key, options, handle } }
local frameComponents = {}      -- { [parentFrame] = { component1, component2, ... } }
local selectedComponent = nil   -- Currently selected component for nudge
local PADDING = 25              -- Drag boundary padding

-- [ HELPERS ]---------------------------------------------------------------------------------------

-- Safe size accessor that handles secret values (WoW 12.0+)
-- For FontStrings, uses GetStringWidth/GetStringHeight which return actual text bounds
local function SafeGetSize(region)
    if not region then
        return 40, 16 -- Default minimum size
    end
    
    local width, height = 40, 16 -- Defaults
    
    -- For FontStrings, prefer GetStringWidth/GetStringHeight for actual text bounds
    local isFontString = region.GetStringWidth ~= nil
    
    -- Try to get width
    local ok, w = pcall(function()
        local val
        if isFontString then
            -- FontStrings: Try GetStringWidth first (actual text width)
            val = region:GetStringWidth()
            if (not val or val <= 0) and region.GetWidth then
                val = region:GetWidth()
            end
        else
            val = region:GetWidth()
        end
        if issecretvalue and issecretvalue(val) then
            return nil
        end
        return val
    end)
    if ok and w and type(w) == "number" and w > 0 then
        width = w
    end
    
    -- Try to get height
    local ok2, h = pcall(function()
        local val
        if isFontString then
            -- FontStrings: Try GetStringHeight (actual text height)
            val = region:GetStringHeight()
            if (not val or val <= 0) and region.GetHeight then
                val = region:GetHeight()
            end
        else
            val = region:GetHeight()
        end
        if issecretvalue and issecretvalue(val) then
            return nil
        end
        return val
    end)
    if ok2 and h and type(h) == "number" and h > 0 then
        height = h
    end
    
    return width, height
end

-- Safe number accessor for position values
local function SafeGetNumber(val, default)
    if val == nil then
        return default
    end
    if issecretvalue and issecretvalue(val) then
        return default
    end
    if type(val) ~= "number" then
        return default
    end
    return val
end

local function ClampPosition(x, y, parentWidth, parentHeight)
    x = SafeGetNumber(x, 0)
    y = SafeGetNumber(y, 0)
    parentWidth = SafeGetNumber(parentWidth, 100)
    parentHeight = SafeGetNumber(parentHeight, 40)
    
    local clampedX = math.max(-PADDING, math.min(x, parentWidth + PADDING))
    local clampedY = math.max(-PADDING, math.min(y, parentHeight + PADDING))
    return clampedX, clampedY
end

-- Use shared position utilities
local CalculateAnchor = Engine.PositionUtils.CalculateAnchor

-- [ DRAG HANDLE CREATION ]--------------------------------------------------------------------------

-- Minimum clickable area for handles (generous size for easy clicking)
local MIN_HANDLE_WIDTH = 50
local MIN_HANDLE_HEIGHT = 20

local function CreateDragHandle(component, parent, data)
    -- Use plain frame with manual textures (BackdropTemplate has secret value issues)
    local handle = CreateFrame("Frame", nil, UIParent)
    handle:SetFrameStrata("FULLSCREEN_DIALOG")
    handle:SetFrameLevel(200)

    -- Size to match component exactly (with minimum for clickability)
    local function UpdateHandleSize()
        local width, height = SafeGetSize(component)
        -- Use actual component size, just enforce minimum
        local handleW = math.max(width, MIN_HANDLE_WIDTH)
        local handleH = math.max(height, MIN_HANDLE_HEIGHT)
        handle:SetSize(handleW, handleH)

        -- Position directly over component
        handle:ClearAllPoints()
        handle:SetPoint("CENTER", component, "CENTER", 0, 0)
    end
    
    handle.UpdateSize = UpdateHandleSize
    UpdateHandleSize()

    -- Create simple visual with textures (no backdrop to avoid secret value issues)
    -- Invisible by default - only show outline on hover/select (like Edit Mode)
    handle.bg = handle:CreateTexture(nil, "BACKGROUND")
    handle.bg:SetAllPoints()
    handle.bg:SetColorTexture(0.3, 0.8, 0.3, 0)  -- Invisible
    
    -- Border - simple colored outline
    local borderSize = 1
    handle.borderTop = handle:CreateTexture(nil, "BORDER")
    handle.borderTop:SetColorTexture(0.3, 0.8, 0.3, 0)  -- Invisible by default
    handle.borderTop:SetPoint("TOPLEFT", 0, 0)
    handle.borderTop:SetPoint("TOPRIGHT", 0, 0)
    handle.borderTop:SetHeight(borderSize)
    
    handle.borderBottom = handle:CreateTexture(nil, "BORDER")
    handle.borderBottom:SetColorTexture(0.3, 0.8, 0.3, 0)  -- Invisible by default
    handle.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    handle.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    handle.borderBottom:SetHeight(borderSize)
    
    handle.borderLeft = handle:CreateTexture(nil, "BORDER")
    handle.borderLeft:SetColorTexture(0.3, 0.8, 0.3, 0)  -- Invisible by default
    handle.borderLeft:SetPoint("TOPLEFT", 0, 0)
    handle.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    handle.borderLeft:SetWidth(borderSize)
    
    handle.borderRight = handle:CreateTexture(nil, "BORDER")
    handle.borderRight:SetColorTexture(0.3, 0.8, 0.3, 0)  -- Invisible by default
    handle.borderRight:SetPoint("TOPRIGHT", 0, 0)
    handle.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    handle.borderRight:SetWidth(borderSize)
    
    -- Helper to set colors
    function handle:SetHandleColor(r, g, b, bgAlpha, borderAlpha)
        self.bg:SetColorTexture(r, g, b, bgAlpha)
        self.borderTop:SetColorTexture(r, g, b, borderAlpha)
        self.borderBottom:SetColorTexture(r, g, b, borderAlpha)
        self.borderLeft:SetColorTexture(r, g, b, borderAlpha)
        self.borderRight:SetColorTexture(r, g, b, borderAlpha)
    end

    -- Enable mouse
    handle:EnableMouse(true)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")

    -- Hover - show subtle outline
    handle:SetScript("OnEnter", function(self)
        if selectedComponent == component then
            self:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.6)  -- Selected + hover
        else
            self:SetHandleColor(0.3, 0.8, 0.3, 0.05, 0.4)  -- Just hover - subtle
        end
        SetCursor("Interface\\CURSOR\\UI-Cursor-Move")
    end)

    handle:SetScript("OnLeave", function(self)
        if not self.isDragging then
            if selectedComponent == component then
                self:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.5)  -- Selected state
            else
                self:SetHandleColor(0.3, 0.8, 0.3, 0, 0)  -- Invisible
            end
        end
        ResetCursor()
    end)

    -- Click to select AND start drag
    handle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            ComponentDrag:SelectComponent(component)
            
            -- Start drag immediately
            self.isDragging = true
            self:SetHandleColor(0.3, 1, 0.3, 0.35, 0.8)
            
            -- Store initial offset from cursor
            -- Use component's effective scale for proper coordinate conversion
            local cursorX, cursorY = GetCursorPosition()
            local compScale = SafeGetNumber(component:GetEffectiveScale(), 1)
            cursorX, cursorY = cursorX / compScale, cursorY / compScale
            
            -- Get component center in screen coordinates, then convert to same space as cursor
            local compWidth, compHeight = SafeGetSize(component)
            local compLeft = SafeGetNumber(component:GetLeft(), 0)
            local compBottom = SafeGetNumber(component:GetBottom(), 0)
            -- Component position is already in screen coordinates, convert to scaled space
            local compCenterX = compLeft + compWidth / 2
            local compCenterY = compBottom + compHeight / 2

            self.dragOffsetX = compCenterX - cursorX
            self.dragOffsetY = compCenterY - cursorY
            
            -- Start update loop - also checks for mouse release
            self:SetScript("OnUpdate", function(self)
                -- Check if mouse button was released (works even if mouse left handle)
                if not IsMouseButtonDown("LeftButton") then
                    self.isDragging = false
                    -- Keep subtle selected color (component remains selected for nudging)
                    self:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.5)
                    self:SetScript("OnUpdate", nil)
                    ComponentDrag:OnDragStop(component, parent, data)
                    return
                end
                ComponentDrag:OnDragUpdate(component, parent, data, self)
            end)
        end
    end)
    
    -- OnMouseUp kept as backup for edge cases
    handle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isDragging then
            self.isDragging = false
            -- Keep subtle selected color (component remains selected for nudging)
            self:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.5)
            self:SetScript("OnUpdate", nil)
            ComponentDrag:OnDragStop(component, parent, data)
        end
    end)

    -- Note: Drag is handled in OnMouseDown/OnMouseUp above
    -- OnDragStart/OnDragStop removed since we handle it manually

    -- Update size when component changes (for FontStrings)
    if component.SetText then
        hooksecurefunc(component, "SetText", function()
            C_Timer.After(0, UpdateHandleSize)
        end)
    end

    handle:Hide() -- Hidden until Component Edit mode
    return handle
end

-- [ DRAG MECHANICS ]--------------------------------------------------------------------------------

function ComponentDrag:OnDragUpdate(component, parent, data, handle)
    local cursorX, cursorY = GetCursorPosition()
    -- Use component's effective scale for consistent coordinate space with OnMouseDown
    local compScale = SafeGetNumber(component:GetEffectiveScale(), 1)
    cursorX, cursorY = cursorX / compScale, cursorY / compScale

    -- Apply drag offset
    local targetX = cursorX + SafeGetNumber(handle.dragOffsetX, 0)
    local targetY = cursorY + SafeGetNumber(handle.dragOffsetY, 0)

    -- Get parent bounds (use the actual component parent for correct positioning)
    local componentParent = component:GetParent() or parent
    local parentLeft = SafeGetNumber(componentParent:GetLeft(), 0)
    local parentBottom = SafeGetNumber(componentParent:GetBottom(), 0)
    local parentWidth, parentHeight = SafeGetSize(componentParent)
    local parentCenterX = parentLeft + parentWidth / 2
    local parentCenterY = parentBottom + parentHeight / 2

    -- Calculate CENTER-relative position (offset from parent center)
    local centerRelX = targetX - parentCenterX
    local centerRelY = targetY - parentCenterY

    -- Clamp to bounds (still using padding but relative to center)
    local halfW, halfH = parentWidth / 2, parentHeight / 2
    centerRelX = math.max(-halfW - PADDING, math.min(centerRelX, halfW + PADDING))
    centerRelY = math.max(-halfH - PADDING, math.min(centerRelY, halfH + PADDING))
    
    -- Snap to 5px grid for cleaner positioning
    local SNAP_SIZE = 5
    centerRelX = math.floor(centerRelX / SNAP_SIZE + 0.5) * SNAP_SIZE
    centerRelY = math.floor(centerRelY / SNAP_SIZE + 0.5) * SNAP_SIZE

    -- Store in data as BOTH pixels (for visual) and percentages (for persistence)
    data.currentX = centerRelX
    data.currentY = centerRelY
    
    -- For percentages: use ORIGINAL dimensions if in canvas mode
    -- Canvas mode stores original dimensions in parent.orbitCanvasOriginal
    local origWidth, origHeight = parentWidth, parentHeight
    if parent.orbitCanvasOriginal then
        origWidth = parent.orbitCanvasOriginal.width or parentWidth
        origHeight = parent.orbitCanvasOriginal.height or parentHeight
        -- Adjust centerRelX/Y to original scale (canvas mode is 2x)
        -- Visual position is in 2x space, but we save as 1x percentages
        local scaleRatio = (parent.orbitCanvasOriginal.scale or 1) / (parent:GetScale() or 1)
        data.xPercent = origWidth > 0 and ((centerRelX * scaleRatio) / origWidth) or 0
        data.yPercent = origHeight > 0 and ((centerRelY * scaleRatio) / origHeight) or 0
    else
        -- Normal mode: percentages relative to current size
        data.xPercent = parentWidth > 0 and (centerRelX / parentWidth) or 0
        data.yPercent = parentHeight > 0 and (centerRelY / parentHeight) or 0
    end

    -- Update component position visually - anchor to component's actual parent
    component:ClearAllPoints()
    component:SetPoint("CENTER", componentParent, "CENTER", centerRelX, centerRelY)

    -- Update handle position
    handle:ClearAllPoints()
    handle:SetPoint("CENTER", component, "CENTER", 0, 0)

    -- Show tooltip with anchor + justify + center + edge coords
    if Engine.SelectionTooltip and Engine.SelectionTooltip.ShowComponentPosition then
        local anchorX, anchorY, edgeOffX, edgeOffY, justifyH = CalculateAnchor(centerRelX, centerRelY, halfW, halfH)
        Engine.SelectionTooltip:ShowComponentPosition(
            component, data.key,
            anchorX, anchorY,
            centerRelX, centerRelY,
            edgeOffX, edgeOffY,
            justifyH
        )
    end
end

function ComponentDrag:OnDragStop(component, parent, data)
    -- Fire callback with edge-relative position data (anchorX format)
    if data.options and data.options.onPositionChange then
        -- Calculate anchor from current position
        local componentParent = component:GetParent() or parent
        local parentWidth, parentHeight = SafeGetSize(componentParent)
        local halfW = parentWidth / 2
        local halfH = parentHeight / 2
        
        -- Get center-relative position from stored data
        local centerX = data.currentX or 0
        local centerY = data.currentY or 0
        
        -- Calculate edge-relative anchor data
        local anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchor(centerX, centerY, halfW, halfH)
        
        -- Pass edge-relative format to callback
        data.options.onPositionChange(component, anchorX, anchorY, offsetX, offsetY, justifyH)
    end

    -- Mark frame dirty for persistence
    if Engine.PositionManager then
        Engine.PositionManager:MarkDirty(parent)
    end

    GameTooltip:Hide()
end

-- [ KEYBOARD NUDGE ]--------------------------------------------------------------------------------

local nudgeFrame = CreateFrame("Frame", "OrbitComponentNudgeFrame", UIParent)
nudgeFrame:EnableKeyboard(false)
nudgeFrame:SetPropagateKeyboardInput(true)

function ComponentDrag:SelectComponent(component)
    selectedComponent = component

    -- Enable keyboard for nudge (combat safe)
    if not InCombatLockdown() then
        nudgeFrame:EnableKeyboard(true)
        nudgeFrame:SetPropagateKeyboardInput(false)
    end

    -- Visual feedback - update size and show selected state (subtle)
    local data = registeredComponents[component]
    if data and data.handle then
        if data.handle.UpdateSize then
            data.handle:UpdateSize()
        end
        -- Subtle selected state
        data.handle:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.5)
    end
end

function ComponentDrag:DeselectComponent()
    if selectedComponent then
        local data = registeredComponents[selectedComponent]
        if data and data.handle and not data.handle.isDragging then
            data.handle:SetHandleColor(0.3, 0.8, 0.3, 0, 0)  -- Invisible
        end
    end

    selectedComponent = nil
    
    -- Disable keyboard (combat safe)
    if not InCombatLockdown() then
        nudgeFrame:EnableKeyboard(false)
        nudgeFrame:SetPropagateKeyboardInput(true)
    end
    
    -- Stop any repeat nudging
    Engine.NudgeRepeat:Stop()
end

nudgeFrame:SetScript("OnKeyDown", function(self, key)
    if not selectedComponent then
        return
    end

    local data = registeredComponents[selectedComponent]
    if not data then
        return
    end

    local dx, dy = 0, 0

    if key == "UP" then
        dy = 1
    elseif key == "DOWN" then
        dy = -1
    elseif key == "LEFT" then
        dx = -1
    elseif key == "RIGHT" then
        dx = 1
    elseif key == "ESCAPE" then
        ComponentDrag:DeselectComponent()
        return
    else
        self:SetPropagateKeyboardInput(true)
        return
    end

    self:SetPropagateKeyboardInput(false)
    ComponentDrag:NudgeComponent(selectedComponent, dx, dy)
    
    -- Start repeat nudging using shared module
    Engine.NudgeRepeat:Start(
        function()
            if selectedComponent then
                ComponentDrag:NudgeComponent(selectedComponent, dx, dy)
            end
        end,
        function()
            return selectedComponent ~= nil
        end
    )
end)

nudgeFrame:SetScript("OnKeyUp", function(self, key)
    if key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
        Engine.NudgeRepeat:Stop()
    end
end)

function ComponentDrag:NudgeComponent(component, dx, dy)
    local data = registeredComponents[component]
    if not data then
        return
    end

    -- Use component's actual parent for correct positioning
    local componentParent = component:GetParent() or data.parent
    local parent = data.parent
    local parentWidth, parentHeight = SafeGetSize(componentParent)
    local halfW, halfH = parentWidth / 2, parentHeight / 2

    -- Get current center-relative position
    local currentX = data.currentX or 0
    local currentY = data.currentY or 0

    -- Apply nudge (center-relative)
    local newX = currentX + dx
    local newY = currentY + dy

    -- Clamp to bounds (center-relative with padding)
    newX = math.max(-halfW - PADDING, math.min(newX, halfW + PADDING))
    newY = math.max(-halfH - PADDING, math.min(newY, halfH + PADDING))

    -- Update data as BOTH pixels and percentages
    data.currentX = newX
    data.currentY = newY
    
    -- For percentages: use ORIGINAL dimensions if in canvas mode
    if parent and parent.orbitCanvasOriginal then
        local origWidth = parent.orbitCanvasOriginal.width or parentWidth
        local origHeight = parent.orbitCanvasOriginal.height or parentHeight
        local scaleRatio = (parent.orbitCanvasOriginal.scale or 1) / (parent:GetScale() or 1)
        data.xPercent = origWidth > 0 and ((newX * scaleRatio) / origWidth) or 0
        data.yPercent = origHeight > 0 and ((newY * scaleRatio) / origHeight) or 0
    else
        data.xPercent = parentWidth > 0 and (newX / parentWidth) or 0
        data.yPercent = parentHeight > 0 and (newY / parentHeight) or 0
    end

    -- Update component position - anchor to actual parent
    component:ClearAllPoints()
    component:SetPoint("CENTER", componentParent, "CENTER", newX, newY)

    -- Update handle
    if data.handle then
        data.handle:ClearAllPoints()
        data.handle:SetPoint("CENTER", component, "CENTER", 0, 0)
    end

    -- Fire callback with PERCENTAGE values
    if data.options and data.options.onPositionChange then
        data.options.onPositionChange(component, nil, data.xPercent, data.yPercent)
    end

    -- Mark dirty
    if Engine.PositionManager then
        Engine.PositionManager:MarkDirty(data.parent)
    end

    -- Show tooltip with anchor + justify + center + edge coords
    if Engine.SelectionTooltip and Engine.SelectionTooltip.ShowComponentPosition then
        local anchorX, anchorY, edgeOffX, edgeOffY, justifyH = CalculateAnchor(newX, newY, halfW, halfH)
        Engine.SelectionTooltip:ShowComponentPosition(
            component, data.key,
            anchorX, anchorY,
            newX, newY,
            edgeOffX, edgeOffY,
            justifyH
        )
    end
end

-- [ PUBLIC API ]------------------------------------------------------------------------------------

function ComponentDrag:Attach(component, parent, options)
    if not component or not parent then
        return
    end

    options = options or {}

    local data = {
        parent = parent,
        key = options.key or "unknown",
        options = options,
        currentX = 0,
        currentY = 0,
        currentAlignment = "LEFT",
        handle = nil,
    }

    -- Create drag handle
    data.handle = CreateDragHandle(component, parent, data)

    -- Register
    registeredComponents[component] = data

    -- Track by parent
    if not frameComponents[parent] then
        frameComponents[parent] = {}
    end
    table.insert(frameComponents[parent], component)
end

function ComponentDrag:Detach(component)
    local data = registeredComponents[component]
    if not data then
        return
    end

    -- Remove handle
    if data.handle then
        data.handle:Hide()
        data.handle:SetParent(nil)
    end

    -- Unregister
    registeredComponents[component] = nil

    -- Remove from parent tracking
    if frameComponents[data.parent] then
        for i, comp in ipairs(frameComponents[data.parent]) do
            if comp == component then
                table.remove(frameComponents[data.parent], i)
                break
            end
        end
    end
end

function ComponentDrag:SetEnabled(component, enabled)
    local data = registeredComponents[component]
    if not data or not data.handle then
        return
    end

    -- Only show handles if Edit Mode, component edit enabled, AND component is visible
    local componentVisible = component.IsShown and component:IsShown() or true  -- Default true for non-widgets
    local shouldShow = enabled and componentVisible and EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    
    if shouldShow then
        -- Update size/position before showing to ensure correct placement
        if data.handle.UpdateSize then
            data.handle:UpdateSize()
        end
        
        -- Deferred update to catch layout finalization (component may not have final position yet)
        C_Timer.After(0.05, function()
            if data.handle and data.handle.UpdateSize then
                data.handle:UpdateSize()
            end
        end)
    end
    
    data.handle:SetShown(shouldShow)

    if not enabled and selectedComponent == component then
        self:DeselectComponent()
    end
end

function ComponentDrag:SetEnabledForFrame(parent, enabled)
    local components = frameComponents[parent]
    if not components then
        return
    end

    -- Only enable if Edit Mode is also active
    local editModeActive = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local shouldEnable = enabled and editModeActive

    for _, component in ipairs(components) do
        self:SetEnabled(component, shouldEnable)
    end

    if not shouldEnable then
        self:DeselectComponent()
    end
end

function ComponentDrag:GetAlignment(component)
    local data = registeredComponents[component]
    return data and data.currentAlignment or "LEFT"
end

function ComponentDrag:RestoreFramePositions(parent, positions)
    local components = frameComponents[parent]
    if not components or not positions then
        return
    end

    for _, component in ipairs(components) do
        local data = registeredComponents[component]
        if data and positions[data.key] then
            local pos = positions[data.key]
            local componentParent = component:GetParent() or parent
            
            -- Single format: Edge-relative (anchorX/Y, offsetX/Y)
            if pos.anchorX then
                local anchorX = pos.anchorX
                local anchorY = pos.anchorY or "CENTER"
                local offsetX = pos.offsetX or 0
                local offsetY = pos.offsetY or 0
                
                -- Build anchor point string
                local anchorPoint
                if anchorY == "CENTER" and anchorX == "CENTER" then
                    anchorPoint = "CENTER"
                elseif anchorY == "CENTER" then
                    anchorPoint = anchorX
                elseif anchorX == "CENTER" then
                    anchorPoint = anchorY
                else
                    anchorPoint = anchorY .. anchorX
                end
                
                -- Calculate final offset with correct sign
                local finalX = offsetX
                local finalY = offsetY
                if anchorX == "RIGHT" then finalX = -offsetX end
                if anchorY == "TOP" then finalY = -offsetY end
                
                -- Apply position
                component:ClearAllPoints()
                
                if pos.justifyH and component.SetJustifyH then
                    component:SetJustifyH(pos.justifyH)
                    component:SetPoint(pos.justifyH, componentParent, anchorPoint, finalX, finalY)
                else
                    component:SetPoint("CENTER", componentParent, anchorPoint, finalX, finalY)
                end
                
                -- Store for reference
                data.anchorX = anchorX
                data.anchorY = anchorY
                data.offsetX = offsetX
                data.offsetY = offsetY
                data.justifyH = pos.justifyH
            end
            
            -- Update handle position
            if data.handle then
                data.handle:ClearAllPoints()
                data.handle:SetPoint("CENTER", component, "CENTER", 0, 0)
            end
        end
    end
end

-- Get all registered components for a frame
function ComponentDrag:GetComponentsForFrame(frame)
    if not frame then return {} end
    
    local components = frameComponents[frame] or {}
    local result = {}
    
    for _, comp in ipairs(components) do
        local data = registeredComponents[comp]
        if data then
            result[data.key] = {
                text = data.key,
                -- Edge-relative format (single source of truth)
                anchorX = data.anchorX,
                anchorY = data.anchorY,
                offsetX = data.offsetX,
                offsetY = data.offsetY,
                justifyH = data.justifyH,
                component = comp,
                originalText = comp.GetText and comp:GetText() or nil
            }
        end
    end
    
    return result
end

-- [ EDIT MODE HOOKS ]-------------------------------------------------------------------------------

-- Disable all component drag handles
function ComponentDrag:DisableAll()
    for component, data in pairs(registeredComponents) do
        if data.handle then
            data.handle:Hide()
        end
    end
    self:DeselectComponent()
end

if EditModeManagerFrame then
    -- Disable all component drags when Edit Mode closes
    EditModeManagerFrame:HookScript("OnHide", function()
        ComponentDrag:DisableAll()
    end)
end
