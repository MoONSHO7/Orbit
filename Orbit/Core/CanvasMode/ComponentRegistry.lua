-- [ COMPONENT REGISTRY ]----------------------------------------------------------------------------
-- Registers internal frame components (Name, HealthText, Level, etc.)
-- and restores their positions from saved ComponentPositions data.
-- Component positioning is managed exclusively through Canvas Mode.
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
local CalculateAnchorWithWidthCompensation = Engine.PositionUtils.CalculateAnchorWithWidthCompensation
local BuildComponentSelfAnchor = Engine.PositionUtils.BuildComponentSelfAnchor
local NeedsEdgeCompensation = Engine.PositionUtils.NeedsEdgeCompensation
local HandleModule = Engine.ComponentHandle

-- [ STATE ]-----------------------------------------------------------------------------------------

local registeredComponents = {} -- { [component] = { parent, key, options, handle } }
local frameComponents = {} -- { [parentFrame] = { component1, component2, ... } }
local selectedComponent = nil -- Currently selected component for nudge

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local SNAP_SIZE = 5
local EDGE_THRESHOLD = 3

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

    local snapX, snapY = nil, nil
    local compWidth = SafeGetSize(component)
    local compHalfW = compWidth / 2

    if IsShiftKeyDown() then
        -- Precision mode: no snapping
    else
        -- Edge Magnet X (0px flush)
        local distRight = math.abs((centerRelX + compHalfW) - halfW)
        local distLeft = math.abs((centerRelX - compHalfW) + halfW)
        if distRight <= EDGE_THRESHOLD then
            centerRelX = halfW - compHalfW
            snapX = "RIGHT"
        elseif distLeft <= EDGE_THRESHOLD then
            centerRelX = -halfW + compHalfW
            snapX = "LEFT"
        elseif math.abs(centerRelX) <= EDGE_THRESHOLD then
            centerRelX = 0
            snapX = "CENTER"
        end
        if not snapX then
            centerRelX = math.floor(centerRelX / SNAP_SIZE + 0.5) * SNAP_SIZE
        end

        -- Edge Magnet Y
        local distTop = math.abs((centerRelY + (component:GetHeight() or 0) / 2) - halfH)
        local distBottom = math.abs((centerRelY - (component:GetHeight() or 0) / 2) + halfH)
        local compHalfH = (component:GetHeight() or 0) / 2
        if distTop <= EDGE_THRESHOLD then
            centerRelY = halfH - compHalfH
            snapY = "TOP"
        elseif distBottom <= EDGE_THRESHOLD then
            centerRelY = -halfH + compHalfH
            snapY = "BOTTOM"
        elseif math.abs(centerRelY) <= EDGE_THRESHOLD then
            centerRelY = 0
            snapY = "CENTER"
        end
        if not snapY then
            centerRelY = math.floor(centerRelY / SNAP_SIZE + 0.5) * SNAP_SIZE
        end
    end



    if Engine.SmartGuides and data.guides then
        Engine.SmartGuides:Update(data.guides, snapX, snapY, parentWidth, parentHeight)
    end

    data.currentX = centerRelX
    data.currentY = centerRelY

    component:ClearAllPoints()
    if data.isAuraContainer then
        local needsComp = NeedsEdgeCompensation(data.isFontString, data.isAuraContainer)
        local compW, compH = SafeGetSize(component)
        local anchorX, anchorY, edgeOffX, edgeOffY, justifyH, selfAnchorY =
            CalculateAnchorWithWidthCompensation(centerRelX, centerRelY, halfW, halfH, needsComp, compW, compH, true)
        local selfAnchor = BuildComponentSelfAnchor(false, true, selfAnchorY, justifyH)
        local anchorPoint = Engine.PositionUtils.BuildAnchorPoint(anchorX, anchorY)
        local finalX, finalY = edgeOffX, edgeOffY
        if anchorX == "RIGHT" then finalX = -finalX end
        if anchorY == "TOP" then finalY = -finalY end
        component:SetPoint(selfAnchor, componentParent, anchorPoint, finalX, finalY)
        if Engine.SelectionTooltip and Engine.SelectionTooltip.ShowComponentPosition then
            Engine.SelectionTooltip:ShowComponentPosition(component, data.key, anchorX, anchorY, centerRelX, centerRelY, edgeOffX, edgeOffY, justifyH, selfAnchorY)
        end
    else
        component:SetPoint("CENTER", componentParent, "CENTER", centerRelX, centerRelY)
        if Engine.SelectionTooltip and Engine.SelectionTooltip.ShowComponentPosition then
            local needsComp = NeedsEdgeCompensation(data.isFontString, data.isAuraContainer)
            local compW, compH = SafeGetSize(component)
            local anchorX, anchorY, edgeOffX, edgeOffY, justifyH, selfAnchorY =
                CalculateAnchorWithWidthCompensation(centerRelX, centerRelY, halfW, halfH, needsComp, compW, compH, false)
            Engine.SelectionTooltip:ShowComponentPosition(component, data.key, anchorX, anchorY, centerRelX, centerRelY, edgeOffX, edgeOffY, justifyH, selfAnchorY)
        end
    end

    handle:ClearAllPoints()
    handle:SetPoint("CENTER", component, "CENTER", 0, 0)
