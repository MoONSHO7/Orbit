-- [ CANVAS MODE DRAG ]-------------------------------------------------------------------------------
local _, Orbit = ...
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
local AnchorOffsetsToFinal = OrbitEngine.PositionUtils.AnchorOffsetsToFinal
local SmartGuides = OrbitEngine.SmartGuides
local SnapEngine = CanvasMode.SnapEngine
local ApplyTextAlignment = CanvasMode.ApplyTextAlignment
local SetBorderColor = CanvasMode.SetBorderColor

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local DRAG_THRESHOLD = 3
local CLICK_THRESHOLD = 0.3
local CLAMP_PADDING_X = 200
local CLAMP_PADDING_Y = 200
local DEFAULT_CONTAINER_WIDTH = 100
local DEFAULT_CONTAINER_HEIGHT = 20
local SNAP_OPTIONS = { edgeThreshold = SnapEngine.EDGE_THRESHOLD, gridSize = SnapEngine.SNAP_SIZE }
local PRECISION_OPTIONS = { precisionMode = true }

-- [ TYPE DETECTION ]---------------------------------------------------------------------------------
local AURA_ICON_KEYS = { DefensiveIcon = true, CrowdControlIcon = true, PrivateAuraAnchor = true }
local STANDARD_ICON_KEYS =
    { MarkerIcon = true, MainTankIcon = true, RestingIcon = true, Difficulty = true, DifficultyIcon = true, Mail = true, CraftingOrder = true, Compartment = true, Zoom = true }

local function DetectCreatorType(key, source)
    local isFontString = source and source.GetFont ~= nil
    local isTexture = source and source.GetTexture ~= nil and not isFontString
    local isIconFrame = source and source.Icon and source.Icon.GetTexture and key ~= "CastBar"

    if isFontString then return "FontString", true, false, false end
    if key == "StatusIcons" or key == "RoleIcon" or key == "LeaderIcon" or key == "Missions" or key == "PvpIcon" then return "CyclingAtlas", false, false, false end
    if key == "Buffs" or key == "Debuffs" then return "Aura", false, true, false end
    -- Known aura icons + healer aura keys (dynamic keys not in standard icon sets)
    local isAuraKey = AURA_ICON_KEYS[key] or (isIconFrame and not STANDARD_ICON_KEYS[key])
    if isTexture then return "Texture", false, false, false end
    if isIconFrame then return "IconFrame", false, isAuraKey or false, false end
    if key == "Portrait" then return "Portrait", false, false, false end
    if key == "CastBar" then return "CastBar", false, false, false end
    return nil, false, false, false
end

-- [ FALLBACK VISUAL ]--------------------------------------------------------------------------------
local function CreateFallbackVisual(container, key)
    local visual = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visual:SetAllPoints()
    visual:SetWordWrap(false)
    visual:SetText(key and key:sub(1, 4) or "?")
    container:SetSize(CC.FALLBACK_CONTAINER_WIDTH, CC.FALLBACK_CONTAINER_HEIGHT)
    return visual
end

-- [ CONTAINER STATE ]--------------------------------------------------------------------------------
local function SetupContainerState(container, preview, key, isFontString, isAuraContainer, startX, startY, data)
    container.border = container:CreateTexture(nil, "BACKGROUND")
    container.border:SetAllPoints()
    SetBorderColor(container.border, CC.BORDER_COLOR_IDLE)

    container.posX = container.posX or startX
    container.posY = container.posY or startY
    container.key = key
    container.isFontString = isFontString
    container.isAuraContainer = isAuraContainer
    container.existingOverrides = data and data.overrides

    local borderInset = preview.borderInset or 0
    local halfW = preview.sourceWidth / 2 - borderInset
    local halfH = preview.sourceHeight / 2 - borderInset
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
    local finalX, finalY = AnchorOffsetsToFinal(anchorX, anchorY, offsetX, offsetY, startX, startY)

    local selfAnchorY = (data and data.selfAnchorY) or anchorY
    if not (data and data.selfAnchorY) and isAuraContainer and data and data.anchorX then
        local needsComp = NeedsEdgeCompensation(isFontString, isAuraContainer) _, _, _, _, _, selfAnchorY =
            CalculateAnchorWithWidthCompensation(startX, startY, halfW, halfH, needsComp, container:GetWidth(), container:GetHeight(), isAuraContainer)
    end
    container.selfAnchorY = selfAnchorY

    container:ClearAllPoints()
    local selfAnchor = BuildComponentSelfAnchor(isFontString, isAuraContainer, selfAnchorY, justifyH)
    container:SetPoint(selfAnchor, preview, anchorPoint, finalX, finalY)

    if isFontString and container.visual then ApplyTextAlignment(container, container.visual, justifyH) end
end

