-- [ CANVAS MODE DIALOG ]------------------------------------------------------------
-- Dedicated dialog for editing frame component positions using a PREVIEW REPLICA
-- Real frame stays in place - we create a fake preview and drag components on that
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-------------------------------------------------
-- CONSTANTS
-------------------------------------------------
local DIALOG_WIDTH = 450
local DIALOG_MIN_HEIGHT = 200
local DEFAULT_PREVIEW_SCALE = 1.0  -- Default preview scale
local MIN_PREVIEW_SCALE = 0.5
local MAX_PREVIEW_SCALE = 1.5
local SCALE_STEP = 0.1
local PREVIEW_SCALE = DEFAULT_PREVIEW_SCALE  -- Current preview scale (updated by scroll)
local PREVIEW_PADDING = 30
local FOOTER_HEIGHT = 55
local TITLE_HEIGHT = 40

-------------------------------------------------
-- CREATE DIALOG FRAME
-------------------------------------------------
local Dialog = CreateFrame("Frame", "OrbitCanvasModeDialog", UIParent, "BackdropTemplate")
Dialog:SetSize(DIALOG_WIDTH, DIALOG_MIN_HEIGHT)
Dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
Dialog:SetFrameStrata("FULLSCREEN_DIALOG")
Dialog:SetFrameLevel(100)
Dialog:SetMovable(true)
Dialog:SetClampedToScreen(true)
Dialog:EnableMouse(true)
Dialog:RegisterForDrag("LeftButton")
Dialog:Hide()

-- Backdrop
Dialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
Dialog:SetBackdropColor(0.05, 0.05, 0.05, 0.98)

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

-------------------------------------------------
-- TITLE
-------------------------------------------------
Dialog.Title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
Dialog.Title:SetPoint("TOP", Dialog, "TOP", 0, -15)
Dialog.Title:SetText("Canvas Mode")

-------------------------------------------------
-- CLOSE BUTTON
-------------------------------------------------
Dialog.CloseButton = CreateFrame("Button", nil, Dialog, "UIPanelCloseButton")
Dialog.CloseButton:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", -2, -2)
Dialog.CloseButton:SetScript("OnClick", function()
    Dialog:Cancel()
end)

-------------------------------------------------
-- PREVIEW CONTAINER
-------------------------------------------------
Dialog.PreviewContainer = CreateFrame("Frame", nil, Dialog)
Dialog.PreviewContainer:SetPoint("TOPLEFT", Dialog, "TOPLEFT", PREVIEW_PADDING, -TITLE_HEIGHT)
Dialog.PreviewContainer:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -PREVIEW_PADDING, FOOTER_HEIGHT)
Dialog.PreviewContainer:EnableMouseWheel(true)

-- Mouse wheel to zoom preview
Dialog.PreviewContainer:SetScript("OnMouseWheel", function(self, delta)
    local newScale = PREVIEW_SCALE + (delta * SCALE_STEP)
    newScale = math.max(MIN_PREVIEW_SCALE, math.min(MAX_PREVIEW_SCALE, newScale))
    
    -- Round to 1 decimal place to avoid floating point issues
    newScale = math.floor(newScale * 10 + 0.5) / 10
    
    if newScale ~= PREVIEW_SCALE then
        PREVIEW_SCALE = newScale
        
        -- Rebuild preview at new scale
        if Dialog.targetFrame and Dialog:IsShown() then
            Dialog:Open(Dialog.targetFrame, Dialog.targetPlugin, Dialog.targetSystemIndex)
        end
    end
end)

-- No background texture - the preview frame will provide its own visuals

-------------------------------------------------
-- FOOTER (Using proper Orbit pattern: divider + stretch-to-fill buttons)
-------------------------------------------------
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

-------------------------------------------------
-- ESC KEY SUPPORT
-------------------------------------------------
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
            C_Timer.After(0.05, function()
                if not InCombatLockdown() then
                    self:SetPropagateKeyboardInput(true)
                end
            end)
        else
            self:SetPropagateKeyboardInput(true)
        end
    else
        self:SetPropagateKeyboardInput(true)
    end
