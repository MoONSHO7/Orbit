-- [ LibOrbitColorPicker-1.0 ] ----------------------------------------------------------------------

local MAJOR, MINOR = "LibOrbitColorPicker-1.0", 4
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- [ CONSTANTS ] ------------------------------------------------------------------------------------

local PICKER_WIDTH = 350
local PICKER_HEIGHT = 300
local WHEEL_SIZE = 128
local WHEEL_PADDING_LEFT = 20
local WHEEL_OFFSET_Y = -35
local VALUE_BAR_WIDTH = 32
local VALUE_BAR_HEIGHT = 128
local VALUE_BAR_GAP = 20
local ALPHA_BAR_WIDTH = 32
local ALPHA_BAR_GAP = 28
local WHEEL_THUMB_SIZE = 10
local VALUE_THUMB_WIDTH = 48
local VALUE_THUMB_HEIGHT = 14
local SWATCH_WIDTH = 44
local SWATCH_HEIGHT = 28
local SWATCH_BORDER = 2
local SWATCH_GAP = 8
local HEX_BOX_WIDTH = 72
local HEX_BOX_HEIGHT = 22
local GRADIENT_BAR_HEIGHT = 24
local GRADIENT_BAR_GAP = 8
local GRADIENT_BAR_PADDING = 23
local PIN_CIRCLE_SIZE = 12
local PIN_STEM_WIDTH = 2
local PIN_STEM_HEIGHT = 14
local DRAG_CURSOR_SIZE = 24

local NOTCH_HEIGHT = 6
local NOTCH_WIDTH = 1
local NOTCH_GAP = 2
local CLASS_SWATCH_GAP = 8
local TITLE_OFFSET_Y = -15
local FOOTER_TOP_PADDING = 8
local FOOTER_BOTTOM_PADDING = 4
local FOOTER_BUTTON_HEIGHT = 20
local FOOTER_DIVIDER_OFFSET = 6
local FOOTER_HEIGHT = FOOTER_TOP_PADDING + FOOTER_BUTTON_HEIGHT + FOOTER_BOTTOM_PADDING
local FOOTER_MARGIN_BOTTOM = 8
local SWATCH_FRAME_LEVEL_OFFSET = 10
local BAR_FRAME_LEVEL = 100
local DRAG_FRAME_LEVEL = 1000
local PIN_HANDLE_FRAME_LEVEL = 100
local GHOST_PIN_ALPHA = 0.6
local REFRESH_DELAY = 0.05
local NOTCH_POSITION_DELAY = 0.1
local INFO_BUTTON_SIZE = 32
local INFO_MARKER_SIZE = 24
local INFO_MARKER_FRAME_LEVEL = 512
local INFO_TOOLTIP_PADDING = 10
local PIN_NUDGE_STEP = 0.01
local PIN_NUDGE_FINE = 0.001
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local CHECKERBOARD_TEXTURE = "Interface\\AddOns\\Orbit\\Core\\Libs\\LibOrbitColorPicker-1.0\\checkerboard"
local WHEEL_TEXTURE = "Interface\\Buttons\\UI-ColorPicker-Buttons"
local DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 }

-- [ MODULE STATE ] ---------------------------------------------------------------------------------

lib.pins = lib.pins or {}
lib.colorCurve = nil
lib.callback = nil
lib.wasCancelled = false
lib.snapshotPins = nil
lib.multiPinMode = false

lib.ui = lib.ui or {}
lib.drag = lib.drag or {}
lib.info = lib.info or { markers = {} }

-- [ UTILITY ] --------------------------------------------------------------------------------------

local function SortPinsByPosition(a, b) return a.position < b.position end
local function ClampPosition(x) return math.max(0, math.min(1, x)) end

local function GetCurrentClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    return color and { r = color.r, g = color.g, b = color.b, a = 1 } or DEFAULT_COLOR
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

