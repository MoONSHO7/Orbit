-- [ LibOrbitColorPicker-1.0 ] ------------------------------------------------------------------------------------
-- Extends Blizzard's ColorPickerFrame with drag-and-drop swatch and ColorCurve gradient bar.
-- Enables visual construction of multi-stop color gradients for WoW 12.0+ secret-safe rendering.

local MAJOR, MINOR = "LibOrbitColorPicker-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- [ CONSTANTS ] ------------------------------------------------------------------------------------
local GRADIENT_BAR_HEIGHT = 24
local GRADIENT_BAR_GAP = 20
local PIN_CIRCLE_SIZE = 12
local PIN_STEM_WIDTH = 2
local PIN_STEM_HEIGHT = 14
local DRAG_CURSOR_SIZE = 24

-- [ MODULE STATE ] ------------------------------------------------------------------------------------
lib.frame = lib.frame or nil
lib.gradientBar = lib.gradientBar or nil
lib.swatchProxy = lib.swatchProxy or nil
lib.pins = lib.pins or {}
lib.segmentPool = lib.segmentPool or {}
lib.colorCurve = nil
lib.dragTexture = nil
lib.dragColor = nil
lib.isDragging = false
lib.callback = nil
lib.wasCancelled = false
lib.originalHeight = nil
lib.isInitialized = false

-- [ UTILITY ] ------------------------------------------------------------------------------------
local function SortPinsByPosition(a, b) return a.position < b.position end

local function ClampPosition(x) return math.max(0, math.min(1, x)) end

local function CreateColorFromRGBA(r, g, b, a)
    assert(r and g and b, "CreateColorFromRGBA: r, g, b are required")
    return CreateColor(r, g, b, a or 1)
end

-- [ GRADIENT BAR ] ------------------------------------------------------------------------------------
local GradientBarMixin = {}

function GradientBarMixin:OnLoad()
    self.segments = {}
    self.pinHandles = {}
end

function GradientBarMixin:GetSortedPins()
    local sorted = {}
    for _, pin in ipairs(lib.pins) do table.insert(sorted, pin) end
    table.sort(sorted, SortPinsByPosition)
    return sorted
end

function GradientBarMixin:GetOrCreateSegment(index)
    if self.segments[index] then return self.segments[index] end
    local seg = self.SegmentContainer:CreateTexture(nil, "ARTWORK")
    seg:SetTexture("Interface\\Buttons\\WHITE8x8")
    seg:SetVertexColor(1, 1, 1, 1)
    seg:SetHeight(self.SegmentContainer:GetHeight())
    self.segments[index] = seg
    return seg
end

function GradientBarMixin:HideUnusedSegments(fromIndex)
    for i = fromIndex, #self.segments do
        if self.segments[i] then self.segments[i]:Hide() end
    end
end