-- [ DRAG HANDLERS ]----------------------------------------------------------------------------------
local function SetupDragHandlers(container, preview, key, data)
    local function StartDrag(self)
        if InCombatLockdown() then return end
        self.wasDragged = true
        self.pendingDrag = false
        self._preDragPos = { posX = self.posX, posY = self.posY, anchorX = self.anchorX, anchorY = self.anchorY, offsetX = self.offsetX, offsetY = self.offsetY, selfAnchorY = self.selfAnchorY, justifyH = self.justifyH }
        local mX, mY = GetCursorPosition()
        local scale = self._dragScale or UIParent:GetEffectiveScale()
        self._dragScale = scale
        local mx, my = mX / scale, mY / scale
        local parentCenterX, parentCenterY = preview:GetCenter()
        local zoomLevel = Dialog.zoomLevel or 1
        self.dragGripX = (parentCenterX + (self.posX or 0) * zoomLevel) - mx
        self.dragGripY = (parentCenterY + (self.posY or 0) * zoomLevel) - my
        self.isDragging = true
        SetBorderColor(self.border, CC.BORDER_COLOR_DRAG)
    end

    local function DragUpdate(self)
        local mX, mY = GetCursorPosition()
        local scale = self._dragScale
        local mx, my = mX / scale, mY / scale

        if self.pendingDrag and not self.isDragging then
            if math.abs(mx - self.mouseDownX) > DRAG_THRESHOLD or math.abs(my - self.mouseDownY) > DRAG_THRESHOLD then
                StartDrag(self)
            else
                return
            end
        end
        if not self.isDragging then return end

        local halfW = preview.sourceWidth / 2
        local halfH = preview.sourceHeight / 2
        local borderInset = preview.borderInset or 0
        local innerHalfW = halfW - borderInset
        local innerHalfH = halfH - borderInset

        local targetWorldX = mx + (self.dragGripX or 0)
        local targetWorldY = my + (self.dragGripY or 0)
        local parentCenterX, parentCenterY = preview:GetCenter()
        local zoomLevel = Dialog.zoomLevel or 1
        local centerRelX = (targetWorldX - parentCenterX) / zoomLevel
        local centerRelY = (targetWorldY - parentCenterY) / zoomLevel

        centerRelX = math.max(-halfW - CLAMP_PADDING_X, math.min(halfW + CLAMP_PADDING_X, centerRelX))
        centerRelY = math.max(-halfH - CLAMP_PADDING_Y, math.min(halfH + CLAMP_PADDING_Y, centerRelY))

        local compHalfW = self:GetWidth() / 2
        local compHalfH = self:GetHeight() / 2
        local doSnap = not IsShiftKeyDown()
        local snapOpts = doSnap and SNAP_OPTIONS or PRECISION_OPTIONS
        local snapX, snapY
        centerRelX, centerRelY, snapX, snapY = SnapEngine:Calculate(centerRelX, centerRelY, innerHalfW, innerHalfH, compHalfW, compHalfH, snapOpts)

        local needsWidthComp = NeedsEdgeCompensation(self.isFontString, self.isAuraContainer)
        local anchorX, anchorY, edgeOffX, edgeOffY, justifyH, selfAnchorY = CalculateAnchorWithWidthCompensation(
            centerRelX, centerRelY, innerHalfW, innerHalfH, needsWidthComp,
            self:GetWidth(), self:GetHeight(), self.isAuraContainer
        )

        -- Mismatched parities between preview and container widths can leave edge offsets fractional.
        if doSnap then
            local g = SnapEngine.SNAP_SIZE
            edgeOffX = math.floor(edgeOffX / g + 0.5) * g
            edgeOffY = math.floor(edgeOffY / g + 0.5) * g
        end

        if SmartGuides and preview.guides then SmartGuides:Update(preview.guides, snapX, snapY, preview.sourceWidth, preview.sourceHeight) end
        if self.isFontString and self.visual then ApplyTextAlignment(self, self.visual, justifyH) end

        self:ClearAllPoints()
        local selfAnchor = BuildComponentSelfAnchor(self.isFontString, self.isAuraContainer, selfAnchorY, justifyH)
        local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
        local finalX, finalY = AnchorOffsetsToFinal(anchorX, anchorY, edgeOffX, edgeOffY, centerRelX, centerRelY)
        self:SetPoint(selfAnchor, preview, anchorPoint, finalX, finalY)

        local prevAnchorX, prevAnchorY, prevJustifyH, prevSelfAnchorY = self.anchorX, self.anchorY, self.justifyH, self.selfAnchorY
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.selfAnchorY = selfAnchorY
        self.offsetX = edgeOffX
        self.offsetY = edgeOffY
        self.justifyH = justifyH
        self.posX = centerRelX
        self.posY = centerRelY

        if self.isAuraContainer and self.RefreshAuraIcons
            and (prevAnchorX ~= anchorX or prevAnchorY ~= anchorY or prevJustifyH ~= justifyH or prevSelfAnchorY ~= selfAnchorY)
        then
            self:RefreshAuraIcons()
        end

        Dialog.DisabledDock.DropHighlight:SetShown(Dialog.DisabledDock:IsMouseOver())
        OrbitEngine.SelectionTooltip:ShowComponentPosition(self, key, anchorX, anchorY, centerRelX, centerRelY, edgeOffX, edgeOffY, justifyH, selfAnchorY)
    end

    container:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self._dragScale = UIParent:GetEffectiveScale()
        local mX, mY = GetCursorPosition()
        self.mouseDownTime = GetTime()
        self.mouseDownX = mX / self._dragScale
        self.mouseDownY = mY / self._dragScale
        self.wasDragged = false
        self.pendingDrag = true
        self:SetScript("OnUpdate", DragUpdate)
    end)

    container:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        self:SetScript("OnUpdate", nil)
        self.pendingDrag = false
        if self.isDragging then
            self.isDragging = false
            SetBorderColor(self.border, CC.BORDER_COLOR_IDLE)
            if SmartGuides and preview.guides then SmartGuides:Hide(preview.guides) end
            Dialog.DisabledDock.DropHighlight:Hide()
            CanvasMode.Transaction:StagePositionFromContainer(self)
        elseif not self.wasDragged and self.mouseDownTime then
            if (GetTime() - self.mouseDownTime) < CLICK_THRESHOLD then
                OrbitEngine.CanvasComponentSettings:Open(self.key, self, Dialog.targetPlugin, Dialog.targetSystemIndex)
            end
        end
        self.mouseDownTime = nil
        self.mouseDownX = nil
        self.mouseDownY = nil
        self._dragScale = nil
    end)

    container:SetScript("OnDragStart", function(self)
        if not self.isDragging and self.pendingDrag then StartDrag(self) end
    end)

    container:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.isDragging = false
        SetBorderColor(self.border, CC.BORDER_COLOR_IDLE)
        Dialog.DisabledDock.DropHighlight:Hide()

        if SmartGuides and preview.guides then SmartGuides:Hide(preview.guides) end

        if Dialog.DisabledDock:IsMouseOver() then
            local compKey = self.key
            self:Hide()
            Dialog.previewComponents[compKey] = nil
            Dialog:AddToDock(compKey, data and data.component)
            if Dialog.dockComponents[compKey] then
                Dialog.dockComponents[compKey].storedDraggableComp = self
            end
            return
        end

        self:ClearAllPoints()
        local selfAnchor = BuildComponentSelfAnchor(self.isFontString, self.isAuraContainer, self.selfAnchorY, self.justifyH)
        local anchorPoint = BuildAnchorPoint(self.anchorX, self.anchorY)
        local fx, fy = AnchorOffsetsToFinal(self.anchorX, self.anchorY, self.offsetX, self.offsetY, self.posX, self.posY)
        self:SetPoint(selfAnchor, preview, anchorPoint, fx, fy)

        if self.visual and self.isFontString then ApplyTextAlignment(self, self.visual, self.justifyH or "CENTER") end

        CanvasMode.Transaction:StagePositionFromContainer(self)
    end)
