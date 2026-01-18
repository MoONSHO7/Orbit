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

Engine.ComponentDrag = Engine.ComponentDrag or {}
local ComponentDrag = Engine.ComponentDrag

-- Import helpers and handle modules
local Helpers = Engine.ComponentHelpers
local SafeGetSize = Helpers.SafeGetSize
local SafeGetNumber = Helpers.SafeGetNumber
local PADDING = Helpers.PADDING
local CalculateAnchor = Engine.PositionUtils.CalculateAnchor
local HandleModule = Engine.ComponentHandle

-- [ STATE ]-----------------------------------------------------------------------------------------

local registeredComponents = {} -- { [component] = { parent, key, options, handle } }
local frameComponents = {}      -- { [parentFrame] = { component1, component2, ... } }
local selectedComponent = nil   -- Currently selected component for nudge

-- [ DRAG MECHANICS ]--------------------------------------------------------------------------------

function ComponentDrag:OnDragUpdate(component, parent, data, handle)
    local cursorX, cursorY = GetCursorPosition()
    local compScale = SafeGetNumber(component:GetEffectiveScale(), 1)
    cursorX, cursorY = cursorX / compScale, cursorY / compScale

    local targetX = cursorX + SafeGetNumber(handle.dragOffsetX, 0)
    local targetY = cursorY + SafeGetNumber(handle.dragOffsetY, 0)

    local componentParent = component:GetParent() or parent
    local parentLeft = SafeGetNumber(componentParent:GetLeft(), 0)
    local parentBottom = SafeGetNumber(componentParent:GetBottom(), 0)
    local parentWidth, parentHeight = SafeGetSize(componentParent)
    local parentCenterX = parentLeft + parentWidth / 2
    local parentCenterY = parentBottom + parentHeight / 2

    local centerRelX = targetX - parentCenterX
    local centerRelY = targetY - parentCenterY

    local halfW, halfH = parentWidth / 2, parentHeight / 2
    centerRelX = math.max(-halfW - PADDING, math.min(centerRelX, halfW + PADDING))
    centerRelY = math.max(-halfH - PADDING, math.min(centerRelY, halfH + PADDING))
    
    local SNAP_SIZE = 5
    centerRelX = math.floor(centerRelX / SNAP_SIZE + 0.5) * SNAP_SIZE
    centerRelY = math.floor(centerRelY / SNAP_SIZE + 0.5) * SNAP_SIZE

    data.currentX = centerRelX
    data.currentY = centerRelY
    
    local origWidth, origHeight = parentWidth, parentHeight
    if parent.orbitCanvasOriginal then
        origWidth = parent.orbitCanvasOriginal.width or parentWidth
        origHeight = parent.orbitCanvasOriginal.height or parentHeight
        local scaleRatio = (parent.orbitCanvasOriginal.scale or 1) / (parent:GetScale() or 1)
        data.xPercent = origWidth > 0 and ((centerRelX * scaleRatio) / origWidth) or 0
        data.yPercent = origHeight > 0 and ((centerRelY * scaleRatio) / origHeight) or 0
    else
        data.xPercent = parentWidth > 0 and (centerRelX / parentWidth) or 0
        data.yPercent = parentHeight > 0 and (centerRelY / parentHeight) or 0
    end

    component:ClearAllPoints()
    component:SetPoint("CENTER", componentParent, "CENTER", centerRelX, centerRelY)

    handle:ClearAllPoints()
    handle:SetPoint("CENTER", component, "CENTER", 0, 0)

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
    if data.options and data.options.onPositionChange then
        local componentParent = component:GetParent() or parent
        local parentWidth, parentHeight = SafeGetSize(componentParent)
        local halfW, halfH = parentWidth / 2, parentHeight / 2
        
        local centerX = data.currentX or 0
        local centerY = data.currentY or 0
        
        local anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchor(centerX, centerY, halfW, halfH)
        data.options.onPositionChange(component, anchorX, anchorY, offsetX, offsetY, justifyH)
    end

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

    if not InCombatLockdown() then
        nudgeFrame:EnableKeyboard(true)
        nudgeFrame:SetPropagateKeyboardInput(false)
    end

    local data = registeredComponents[component]
    if data and data.handle then
        if data.handle.UpdateSize then data.handle:UpdateSize() end
        data.handle:SetHandleColor(0.5, 0.9, 0.3, 0.1, 0.5)
    end
end

