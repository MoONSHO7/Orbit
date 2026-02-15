-- [ CANVAS MODE - DIALOG ]----------------------------------------------------------
-- Main dialog operations for Canvas Mode (Open, Apply, Cancel, Reset)
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local C = CanvasMode.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- Use shared position utilities
local CalculateAnchor = OrbitEngine.PositionUtils.CalculateAnchor
local CalculateAnchorWithWidthCompensation = OrbitEngine.PositionUtils.CalculateAnchorWithWidthCompensation
local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint
local BuildComponentSelfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor
local NeedsEdgeCompensation = OrbitEngine.PositionUtils.NeedsEdgeCompensation

-- Use shared functions from other modules
local CreateDraggableComponent = function(...) return CanvasMode.CreateDraggableComponent(...) end
local ApplyTextAlignment = function(...) return CanvasMode.ApplyTextAlignment(...) end

-- [ FOOTER SETUP ]-----------------------------------------------------------------------

local Layout = OrbitEngine.Layout
local Constants = Orbit.Constants
local FC = Constants.Footer
local PC = Constants.Panel

-- Footer container
Dialog.Footer = CreateFrame("Frame", nil, Dialog)
Dialog.Footer:SetPoint("BOTTOMLEFT", Dialog, "BOTTOMLEFT", C.DIALOG_INSET, C.DIALOG_INSET)
Dialog.Footer:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -C.DIALOG_INSET, C.DIALOG_INSET)

-- Divider line
Dialog.FooterDivider = Dialog.Footer:CreateTexture(nil, "ARTWORK")
Dialog.FooterDivider:SetSize(PC.DividerWidth, PC.DividerHeight)
Dialog.FooterDivider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
Dialog.FooterDivider:SetPoint("TOP", Dialog.Footer, "TOP", 0, FC.DividerOffset)

-- Create buttons
Dialog.CancelButton = Layout:CreateButton(Dialog.Footer, "Cancel", function() Dialog:Cancel() end)
Dialog.ResetButton = Layout:CreateButton(Dialog.Footer, "Reset", function() Dialog:ResetPositions() end)
Dialog.ApplyButton = Layout:CreateButton(Dialog.Footer, "Apply", function() Dialog:Apply() end)

function Dialog:LayoutFooterButtons()
    local buttons = { self.CancelButton, self.ResetButton, self.ApplyButton }
    local numButtons = #buttons

    local availableWidth = (self:GetWidth() - (C.DIALOG_INSET * 2)) - (FC.SidePadding * 2)
    local totalSpacing = FC.ButtonSpacing * (numButtons - 1)
    local btnWidth = (availableWidth - totalSpacing) / numButtons

    local currentX = FC.SidePadding
    local topY = -FC.TopPadding

    for _, btn in ipairs(buttons) do
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.Footer, "TOPLEFT", currentX, topY)
        btn:SetWidth(btnWidth)
        btn:SetHeight(FC.ButtonHeight)
        currentX = currentX + btnWidth + FC.ButtonSpacing
    end

    local footerHeight = FC.TopPadding + FC.ButtonHeight + FC.BottomPadding
    self.Footer:SetHeight(footerHeight)
end

Dialog.Footer:SetHeight(FC.TopPadding + FC.ButtonHeight + FC.BottomPadding)

-- [ ESC KEY SUPPORT ]--------------------------------------------------------------------

table.insert(UISpecialFrames, "OrbitCanvasModeDialog")

Dialog:SetPropagateKeyboardInput(true)
Dialog:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then
        return
    end

    if key == "ESCAPE" then
        self:SetPropagateKeyboardInput(false)
        self:Cancel()
        C_Timer.After(0.05, function()
            if not InCombatLockdown() then
                self:SetPropagateKeyboardInput(true)
            end
        end)
    elseif key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
        if self.hoveredComponent then
            self:SetPropagateKeyboardInput(false)
            self:NudgeComponent(self.hoveredComponent, key)

            local direction = key
            local component = self.hoveredComponent
            OrbitEngine.NudgeRepeat:Start(function()
                if self.hoveredComponent == component then
                    self:NudgeComponent(component, direction)
                end
            end, function() return self.hoveredComponent == component end)
        else
            self:SetPropagateKeyboardInput(true)
        end
    else
        self:SetPropagateKeyboardInput(true)
    end
