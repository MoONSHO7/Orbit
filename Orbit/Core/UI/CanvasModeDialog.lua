-- [ CANVAS MODE DIALOG ]------------------------------------------------------------
-- Dedicated dialog for editing frame component positions using a PREVIEW REPLICA
-- Real frame stays in place - we create a fake preview and drag components on that
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]--------------------------------------------------------------------------------

-- Fixed dialog dimensions (decoupled from frame size)
local DIALOG_WIDTH = 480  -- 20% less than 600
local DIALOG_HEIGHT = 250  -- Half of 500
local DIALOG_MIN_HEIGHT = 200

-- Viewport constants
local VIEWPORT_PADDING = 20  -- Padding inside viewport
local FOOTER_HEIGHT = 55
local TITLE_HEIGHT = 40

-- Zoom constants (applied via SetScale on TransformLayer, not preview rebuild)
local DEFAULT_ZOOM = 2.0
local MIN_ZOOM = 0.5
local MAX_ZOOM = 4.0
local ZOOM_STEP = 0.25

-- Pan clamping (how much of preview must remain visible)
local PAN_CLAMP_PADDING = 50

-- [ CREATE DIALOG FRAME ]------------------------------------------------------------------------

local Dialog = CreateFrame("Frame", "OrbitCanvasModeDialog", UIParent)
Dialog:SetSize(DIALOG_WIDTH, DIALOG_MIN_HEIGHT)
Dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
Dialog:SetFrameStrata("FULLSCREEN_DIALOG")
Dialog:SetFrameLevel(100)
Dialog:SetMovable(true)
Dialog:SetClampedToScreen(true)
Dialog:EnableMouse(true)
Dialog:RegisterForDrag("LeftButton")
Dialog:Hide()

-- Backdrop: Use Blizzard's high-quality DialogBorderTranslucentTemplate
-- This provides the professional metallic nine-slice border matching Blizzard's EditMode dialogs
Dialog.Border = CreateFrame("Frame", nil, Dialog, "DialogBorderTranslucentTemplate")
Dialog.Border:SetAllPoints(Dialog)
Dialog.Border:SetFrameLevel(Dialog:GetFrameLevel())

-- Drag handlers
Dialog:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

Dialog:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Close on combat
Dialog:RegisterEvent("PLAYER_REGEN_DISABLED")
Dialog:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then
        self:Cancel()
    end
end)

-- [ TITLE ]--------------------------------------------------------------------------------------

Dialog.Title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
Dialog.Title:SetPoint("TOP", Dialog, "TOP", 0, -15)
Dialog.Title:SetText("Canvas Mode")

-- [ CLOSE BUTTON ]------------------------------------------------------------------------------

Dialog.CloseButton = CreateFrame("Button", nil, Dialog, "UIPanelCloseButton")
Dialog.CloseButton:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", -2, -2)
Dialog.CloseButton:SetScript("OnClick", function()
    Dialog:Cancel()
end)

-- [ PREVIEW CONTAINER ]-------------------------------------------------------------------------
-- Architecture: PreviewContainer > Viewport (clips) > TransformLayer (zoom/pan) > PreviewFrame

Dialog.PreviewContainer = CreateFrame("Frame", nil, Dialog)
Dialog.PreviewContainer:SetPoint("TOPLEFT", Dialog, "TOPLEFT", VIEWPORT_PADDING, -TITLE_HEIGHT)
Dialog.PreviewContainer:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -VIEWPORT_PADDING, FOOTER_HEIGHT)

-- Viewport: Clips children to create the viewable area
Dialog.Viewport = CreateFrame("Frame", nil, Dialog.PreviewContainer)
Dialog.Viewport:SetAllPoints()
Dialog.Viewport:SetClipsChildren(true)
Dialog.Viewport:EnableMouse(true)
Dialog.Viewport:EnableMouseWheel(true)
Dialog.Viewport:RegisterForDrag("MiddleButton", "LeftButton")

-- TransformLayer: Receives zoom (SetScale) and pan (position offset)
Dialog.TransformLayer = CreateFrame("Frame", nil, Dialog.Viewport)
Dialog.TransformLayer:SetSize(1, 1)  -- Size managed dynamically
Dialog.TransformLayer:SetPoint("CENTER", Dialog.Viewport, "CENTER", 0, 0)

-- Zoom/Pan state
Dialog.zoomLevel = DEFAULT_ZOOM
Dialog.panOffsetX = 0
Dialog.panOffsetY = 0

-- Helper: Calculate pan clamping bounds
local function GetPanBounds(transformLayer, viewport, zoomLevel)
    local baseWidth = transformLayer.baseWidth or 200
    local baseHeight = transformLayer.baseHeight or 60
    local scaledW = baseWidth * zoomLevel
    local scaledH = baseHeight * zoomLevel
    local viewW = viewport:GetWidth()
    local viewH = viewport:GetHeight()
    
    -- Allow panning up to the point where preview edge reaches viewport center
    local maxX = math.max(0, (scaledW / 2) - (viewW / 2) + PAN_CLAMP_PADDING)
    local maxY = math.max(0, (scaledH / 2) - (viewH / 2) + PAN_CLAMP_PADDING)
    
    return maxX, maxY
end

