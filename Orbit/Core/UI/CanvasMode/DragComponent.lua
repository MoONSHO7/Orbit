-- [ CANVAS MODE - DRAG COMPONENT ]------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local CC = CanvasMode.CreatorConstants
local LSM = LibStub("LibSharedMedia-3.0")

local CalculateAnchor = OrbitEngine.PositionUtils.CalculateAnchor
local CalculateAnchorWithWidthCompensation = OrbitEngine.PositionUtils.CalculateAnchorWithWidthCompensation
local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint
local BuildComponentSelfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor
local NeedsEdgeCompensation = OrbitEngine.PositionUtils.NeedsEdgeCompensation
local SmartGuides = OrbitEngine.SmartGuides
local ApplyTextAlignment = CanvasMode.ApplyTextAlignment
local SetBorderColor = CanvasMode.SetBorderColor

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local SNAP_SIZE = 5
local EDGE_THRESHOLD = 3
local DRAG_THRESHOLD = 3
local CLICK_THRESHOLD = 0.3
local CLAMP_PADDING_X = 100
local CLAMP_PADDING_Y = 50
local SNAP_GRID = 5
local DEFAULT_COMP_WIDTH = 40
local DEFAULT_COMP_HEIGHT = 16

-- [ TYPE DETECTION ]--------------------------------------------------------------------------------

local function DetectCreatorType(key, source)
    local isFontString = source and source.GetFont ~= nil
    local isTexture = source and source.GetTexture ~= nil and not isFontString
    local isIconFrame = source and source.Icon and source.Icon.GetTexture and key ~= "CastBar"

    if isFontString then return "FontString", true, false, false end
    if isTexture then return "Texture", false, false, false end
    if isIconFrame then return "IconFrame", false, false, false end
    if key == "Portrait" then return "Portrait", false, false, false end
    if key == "Buffs" or key == "Debuffs" then return "Aura", false, true, false end
    if key == "CastBar" then return "CastBar", false, false, false end
    return nil, false, false, false
end

-- [ FALLBACK VISUAL ]-------------------------------------------------------------------------------

local function CreateFallbackVisual(container, key)
    local visual = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    visual:SetPoint("CENTER", container, "CENTER", 0, 0)
    visual:SetText(key or "?")
    container:SetSize(CC.FALLBACK_CONTAINER_WIDTH, CC.FALLBACK_CONTAINER_HEIGHT)
    return visual
end

-- [ CONTAINER STATE ]-------------------------------------------------------------------------------

local function SetupContainerState(container, preview, key, isFontString, isAuraContainer, startX, startY, data)
    container.border = container:CreateTexture(nil, "BACKGROUND")
    container.border:SetAllPoints()
    SetBorderColor(container.border, CC.BORDER_COLOR_IDLE)

    container.posX = container.posX or startX
    container.posY = container.posY or startY
    container.key = key
    container.isFontString = isFontString
    container.existingOverrides = data and data.overrides

    local halfW = preview.sourceWidth / 2
    local halfH = preview.sourceHeight / 2
    local anchorX, anchorY, offsetX, offsetY, justifyH

    if data and data.anchorX then
        anchorX, anchorY, offsetX, offsetY, justifyH = data.anchorX, data.anchorY, data.offsetX, data.offsetY, data.justifyH
    else
        anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchor(startX, startY, halfW, halfH)
    end

    container.anchorX = anchorX
    container.anchorY = anchorY
    container.offsetX = offsetX
    container.offsetY = offsetY
    container.justifyH = justifyH

    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
    local finalX = anchorX == "CENTER" and startX or (anchorX == "RIGHT" and -offsetX or offsetX)
    local finalY = anchorY == "CENTER" and startY or (anchorY == "TOP" and -offsetY or offsetY)

    container:ClearAllPoints()
    local selfAnchor = BuildComponentSelfAnchor(isFontString, isAuraContainer, anchorY, justifyH)
    container:SetPoint(selfAnchor, preview, anchorPoint, finalX, finalY)

    if isFontString and container.visual then ApplyTextAlignment(container, container.visual, justifyH) end
end

-- [ DRAG HANDLERS ]---------------------------------------------------------------------------------