end)

Dialog:SetScript("OnKeyUp", function(self, key)
    if key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
        OrbitEngine.NudgeRepeat:Stop()
        if not InCombatLockdown() then
            self:SetPropagateKeyboardInput(true)
        end
    end
end)

-- [ STATE ]------------------------------------------------------------------------------

Dialog.targetFrame = nil
Dialog.targetPlugin = nil
Dialog.targetSystemIndex = nil
Dialog.originalPositions = {}
Dialog.previewFrame = nil
Dialog.hoveredComponent = nil

-- [ NUDGE COMPONENT ]--------------------------------------------------------------------

function Dialog:NudgeComponent(container, direction)
    if not container or not self.previewFrame then
        return
    end

    local preview = self.previewFrame
    local NUDGE = 1

    local anchorX = container.anchorX or "CENTER"
    local anchorY = container.anchorY or "CENTER"
    local offsetX = container.offsetX or 0
    local offsetY = container.offsetY or 0
    local justifyH = container.justifyH or "CENTER"

    if direction == "LEFT" then
        if anchorX == "LEFT" then
            offsetX = offsetX - NUDGE
        elseif anchorX == "RIGHT" then
            offsetX = offsetX + NUDGE
        else
            container.posX = (container.posX or 0) - NUDGE
            offsetX = container.posX
        end
    elseif direction == "RIGHT" then
        if anchorX == "LEFT" then
            offsetX = offsetX + NUDGE
        elseif anchorX == "RIGHT" then
            offsetX = offsetX - NUDGE
        else
            container.posX = (container.posX or 0) + NUDGE
            offsetX = container.posX
        end
    elseif direction == "UP" then
        if anchorY == "TOP" then
            offsetY = offsetY - NUDGE
        elseif anchorY == "BOTTOM" then
            offsetY = offsetY + NUDGE
        else
            container.posY = (container.posY or 0) + NUDGE
            offsetY = container.posY
        end
    elseif direction == "DOWN" then
        if anchorY == "TOP" then
            offsetY = offsetY + NUDGE
        elseif anchorY == "BOTTOM" then
            offsetY = offsetY - NUDGE
        else
            container.posY = (container.posY or 0) - NUDGE
            offsetY = container.posY
        end
    end

    container.offsetX = offsetX
    container.offsetY = offsetY

    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
    local posX = container.posX or 0
    local posY = container.posY or 0

    local finalX, finalY
    if anchorX == "CENTER" then
        finalX = posX
    else
        finalX = offsetX
        if anchorX == "RIGHT" then
            finalX = -finalX
        end
    end

    if anchorY == "CENTER" then
        finalY = posY
    else
        finalY = offsetY
        if anchorY == "TOP" then
            finalY = -finalY
        end
    end

    container:ClearAllPoints()
    local selfAnchor = BuildComponentSelfAnchor(container.isFontString, container.isAuraContainer, anchorY, justifyH)
    container:SetPoint(selfAnchor, preview, anchorPoint, finalX, finalY)

    if OrbitEngine.SelectionTooltip then
        OrbitEngine.SelectionTooltip:ShowComponentPosition(
            container,
            container.key,
            anchorX,
            anchorY,
            container.posX or 0,
            container.posY or 0,
            offsetX,
            offsetY,
            justifyH
        )
    end
end

-- [ SAVE ORIGINAL POSITIONS ]------------------------------------------------------------

function Dialog:SaveOriginalPositions()
    self.originalPositions = {}
    if not self.targetPlugin or not self.targetPlugin.GetSetting then
        return
    end

    local positions = self.targetPlugin:GetSetting(self.targetSystemIndex, "ComponentPositions")
    if positions then
        for key, pos in pairs(positions) do
            self.originalPositions[key] = {
                anchorX = pos.anchorX,
                anchorY = pos.anchorY,
                offsetX = pos.offsetX,
                offsetY = pos.offsetY,
                justifyH = pos.justifyH,
            }
        end
    end