function GradientBarMixin:Refresh()
    local pins = self:GetSortedPins()
    local barWidth = self.SegmentContainer:GetWidth()
    
    print("[LibOrbitColorPicker] Refresh: pinCount=" .. #pins .. ", barWidth=" .. barWidth)
    
    if barWidth <= 0 then 
        print("[LibOrbitColorPicker] Early return - barWidth <= 0")
        return 
    end
    
    -- Hide solid texture by default
    self.SolidTexture:Hide()
    
    if #pins == 0 then
        self:HideUnusedSegments(1)
        self.SolidTexture:SetColorTexture(0.2, 0.2, 0.2, 1)
        self.SolidTexture:Show()
        print("[LibOrbitColorPicker] Showing grey (no pins)")
        return
    end
    
    if #pins == 1 then
        self:HideUnusedSegments(1)
        local c = pins[1].color
        assert(c and c.r and c.g and c.b, "Pin color is invalid")
        self.SolidTexture:SetColorTexture(c.r, c.g, c.b, c.a or 1)
        self.SolidTexture:Show()
        print("[LibOrbitColorPicker] Showing solid color: r=" .. c.r .. " g=" .. c.g .. " b=" .. c.b)
        self:RefreshPinHandles()
        return
    end
    
    -- Multi-pin gradient
    local segIndex = 0
    
    -- Extend first segment to left edge if needed (solid color)
    if pins[1].position > 0 then
        segIndex = segIndex + 1
        local seg = self:GetOrCreateSegment(segIndex)
        local c = pins[1].color
        seg:ClearAllPoints()
        seg:SetPoint("LEFT", self.SegmentContainer, "LEFT", 0, 0)
        seg:SetWidth(pins[1].position * barWidth)
        seg:SetHeight(self.SegmentContainer:GetHeight())
        seg:SetTexture("Interface\\Buttons\\WHITE8x8")
        seg:SetGradient("HORIZONTAL", c, c)
        seg:Show()
    end
    
    -- Gradient segments between pins
    for i = 1, #pins - 1 do
        segIndex = segIndex + 1
        local seg = self:GetOrCreateSegment(segIndex)
        local left, right = pins[i], pins[i + 1]
        local leftX = left.position * barWidth
        local rightX = right.position * barWidth
        local width = math.max(1, rightX - leftX)
        
        seg:ClearAllPoints()
        seg:SetPoint("LEFT", self.SegmentContainer, "LEFT", leftX, 0)
        seg:SetWidth(width)
        seg:SetHeight(self.SegmentContainer:GetHeight())
        seg:SetTexture("Interface\\Buttons\\WHITE8x8")
        seg:SetGradient("HORIZONTAL", left.color, right.color)
        seg:Show()
    end
    
    -- Extend last segment to right edge if needed (solid color)
    if pins[#pins].position < 1 then
        segIndex = segIndex + 1
        local seg = self:GetOrCreateSegment(segIndex)
        local c = pins[#pins].color
        local startX = pins[#pins].position * barWidth
        seg:ClearAllPoints()
        seg:SetPoint("LEFT", self.SegmentContainer, "LEFT", startX, 0)
        seg:SetWidth(barWidth - startX)
        seg:SetHeight(self.SegmentContainer:GetHeight())
        seg:SetTexture("Interface\\Buttons\\WHITE8x8")
        seg:SetGradient("HORIZONTAL", c, c)
        seg:Show()
    end
    
    self:HideUnusedSegments(segIndex + 1)
    self:RefreshPinHandles()
end

function GradientBarMixin:RefreshPinHandles()
    local pins = self:GetSortedPins()
    local barWidth = self.SegmentContainer:GetWidth()
    if barWidth <= 0 then return end
    
    -- Hide all existing handles first
    for _, handle in ipairs(self.pinHandles) do handle:Hide() end
    
    for i, pin in ipairs(pins) do
        local handle = self.pinHandles[i]
        if not handle then
            handle = lib:CreatePinHandle(self)
            self.pinHandles[i] = handle
        end
        
        handle.pinIndex = i
        handle.pinData = pin
        handle:ClearAllPoints()
        -- Position pin above the bar, centered on the position
        local xOffset = (pin.position - 0.5) * barWidth
        handle:SetPoint("BOTTOM", self.SegmentContainer, "TOP", xOffset, 0)
        handle.Circle:SetColorTexture(pin.color.r, pin.color.g, pin.color.b, pin.color.a or 1)
        handle:SetFrameStrata("TOOLTIP")
        handle:SetFrameLevel(100)
        handle:Show()
    end
end

function GradientBarMixin:OnMouseUp(button)
    if button == "RightButton" then return end
    if not lib.isDragging then return end
    lib:EndDrag()
end

function GradientBarMixin:OnEnter()
    if lib.isDragging then
        self.DropHighlight:Show()
        lib:ShowGhostPin()
    end
end

function GradientBarMixin:OnLeave()
    self.DropHighlight:Hide()
    lib:HideGhostPin()
end

-- [ PIN HANDLE ] ------------------------------------------------------------------------------------
function lib:CreatePinHandle(gradientBar)
    local totalHeight = PIN_STEM_HEIGHT + PIN_CIRCLE_SIZE
    local handle = CreateFrame("Button", nil, gradientBar.PinsContainer)
    handle:SetSize(PIN_CIRCLE_SIZE + 4, totalHeight)
    handle:EnableMouse(true)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("RightButtonUp")
    
    -- White stem (line pointing down to the bar)
    handle.Stem = handle:CreateTexture(nil, "BACKGROUND")
    handle.Stem:SetSize(PIN_STEM_WIDTH, PIN_STEM_HEIGHT)
    handle.Stem:SetPoint("BOTTOM", handle, "BOTTOM", 0, 0)
    handle.Stem:SetColorTexture(1, 1, 1, 1)
    
    -- Circle border (black outline)
    handle.CircleBorder = handle:CreateTexture(nil, "BORDER")
    handle.CircleBorder:SetSize(PIN_CIRCLE_SIZE + 2, PIN_CIRCLE_SIZE + 2)
    handle.CircleBorder:SetPoint("BOTTOM", handle.Stem, "TOP", 0, -1)
    handle.CircleBorder:SetColorTexture(0, 0, 0, 1)
    
    -- Color circle on top
    handle.Circle = handle:CreateTexture(nil, "ARTWORK")
    handle.Circle:SetSize(PIN_CIRCLE_SIZE, PIN_CIRCLE_SIZE)
    handle.Circle:SetPoint("CENTER", handle.CircleBorder, "CENTER", 0, 0)
    handle.Circle:SetTexture("Interface\\Buttons\\WHITE8x8")
    
    handle.isDragging = false
    
    handle:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:StartMoving()
        self:SetFrameStrata("TOOLTIP")
        self:SetClampedToScreen(true)
    end)
    
    handle:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:StopMovingOrSizing()
        self:SetFrameStrata("TOOLTIP")
        
        -- Calculate final position from handle's current location
        local handleX = self:GetCenter()
        local barLeft = gradientBar.SegmentContainer:GetLeft()
        local barWidth = gradientBar.SegmentContainer:GetWidth()
        local newPos = ClampPosition((handleX - barLeft) / barWidth)
        
        if self.pinData then
            self.pinData.position = newPos
        end
        
        -- Full refresh to rebuild gradient and reposition all pins
        gradientBar:Refresh()
        lib:UpdateCurve()
    end)
    
    handle:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.pinIndex then
            lib:RemovePin(self.pinIndex)
        end
    end)
    
    return handle
end

-- [ SWATCH PROXY (DRAG SOURCE) ] ------------------------------------------------------------------------------------
function lib:CreateSwatchProxy()
    if self.swatchProxy then return self.swatchProxy end
    
    local content = ColorPickerFrame.Content
    local swatch = content.ColorSwatchCurrent
    
    -- Parent to Content frame, position over the swatch texture
    local proxy = CreateFrame("Frame", nil, content)
    proxy:SetPoint("TOPLEFT", swatch, "TOPLEFT", 0, 0)
    proxy:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 0, 0)
    proxy:EnableMouse(true)
    proxy:RegisterForDrag("LeftButton")
    proxy:SetFrameLevel(content:GetFrameLevel() + 10)
    
    proxy.startX = 0
    proxy.startY = 0
    
    proxy:SetScript("OnDragStart", function(self)
        local r, g, b = ColorPickerFrame.Content.ColorPicker:GetColorRGB()
        local a = ColorPickerFrame.Content.ColorPicker:GetColorAlpha()
        print("[LibOrbitColorPicker] Drag start: r=" .. r .. " g=" .. g .. " b=" .. b .. " a=" .. a)
        lib:StartDrag(r, g, b, a)
        self.startX, self.startY = GetCursorPosition()
    end)
    
    proxy:SetScript("OnDragStop", function() lib:EndDrag() end)
    
    self.swatchProxy = proxy
    return proxy