local function SetupDragHandlers(container, preview, key, data)
    local function StartDrag(self)
        if InCombatLockdown() then return end
        self.wasDragged = true
        self.pendingDrag = false
        local mX, mY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mX, mY = Orbit.Engine.Pixel:Snap(mX / scale, scale), Orbit.Engine.Pixel:Snap(mY / scale, scale)
        local parentCenterX, parentCenterY = preview:GetCenter()
        local zoomLevel = Dialog.zoomLevel or 1
        self.dragGripX = (parentCenterX + (self.posX or 0) * zoomLevel) - mX
        self.dragGripY = (parentCenterY + (self.posY or 0) * zoomLevel) - mY
        self.isDragging = true
        SetBorderColor(self.border, CC.BORDER_COLOR_DRAG)
    end

    container:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.mouseDownTime = GetTime()
        self.wasDragged = false
        self.pendingDrag = true
        local mx, my = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self.mouseDownX = Orbit.Engine.Pixel:Snap(mx / scale, scale)
        self.mouseDownY = Orbit.Engine.Pixel:Snap(my / scale, scale)
    end)

    container:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        self.pendingDrag = false
        if self.isDragging then
            self.isDragging = false
            SetBorderColor(self.border, CC.BORDER_COLOR_IDLE)
            if SmartGuides and preview.guides then SmartGuides:Hide(preview.guides) end
            Dialog.DisabledDock.DropHighlight:Hide()
        elseif not self.wasDragged and self.mouseDownTime then
            if (GetTime() - self.mouseDownTime) < CLICK_THRESHOLD then
                if OrbitEngine.CanvasComponentSettings then
                    OrbitEngine.CanvasComponentSettings:Open(self.key, self, Dialog.targetPlugin, Dialog.targetSystemIndex)
                end
            end
        end
        self.mouseDownTime = nil
        self.mouseDownX = nil
        self.mouseDownY = nil
    end)

    container:SetScript("OnDragStart", function(self)
        if not self.isDragging and not self.wasDragged then StartDrag(self) end
    end)

    container:SetScript("OnUpdate", function(self)
        if self.pendingDrag and self.mouseDownX and self.mouseDownY then
            local mX, mY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            mX, mY = Orbit.Engine.Pixel:Snap(mX / scale, scale), Orbit.Engine.Pixel:Snap(mY / scale, scale)
            if math.abs(mX - self.mouseDownX) > DRAG_THRESHOLD or math.abs(mY - self.mouseDownY) > DRAG_THRESHOLD then
                StartDrag(self)
            end
        end

        if not self.isDragging then return end

        local halfW = preview.sourceWidth / 2
        local halfH = preview.sourceHeight / 2
        local mX, mY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mX, mY = Orbit.Engine.Pixel:Snap(mX / scale, scale), Orbit.Engine.Pixel:Snap(mY / scale, scale)

        local targetWorldX = mX + (self.dragGripX or 0)
        local targetWorldY = mY + (self.dragGripY or 0)
        local parentCenterX, parentCenterY = preview:GetCenter()
        local zoomLevel = Dialog.zoomLevel or 1
        local centerRelX = (targetWorldX - parentCenterX) / zoomLevel
        local centerRelY = (targetWorldY - parentCenterY) / zoomLevel

        centerRelX = math.max(-halfW - CLAMP_PADDING_X, math.min(halfW + CLAMP_PADDING_X, centerRelX))
        centerRelY = math.max(-halfH - CLAMP_PADDING_Y, math.min(halfH + CLAMP_PADDING_Y, centerRelY))

        local snapX, snapY
        local compHalfW = (self:GetWidth() or DEFAULT_COMP_WIDTH) / 2
        local compHalfH = (self:GetHeight() or DEFAULT_COMP_HEIGHT) / 2

        if not IsShiftKeyDown() then
            local rightEdge = halfW - compHalfW
            local leftEdge = -halfW + compHalfW
            local distR = math.abs(centerRelX - rightEdge)
            local distL = math.abs(centerRelX - leftEdge)

            if distR <= EDGE_THRESHOLD and centerRelX <= rightEdge then centerRelX = rightEdge; snapX = "RIGHT"
            elseif distL <= EDGE_THRESHOLD and centerRelX >= leftEdge then centerRelX = leftEdge; snapX = "LEFT"
            elseif math.abs(centerRelX) <= EDGE_THRESHOLD then centerRelX = 0; snapX = "CENTER"
            elseif centerRelX > rightEdge then snapX = "RIGHT"
            elseif centerRelX < leftEdge then snapX = "LEFT" end
            if not snapX then centerRelX = OrbitEngine.Pixel:Snap(math.floor(centerRelX / SNAP_SIZE + 0.5) * SNAP_SIZE, scale) end

            local topEdge = halfH - compHalfH
            local bottomEdge = -halfH + compHalfH
            local distT = math.abs(centerRelY - topEdge)
            local distB = math.abs(centerRelY - bottomEdge)

            if distT <= EDGE_THRESHOLD and centerRelY <= topEdge then centerRelY = topEdge; snapY = "TOP"
            elseif distB <= EDGE_THRESHOLD and centerRelY >= bottomEdge then centerRelY = bottomEdge; snapY = "BOTTOM"
            elseif math.abs(centerRelY) <= EDGE_THRESHOLD then centerRelY = 0; snapY = "CENTER"
            elseif centerRelY > topEdge then snapY = "TOP"
            elseif centerRelY < bottomEdge then snapY = "BOTTOM" end
            if not snapY then centerRelY = OrbitEngine.Pixel:Snap(math.floor(centerRelY / SNAP_SIZE + 0.5) * SNAP_SIZE, scale) end
        end

        local needsWidthComp = NeedsEdgeCompensation(self.isFontString, self.isAuraContainer)
        local anchorX, anchorY, edgeOffX, edgeOffY, justifyH =
            CalculateAnchorWithWidthCompensation(centerRelX, centerRelY, halfW, halfH, needsWidthComp, self:GetWidth(), self:GetHeight(), self.isAuraContainer)

        if SmartGuides and preview.guides then SmartGuides:Update(preview.guides, snapX, snapY, preview.sourceWidth, preview.sourceHeight) end
        if self.isFontString and self.visual then ApplyTextAlignment(self, self.visual, justifyH) end

        self:ClearAllPoints()
        self:SetPoint("CENTER", preview, "CENTER", centerRelX, centerRelY)

        local prevAnchorX, prevAnchorY, prevJustifyH = self.anchorX, self.anchorY, self.justifyH
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.offsetX = edgeOffX
        self.offsetY = edgeOffY
        self.justifyH = justifyH
        self.posX = centerRelX
        self.posY = centerRelY

        if self.isAuraContainer and self.RefreshAuraIcons and (prevAnchorX ~= anchorX or prevAnchorY ~= anchorY or prevJustifyH ~= justifyH) then
            self:RefreshAuraIcons()
        end

        Dialog.DisabledDock.DropHighlight:SetShown(Dialog.DisabledDock:IsMouseOver())

        if OrbitEngine.SelectionTooltip then
            OrbitEngine.SelectionTooltip:ShowComponentPosition(self, key, anchorX, anchorY, centerRelX, centerRelY, edgeOffX, edgeOffY, justifyH)
        end
    end)

    container:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self.dragStartLocalX = nil
        self.dragStartLocalY = nil
        SetBorderColor(self.border, CC.BORDER_COLOR_IDLE)
        Dialog.DisabledDock.DropHighlight:Hide()

        if SmartGuides and preview.guides then SmartGuides:Hide(preview.guides) end

        if Dialog.DisabledDock:IsMouseOver() then
            local compKey = self.key
            self:Hide()
            self:SetParent(nil)
            Dialog.previewComponents[compKey] = nil
            Dialog:AddToDock(compKey, data and data.component)
            return
        end

        local scale = UIParent:GetEffectiveScale()
        self.posX = OrbitEngine.Pixel:Snap(math.floor((self.posX or 0) / SNAP_GRID + 0.5) * SNAP_GRID, scale)
        self.posY = OrbitEngine.Pixel:Snap(math.floor((self.posY or 0) / SNAP_GRID + 0.5) * SNAP_GRID, scale)
        self.offsetX = OrbitEngine.Pixel:Snap(math.floor((self.offsetX or 0) / SNAP_GRID + 0.5) * SNAP_GRID, scale)
        self.offsetY = OrbitEngine.Pixel:Snap(math.floor((self.offsetY or 0) / SNAP_GRID + 0.5) * SNAP_GRID, scale)

        self:ClearAllPoints()
        self:SetPoint("CENTER", preview, "CENTER", self.posX, self.posY)

        if self.visual and self.isFontString then ApplyTextAlignment(self, self.visual, self.justifyH or "CENTER") end
    end)