end

-- [ OPEN DIALOG ]------------------------------------------------------------------------

function Dialog:Open(frame, plugin, systemIndex)
    if InCombatLockdown() then
        return false
    end
    if not frame then
        return false
    end

    -- Close Component Settings dialog if open
    if Orbit.CanvasComponentSettings and Orbit.CanvasComponentSettings:IsShown() then
        Orbit.CanvasComponentSettings:Hide()
    end

    local canvasFrame = frame.orbitCanvasFrame or frame

    self.targetFrame = frame
    self.targetPlugin = plugin
    self.targetSystemIndex = systemIndex

    local title = frame.orbitCanvasTitle or canvasFrame.editModeName or canvasFrame:GetName() or "Frame"
    self.Title:SetText("Canvas Mode: " .. title)

    self:CleanupPreview()

    -- Reset zoom/pan state
    self.zoomLevel = C.DEFAULT_ZOOM
    self.panOffsetX = 0
    self.panOffsetY = 0
    self.TransformLayer:SetScale(C.DEFAULT_ZOOM)
    self.TransformLayer:ClearAllPoints()
    self.TransformLayer:SetPoint("CENTER", self.Viewport, "CENTER", 0, 0)
    if self.ZoomIndicator then
        self.ZoomIndicator:SetText(string.format("%.0f%%", C.DEFAULT_ZOOM * 100))
    end

    -- Sync toggle: Show only for Action Bars plugin (or other plugins with GlobalComponentPositions)
    if self.SyncToggle then
        local supportsSync = plugin and plugin.system == "Orbit_ActionBars"
        if supportsSync then
            local isSynced = plugin:GetSetting(systemIndex, "UseGlobalTextStyle")
            self.SyncToggle.isSynced = (isSynced ~= false) -- default true
            self.SyncToggle:UpdateVisual()
            self.SyncToggle:Show()
        else
            self.SyncToggle:Hide()
        end
    end

    -- Create preview frame
    local textureName = plugin and plugin:GetSetting(systemIndex, "Texture") or "Melli"
    local borderSize = plugin and plugin:GetSetting(systemIndex, "BorderSize") or 1

    self.previewFrame = OrbitEngine.Preview.Frame:Create(canvasFrame, {
        scale = 1,
        parent = self.TransformLayer,
        borderSize = borderSize,
        textureName = textureName,
        useClassColor = true,
        plugin = plugin,
        systemIndex = systemIndex,
    })
    self.previewFrame:SetPoint("CENTER", self.TransformLayer, "CENTER", 0, 0)

    -- Create SmartGuides for visual snap feedback
    if OrbitEngine.SmartGuides then
        self.previewFrame.guides = OrbitEngine.SmartGuides:Create(self.previewFrame)
    end

    self.TransformLayer.baseWidth = canvasFrame:GetWidth()
    self.TransformLayer.baseHeight = canvasFrame:GetHeight()
    self.TransformLayer:SetSize(self.TransformLayer.baseWidth, self.TransformLayer.baseHeight)

    -- Get saved positions (use global if synced for Action Bars)
    local savedPositions
    local isSynced = plugin and plugin.system == "Orbit_ActionBars" and plugin:GetSetting(systemIndex, "UseGlobalTextStyle") ~= false
    if isSynced then
        savedPositions = plugin:GetSetting(1, "GlobalComponentPositions") or {}
    else
        savedPositions = plugin and plugin:GetSetting(systemIndex, "ComponentPositions") or {}
    end

    local defaults = plugin and plugin.defaults and plugin.defaults.ComponentPositions
    if defaults then
        for key, defaultPos in pairs(defaults) do
            if not savedPositions[key] or not savedPositions[key].anchorX then
                savedPositions[key] = defaultPos
            end
        end
    end

    -- Get draggable components
    local dragComponents = OrbitEngine.ComponentDrag:GetComponentsForFrame(frame)
    local components = {}
    local frameW = canvasFrame:GetWidth()
    local frameH = canvasFrame:GetHeight()

    for key, data in pairs(dragComponents) do
        local pos = savedPositions[key]

        if not pos and data.anchorX then
            pos = { anchorX = data.anchorX, anchorY = data.anchorY, offsetX = data.offsetX, offsetY = data.offsetY, justifyH = data.justifyH }
        end

        local centerX, centerY = 0, 0
        local anchorX, anchorY = "CENTER", "CENTER"
        local offsetX, offsetY = 0, 0

        if pos and pos.anchorX then
            anchorX = pos.anchorX
            anchorY = pos.anchorY or "CENTER"
            offsetX = pos.offsetX or 0
            offsetY = pos.offsetY or 0

            local halfW = frameW / 2
            local halfH = frameH / 2

            if anchorX == "LEFT" then
                centerX = offsetX - halfW
            elseif anchorX == "RIGHT" then
                centerX = halfW - offsetX
            end

            if anchorY == "BOTTOM" then
                centerY = offsetY - halfH
            elseif anchorY == "TOP" then
                centerY = halfH - offsetY
            end
        end

        local justifyH = pos and pos.justifyH
        if not justifyH then
            local halfW = frameW / 2
            if centerX == 0 then
                justifyH = "CENTER"
            elseif centerX > 0 then
                justifyH = centerX > halfW and "LEFT" or "RIGHT"
            else
                justifyH = centerX < -halfW and "RIGHT" or "LEFT"
            end
        end

        components[key] = {
            component = data.component,
            x = centerX,
            y = centerY,
            anchorX = anchorX,
            anchorY = anchorY,
            offsetX = offsetX,
            offsetY = offsetY,
            justifyH = justifyH,
            overrides = pos and pos.overrides,
        }
    end

    self:ClearDock()

    local hasDisabledFeature = plugin and plugin.IsComponentDisabled
    local disabledComponents = hasDisabledFeature and plugin:GetSetting(systemIndex, "DisabledComponents") or {}

    -- Initialize disabledComponentKeys from saved data
    self.disabledComponentKeys = {}
    for _, key in ipairs(disabledComponents) do
        table.insert(self.disabledComponentKeys, key)
    end

    local function isDisabled(key)
        if not hasDisabledFeature then
            return false
        end
        for _, k in ipairs(disabledComponents) do
            if k == key then
                return true
            end
        end
        return false
    end

    wipe(self.previewComponents)

    -- Check if preview already has components from CreateCanvasPreview hook
    if self.previewFrame.components and next(self.previewFrame.components) then
        for key, comp in pairs(self.previewFrame.components) do
            -- Check if this component should be disabled
            if isDisabled(key) then
                -- Hide the component and add to dock instead
                comp:Hide()
                local sourceComponent = comp.sourceComponent or comp
                self:AddToDock(key, sourceComponent)
                -- Store reference to original draggable comp so we can restore it
                if self.dockComponents[key] then
                    self.dockComponents[key].storedDraggableComp = comp
                end
            else
                self.previewComponents[key] = comp
            end
        end
    else
        -- Fallback: create from ComponentDrag-registered components
        for key, data in pairs(components) do
            if isDisabled(key) then
                self:AddToDock(key, data.component)
            else
                local comp = CreateDraggableComponent(self.previewFrame, key, data.component, data.x, data.y, data)
                if comp then
                    comp:SetFrameLevel(self.previewFrame:GetFrameLevel() + 10)
                end
                self.previewComponents[key] = comp
            end
        end
    end

    self:SetSize(C.DIALOG_WIDTH, C.DIALOG_HEIGHT + C.DOCK_HEIGHT)
    self:LayoutFooterButtons()

    self:Show()
    return true