end

function ComponentDrag:OnDragStop(component, parent, data)
    if data.options and data.options.onPositionChange then
        local componentParent = component:GetParent() or parent
        local parentWidth, parentHeight = SafeGetSize(componentParent)
        local halfW, halfH = parentWidth / 2, parentHeight / 2

        local centerX = data.currentX or 0
        local centerY = data.currentY or 0

        local needsWidthComp = NeedsEdgeCompensation(data.isFontString, data.isAuraContainer)
        local compW, compH = SafeGetSize(component)
        local anchorX, anchorY, offsetX, offsetY, justifyH, selfAnchorY =
            CalculateAnchorWithWidthCompensation(centerX, centerY, halfW, halfH, needsWidthComp, compW, compH, data.isAuraContainer)
        data.options.onPositionChange(component, anchorX, anchorY, offsetX, offsetY, justifyH, nil, selfAnchorY)
    end

    if Engine.PositionManager then
        Engine.PositionManager:MarkDirty(parent)
    end

    if Engine.SmartGuides and data.guides then
        Engine.SmartGuides:Hide(data.guides)
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
        if data.handle.UpdateSize then
            data.handle:UpdateSize()
        end
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

    Engine.NudgeRepeat:Start(function()
        if selectedComponent then
            ComponentDrag:NudgeComponent(selectedComponent, dx, dy)
        end
    end, function() return selectedComponent ~= nil end)
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

    component:ClearAllPoints()
    component:SetPoint("CENTER", componentParent, "CENTER", newX, newY)

    if data.handle then
        data.handle:ClearAllPoints()
        data.handle:SetPoint("CENTER", component, "CENTER", 0, 0)
    end

    if data.options and data.options.onPositionChange then
        local needsWidthComp = NeedsEdgeCompensation(data.isFontString, data.isAuraContainer)
        local compW, compH = SafeGetSize(component)
        local anchorX, anchorY, offsetX, offsetY, justifyH, selfAnchorY =
            CalculateAnchorWithWidthCompensation(newX, newY, halfW, halfH, needsWidthComp, compW, compH, data.isAuraContainer)
        data.options.onPositionChange(component, anchorX, anchorY, offsetX, offsetY, justifyH, nil, selfAnchorY)
    end

    if Engine.PositionManager then
        Engine.PositionManager:MarkDirty(data.parent)
    end

    if Engine.SelectionTooltip and Engine.SelectionTooltip.ShowComponentPosition then
        local anchorX, anchorY, edgeOffX, edgeOffY, justifyH, selfAnchorY = CalculateAnchor(newX, newY, halfW, halfH)
        Engine.SelectionTooltip:ShowComponentPosition(component, data.key, anchorX, anchorY, newX, newY, edgeOffX, edgeOffY, justifyH, selfAnchorY)
    end
end