end)

-------------------------------------------------
-- STATE
-------------------------------------------------
Dialog.targetFrame = nil
Dialog.targetPlugin = nil
Dialog.targetSystemIndex = nil
Dialog.originalPositions = {}
Dialog.previewFrame = nil
Dialog.previewComponents = {}  -- { key = container }
Dialog.hoveredComponent = nil  -- Currently hovered component for nudge

-- Helper: Calculate anchor type, edge offsets, and justifyH based on center-relative position
-- Returns: anchorX, anchorY, offsetX, offsetY, justifyH
local function CalculateAnchor(posX, posY, halfW, halfH)
    local anchorX, offsetX, justifyH
    local anchorY, offsetY
    local isOutsideRight = posX > halfW
    local isOutsideLeft = posX < -halfW
    local CENTER_THRESHOLD = 10  -- Within 10px of center = CENTER anchor
    
    -- X axis: anchor to nearest horizontal edge (with center threshold)
    if posX > CENTER_THRESHOLD then
        anchorX = "RIGHT"
        offsetX = halfW - posX  -- distance from right edge (negative if outside)
        -- Inside: text grows LEFT (toward center), Outside: text grows RIGHT (away)
        justifyH = isOutsideRight and "LEFT" or "RIGHT"
    elseif posX < -CENTER_THRESHOLD then
        anchorX = "LEFT"
        offsetX = halfW + posX  -- distance from left edge (negative if outside)
        -- Inside: text grows RIGHT (toward center), Outside: text grows LEFT (away)
        justifyH = isOutsideLeft and "RIGHT" or "LEFT"
    else
        anchorX = "CENTER"
        offsetX = 0
        justifyH = "CENTER"
    end
    
    -- Y axis: anchor to nearest vertical edge (with center threshold)
    if posY > CENTER_THRESHOLD then
        anchorY = "TOP"
        offsetY = halfH - posY  -- distance from top edge
    elseif posY < -CENTER_THRESHOLD then
        anchorY = "BOTTOM"
        offsetY = halfH + posY  -- distance from bottom edge
    else
        anchorY = "CENTER"
        offsetY = 0
    end
    
    return anchorX, anchorY, offsetX, offsetY, justifyH
end

-- Build anchor point string from anchorX and anchorY
local function BuildAnchorPoint(anchorX, anchorY)
    if anchorY == "CENTER" and anchorX == "CENTER" then
        return "CENTER"
    elseif anchorY == "CENTER" then
        return anchorX
    elseif anchorX == "CENTER" then
        return anchorY
    else
        return anchorY .. anchorX  -- e.g., "TOPLEFT", "BOTTOMRIGHT"
    end
end

-- Apply alignment to a FontString visual within its container
local function ApplyTextAlignment(container, visual, justifyH)
    visual:ClearAllPoints()
    visual:SetPoint(justifyH, container, justifyH, 0, 0)
    visual:SetJustifyH(justifyH)
end