-- Helper: Apply pan with clamping
local function ApplyPanOffset(dialog, offsetX, offsetY)
    local maxX, maxY = GetPanBounds(dialog.TransformLayer, dialog.Viewport, dialog.zoomLevel)
    
    dialog.panOffsetX = math.max(-maxX, math.min(maxX, offsetX))
    dialog.panOffsetY = math.max(-maxY, math.min(maxY, offsetY))
    
    dialog.TransformLayer:ClearAllPoints()
    dialog.TransformLayer:SetPoint("CENTER", dialog.Viewport, "CENTER", dialog.panOffsetX, dialog.panOffsetY)
end

-- Helper: Apply zoom level
local function ApplyZoom(dialog, newZoom)
    newZoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, newZoom))
    -- Round to 2 decimal places
    newZoom = math.floor(newZoom * 100 + 0.5) / 100
    
    dialog.zoomLevel = newZoom
    dialog.TransformLayer:SetScale(newZoom)
    
    -- Re-clamp pan after zoom change (visible area may have changed)
    ApplyPanOffset(dialog, dialog.panOffsetX, dialog.panOffsetY)
    
    -- Update zoom indicator if present
    if dialog.ZoomIndicator then
        dialog.ZoomIndicator:SetText(string.format("%.0f%%", newZoom * 100))
    end
end

-- Mouse wheel to zoom
Dialog.Viewport:SetScript("OnMouseWheel", function(self, delta)
    local newZoom = Dialog.zoomLevel + (delta * ZOOM_STEP)
    ApplyZoom(Dialog, newZoom)
end)

-- Pan: Drag to move the preview within viewport
Dialog.Viewport:SetScript("OnDragStart", function(self)
    self.isPanning = true
    local mx, my = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self.panStartMouseX = mx / scale
    self.panStartMouseY = my / scale
    self.panStartOffsetX = Dialog.panOffsetX
    self.panStartOffsetY = Dialog.panOffsetY
    -- No custom cursor needed - default cursor is already high-resolution
end)

Dialog.Viewport:SetScript("OnDragStop", function(self)
    self.isPanning = false
    ResetCursor()
end)

Dialog.Viewport:SetScript("OnUpdate", function(self)
    if self.isPanning then
        local mx, my = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mx = mx / scale
        my = my / scale
        
        local deltaX = mx - self.panStartMouseX
        local deltaY = my - self.panStartMouseY
        
        ApplyPanOffset(Dialog, self.panStartOffsetX + deltaX, self.panStartOffsetY + deltaY)
    end
end)

-- Zoom indicator (bottom-right of viewport)
Dialog.ZoomIndicator = Dialog.PreviewContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.ZoomIndicator:SetPoint("BOTTOMRIGHT", Dialog.PreviewContainer, "BOTTOMRIGHT", -5, 5)
Dialog.ZoomIndicator:SetText(string.format("%.0f%%", DEFAULT_ZOOM * 100))
Dialog.ZoomIndicator:SetTextColor(0.7, 0.7, 0.7, 0.8)

-- [ FOOTER (Using pattern: divider + stretch-to-fill buttons) ]----------------------

local Layout = OrbitEngine.Layout
local Constants = Orbit.Constants
local FC = Constants.Footer
local PC = Constants.Panel

-- Dialog backdrop insets (from the SetBackdrop above: insets = { left = 11, right = 12, top = 12, bottom = 11 })
local DIALOG_INSET = 12

-- Footer container (attached to bottom of dialog with insets for border)
Dialog.Footer = CreateFrame("Frame", nil, Dialog)
Dialog.Footer:SetPoint("BOTTOMLEFT", Dialog, "BOTTOMLEFT", DIALOG_INSET, DIALOG_INSET)
Dialog.Footer:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -DIALOG_INSET, DIALOG_INSET)

-- Divider line at top of footer
Dialog.FooterDivider = Dialog.Footer:CreateTexture(nil, "ARTWORK")
Dialog.FooterDivider:SetSize(PC.DividerWidth, PC.DividerHeight)
Dialog.FooterDivider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
Dialog.FooterDivider:SetPoint("TOP", Dialog.Footer, "TOP", 0, FC.DividerOffset)

-- Create the buttons
Dialog.CancelButton = Layout:CreateButton(Dialog.Footer, "Cancel", function()
    Dialog:Cancel()
end)
Dialog.ResetButton = Layout:CreateButton(Dialog.Footer, "Reset", function()
    Dialog:ResetPositions()
end)
Dialog.ApplyButton = Layout:CreateButton(Dialog.Footer, "Apply", function()
    Dialog:Apply()
end)

-- Layout function to position buttons (called on Open to handle dynamic dialog width)
function Dialog:LayoutFooterButtons()
    local buttons = { self.CancelButton, self.ResetButton, self.ApplyButton }
    local numButtons = #buttons
    
    -- Account for Dialog insets (12px on each side) AND internal footer padding (10px on each side)
    -- Total deduction: 24px (insets) + 20px (padding) = 44px
    local DIALOG_INSET = 12
    local availableWidth = (self:GetWidth() - (DIALOG_INSET * 2)) - (FC.SidePadding * 2)
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
    
    -- Set footer height
    local footerHeight = FC.TopPadding + FC.ButtonHeight + FC.BottomPadding
    self.Footer:SetHeight(footerHeight)
end

-- Initial layout (will be called again in Open with proper dialog width)
Dialog.Footer:SetHeight(FC.TopPadding + FC.ButtonHeight + FC.BottomPadding)

-- [ ESC KEY SUPPORT ]----------------------------------------------------------------------------

table.insert(UISpecialFrames, "OrbitCanvasModeDialog")