-- [ POSITION CALLBACK FACTORY ]---------------------------------------------------------------------
local function GetTransaction()
    local CM = Engine.CanvasMode
    return CM and CM.Transaction
end

function ComponentDrag:MakePositionCallback(plugin, systemIndex, key)
    return function(_, anchorX, anchorY, offsetX, offsetY, justifyH, justifyV)
        local Txn = GetTransaction()
        if Txn and Txn:IsActive() and Txn:GetPlugin() == plugin then
            Txn:SetPosition(key, { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH, justifyV = justifyV })
            return
        end
        local positions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        positions[key] = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH, justifyV = justifyV }
        plugin:SetSetting(systemIndex, "ComponentPositions", positions)
    end
end

function ComponentDrag:MakeAuraPositionCallback(plugin, systemIndex, key)
    return function(comp, anchorX, anchorY, offsetX, offsetY, justifyH, justifyV, selfAnchorY)
        local posX, posY
        local compParent = comp:GetParent()
        if compParent then
            local cx, cy = comp:GetCenter()
            local px, py = compParent:GetCenter()
            if cx and px then posX = cx - px end
            if cy and py then posY = cy - py end
        end
        local posData = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH, justifyV = justifyV, posX = posX, posY = posY, selfAnchorY = selfAnchorY }
        local Txn = GetTransaction()
        if Txn and Txn:IsActive() and Txn:GetPlugin() == plugin then
            Txn:SetPosition(key, posData)
            return
        end
        local positions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        positions[key] = posData
        plugin:SetSetting(systemIndex, "ComponentPositions", positions)
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
        isFontString = component.GetText ~= nil,
        isAuraContainer = options.isAuraContainer or false,

        guides = Engine.SmartGuides and Engine.SmartGuides:Create(parent) or nil,
        handle = nil,
    }

    -- Create handle using the Handle module with callbacks
    data.handle = HandleModule:Create(component, parent, {
        key = options.key,
        isSelected = function(comp) return selectedComponent == comp end,
        onSelect = function(comp) ComponentDrag:SelectComponent(comp) end,
        onDragUpdate = function(comp, handle) ComponentDrag:OnDragUpdate(comp, parent, data, handle) end,
        onDragStop = function(comp, handle) ComponentDrag:OnDragStop(comp, parent, data) end,
    })

    registeredComponents[component] = data

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
    if not data or not data.handle then
        return
    end

    local componentVisible = component.IsShown and component:IsShown() or true
    local shouldShow = enabled and componentVisible and Orbit:IsEditMode()

    if shouldShow then
        if data.handle.UpdateSize then
            data.handle:UpdateSize()
        end
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

    local editModeActive = Orbit:IsEditMode()
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

-- Check if a component is disabled via Canvas Mode
-- Uses the key stored during Attach and checks the parent frame's plugin
function ComponentDrag:IsDisabled(component)
    local data = registeredComponents[component]
    if not data then
        return false
    end

    local parent = data.parent
    local plugin = parent and parent.orbitPlugin
    if plugin and plugin.IsComponentDisabled then
        return plugin:IsComponentDisabled(data.key)
    end

    return false
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
                if anchorX == "RIGHT" then
                    finalX = -offsetX
                end
                if anchorY == "TOP" then
                    finalY = -offsetY
                end

                component:ClearAllPoints()

                if pos.justifyH and component.SetJustifyH then
                    component:SetJustifyH(pos.justifyH)
                end

                local selfAnchorY = pos.selfAnchorY or anchorY
                local selfAnchor = BuildComponentSelfAnchor(data.isFontString, data.isAuraContainer, selfAnchorY, pos.justifyH)
                component:SetPoint(selfAnchor, componentParent, anchorPoint, finalX, finalY)

                data.anchorX = anchorX
                data.anchorY = anchorY
                data.selfAnchorY = selfAnchorY
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
    if not frame then
        return {}
    end

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
                originalText = comp.GetText and comp:GetText() or nil,
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
    EditModeManagerFrame:HookScript("OnHide", function() ComponentDrag:DisableAll() end)
end
