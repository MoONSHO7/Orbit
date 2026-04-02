-- [ CANVAS MODE - DIALOG ACTIONS ]------------------------------------------------------------------
local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local LSM = LibStub("LibSharedMedia-3.0")

local CalculateAnchorWithWidthCompensation = OrbitEngine.PositionUtils.CalculateAnchorWithWidthCompensation
local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint
local BuildComponentSelfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor
local NeedsEdgeCompensation = OrbitEngine.PositionUtils.NeedsEdgeCompensation
local AnchorToCenter = OrbitEngine.PositionUtils.AnchorToCenter


-- [ APPLY ]------------------------------------------------------------------------------
function Dialog:Apply()
    if not self.targetPlugin or not self.previewFrame then self:CloseDialog(); return end
    local positions = {}
    local borderInset = self.previewFrame.borderInset or 0
    local halfWidth = self.previewFrame.sourceWidth / 2 - borderInset
    local halfHeight = self.previewFrame.sourceHeight / 2 - borderInset
    for key, comp in pairs(self.previewComponents) do
        local anchorX, anchorY, offsetX, offsetY, justifyH = comp.anchorX, comp.anchorY, comp.offsetX, comp.offsetY, comp.justifyH
        if not anchorX then
            local needsWidthComp = NeedsEdgeCompensation(comp.isFontString, comp.isAuraContainer)
            anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchorWithWidthCompensation(comp.posX or 0, comp.posY or 0, halfWidth, halfHeight, needsWidthComp, comp:GetWidth(), comp:GetHeight(), comp.isAuraContainer)
        end
        positions[key] = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH, selfAnchorY = comp.selfAnchorY, posX = comp.posX or 0, posY = comp.posY or 0 }
        if comp.pendingOverrides then positions[key].overrides = comp.pendingOverrides
        elseif comp.existingOverrides then positions[key].overrides = comp.existingOverrides end
        if key == "CastBar" then
            local subs = {}
            if comp.TextSub then subs.Text = { anchorX = comp.TextSub.anchorX, anchorY = comp.TextSub.anchorY, offsetX = comp.TextSub.offsetX, offsetY = comp.TextSub.offsetY, justifyH = comp.TextSub.justifyH } end
            if comp.TimerSub then subs.Timer = { anchorX = comp.TimerSub.anchorX, anchorY = comp.TimerSub.anchorY, offsetX = comp.TimerSub.offsetX, offsetY = comp.TimerSub.offsetY, justifyH = comp.TimerSub.justifyH } end
            if next(subs) then positions[key].subComponents = subs end
        end
    end
    local plugin = self.targetPlugin
    local systemIndex = self.targetSystemIndex
    if self.SyncToggle and self.SyncToggle:IsShown() then plugin:SetSetting(systemIndex, "UseGlobalTextStyle", self.SyncToggle.isSynced) end
    local isSynced = self.SyncToggle and self.SyncToggle:IsShown() and self.SyncToggle.isSynced
    local disabledCopy = {}
    for _, key in ipairs(self.disabledComponentKeys) do table.insert(disabledCopy, key) end
    if plugin.NormalizeCanvasDisabledComponents then
        disabledCopy = plugin:NormalizeCanvasDisabledComponents(disabledCopy)
    end
    -- Fan out StatusIcons grouped position to individual status icon keys
    if positions.StatusIcons then
        Orbit.GroupCanvasRegistration:FanOutStatusIcons(positions)
    end
    if plugin.NormalizeCanvasComponentPositions then
        positions = plugin:NormalizeCanvasComponentPositions(positions, systemIndex) or positions
    end
    if isSynced and plugin.supportsGlobalSync then
        plugin:SetSetting(1, "GlobalComponentPositions", positions)
        if plugin.IsComponentDisabled then plugin:SetSetting(1, "GlobalDisabledComponents", disabledCopy) end
    else
        plugin:SetSetting(systemIndex, "ComponentPositions", positions)
        if plugin.IsComponentDisabled then plugin:SetSetting(systemIndex, "DisabledComponents", disabledCopy) end
    end
    local targetFrame = self.targetFrame
    if OrbitEngine.CanvasComponentSettings and OrbitEngine.CanvasComponentSettings.FlushPendingPluginSettings then OrbitEngine.CanvasComponentSettings:FlushPendingPluginSettings() end
    -- Bypass Transaction:Commit() — Apply needs fine-grained control over sync/global writes
    -- and builds positions from preview state, not from pendingPositions.
    CanvasMode.Transaction:Clear()
    self:CloseDialog()
    if plugin.OnCanvasApply then plugin:OnCanvasApply() end
    if isSynced and plugin.ApplyAll then plugin:ApplyAll() end
