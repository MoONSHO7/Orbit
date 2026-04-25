-- [ CANVAS MODE - DIALOG ] --------------------------------------------------------------------------
-- Main dialog operations for Canvas Mode (Open, Apply, Cancel, Reset)

local _, Orbit = ...
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
local AnchorToCenter = OrbitEngine.PositionUtils.AnchorToCenter

-- Forward-declared: resolved at runtime after CanvasModeDrag.lua loads

-- [ FOOTER SETUP ] ----------------------------------------------------------------------------------
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

-- [ ESC KEY SUPPORT ] -------------------------------------------------------------------------------
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

-- [ STATE ] -----------------------------------------------------------------------------------------
Dialog.targetFrame = nil
Dialog.targetPlugin = nil
Dialog.targetSystemIndex = nil
Dialog.previewFrame = nil
Dialog.hoveredComponent = nil

-- [ NUDGE COMPONENT ] -------------------------------------------------------------------------------
function Dialog:NudgeComponent(container, direction)
    if not container or not self.previewFrame then
        return
    end

    local NUDGE = 1

    if container.isSubComponent then
        local parent = container.subComponentParent
        if not parent then return end
        local cx, cy = container:GetCenter()
        local px, py = parent:GetCenter()
        local relX = (cx - px) or 0
        local relY = (cy - py) or 0
        if direction == "LEFT" then relX = relX - NUDGE
        elseif direction == "RIGHT" then relX = relX + NUDGE
        elseif direction == "UP" then relY = relY + NUDGE
        elseif direction == "DOWN" then relY = relY - NUDGE end
        container:ClearAllPoints()
        container:SetPoint("CENTER", parent, "CENTER", relX, relY)
        local halfW = parent:GetWidth() / 2
        local halfH = parent:GetHeight() / 2
        local aX, aY, oX, oY, jH = CalculateAnchorWithWidthCompensation(relX, relY, halfW, halfH, true, container:GetWidth())
        container.anchorX = aX
        container.anchorY = aY
        container.offsetX = oX
        container.offsetY = oY
        container.justifyH = jH
        OrbitEngine.SelectionTooltip:ShowComponentPosition(container, container.key, aX, aY, relX, relY, oX, oY, jH)
        return
    end

    local preview = self.previewFrame

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

    local borderInset = preview.borderInset or 0
    local halfW = preview.sourceWidth / 2 - borderInset
    local halfH = preview.sourceHeight / 2 - borderInset
    container.posX, container.posY = AnchorToCenter(anchorX, anchorY, offsetX, offsetY, halfW, halfH)

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
    local selfAnchor = BuildComponentSelfAnchor(container.isFontString, container.isAuraContainer, container.selfAnchorY or anchorY, justifyH)
    container:SetPoint(selfAnchor, preview, anchorPoint, finalX, finalY)

    OrbitEngine.SelectionTooltip:ShowComponentPosition(
        container,
        container.key,
        anchorX,
        anchorY,
        container.posX or 0,
        container.posY or 0,
        offsetX,
        offsetY,
        justifyH,
        container.selfAnchorY
    )

    -- Stage nudged position into transaction for live preview updates
    if CanvasMode.Transaction and CanvasMode.Transaction:IsActive() and container.key then
        CanvasMode.Transaction:SetPosition(container.key, {
            anchorX = anchorX, anchorY = anchorY,
            offsetX = offsetX, offsetY = offsetY,
            justifyH = justifyH, selfAnchorY = container.selfAnchorY,
            posX = container.posX, posY = container.posY,
        })
    end
end


-- [ AURA COMPONENT KEYS ] ---------------------------------------------------------------------------
local AURA_COMPONENT_KEYS = { DefensiveIcon = true, PrivateAuraAnchor = true, CrowdControlIcon = true }
do
    local HealerReg = Orbit.HealerAuraRegistry
    if HealerReg then
        for _, k in ipairs(HealerReg:AllSlotKeys()) do AURA_COMPONENT_KEYS[k] = true end
    end
end