end

-- [ HOVER ]-----------------------------------------------------------------------------------------

local function SetupHoverEffects(container)
    container:SetScript("OnEnter", function(self)
        SetBorderColor(self.border, CC.BORDER_COLOR_HOVER)
        Dialog.hoveredComponent = self
    end)
    container:SetScript("OnLeave", function(self)
        SetBorderColor(self.border, CC.BORDER_COLOR_IDLE)
        if Dialog.hoveredComponent == self then Dialog.hoveredComponent = nil end
    end)
end

-- [ OVERRIDES ]-------------------------------------------------------------------------------------

local function ApplyExistingOverrides(container)
    if container.existingOverrides and OrbitEngine.CanvasComponentSettings and OrbitEngine.CanvasComponentSettings.ApplyAll then
        OrbitEngine.CanvasComponentSettings:ApplyAll(container, container.existingOverrides)
    end
end

-- [ DISPATCHER ]------------------------------------------------------------------------------------

local function CreateDraggableComponent(preview, key, sourceComponent, startX, startY, data)
    local container = CreateFrame("Frame", nil, preview)
    container:SetSize(100, 20)
    container:EnableMouse(true)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")

    local creatorType, isFontString, isAuraContainer = DetectCreatorType(key, sourceComponent)
    local creator = creatorType and CanvasMode.ComponentCreators[creatorType]

    local visual = creator
        and creator(container, preview, key, sourceComponent, data)
        or CreateFallbackVisual(container, key)

    container.visual = visual
    SetupContainerState(container, preview, key, isFontString, isAuraContainer, startX, startY, data)
    SetupDragHandlers(container, preview, key, data)
    SetupHoverEffects(container)
    ApplyExistingOverrides(container)
    return container
end

CanvasMode.CreateDraggableComponent = CreateDraggableComponent