end

-- [ DRAG CURSOR ] ------------------------------------------------------------------------------------
function lib:CreateDragTexture()
    if self.dragTexture then return self.dragTexture end
    
    local tex = CreateFrame("Frame", nil, UIParent)
    tex:SetSize(DRAG_CURSOR_SIZE, DRAG_CURSOR_SIZE)
    tex:SetFrameStrata("TOOLTIP")
    tex:SetFrameLevel(1000)
    
    tex.Border = tex:CreateTexture(nil, "BORDER")
    tex.Border:SetAllPoints()
    tex.Border:SetColorTexture(0, 0, 0, 1)
    
    tex.Color = tex:CreateTexture(nil, "ARTWORK")
    tex.Color:SetPoint("TOPLEFT", 2, -2)
    tex.Color:SetPoint("BOTTOMRIGHT", -2, 2)
    tex.Color:SetTexture("Interface\\Buttons\\WHITE8x8")
    
    tex:Hide()
    
    tex:SetScript("OnUpdate", function(self)
        if not lib.isDragging then
            self:Hide()
            return
        end
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        
        -- Check if over gradient bar
        if lib.gradientBar and lib.gradientBar:IsMouseOver() then
            lib.gradientBar.DropHighlight:Show()
            lib:ShowGhostPin()
        else
            if lib.gradientBar then lib.gradientBar.DropHighlight:Hide() end
            lib:HideGhostPin()
        end
    end)
    
    self.dragTexture = tex
    return tex