end

-- [ CLEANUP PREVIEW ]--------------------------------------------------------------------

function Dialog:CleanupPreview()
    for key, comp in pairs(self.previewComponents) do
        comp:Hide()
        comp:SetParent(nil)
    end
    wipe(self.previewComponents)

    self:ClearDock()

    if self.previewFrame then
        self.previewFrame:Hide()
        self.previewFrame:SetParent(nil)
        self.previewFrame = nil
    end
end

-- [ CLOSE DIALOG ]-----------------------------------------------------------------------

function Dialog:CloseDialog()
    if Orbit.CanvasComponentSettings and Orbit.CanvasComponentSettings:IsShown() then
        Orbit.CanvasComponentSettings:Hide()
    end

    self:CleanupPreview()

    self.targetFrame = nil
    self.targetPlugin = nil
    self.targetSystemIndex = nil
    wipe(self.originalPositions)

    self:Hide()

    if OrbitEngine.ComponentEdit then
        OrbitEngine.ComponentEdit.currentFrame = nil
    end

    if OrbitEngine.FrameSelection then
        OrbitEngine.FrameSelection:RefreshVisuals()
    end
end

-- [ APPLY ]------------------------------------------------------------------------------

function Dialog:Apply()
    if not self.targetPlugin or not self.previewFrame then
        self:CloseDialog()
        return
    end

    local positions = {}
    local halfWidth = self.previewFrame.sourceWidth / 2
    local halfHeight = self.previewFrame.sourceHeight / 2

    for key, comp in pairs(self.previewComponents) do
        local anchorX = comp.anchorX
        local anchorY = comp.anchorY
        local offsetX = comp.offsetX
        local offsetY = comp.offsetY
        local justifyH = comp.justifyH

        if not anchorX then
            local posX = comp.posX or 0
            local posY = comp.posY or 0
            local needsWidthComp = NeedsEdgeCompensation(comp.isFontString, comp.isAuraContainer)
            anchorX, anchorY, offsetX, offsetY, justifyH =
                CalculateAnchorWithWidthCompensation(posX, posY, halfWidth, halfHeight, needsWidthComp, comp:GetWidth())
            -- Aura containers need height compensation for vertical self-anchors
            if comp.isAuraContainer and anchorY ~= "CENTER" then
                offsetY = offsetY - (comp:GetHeight() or 0) / 2
            end
        end

        positions[key] = {
            anchorX = anchorX,
            anchorY = anchorY,
            offsetX = offsetX,
            offsetY = offsetY,
            justifyH = justifyH,
            posX = comp.posX or 0, -- Also save center-relative for easier restoration
            posY = comp.posY or 0,
        }

        if comp.pendingOverrides then
            positions[key].overrides = comp.pendingOverrides
        elseif comp.existingOverrides then
            positions[key].overrides = comp.existingOverrides
        end
    end

    local plugin = self.targetPlugin
    local systemIndex = self.targetSystemIndex

    -- Check if synced (Action Bars specific)
    local isSynced = self.SyncToggle and self.SyncToggle:IsShown() and self.SyncToggle.isSynced

    if isSynced and plugin.system == "Orbit_ActionBars" then
        -- Save to global positions (stored at systemIndex 1 for consistency)
        plugin:SetSetting(1, "GlobalComponentPositions", positions)

        -- Also save disabled components to global
        if plugin.IsComponentDisabled then
            local disabledCopy = {}
            for _, key in ipairs(self.disabledComponentKeys) do
                table.insert(disabledCopy, key)
            end
            plugin:SetSetting(1, "GlobalDisabledComponents", disabledCopy)
        end

        -- Propagate to all synced action bars
        -- Note: ApplySettings will use GlobalComponentPositions for all bars with UseGlobalTextStyle=true
    else
        -- Local save only
        plugin:SetSetting(systemIndex, "ComponentPositions", positions)

        if plugin.IsComponentDisabled then
            local disabledCopy = {}
            for _, key in ipairs(self.disabledComponentKeys) do
                table.insert(disabledCopy, key)
            end
            plugin:SetSetting(systemIndex, "DisabledComponents", disabledCopy)
        end
    end

    -- Apply settings to the specific frame that was edited
    local targetFrame = self.targetFrame
    self:CloseDialog()

    if plugin.ApplySettings then
        plugin:ApplySettings(targetFrame)
    end

    -- For Action Bars, refresh all bars to pick up global changes
    if isSynced and plugin.ApplyAll then
        plugin:ApplyAll()
    end