local function SerializePins(pins)
    local result = {}
    for _, pin in ipairs(pins) do
        local resolved = ResolveClassColorPin(pin)
        local entry = { position = pin.position, color = { r = resolved.r, g = resolved.g, b = resolved.b, a = resolved.a or 1 } }
        if pin.type then entry.type = pin.type end
        result[#result + 1] = entry
    end
    return result
end

local function DeepCopyPins(pins)
    local copy = {}
    for _, pin in ipairs(pins) do
        local snap = { position = pin.position, color = { r = pin.color.r, g = pin.color.g, b = pin.color.b, a = pin.color.a } }
        if pin.type then snap.type = pin.type end
        copy[#copy + 1] = snap
    end
    return copy
end

local function GetSortedPins()
    local sorted = {}
    for _, pin in ipairs(lib.pins) do sorted[#sorted + 1] = pin end
    table.sort(sorted, SortPinsByPosition)
    return sorted
end

local function ColorToHex(r, g, b)
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function HexToColor(hex)
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return nil end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not r or not g or not b then return nil end
    return r / 255, g / 255, b / 255
end

-- [ PIN VISUALS ] ----------------------------------------------------------------------------------

local function CreatePinVisual(parent, alpha)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(PIN_CIRCLE_SIZE + 4, PIN_STEM_HEIGHT + PIN_CIRCLE_SIZE)

    frame.Stem = frame:CreateTexture(nil, "BACKGROUND")
    frame.Stem:SetSize(PIN_STEM_WIDTH, PIN_STEM_HEIGHT)
    frame.Stem:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    frame.Stem:SetColorTexture(1, 1, 1, alpha or 1)

    frame.CircleBorder = frame:CreateTexture(nil, "BORDER")
    frame.CircleBorder:SetSize(PIN_CIRCLE_SIZE + 2, PIN_CIRCLE_SIZE + 2)
    frame.CircleBorder:SetPoint("BOTTOM", frame.Stem, "TOP", 0, -1)
    frame.CircleBorder:SetColorTexture(0, 0, 0, alpha or 1)

    frame.Circle = frame:CreateTexture(nil, "ARTWORK")
    frame.Circle:SetSize(PIN_CIRCLE_SIZE, PIN_CIRCLE_SIZE)
    frame.Circle:SetPoint("CENTER", frame.CircleBorder, "CENTER", 0, 0)
    frame.Circle:SetTexture(WHITE_TEXTURE)

    if alpha and alpha < 1 then frame:SetAlpha(alpha) end
    return frame
end

-- [ GRADIENT BAR MIXIN ] ---------------------------------------------------------------------------

local GradientBarMixin = {}

function GradientBarMixin:OnLoad()
    self.segments = {}
    self.pinHandles = {}
end

function GradientBarMixin:GetOrCreateSegment(index)
    if self.segments[index] then return self.segments[index] end
    local seg = self.SegmentContainer:CreateTexture(nil, "ARTWORK")
    seg:SetTexture(WHITE_TEXTURE)
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
    local pins = GetSortedPins()
    local barWidth, barHeight = self.SegmentContainer:GetWidth(), self.SegmentContainer:GetHeight()
    if barWidth <= 0 or barHeight <= 0 then return end

    self.SolidTexture:Hide()
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
        seg:ClearAllPoints()
        seg:SetPoint("LEFT", self.SegmentContainer, "LEFT", leftX, 0)
        seg:SetSize(math.max(1, rightX - leftX), barHeight)
        seg:SetGradient("HORIZONTAL", ToColorMixin(ResolveClassColorPin(left)), ToColorMixin(ResolveClassColorPin(right)))
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
    local pins = GetSortedPins()
    local barWidth = self.SegmentContainer:GetWidth()
    if barWidth <= 0 then return end

    for _, handle in ipairs(self.pinHandles) do handle:Hide() end

    for i, pin in ipairs(pins) do
        local handle = self.pinHandles[i] or lib:CreatePinHandle(self)
        self.pinHandles[i] = handle
        handle.pinIndex, handle.pinData = i, pin
        handle:ClearAllPoints()
        handle:SetPoint("BOTTOM", self.SegmentContainer, "TOP", (pin.position - 0.5) * barWidth, 0)
        local resolved = ResolveClassColorPin(pin)
        handle.Circle:SetColorTexture(resolved.r, resolved.g, resolved.b, resolved.a or 1)
        handle:SetFrameStrata("TOOLTIP")
        handle:SetFrameLevel(PIN_HANDLE_FRAME_LEVEL)
        handle:EnableKeyboard(lib.nudgePin == pin)
        handle:Show()
    end
end

function GradientBarMixin:OnMouseUp(button)
    if button == "RightButton" or not lib.drag.active then return end
    lib:EndDrag()
end

function GradientBarMixin:OnEnter()
    if lib.drag.active then
        self.DropHighlight:Show()
        lib:ShowGhostPin()
    end
end

function GradientBarMixin:OnLeave()
    self.DropHighlight:Hide()
    lib:HideGhostPin()
end

-- [ PIN HANDLE ] -----------------------------------------------------------------------------------

function lib:CreatePinHandle(gradientBar)
    local handle = CreateFrame("Button", nil, gradientBar.PinsContainer)
    handle:SetSize(PIN_CIRCLE_SIZE + 4, PIN_STEM_HEIGHT + PIN_CIRCLE_SIZE)
    handle:EnableMouse(true)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("RightButtonUp")

    local visual = CreatePinVisual(handle, 1)
    visual:SetAllPoints()
    handle.Stem = visual.Stem
    handle.CircleBorder = visual.CircleBorder
    handle.Circle = visual.Circle

    handle:SetScript("OnEnter", function(self)
        if not self.pinData then return end
        lib.nudgePin = self.pinData
        self:EnableKeyboard(true)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(string.format("Position: %.1f%%", self.pinData.position * 100))
        if lib.multiPinMode then GameTooltip:AddLine("Arrow keys to nudge, Shift for fine", 0.5, 0.5, 0.5) end
        GameTooltip:Show()
    end)

    handle:SetScript("OnLeave", function(self)
        lib.nudgePin = nil
        self:EnableKeyboard(false)
        GameTooltip:Hide()
    end)

    handle:SetScript("OnDragStart", function(self)
        if not lib.multiPinMode then return end
        self:StartMoving()
        self:SetFrameStrata("TOOLTIP")
        self:SetClampedToScreen(true)
        self:SetScript("OnUpdate", function(self)
            local handleX = self:GetCenter()
            if not handleX then return end
            local barLeft = gradientBar.SegmentContainer:GetLeft()
            local barWidth = gradientBar.SegmentContainer:GetWidth()
            local pct = ClampPosition((handleX - barLeft) / barWidth) * 100
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(string.format("Position: %.1f%%", pct))
            GameTooltip:Show()
        end)
    end)

    handle:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:StopMovingOrSizing()
        self:SetFrameStrata("TOOLTIP")
        local handleX = self:GetCenter()
        local barLeft = gradientBar.SegmentContainer:GetLeft()
        local barWidth = gradientBar.SegmentContainer:GetWidth()
        if self.pinData then self.pinData.position = ClampPosition((handleX - barLeft) / barWidth) end
        gradientBar:Refresh()
        lib:UpdateCurve()
        GameTooltip:Hide()
    end)

    handle:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.pinData then lib:RemovePin(self.pinData) end
    end)

    handle:SetScript("OnKeyDown", function(self, key)
        if not lib.multiPinMode or not lib.nudgePin then
            self:SetPropagateKeyboardInput(true)
            return
        end
        local step = IsShiftKeyDown() and PIN_NUDGE_FINE or PIN_NUDGE_STEP
        if key == "LEFT" then
            lib.nudgePin.position = ClampPosition(lib.nudgePin.position - step)
        elseif key == "RIGHT" then
            lib.nudgePin.position = ClampPosition(lib.nudgePin.position + step)
        else
            self:SetPropagateKeyboardInput(true)
            return
        end
        self:SetPropagateKeyboardInput(false)
        gradientBar:Refresh()
        lib:UpdateCurve()
        lib:UpdateApplyButtonState()
        if GameTooltip:IsOwned(self) then
            GameTooltip:ClearLines()
            GameTooltip:AddLine(string.format("Position: %.1f%%", lib.nudgePin.position * 100))
            GameTooltip:AddLine("Arrow keys to nudge, Shift for fine", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end
    end)

    return handle
end

-- [ CLASS COLOR SWATCH ] ---------------------------------------------------------------------------

function lib:CreateClassColorSwatch()
    if self.ui.classSwatch then return self.ui.classSwatch end

    local frame = CreateFrame("Frame", nil, self.ui.frame, "BackdropTemplate")
    frame:SetSize(SWATCH_WIDTH, SWATCH_HEIGHT)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({ bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = SWATCH_BORDER })
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    frame.Label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Label:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame.Label:SetText("Class")
    frame.Label:SetTextColor(0.7, 0.7, 0.7, 1)

    frame:SetScript("OnDragStart", function()
        if not lib.multiPinMode and #lib.pins > 0 then return end
        local c = GetCurrentClassColor()
        lib:StartDrag(c.r, c.g, c.b, c.a, true)
    end)

    frame:SetScript("OnDragStop", function() lib:EndDrag() end)

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Class Color", 1, 0.82, 0)
        local hint = (lib.multiPinMode or #lib.pins == 0) and "Drag to gradient bar to add as pin" or "Single color mode (remove pin to add new)"
        GameTooltip:AddLine(hint, 1, 1, 1)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.ui.classSwatch = frame
    self:UpdateClassColorSwatch()
    return frame
end

function lib:UpdateClassColorSwatch()
    if not self.ui.classSwatch then return end
    local c = GetCurrentClassColor()
    self.ui.classSwatch:SetBackdropColor(c.r, c.g, c.b, 1)
end

function lib:SetupClassColorEvents()
    if self.ui.classEventFrame then return end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:SetScript("OnEvent", function() lib:UpdateClassColorSwatch() end)
    self.ui.classEventFrame = f
end

-- [ DRAG SYSTEM ] ----------------------------------------------------------------------------------

function lib:CreateDragTexture()
    if self.drag.texture then return self.drag.texture end

    local tex = CreateFrame("Frame", nil, UIParent)
    tex:SetSize(DRAG_CURSOR_SIZE, DRAG_CURSOR_SIZE)
    tex:SetFrameStrata("TOOLTIP")
    tex:SetFrameLevel(DRAG_FRAME_LEVEL)

    tex.Border = tex:CreateTexture(nil, "BORDER")
    tex.Border:SetAllPoints()
    tex.Border:SetColorTexture(0, 0, 0, 1)

    tex.Color = tex:CreateTexture(nil, "ARTWORK")
    tex.Color:SetPoint("TOPLEFT", 2, -2)
    tex.Color:SetPoint("BOTTOMRIGHT", -2, 2)
    tex.Color:SetTexture(WHITE_TEXTURE)
    tex:Hide()

    tex:SetScript("OnUpdate", function(self)
        if not lib.drag.active then self:Hide() return end
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

        if lib.ui.gradientBar and lib.ui.gradientBar:IsMouseOver() then
            lib.ui.gradientBar.DropHighlight:Show()
            lib:ShowGhostPin()
        else
            if lib.ui.gradientBar then lib.ui.gradientBar.DropHighlight:Hide() end
            lib:HideGhostPin()
        end
    end)

    self.drag.texture = tex
    return tex
end

function lib:StartDrag(r, g, b, a, isClassDrag)
    if not self.multiPinMode and #self.pins > 0 then return end
    self.drag.active = true
    self.drag.color = { r = r, g = g, b = b, a = a or 1 }
    self.drag.type = isClassDrag and "class" or nil
    local tex = self:CreateDragTexture()
    tex.Color:SetVertexColor(r, g, b, a or 1)
    tex:Show()
end

function lib:EndDrag()
    if not self.drag.active then return end
    self.drag.active = false
    if self.drag.texture then self.drag.texture:Hide() end
    self:HideGhostPin()
    if self.ui.gradientBar then self.ui.gradientBar.DropHighlight:Hide() end

    if self.ui.gradientBar and self.ui.gradientBar:IsMouseOver() and self.drag.color then
        local x = GetCursorPosition() / self.ui.gradientBar:GetEffectiveScale()
        local barLeft = self.ui.gradientBar.SegmentContainer:GetLeft()
        local barWidth = self.ui.gradientBar.SegmentContainer:GetWidth()
        self:AddPin(ClampPosition((x - barLeft) / barWidth), self.drag.color, self.drag.type)
    end
    self.drag.color = nil
    self.drag.type = nil
end

-- [ GHOST PIN ] ------------------------------------------------------------------------------------

function lib:ShowGhostPin()
    if not self.ui.gradientBar or not self.drag.color then return end

    if not self.ui.ghostPin then
        self.ui.ghostPin = CreatePinVisual(self.ui.gradientBar.PinsContainer, GHOST_PIN_ALPHA)
    end

    local x = GetCursorPosition() / self.ui.gradientBar:GetEffectiveScale()
    local barLeft = self.ui.gradientBar.SegmentContainer:GetLeft()
    local barWidth = self.ui.gradientBar.SegmentContainer:GetWidth()
    local position = ClampPosition((x - barLeft) / barWidth)
    self.ui.ghostPin:ClearAllPoints()
    self.ui.ghostPin:SetPoint("BOTTOM", self.ui.gradientBar.SegmentContainer, "TOP", (position - 0.5) * barWidth, 0)
    self.ui.ghostPin.Circle:SetVertexColor(self.drag.color.r, self.drag.color.g, self.drag.color.b, self.drag.color.a or 1)
    self.ui.ghostPin:Show()
end

function lib:HideGhostPin()
    if self.ui.ghostPin then self.ui.ghostPin:Hide() end
end

function lib:UpdateApplyButtonState()
    if not self.ui.applyButton then return end
    self.ui.applyButton:SetEnabled(true)
    self.ui.applyButton:SetText((self.pins and #self.pins > 0) and "Apply Color" or "Clear Color")
end

-- [ PIN MANAGEMENT ] -------------------------------------------------------------------------------

function lib:AddPin(position, color, pinType)
    local pin = { position = ClampPosition(position), color = NormalizeColor(color) }
    if pinType then pin.type = pinType end
    self.pins[#self.pins + 1] = pin
    self:UpdateCurve()
    if self.ui.gradientBar then self.ui.gradientBar:Refresh() end
end

function lib:AddClassColorPin(position)
    self.pins[#self.pins + 1] = { position = ClampPosition(position), color = GetCurrentClassColor(), type = "class" }
    self:UpdateCurve()
    if self.ui.gradientBar then self.ui.gradientBar:Refresh() end
end

function lib:RemovePin(pinToRemove)
    for i, pin in ipairs(self.pins) do
        if pin == pinToRemove then
            table.remove(self.pins, i)
            break
        end
    end
    self:UpdateCurve()
    if self.ui.gradientBar then self.ui.gradientBar:Refresh() end
end

function lib:ClearPins()
    wipe(self.pins)
    self:UpdateCurve()
    if self.ui.gradientBar then self.ui.gradientBar:Refresh() end
end

-- [ COLORCURVE INTEGRATION ] -----------------------------------------------------------------------

function lib:BuildColorCurve()
    local curve = C_CurveUtil.CreateColorCurve()
    for _, pin in ipairs(GetSortedPins()) do
        curve:AddPoint(pin.position, ToColorMixin(ResolveClassColorPin(pin)))
    end
    return curve
end

function lib:UpdateCurve()
    self.colorCurve = self:BuildColorCurve()
    if self.callback then
        self.callback({ curve = self.colorCurve, pins = SerializePins(self.pins) }, false)
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
            self.pins[#self.pins + 1] = newPin
        end
    elseif curveData.GetPoints then
        for _, point in ipairs(curveData:GetPoints()) do
            self.pins[#self.pins + 1] = { position = point.x, color = NormalizeColor(point.y) }
        end
    end

    self:UpdateCurve()
    if self.ui.gradientBar then self.ui.gradientBar:Refresh() end
end

-- [ GRADIENT BAR CREATION ] ------------------------------------------------------------------------

function lib:CreateGradientBar()
    if self.ui.gradientBar then return self.ui.gradientBar end

    local bar = CreateFrame("Frame", nil, UIParent)
    Mixin(bar, GradientBarMixin)
    bar:SetHeight(GRADIENT_BAR_HEIGHT)
    bar:SetFrameStrata("TOOLTIP")
    bar:SetFrameLevel(BAR_FRAME_LEVEL)
    bar:SetPoint("LEFT", self.ui.frame, "LEFT", GRADIENT_BAR_PADDING, 0)
    bar:SetPoint("RIGHT", self.ui.frame, "RIGHT", -GRADIENT_BAR_PADDING, 0)
    bar:SetPoint("BOTTOM", self.ui.footer, "TOP", 0, GRADIENT_BAR_GAP)

    bar.SegmentContainer = CreateFrame("Frame", nil, bar)
    bar.SegmentContainer:SetAllPoints()
    bar.SegmentContainer:SetScript("OnSizeChanged", function(self, width, height)
        if width > 0 and height > 0 then bar:Refresh() end
    end)

    bar.Checkerboard = bar.SegmentContainer:CreateTexture(nil, "BACKGROUND")
    bar.Checkerboard:SetAllPoints()
    bar.Checkerboard:SetTexture(CHECKERBOARD_TEXTURE, "REPEAT", "REPEAT")
    bar.Checkerboard:SetHorizTile(true)
    bar.Checkerboard:SetVertTile(true)

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

    bar.Notches = {}
    for _, pct in ipairs({ 0.25, 0.5, 0.75 }) do
        local notch = bar:CreateTexture(nil, "OVERLAY")
        notch:SetColorTexture(1, 1, 1, 0.6)
        notch:SetSize(NOTCH_WIDTH, NOTCH_HEIGHT)
        notch.pct = pct
        bar.Notches[#bar.Notches + 1] = notch
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
    C_Timer.After(NOTCH_POSITION_DELAY, UpdateNotchPositions)

    bar:OnLoad()
    bar:EnableMouse(true)
    bar:SetScript("OnMouseUp", bar.OnMouseUp)
    bar:SetScript("OnEnter", bar.OnEnter)
    bar:SetScript("OnLeave", bar.OnLeave)

    self.ui.gradientBar = bar
    return bar
end

-- [ FRAME CREATION ] -------------------------------------------------------------------------------

function lib:CreatePickerFrame()
    if self.ui.frame then return self.ui.frame end

    local f = CreateFrame("Frame", "OrbitColorPickerFrame", UIParent)
    f:SetSize(PICKER_WIDTH, PICKER_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")

    local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
    border:SetAllPoints(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            lib.wasCancelled = true
            lib:CloseFrame()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    f:SetScript("OnHide", function()
        if lib.ui.gradientBar then lib.ui.gradientBar:Hide() end
        if lib.ui.classSwatch then lib.ui.classSwatch:Hide() end
        lib:HideInfoMarkers()
        if lib.info.button then lib.info.button:Hide() end
        lib:EndDrag()

        if lib.callback then
            if lib.wasCancelled then
                lib.callback({ curve = lib.colorCurve, pins = SerializePins(lib.snapshotPins) }, true)
            elseif lib.pins and #lib.pins > 0 then
                lib.callback({ curve = lib.colorCurve, pins = SerializePins(lib.pins) }, false)
            else
                lib.callback(nil, false)
            end
        end
        lib.snapshotPins = nil
        lib.wasCancelled = false
    end)

    f:Hide()
    self.ui.frame = f
    return f
end

function lib:CloseFrame()
    if self.ui.frame then self.ui.frame:Hide() end
end

-- [ COLOR SELECT WIDGET ] --------------------------------------------------------------------------

function lib:CreateColorSelect()
    if self.ui.colorSelect then return self.ui.colorSelect end

    local cs = CreateFrame("ColorSelect", nil, self.ui.frame)
    cs:SetSize(WHEEL_SIZE + VALUE_BAR_GAP + VALUE_BAR_WIDTH + ALPHA_BAR_GAP + ALPHA_BAR_WIDTH, VALUE_BAR_HEIGHT)
    cs:SetPoint("TOPLEFT", self.ui.frame, "TOPLEFT", WHEEL_PADDING_LEFT, WHEEL_OFFSET_Y)

    local wheel = cs:CreateTexture(nil, "ARTWORK")
    wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
    wheel:SetPoint("TOPLEFT", 0, 0)
    cs:SetColorWheelTexture(wheel)

    local wheelThumb = cs:CreateTexture(nil, "OVERLAY")
    wheelThumb:SetTexture(WHEEL_TEXTURE)
    wheelThumb:SetSize(WHEEL_THUMB_SIZE, WHEEL_THUMB_SIZE)
    wheelThumb:SetTexCoord(0, 0.15625, 0, 0.625)
    cs:SetColorWheelThumbTexture(wheelThumb)

    local value = cs:CreateTexture(nil, "ARTWORK")
    value:SetSize(VALUE_BAR_WIDTH, VALUE_BAR_HEIGHT)
    value:SetPoint("LEFT", wheel, "RIGHT", VALUE_BAR_GAP, 0)
    cs:SetColorValueTexture(value)

    local valueThumb = cs:CreateTexture(nil, "OVERLAY")
    valueThumb:SetTexture(WHEEL_TEXTURE)
    valueThumb:SetSize(VALUE_THUMB_WIDTH, VALUE_THUMB_HEIGHT)
    valueThumb:SetTexCoord(0.25, 1.0, 0, 0.875)
    cs:SetColorValueThumbTexture(valueThumb)

    local alphaChecker = cs:CreateTexture(nil, "BACKGROUND")
    alphaChecker:SetSize(ALPHA_BAR_WIDTH, VALUE_BAR_HEIGHT)
    alphaChecker:SetPoint("LEFT", value, "RIGHT", ALPHA_BAR_GAP, 0)
    alphaChecker:SetTexture(CHECKERBOARD_TEXTURE, "REPEAT", "REPEAT")
    alphaChecker:SetHorizTile(true)
    alphaChecker:SetVertTile(true)

    local alpha = cs:CreateTexture(nil, "ARTWORK")
    alpha:SetSize(ALPHA_BAR_WIDTH, VALUE_BAR_HEIGHT)
    alpha:SetPoint("LEFT", value, "RIGHT", ALPHA_BAR_GAP, 0)
    cs:SetColorAlphaTexture(alpha)

    local alphaThumb = cs:CreateTexture(nil, "OVERLAY")
    alphaThumb:SetTexture(WHEEL_TEXTURE)
    alphaThumb:SetSize(VALUE_THUMB_WIDTH, VALUE_THUMB_HEIGHT)
    alphaThumb:SetTexCoord(0.25, 1.0, 0, 0.875)
    cs:SetColorAlphaThumbTexture(alphaThumb)

    cs:SetScript("OnColorSelect", function(self, r, g, b)
        lib:OnColorChanged(r, g, b)
    end)

    self.ui.colorSelect = cs
    return cs
end

function lib:OnColorChanged(r, g, b)
    local a = self.ui.colorSelect and self.ui.colorSelect:GetColorAlpha() or 1
    if self.ui.currentSwatch then
        self.ui.currentSwatch.Color:SetColorTexture(r, g, b, a)
    end
    if self.ui.hexBox then
        self.ui.hexBox:SetText(ColorToHex(r, g, b))
    end

    if #self.pins > 0 and not self.multiPinMode then
        local a = self.ui.colorSelect and self.ui.colorSelect:GetColorAlpha() or 1
        self.pins[1].color = { r = r, g = g, b = b, a = a }
        if self.pins[1].type ~= "class" then
            self:UpdateCurve()
            if self.ui.gradientBar then self.ui.gradientBar:Refresh() end
        end
    end
end



-- [ CURRENT COLOR SWATCH ] -------------------------------------------------------------------------

function lib:CreateCurrentSwatch()
    if self.ui.currentSwatch then return self.ui.currentSwatch end

    local frame = CreateFrame("Frame", nil, self.ui.frame, "BackdropTemplate")
    frame:SetSize(SWATCH_WIDTH, SWATCH_HEIGHT)
    frame:SetBackdrop({ bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = SWATCH_BORDER })
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame.Checkerboard = frame:CreateTexture(nil, "BACKGROUND")
    frame.Checkerboard:SetPoint("TOPLEFT", SWATCH_BORDER, -SWATCH_BORDER)
    frame.Checkerboard:SetPoint("BOTTOMRIGHT", -SWATCH_BORDER, SWATCH_BORDER)
    frame.Checkerboard:SetTexture(CHECKERBOARD_TEXTURE, "REPEAT", "REPEAT")
    frame.Checkerboard:SetHorizTile(true)
    frame.Checkerboard:SetVertTile(true)

    frame.Color = frame:CreateTexture(nil, "ARTWORK")
    frame.Color:SetPoint("TOPLEFT", SWATCH_BORDER, -SWATCH_BORDER)
    frame.Color:SetPoint("BOTTOMRIGHT", -SWATCH_BORDER, SWATCH_BORDER)
    frame.Color:SetColorTexture(1, 1, 1, 1)

    frame.Label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Label:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame.Label:SetText("Color")
    frame.Label:SetTextColor(0.7, 0.7, 0.7, 1)

    frame:SetScript("OnDragStart", function()
        if not lib.multiPinMode and #lib.pins > 0 then return end
        local r, g, b = lib.ui.colorSelect:GetColorRGB()
        local a = lib.ui.colorSelect and lib.ui.colorSelect:GetColorAlpha() or 1
        lib:StartDrag(r, g, b, a)
    end)

    frame:SetScript("OnDragStop", function() lib:EndDrag() end)

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Current Color", 1, 0.82, 0)
        local hint = (lib.multiPinMode or #lib.pins == 0) and "Drag to gradient bar to add as pin" or "Single color mode (remove pin to add new)"
        GameTooltip:AddLine(hint, 1, 1, 1)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.ui.currentSwatch = frame
    return frame
end

-- [ HEX INPUT ] ------------------------------------------------------------------------------------

function lib:CreateHexInput()
    if self.ui.hexBox then return self.ui.hexBox end

    local box = CreateFrame("EditBox", nil, self.ui.frame, "InputBoxTemplate")
    box:SetSize(HEX_BOX_WIDTH, HEX_BOX_HEIGHT)
    box:SetAutoFocus(false)
    box:SetMaxLetters(7)

    box.Label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    box.Label:SetPoint("RIGHT", box, "LEFT", -4, 0)
    box.Label:SetText("#")
    box.Label:SetTextColor(0.7, 0.7, 0.7, 1)

    box:SetScript("OnEnterPressed", function(self)
        local r, g, b = HexToColor(self:GetText())
        if r then lib.ui.colorSelect:SetColorRGB(r, g, b) end
        self:ClearFocus()
    end)

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    self.ui.hexBox = box
    return box
end

-- [ CLOSE BUTTON ] ---------------------------------------------------------------------------------

function lib:CreateCloseButton()
    if self.ui.closeButton then return end
    self.ui.closeButton = CreateFrame("Button", nil, self.ui.frame, "UIPanelCloseButton")
    self.ui.closeButton:SetPoint("TOPRIGHT", self.ui.frame, "TOPRIGHT", -2, -2)
    self.ui.closeButton:SetScript("OnClick", function()
        lib.wasCancelled = true
        lib:CloseFrame()
    end)
end

-- [ MODE TITLE ] -----------------------------------------------------------------------------------

function lib:CreateModeTitle()
    if self.ui.modeTitle then return end
    self.ui.modeTitle = self.ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.ui.modeTitle:SetPoint("TOP", self.ui.frame, "TOP", 0, TITLE_OFFSET_Y)
end

-- [ FOOTER ] ---------------------------------------------------------------------------------------

function lib:CreateFooter()
    if self.ui.footer then return end

    self.ui.footer = CreateFrame("Frame", nil, self.ui.frame)
    self.ui.footer:SetPoint("BOTTOMLEFT", self.ui.frame, "BOTTOMLEFT", GRADIENT_BAR_PADDING, FOOTER_MARGIN_BOTTOM)
    self.ui.footer:SetPoint("BOTTOMRIGHT", self.ui.frame, "BOTTOMRIGHT", -GRADIENT_BAR_PADDING, FOOTER_MARGIN_BOTTOM)
    self.ui.footer:SetHeight(FOOTER_HEIGHT)

    self.ui.footer.Divider = self.ui.footer:CreateTexture(nil, "ARTWORK")
    self.ui.footer.Divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
    self.ui.footer.Divider:SetSize(280, 16)
    self.ui.footer.Divider:SetPoint("TOP", self.ui.footer, "TOP", 0, FOOTER_DIVIDER_OFFSET)

    self.ui.applyButton = CreateFrame("Button", nil, self.ui.footer, "UIPanelButtonTemplate")
    self.ui.applyButton:SetText("Apply Color")
    self.ui.applyButton:SetHeight(FOOTER_BUTTON_HEIGHT)
    self.ui.applyButton:SetPoint("TOPLEFT", self.ui.footer, "TOPLEFT", 0, -FOOTER_TOP_PADDING)
    self.ui.applyButton:SetPoint("TOPRIGHT", self.ui.footer, "TOPRIGHT", 0, -FOOTER_TOP_PADDING)
    self.ui.applyButton:SetScript("OnClick", function()
        lib.wasCancelled = false
        lib:CloseFrame()
    end)
    self.ui.applyButton:SetScript("OnEnter", function(self)
        if not lib.pins or #lib.pins > 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("applies default color")
        GameTooltip:Show()
    end)
    self.ui.applyButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- [ LAYOUT ] ---------------------------------------------------------------------------------------

function lib:LayoutControls()
    local cs = self.ui.colorSelect
    local swatch = self.ui.currentSwatch
    local classSwatch = self.ui.classSwatch
    local hexBox = self.ui.hexBox

    if not self.ui.swatchContainer then
        self.ui.swatchContainer = CreateFrame("Frame", nil, self.ui.frame)
    end
    local container = self.ui.swatchContainer
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", cs, "TOPRIGHT", 2, 0)
    container:SetPoint("BOTTOMRIGHT", self.ui.frame, "RIGHT", -GRADIENT_BAR_PADDING, 0)

    swatch:SetParent(container)
    swatch:ClearAllPoints()
    swatch:SetPoint("TOP", container, "TOP", 0, -SWATCH_GAP)

    classSwatch:SetParent(container)
    classSwatch:ClearAllPoints()
    classSwatch:SetPoint("TOP", swatch, "BOTTOM", 0, -(CLASS_SWATCH_GAP + 14))

    hexBox:ClearAllPoints()
    hexBox:SetPoint("TOP", cs, "BOTTOMLEFT", WHEEL_SIZE / 2, -SWATCH_GAP)
end

-- [ INITIALIZE ] -----------------------------------------------------------------------------------

function lib:Initialize()
    if self.ui.initialized then return end

    self:CreatePickerFrame()
    self:CreateCloseButton()
    self:CreateModeTitle()
    self:CreateFooter()
    self:CreateGradientBar()
    self:CreateColorSelect()
    self:CreateCurrentSwatch()
    self:CreateHexInput()
    self:CreateClassColorSwatch()
    self:SetupClassColorEvents()
    self:CreateDragTexture()
    self:CreateInfoButton()

    self.ui.initialized = true
end

-- [ INFO SYSTEM ] ----------------------------------------------------------------------------------

local INFO_TOOLTIP_DIRECTIONS = {
    UP    = { arrow = "ArrowUp",    glow = "ArrowGlowUp",    point = "BOTTOM", rel = "TOP",    x = 0, y = INFO_TOOLTIP_PADDING },
    DOWN  = { arrow = "ArrowDown",  glow = "ArrowGlowDown",  point = "TOP",    rel = "BOTTOM", x = 0, y = -INFO_TOOLTIP_PADDING },
    LEFT  = { arrow = "ArrowLeft",  glow = "ArrowGlowLeft",  point = "RIGHT",  rel = "LEFT",   x = -INFO_TOOLTIP_PADDING, y = 0 },
    RIGHT = { arrow = "ArrowRight", glow = "ArrowGlowRight", point = "LEFT",   rel = "RIGHT",  x = INFO_TOOLTIP_PADDING,  y = 0 },
}

local INFO_PLATE_DATA = {
    { key = "wheel",    anchor = function() return lib.ui.colorSelect end,
      point = "TOPRIGHT", relPoint = "TOPRIGHT", xOff = -4, yOff = -4, tooltipDir = "LEFT",
      text = "Use the color wheel to select a hue and saturation. The vertical slider adjusts brightness." },
    { key = "swatch",   anchor = function() return lib.ui.currentSwatch end,
      point = "TOPRIGHT", relPoint = "TOPRIGHT", xOff = 4, yOff = 4, tooltipDir = "RIGHT",
      text = "This is your currently selected color. Drag it onto the gradient bar below to add it as a color stop." },
    { key = "class",    anchor = function() return lib.ui.classSwatch end,
      point = "TOPRIGHT", relPoint = "TOPRIGHT", xOff = 4, yOff = 4, tooltipDir = "RIGHT",
      text = "Your class color. Drag this onto the gradient bar to add a class-colored stop that updates dynamically with your spec." },
    { key = "gradient", anchor = function() return lib.ui.gradientBar end,
      point = "TOPRIGHT", relPoint = "TOPRIGHT", xOff = 4, yOff = 4, tooltipDir = "RIGHT",
      text = "The gradient bar visualizes your color curve. Drag colors here to add stops. Right-click a pin to remove it." },
    { key = "apply",    anchor = function() return lib.ui.applyButton end,
      point = "RIGHT", relPoint = "LEFT", xOff = -4, yOff = 0, tooltipDir = "LEFT",
      text = "Apply Color saves your gradient and closes the picker. Clearing all pins resets the component to its default color." },
}

function lib:CreateInfoButton()
    if self.info.button then return self.info.button end

    local btn = CreateFrame("Button", nil, self.ui.frame, "MainHelpPlateButton")
    btn:SetSize(INFO_BUTTON_SIZE, INFO_BUTTON_SIZE)
    btn:SetHitRectInsets(0, 0, 0, 0)
    btn:SetPoint("TOPLEFT", self.ui.frame, "TOPLEFT", 4, -4)
    btn.mainHelpPlateButtonTooltipText = "Toggle info markers to learn how to use the color picker."

    local innerSize = INFO_BUTTON_SIZE - 8
    btn.I:SetSize(innerSize, innerSize)
    btn.Ring:Hide()
    btn.BigIPulse:SetSize(innerSize, innerSize)
    btn.RingPulse:SetSize(INFO_BUTTON_SIZE - 4, INFO_BUTTON_SIZE - 4)
    local hl = btn:GetHighlightTexture()
    if hl then hl:SetSize(innerSize, innerSize) end

    btn:HookScript("OnEnter", function() HelpPlateTooltip:SetFrameStrata("TOOLTIP") end)
    btn:HookScript("OnMouseUp", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        lib:ToggleInfoMode()
    end)

    self.info.button = btn
    return btn
end

function lib:ShowInfoTooltip(anchor, direction, text)
    local dir = INFO_TOOLTIP_DIRECTIONS[direction] or INFO_TOOLTIP_DIRECTIONS.RIGHT
    HelpPlateTooltip.LingerAndFade:Stop()
    HelpPlateTooltip:ClearAllPoints()
    HelpPlateTooltip:SetParent(GetAppropriateTopLevelParent())
    HelpPlateTooltip:SetFrameStrata("TOOLTIP")
    HelpPlateTooltip:SetFrameLevel(2)
    HelpPlateTooltip:HideTextures()
    HelpPlateTooltip[dir.arrow]:Show()
    HelpPlateTooltip[dir.glow]:Show()
    HelpPlateTooltip:SetPoint(dir.point, anchor, dir.rel, dir.x, dir.y)
    HelpPlateTooltip.Text:SetText(text)
    HelpPlateTooltip:SetHeight(HelpPlateTooltip.Text:GetHeight() + 30)
    HelpPlateTooltip:Show()
end

function lib:CreateInfoMarker(data)
    local anchorFrame = data.anchor()
    if not anchorFrame then return nil end

    local marker = CreateFrame("Button", nil, self.ui.frame)
    marker:SetSize(INFO_MARKER_SIZE, INFO_MARKER_SIZE)
    marker:SetFrameStrata("TOOLTIP")
    marker:SetFrameLevel(INFO_MARKER_FRAME_LEVEL)
    marker:SetPoint(data.point, anchorFrame, data.relPoint, data.xOff, data.yOff)

    marker.Icon = marker:CreateTexture(nil, "ARTWORK")
    marker.Icon:SetTexture("Interface\\common\\help-i")
    marker.Icon:SetSize(INFO_MARKER_SIZE, INFO_MARKER_SIZE)
    marker.Icon:SetPoint("CENTER")

    marker:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    local hl = marker:GetHighlightTexture()
    hl:SetSize(INFO_MARKER_SIZE, INFO_MARKER_SIZE)
    hl:SetPoint("CENTER")

    marker:SetScript("OnEnter", function(self) lib:ShowInfoTooltip(self, data.tooltipDir, data.text) end)
    marker:SetScript("OnLeave", function() HelpPlateTooltip:Hide() end)
    return marker
end

function lib:ToggleInfoMode()
    self.info.active = not self.info.active
    if self.info.active then self:ShowInfoMarkers() else self:HideInfoMarkers() end
end

function lib:ShowInfoMarkers()
    for _, data in ipairs(INFO_PLATE_DATA) do
        if not self.info.markers[data.key] then
            self.info.markers[data.key] = self:CreateInfoMarker(data)
        end
        if self.info.markers[data.key] then self.info.markers[data.key]:Show() end
    end
end

function lib:HideInfoMarkers()
    for _, marker in pairs(self.info.markers) do marker:Hide() end
    if HelpPlateTooltip then HelpPlateTooltip:Hide() end
    self.info.active = false
end

-- [ PUBLIC API ] -----------------------------------------------------------------------------------

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
        local colorSource = (data.pins and data.pins[1]) and data.pins[1].color or data
        local pinData = { position = 0.5, color = NormalizeColor(colorSource) }
        if data.pins and data.pins[1] and data.pins[1].type then pinData.type = data.pins[1].type end
        self.pins[#self.pins + 1] = pinData
    end

    self:Initialize()

    self.snapshotPins = DeepCopyPins(self.pins)

    if self.ui.gradientBar then
        for _, handle in ipairs(self.ui.gradientBar.pinHandles) do handle:Hide() end
    end

    local initialColor = (self.pins[1] and self.pins[1].color) or DEFAULT_COLOR
    self.ui.colorSelect:SetColorRGB(initialColor.r, initialColor.g, initialColor.b)

    self.ui.colorSelect:SetColorAlpha(initialColor.a or 1)
    self:LayoutControls()

    if self.ui.modeTitle then
        self.ui.modeTitle:SetText(self.multiPinMode and "Multi-Color Mode" or "Single Color Mode")
    end

    self:UpdateClassColorSwatch()
    if self.ui.classSwatch then self.ui.classSwatch:Show() end
    if self.info.button then self.info.button:Show() end

    self.ui.frame:ClearAllPoints()
    self.ui.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 375, -75)
    self.ui.frame:Show()

    C_Timer.After(REFRESH_DELAY, function()
        if lib.ui.gradientBar then
            lib.ui.gradientBar:Show()
            lib.ui.gradientBar:Refresh()
        end
        lib:UpdateApplyButtonState()
    end)
end

function lib:IsOpen() return self.ui.frame and self.ui.frame:IsShown() end