end

function lib:StartDrag(r, g, b, a)
    self.isDragging = true
    self.dragColor = CreateColorFromRGBA(r, g, b, a)
    
    local tex = self:CreateDragTexture()
    tex.Color:SetVertexColor(r, g, b, a)
    tex:Show()
end

function lib:EndDrag()
    if not self.isDragging then return end
    self.isDragging = false
    
    if self.dragTexture then self.dragTexture:Hide() end
    self:HideGhostPin()
    if self.gradientBar then self.gradientBar.DropHighlight:Hide() end
    
    -- Check drop target
    if self.gradientBar and self.gradientBar:IsMouseOver() and self.dragColor then
        local x = GetCursorPosition() / self.gradientBar:GetEffectiveScale()
        local barLeft = self.gradientBar.SegmentContainer:GetLeft()
        local barWidth = self.gradientBar.SegmentContainer:GetWidth()
        local position = ClampPosition((x - barLeft) / barWidth)
        self:AddPin(position, self.dragColor)
    end
    
    self.dragColor = nil
end

-- [ GHOST PIN ] ------------------------------------------------------------------------------------
function lib:ShowGhostPin()
    if not self.gradientBar or not self.dragColor then return end
    
    if not self.ghostPin then
        local totalHeight = PIN_STEM_HEIGHT + PIN_CIRCLE_SIZE
        self.ghostPin = CreateFrame("Frame", nil, self.gradientBar.PinsContainer)
        self.ghostPin:SetSize(PIN_CIRCLE_SIZE + 4, totalHeight)
        
        -- White stem
        self.ghostPin.Stem = self.ghostPin:CreateTexture(nil, "BACKGROUND")
        self.ghostPin.Stem:SetSize(PIN_STEM_WIDTH, PIN_STEM_HEIGHT)
        self.ghostPin.Stem:SetPoint("BOTTOM", self.ghostPin, "BOTTOM", 0, 0)
        self.ghostPin.Stem:SetColorTexture(1, 1, 1, 0.6)
        
        -- Circle border
        self.ghostPin.CircleBorder = self.ghostPin:CreateTexture(nil, "BORDER")
        self.ghostPin.CircleBorder:SetSize(PIN_CIRCLE_SIZE + 2, PIN_CIRCLE_SIZE + 2)
        self.ghostPin.CircleBorder:SetPoint("BOTTOM", self.ghostPin.Stem, "TOP", 0, -1)
        self.ghostPin.CircleBorder:SetColorTexture(0, 0, 0, 0.6)
        
        -- Color circle
        self.ghostPin.Circle = self.ghostPin:CreateTexture(nil, "ARTWORK")
        self.ghostPin.Circle:SetSize(PIN_CIRCLE_SIZE, PIN_CIRCLE_SIZE)
        self.ghostPin.Circle:SetPoint("CENTER", self.ghostPin.CircleBorder, "CENTER", 0, 0)
        self.ghostPin.Circle:SetTexture("Interface\\Buttons\\WHITE8x8")
        
        self.ghostPin:SetAlpha(0.6)
    end
    
    local x = GetCursorPosition() / self.gradientBar:GetEffectiveScale()
    local barLeft = self.gradientBar.SegmentContainer:GetLeft()
    local barWidth = self.gradientBar.SegmentContainer:GetWidth()
    local position = ClampPosition((x - barLeft) / barWidth)
    
    self.ghostPin:ClearAllPoints()
    local xOffset = (position - 0.5) * barWidth
    self.ghostPin:SetPoint("BOTTOM", self.gradientBar.SegmentContainer, "TOP", xOffset, 0)
    self.ghostPin.Circle:SetVertexColor(self.dragColor.r, self.dragColor.g, self.dragColor.b, self.dragColor.a or 1)
    self.ghostPin:Show()