Dialog:SetPropagateKeyboardInput(true)
Dialog:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then return end
    
    if key == "ESCAPE" then
        self:SetPropagateKeyboardInput(false)
        self:Cancel()
        C_Timer.After(0.05, function()
            if not InCombatLockdown() then
                self:SetPropagateKeyboardInput(true)
            end
        end)
    elseif key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
        -- Nudge hovered component
        if self.hoveredComponent then
            self:SetPropagateKeyboardInput(false)
            self:NudgeComponent(self.hoveredComponent, key)
            
            -- Start repeat nudging
            local direction = key
            local component = self.hoveredComponent
            OrbitEngine.NudgeRepeat:Start(
                function()
                    if self.hoveredComponent == component then
                        self:NudgeComponent(component, direction)
                    end
                end,
                function()
                    return self.hoveredComponent == component
                end
            )
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

-- [ STATE ]--------------------------------------------------------------------------------------

Dialog.targetFrame = nil
Dialog.targetPlugin = nil
Dialog.targetSystemIndex = nil
Dialog.originalPositions = {}
Dialog.previewFrame = nil
Dialog.previewComponents = {}  -- { key = container }
Dialog.hoveredComponent = nil  -- Currently hovered component for nudge

-- Use shared position utilities
local CalculateAnchor = OrbitEngine.PositionUtils.CalculateAnchor
local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint

-- Apply alignment to a FontString visual within its container
local function ApplyTextAlignment(container, visual, justifyH)
    visual:ClearAllPoints()
    visual:SetPoint(justifyH, container, justifyH, 0, 0)
    visual:SetJustifyH(justifyH)
end

-- [ NUDGE COMPONENT ]--------------------------------------------------------------------------

