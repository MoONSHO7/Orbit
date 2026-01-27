-- [ CANVAS MODE - DOCK ]------------------------------------------------------------
-- Disabled Components Dock for Canvas Mode
-- Components dragged here are hidden from the frame
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local C = CanvasMode.Constants
local Layout = OrbitEngine.Layout
local Constants = Orbit.Constants

-- Calculate positions: Footer height = TopPadding(12) + ButtonHeight(20) + BottomPadding(12) = 44
-- Footer starts at DIALOG_INSET(12) from bottom, so footer top is at 12 + 44 = 56
-- Dock is 2px above footer top
local DOCK_BOTTOM_OFFSET = C.DIALOG_INSET + Constants.Footer.TopPadding + Constants.Footer.ButtonHeight + Constants.Footer.BottomPadding + 2

Dialog.DisabledDock = CreateFrame("Frame", nil, Dialog)
Dialog.DisabledDock:SetPoint("BOTTOMLEFT", Dialog, "BOTTOMLEFT", C.DIALOG_INSET, DOCK_BOTTOM_OFFSET)
Dialog.DisabledDock:SetPoint("BOTTOMRIGHT", Dialog, "BOTTOMRIGHT", -C.DIALOG_INSET, DOCK_BOTTOM_OFFSET)
Dialog.DisabledDock:SetHeight(C.DOCK_HEIGHT)

-- Dock label
Dialog.DisabledDock.Label = Dialog.DisabledDock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.DisabledDock.Label:SetPoint("TOPLEFT", Dialog.DisabledDock, "TOPLEFT", C.DOCK_PADDING, -4)
Dialog.DisabledDock.Label:SetText("Disabled Components")
Dialog.DisabledDock.Label:SetTextColor(0.6, 0.6, 0.6, 1)

-- Zoom indicator (right-aligned in header row)
Dialog.DisabledDock.ZoomIndicator = Dialog.DisabledDock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.DisabledDock.ZoomIndicator:SetPoint("TOPRIGHT", Dialog.DisabledDock, "TOPRIGHT", -C.DOCK_PADDING, -4)
Dialog.DisabledDock.ZoomIndicator:SetText(string.format("%.0f%%", C.DEFAULT_ZOOM * 100))
Dialog.DisabledDock.ZoomIndicator:SetTextColor(0.6, 0.6, 0.6, 1)

-- Dock hint text (shown when empty)
Dialog.DisabledDock.EmptyHint = Dialog.DisabledDock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.DisabledDock.EmptyHint:SetPoint("CENTER", Dialog.DisabledDock, "CENTER", 0, -4)
Dialog.DisabledDock.EmptyHint:SetText("Drag icons here to disable")
Dialog.DisabledDock.EmptyHint:SetTextColor(0.5, 0.5, 0.5, 0.7)

-- Container for dock component icons
Dialog.DisabledDock.IconContainer = CreateFrame("Frame", nil, Dialog.DisabledDock)
Dialog.DisabledDock.IconContainer:SetPoint("TOPLEFT", Dialog.DisabledDock, "TOPLEFT", C.DOCK_PADDING, -18)
Dialog.DisabledDock.IconContainer:SetPoint("BOTTOMRIGHT", Dialog.DisabledDock, "BOTTOMRIGHT", -C.DOCK_PADDING, C.DOCK_PADDING)

-- Drop highlight for dock (shows when dragging component over dock)
Dialog.DisabledDock.DropHighlight = Dialog.DisabledDock:CreateTexture(nil, "ARTWORK")
Dialog.DisabledDock.DropHighlight:SetAllPoints()
Dialog.DisabledDock.DropHighlight:SetColorTexture(0.3, 0.8, 0.3, 0.2)
Dialog.DisabledDock.DropHighlight:Hide()

-- [ DOCK LAYOUT ]------------------------------------------------------------------------

function Dialog:LayoutDockIcons()
    local x = 0
    local iconCount = 0
    
    for key, icon in pairs(self.dockComponents) do
        if icon:IsShown() then
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", self.DisabledDock.IconContainer, "TOPLEFT", x, 0)
            x = x + C.DOCK_ICON_SIZE + C.DOCK_ICON_SPACING
            iconCount = iconCount + 1
        end
    end
    
    -- Show/hide empty hint based on whether there are icons
    self.DisabledDock.EmptyHint:SetShown(iconCount == 0)
end

-- [ ADD TO DOCK ]------------------------------------------------------------------------