end

function lib:HideGhostPin()
    if self.ghostPin then self.ghostPin:Hide() end
end

-- [ PIN MANAGEMENT ] ------------------------------------------------------------------------------------
function lib:AddPin(position, color)
    print("[LibOrbitColorPicker] AddPin: pos=" .. position .. " r=" .. color.r .. " g=" .. color.g .. " b=" .. color.b .. " a=" .. (color.a or "nil"))
    table.insert(self.pins, { position = ClampPosition(position), color = color })
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

function lib:RemovePin(index)
    if #self.pins <= 1 then return end -- Keep at least one pin
    table.remove(self.pins, index)
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

function lib:ClearPins()
    wipe(self.pins)
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

function lib:SetPins(pinsTable)
    wipe(self.pins)
    for _, p in ipairs(pinsTable) do
        table.insert(self.pins, {
            position = ClampPosition(p.position or p.x or 0),
            color = p.color or CreateColorFromRGBA(p.r, p.g, p.b, p.a),
        })
    end
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

-- [ COLORCURVE INTEGRATION ] ------------------------------------------------------------------------------------
function lib:BuildColorCurve()
    local curve = C_CurveUtil.CreateColorCurve()
    local sorted = {}
    for _, pin in ipairs(self.pins) do table.insert(sorted, pin) end
    table.sort(sorted, SortPinsByPosition)
    
    for _, pin in ipairs(sorted) do
        curve:AddPoint(pin.position, pin.color)
    end
    return curve
end

function lib:UpdateCurve()
    self.colorCurve = self:BuildColorCurve()
    if self.callback then
        -- Return both native curve and serializable pins for persistence
        local serializedPins = {}
        for _, pin in ipairs(self.pins) do
            table.insert(serializedPins, {
                position = pin.position,
                color = { r = pin.color.r, g = pin.color.g, b = pin.color.b, a = pin.color.a or 1 },
            })
        end
        self.callback({ curve = self.colorCurve, pins = serializedPins }, false)
    end
end

function lib:GetColorCurve() return self.colorCurve end

function lib:LoadFromCurve(curveData)
    if not curveData then return end
    wipe(self.pins)
    
    -- Handle serialized pins format { pins = { ... } }
    if curveData.pins then
        for _, pin in ipairs(curveData.pins) do
            table.insert(self.pins, {
                position = pin.position or 0,
                color = CreateColorFromRGBA(pin.color.r, pin.color.g, pin.color.b, pin.color.a or 1),
            })
        end
    -- Handle native ColorCurve object
    elseif curveData.GetPoints then
        local points = curveData:GetPoints()
        for _, point in ipairs(points) do
            table.insert(self.pins, { position = point.x, color = point.y })
        end
    end
    
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

-- [ SERIALIZATION ] ------------------------------------------------------------------------------------
function lib:SerializePins()
    local data = {}
    for _, pin in ipairs(self.pins) do
        table.insert(data, {
            x = pin.position,
            r = pin.color.r,
            g = pin.color.g,
            b = pin.color.b,
            a = pin.color.a or 1,
        })
    end
    return data
end

function lib:DeserializePins(data)
    wipe(self.pins)
    for _, p in ipairs(data) do
        table.insert(self.pins, {
            position = p.x,
            color = CreateColorFromRGBA(p.r, p.g, p.b, p.a),
        })
    end
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