-------------------------------------------------
-- NUDGE COMPONENT
-------------------------------------------------
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
    if direction == "LEFT" then
        if anchorX == "LEFT" then
            offsetX = offsetX - NUDGE  -- Move toward left edge
        elseif anchorX == "RIGHT" then
            offsetX = offsetX + NUDGE  -- Move away from right edge
        else
            container.posX = (container.posX or 0) - NUDGE
        end
    elseif direction == "RIGHT" then
        if anchorX == "LEFT" then
            offsetX = offsetX + NUDGE  -- Move away from left edge
        elseif anchorX == "RIGHT" then
            offsetX = offsetX - NUDGE  -- Move toward right edge
        else
            container.posX = (container.posX or 0) + NUDGE
        end
    elseif direction == "UP" then
        if anchorY == "TOP" then
            offsetY = offsetY - NUDGE  -- Move toward top edge
        elseif anchorY == "BOTTOM" then
            offsetY = offsetY + NUDGE  -- Move away from bottom edge
        else
            container.posY = (container.posY or 0) + NUDGE
        end
    elseif direction == "DOWN" then
        if anchorY == "TOP" then
            offsetY = offsetY + NUDGE  -- Move away from top edge
        elseif anchorY == "BOTTOM" then
            offsetY = offsetY - NUDGE  -- Move toward bottom edge
        else
            container.posY = (container.posY or 0) - NUDGE
        end
    end
    
    -- Store updated offset (anchor stays the same)
    container.offsetX = offsetX
    container.offsetY = offsetY
    
    -- Reposition the container
    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
    local finalX = offsetX * PREVIEW_SCALE
    local finalY = offsetY * PREVIEW_SCALE
    if anchorX == "RIGHT" then finalX = -finalX end
    if anchorY == "TOP" then finalY = -finalY end
    
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

-------------------------------------------------
-- CREATE PREVIEW FRAME
-------------------------------------------------
local function CreatePreviewFrame(sourceFrame)
    local plugin = Dialog.targetPlugin
    local systemIndex = Dialog.targetSystemIndex
    
    -- 1. Create Container (Background)
    local preview = CreateFrame("Frame", nil, Dialog.PreviewContainer, "BackdropTemplate")
    
    -- Size based on source frame (Scaled)
    local width = sourceFrame:GetWidth() * PREVIEW_SCALE
    local height = sourceFrame:GetHeight() * PREVIEW_SCALE
    preview:SetSize(width, height)
    preview:SetPoint("CENTER", Dialog.PreviewContainer, "CENTER", 0, 0)
    
    -- 2. Get Settings from Plugin (or defaults)
    local textureName = plugin and plugin:GetSetting(systemIndex, "Texture") or "Melli"
    local borderSize = plugin and plugin:GetSetting(systemIndex, "BorderSize") or 1
    
    -- 3. Set Backdrop (Orbit Style)
    local bgColor = Orbit.Constants.Colors.Background
    preview:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = borderSize * PREVIEW_SCALE, -- Scale border too
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    preview:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    preview:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- 4. Create Health Bar (Texture)
    local bar = CreateFrame("StatusBar", nil, preview)
    bar:SetAllPoints()
    -- Apply border insets to bar so it sits inside the border
    local inset = borderSize * PREVIEW_SCALE
    bar:SetPoint("TOPLEFT", preview, "TOPLEFT", inset, -inset)
    bar:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -inset, inset)
    
    local texturePath = LSM:Fetch("statusbar", textureName)
    bar:SetStatusBarTexture(texturePath)
    
    -- Use Class Color for the bar
    local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
    if classColor then
        bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
    else
        bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
    end
    
    -- Store reference for later
    preview.Health = bar
    
    preview.sourceWidth = sourceFrame:GetWidth()
    preview.sourceHeight = sourceFrame:GetHeight()
    
    return preview
end