function Dialog:AddToDock(key, sourceComponent)
    if self.dockComponents[key] then
        return  -- Already in dock
    end
    
    -- Create a dock icon
    local icon = CreateFrame("Button", nil, self.DisabledDock.IconContainer)
    icon:SetSize(C.DOCK_ICON_SIZE, C.DOCK_ICON_SIZE)
    icon.key = key
    
    -- Background
    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetAllPoints()
    icon.bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
    
    -- Icon visual
    local isTexture = sourceComponent and sourceComponent.GetTexture
    local isFontString = sourceComponent and sourceComponent.GetText
    
    if isTexture and not isFontString then
        icon.visual = icon:CreateTexture(nil, "OVERLAY")
        icon.visual:SetPoint("CENTER")
        icon.visual:SetSize(C.DOCK_ICON_SIZE - 4, C.DOCK_ICON_SIZE - 4)
        
        -- Copy atlas or texture
        local atlasName = sourceComponent.GetAtlas and sourceComponent:GetAtlas()
        if atlasName then
            icon.visual:SetAtlas(atlasName)
        else
            local texturePath = sourceComponent:GetTexture()
            if texturePath then
                icon.visual:SetTexture(texturePath)
            end
            
            -- Copy TexCoord from source if available
            if sourceComponent.GetTexCoord then
                local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = sourceComponent:GetTexCoord()
                if ULx and ULy then
                    if LRx then
                        icon.visual:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
                    else
                        icon.visual:SetTexCoord(ULx, ULy, LLx, LLy)
                    end
                end
            end
            
            -- Fallback for MarkerIcon using shared constant
            if key == "MarkerIcon" then
                local tc = Orbit.MarkerIconTexCoord
                if tc then
                    icon.visual:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
                end
            end
            
            -- Handle sprite sheet (legacy Orbit sprite system)
            if sourceComponent.orbitSpriteIndex then
                local index = sourceComponent.orbitSpriteIndex
                local rows = sourceComponent.orbitSpriteRows or 4
                local cols = sourceComponent.orbitSpriteCols or 4
                local col = (index - 1) % cols
                local row = math.floor((index - 1) / cols)
                local w = 1 / cols
                local h = 1 / rows
                icon.visual:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
            end
        end
        
        -- Desaturate to show disabled state
        icon.visual:SetDesaturated(true)
        icon.visual:SetAlpha(0.7)
    else
        -- Fallback: just show key name
        icon.visual = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        icon.visual:SetPoint("CENTER")
        icon.visual:SetText(key:sub(1, 4))
        icon.visual:SetTextColor(0.7, 0.7, 0.7, 1)
    end
    
    -- Hover effect
    icon:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.3, 0.5, 0.3, 0.8)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(key, 1, 1, 1)
        GameTooltip:AddLine("Click to enable", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    icon:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
        GameTooltip:Hide()
    end)
    
    -- Click to re-enable
    icon:SetScript("OnClick", function(self)
        Dialog:RestoreFromDock(self.key)
    end)
    
    self.dockComponents[key] = icon
    
    -- Track as disabled
    table.insert(self.disabledComponentKeys, key)
    
    self:LayoutDockIcons()
end

-- [ REMOVE FROM DOCK ]-------------------------------------------------------------------

function Dialog:RemoveFromDock(key)
    local icon = self.dockComponents[key]
    if icon then
        icon:Hide()
        icon:SetParent(nil)
        self.dockComponents[key] = nil
    end
    
    -- Remove from disabled keys array
    for i, k in ipairs(self.disabledComponentKeys) do
        if k == key then
            table.remove(self.disabledComponentKeys, i)
            break
        end
    end
    
    self:LayoutDockIcons()
end

-- [ RESTORE FROM DOCK ]------------------------------------------------------------------

function Dialog:RestoreFromDock(key)
    -- Remove from dock
    self:RemoveFromDock(key)
    
    -- Create component in preview at saved position
    local savedPositions = self.targetPlugin and self.targetPlugin:GetSetting(self.targetSystemIndex, "ComponentPositions") or {}
    local pos = savedPositions[key]
    
    -- Get source component from registered components
    local dragComponents = OrbitEngine.ComponentDrag:GetComponentsForFrame(self.targetFrame)
    local data = dragComponents and dragComponents[key]
    
    if data and data.component then
        local canvasFrame = self.targetFrame.orbitCanvasFrame or self.targetFrame
        local frameW = canvasFrame:GetWidth()
        local frameH = canvasFrame:GetHeight()
        
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
        
        local compData = {
            component = data.component,
            x = centerX,
            y = centerY,
            anchorX = anchorX,
            anchorY = anchorY,
            offsetX = offsetX,
            offsetY = offsetY,
            justifyH = pos and pos.justifyH or "CENTER",
        }
        
        -- Use CreateDraggableComponent from DragComponent module
        if CanvasMode.CreateDraggableComponent then
            local comp = CanvasMode.CreateDraggableComponent(Dialog.previewFrame, key, data.component, centerX, centerY, compData)
            Dialog.previewComponents[key] = comp
        end
    end
end

-- [ CLEAR DOCK ]-------------------------------------------------------------------------

function Dialog:ClearDock()
    for key, icon in pairs(self.dockComponents) do
        icon:Hide()
        icon:SetParent(nil)
    end
    wipe(self.dockComponents)
    wipe(self.disabledComponentKeys)
    self:LayoutDockIcons()
end
