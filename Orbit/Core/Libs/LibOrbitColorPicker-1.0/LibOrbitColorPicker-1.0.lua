-- [ LibOrbitColorPicker-1.0 ] ------------------------------------------------------------------------------------
-- Extends Blizzard's ColorPickerFrame with drag-and-drop swatch and ColorCurve gradient bar.
-- Single-pin mode for simple RGB colors, multi-pin mode for ColorCurve gradients.

local MAJOR, MINOR = "LibOrbitColorPicker-1.0", 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local _, Orbit = ...
local Pixel = Orbit and Orbit.Engine and Orbit.Engine.Pixel

-- [ CONSTANTS ] ------------------------------------------------------------------------------------
local GRADIENT_BAR_HEIGHT = 24
local GRADIENT_BAR_GAP = 20
local GRADIENT_BAR_EXTENSION = 106
local GRADIENT_BAR_PADDING = 20
local PIN_CIRCLE_SIZE = 12
local PIN_STEM_WIDTH = 2
local PIN_STEM_HEIGHT = 14
local DRAG_CURSOR_SIZE = 24
local HEX_BOX_WIDTH = 70
local FOOTER_TOP_PADDING = 8
local FOOTER_BOTTOM_PADDING = 4
local FOOTER_BUTTON_HEIGHT = 20
local FOOTER_DIVIDER_OFFSET = 6
local FOOTER_HEIGHT = FOOTER_TOP_PADDING + FOOTER_BUTTON_HEIGHT + FOOTER_BOTTOM_PADDING

-- [ MODULE STATE ] ------------------------------------------------------------------------------------
lib.gradientBar = lib.gradientBar or nil
lib.swatchProxy = lib.swatchProxy or nil
lib.pins = lib.pins or {}
lib.colorCurve = nil
lib.dragTexture = nil
lib.dragColor = nil
lib.isDragging = false
lib.callback = nil
lib.wasCancelled = false
lib.originalHeight = nil
lib.isInitialized = false
lib.classColorSwatch = nil
lib.classColorEventFrame = nil
lib.multiPinMode = false

-- [ UTILITY ] ------------------------------------------------------------------------------------
local function SortPinsByPosition(a, b) return a.position < b.position end
local function ClampPosition(x) return math.max(0, math.min(1, x)) end

local function GetCurrentClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    if color then return { r = color.r, g = color.g, b = color.b, a = 1 } end
    return { r = 1, g = 1, b = 1, a = 1 }
end

local function NormalizeColor(c)
    if not c then return { r = 1, g = 1, b = 1, a = 1 } end
    if c.GetRGBA then
        local r, g, b, a = c:GetRGBA()
        return { r = r, g = g, b = b, a = a }
    end
    return { r = c.r or c[1] or 1, g = c.g or c[2] or 1, b = c.b or c[3] or 1, a = c.a or c[4] or 1 }
end

local function ResolveClassColorPin(pin)
    if pin.type == "class" then return GetCurrentClassColor() end
    return pin.color
end

local function ToColorMixin(c) return CreateColor(c.r, c.g, c.b, c.a or 1) end