function Dialog:NudgeComponent(container, direction)
    if not container or not self.previewFrame then return end
    
    local preview = self.previewFrame
    local NUDGE = 1 -- 1px nudge for fine-tuning
    
    -- Get current anchor and offset (preserve these, don't recalculate)
    local anchorX = container.anchorX or "CENTER"
    local anchorY = container.anchorY or "CENTER"
    local offsetX = container.offsetX or 0
    local offsetY = container.offsetY or 0
    local justifyH = container.justifyH or "CENTER"
    
    -- Adjust offset based on direction
    -- For LEFT/RIGHT anchor, offsetX is distance from that edge (positive = inside)
    -- For TOP/BOTTOM anchor, offsetY is distance from that edge (positive = inside)
    -- For CENTER anchor, offset = pos (distance from center)
    if direction == "LEFT" then
        if anchorX == "LEFT" then
            offsetX = offsetX - NUDGE
        elseif anchorX == "RIGHT" then
            offsetX = offsetX + NUDGE
        else
            container.posX = (container.posX or 0) - NUDGE
            offsetX = container.posX  -- Sync for Apply
        end
    elseif direction == "RIGHT" then
        if anchorX == "LEFT" then
            offsetX = offsetX + NUDGE
        elseif anchorX == "RIGHT" then
            offsetX = offsetX - NUDGE
        else
            container.posX = (container.posX or 0) + NUDGE
            offsetX = container.posX  -- Sync for Apply
        end
    elseif direction == "UP" then
        if anchorY == "TOP" then
            offsetY = offsetY - NUDGE
        elseif anchorY == "BOTTOM" then
            offsetY = offsetY + NUDGE
        else
            container.posY = (container.posY or 0) + NUDGE
            offsetY = container.posY  -- Sync for Apply
        end
    elseif direction == "DOWN" then
        if anchorY == "TOP" then
            offsetY = offsetY + NUDGE
        elseif anchorY == "BOTTOM" then
            offsetY = offsetY - NUDGE
        else
            container.posY = (container.posY or 0) - NUDGE
            offsetY = container.posY  -- Sync for Apply
        end
    end
    
    -- Store updated offset (anchor stays the same)
    container.offsetX = offsetX
    container.offsetY = offsetY
    
    -- Reposition the container
    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
    
    -- For CENTER anchor, use posX/posY for positioning
    local posX = container.posX or 0
    local posY = container.posY or 0
    
    local finalX, finalY
    -- Note: No scale multiplication - TransformLayer handles zoom via SetScale
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
    if container.isFontString and justifyH ~= "CENTER" then
        container:SetPoint(justifyH, preview, anchorPoint, finalX, finalY)
    else
        container:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
    end
    
    -- Show tooltip with updated values
    if OrbitEngine.SelectionTooltip then
        OrbitEngine.SelectionTooltip:ShowComponentPosition(
            container, container.key,
            anchorX, anchorY,
            container.posX or 0, container.posY or 0,
            offsetX, offsetY,
            justifyH
        )
    end
end


-- [ CREATE DRAGGABLE COMPONENT ]-----------------------------------------------------------------

local function CreateDraggableComponent(preview, key, sourceComponent, startX, startY, data)
    -- Create a container for the component
    local container = CreateFrame("Frame", nil, preview)
    container:SetSize(100, 20)
    container:EnableMouse(true)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")
    
    local visual -- The cloned visual element (FontString or Texture)
    local isFontString = sourceComponent and sourceComponent.GetText ~= nil
    local isTexture = sourceComponent and sourceComponent.GetTexture ~= nil and not isFontString
    -- Check for Frame with Icon child (used by BigDefensive, aura frames, etc.)
    local isIconFrame = sourceComponent and sourceComponent.Icon and sourceComponent.Icon.GetTexture
    
    if isFontString then
        -- Clone FontString
        visual = container:CreateFontString(nil, "OVERLAY")
        
        -- MUST set font BEFORE text (WoW requirement)
        local fontPath, fontSize, fontFlags = sourceComponent:GetFont()
        if fontPath and fontSize then
            -- Font at 1x scale - TransformLayer handles zoom
            visual:SetFont(fontPath, fontSize, fontFlags or "")
        else
            -- Fallback to Orbit's global font (1x scale)
            local globalFontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
            local fallbackPath = LSM:Fetch("font", globalFontName) or Orbit.Constants.Settings.Font.FallbackPath
            local fallbackSize = Orbit.Constants.UI.UnitFrameTextSize or 12
            visual:SetFont(fallbackPath, fallbackSize, "OUTLINE")
        end
        
        -- Now copy text (handle secrets)
        local text = "Text"
        local ok, t = pcall(function() return sourceComponent:GetText() end)
        if ok and t and type(t) == "string" then
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
        if sx then visual:SetShadowOffset(sx, sy) end  -- 1x scale - TransformLayer handles zoom
        
        -- Auto-size container to fit text
        local textWidth, textHeight = 60, 16
        local ok, w = pcall(function() return visual:GetStringWidth() end)
        if ok and w and type(w) == "number" and (not issecretvalue or not issecretvalue(w)) then
            textWidth = w + 10
        end
        local ok2, h = pcall(function() return visual:GetStringHeight() end)
        if ok2 and h and type(h) == "number" and (not issecretvalue or not issecretvalue(h)) then
            textHeight = h + 6
        end
        container:SetSize(math.max(50, textWidth), math.max(18, textHeight))
        
        -- Center visual in container (matches how real components are anchored)
        visual:SetPoint("CENTER", container, "CENTER", 0, 0)
        container.isFontString = true
        
    elseif isTexture then
        -- Clone Texture
        visual = container:CreateTexture(nil, "OVERLAY")
        visual:SetAllPoints(container)
        
        -- Check for Atlas first (used by modern Blizzard icons like CombatIcon)
        local atlasName = sourceComponent.GetAtlas and sourceComponent:GetAtlas()
        if atlasName then
            visual:SetAtlas(atlasName)
        else
            -- Fall back to regular texture path
            local texturePath = sourceComponent:GetTexture()
            if texturePath then
                visual:SetTexture(texturePath)
            end
            
            -- Copy texture coords if set (only for non-atlas)
            local ok, l, r, t, b = pcall(function() return sourceComponent:GetTexCoord() end)
            if ok and l then
                visual:SetTexCoord(l, r, t, b)
            end
        end
        
        -- Copy vertex color
        local vr, vg, vb, va = sourceComponent:GetVertexColor()
        if vr then visual:SetVertexColor(vr, vg, vb, va or 1) end
        
        -- Size based on source, scaled
        local srcWidth, srcHeight = 20, 20
        local ok, w = pcall(function() return sourceComponent:GetWidth() end)
        if ok and w and type(w) == "number" and w > 0 then srcWidth = w end
        local ok2, h = pcall(function() return sourceComponent:GetHeight() end)
        if ok2 and h and type(h) == "number" and h > 0 then srcHeight = h end
        
        container:SetSize(srcWidth, srcHeight)  -- TransformLayer handles zoom
    elseif isIconFrame then
        -- Clone Frame with Icon child (BigDefensive, aura frames, etc.)
        visual = container:CreateTexture(nil, "OVERLAY")
        visual:SetAllPoints(container)
        
        local iconTexture = sourceComponent.Icon
        local texturePath = iconTexture:GetTexture()
        if texturePath then
            visual:SetTexture(texturePath)
        end
        
        -- Copy texture coords
        local ok, l, r, t, b = pcall(function() return iconTexture:GetTexCoord() end)
        if ok and l then
            visual:SetTexCoord(l, r, t, b)
        end
        
        -- Size based on parent frame, scaled
        local srcWidth, srcHeight = 24, 24
        local ok, w = pcall(function() return sourceComponent:GetWidth() end)
        if ok and w and type(w) == "number" and w > 0 then srcWidth = w end
        local ok2, h = pcall(function() return sourceComponent:GetHeight() end)
        if ok2 and h and type(h) == "number" and h > 0 then srcHeight = h end
        
        container:SetSize(srcWidth, srcHeight)  -- TransformLayer handles zoom
    else
        -- Fallback: Create a simple label with key name
        visual = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        visual:SetPoint("CENTER", container, "CENTER", 0, 0)
        visual:SetText(key or "?")
        container:SetSize(60, 20)
    end
    
    container.visual = visual
    
    -- Border (subtle, visible on hover/drag)
    container.border = container:CreateTexture(nil, "BACKGROUND")
    container.border:SetAllPoints()
    container.border:SetColorTexture(0.3, 0.8, 0.3, 0)  -- Invisible by default
    
    -- Store center-relative position
    container.posX = startX
    container.posY = startY
    container.key = key
    container.isFontString = isFontString
    container.existingOverrides = data and data.overrides  -- Preserve saved style overrides
    
    -- Use saved anchor data if available, otherwise calculate from center position
    local halfW = preview.sourceWidth / 2
    local halfH = preview.sourceHeight / 2
    local anchorX, anchorY, offsetX, offsetY, justifyH
    
    if data and data.anchorX then
        -- Use saved anchor data (preserves exact edge-relative position)
        anchorX = data.anchorX
        anchorY = data.anchorY
        offsetX = data.offsetX
        offsetY = data.offsetY
        justifyH = data.justifyH
    else
        anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchor(startX, startY, halfW, halfH)
    end
    
    -- Store anchor data on container
    container.anchorX = anchorX
    container.anchorY = anchorY
    container.offsetX = offsetX
    container.offsetY = offsetY
    container.justifyH = justifyH

    
    -- Build anchor point for positioning (matches real frame logic)
    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
    
    -- Calculate finalX/finalY the same way as NudgeComponent for consistency
    local posX = startX  -- center-relative position
    local posY = startY
    
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
    
    -- Position using the same logic as NudgeComponent
    container:ClearAllPoints()
    if isFontString and justifyH ~= "CENTER" then
        container:SetPoint(justifyH, preview, anchorPoint, finalX, finalY)
    else
        container:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
    end
    
    -- Apply text alignment to visual
    if isFontString and visual then
        ApplyTextAlignment(container, visual, justifyH)
    end
    
    -- Click-vs-Drag detection: Track if this was a click or a drag
    -- Click = opens settings dialog, Drag = repositions component
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
            
            -- If no drag occurred and click was quick, treat as click to open settings
            if not self.wasDragged and clickDuration < 0.3 then
                -- Open component settings dialog
                if OrbitEngine.CanvasComponentSettings then
                    OrbitEngine.CanvasComponentSettings:Open(self.key, self, plugin, systemIndex)
                end
            end
            
            self.mouseDownTime = nil
            self.mouseDownX = nil
            self.mouseDownY = nil
        end
    end)
    
    -- Drag handlers with manual mouse tracking for live anchor updating
    container:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        
        -- Mark as dragged (prevents click from opening settings)
        self.wasDragged = true
        
        -- Get mouse position in screen coordinates
        local mx, my = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        mx = mx / uiScale
        my = my / uiScale
        
        -- Get component center in screen coordinates
        local compCenterX, compCenterY = self:GetCenter()
        
        -- Store click offset (where on the component they clicked, relative to its center)
        -- This prevents the component from snapping to cursor on drag start
        self.clickOffsetX = mx - compCenterX
        self.clickOffsetY = my - compCenterY
        
        -- Store initial local position for reference
        self.dragStartLocalX = self.posX or 0
        self.dragStartLocalY = self.posY or 0
        self.isDragging = true
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0.3)
    end)
    
    container:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local halfW = preview.sourceWidth / 2
            local halfH = preview.sourceHeight / 2
            
            -- Get current mouse position in screen coordinates
            local mx, my = GetCursorPosition()
            local uiScale = UIParent:GetEffectiveScale()
            mx = mx / uiScale
            my = my / uiScale
            
            -- Get preview center in screen coordinates
            local previewCenterX, previewCenterY = preview:GetCenter()
            
            -- Calculate component center position in screen pixels
            -- Subtract click offset so component doesn't snap to cursor
            local compScreenX = mx - (self.clickOffsetX or 0)
            local compScreenY = my - (self.clickOffsetY or 0)
            
            -- Calculate offset from preview center in screen pixels
            local screenOffsetX = compScreenX - previewCenterX
            local screenOffsetY = compScreenY - previewCenterY
            
            -- Convert to local (unscaled) coordinates by dividing by zoom
            local zoomLevel = Dialog.zoomLevel or 1
            local centerRelX = screenOffsetX / zoomLevel
            local centerRelY = screenOffsetY / zoomLevel
            
            -- Clamp to reasonable bounds (frame extents + padding)
            local CLAMP_PADDING_X = 100
            local CLAMP_PADDING_Y = 50
            centerRelX = math.max(-halfW - CLAMP_PADDING_X, math.min(halfW + CLAMP_PADDING_X, centerRelX))
            centerRelY = math.max(-halfH - CLAMP_PADDING_Y, math.min(halfH + CLAMP_PADDING_Y, centerRelY))
            
            -- Calculate anchor data using CalculateAnchor (includes CENTER_THRESHOLD)
            local anchorX, anchorY, edgeOffX, edgeOffY, justifyH = CalculateAnchor(centerRelX, centerRelY, halfW, halfH)
            
            -- For FontStrings, calculate edge offset based on JUSTIFY edge (not anchor edge)
            -- This prevents jarring jumps when justify flips
            if self.isFontString then
                -- Note: GetWidth() returns the logical size (SetSize value), unaffected by TransformLayer scale
                local containerW = self:GetWidth()
                local isOutsideLeft = centerRelX < -halfW
                local isOutsideRight = centerRelX > halfW
                
                if anchorX == "LEFT" then
                    justifyH = isOutsideLeft and "RIGHT" or "LEFT"
                    if justifyH == "LEFT" then
                        -- Text LEFT edge distance from frame LEFT
                        edgeOffX = centerRelX + halfW - containerW / 2
                    else
                        -- Text RIGHT edge distance from frame LEFT (outside)
                        edgeOffX = centerRelX + halfW + containerW / 2
                    end
                elseif anchorX == "RIGHT" then
                    justifyH = isOutsideRight and "LEFT" or "RIGHT"
                    if justifyH == "RIGHT" then
                        -- Text RIGHT edge distance from frame RIGHT
                        edgeOffX = halfW - centerRelX - containerW / 2
                    else
                        -- Text LEFT edge distance from frame RIGHT (outside)
                        edgeOffX = halfW - centerRelX + containerW / 2
                    end
                else
                    edgeOffX = 0
                    justifyH = "CENTER"
                end
            end
            
            -- Build anchor point and position the container
            -- IMPORTANT: During drag, always use CENTER anchor for smooth movement
            -- The edge-based anchoring is applied on drop (prevents jarring jumps when justify changes)
            local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
            
            -- Position by CENTER relative to anchor point during drag
            -- This keeps movement smooth regardless of justify changes
            local centerOffX = centerRelX
            local centerOffY = centerRelY
            
            -- Convert center-relative to anchor-relative offsets for display
            if anchorX == "LEFT" then
                centerOffX = centerRelX + halfW  -- Distance from left edge
            elseif anchorX == "RIGHT" then
                centerOffX = -(centerRelX - halfW)  -- Distance from right edge (positive = inward)
            else
                centerOffX = 0
            end
            
            if anchorY == "BOTTOM" then
                centerOffY = centerRelY + halfH
            elseif anchorY == "TOP" then
                centerOffY = -(centerRelY - halfH)
            else
                centerOffY = 0
            end
            
            -- Always position by CENTER during drag for smooth movement
            -- Note: SetPoint uses local (unscaled) coordinates - TransformLayer handles zoom
            self:ClearAllPoints()
            self:SetPoint("CENTER", preview, "CENTER", centerRelX, centerRelY)
            
            -- Update text alignment in preview
            if self.visual and self.isFontString then
                ApplyTextAlignment(self, self.visual, justifyH)
            end
            
            -- Store current values for OnDragStop
            self.anchorX = anchorX
            self.anchorY = anchorY
            self.offsetX = edgeOffX
            self.offsetY = edgeOffY
            self.justifyH = justifyH
            self.posX = centerRelX
            self.posY = centerRelY
            
            -- Show tooltip with live anchor info
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
        self.dragStartLocalX = nil  -- Clear for next drag
        self.dragStartLocalY = nil
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0)
        
        -- Snap center position to 5px grid for visual positioning
        local SNAP = 5
        local snappedX = math.floor((self.posX or 0) / SNAP + 0.5) * SNAP
        local snappedY = math.floor((self.posY or 0) / SNAP + 0.5) * SNAP
        self.posX = snappedX
        self.posY = snappedY
        
        -- Also snap the edge offsets (these were set correctly during OnUpdate)
        self.offsetX = math.floor((self.offsetX or 0) / SNAP + 0.5) * SNAP
        self.offsetY = math.floor((self.offsetY or 0) / SNAP + 0.5) * SNAP
        
        -- Position by CENTER (consistent with OnUpdate)
        self:ClearAllPoints()
        self:SetPoint("CENTER", preview, "CENTER", snappedX, snappedY)
    end)
    
    -- Hover effects + nudge tracking
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
    
    return container