-------------------------------------------------
-- CREATE DRAGGABLE COMPONENT
-------------------------------------------------
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
    
    if isFontString then
        -- Clone FontString
        visual = container:CreateFontString(nil, "OVERLAY")
        
        -- MUST set font BEFORE text (WoW requirement)
        local fontPath, fontSize, fontFlags = sourceComponent:GetFont()
        if fontPath and fontSize then
            -- Scale the font for preview
            visual:SetFont(fontPath, fontSize * PREVIEW_SCALE, fontFlags or "")
        else
            -- Fallback to Orbit's global font
            local globalFontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
            local fallbackPath = LSM:Fetch("font", globalFontName) or Orbit.Constants.Settings.Font.FallbackPath
            local fallbackSize = (Orbit.Constants.UI.UnitFrameTextSize or 12) * PREVIEW_SCALE
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
        if sx then visual:SetShadowOffset(sx * PREVIEW_SCALE, sy * PREVIEW_SCALE) end
        
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
        
        container:SetSize(srcWidth * PREVIEW_SCALE, srcHeight * PREVIEW_SCALE)
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
        print("[CreateDraggable] " .. key .. " USING SAVED: anchorX=" .. tostring(anchorX) .. " offsetX=" .. tostring(offsetX))
    else
        -- Calculate anchor data from center position (new/unmoved component)
        anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchor(startX, startY, halfW, halfH)
        print("[CreateDraggable] " .. key .. " CALCULATED: anchorX=" .. tostring(anchorX) .. " offsetX=" .. tostring(offsetX))
    end
    
    -- Store anchor data on container
    container.anchorX = anchorX
    container.anchorY = anchorY
    container.offsetX = offsetX
    container.offsetY = offsetY
    container.justifyH = justifyH
    print("[CreateDraggable] STORED on container: " .. key .. " offsetX=" .. tostring(container.offsetX))
    
    -- Build anchor point for positioning (matches real frame logic)
    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
    
    -- Calculate final offset with sign adjustment for anchor direction
    local finalX = offsetX * PREVIEW_SCALE
    local finalY = offsetY * PREVIEW_SCALE
    if anchorX == "RIGHT" then finalX = -finalX end
    if anchorY == "TOP" then finalY = -finalY end
    
    -- Position container to match real frame anchoring
    container:ClearAllPoints()
    if isFontString and justifyH ~= "CENTER" then
        -- FontStrings with LEFT/RIGHT justification: anchor by that edge
        container:SetPoint(justifyH, preview, anchorPoint, finalX, finalY)
    else
        -- CENTER justified or non-FontStrings: anchor by CENTER
        container:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
    end
    
    -- Apply text alignment to visual
    if isFontString and visual then
        ApplyTextAlignment(container, visual, justifyH)
    end
    
    -- Drag handlers with manual mouse tracking for live anchor updating
    container:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        -- Store initial mouse position and frame center for offset tracking
        local mx, my = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self.dragStartMouseX = mx / scale
        self.dragStartMouseY = my / scale
        self.dragStartCenterX, self.dragStartCenterY = self:GetCenter()
        self.isDragging = true
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0.3)
    end)
    
    container:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local halfW = preview.sourceWidth / 2
            local halfH = preview.sourceHeight / 2
            
            -- Get current mouse position
            local mx, my = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            mx = mx / scale
            my = my / scale
            
            -- Calculate new center based on mouse delta
            local deltaX = mx - self.dragStartMouseX
            local deltaY = my - self.dragStartMouseY
            local newCenterX = self.dragStartCenterX + deltaX
            local newCenterY = self.dragStartCenterY + deltaY
            
            -- Clamp to preview bounds with padding (X=100px, Y=50px)
            local CLAMP_PADDING_X = 100
            local CLAMP_PADDING_Y = 50
            local containerW = self:GetWidth()
            local containerH = self:GetHeight()
            local pLeft = preview:GetLeft() - CLAMP_PADDING_X + containerW / 2
            local pRight = preview:GetRight() + CLAMP_PADDING_X - containerW / 2
            local pBottom = preview:GetBottom() - CLAMP_PADDING_Y + containerH / 2
            local pTop = preview:GetTop() + CLAMP_PADDING_Y - containerH / 2
            
            newCenterX = math.max(pLeft, math.min(pRight, newCenterX))
            newCenterY = math.max(pBottom, math.min(pTop, newCenterY))
            
            -- Calculate center-relative position (in logical/unscaled pixels)
            local previewCenterX = preview:GetLeft() + preview:GetWidth() / 2
            local previewCenterY = preview:GetBottom() + preview:GetHeight() / 2
            local centerRelX = (newCenterX - previewCenterX) / PREVIEW_SCALE
            local centerRelY = (newCenterY - previewCenterY) / PREVIEW_SCALE
            
            -- Calculate anchor data using CalculateAnchor (includes CENTER_THRESHOLD)
            local anchorX, anchorY, edgeOffX, edgeOffY, justifyH = CalculateAnchor(centerRelX, centerRelY, halfW, halfH)
            
            -- For FontStrings, recalculate edge offset from actual edge position
            if self.isFontString then
                if anchorX == "LEFT" then
                    -- Distance from preview LEFT to container LEFT
                    local containerLeft = newCenterX - containerW / 2
                    edgeOffX = (containerLeft - preview:GetLeft()) / PREVIEW_SCALE
                    justifyH = "LEFT"
                elseif anchorX == "RIGHT" then
                    -- Distance from container RIGHT to preview RIGHT
                    local containerRight = newCenterX + containerW / 2
                    edgeOffX = (preview:GetRight() - containerRight) / PREVIEW_SCALE
                    justifyH = "RIGHT"
                else
                    edgeOffX = 0
                    justifyH = "CENTER"
                end
            end
            
            -- Build anchor point and position the container with proper anchoring
            local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
            local finalX = edgeOffX * PREVIEW_SCALE
            local finalY = edgeOffY * PREVIEW_SCALE
            if anchorX == "RIGHT" then finalX = -finalX end
            if anchorY == "TOP" then finalY = -finalY end
            
            self:ClearAllPoints()
            if self.isFontString and justifyH ~= "CENTER" then
                self:SetPoint(justifyH, preview, anchorPoint, finalX, finalY)
            else
                self:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
            end
            
            -- Update text alignment
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
        print("[OnDragStop] " .. key .. " FIRED!")
        self.isDragging = false
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0)
        
        -- Snap offsets to 5px grid (values were already set during OnUpdate)
        local SNAP = 5
        self.offsetX = math.floor((self.offsetX or 0) / SNAP + 0.5) * SNAP
        self.offsetY = math.floor((self.offsetY or 0) / SNAP + 0.5) * SNAP
        
        -- Re-apply final position with snapped values
        local anchorPoint = BuildAnchorPoint(self.anchorX or "CENTER", self.anchorY or "CENTER")
        local finalX = self.offsetX * PREVIEW_SCALE
        local finalY = self.offsetY * PREVIEW_SCALE
        if self.anchorX == "RIGHT" then finalX = -finalX end
        if self.anchorY == "TOP" then finalY = -finalY end
        
        self:ClearAllPoints()
        if self.isFontString and self.justifyH and self.justifyH ~= "CENTER" then
            self:SetPoint(self.justifyH, preview, anchorPoint, finalX, finalY)
        else
            self:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
        end
        
        print("[OnDragStop] Final: anchorX=" .. tostring(self.anchorX) .. " offsetX=" .. tostring(self.offsetX) .. " justifyH=" .. tostring(self.justifyH))
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

