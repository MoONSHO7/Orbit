-- [ CANVAS MODE - DRAG COMPONENT ]------------------------------------------------------
-- Draggable component creation and interaction handlers for Canvas Mode
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

-- SmartGuides for visual snap feedback
local SmartGuides = OrbitEngine.SmartGuides

-- [ CONSTANTS ]--------------------------------------------------------------------------

local SNAP_SIZE = 5
local EDGE_THRESHOLD = 3

-- [ TEXT ALIGNMENT ]---------------------------------------------------------------------

local function ApplyTextAlignment(container, visual, justifyH)
    visual:ClearAllPoints()
    visual:SetPoint(justifyH, container, justifyH, 0, 0)
    visual:SetJustifyH(justifyH)
end

-- Export for other modules
CanvasMode.ApplyTextAlignment = ApplyTextAlignment

-- [ SPRITE SHEET HELPER ]----------------------------------------------------------------

local function ApplySpriteSheetCell(texture, index, rows, cols)
    if not texture or not index then
        return
    end
    rows = rows or 4
    cols = cols or 4

    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    local width = 1 / cols
    local height = 1 / rows
    local left = col * width
    local right = left + width
    local top = row * height
    local bottom = top + height

    texture:SetTexCoord(left, right, top, bottom)
end

-- [ PREVIEW FALLBACK VALUES ]------------------------------------------------------------

local PREVIEW_TEXT_VALUES = {
    Name = "Name",
    HealthText = "100%",
    LevelText = "80",
    GroupPositionText = "G1",
    PowerText = "100%",
    Text = "100",
    Keybind = "Q",
}

local PREVIEW_TEXT_COLORS = {
    LevelText = { 1.0, 0.82, 0.0 },
}

-- [ CREATE DRAGGABLE COMPONENT ]---------------------------------------------------------

