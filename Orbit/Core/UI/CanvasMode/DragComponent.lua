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
local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint

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
    if not texture or not index then return end
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


-- [ CREATE DRAGGABLE COMPONENT ]---------------------------------------------------------

local function CreateDraggableComponent(preview, key, sourceComponent, startX, startY, data)
    -- Create a container for the component
    local container = CreateFrame("Frame", nil, preview)
    container:SetSize(100, 20)
    container:EnableMouse(true)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")
    
    local visual
    local isFontString = sourceComponent and sourceComponent.GetText ~= nil
    local isTexture = sourceComponent and sourceComponent.GetTexture ~= nil and not isFontString
    local isIconFrame = sourceComponent and sourceComponent.Icon and sourceComponent.Icon.GetTexture
    
    if isFontString then
        -- Clone FontString
        visual = container:CreateFontString(nil, "OVERLAY")
        
        local fontPath, fontSize, fontFlags = sourceComponent:GetFont()
        -- Default to OUTLINE if flags is nil or empty (most WoW text uses outline)
        local flags = (fontFlags and fontFlags ~= "") and fontFlags or "OUTLINE"
        if fontPath and fontSize then
            visual:SetFont(fontPath, fontSize, flags)
        else
            local globalFontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
            local fallbackPath = LSM:Fetch("font", globalFontName) or Orbit.Constants.Settings.Font.FallbackPath
            local fallbackSize = Orbit.Constants.UI.UnitFrameTextSize or 12
            visual:SetFont(fallbackPath, fallbackSize, "OUTLINE")
        end
        
        -- Copy text with preview fallback
        local text = PREVIEW_TEXT_VALUES[key] or "Text"
        local ok, t = pcall(function() return sourceComponent:GetText() end)
        if ok and t and type(t) == "string" and (not issecretvalue or not issecretvalue(t)) and t ~= "" then
            text = t
        end
        visual:SetText(text)
        
        -- Copy text color
        local r, g, b, a = sourceComponent:GetTextColor()
        if r then visual:SetTextColor(r, g, b, a or 1) end
        
        -- Copy shadow
        local sr, sg, sb, sa = sourceComponent:GetShadowColor()
        if sr then visual:SetShadowColor(sr, sg, sb, sa or 1) end
        local sx, sy = sourceComponent:GetShadowOffset()
        if sx then visual:SetShadowOffset(sx, sy) end
        
        -- Auto-size container based on text dimensions
        local text = visual:GetText() or ""
        local fontSize = select(2, visual:GetFont()) or 12
        -- Fallback width based on character count (rough estimate)
        local textWidth = math.max(fontSize * #text * 0.7, 12)
        local textHeight = fontSize + 4
        local ok, w = pcall(function() return visual:GetStringWidth() end)
        if ok and w and type(w) == "number" and w > 0 and (not issecretvalue or not issecretvalue(w)) then
            textWidth = w
        end
        local ok2, h = pcall(function() return visual:GetStringHeight() end)
        if ok2 and h and type(h) == "number" and h > 0 and (not issecretvalue or not issecretvalue(h)) then
            textHeight = h
        end
        container:SetSize(math.max(12, textWidth), math.max(12, textHeight))
        
        visual:SetPoint("CENTER", container, "CENTER", 0, 0)
        container.isFontString = true
        
    elseif isTexture then
        -- Clone Texture
        visual = container:CreateTexture(nil, "OVERLAY")
        visual:SetAllPoints(container)
        
        local atlasName = sourceComponent.GetAtlas and sourceComponent:GetAtlas()
        local texturePath = sourceComponent:GetTexture()
        
        if atlasName then
            visual:SetAtlas(atlasName, false)  -- false = don't use atlas native size
        elseif texturePath then
            visual:SetTexture(texturePath)
            
            if sourceComponent.orbitSpriteIndex then
                ApplySpriteSheetCell(visual, sourceComponent.orbitSpriteIndex, 
                    sourceComponent.orbitSpriteRows or 4, sourceComponent.orbitSpriteCols or 4)
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
        if vr then visual:SetVertexColor(vr, vg, vb, va or 1) end
        
        local srcWidth, srcHeight = 20, 20
        if sourceComponent.orbitOriginalWidth and sourceComponent.orbitOriginalWidth > 0 then
            srcWidth = sourceComponent.orbitOriginalWidth
        else
            local ok, w = pcall(function() return sourceComponent:GetWidth() end)
            if ok and w and type(w) == "number" and w > 0 then srcWidth = w end
        end
        if sourceComponent.orbitOriginalHeight and sourceComponent.orbitOriginalHeight > 0 then
            srcHeight = sourceComponent.orbitOriginalHeight
        else
            local ok2, h = pcall(function() return sourceComponent:GetHeight() end)
            if ok2 and h and type(h) == "number" and h > 0 then srcHeight = h end
        end
        
        container:SetSize(srcWidth, srcHeight)
        
    elseif isIconFrame then
        -- Clone Frame with Icon child
        visual = container:CreateTexture(nil, "OVERLAY")
        visual:SetAllPoints(container)
        
        local iconTexture = sourceComponent.Icon
        local texturePath = iconTexture:GetTexture()
        if texturePath then
            visual:SetTexture(texturePath)
        end
        
        local ok, l, r, t, b = pcall(function() return iconTexture:GetTexCoord() end)
        if ok and l then
            visual:SetTexCoord(l, r, t, b)
        end
        
        local srcWidth, srcHeight = 24, 24
        local ok, w = pcall(function() return sourceComponent:GetWidth() end)
        if ok and w and type(w) == "number" and w > 0 then srcWidth = w end
        local ok2, h = pcall(function() return sourceComponent:GetHeight() end)
        if ok2 and h and type(h) == "number" and h > 0 then srcHeight = h end
        
        container:SetSize(srcWidth, srcHeight)
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
        if anchorX == "RIGHT" then finalX = -finalX end
    end
    
    if anchorY == "CENTER" then
        finalY = posY
    else
        finalY = offsetY
        if anchorY == "TOP" then finalY = -finalY end
    end
    
    container:ClearAllPoints()
    if isFontString and justifyH ~= "CENTER" then
        container:SetPoint(justifyH, preview, anchorPoint, finalX, finalY)
    else
        container:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
    end
    
    if isFontString and visual then
        ApplyTextAlignment(container, visual, justifyH)
    end
    
    -- [ CLICK/DRAG HANDLERS ]------------------------------------------------------------
    
    container:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.mouseDownTime = GetTime()
            self.wasDragged = false
            local mx, my = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self.mouseDownX = mx / scale
            self.mouseDownY = my / scale
        end
    end)
    
    container:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            local clickDuration = GetTime() - (self.mouseDownTime or 0)
            
            if not self.wasDragged and clickDuration < 0.3 then
                if OrbitEngine.CanvasComponentSettings then
                    OrbitEngine.CanvasComponentSettings:Open(self.key, self, Dialog.targetPlugin, Dialog.targetSystemIndex)
                end
            end
            
            self.mouseDownTime = nil
            self.mouseDownX = nil
            self.mouseDownY = nil
        end
    end)
    
    container:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        
        self.wasDragged = true
        
        -- Get Mouse Screen Position (normalized to UIParent scale)
        local mX, mY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mX, mY = mX / scale, mY / scale
        
        -- Get preview's center in screen coords
        local parentCenterX, parentCenterY = preview:GetCenter()
        
        -- Calculate where the component's CENTER should be in screen coords
        -- using our stored center-relative posX/posY
        local zoomLevel = Dialog.zoomLevel or 1
        local itemScreenX = parentCenterX + (self.posX or 0) * zoomLevel
        local itemScreenY = parentCenterY + (self.posY or 0) * zoomLevel
        
        -- Calculate grip offset (distance from click to item center)
        self.dragGripX = itemScreenX - mX
        self.dragGripY = itemScreenY - mY
        
        self.isDragging = true
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0.3)
    end)
    
    container:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local halfW = preview.sourceWidth / 2
            local halfH = preview.sourceHeight / 2
            
            -- 1. Get current Mouse Screen Position
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
            
            local anchorX, anchorY, edgeOffX, edgeOffY, justifyH = CalculateAnchor(centerRelX, centerRelY, halfW, halfH)
            
            -- FontString justify calculation with width-compensated edge offsets
            if self.isFontString then
                local isOutsideLeft = centerRelX < -halfW
                local isOutsideRight = centerRelX > halfW
                local containerHalfW = self:GetWidth() / 2
                
                if anchorX == "LEFT" then
                    justifyH = isOutsideLeft and "RIGHT" or "LEFT"
                    -- When inside: justify=LEFT, SetPoint uses text's LEFT edge → subtract
                    -- When outside: justify=RIGHT, SetPoint uses text's RIGHT edge → add
                    local widthCompensation = isOutsideLeft and containerHalfW or -containerHalfW
                    edgeOffX = centerRelX + halfW + widthCompensation
                elseif anchorX == "RIGHT" then
                    justifyH = isOutsideRight and "LEFT" or "RIGHT"
                    -- When inside: justify=RIGHT, SetPoint uses text's RIGHT edge → subtract
                    -- When outside: justify=LEFT, SetPoint uses text's LEFT edge → add
                    local widthCompensation = isOutsideRight and containerHalfW or -containerHalfW
                    edgeOffX = halfW - centerRelX + widthCompensation
                else
                    edgeOffX = 0
                    justifyH = "CENTER"
                end
                
                -- Live text alignment during drag (what you see = what you get)
                if self.visual then
                    ApplyTextAlignment(self, self.visual, justifyH)
                end
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
                OrbitEngine.SelectionTooltip:ShowComponentPosition(
                    self, key,
                    anchorX, anchorY,
                    centerRelX, centerRelY,
                    edgeOffX, edgeOffY,
                    justifyH
                )
            end
        end
    end)
    
    container:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self.dragStartLocalX = nil
        self.dragStartLocalY = nil
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0)
        
        Dialog.DisabledDock.DropHighlight:Hide()
        
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