-------------------------------------------------
-- SAVE ORIGINAL POSITIONS (for Cancel restore)
-------------------------------------------------
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

-------------------------------------------------
-- OPEN DIALOG
-------------------------------------------------
function Dialog:Open(frame, plugin, systemIndex)
    if InCombatLockdown() then return false end
    if not frame then return false end
    
    -- Store references
    self.targetFrame = frame
    self.targetPlugin = plugin
    self.targetSystemIndex = systemIndex
    
    -- Update title
    local title = frame.editModeName or frame:GetName() or "Frame"
    self.Title:SetText("Canvas Mode: " .. title)
    
    -- Clean up previous preview
    self:CleanupPreview()
    
    -- Create preview frame
    self.previewFrame = CreatePreviewFrame(frame)
    
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
    local frameW = frame:GetWidth()
    local frameH = frame:GetHeight()
    
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
        }
    end
    
    -- Create draggable clones for each component
    wipe(self.previewComponents)
    for key, data in pairs(components) do
        local comp = CreateDraggableComponent(self.previewFrame, key, data.component, data.x, data.y, data)
        self.previewComponents[key] = comp
    end
    
    -- Size dialog based on source frame (height + 200px, width + 400px)
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()
    local dialogWidth = math.max(DIALOG_WIDTH, (frameWidth * PREVIEW_SCALE) + 400)
    local dialogHeight = math.max(DIALOG_MIN_HEIGHT, (frameHeight * PREVIEW_SCALE) + 200)
    self:SetSize(dialogWidth, dialogHeight)
    
    -- Layout footer buttons to stretch across dialog width
    self:LayoutFooterButtons()
    
    self:Show()
    return true