-- [ GRADIENT BAR CREATION ] ------------------------------------------------------------------------------------
local GRADIENT_BAR_EXTENSION = 100

function lib:CreateGradientBar()
    if self.gradientBar then return self.gradientBar end
    
    local bar = CreateFrame("Frame", "LibOrbitColorPickerGradientBar", ColorPickerFrame.Content, "BackdropTemplate")
    Mixin(bar, GradientBarMixin)
    
    bar:SetHeight(GRADIENT_BAR_HEIGHT)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    
    -- Position above the footer buttons with gap
    bar:SetPoint("LEFT", ColorPickerFrame, "LEFT", 20, 0)
    bar:SetPoint("RIGHT", ColorPickerFrame, "RIGHT", -20, 0)
    bar:SetPoint("BOTTOM", ColorPickerFrame.Footer, "TOP", 0, GRADIENT_BAR_GAP)
    
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.1, 0.1, 0.1, 1)
    bar:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Checkerboard background for alpha visibility
    bar.Checkerboard = bar:CreateTexture(nil, "BACKGROUND")
    bar.Checkerboard:SetPoint("TOPLEFT", 1, -1)
    bar.Checkerboard:SetPoint("BOTTOMRIGHT", -1, 1)
    bar.Checkerboard:SetAtlas("colorpicker-checkerboard")
    bar.Checkerboard:SetHorizTile(true)
    bar.Checkerboard:SetVertTile(true)
    
    -- Segment container (gradient textures go here)
    bar.SegmentContainer = CreateFrame("Frame", nil, bar)
    bar.SegmentContainer:SetPoint("TOPLEFT", 1, -1)
    bar.SegmentContainer:SetPoint("BOTTOMRIGHT", -1, 1)
    
    -- Solid texture for single-color display
    bar.SolidTexture = bar.SegmentContainer:CreateTexture(nil, "ARTWORK")
    bar.SolidTexture:SetAllPoints()
    bar.SolidTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar.SolidTexture:Hide()
    
    -- Drop highlight
    bar.DropHighlight = bar:CreateTexture(nil, "OVERLAY")
    bar.DropHighlight:SetAllPoints()
    bar.DropHighlight:SetColorTexture(1, 1, 1, 0.2)
    bar.DropHighlight:Hide()
    
    -- Pins container (positioned ABOVE the bar)
    local pinHeight = PIN_STEM_HEIGHT + PIN_CIRCLE_SIZE + 4
    bar.PinsContainer = CreateFrame("Frame", nil, bar)
    bar.PinsContainer:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 0)
    bar.PinsContainer:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
    bar.PinsContainer:SetHeight(pinHeight)
    bar.PinsContainer:SetFrameStrata("TOOLTIP")
    bar.PinsContainer:SetFrameLevel(50)
    bar.PinsContainer:Show()
    
    bar:OnLoad()
    bar:EnableMouse(true)
    bar:SetScript("OnMouseUp", bar.OnMouseUp)
    bar:SetScript("OnEnter", bar.OnEnter)
    bar:SetScript("OnLeave", bar.OnLeave)
    
    self.gradientBar = bar
    return bar
end