local function CreateDraggableComponent(preview, key, sourceComponent, startX, startY, data)
    local container = CreateFrame("Frame", nil, preview)
    container:SetSize(100, 20)
    container:EnableMouse(true)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")

    local visual
    local isFontString = sourceComponent and sourceComponent.GetFont ~= nil
    local isTexture = sourceComponent and sourceComponent.GetTexture ~= nil and not isFontString
    local isIconFrame = sourceComponent and sourceComponent.Icon and sourceComponent.Icon.GetTexture

    if isFontString then
        visual = container:CreateFontString(nil, "OVERLAY")

        local fontPath, fontSize, fontFlags = sourceComponent:GetFont()
        local flags = (fontFlags and fontFlags ~= "") and fontFlags or Orbit.Skin:GetFontOutline()
        if fontPath and fontSize then
            visual:SetFont(fontPath, fontSize, flags)
        else
            local globalFontName = Orbit.db.GlobalSettings.Font
            local fallbackPath = LSM:Fetch("font", globalFontName) or Orbit.Constants.Settings.Font.FallbackPath
            local fallbackSize = Orbit.Constants.UI.UnitFrameTextSize or 12
            visual:SetFont(fallbackPath, fallbackSize, Orbit.Skin:GetFontOutline())
        end

        local text = PREVIEW_TEXT_VALUES[key] or "Text"
        local ok, t = pcall(function() return sourceComponent:GetText() end)
        if ok and t and type(t) == "string" and (not issecretvalue or not issecretvalue(t)) and t ~= "" then
            text = t
        end
        visual:SetText(text)

        local r, g, b, a = sourceComponent:GetTextColor()
        local fallback = PREVIEW_TEXT_COLORS[key]
        if fallback and r and r > 0.95 and g > 0.95 and b > 0.95 then
            visual:SetTextColor(fallback[1], fallback[2], fallback[3], 1)
        elseif r then
            visual:SetTextColor(r, g, b, a or 1)
        end

        local sr, sg, sb, sa = sourceComponent:GetShadowColor()
        if sr then
            visual:SetShadowColor(sr, sg, sb, sa or 1)
        end
        local sx, sy = sourceComponent:GetShadowOffset()
        if sx then
            visual:SetShadowOffset(sx, sy)
        end

        -- Auto-size container to tightly fit text (minimal footprint)
        local text = visual:GetText() or ""
        local fontSize = select(2, visual:GetFont()) or 12
        -- Maximum reasonable width: 0.8 * fontSize * charCount (accounts for wide chars)
        local maxReasonableWidth = fontSize * #text * 0.8
        -- Tight fallback: ~0.55 per character for most fonts
        local textWidth = fontSize * #text * 0.55
        local textHeight = fontSize
        local ok, w = pcall(function() return visual:GetStringWidth() end)
        if ok and w and type(w) == "number" and w > 0 and w <= maxReasonableWidth * 2 and (not issecretvalue or not issecretvalue(w)) then
            textWidth = w
        end
        local ok2, h = pcall(function() return visual:GetStringHeight() end)
        if ok2 and h and type(h) == "number" and h > 0 and h <= fontSize * 2 and (not issecretvalue or not issecretvalue(h)) then
            textHeight = h
        end
        container:SetSize(textWidth, textHeight)

        visual:SetPoint("CENTER", container, "CENTER", 0, 0)
        container.isFontString = true
    elseif isTexture then
        -- Clone Texture
        visual = container:CreateTexture(nil, "OVERLAY")
        visual:SetAllPoints(container)

        local atlasName = sourceComponent.GetAtlas and sourceComponent:GetAtlas()
        local texturePath = sourceComponent:GetTexture()

        if atlasName then
            visual:SetAtlas(atlasName, false) -- false = don't use atlas native size
        elseif texturePath then
            visual:SetTexture(texturePath)

            if sourceComponent.orbitSpriteIndex then
                ApplySpriteSheetCell(visual, sourceComponent.orbitSpriteIndex, sourceComponent.orbitSpriteRows or 4, sourceComponent.orbitSpriteCols or 4)
            else
                local ok, l, r, t, b = pcall(function() return sourceComponent:GetTexCoord() end)
                if ok and l then
                    visual:SetTexCoord(l, r, t, b)
                end
            end
        else
            local previewAtlases = Orbit.IconPreviewAtlases or {}
            local fallbackAtlas = previewAtlases[key]

            if fallbackAtlas then
                if key == "MarkerIcon" then
                    visual:SetTexture(fallbackAtlas)
                    ApplySpriteSheetCell(visual, 8, 4, 4)
                else
                    visual:SetAtlas(fallbackAtlas, false)
                end
            else
                visual:SetColorTexture(0.5, 0.5, 0.5, 0.5)
            end
        end

        local vr, vg, vb, va = sourceComponent:GetVertexColor()
        if vr then
            visual:SetVertexColor(vr, vg, vb, va or 1)
        end

        local srcWidth, srcHeight = 20, 20
        if sourceComponent.orbitOriginalWidth and sourceComponent.orbitOriginalWidth > 0 then
            srcWidth = sourceComponent.orbitOriginalWidth
        else
            local ok, w = pcall(function() return sourceComponent:GetWidth() end)
            if ok and w and type(w) == "number" and w > 0 then
                srcWidth = w
            end
        end
        if sourceComponent.orbitOriginalHeight and sourceComponent.orbitOriginalHeight > 0 then
            srcHeight = sourceComponent.orbitOriginalHeight
        else
            local ok2, h = pcall(function() return sourceComponent:GetHeight() end)
            if ok2 and h and type(h) == "number" and h > 0 then
                srcHeight = h
            end
        end

        container:SetSize(srcWidth, srcHeight)
    elseif isIconFrame then
        local iconTexture = sourceComponent.Icon
        local hasFlipbook = iconTexture and iconTexture.orbitPreviewTexCoord

        if hasFlipbook then
            -- Flipbook atlas (e.g. RestingIcon): plain texture clone with single-frame texcoord
            visual = container:CreateTexture(nil, "OVERLAY")
            visual:SetAllPoints(container)
            local atlasName = iconTexture.GetAtlas and iconTexture:GetAtlas()
            if atlasName then
                visual:SetAtlas(atlasName, false)
            elseif iconTexture:GetTexture() then
                visual:SetTexture(iconTexture:GetTexture())
            end
            local tc = iconTexture.orbitPreviewTexCoord
            visual:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        else
            -- Standard icon: skinned Button with ApplyCustom (proven working for party frame icons)
            local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
            btn:SetAllPoints(container)
            btn:EnableMouse(false)
            btn.Icon = btn:CreateTexture(nil, "ARTWORK")
            btn.Icon:SetAllPoints()
            btn.icon = btn.Icon

            local texturePath = iconTexture and iconTexture:GetTexture()
            local StatusMixin = Orbit.StatusIconMixin
            if texturePath then
                btn.Icon:SetTexture(texturePath)
            elseif StatusMixin and key == "DefensiveIcon" then
                btn.Icon:SetTexture(StatusMixin:GetDefensiveTexture())
            elseif StatusMixin and key == "ImportantIcon" then
                btn.Icon:SetTexture(StatusMixin:GetImportantTexture())
            elseif StatusMixin and key == "CrowdControlIcon" then
                btn.Icon:SetTexture(StatusMixin:GetCrowdControlTexture())
            else
                local previewAtlases = Orbit.IconPreviewAtlases or {}
                if previewAtlases[key] then
                    btn.Icon:SetAtlas(previewAtlases[key], false)
                else
                    btn.Icon:SetColorTexture(0.5, 0.5, 0.5, 0.5)
                end
            end

            local globalBorder = Orbit.db.GlobalSettings.BorderSize or 1
            if Orbit.Skin and Orbit.Skin.Icons then
                Orbit.Skin.Icons:ApplyCustom(btn, { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false })
            end

            visual = btn
            container.isIconFrame = true
        end

        local srcWidth, srcHeight = 24, 24
        if sourceComponent.orbitOriginalWidth and sourceComponent.orbitOriginalWidth > 0 then
            srcWidth = sourceComponent.orbitOriginalWidth
        else
            local ok, w = pcall(function() return sourceComponent:GetWidth() end)
            if ok and w and type(w) == "number" and w > 0 then
                srcWidth = w
            end
        end
        if sourceComponent.orbitOriginalHeight and sourceComponent.orbitOriginalHeight > 0 then
            srcHeight = sourceComponent.orbitOriginalHeight
        else
            local ok2, h = pcall(function() return sourceComponent:GetHeight() end)
            if ok2 and h and type(h) == "number" and h > 0 then
                srcHeight = h
            end
        end

        container:SetSize(srcWidth, srcHeight)
    elseif key == "Buffs" or key == "Debuffs" then
        -- Aura container: render sample icons in a grid (refreshable)
        local sampleIcons
        if key == "Buffs" then
            sampleIcons = { 135936, 136051, 135994 } -- Renew, PW:Shield, Rejuvenation
        else
            sampleIcons = { 132122, 136207, 135824 } -- Corruption, Shadow Word: Pain, Moonfire
        end

        container.auraIconPool = {}
        container.isAuraContainer = true

        -- Reusable refresh: reads overrides from pendingOverrides > existingOverrides > fallback
        container.RefreshAuraIcons = function(self)
            local AURA_BASE_ICON_SIZE = Orbit.PartyFrameHelpers and Orbit.PartyFrameHelpers.LAYOUT.AuraBaseIconSize or 25
            local AURA_SPACING = 2
            local overrides = self.pendingOverrides or self.existingOverrides or {}
            local scale = overrides.IconScale or 1.0
            local maxIcons = overrides.MaxIcons or 3
            local maxRows = overrides.MaxRows or 2
            local iconSize = math.max(12, math.floor(AURA_BASE_ICON_SIZE * scale + 0.5))

            -- Calculate grid layout
            local iconsPerRow = math.ceil(maxIcons / maxRows)
            local rows = math.min(maxRows, math.ceil(maxIcons / iconsPerRow))
            local displayCols = math.min(maxIcons, iconsPerRow)
            local containerWidth = (displayCols * iconSize) + ((displayCols - 1) * AURA_SPACING)
            local containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
            self:SetSize(containerWidth, containerHeight)

            -- Hide all pooled icons
            for _, btn in ipairs(self.auraIconPool) do
                btn:Hide()
            end

            local globalBorder = Orbit.db.GlobalSettings.BorderSize or 1
            local skinSettings = { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false }

            -- Create or reuse sample icons
            local iconIndex = 0
            for i = 1, maxIcons do
                local col = (i - 1) % iconsPerRow
                local row = math.floor((i - 1) / iconsPerRow)
                if row >= rows then
                    break
                end
                iconIndex = iconIndex + 1

                local btn = self.auraIconPool[iconIndex]
                if not btn then
                    btn = CreateFrame("Button", nil, self, "BackdropTemplate")
                    btn:EnableMouse(false)
                    btn.Icon = btn:CreateTexture(nil, "ARTWORK")
                    btn.Icon:SetAllPoints()
                    btn.icon = btn.Icon
                    self.auraIconPool[iconIndex] = btn
                end

                btn:SetSize(iconSize, iconSize)

                local texIndex = ((i - 1) % #sampleIcons) + 1
                btn.Icon:SetTexture(sampleIcons[texIndex])

                if Orbit.Skin and Orbit.Skin.Icons then
                    Orbit.Skin.Icons:ApplyCustom(btn, skinSettings)
                end

                btn:ClearAllPoints()
                local xOffset = col * (iconSize + AURA_SPACING)
                local yOffset = row * (iconSize + AURA_SPACING)
                btn:SetPoint("TOPLEFT", self, "TOPLEFT", xOffset, -yOffset)
                btn:Show()
            end
        end

        -- Initial render
        container.existingOverrides = data and data.overrides
        container:RefreshAuraIcons()
        visual = container.auraIconPool[1]
    else
        -- Fallback
        visual = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        visual:SetPoint("CENTER", container, "CENTER", 0, 0)
        visual:SetText(key or "?")
        container:SetSize(60, 20)
    end

    container.visual = visual

    -- Border (visible on hover/drag)
    container.border = container:CreateTexture(nil, "BACKGROUND")
    container.border:SetAllPoints()
    container.border:SetColorTexture(0.3, 0.8, 0.3, 0)

    -- Store position data
    container.posX = startX
    container.posY = startY
    container.key = key
    container.isFontString = isFontString
    container.existingOverrides = data and data.overrides

    -- Calculate anchor data
    local halfW = preview.sourceWidth / 2
    local halfH = preview.sourceHeight / 2
    local anchorX, anchorY, offsetX, offsetY, justifyH

    if data and data.anchorX then
        anchorX = data.anchorX
        anchorY = data.anchorY
        offsetX = data.offsetX
        offsetY = data.offsetY
        justifyH = data.justifyH
    else
        anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchor(startX, startY, halfW, halfH)
    end

    container.anchorX = anchorX
    container.anchorY = anchorY
    container.offsetX = offsetX
    container.offsetY = offsetY
    container.justifyH = justifyH

    -- Position the container
    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
    local posX, posY = startX, startY

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
    local selfAnchor = BuildComponentSelfAnchor(isFontString, container.isAuraContainer, anchorY, justifyH)
    container:SetPoint(selfAnchor, preview, anchorPoint, finalX, finalY)

    if isFontString and visual then
        ApplyTextAlignment(container, visual, justifyH)
    end

    -- [ CLICK/DRAG HANDLERS ]------------------------------------------------------------

    local DRAG_THRESHOLD = 3 -- Custom threshold (WoW default is ~15px)

    container:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.mouseDownTime = GetTime()
            self.wasDragged = false
            self.pendingDrag = true
            local mx, my = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self.mouseDownX = mx / scale
            self.mouseDownY = my / scale
        end
    end)

    container:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.pendingDrag = false

            -- If we were dragging, stop the drag
            if self.isDragging then
                self.isDragging = false
                self.border:SetColorTexture(0.3, 0.8, 0.3, 0)

                -- Hide SmartGuides
                if SmartGuides and preview.guides then
                    SmartGuides:Hide(preview.guides)
                end

                Dialog.DisabledDock.DropHighlight:Hide()
            elseif not self.wasDragged and self.mouseDownTime then
                -- Click behavior (not a drag)
                local clickDuration = GetTime() - self.mouseDownTime
                if clickDuration < 0.3 then
                    if OrbitEngine.CanvasComponentSettings then
                        OrbitEngine.CanvasComponentSettings:Open(self.key, self, Dialog.targetPlugin, Dialog.targetSystemIndex)
                    end
                end
            end

            self.mouseDownTime = nil
            self.mouseDownX = nil
            self.mouseDownY = nil
        end
    end)

    -- Helper to start dragging (shared logic)
    local function StartDrag(self)
        if InCombatLockdown() then
            return
        end

        self.wasDragged = true
        self.pendingDrag = false

        local mX, mY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mX, mY = mX / scale, mY / scale

        local parentCenterX, parentCenterY = preview:GetCenter()
        local zoomLevel = Dialog.zoomLevel or 1
        local itemScreenX = parentCenterX + (self.posX or 0) * zoomLevel
        local itemScreenY = parentCenterY + (self.posY or 0) * zoomLevel

        self.dragGripX = itemScreenX - mX
        self.dragGripY = itemScreenY - mY
        self.isDragging = true
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0.3)
    end

    -- Keep OnDragStart as fallback (for accessibility/edge cases)
    container:SetScript("OnDragStart", function(self)
        if not self.isDragging and not self.wasDragged then
            StartDrag(self)
        end
    end)

    container:SetScript("OnUpdate", function(self)
        -- Check for pending drag with custom threshold (faster than WoW's ~15px default)
        if self.pendingDrag and self.mouseDownX and self.mouseDownY then
            local mX, mY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            mX, mY = mX / scale, mY / scale

            local dx = math.abs(mX - self.mouseDownX)
            local dy = math.abs(mY - self.mouseDownY)

            if dx > DRAG_THRESHOLD or dy > DRAG_THRESHOLD then
                StartDrag(self)
            end
        end

        if self.isDragging then
            local halfW = preview.sourceWidth / 2
            local halfH = preview.sourceHeight / 2

            local mX, mY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            mX, mY = mX / scale, mY / scale

            -- 2. Calculate where the Center SHOULD be (Mouse + Grip)
            local targetWorldX = mX + (self.dragGripX or 0)
            local targetWorldY = mY + (self.dragGripY or 0)

            -- 3. Normalize to Parent Frame (Convert to local coords, 0,0 at center)
            local parentCenterX, parentCenterY = preview:GetCenter()
            local screenOffsetX = targetWorldX - parentCenterX
            local screenOffsetY = targetWorldY - parentCenterY

            -- 4. Account for zoom level (screen pixels -> local pixels)
            local zoomLevel = Dialog.zoomLevel or 1
            local relativeX = screenOffsetX / zoomLevel
            local relativeY = screenOffsetY / zoomLevel

            -- 5. Clamp to bounds
            local CLAMP_PADDING_X = 100
            local CLAMP_PADDING_Y = 50
            relativeX = math.max(-halfW - CLAMP_PADDING_X, math.min(halfW + CLAMP_PADDING_X, relativeX))
            relativeY = math.max(-halfH - CLAMP_PADDING_Y, math.min(halfH + CLAMP_PADDING_Y, relativeY))

            -- Alias for consistency with rest of code
            local centerRelX, centerRelY = relativeX, relativeY

            -- [ TIERED SNAP LOGIC ]------------------------------------------------------
            local snapX, snapY = nil, nil
            local compWidth = self:GetWidth() or 40
            local compHeight = self:GetHeight() or 16
            local compHalfW = compWidth / 2
            local compHalfH = compHeight / 2

            if IsShiftKeyDown() then
                -- Precision mode: no snapping
            else
                -- Edge Magnet X (snap when near edge, show guide when beyond)
                local rightEdgePos = halfW - compHalfW
                local leftEdgePos = -halfW + compHalfW
                local distRight = math.abs(centerRelX - rightEdgePos)
                local distLeft = math.abs(centerRelX - leftEdgePos)
                local beyondRight = centerRelX > rightEdgePos
                local beyondLeft = centerRelX < leftEdgePos

                if distRight <= EDGE_THRESHOLD and not beyondRight then
                    centerRelX = rightEdgePos
                    snapX = "RIGHT"
                elseif distLeft <= EDGE_THRESHOLD and not beyondLeft then
                    centerRelX = leftEdgePos
                    snapX = "LEFT"
                elseif math.abs(centerRelX) <= EDGE_THRESHOLD then
                    centerRelX = 0
                    snapX = "CENTER"
                elseif beyondRight then
                    snapX = "RIGHT" -- Show guide only, no snap
                elseif beyondLeft then
                    snapX = "LEFT" -- Show guide only, no snap
                end
                if not snapX then
                    centerRelX = math.floor(centerRelX / SNAP_SIZE + 0.5) * SNAP_SIZE
                end

                -- Edge Magnet Y (snap when near edge, show guide when beyond)
                local topEdgePos = halfH - compHalfH
                local bottomEdgePos = -halfH + compHalfH
                local distTop = math.abs(centerRelY - topEdgePos)
                local distBottom = math.abs(centerRelY - bottomEdgePos)
                local beyondTop = centerRelY > topEdgePos
                local beyondBottom = centerRelY < bottomEdgePos

                if distTop <= EDGE_THRESHOLD and not beyondTop then
                    centerRelY = topEdgePos
                    snapY = "TOP"
                elseif distBottom <= EDGE_THRESHOLD and not beyondBottom then
                    centerRelY = bottomEdgePos
                    snapY = "BOTTOM"
                elseif math.abs(centerRelY) <= EDGE_THRESHOLD then
                    centerRelY = 0
                    snapY = "CENTER"
                elseif beyondTop then
                    snapY = "TOP" -- Show guide only, no snap
                elseif beyondBottom then
                    snapY = "BOTTOM" -- Show guide only, no snap
                end
                if not snapY then
                    centerRelY = math.floor(centerRelY / SNAP_SIZE + 0.5) * SNAP_SIZE
                end
            end

            local needsWidthComp = NeedsEdgeCompensation(self.isFontString, self.isAuraContainer)
            local anchorX, anchorY, edgeOffX, edgeOffY, justifyH =
                CalculateAnchorWithWidthCompensation(centerRelX, centerRelY, halfW, halfH, needsWidthComp, self:GetWidth())
            -- Aura containers also need height compensation (vertical self-anchor is BOTTOM/TOP)
            if self.isAuraContainer and anchorY ~= "CENTER" then
                edgeOffY = edgeOffY - (self:GetHeight() or 0) / 2
            end

            -- Update SmartGuides
            if SmartGuides and preview.guides then
                SmartGuides:Update(preview.guides, snapX, snapY, preview.sourceWidth, preview.sourceHeight)
            end

            if self.isFontString and self.visual then
                ApplyTextAlignment(self, self.visual, justifyH)
            end

            -- Always position by CENTER during drag for smooth movement
            self:ClearAllPoints()
            self:SetPoint("CENTER", preview, "CENTER", centerRelX, centerRelY)

            -- Store values for OnDragStop
            self.anchorX = anchorX
            self.anchorY = anchorY
            self.offsetX = edgeOffX
            self.offsetY = edgeOffY
            self.justifyH = justifyH
            self.posX = centerRelX
            self.posY = centerRelY

            -- Show/hide dock drop highlight
            if Dialog.DisabledDock:IsMouseOver() then
                Dialog.DisabledDock.DropHighlight:Show()
            else
                Dialog.DisabledDock.DropHighlight:Hide()
            end

            -- Show tooltip
            if OrbitEngine.SelectionTooltip then
                OrbitEngine.SelectionTooltip:ShowComponentPosition(self, key, anchorX, anchorY, centerRelX, centerRelY, edgeOffX, edgeOffY, justifyH)
            end
        end
    end)

    container:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self.dragStartLocalX = nil
        self.dragStartLocalY = nil
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0)

        Dialog.DisabledDock.DropHighlight:Hide()

        -- Hide SmartGuides
        if SmartGuides and preview.guides then
            SmartGuides:Hide(preview.guides)
        end

        -- Check if dropped over the disabled dock
        if Dialog.DisabledDock:IsMouseOver() then
            local compKey = self.key
            local sourceComponent = data and data.component

            self:Hide()
            self:SetParent(nil)
            Dialog.previewComponents[compKey] = nil

            Dialog:AddToDock(compKey, sourceComponent)
            return
        end

        -- Snap to grid
        local SNAP = 5
        local snappedX = math.floor((self.posX or 0) / SNAP + 0.5) * SNAP
        local snappedY = math.floor((self.posY or 0) / SNAP + 0.5) * SNAP
        self.posX = snappedX
        self.posY = snappedY

        self.offsetX = math.floor((self.offsetX or 0) / SNAP + 0.5) * SNAP
        self.offsetY = math.floor((self.offsetY or 0) / SNAP + 0.5) * SNAP

        self:ClearAllPoints()
        self:SetPoint("CENTER", preview, "CENTER", snappedX, snappedY)

        if self.visual and self.isFontString then
            ApplyTextAlignment(self, self.visual, self.justifyH or "CENTER")
        end
    end)

    -- Hover effects
    container:SetScript("OnEnter", function(self)
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0.2)
        Dialog.hoveredComponent = self
    end)

    container:SetScript("OnLeave", function(self)
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0)
        if Dialog.hoveredComponent == self then
            Dialog.hoveredComponent = nil
        end
    end)

    -- Apply existing overrides
    if container.existingOverrides and OrbitEngine.CanvasComponentSettings and OrbitEngine.CanvasComponentSettings.ApplyAll then
        OrbitEngine.CanvasComponentSettings:ApplyAll(container, container.existingOverrides)
    end

    return container
end

-- Export for use by other modules
CanvasMode.CreateDraggableComponent = CreateDraggableComponent