end

-- [ SAVE ORIGINAL POSITIONS (for Cancel restore) ]----------------------------------------------

function Dialog:SaveOriginalPositions()
    self.originalPositions = {}
    if not self.targetPlugin or not self.targetPlugin.GetSetting then
        return
    end
    
    local positions = self.targetPlugin:GetSetting(self.targetSystemIndex, "ComponentPositions")
    if positions then
        -- Deep copy to avoid reference issues
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

-- [ OPEN DIALOG ]--------------------------------------------------------------------------------

function Dialog:Open(frame, plugin, systemIndex)
    if InCombatLockdown() then return false end
    if not frame then return false end
    
    -- Close Component Settings dialog if open (handles switching frames or reopening)
    if Orbit.CanvasComponentSettings and Orbit.CanvasComponentSettings:IsShown() then
        Orbit.CanvasComponentSettings:Hide()
    end
    
    -- Check if frame has a redirect for Canvas Mode (for container frames)
    local canvasFrame = frame.orbitCanvasFrame or frame
    
    -- Store references (keep original frame for component lookup)
    self.targetFrame = frame
    self.targetPlugin = plugin
    self.targetSystemIndex = systemIndex
    
    -- Update title (use custom canvas title if available)
    local title = frame.orbitCanvasTitle or canvasFrame.editModeName or canvasFrame:GetName() or "Frame"
    self.Title:SetText("Canvas Mode: " .. title)
    
    -- Clean up previous preview
    self:CleanupPreview()
    
    -- Reset zoom/pan state BEFORE creating preview (ensures consistent state)
    self.zoomLevel = DEFAULT_ZOOM
    self.panOffsetX = 0
    self.panOffsetY = 0
    self.TransformLayer:SetScale(DEFAULT_ZOOM)
    self.TransformLayer:ClearAllPoints()
    self.TransformLayer:SetPoint("CENTER", self.Viewport, "CENTER", 0, 0)
    if self.ZoomIndicator then
        self.ZoomIndicator:SetText(string.format("%.0f%%", DEFAULT_ZOOM * 100))
    end
    
    -- Create preview frame using Preview module (use redirected frame)
    -- Note: Preview scale is now 1 - actual zoom is handled by TransformLayer:SetScale()
    local textureName = plugin and plugin:GetSetting(systemIndex, "Texture") or "Melli"
    local borderSize = plugin and plugin:GetSetting(systemIndex, "BorderSize") or 1
    
    self.previewFrame = OrbitEngine.Preview.Frame:Create(canvasFrame, {
        scale = 1,  -- Base scale - zoom handled by TransformLayer
        parent = self.TransformLayer,  -- Parent to TransformLayer for zoom/pan
        borderSize = borderSize,
        textureName = textureName,
        useClassColor = true,
    })
    self.previewFrame:SetPoint("CENTER", self.TransformLayer, "CENTER", 0, 0)
    
    -- Store base dimensions on TransformLayer for pan clamping calculations
    self.TransformLayer.baseWidth = canvasFrame:GetWidth()
    self.TransformLayer.baseHeight = canvasFrame:GetHeight()
    self.TransformLayer:SetSize(self.TransformLayer.baseWidth, self.TransformLayer.baseHeight)
    
    -- Create draggable components based on registered components
    local savedPositions = plugin and plugin:GetSetting(systemIndex, "ComponentPositions") or {}
    
    -- Merge with defaults for any missing components
    local defaults = plugin and plugin.defaults and plugin.defaults.ComponentPositions
    if defaults then
        for key, defaultPos in pairs(defaults) do
            if not savedPositions[key] or not savedPositions[key].anchorX then
                savedPositions[key] = defaultPos
            end
        end
    end
    
    -- Get draggable components dynamically
    local dragComponents = OrbitEngine.ComponentDrag:GetComponentsForFrame(frame)
    local components = {}
    -- IMPORTANT: Use canvasFrame dimensions to match preview frame size
    local frameW = canvasFrame:GetWidth()
    local frameH = canvasFrame:GetHeight()
    
    local DEFAULTS = {
        Name = "Name",
        HealthText = "100%",
        CombatIcon = "Combat",
        Level = "70",
    }
    
    for key, data in pairs(dragComponents) do
        -- Get saved position from settings, or fall back to cached data from ComponentDrag
        local pos = savedPositions[key]
        
        -- If no saved position, check if ComponentDrag has cached positions
        if not pos and data.anchorX then
            -- Use cached position from ComponentDrag
            pos = { anchorX = data.anchorX, anchorY = data.anchorY, offsetX = data.offsetX, offsetY = data.offsetY, justifyH = data.justifyH }
        end
        
        local centerX, centerY = 0, 0
        local anchorX, anchorY = "CENTER", "CENTER"
        local offsetX, offsetY = 0, 0
        
        if pos and pos.anchorX then
            -- Edge-relative format (anchorX/Y, offsetX/Y) - single source of truth
            anchorX = pos.anchorX
            anchorY = pos.anchorY or "CENTER"
            offsetX = pos.offsetX or 0
            offsetY = pos.offsetY or 0
            
            -- Convert to center-relative for preview positioning
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
        elseif not pos then
            -- No saved position - calculate from defaults if component has a position
            -- This path should rarely be hit since we have defaults in plugin registration
            centerX = 0
            centerY = 0
        end
        
        -- Get justifyH from saved position or calculate based on center position
        local justifyH = pos and pos.justifyH
        if not justifyH then
            -- Calculate justifyH from center position
            local halfW = frameW / 2
            local isOutsideRight = centerX > halfW
            local isOutsideLeft = centerX < -halfW
            
            if centerX == 0 then
                justifyH = "CENTER"
            elseif centerX > 0 then
                justifyH = isOutsideRight and "LEFT" or "RIGHT"
            else
                justifyH = isOutsideLeft and "RIGHT" or "LEFT"
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
            overrides = pos and pos.overrides,  -- Preserve existing style overrides
        }
    end
    
    -- Create draggable clones for each component
    wipe(self.previewComponents)
    for key, data in pairs(components) do
        local comp = CreateDraggableComponent(self.previewFrame, key, data.component, data.x, data.y, data)
        self.previewComponents[key] = comp
    end
    
    -- Fixed dialog size (decoupled from frame dimensions)
    self:SetSize(DIALOG_WIDTH, DIALOG_HEIGHT)
    
    -- Layout footer buttons to stretch across dialog width
    self:LayoutFooterButtons()
    
    self:Show()
    return true