-- [ GRADIENT BAR MIXIN ] ------------------------------------------------------------------------------------
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
    local barWidth, barHeight = self.SegmentContainer:GetWidth(), self.SegmentContainer:GetHeight()
    if barWidth <= 0 or barHeight <= 0 then return end
    
    self.SolidTexture:Hide()
    
    -- Update Apply button state based on pin count
    lib:UpdateApplyButtonState()
    
    if #pins == 0 then
        self:HideUnusedSegments(1)
        self:RefreshPinHandles()
        return
    end
    
    if #pins == 1 then
        self:HideUnusedSegments(1)
        local c = ResolveClassColorPin(pins[1])
        self.SolidTexture:SetColorTexture(c.r, c.g, c.b, c.a or 1)
        self.SolidTexture:Show()
        self:RefreshPinHandles()
        return
    end
    
    local segIndex = 0
    
    if pins[1].position > 0 then
        segIndex = segIndex + 1
        local seg = self:GetOrCreateSegment(segIndex)
        local c = ToColorMixin(ResolveClassColorPin(pins[1]))
        seg:ClearAllPoints()
        seg:SetPoint("LEFT", self.SegmentContainer, "LEFT", 0, 0)
        seg:SetSize(pins[1].position * barWidth, barHeight)
        seg:SetGradient("HORIZONTAL", c, c)
        seg:Show()
    end
    
    for i = 1, #pins - 1 do
        segIndex = segIndex + 1
        local seg = self:GetOrCreateSegment(segIndex)
        local left, right = pins[i], pins[i + 1]
        local leftX, rightX = left.position * barWidth, right.position * barWidth
        local leftColor = ToColorMixin(ResolveClassColorPin(left))
        local rightColor = ToColorMixin(ResolveClassColorPin(right))
        seg:ClearAllPoints()
        seg:SetPoint("LEFT", self.SegmentContainer, "LEFT", leftX, 0)
        seg:SetSize(math.max(1, rightX - leftX), barHeight)
        seg:SetGradient("HORIZONTAL", leftColor, rightColor)
        seg:Show()
    end
    
    if pins[#pins].position < 1 then
        segIndex = segIndex + 1
        local seg = self:GetOrCreateSegment(segIndex)
        local c = ToColorMixin(ResolveClassColorPin(pins[#pins]))
        local startX = pins[#pins].position * barWidth
        seg:ClearAllPoints()
        seg:SetPoint("LEFT", self.SegmentContainer, "LEFT", startX, 0)
        seg:SetSize(barWidth - startX, barHeight)
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
    
    for _, handle in ipairs(self.pinHandles) do handle:Hide() end
    
    for i, pin in ipairs(pins) do
        local handle = self.pinHandles[i] or lib:CreatePinHandle(self)
        self.pinHandles[i] = handle
        handle.pinIndex, handle.pinData = i, pin
        handle:ClearAllPoints()
        handle:SetPoint("BOTTOM", self.SegmentContainer, "TOP", (pin.position - 0.5) * barWidth, 0)
        local resolvedColor = ResolveClassColorPin(pin)
        handle.Circle:SetColorTexture(resolvedColor.r, resolvedColor.g, resolvedColor.b, resolvedColor.a or 1)
        handle:SetFrameStrata("TOOLTIP")
        handle:SetFrameLevel(100)
        handle:Show()
    end
end

function GradientBarMixin:OnMouseUp(button)
    if button == "RightButton" or not lib.isDragging then return end
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
    local handle = CreateFrame("Button", nil, gradientBar.PinsContainer)
    handle:SetSize(PIN_CIRCLE_SIZE + 4, PIN_STEM_HEIGHT + PIN_CIRCLE_SIZE)
    handle:EnableMouse(true)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("RightButtonUp")
    
    handle.Stem = handle:CreateTexture(nil, "BACKGROUND")
    handle.Stem:SetSize(PIN_STEM_WIDTH, PIN_STEM_HEIGHT)
    handle.Stem:SetPoint("BOTTOM", handle, "BOTTOM", 0, 0)
    handle.Stem:SetColorTexture(1, 1, 1, 1)
    
    handle.CircleBorder = handle:CreateTexture(nil, "BORDER")
    handle.CircleBorder:SetSize(PIN_CIRCLE_SIZE + 2, PIN_CIRCLE_SIZE + 2)
    handle.CircleBorder:SetPoint("BOTTOM", handle.Stem, "TOP", 0, -1)
    handle.CircleBorder:SetColorTexture(0, 0, 0, 1)
    
    handle.Circle = handle:CreateTexture(nil, "ARTWORK")
    handle.Circle:SetSize(PIN_CIRCLE_SIZE, PIN_CIRCLE_SIZE)
    handle.Circle:SetPoint("CENTER", handle.CircleBorder, "CENTER", 0, 0)
    handle.Circle:SetTexture("Interface\\Buttons\\WHITE8x8")
    
    handle:SetScript("OnDragStart", function(self)
        if not lib.multiPinMode then return end
        self:StartMoving()
        self:SetFrameStrata("TOOLTIP")
        self:SetClampedToScreen(true)
    end)
    
    handle:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetFrameStrata("TOOLTIP")
        local handleX = self:GetCenter()
        local barLeft, barWidth = gradientBar.SegmentContainer:GetLeft(), gradientBar.SegmentContainer:GetWidth()
        if self.pinData then self.pinData.position = ClampPosition((handleX - barLeft) / barWidth) end
        gradientBar:Refresh()
        lib:UpdateCurve()
    end)
    
    handle:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.pinData then
            lib:RemovePin(self.pinData)
        end
    end)
    
    return handle
end

-- [ SWATCH PROXY ] ------------------------------------------------------------------------------------
function lib:CreateSwatchProxy()
    if self.swatchProxy then return self.swatchProxy end
    
    local content = ColorPickerFrame.Content
    local swatch = content.ColorSwatchCurrent
    
    local proxy = CreateFrame("Frame", nil, content)
    proxy:SetAllPoints(swatch)
    proxy:EnableMouse(true)
    proxy:RegisterForDrag("LeftButton")
    proxy:SetFrameLevel(content:GetFrameLevel() + 10)
    
    proxy:SetScript("OnDragStart", function()
        if not lib.multiPinMode and #lib.pins > 0 then return end
        local r, g, b = ColorPickerFrame.Content.ColorPicker:GetColorRGB()
        local a = ColorPickerFrame.Content.ColorPicker:GetColorAlpha()
        lib:StartDrag(r, g, b, a)
    end)
    
    proxy:SetScript("OnDragStop", function() lib:EndDrag() end)
    
    self.swatchProxy = proxy
    return proxy
end

-- [ CLASS COLOR SWATCH ] ------------------------------------------------------------------------------------
function lib:GetPlayerClassColor()
    local _, playerClass = UnitClass("player")
    local classColor = playerClass and RAID_CLASS_COLORS[playerClass]
    return classColor and { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } or { r = 1, g = 1, b = 1, a = 1 }
end

function lib:CreateClassColorSwatch()
    if self.classColorSwatch then return self.classColorSwatch end
    
    local content = ColorPickerFrame.Content
    local currentSwatch = content.ColorSwatchCurrent
    local swatchWidth, swatchHeight = currentSwatch:GetSize()
    
    local frame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    frame:SetSize(swatchWidth, swatchHeight)
    frame:SetPoint("TOP", currentSwatch, "BOTTOM", 0, -8)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameLevel(content:GetFrameLevel() + 10)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    
    frame.Label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.Label:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame.Label:SetText("Class")
    frame.Label:SetTextColor(0.7, 0.7, 0.7, 1)
    
    frame:SetScript("OnDragStart", function()
        if not lib.multiPinMode and #lib.pins > 0 then return end
        local c = lib:GetPlayerClassColor()
        lib:StartDrag(c.r, c.g, c.b, c.a, true)
    end)
    
    frame:SetScript("OnDragStop", function() lib:EndDrag() end)
    
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Class Color", 1, 0.82, 0)
        local canDrag = lib.multiPinMode or #lib.pins == 0
        GameTooltip:AddLine(canDrag and "Drag to gradient bar to add as pin" or "Single color mode (remove pin to add new)", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    self.classColorSwatch = frame
    self:UpdateClassColorSwatch()
    return frame
end

function lib:UpdateClassColorSwatch()
    if not self.classColorSwatch then return end
    local c = self:GetPlayerClassColor()
    self.classColorSwatch:SetBackdropColor(c.r, c.g, c.b, 1)
end

function lib:SetupClassColorEvents()
    if self.classColorEventFrame then return end
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:SetScript("OnEvent", function() lib:UpdateClassColorSwatch() end)
    self.classColorEventFrame = eventFrame
end

-- [ DRAG SYSTEM ] ------------------------------------------------------------------------------------
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
        if not lib.isDragging then self:Hide() return end
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        
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

function lib:StartDrag(r, g, b, a, isClassDrag)
    if not self.multiPinMode and #self.pins > 0 then return end
    self.isDragging = true
    self.dragColor = { r = r, g = g, b = b, a = a or 1 }
    self.dragType = isClassDrag and "class" or nil
    local tex = self:CreateDragTexture()
    tex.Color:SetVertexColor(r, g, b, a or 1)
    tex:Show()
end

function lib:EndDrag()
    if not self.isDragging then return end
    self.isDragging = false
    if self.dragTexture then self.dragTexture:Hide() end
    self:HideGhostPin()
    if self.gradientBar then self.gradientBar.DropHighlight:Hide() end
    
    if self.gradientBar and self.gradientBar:IsMouseOver() and self.dragColor then
        local x = GetCursorPosition() / self.gradientBar:GetEffectiveScale()
        local barLeft, barWidth = self.gradientBar.SegmentContainer:GetLeft(), self.gradientBar.SegmentContainer:GetWidth()
        self:AddPin(ClampPosition((x - barLeft) / barWidth), self.dragColor, self.dragType)
    end
    self.dragColor = nil
    self.dragType = nil
end

-- [ GHOST PIN ] ------------------------------------------------------------------------------------
function lib:ShowGhostPin()
    if not self.gradientBar or not self.dragColor then return end
    
    if not self.ghostPin then
        self.ghostPin = CreateFrame("Frame", nil, self.gradientBar.PinsContainer)
        self.ghostPin:SetSize(PIN_CIRCLE_SIZE + 4, PIN_STEM_HEIGHT + PIN_CIRCLE_SIZE)
        self.ghostPin.Stem = self.ghostPin:CreateTexture(nil, "BACKGROUND")
        self.ghostPin.Stem:SetSize(PIN_STEM_WIDTH, PIN_STEM_HEIGHT)
        self.ghostPin.Stem:SetPoint("BOTTOM", self.ghostPin, "BOTTOM", 0, 0)
        self.ghostPin.Stem:SetColorTexture(1, 1, 1, 0.6)
        self.ghostPin.CircleBorder = self.ghostPin:CreateTexture(nil, "BORDER")
        self.ghostPin.CircleBorder:SetSize(PIN_CIRCLE_SIZE + 2, PIN_CIRCLE_SIZE + 2)
        self.ghostPin.CircleBorder:SetPoint("BOTTOM", self.ghostPin.Stem, "TOP", 0, -1)
        self.ghostPin.CircleBorder:SetColorTexture(0, 0, 0, 0.6)
        self.ghostPin.Circle = self.ghostPin:CreateTexture(nil, "ARTWORK")
        self.ghostPin.Circle:SetSize(PIN_CIRCLE_SIZE, PIN_CIRCLE_SIZE)
        self.ghostPin.Circle:SetPoint("CENTER", self.ghostPin.CircleBorder, "CENTER", 0, 0)
        self.ghostPin.Circle:SetTexture("Interface\\Buttons\\WHITE8x8")
        self.ghostPin:SetAlpha(0.6)
    end
    
    local x = GetCursorPosition() / self.gradientBar:GetEffectiveScale()
    local barLeft, barWidth = self.gradientBar.SegmentContainer:GetLeft(), self.gradientBar.SegmentContainer:GetWidth()
    local position = ClampPosition((x - barLeft) / barWidth)
    self.ghostPin:ClearAllPoints()
    self.ghostPin:SetPoint("BOTTOM", self.gradientBar.SegmentContainer, "TOP", (position - 0.5) * barWidth, 0)
    self.ghostPin.Circle:SetVertexColor(self.dragColor.r, self.dragColor.g, self.dragColor.b, self.dragColor.a or 1)
    self.ghostPin:Show()
end

function lib:HideGhostPin()
    if self.ghostPin then self.ghostPin:Hide() end
end

function lib:UpdateApplyButtonState()
    if not self.applyButton then return end
    local hasPins = self.pins and #self.pins > 0
    self.applyButton:SetEnabled(hasPins)
    if hasPins then
        self.applyButton:SetText("Apply Color")
    else
        self.applyButton:SetText("No Color (Disabled)")
    end
end

-- [ PIN MANAGEMENT ] ------------------------------------------------------------------------------------
function lib:AddPin(position, color, pinType)
    local c = NormalizeColor(color)
    local pin = { position = ClampPosition(position), color = c }
    if pinType then pin.type = pinType end
    table.insert(self.pins, pin)
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

function lib:AddClassColorPin(position)
    local c = GetCurrentClassColor()
    table.insert(self.pins, { position = ClampPosition(position), color = c, type = "class" })
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

function lib:RemovePin(pinToRemove)
    for i, pin in ipairs(self.pins) do
        if pin == pinToRemove then
            table.remove(self.pins, i)
            break
        end
    end
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

function lib:ClearPins()
    wipe(self.pins)
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

-- [ COLORCURVE INTEGRATION ] ------------------------------------------------------------------------------------
function lib:BuildColorCurve()
    local curve = C_CurveUtil.CreateColorCurve()
    local sorted = self.gradientBar and self.gradientBar:GetSortedPins() or {}
    for _, pin in ipairs(sorted) do
        local resolvedColor = ResolveClassColorPin(pin)
        curve:AddPoint(pin.position, ToColorMixin(resolvedColor))
    end
    return curve
end

function lib:UpdateCurve()
    self.colorCurve = self:BuildColorCurve()
    if self.callback then
        local serializedPins = {}
        for _, pin in ipairs(self.pins) do
            local resolvedColor = ResolveClassColorPin(pin)
            local serialized = { 
                position = pin.position, 
                color = { r = resolvedColor.r, g = resolvedColor.g, b = resolvedColor.b, a = resolvedColor.a or 1 },
            }
            if pin.type then serialized.type = pin.type end
            table.insert(serializedPins, serialized)
        end
        self.callback({ curve = self.colorCurve, pins = serializedPins }, false)
    end
end

function lib:GetColorCurve() return self.colorCurve end

function lib:LoadFromCurve(curveData)
    if not curveData then return end
    wipe(self.pins)
    
    if curveData.pins then
        for _, pin in ipairs(curveData.pins) do
            local newPin = { position = pin.position or 0, color = NormalizeColor(pin.color) }
            if pin.type then newPin.type = pin.type end
            table.insert(self.pins, newPin)
        end
    elseif curveData.GetPoints then
        for _, point in ipairs(curveData:GetPoints()) do
            table.insert(self.pins, { position = point.x, color = NormalizeColor(point.y) })
        end
    end
    
    self:UpdateCurve()
    if self.gradientBar then self.gradientBar:Refresh() end
end

-- [ GRADIENT BAR CREATION ] ------------------------------------------------------------------------------------
function lib:CreateGradientBar()
    if self.gradientBar then return self.gradientBar end
    
    local bar = CreateFrame("Frame", "LibOrbitColorPickerGradientBar", ColorPickerFrame.Content)
    Mixin(bar, GradientBarMixin)
    bar:SetHeight(GRADIENT_BAR_HEIGHT)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:SetFrameLevel(10)
    bar:SetPoint("LEFT", ColorPickerFrame, "LEFT", GRADIENT_BAR_PADDING, 0)
    bar:SetPoint("RIGHT", ColorPickerFrame, "RIGHT", -GRADIENT_BAR_PADDING, 0)
    bar:SetPoint("BOTTOM", lib.orbitFooter, "TOP", 0, GRADIENT_BAR_GAP)
    
    local borderSize = Pixel and Pixel:Snap(1, bar:GetEffectiveScale()) or 1
    
    bar.BorderTop = bar:CreateTexture(nil, "OVERLAY")
    bar.BorderTop:SetColorTexture(1, 1, 1, 1)
    bar.BorderTop:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.BorderTop:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    bar.BorderTop:SetHeight(borderSize)
    
    bar.BorderBottom = bar:CreateTexture(nil, "OVERLAY")
    bar.BorderBottom:SetColorTexture(1, 1, 1, 1)
    bar.BorderBottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bar.BorderBottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bar.BorderBottom:SetHeight(borderSize)
    
    bar.BorderLeft = bar:CreateTexture(nil, "OVERLAY")
    bar.BorderLeft:SetColorTexture(1, 1, 1, 1)
    bar.BorderLeft:SetPoint("TOPLEFT", bar.BorderTop, "BOTTOMLEFT", 0, 0)
    bar.BorderLeft:SetPoint("BOTTOMLEFT", bar.BorderBottom, "TOPLEFT", 0, 0)
    bar.BorderLeft:SetWidth(borderSize)
    
    bar.BorderRight = bar:CreateTexture(nil, "OVERLAY")
    bar.BorderRight:SetColorTexture(1, 1, 1, 1)
    bar.BorderRight:SetPoint("TOPRIGHT", bar.BorderTop, "BOTTOMRIGHT", 0, 0)
    bar.BorderRight:SetPoint("BOTTOMRIGHT", bar.BorderBottom, "TOPRIGHT", 0, 0)
    bar.BorderRight:SetWidth(borderSize)
    
    bar.SegmentContainer = CreateFrame("Frame", nil, bar)
    bar.SegmentContainer:SetPoint("TOPLEFT", borderSize, -borderSize)
    bar.SegmentContainer:SetPoint("BOTTOMRIGHT", -borderSize, borderSize)
    bar.SegmentContainer:SetScript("OnSizeChanged", function(self, width, height)
        if width > 0 and height > 0 then bar:Refresh() end
    end)
    
    bar.SolidTexture = bar.SegmentContainer:CreateTexture(nil, "ARTWORK")
    bar.SolidTexture:SetAllPoints()
    bar.SolidTexture:Hide()
    
    bar.DropHighlight = bar:CreateTexture(nil, "OVERLAY")
    bar.DropHighlight:SetAllPoints()
    bar.DropHighlight:SetColorTexture(1, 1, 1, 0.2)
    bar.DropHighlight:Hide()
    
    local pinHeight = PIN_STEM_HEIGHT + PIN_CIRCLE_SIZE + 4
    bar.PinsContainer = CreateFrame("Frame", nil, bar)
    bar.PinsContainer:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 0)
    bar.PinsContainer:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
    bar.PinsContainer:SetHeight(pinHeight)
    bar.PinsContainer:SetFrameStrata("TOOLTIP")
    bar.PinsContainer:SetFrameLevel(50)
    bar.PinsContainer:Show()
    
    -- Percentage notches (25%, 50%, 75%)
    local NOTCH_HEIGHT, NOTCH_WIDTH, NOTCH_GAP = 6, 1, 2
    bar.Notches = {}
    for _, pct in ipairs({ 0.25, 0.5, 0.75 }) do
        local notch = bar:CreateTexture(nil, "OVERLAY")
        notch:SetColorTexture(1, 1, 1, 0.6)
        notch:SetSize(NOTCH_WIDTH, NOTCH_HEIGHT)
        notch.pct = pct
        table.insert(bar.Notches, notch)
    end
    
    local function UpdateNotchPositions()
        local barWidth = bar.SegmentContainer:GetWidth()
        if barWidth <= 0 then return end
        for _, notch in ipairs(bar.Notches) do
            notch:ClearAllPoints()
            notch:SetPoint("TOP", bar.SegmentContainer, "BOTTOMLEFT", barWidth * notch.pct, -NOTCH_GAP)
        end
    end
    bar.SegmentContainer:HookScript("OnSizeChanged", UpdateNotchPositions)
    C_Timer.After(0.1, UpdateNotchPositions)
    
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
    
    self.originalHeight = ColorPickerFrame:GetHeight()
    
    if ColorPickerFrame.Border then ColorPickerFrame.Border:Hide() end
    
    if not self.dialogBorder then
        self.dialogBorder = CreateFrame("Frame", nil, ColorPickerFrame, "DialogBorderTranslucentTemplate")
        self.dialogBorder:SetAllPoints(ColorPickerFrame)
        self.dialogBorder:SetFrameStrata("BACKGROUND")
        self.dialogBorder:SetFrameLevel(ColorPickerFrame:GetFrameLevel())
    end
    
    ColorPickerFrame:SetMovable(true)
    ColorPickerFrame:EnableMouse(true)
    ColorPickerFrame:RegisterForDrag("LeftButton")
    ColorPickerFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ColorPickerFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    if ColorPickerFrame.Header then ColorPickerFrame.Header:Hide() end
    if ColorPickerFrame.Footer then ColorPickerFrame.Footer:Hide() end
    if ColorPickerFrame.Content.ColorSwatchOriginal then
        ColorPickerFrame.Content.ColorSwatchOriginal:Hide()
        ColorPickerFrame.Content.ColorSwatchOriginal:SetAlpha(0)
    end
    
    if not self.closeButton then
        self.closeButton = CreateFrame("Button", nil, ColorPickerFrame, "UIPanelCloseButton")
        self.closeButton:SetPoint("TOPRIGHT", ColorPickerFrame, "TOPRIGHT", -2, -2)
        self.closeButton:SetScript("OnClick", function()
            lib.wasCancelled = true
            ColorPickerFrame:Hide()
        end)
    end
    
    if not self.modeTitle then
        self.modeTitle = ColorPickerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self.modeTitle:SetPoint("TOP", ColorPickerFrame, "TOP", 0, -15)
    end
    
    if not self.orbitFooter then
        self.orbitFooter = CreateFrame("Frame", nil, ColorPickerFrame)
        self.orbitFooter:SetPoint("BOTTOMLEFT", ColorPickerFrame, "BOTTOMLEFT", GRADIENT_BAR_PADDING, 12)
        self.orbitFooter:SetPoint("BOTTOMRIGHT", ColorPickerFrame, "BOTTOMRIGHT", -GRADIENT_BAR_PADDING, 12)
        self.orbitFooter:SetHeight(FOOTER_HEIGHT)
        
        self.orbitFooter.Divider = self.orbitFooter:CreateTexture(nil, "ARTWORK")
        self.orbitFooter.Divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
        self.orbitFooter.Divider:SetSize(280, 16)
        self.orbitFooter.Divider:SetPoint("TOP", self.orbitFooter, "TOP", 0, FOOTER_DIVIDER_OFFSET)
        
        self.applyButton = CreateFrame("Button", nil, self.orbitFooter, "UIPanelButtonTemplate")
        self.applyButton:SetText("Apply Color")
        self.applyButton:SetHeight(FOOTER_BUTTON_HEIGHT)
        self.applyButton:SetPoint("TOPLEFT", self.orbitFooter, "TOPLEFT", 0, -FOOTER_TOP_PADDING)
        self.applyButton:SetPoint("TOPRIGHT", self.orbitFooter, "TOPRIGHT", 0, -FOOTER_TOP_PADDING)
        self.applyButton:SetScript("OnClick", function()
            lib.wasCancelled = false
            ColorPickerFrame:Hide()
        end)
    end
    
    self:CreateGradientBar()
    self:CreateSwatchProxy()
    self:CreateClassColorSwatch()
    self:SetupClassColorEvents()
    self:CreateDragTexture()
    
    ColorPickerFrame:HookScript("OnShow", function()
        ColorPickerFrame:SetHeight(lib.originalHeight + GRADIENT_BAR_EXTENSION)
        if ColorPickerFrame.Footer then ColorPickerFrame.Footer:Hide() end
        if ColorPickerFrame.Header then ColorPickerFrame.Header:Hide() end
        
        local hexBox = ColorPickerFrame.Content.HexBox
        if hexBox then
            hexBox:ClearAllPoints()
            hexBox:SetPoint("TOP", lib.classColorSwatch, "BOTTOM", 0, -20)
            hexBox:SetWidth(HEX_BOX_WIDTH)
        end
        
        if ColorPickerFrame.Content.ColorSwatchOriginal then ColorPickerFrame.Content.ColorSwatchOriginal:Hide() end
        if lib.closeButton then lib.closeButton:Show() end
        if lib.orbitFooter then lib.orbitFooter:Show() end
        
        lib:UpdateClassColorSwatch()
        if lib.classColorSwatch then lib.classColorSwatch:Show() end
        
        if lib.modeTitle then
            lib.modeTitle:SetText(lib.multiPinMode and "Multi-Color Mode" or "Single Color Mode")
            lib.modeTitle:Show()
        end
        
        if lib.gradientBar then
            lib.gradientBar:Show()
            C_Timer.After(0.05, function()
                if lib.gradientBar then lib.gradientBar:Refresh() end
                lib:UpdateApplyButtonState()
            end)
        end
    end)
    
    ColorPickerFrame:HookScript("OnHide", function()
        ColorPickerFrame:SetHeight(lib.originalHeight)
        if lib.gradientBar then lib.gradientBar:Hide() end
        if lib.classColorSwatch then lib.classColorSwatch:Hide() end
        lib:EndDrag()
        
        if lib.callback then
            local serializedPins = {}
            for _, pin in ipairs(lib.pins) do
                local resolvedColor = ResolveClassColorPin(pin)
                local serialized = { 
                    position = pin.position, 
                    color = { r = resolvedColor.r, g = resolvedColor.g, b = resolvedColor.b, a = resolvedColor.a or 1 }
                }
                if pin.type then serialized.type = pin.type end
                table.insert(serializedPins, serialized)
            end
            lib.callback({ curve = lib.colorCurve, pins = serializedPins }, lib.wasCancelled)
        end
        lib.wasCancelled = false
    end)
    
    self.isInitialized = true
end

-- [ PUBLIC API ] ------------------------------------------------------------------------------------
-- Auto-detects data type: curve ({ pins = {...} } or native ColorCurve) vs simple color ({ r, g, b })
local function IsCurveData(data)
    if not data then return false end
    if data.pins then return true end
    if data.GetPoints then return true end
    return false
end

-- Opens the color picker with auto-detected mode.
-- options.initialData: auto-detected - { r, g, b, a } for single color, { pins = {...} } for curve
-- options.callback: function(result, wasCancelled) - Called on close
-- options.hasOpacity: boolean - Whether to show opacity slider (default true)
function lib:Open(options)
    options = options or {}
    self.wasCancelled = false
    self.callback = options.callback
    
    local data = options.initialData or options.initialCurve or options.initialColor
    self.multiPinMode = not options.forceSingleColor
    
    wipe(self.pins)
    if self.multiPinMode then
        self:LoadFromCurve(data)
    elseif data then
        local c = NormalizeColor(data)
        table.insert(self.pins, { position = 0.5, color = c })
    end
    
    self:Initialize()
    
    if self.gradientBar then
        for _, handle in ipairs(self.gradientBar.pinHandles) do handle:Hide() end
        self.gradientBar:Refresh()
    end
    
    local initialColor = (self.pins[1] and self.pins[1].color) or { r = 1, g = 1, b = 1, a = 1 }
    
    ColorPickerFrame:SetupColorPickerAndShow({
        swatchFunc = function() end,
        opacityFunc = function() end,
        cancelFunc = function() lib.wasCancelled = true end,
        hasOpacity = options.hasOpacity ~= false,
        r = initialColor.r,
        g = initialColor.g,
        b = initialColor.b,
        opacity = initialColor.a,
    })
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    
    if self.gradientBar then self.gradientBar:Refresh() end
end

function lib:IsOpen() return ColorPickerFrame:IsShown() end