-- [ OPEN DIALOG ] -----------------------------------------------------------------------------------
function Dialog:Open(frame, plugin, systemIndex)
    if InCombatLockdown() then
        return false
    end
    if not frame then
        return false
    end

    if Orbit.CanvasComponentSettings and Orbit.CanvasComponentSettings.componentKey then
        Orbit.CanvasComponentSettings:Close()
    end

    local canvasFrame = frame.orbitCanvasFrame or frame

    self.targetFrame = frame
    self.targetPlugin = plugin
    self.targetSystemIndex = systemIndex

    local title = frame.orbitCanvasTitle or canvasFrame.editModeName or canvasFrame:GetName() or "Frame"
    self.Title:SetText(title)

    self:CleanupPreview()

    -- Tab visibility deferred until after components are loaded
    if self.filterTabButtons then
        for _, label in ipairs(self.filterTabButtons) do label:Hide(); if label.hitButton then label.hitButton:Hide() end end
    end

    -- Reset zoom/pan state. Plugins can set canvasDefaultZoom to override the default.
    local initialZoom = (plugin and plugin.canvasDefaultZoom) or C.DEFAULT_ZOOM
    self.zoomLevel = initialZoom
    self.panOffsetX = 0
    self.panOffsetY = 0
    self.TransformLayer:SetScale(initialZoom)
    self.TransformLayer:ClearAllPoints()
    self.TransformLayer:SetPoint("CENTER", self.Viewport, "CENTER", 0, C.DOCK_Y_OFFSET)
    if self.ZoomIndicator then
        self.ZoomIndicator:SetText(string.format("%.0f%%", initialZoom * 100))
    end

    -- Sync toggle: Show only for Action Bars plugin (or other plugins with GlobalComponentPositions)
    if self.SyncToggle then
        local supportsSync = plugin and plugin.supportsGlobalSync
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
    local borderSize = plugin and plugin:GetSetting(systemIndex, "BorderSize") or OrbitEngine.Pixel:DefaultBorderSize(canvasFrame:GetEffectiveScale())

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
    self.previewFrame.guides = OrbitEngine.SmartGuides:Create(self.previewFrame)

    self.TransformLayer.baseWidth = canvasFrame:GetWidth()
    self.TransformLayer.baseHeight = canvasFrame:GetHeight()
    self.TransformLayer:SetSize(self.TransformLayer.baseWidth, self.TransformLayer.baseHeight)

    -- The cleric's Detect Magic reveals changes to the dungeon walls in real time
    self:HookSourceSizeChanged(canvasFrame)

    -- Get saved positions (use global if synced for Action Bars)
    local savedPositions
    local isSynced = plugin and plugin.supportsGlobalSync and plugin:GetSetting(systemIndex, "UseGlobalTextStyle") ~= false
    if isSynced then
        savedPositions = plugin:GetSetting(1, "GlobalComponentPositions") or {}
    else
        savedPositions = plugin and plugin.GetComponentPositions and plugin:GetComponentPositions(systemIndex) or plugin and plugin:GetSetting(systemIndex, "ComponentPositions") or {}
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

        local anchorX = pos and pos.anchorX or "CENTER"
        local anchorY = pos and (pos.anchorY or "CENTER") or "CENTER"
        local offsetX = pos and pos.offsetX or 0
        local offsetY = pos and pos.offsetY or 0
        local centerX, centerY = AnchorToCenter(anchorX, anchorY, offsetX, offsetY, frameW / 2, frameH / 2)

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
            subComponents = pos and pos.subComponents,
            posX = pos and pos.posX,
            posY = pos and pos.posY,
            selfAnchorY = pos and pos.selfAnchorY,
        }
    end

    self:ClearDock()

    local hasDisabledFeature = plugin and plugin.IsComponentDisabled
    local disabledComponents
    if hasDisabledFeature then
        if isSynced then disabledComponents = plugin:GetSetting(1, "GlobalDisabledComponents") or {}
        else disabledComponents = plugin:GetSetting(systemIndex, "DisabledComponents") or {} end
    else disabledComponents = {} end

    local disabledSet = {}
    for _, key in ipairs(disabledComponents) do disabledSet[key] = true end

    self.disabledComponentKeys = {}
    for _, key in ipairs(disabledComponents) do
        table.insert(self.disabledComponentKeys, key)
    end

    local healthTextDisabled = disabledSet["HealthText"]
    if not healthTextDisabled then
        if not disabledSet["Status"] then
            table.insert(self.disabledComponentKeys, "Status")
            disabledSet["Status"] = true
        end
    end

    local function isDisabled(key)
        if not hasDisabledFeature then return false end
        return disabledSet[key] == true
    end

    local function isHidden(key)
        return plugin and plugin.IsCanvasComponentHidden and plugin:IsCanvasComponentHidden(key)
    end

    wipe(self.previewComponents)

    -- Adopt any components pre-built by CreateCanvasPreview
    if self.previewFrame.components then
        for key, comp in pairs(self.previewFrame.components) do
            if isHidden(key) then
                comp:Hide()
            elseif isDisabled(key) then
                comp:Hide()
                local sourceComponent = comp.sourceComponent or comp
                self:AddToDock(key, sourceComponent)
                if self.dockComponents[key] then
                    self.dockComponents[key].storedDraggableComp = comp
                end
            else
                self.previewComponents[key] = comp
            end
        end
    end

    -- Create remaining components from ComponentDrag registry
    for key, data in pairs(components) do
        if not isHidden(key) and not self.previewComponents[key] and not (self.dockComponents and self.dockComponents[key]) then
            if isDisabled(key) then
                self:AddToDock(key, data.component)
            else
                local comp = CanvasMode.CreateDraggableComponent(self.previewFrame, key, data.component, data.x, data.y, data)
                if comp then
                    comp:SetFrameLevel(self.previewFrame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
                end
                self.previewComponents[key] = comp
            end
        end
    end

    -- Re-dock disabled subcomponents (keys like "CastBar.Text" aren't in dragComponents)
    local SUB_FRAME_MAP = { Text = "TextSub", Timer = "TimerSub" }
    for _, disabledKey in ipairs(disabledComponents) do
        local parentKey, subKey = disabledKey:match("^(.+)%.(.+)$")
        if parentKey and subKey and self.previewComponents[parentKey] then
            local subFieldName = SUB_FRAME_MAP[subKey]
            local subFrame = subFieldName and self.previewComponents[parentKey][subFieldName]
            if subFrame then
                subFrame:Hide()
                self:AddToDock(disabledKey, subFrame.visual)
                if self.dockComponents[disabledKey] then
                    self.dockComponents[disabledKey].storedSubFrame = subFrame
                    self.dockComponents[disabledKey].parentContainer = self.previewComponents[parentKey]
                end
            end
        end
    end

    local showTabs = canvasFrame.showFilterTabs or false
    if not showTabs then
        for key, comp in pairs(self.previewComponents) do
            if comp.isAuraContainer or AURA_COMPONENT_KEYS[key] then showTabs = true; break end
        end
    end
    if not showTabs and self.dockComponents then
        for key, _ in pairs(self.dockComponents) do
            if AURA_COMPONENT_KEYS[key] then showTabs = true; break end
        end
    end
    if self.filterTabButtons then
        self.activeFilter = "All"
        for _, label in ipairs(self.filterTabButtons) do
            label:SetShown(showTabs)
            if label.hitButton then label.hitButton:SetShown(showTabs) end
            if showTabs then
                local isAll = label.filterName == "All"
                label:SetTextColor(isAll and 1.0 or 0.6, isAll and 0.82 or 0.6, isAll and 0.0 or 0.6)
            end
        end
    end

    if self.OverrideContainer then self.OverrideContainer:Hide() end
    if self.ViewportDivider then self.ViewportDivider:Hide() end

    self:SetWidth(math.max(C.DIALOG_MIN_WIDTH, self:GetWidth()))
    self:RecalculateHeight()

    self:Show()

    -- Begin transactional cache so edits are buffered until Apply/Cancel
    CanvasMode.Transaction:Begin(plugin, systemIndex)

    if OrbitEngine.CanvasComponentSettings and OrbitEngine.CanvasComponentSettings.ApplyInitialPluginPreviews then
        OrbitEngine.CanvasComponentSettings:ApplyInitialPluginPreviews(self.targetPlugin, self.targetSystemIndex)
    end

    -- Auto-start tour for first-time users
    local as = Orbit.db and Orbit.db.AccountSettings
    if as and not as.CanvasTourComplete then
        as.CanvasTourComplete = true
        C_Timer.After(0.1, function() if self:IsShown() then self:StartTour() end end)
    end

    return true
end

-- [ APPLY FILTER ] ----------------------------------------------------------------------------------
function Dialog:ApplyFilter(filterName)
    self.activeFilter = filterName or "All"
    for key, comp in pairs(self.previewComponents) do
        local isAura = comp.isAuraContainer or AURA_COMPONENT_KEYS[key]
        local visible = true
        if filterName == "Text" then
            visible = comp.isFontString == true
        elseif filterName == "Icons" then
            visible = not comp.isFontString and not isAura
        elseif filterName == "Auras" then
            visible = isAura == true
        end
        comp:SetShown(visible)
        if comp.handle then comp.handle:SetShown(visible) end
    end
end

-- [ LIVE DIMENSION SYNC ] ---------------------------------------------------------------------------
function Dialog:HookSourceSizeChanged(sourceFrame)
    self:UnhookSourceSizeChanged()
    if not sourceFrame then return end

    self._sizeHookFrame = sourceFrame
    self._sizeHookActive = true

    if not sourceFrame._orbitCanvasSizeHooked then
        sourceFrame._orbitCanvasSizeHooked = true
        sourceFrame:HookScript("OnSizeChanged", function(_, w, h)
            local dlg = CanvasMode.Dialog
            if not dlg._sizeHookActive or dlg._sizeHookFrame ~= sourceFrame then return end
            if not dlg.previewFrame or not dlg:IsShown() then return end
            if w <= 0 or h <= 0 then return end

            dlg.previewFrame.sourceWidth = w
            dlg.previewFrame.sourceHeight = h
            local globalBorder = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderSize or 0
            dlg.previewFrame.borderInset = Orbit.Engine.Pixel:Multiple(globalBorder, sourceFrame:GetEffectiveScale())
            dlg.previewFrame:SetSize(w, h)
            dlg.TransformLayer.baseWidth = w
            dlg.TransformLayer.baseHeight = h
            dlg.TransformLayer:SetSize(w, h)
            CanvasMode.ApplyPanOffset(dlg, dlg.panOffsetX, dlg.panOffsetY)
        end)
    end
end

function Dialog:UnhookSourceSizeChanged()
    self._sizeHookActive = nil
    self._sizeHookFrame = nil
end

-- [ CLEANUP PREVIEW ] -------------------------------------------------------------------------------
function Dialog:CleanupPreview()
    self.activeFilter = "All"
    self:UnhookSourceSizeChanged()

    for key, comp in pairs(self.previewComponents) do
        if comp._cyclingTicker then comp._cyclingTicker:Cancel(); comp._cyclingTicker = nil end
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

-- [ CLOSE DIALOG ] ----------------------------------------------------------------------------------
function Dialog:CloseDialog()
    if Orbit.CanvasComponentSettings and Orbit.CanvasComponentSettings.componentKey then
        Orbit.CanvasComponentSettings:Close()
    end

    self:EndTourCleanup()
    self:CleanupPreview()

    self.targetFrame = nil
    self.targetPlugin = nil
    self.targetSystemIndex = nil

    self:Hide()

    OrbitEngine.CanvasMode.currentFrame = nil

    OrbitEngine.FrameSelection:RefreshVisuals()
end

-- [ EDIT MODE LIFECYCLE ] ---------------------------------------------------------------------------
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", function()
        if Dialog:IsShown() then
            Dialog:Cancel()
        end
    end)
end

-- [ EXPORT ] ----------------------------------------------------------------------------------------
Orbit.CanvasModeDialog = Dialog
OrbitEngine.CanvasModeDialog = Dialog