end

-- [ CLEANUP PREVIEW ]--------------------------------------------------------------------------

function Dialog:CleanupPreview()
    -- Hide and release preview components
    for key, comp in pairs(self.previewComponents) do
        comp:Hide()
        comp:SetParent(nil)
    end
    wipe(self.previewComponents)
    
    -- Hide and release preview frame
    if self.previewFrame then
        self.previewFrame:Hide()
        self.previewFrame:SetParent(nil)
        self.previewFrame = nil
    end
end

-- [ CLOSE DIALOG ]-----------------------------------------------------------------------------

function Dialog:CloseDialog()
    -- Close Component Settings popout if open
    if Orbit.CanvasComponentSettings and Orbit.CanvasComponentSettings:IsShown() then
        Orbit.CanvasComponentSettings:Hide()
    end
    
    self:CleanupPreview()
    
    -- Clear state
    self.targetFrame = nil
    self.targetPlugin = nil
    self.targetSystemIndex = nil
    wipe(self.originalPositions)
    
    self:Hide()
    
    -- Clear canvas mode state FIRST (before refreshing visuals)
    if OrbitEngine.ComponentEdit then
        OrbitEngine.ComponentEdit.currentFrame = nil
    end
    
    -- Refresh selection visuals (now shows normal Edit Mode appearance)
    if OrbitEngine.FrameSelection then
        OrbitEngine.FrameSelection:RefreshVisuals()
    end