-- [ MAIN FRAME SETUP ] ------------------------------------------------------------------------------------
function lib:Initialize()
    if self.isInitialized then return end
    
    -- Store original height and positions
    self.originalHeight = ColorPickerFrame:GetHeight()
    self.originalFooterPoint = { ColorPickerFrame.Footer:GetPoint(1) }
    if ColorPickerFrame.Content.HexBox then
        self.originalHexBoxPoint = { ColorPickerFrame.Content.HexBox:GetPoint(1) }
    end
    
    -- Create gradient bar
    self:CreateGradientBar()
    
    -- Create swatch proxy
    self:CreateSwatchProxy()
    
    -- Create drag texture
    self:CreateDragTexture()
    
    -- Hook ColorPickerFrame show/hide
    ColorPickerFrame:HookScript("OnShow", function()
        -- Extend frame height
        ColorPickerFrame:SetHeight(lib.originalHeight + GRADIENT_BAR_EXTENSION)
        
        -- Push footer down
        ColorPickerFrame.Footer:ClearAllPoints()
        ColorPickerFrame.Footer:SetPoint("BOTTOM", ColorPickerFrame, "BOTTOM", 0, 12)
        
        -- Keep HexBox aligned with the color picker (not pushed down)
        local hexBox = ColorPickerFrame.Content.HexBox
        if hexBox then
            hexBox:ClearAllPoints()
            hexBox:SetPoint("BOTTOMRIGHT", ColorPickerFrame.Content.ColorPicker, "BOTTOMRIGHT", 73, -7)
        end
        
        if lib.gradientBar then
            lib.gradientBar:Show()
            lib.gradientBar:Refresh()
        end
    end)
    
    ColorPickerFrame:HookScript("OnHide", function()
        -- Restore original height
        ColorPickerFrame:SetHeight(lib.originalHeight)
        
        -- Restore footer position
        if lib.originalFooterPoint then
            ColorPickerFrame.Footer:ClearAllPoints()
            ColorPickerFrame.Footer:SetPoint(unpack(lib.originalFooterPoint))
        end
        
        -- Restore HexBox position
        if lib.originalHexBoxPoint and ColorPickerFrame.Content.HexBox then
            ColorPickerFrame.Content.HexBox:ClearAllPoints()
            ColorPickerFrame.Content.HexBox:SetPoint(unpack(lib.originalHexBoxPoint))
        end
        
        if lib.gradientBar then lib.gradientBar:Hide() end
        lib:EndDrag()
        
        if lib.callback then
            local serializedPins = {}
            for _, pin in ipairs(lib.pins) do
                table.insert(serializedPins, {
                    position = pin.position,
                    color = { r = pin.color.r, g = pin.color.g, b = pin.color.b, a = pin.color.a or 1 },
                })
            end
            lib.callback({ curve = lib.colorCurve, pins = serializedPins }, lib.wasCancelled)
        end
        lib.wasCancelled = false
    end)
    
    self.isInitialized = true
end

-- [ PUBLIC API ] ------------------------------------------------------------------------------------
function lib:Open(options)
    options = options or {}
    
    -- Initialize on first use
    self:Initialize()
    
    -- Reset state
    self.wasCancelled = false
    self.callback = options.callback
    
    -- Clear existing pin handles
    if self.gradientBar then
        for _, handle in ipairs(self.gradientBar.pinHandles) do
            handle:Hide()
        end
    end
    
    -- Load initial curve or color, or start fresh
    if options.initialCurve then
        self:LoadFromCurve(options.initialCurve)
    elseif options.initialColor then
        wipe(self.pins)
        local c = options.initialColor
        self:AddPin(0.5, CreateColorFromRGBA(c.r or c[1], c.g or c[2], c.b or c[3], c.a or c[4] or 1))
    else
        wipe(self.pins)
        self.colorCurve = nil
        -- Immediately refresh to clear the bar
        if self.gradientBar then
            self.gradientBar:Refresh()
        end
    end
    
    -- Setup Blizzard picker
    local info = {
        swatchFunc = function()
            -- Live preview optional synchronization
        end,
        opacityFunc = function() end,
        cancelFunc = function()
            lib.wasCancelled = true
        end,
        hasOpacity = options.hasOpacity ~= false,
        r = options.initialColor and (options.initialColor.r or options.initialColor[1]) or 1,
        g = options.initialColor and (options.initialColor.g or options.initialColor[2]) or 1,
        b = options.initialColor and (options.initialColor.b or options.initialColor[3]) or 1,
        opacity = options.initialColor and (options.initialColor.a or options.initialColor[4]) or 1,
    }
    
    ColorPickerFrame:SetupColorPickerAndShow(info)
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    
    -- Refresh gradient bar
    if self.gradientBar then
        self.gradientBar:Refresh()
    end
end

-- Accessor for checking if library is active
function lib:IsOpen() return ColorPickerFrame:IsShown() end