end

-- [ CANCEL ]-----------------------------------------------------------------------------
function Dialog:Cancel()
    CanvasMode.Transaction:Rollback()
    self:CloseDialog()
end

-- [ RESET POSITIONS ]--------------------------------------------------------------------
function Dialog:ResetPositions()
    if not self.targetPlugin or not self.previewFrame then return end
    local plugin = self.targetPlugin
    
    local defaults = plugin.defaults and plugin.defaults.ComponentPositions
    local isSynced = self.SyncToggle and self.SyncToggle:IsShown() and self.SyncToggle.isSynced
    if (isSynced or not defaults or not next(defaults)) and plugin.defaults and plugin.defaults.GlobalComponentPositions then
        defaults = plugin.defaults.GlobalComponentPositions
    end
    if not defaults then return end
    local preview = self.previewFrame
    local borderInset = preview.borderInset or 0
    local halfW = preview.sourceWidth / 2 - borderInset
    local halfH = preview.sourceHeight / 2 - borderInset
    local dragComponents = OrbitEngine.ComponentDrag:GetComponentsForFrame(self.targetFrame)

    for key, dockIcon in pairs(self.dockComponents) do
        local defaultPos = defaults[key]
        local centerX, centerY = AnchorToCenter(defaultPos and defaultPos.anchorX or "CENTER", defaultPos and defaultPos.anchorY or "CENTER", defaultPos and defaultPos.offsetX or 0, defaultPos and defaultPos.offsetY or 0, halfW, halfH)
        if dockIcon.storedDraggableComp then
            local storedComp = dockIcon.storedDraggableComp
            storedComp:Show()
            storedComp.anchorX = defaultPos and defaultPos.anchorX or "CENTER"
            storedComp.anchorY = defaultPos and defaultPos.anchorY or "CENTER"
            storedComp.offsetX = defaultPos and defaultPos.offsetX or 0
            storedComp.offsetY = defaultPos and defaultPos.offsetY or 0
            storedComp.justifyH = defaultPos and defaultPos.justifyH or "CENTER"
            storedComp.posX, storedComp.posY = centerX, centerY
            storedComp.pendingOverrides, storedComp.existingOverrides = nil, nil
            local anchorPoint = BuildAnchorPoint(storedComp.anchorX, storedComp.anchorY)
            local finalX, finalY
            if storedComp.anchorX == "CENTER" then finalX = centerX else finalX = storedComp.offsetX; if storedComp.anchorX == "RIGHT" then finalX = -finalX end end
            if storedComp.anchorY == "CENTER" then finalY = centerY else finalY = storedComp.offsetY; if storedComp.anchorY == "TOP" then finalY = -finalY end end
            storedComp:ClearAllPoints()
            storedComp.selfAnchorY = defaultPos and defaultPos.selfAnchorY or storedComp.anchorY
            local selfAnchor = BuildComponentSelfAnchor(storedComp.isFontString, storedComp.isAuraContainer, storedComp.selfAnchorY, storedComp.justifyH)
            storedComp:SetPoint(selfAnchor, preview, anchorPoint, finalX, finalY)
            if storedComp.visual and storedComp.isFontString then CanvasMode.ApplyTextAlignment(storedComp, storedComp.visual, storedComp.justifyH) end
            self.previewComponents[key] = storedComp
        elseif dragComponents then
            local data = dragComponents[key]
            if data and data.component then
                local compData = { component = data.component, x = centerX, y = centerY, anchorX = defaultPos and defaultPos.anchorX or "CENTER", anchorY = defaultPos and defaultPos.anchorY or "CENTER", offsetX = defaultPos and defaultPos.offsetX or 0, offsetY = defaultPos and defaultPos.offsetY or 0, justifyH = defaultPos and defaultPos.justifyH or "CENTER" }
                local comp = CanvasMode.CreateDraggableComponent(preview, key, data.component, centerX, centerY, compData)
                if comp then comp:SetFrameLevel(preview:GetFrameLevel() + 10) end
                self.previewComponents[key] = comp
            end
        end
    end

    self:ClearDock()
    local defaultDisabled = plugin.defaults and plugin.defaults.DisabledComponents or {}
    self.disabledComponentKeys = {}
    for _, key in ipairs(defaultDisabled) do table.insert(self.disabledComponentKeys, key) end
    for _, key in ipairs(defaultDisabled) do
        local comp = self.previewComponents[key]
        if comp then
            comp:Hide()
            local sourceComponent = comp.sourceComponent or comp.visual or comp
            self:AddToDock(key, sourceComponent)
            if self.dockComponents[key] then self.dockComponents[key].storedDraggableComp = comp end
            self.previewComponents[key] = nil
        end
    end

    for key, container in pairs(self.previewComponents) do
        local defaultPos = defaults[key]
        if not defaultPos and dragComponents then
            local reg = dragComponents[key]
            if reg and reg.anchorX then defaultPos = { anchorX = reg.anchorX, anchorY = reg.anchorY, offsetX = reg.offsetX, offsetY = reg.offsetY, justifyH = reg.justifyH } end
        end
        if defaultPos and defaultPos.anchorX then
            container.anchorX = defaultPos.anchorX
            container.anchorY = defaultPos.anchorY or "CENTER"
            container.offsetX = defaultPos.offsetX or 0
            container.offsetY = defaultPos.offsetY or 0
            container.justifyH = defaultPos.justifyH or "CENTER"
            container.pendingOverrides, container.existingOverrides = nil, nil
            if container.anchorX == "LEFT" then container.posX = container.offsetX - halfW
            elseif container.anchorX == "RIGHT" then container.posX = halfW - container.offsetX
            else container.posX = 0 end
            if container.anchorY == "TOP" then container.posY = halfH - container.offsetY
            elseif container.anchorY == "BOTTOM" then container.posY = container.offsetY - halfH
            else container.posY = 0 end
            container.selfAnchorY = defaultPos.selfAnchorY or container.anchorY
            if container.isAuraContainer and container.RefreshAuraIcons then container:RefreshAuraIcons() end
            local anchorPoint = BuildAnchorPoint(container.anchorX, container.anchorY)
            local finalX, finalY
            if container.anchorX == "CENTER" then finalX = container.posX else finalX = container.offsetX; if container.anchorX == "RIGHT" then finalX = -finalX end end
            if container.anchorY == "CENTER" then finalY = container.posY else finalY = container.offsetY; if container.anchorY == "TOP" then finalY = -finalY end end
            container:ClearAllPoints()
            local selfAnchor = BuildComponentSelfAnchor(container.isFontString, container.isAuraContainer, container.selfAnchorY, container.justifyH)
            container:SetPoint(selfAnchor, preview, anchorPoint, finalX, finalY)
            if container.visual and container.isFontString then
                CanvasMode.ApplyTextAlignment(container, container.visual, container.justifyH)
                local globalFontName = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
                local fontPath = globalFontName and LSM:Fetch("font", globalFontName)
                if fontPath and container.visual.SetFont then
                    local _, currentSize = container.visual:GetFont()
                    container.visual:SetFont(fontPath, currentSize or 12, Orbit.Skin:GetFontOutline())
                    Orbit.Skin:ApplyFontShadow(container.visual)
                end
                if container.visual.SetTextColor and OrbitEngine.OverrideUtils then OrbitEngine.OverrideUtils.ApplyTextColor(container.visual, nil) end
            elseif container.visual and container.visual.GetObjectType and container.visual:GetObjectType() == "Texture" then
                container.visual:ClearAllPoints(); container.visual:SetAllPoints(container)
                container.originalVisualWidth, container.originalVisualHeight = nil, nil
            end
        end
    end
    if self.activeFilter and self.activeFilter ~= "All" then self:ApplyFilter(self.activeFilter) end

    if CanvasMode.Transaction:IsActive() then
        CanvasMode.Transaction:ClearPositions()
        for key, pos in pairs(defaults) do CanvasMode.Transaction:SetPosition(key, pos) end
        if dragComponents then
            for key, reg in pairs(dragComponents) do
                if not defaults[key] and reg.anchorX then
                    CanvasMode.Transaction:SetPosition(key, { anchorX = reg.anchorX, anchorY = reg.anchorY, offsetX = reg.offsetX, offsetY = reg.offsetY, justifyH = reg.justifyH })
                end
            end
        end
    end
end
