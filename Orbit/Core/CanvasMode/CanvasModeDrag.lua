-- [ CANVAS MODE DRAG ]------------------------------------------------------------------------------

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

local SNAP_SIZE = OrbitEngine.CanvasMode.SnapEngine.SNAP_SIZE
local DRAG_THRESHOLD = 3
local CLICK_THRESHOLD = 0.3
local CLAMP_PADDING_X = 200
local CLAMP_PADDING_Y = 200

-- [ TYPE DETECTION ]--------------------------------------------------------------------------------

local AURA_ICON_KEYS = { DefensiveIcon = true, CrowdControlIcon = true, PrivateAuraAnchor = true }
local STANDARD_ICON_KEYS =
    { MarkerIcon = true, LeaderIcon = true, MainTankIcon = true, Difficulty = true, Mail = true, CraftingOrder = true, Compartment = true, Zoom = true }

local function DetectCreatorType(key, source)
    local isFontString = source and source.GetFont ~= nil
    local isTexture = source and source.GetTexture ~= nil and not isFontString
    local isIconFrame = source and source.Icon and source.Icon.GetTexture and key ~= "CastBar"

    if isFontString then return "FontString", true, false, false end
    if key == "StatusIcons" or key == "RoleIcon" or key == "Missions" or key == "PvpIcon" then return "CyclingAtlas", false, false, false end
    if key == "Buffs" or key == "Debuffs" then return "Aura", false, true, false end
    -- Known aura icons + healer aura keys (dynamic keys not in standard icon sets)
    local isAuraKey = AURA_ICON_KEYS[key] or (isIconFrame and not STANDARD_ICON_KEYS[key])
    if isTexture then return "Texture", false, false, false end
    if isIconFrame then return "IconFrame", false, isAuraKey or false, false end
    if key == "Portrait" then return "Portrait", false, false, false end
    if key == "CastBar" then return "CastBar", false, false, false end
    return nil, false, false, false
end

-- [ FALLBACK VISUAL ]-------------------------------------------------------------------------------

local function CreateFallbackVisual(container, key)
    local visual = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visual:SetAllPoints()
    visual:SetWordWrap(false)
    visual:SetText(key and key:sub(1, 4) or "?")
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
    local finalX = anchorX == "CENTER" and startX or (anchorX == "RIGHT" and -offsetX or offsetX)
    local finalY = anchorY == "CENTER" and startY or (anchorY == "TOP" and -offsetY or offsetY)

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

-- [ DRAG HANDLERS ]---------------------------------------------------------------------------------