end

-- [ APPLY ]--------------------------------------------------------------------------------------

function Dialog:Apply()
    if not self.targetPlugin then
        self:CloseDialog()
        return
    end
    
    if not self.previewFrame then
        self:CloseDialog()
        return
    end
    
    -- Collect positions from containers (already calculated during drag/nudge)
    local positions = {}
    local halfWidth = self.previewFrame.sourceWidth / 2
    local halfHeight = self.previewFrame.sourceHeight / 2
    
    for key, comp in pairs(self.previewComponents) do
        -- Use anchor data stored on container, or calculate if missing
        local anchorX = comp.anchorX
        local anchorY = comp.anchorY
        local offsetX = comp.offsetX
        local offsetY = comp.offsetY
        local justifyH = comp.justifyH
        
        -- If anchor data not set (component wasn't moved), calculate from posX/posY
        if not anchorX then
            local posX = comp.posX or 0
            local posY = comp.posY or 0
            anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchor(posX, posY, halfWidth, halfHeight)
        end
        
        -- Save EDGE-RELATIVE format (matches what UnitButton expects)
        positions[key] = {
            anchorX = anchorX,
            anchorY = anchorY,
            offsetX = offsetX,
            offsetY = offsetY,
            justifyH = justifyH,
        }
        
        -- Include style overrides if set via Component Settings dialog
        if comp.pendingOverrides then
            positions[key].overrides = comp.pendingOverrides
        elseif comp.existingOverrides then
            -- Preserve existing overrides if component wasn't edited
            positions[key].overrides = comp.existingOverrides
        end
    end
    
    -- Save references before closing
    local plugin = self.targetPlugin
    local systemIndex = self.targetSystemIndex
    
    -- Save positions to plugin settings
    plugin:SetSetting(systemIndex, "ComponentPositions", positions)
    
    -- Close dialog FIRST (clears canvas mode state)
    self:CloseDialog()
    
    -- NOW apply settings - isInCanvasMode will be false so positions will be restored
    if plugin.ApplySettings then
        plugin:ApplySettings()
    end
end

-- [ CANCEL ]-------------------------------------------------------------------------------------

function Dialog:Cancel()
    -- Just close the dialog - saved data was never modified
    -- Preview changes are discarded, original positions remain intact
    self:CloseDialog()
end

-- [ RESET POSITIONS ]--------------------------------------------------------------------------

function Dialog:ResetPositions()
    if not self.targetPlugin or not self.previewFrame then return end
    
    local plugin = self.targetPlugin
    local defaults = plugin.defaults and plugin.defaults.ComponentPositions
    if not defaults then return end
    
    local preview = self.previewFrame
    local halfW = preview.sourceWidth / 2
    local halfH = preview.sourceHeight / 2
    
    -- Reset each preview container to its default position
    for key, container in pairs(self.previewComponents) do
        local defaultPos = defaults[key]
        if defaultPos and defaultPos.anchorX then
            -- Update container's stored position data
            container.anchorX = defaultPos.anchorX
            container.anchorY = defaultPos.anchorY or "CENTER"
            container.offsetX = defaultPos.offsetX or 0
            container.offsetY = defaultPos.offsetY or 0
            container.justifyH = defaultPos.justifyH or "CENTER"
            
            -- Clear any pending or existing style overrides so they reset to global defaults
            container.pendingOverrides = nil
            container.existingOverrides = nil
            
            -- Calculate center-relative position for posX/posY (used by nudge)
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
            
            -- Build anchor point for positioning (matches real frame logic)
            local anchorPoint = BuildAnchorPoint(container.anchorX, container.anchorY)
            
            -- Calculate finalX/finalY using edge-relative logic (same as NudgeComponent)
            local finalX, finalY
            if container.anchorX == "CENTER" then
                finalX = container.posX
            else
                finalX = container.offsetX
                if container.anchorX == "RIGHT" then finalX = -finalX end
            end
            
            if container.anchorY == "CENTER" then
                finalY = container.posY
            else
                finalY = container.offsetY
                if container.anchorY == "TOP" then finalY = -finalY end
            end
            
            -- Reposition using the same logic as NudgeComponent
            container:ClearAllPoints()
            if container.isFontString and container.justifyH ~= "CENTER" then
                container:SetPoint(container.justifyH, preview, anchorPoint, finalX, finalY)
            else
                container:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
            end
            
            -- Update text alignment
            if container.visual and container.isFontString then
                ApplyTextAlignment(container, container.visual, container.justifyH)
                
                -- Reset font to global defaults from plugin or Constants
                local globalFont = Orbit.Constants.Settings and Orbit.Constants.Settings.Font
                local defaultFontName = globalFont and globalFont.Default or "PT Sans Narrow"
                local defaultFontSize = globalFont and globalFont.DefaultSize or 12
                
                local fontPath = LSM:Fetch("font", defaultFontName)
                if fontPath and container.visual.SetFont then
                    local _, _, flags = container.visual:GetFont()
                    container.visual:SetFont(fontPath, defaultFontSize, flags or "")
                end
                
                -- Reset shadow to default (off)
                if container.visual.SetShadowOffset then
                    container.visual:SetShadowOffset(0, 0)
                end
            elseif container.visual and container.visual.GetObjectType and container.visual:GetObjectType() == "Texture" then
                -- Reset texture to original size (scale = 1)
                local origW = container.originalVisualWidth or container:GetWidth() or 18
                local origH = container.originalVisualHeight or container:GetHeight() or 18
                container.visual:ClearAllPoints()
                container.visual:SetAllPoints(container)  -- Reset to fill container
                -- Clear cached original size so next scale starts fresh
                container.originalVisualWidth = nil
                container.originalVisualHeight = nil
            end
        end
    end
end

-- [ EDIT MODE LIFECYCLE ]------------------------------------------------------------------------

if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", function()
        if Dialog:IsShown() then
            Dialog:Cancel()
        end
    end)
end

-- [ EXPORT ]-------------------------------------------------------------------------------------

Orbit.CanvasModeDialog = Dialog
OrbitEngine.CanvasModeDialog = Dialog
