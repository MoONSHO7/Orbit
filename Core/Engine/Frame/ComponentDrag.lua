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
local function SafeGetSize(region)
    if not region then
        return 20, 16 -- Default minimum size
    end
    
    local width, height = 20, 16 -- Defaults
    
    -- Try to get width
    local ok, w = pcall(function()
        local val = region:GetWidth()
        if issecretvalue and issecretvalue(val) then
            return nil
        end
        return val
    end)
    if ok and w and type(w) == "number" then
        width = w
    end
    
    -- Try to get height
    ok, h = pcall(function()
        local val = region:GetHeight()
        if issecretvalue and issecretvalue(val) then
            return nil
        end
        return val
    end)
    if ok and h and type(h) == "number" then
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

-- [ DRAG HANDLE CREATION ]--------------------------------------------------------------------------

-- Minimum clickable area for handles
local MIN_HANDLE_WIDTH = 40
local MIN_HANDLE_HEIGHT = 16

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
            local cursorX, cursorY = GetCursorPosition()
            local scale = SafeGetNumber(parent:GetEffectiveScale(), 1)
            cursorX, cursorY = cursorX / scale, cursorY / scale

            local compWidth, compHeight = SafeGetSize(component)
            local compLeft = SafeGetNumber(component:GetLeft(), 0)
            local compBottom = SafeGetNumber(component:GetBottom(), 0)
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
    local scale = SafeGetNumber(parent:GetEffectiveScale(), 1)
    cursorX, cursorY = cursorX / scale, cursorY / scale

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

    -- Show tooltip (pass center-relative coords directly)
    if Engine.SelectionTooltip and Engine.SelectionTooltip.ShowComponentPosition then
        Engine.SelectionTooltip:ShowComponentPosition(component, data.key, nil, centerRelX, centerRelY, parentWidth, parentHeight)
    end
end

function ComponentDrag:OnDragStop(component, parent, data)
    -- Fire callback with PERCENTAGE position data
    if data.options and data.options.onPositionChange then
        -- Pass percentages instead of pixels for persistence
        data.options.onPositionChange(component, nil, data.xPercent, data.yPercent)
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
    if nudgeFrame.repeatTimer then
        nudgeFrame.repeatTimer:Cancel()
        nudgeFrame.repeatTimer = nil
    end
end

-- Nudge repeat state
local nudgeRepeatDelay = 0.4  -- Initial delay before repeat starts
local nudgeRepeatRate = 0.05  -- Rate of repeat (20 nudges/sec)

local function StartNudgeRepeat(dx, dy)
    if nudgeFrame.repeatTimer then
        nudgeFrame.repeatTimer:Cancel()
    end
    
    -- Initial delay, then repeat
    nudgeFrame.repeatTimer = C_Timer.NewTimer(nudgeRepeatDelay, function()
        if selectedComponent then
            -- Start repeating
            nudgeFrame.repeatTimer = C_Timer.NewTicker(nudgeRepeatRate, function()
                if selectedComponent then
                    local delta = IsShiftKeyDown() and 10 or 1
                    ComponentDrag:NudgeComponent(selectedComponent, dx * delta, dy * delta)
                else
                    if nudgeFrame.repeatTimer then
                        nudgeFrame.repeatTimer:Cancel()
                        nudgeFrame.repeatTimer = nil
                    end
                end
            end)
        end
    end)
end

local function StopNudgeRepeat()
    if nudgeFrame.repeatTimer then
        nudgeFrame.repeatTimer:Cancel()
        nudgeFrame.repeatTimer = nil
    end
end

nudgeFrame:SetScript("OnKeyDown", function(self, key)
    if not selectedComponent then
        return
    end

    local data = registeredComponents[selectedComponent]
    if not data then
        return
    end

    local delta = IsShiftKeyDown() and 10 or 1
    local dx, dy = 0, 0
    local baseX, baseY = 0, 0  -- Base direction for repeat

    if key == "UP" then
        dy = delta
        baseY = 1
    elseif key == "DOWN" then
        dy = -delta
        baseY = -1
    elseif key == "LEFT" then
        dx = -delta
        baseX = -1
    elseif key == "RIGHT" then
        dx = delta
        baseX = 1
    elseif key == "ESCAPE" then
        ComponentDrag:DeselectComponent()
        return
    else
        self:SetPropagateKeyboardInput(true)
        return
    end

    self:SetPropagateKeyboardInput(false)
    ComponentDrag:NudgeComponent(selectedComponent, dx, dy)
    
    -- Start repeat nudging for held key
    StartNudgeRepeat(baseX, baseY)
end)

nudgeFrame:SetScript("OnKeyUp", function(self, key)
    if key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
        StopNudgeRepeat()
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

    -- Show tooltip (center-relative coords in pixels for display)
    if Engine.SelectionTooltip and Engine.SelectionTooltip.ShowComponentPosition then
        Engine.SelectionTooltip:ShowComponentPosition(component, data.key, nil, newX, newY, parentWidth, parentHeight)
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
    
    -- Update size/position before showing to ensure correct placement
    if shouldShow and data.handle.UpdateSize then
        data.handle:UpdateSize()
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
            local x = pos.x or 0
            local y = pos.y or 0
            
            -- Store in data
            data.currentX = x
            data.currentY = y

            -- Use component's actual parent for correct positioning
            local componentParent = component:GetParent() or parent
            
            -- Apply position visually (center-relative to actual parent)
            component:ClearAllPoints()
            component:SetPoint("CENTER", componentParent, "CENTER", x, y)
            
            -- Update handle position
            if data.handle then
                data.handle:ClearAllPoints()
                data.handle:SetPoint("CENTER", component, "CENTER", 0, 0)
            end
        end
    end
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