function ComponentDrag:DeselectComponent()
    if selectedComponent then
        local data = registeredComponents[selectedComponent]
        if data and data.handle and not data.handle.isDragging then
            data.handle:SetHandleColor(0.3, 0.8, 0.3, 0, 0)
        end
    end

    selectedComponent = nil
    
    if not InCombatLockdown() then
        nudgeFrame:EnableKeyboard(false)
        nudgeFrame:SetPropagateKeyboardInput(true)
    end
    
    Engine.NudgeRepeat:Stop()
end

nudgeFrame:SetScript("OnKeyDown", function(self, key)
    if not selectedComponent then return end

    local data = registeredComponents[selectedComponent]
    if not data then return end

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
    if not data then return end

    local componentParent = component:GetParent() or data.parent
    local parent = data.parent
    local parentWidth, parentHeight = SafeGetSize(componentParent)
    local halfW, halfH = parentWidth / 2, parentHeight / 2

    local currentX = data.currentX or 0
    local currentY = data.currentY or 0

    local newX = currentX + dx
    local newY = currentY + dy

    newX = math.max(-halfW - PADDING, math.min(newX, halfW + PADDING))
    newY = math.max(-halfH - PADDING, math.min(newY, halfH + PADDING))

    data.currentX = newX
    data.currentY = newY
    
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

    component:ClearAllPoints()
    component:SetPoint("CENTER", componentParent, "CENTER", newX, newY)

    if data.handle then
        data.handle:ClearAllPoints()
        data.handle:SetPoint("CENTER", component, "CENTER", 0, 0)
    end

    if data.options and data.options.onPositionChange then
        data.options.onPositionChange(component, nil, data.xPercent, data.yPercent)
    end

    if Engine.PositionManager then
        Engine.PositionManager:MarkDirty(data.parent)
    end

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
    if not component or not parent then return end

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

    -- Create handle using the Handle module with callbacks
    data.handle = HandleModule:Create(component, parent, {
        isSelected = function(comp)
            return selectedComponent == comp
        end,
        onSelect = function(comp)
            ComponentDrag:SelectComponent(comp)
        end,
        onDragUpdate = function(comp, handle)
            ComponentDrag:OnDragUpdate(comp, parent, data, handle)
        end,
        onDragStop = function(comp, handle)
            ComponentDrag:OnDragStop(comp, parent, data)
        end,
    })

    registeredComponents[component] = data

    if not frameComponents[parent] then
        frameComponents[parent] = {}
    end
    table.insert(frameComponents[parent], component)
end

function ComponentDrag:Detach(component)
    local data = registeredComponents[component]
    if not data then return end

    if data.handle then
        HandleModule:Release(data.handle)
    end

    registeredComponents[component] = nil

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
    if not data or not data.handle then return end

    local componentVisible = component.IsShown and component:IsShown() or true
    local shouldShow = enabled and componentVisible and EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    
    if shouldShow then
        if data.handle.UpdateSize then data.handle:UpdateSize() end
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
    if not components then return end

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
    if not components or not positions then return end

    for _, component in ipairs(components) do
        local data = registeredComponents[component]
        if data and positions[data.key] then
            local pos = positions[data.key]
            local componentParent = component:GetParent() or parent
            
            if pos.anchorX then
                local anchorX = pos.anchorX
                local anchorY = pos.anchorY or "CENTER"
                local offsetX = pos.offsetX or 0
                local offsetY = pos.offsetY or 0
                
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
                
                local finalX = offsetX
                local finalY = offsetY
                if anchorX == "RIGHT" then finalX = -offsetX end
                if anchorY == "TOP" then finalY = -offsetY end
                
                component:ClearAllPoints()
                
                if pos.justifyH and component.SetJustifyH then
                    component:SetJustifyH(pos.justifyH)
                    component:SetPoint(pos.justifyH, componentParent, anchorPoint, finalX, finalY)
                else
                    component:SetPoint("CENTER", componentParent, anchorPoint, finalX, finalY)
                end
                
                data.anchorX = anchorX
                data.anchorY = anchorY
                data.offsetX = offsetX
                data.offsetY = offsetY
                data.justifyH = pos.justifyH
            end
            
            if data.handle then
                data.handle:ClearAllPoints()
                data.handle:SetPoint("CENTER", component, "CENTER", 0, 0)
            end
        end
    end
end

function ComponentDrag:GetComponentsForFrame(frame)
    if not frame then return {} end
    
    local components = frameComponents[frame] or {}
    local result = {}
    
    for _, comp in ipairs(components) do
        local data = registeredComponents[comp]
        if data then
            result[data.key] = {
                text = data.key,
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

function ComponentDrag:DisableAll()
    for component, data in pairs(registeredComponents) do
        if data.handle then
            data.handle:Hide()
        end
    end
    self:DeselectComponent()
end

if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", function()
        ComponentDrag:DisableAll()
    end)
end