end

-- [ HOVER ]------------------------------------------------------------------------------------------
local function SetupHoverEffects(container)
    container:SetScript("OnEnter", function(self)
        SetBorderColor(self.border, CC.BORDER_COLOR_HOVER)
        Dialog.hoveredComponent = self
    end)
    container:SetScript("OnLeave", function(self)
        SetBorderColor(self.border, CC.BORDER_COLOR_IDLE)
        if Dialog.hoveredComponent == self then
            Dialog.hoveredComponent = nil
        end
    end)
end

-- [ OVERRIDES ]--------------------------------------------------------------------------------------
local function ApplyExistingOverrides(container)
    if container.existingOverrides and OrbitEngine.CanvasComponentSettings and OrbitEngine.CanvasComponentSettings.ApplyAll then
        OrbitEngine.CanvasComponentSettings:ApplyAll(container, container.existingOverrides)
    end
end

-- [ DISPATCHER ]-------------------------------------------------------------------------------------
local function CreateDraggableComponent(preview, key, sourceComponent, startX, startY, data)
    local container = CreateFrame("Frame", nil, preview)
    container:SetSize(DEFAULT_CONTAINER_WIDTH, DEFAULT_CONTAINER_HEIGHT)
    container:EnableMouse(true)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")

    local creatorType, isFontString, isAuraContainer = DetectCreatorType(key, sourceComponent)
    local creator = creatorType and CanvasMode.ComponentCreators[creatorType]

    local visual = creator and creator(container, preview, key, sourceComponent, data) or CreateFallbackVisual(container, key)
    if container.isFontString ~= nil then isFontString = container.isFontString end
    if container.isAuraContainer ~= nil then isAuraContainer = container.isAuraContainer end

    if not container.skipSourceSizeRestore and sourceComponent and sourceComponent.orbitOriginalWidth then
        container:SetSize(sourceComponent.orbitOriginalWidth, sourceComponent.orbitOriginalHeight or sourceComponent.orbitOriginalWidth)
    end

    container.visual = visual
    SetupContainerState(container, preview, key, isFontString, isAuraContainer, startX, startY, data)
    SetupDragHandlers(container, preview, key, data)
    SetupHoverEffects(container)
    -- Order matters: Scale/IconSize handlers cache the container's post-anchor size on first call.
    ApplyExistingOverrides(container)
    return container
end

CanvasMode.CreateDraggableComponent = CreateDraggableComponent