end

-------------------------------------------------
-- CLEANUP PREVIEW
-------------------------------------------------
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

-------------------------------------------------
-- CLOSE DIALOG
-------------------------------------------------
function Dialog:CloseDialog()
    self:CleanupPreview()
    
    -- Clear state
    self.targetFrame = nil
    self.targetPlugin = nil
    self.targetSystemIndex = nil
    wipe(self.originalPositions)
    
    self:Hide()
    
    -- Refresh selection visuals
    if OrbitEngine.FrameSelection then
        OrbitEngine.FrameSelection:RefreshVisuals()
    end
    
    -- Clear canvas mode state
    if OrbitEngine.ComponentEdit then
        OrbitEngine.ComponentEdit.currentFrame = nil
    end
end

-------------------------------------------------
-- APPLY
-------------------------------------------------
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
        
        print("[Apply] " .. key .. " anchorX=" .. tostring(anchorX) .. " offsetX=" .. tostring(offsetX) .. " justifyH=" .. tostring(justifyH))
        
        -- If anchor data not set (component wasn't moved), calculate from posX/posY
        if not anchorX then
            local posX = comp.posX or 0
            local posY = comp.posY or 0
            print("[Apply]   Fallback: calculating from posX=" .. posX .. " posY=" .. posY)
            anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchor(posX, posY, halfWidth, halfHeight)
            print("[Apply]   Calculated: anchorX=" .. tostring(anchorX) .. " offsetX=" .. tostring(offsetX))
        end
        
        -- Save EDGE-RELATIVE format (matches what UnitButton expects)
        positions[key] = {
            anchorX = anchorX,
            anchorY = anchorY,
            offsetX = offsetX,
            offsetY = offsetY,
            justifyH = justifyH,
        }
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

-------------------------------------------------
-- CANCEL
-------------------------------------------------
function Dialog:Cancel()
    -- Just close the dialog - saved data was never modified
    -- Preview changes are discarded, original positions remain intact
    self:CloseDialog()
end

-------------------------------------------------
-- RESET POSITIONS
-------------------------------------------------
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
            
            -- Reposition the visual container in the preview
            local anchorPoint = BuildAnchorPoint(container.anchorX, container.anchorY)
            local finalX = container.offsetX * PREVIEW_SCALE
            local finalY = container.offsetY * PREVIEW_SCALE
            if container.anchorX == "RIGHT" then finalX = -finalX end
            if container.anchorY == "TOP" then finalY = -finalY end
            
            container:ClearAllPoints()
            if container.isFontString and container.justifyH ~= "CENTER" then
                container:SetPoint(container.justifyH, preview, anchorPoint, finalX, finalY)
            else
                container:SetPoint("CENTER", preview, anchorPoint, finalX, finalY)
            end
            
            -- Update text alignment
            if container.visual and container.isFontString then
                ApplyTextAlignment(container, container.visual, container.justifyH)
            end
        end
    end
end

-------------------------------------------------
-- EDIT MODE LIFECYCLE
-------------------------------------------------
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", function()
        if Dialog:IsShown() then
            Dialog:Cancel()
        end
    end)
end

-------------------------------------------------
-- EXPORT
-------------------------------------------------
Orbit.CanvasModeDialog = Dialog
OrbitEngine.CanvasModeDialog = Dialog