local function SetupDragHandlers(container, preview, key, data)
    local function StartDrag(self)
        if InCombatLockdown() then return end
        self.wasDragged = true
        self.pendingDrag = false
        -- Snapshot pre-drag position for dock restore
        self._preDragPos = { posX = self.posX, posY = self.posY, anchorX = self.anchorX, anchorY = self.anchorY, offsetX = self.offsetX, offsetY = self.offsetY, selfAnchorY = self.selfAnchorY, justifyH = self.justifyH, }
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
            -- Stage position into transaction for live preview updates
            if CanvasMode.Transaction and CanvasMode.Transaction:IsActive() and self.key then
                local pos = { anchorX = self.anchorX, anchorY = self.anchorY, offsetX = self.offsetX, offsetY = self.offsetY, justifyH = self.justifyH, selfAnchorY = self.selfAnchorY, posX = self.posX, posY = self.posY, }
                CanvasMode.Transaction:SetPosition(self.key, pos)
            end
        elseif not self.wasDragged and self.mouseDownTime then
            if (GetTime() - self.mouseDownTime) < CLICK_THRESHOLD then
                OrbitEngine.CanvasComponentSettings:Open(self.key, self, Dialog.targetPlugin, Dialog.targetSystemIndex)
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

        if not self.isDragging then
            return
        end

        local halfW = preview.sourceWidth / 2
        local halfH = preview.sourceHeight / 2
        local borderInset = preview.borderInset or 0
        local innerHalfW = halfW - borderInset
        local innerHalfH = halfH - borderInset
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
        local doSnap = not IsShiftKeyDown()

        -- Snap center-relative position first, then derive anchors/offsets from snapped values
        if doSnap then
            centerRelX = math.floor(centerRelX / SNAP_SIZE + 0.5) * SNAP_SIZE
            centerRelY = math.floor(centerRelY / SNAP_SIZE + 0.5) * SNAP_SIZE
        end

        -- Compute anchors and offsets using inner bounds (content area inside borders)
        local needsWidthComp = NeedsEdgeCompensation(self.isFontString, self.isAuraContainer)
        local anchorX, anchorY, edgeOffX, edgeOffY, justifyH, selfAnchorY = CalculateAnchorWithWidthCompensation(
            centerRelX,
            centerRelY,
            innerHalfW,
            innerHalfH,
            needsWidthComp,
            self:GetWidth(),
            self:GetHeight(),
            self.isAuraContainer
        )

        -- Snap edge offsets to grid (derived from already-snapped position, so minimal rounding)
        if doSnap then
            edgeOffX = math.floor(edgeOffX / SNAP_SIZE + 0.5) * SNAP_SIZE
            edgeOffY = math.floor(edgeOffY / SNAP_SIZE + 0.5) * SNAP_SIZE

            -- Edge/center guide detection using inner bounds
            local rightEdge = innerHalfW - compHalfW
            local leftEdge = -innerHalfW + compHalfW
            if edgeOffX == 0 and anchorX ~= "CENTER" then
                snapX = (anchorX == "RIGHT") and "RIGHT" or "LEFT"
            elseif centerRelX == 0 or math.abs(centerRelX) < SNAP_SIZE then
                snapX = "CENTER"
                centerRelX = 0
                edgeOffX = 0
            elseif centerRelX > rightEdge then
                snapX = "RIGHT"
            elseif centerRelX < leftEdge then
                snapX = "LEFT"
            end

            local topEdge = innerHalfH - compHalfH
            local bottomEdge = -innerHalfH + compHalfH
            if edgeOffY == 0 and anchorY ~= "CENTER" then snapY = (anchorY == "TOP") and "TOP" or "BOTTOM"
            elseif centerRelY == 0 or math.abs(centerRelY) < SNAP_SIZE then snapY = "CENTER" centerRelY = 0 edgeOffY = 0
            elseif centerRelY > topEdge then snapY = "TOP"
            elseif centerRelY < bottomEdge then snapY = "BOTTOM"
            end
        end

        if SmartGuides and preview.guides then SmartGuides:Update(preview.guides, snapX, snapY, preview.sourceWidth, preview.sourceHeight) end
        if self.isFontString and self.visual then ApplyTextAlignment(self, self.visual, justifyH) end

        self:ClearAllPoints()
        local selfAnchor = BuildComponentSelfAnchor(self.isFontString, self.isAuraContainer, selfAnchorY, justifyH)
        local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
        local finalX, finalY
        if anchorX == "CENTER" then finalX = centerRelX
        else finalX = edgeOffX if anchorX == "RIGHT" then finalX = -finalX end
        end
        if anchorY == "CENTER" then finalY = centerRelY
        else finalY = edgeOffY if anchorY == "TOP" then finalY = -finalY end
        end
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

        if
            self.isAuraContainer
            and self.RefreshAuraIcons
            and (prevAnchorX ~= anchorX or prevAnchorY ~= anchorY or prevJustifyH ~= justifyH or prevSelfAnchorY ~= selfAnchorY)
        then
            self:RefreshAuraIcons()
        end

        Dialog.DisabledDock.DropHighlight:SetShown(Dialog.DisabledDock:IsMouseOver())

        OrbitEngine.SelectionTooltip:ShowComponentPosition(self, key, anchorX, anchorY, centerRelX, centerRelY, edgeOffX, edgeOffY, justifyH, selfAnchorY)
    end)

    container:SetScript("OnDragStop", function(self)
        self.isDragging = false
        SetBorderColor(self.border, CC.BORDER_COLOR_IDLE)
        Dialog.DisabledDock.DropHighlight:Hide()

        if SmartGuides and preview.guides then
            SmartGuides:Hide(preview.guides)
        end

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
        local fx, fy
        if self.anchorX == "CENTER" then
            fx = self.posX or 0
        else
            fx = self.offsetX or 0
            if self.anchorX == "RIGHT" then fx = -fx end
        end
        if self.anchorY == "CENTER" then
            fy = self.posY or 0
        else
            fy = self.offsetY or 0
            if self.anchorY == "TOP" then fy = -fy end
        end
        self:SetPoint(selfAnchor, preview, anchorPoint, fx, fy)

        if self.visual and self.isFontString then ApplyTextAlignment(self, self.visual, self.justifyH or "CENTER") end

        -- Stage position into transaction for live preview updates
        if CanvasMode.Transaction and CanvasMode.Transaction:IsActive() then
            local pos = {
                anchorX = self.anchorX,
                anchorY = self.anchorY,
                offsetX = self.offsetX,
                offsetY = self.offsetY,
                justifyH = self.justifyH,
                selfAnchorY = self.selfAnchorY,
                posX = self.posX,
                posY = self.posY,
            }
            CanvasMode.Transaction:SetPosition(key, pos)
        end
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
        if Dialog.hoveredComponent == self then
            Dialog.hoveredComponent = nil
        end
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

    local visual = creator and creator(container, preview, key, sourceComponent, data) or CreateFallbackVisual(container, key)

    if sourceComponent and sourceComponent.orbitOriginalWidth then
        container:SetSize(sourceComponent.orbitOriginalWidth, sourceComponent.orbitOriginalHeight or sourceComponent.orbitOriginalWidth)
    end

    container.visual = visual
    SetupContainerState(container, preview, key, isFontString, isAuraContainer, startX, startY, data)
    SetupDragHandlers(container, preview, key, data)
    SetupHoverEffects(container)
    ApplyExistingOverrides(container)
    return container
end

CanvasMode.CreateDraggableComponent = CreateDraggableComponent