end

-- [ CANCEL ]-----------------------------------------------------------------------------

function Dialog:Cancel() self:CloseDialog() end

-- [ RESET POSITIONS ]--------------------------------------------------------------------

function Dialog:ResetPositions()
    if not self.targetPlugin or not self.previewFrame then
        return
    end

    local plugin = self.targetPlugin
    local defaults = plugin.defaults and plugin.defaults.ComponentPositions
    if not defaults then
        return
    end

    local preview = self.previewFrame
    local halfW = preview.sourceWidth / 2
    local halfH = preview.sourceHeight / 2

    -- Restore disabled components from dock
    local dragComponents = OrbitEngine.ComponentDrag:GetComponentsForFrame(self.targetFrame)
    for key, dockIcon in pairs(self.dockComponents) do
        local defaultPos = defaults[key]
        local centerX, centerY = 0, 0

        if defaultPos and defaultPos.anchorX then
            if defaultPos.anchorX == "LEFT" then
                centerX = (defaultPos.offsetX or 0) - halfW
            elseif defaultPos.anchorX == "RIGHT" then
                centerX = halfW - (defaultPos.offsetX or 0)
            end

            if defaultPos.anchorY == "BOTTOM" then
                centerY = (defaultPos.offsetY or 0) - halfH
            elseif defaultPos.anchorY == "TOP" then
                centerY = halfH - (defaultPos.offsetY or 0)
            end
        end

        -- Check for CDM path: use storedDraggableComp if available
        if dockIcon.storedDraggableComp then
            local storedComp = dockIcon.storedDraggableComp
            storedComp:Show()

            -- Reset position to default
            storedComp.anchorX = defaultPos and defaultPos.anchorX or "CENTER"
            storedComp.anchorY = defaultPos and defaultPos.anchorY or "CENTER"
            storedComp.offsetX = defaultPos and defaultPos.offsetX or 0
            storedComp.offsetY = defaultPos and defaultPos.offsetY or 0
            storedComp.justifyH = defaultPos and defaultPos.justifyH or "CENTER"
            storedComp.posX = centerX
            storedComp.posY = centerY
            storedComp.pendingOverrides = nil
            storedComp.existingOverrides = nil

            -- Reposition
            local anchorPoint = BuildAnchorPoint(storedComp.anchorX, storedComp.anchorY)
            local finalX, finalY
            if storedComp.anchorX == "CENTER" then
                finalX = centerX
            else
                finalX = storedComp.offsetX
                if storedComp.anchorX == "RIGHT" then
                    finalX = -finalX
                end
            end
            if storedComp.anchorY == "CENTER" then
                finalY = centerY
            else
                finalY = storedComp.offsetY
                if storedComp.anchorY == "TOP" then
                    finalY = -finalY
                end
            end

            storedComp:ClearAllPoints()
            if storedComp.isFontString and storedComp.justifyH ~= "CENTER" then
                storedComp:SetPoint(storedComp.justifyH, preview, anchorPoint, finalX, finalY)
            else
                storedComp:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
            end

            if storedComp.visual and storedComp.isFontString then
                ApplyTextAlignment(storedComp, storedComp.visual, storedComp.justifyH)
            end

            self.previewComponents[key] = storedComp
        elseif dragComponents then
            -- Fallback: use ComponentDrag path
            local data = dragComponents[key]
            if data and data.component then
                local compData = {
                    component = data.component,
                    x = centerX,
                    y = centerY,
                    anchorX = defaultPos and defaultPos.anchorX or "CENTER",
                    anchorY = defaultPos and defaultPos.anchorY or "CENTER",
                    offsetX = defaultPos and defaultPos.offsetX or 0,
                    offsetY = defaultPos and defaultPos.offsetY or 0,
                    justifyH = defaultPos and defaultPos.justifyH or "CENTER",
                }

                local comp = CreateDraggableComponent(preview, key, data.component, centerX, centerY, compData)
                if comp then
                    comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                end
                self.previewComponents[key] = comp
            end
        end
    end

    self:ClearDock()

    -- Reset disabledComponentKeys to defaults
    local defaultDisabled = plugin.defaults and plugin.defaults.DisabledComponents or {}
    self.disabledComponentKeys = {}
    for _, key in ipairs(defaultDisabled) do
        table.insert(self.disabledComponentKeys, key)
    end

    -- Move default-disabled components back to dock
    for _, key in ipairs(defaultDisabled) do
        local comp = self.previewComponents[key]
        if comp then
            comp:Hide()
            local sourceComponent = comp.sourceComponent or comp.visual or comp
            self:AddToDock(key, sourceComponent)
            if self.dockComponents[key] then
                self.dockComponents[key].storedDraggableComp = comp
            end
            self.previewComponents[key] = nil
        end
    end

    -- Reset each preview container
    for key, container in pairs(self.previewComponents) do
        local defaultPos = defaults[key]
        if defaultPos and defaultPos.anchorX then
            container.anchorX = defaultPos.anchorX
            container.anchorY = defaultPos.anchorY or "CENTER"
            container.offsetX = defaultPos.offsetX or 0
            container.offsetY = defaultPos.offsetY or 0
            container.justifyH = defaultPos.justifyH or "CENTER"

            container.pendingOverrides = nil
            container.existingOverrides = nil

            if container.anchorX == "LEFT" then
                container.posX = container.offsetX - halfW
            elseif container.anchorX == "RIGHT" then
                container.posX = halfW - container.offsetX
            else
                container.posX = 0
            end

            if container.anchorY == "TOP" then
                container.posY = halfH - container.offsetY
            elseif container.anchorY == "BOTTOM" then
                container.posY = container.offsetY - halfH
            else
                container.posY = 0
            end

            local anchorPoint = BuildAnchorPoint(container.anchorX, container.anchorY)

            local finalX, finalY
            if container.anchorX == "CENTER" then
                finalX = container.posX
            else
                finalX = container.offsetX
                if container.anchorX == "RIGHT" then
                    finalX = -finalX
                end
            end

            if container.anchorY == "CENTER" then
                finalY = container.posY
            else
                finalY = container.offsetY
                if container.anchorY == "TOP" then
                    finalY = -finalY
                end
            end

            container:ClearAllPoints()
            if container.isFontString and container.justifyH ~= "CENTER" then
                container:SetPoint(container.justifyH, preview, anchorPoint, finalX, finalY)
            else
                container:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
            end

            if container.visual and container.isFontString then
                ApplyTextAlignment(container, container.visual, container.justifyH)

                -- Use current global font setting (not a hardcoded constant)
                local globalFontName = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
                local fontPath = globalFontName and LSM:Fetch("font", globalFontName)
                if fontPath and container.visual.SetFont then
                    local _, currentSize = container.visual:GetFont()
                    local flags = Orbit.Skin:GetFontOutline()
                    container.visual:SetFont(fontPath, currentSize or 12, flags)
                end

                -- Reset text color to current global FontColorCurve (not hardcoded white)
                if container.visual.SetTextColor and OrbitEngine.OverrideUtils then
                    OrbitEngine.OverrideUtils.ApplyTextColor(container.visual, nil)
                end

                if container.visual.SetShadowOffset then
                    container.visual:SetShadowOffset(0, 0)
                end
            elseif container.visual and container.visual.GetObjectType and container.visual:GetObjectType() == "Texture" then
                container.visual:ClearAllPoints()
                container.visual:SetAllPoints(container)
                container.originalVisualWidth = nil
                container.originalVisualHeight = nil
            end
        end
    end
end

-- [ EDIT MODE LIFECYCLE ]----------------------------------------------------------------

if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", function()
        if Dialog:IsShown() then
            Dialog:Cancel()
        end
    end)
end

-- [ EXPORT ]-----------------------------------------------------------------------------

Orbit.CanvasModeDialog = Dialog
OrbitEngine.CanvasModeDialog = Dialog
