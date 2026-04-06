-- [ LibOrbitColorPicker-1.0 ] ----------------------------------------------------------------------

local MAJOR, MINOR = "LibOrbitColorPicker-1.0", 4
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- [ CONSTANTS ] ------------------------------------------------------------------------------------

local PICKER_WIDTH = 350
local PICKER_HEIGHT = 356
local WHEEL_SIZE = 128
local WHEEL_PADDING_LEFT = 20
local WHEEL_OFFSET_Y = -43
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
local GRADIENT_BAR_GAP = 16
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

local BAR_FRAME_LEVEL = 100
local DRAG_FRAME_LEVEL = 1000
local PIN_HANDLE_FRAME_LEVEL = 100
local GHOST_PIN_ALPHA = 0.6
local REFRESH_DELAY = 0.05
local NOTCH_POSITION_DELAY = 0.1
local INFO_BUTTON_SIZE = 32
local PIN_NUDGE_STEP = 0.01
local PIN_NUDGE_FINE = 0.001
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local LIB_PATH = debugstack(1, 1, 0):match("Interface.*LibOrbitColorPicker%-1%.0[\\/]")
local CHECKERBOARD_TEXTURE = LIB_PATH .. "checkerboard.tga"
local WHEEL_TEXTURE = "Interface\\Buttons\\UI-ColorPicker-Buttons"
local DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 }

-- [ MODULE STATE ] ---------------------------------------------------------------------------------

lib.recentColors = lib.recentColors or {}
lib.pins = lib.pins or {}
lib.colorCurve = nil
lib.callback = nil
lib.wasCancelled = false
lib.snapshotPins = nil
lib.multiPinMode = false
lib.desaturated = false
lib.hasDesaturation = false

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

    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)

    self.ui.classSwatch = frame
    self:UpdateClassColorSwatch()
    return frame
end

-- [ DESATURATION CHECKBOX ] ------------------------------------------------------------------------
local DESAT_CHECKBOX_SIZE = 18

function lib:CreateDesaturationCheckbox()
    if self.ui.desatCheckbox then return self.ui.desatCheckbox end
    local cb = CreateFrame("CheckButton", nil, self.ui.frame, "UICheckButtonTemplate")
    cb:SetSize(DESAT_CHECKBOX_SIZE, DESAT_CHECKBOX_SIZE)
    cb.text:SetText("")
    cb.Label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.Label:SetPoint("TOP", cb, "BOTTOM", 0, -1)
    cb.Label:SetText("Desat")
    cb.Label:SetTextColor(0.7, 0.7, 0.7, 1)
    cb:SetScript("OnClick", function(self)
        lib.desaturated = self:GetChecked()
        lib:UpdateCurve()
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Desaturated", 1, 0.82, 0)
        GameTooltip:AddLine("Apply grayscale to the texture", 1, 1, 1)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.ui.desatCheckbox = cb
    return cb
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
    self:AddRecentColor(pin)
    self:UpdateRecentColors()
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
        local result = { curve = self.colorCurve, pins = SerializePins(self.pins) }
        if self.hasDesaturation then result.desaturated = self.desaturated end
        self.callback(result, false)
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

-- [ RECENT COLORS ] --------------------------------------------------------------------------------

function lib:AddRecentColor(pin)
    if not pin or pin.type == "class" then return end
    local color = pin.color
    local hex = ColorToHex(color.r, color.g, color.b)
    
    -- Deduplicate
    for i = #self.recentColors, 1, -1 do
        local rc = self.recentColors[i]
        if ColorToHex(rc.r, rc.g, rc.b) == hex and math.abs((rc.a or 1) - (color.a or 1)) < 0.05 then
            table.remove(self.recentColors, i)
        end
    end
    
    table.insert(self.recentColors, 1, { r = color.r, g = color.g, b = color.b, a = color.a or 1 })
    
    -- Trim to 8
    while #self.recentColors > 8 do
        table.remove(self.recentColors)
    end
end

function lib:UpdateRecentColors()
    if not self.ui.recentColorsBar then return end
    for i = 1, 8 do
        local swatch = self.ui.recentColorsBar.swatches[i]
        local c = self.recentColors[i]
        if c then
            swatch:SetBackdropBorderColor(0, 0, 0, 1)
            swatch.Color:SetColorTexture(c.r, c.g, c.b, c.a or 1)
            swatch.Checkerboard:SetAlpha(1)
            swatch:EnableMouse(true)
            swatch.TooltipText = "Recent Color\nDrag to use as a pin"
            swatch.ColorModel = c
        else
            swatch:SetBackdropBorderColor(0, 0, 0, 0)
            swatch.Color:SetColorTexture(0, 0, 0, 0)
            swatch.Checkerboard:SetAlpha(0)
            swatch:EnableMouse(false)
            swatch.TooltipText = nil
            swatch.ColorModel = nil
        end
    end
end

function lib:CreateRecentColorsBar()
    if self.ui.recentColorsBar then return self.ui.recentColorsBar end

    local container = CreateFrame("Frame", nil, self.ui.gradientBar)
    container:SetPoint("BOTTOMLEFT", self.ui.gradientBar.PinsContainer, "TOPLEFT", 0, 2)
    container:SetPoint("BOTTOMRIGHT", self.ui.gradientBar.PinsContainer, "TOPRIGHT", 0, 2)
    container:SetHeight(31)
    container:SetFrameStrata("FULLSCREEN_DIALOG")
    container:SetFrameLevel(self.ui.frame:GetFrameLevel() + 50)
    
    container.swatches = {}
    
    -- Standard 304px width, 8 boxes of 31px with 8px gaps => exactly 304px.
    local swatchSize = 31
    local spacing = 8
    
    for i = 1, 8 do
        local swatch = CreateFrame("Frame", nil, container, "BackdropTemplate")
        swatch:SetSize(swatchSize, swatchSize)
        if i == 1 then
            swatch:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            swatch:SetPoint("LEFT", container.swatches[i - 1], "RIGHT", spacing, 0)
        end
        
        swatch:SetBackdrop({ bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = SWATCH_BORDER })
        swatch:SetBackdropBorderColor(0, 0, 0, 1)
        swatch:SetBackdropColor(0, 0, 0, 0)
        swatch:RegisterForDrag("LeftButton")
        
        swatch.Checkerboard = swatch:CreateTexture(nil, "BACKGROUND")
        swatch.Checkerboard:SetPoint("TOPLEFT", SWATCH_BORDER, -SWATCH_BORDER)
        swatch.Checkerboard:SetPoint("BOTTOMRIGHT", -SWATCH_BORDER, SWATCH_BORDER)
        swatch.Checkerboard:SetTexture(CHECKERBOARD_TEXTURE, "REPEAT", "REPEAT")
        swatch.Checkerboard:SetHorizTile(true)
        swatch.Checkerboard:SetVertTile(true)

        swatch.Color = swatch:CreateTexture(nil, "ARTWORK")
        swatch.Color:SetPoint("TOPLEFT", SWATCH_BORDER, -SWATCH_BORDER)
        swatch.Color:SetPoint("BOTTOMRIGHT", -SWATCH_BORDER, SWATCH_BORDER)

        swatch:SetScript("OnEnter", function(self)
            if self.TooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(self.TooltipText)
                GameTooltip:Show()
            end
        end)
        swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

        swatch:SetScript("OnDragStart", function(self)
            if not lib.multiPinMode and #lib.pins > 0 then return end
            if not self.ColorModel then return end
            lib:StartDrag(self.ColorModel.r, self.ColorModel.g, self.ColorModel.b, self.ColorModel.a)
        end)
        swatch:SetScript("OnDragStop", function() lib:EndDrag() end)
        
        container.swatches[i] = swatch
    end
    
    self.ui.recentColorsBar = container
    return container
end


-- [ FRAME CREATION ] -------------------------------------------------------------------------------

function lib:CreatePickerFrame()
    if self.ui.frame then return self.ui.frame end

    local f = CreateFrame("Frame", nil, UIParent)
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
        lib:EndTourCleanup()
        if lib.info.button then lib.info.button:Hide() end
        lib:EndDrag()

        if lib.callback then
            local function BuildResult(pins)
                local result = { curve = lib.colorCurve, pins = SerializePins(pins) }
                if lib.hasDesaturation then result.desaturated = lib.desaturated end
                return result
            end
            if lib.wasCancelled then
                lib.callback(BuildResult(lib.snapshotPins), true)
            elseif lib.pins and #lib.pins > 0 then
                -- In multi-color mode, colors are saved instantly during 'AddPin' (pin drop).
                -- In single-color mode, there are no 'drops', so we save the final picked color upon 'Apply'.
                if not lib.multiPinMode then
                    lib:AddRecentColor(lib.pins[1])
                    lib:UpdateRecentColors()
                end
                
                lib.callback(BuildResult(lib.pins), false)
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

    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)

    self.ui.currentSwatch = frame
    return frame
end

-- [ HEX INPUT ] ------------------------------------------------------------------------------------

function lib:CreateHexInput()
    if self.ui.hexBoxFrame then return self.ui.hexBoxFrame end

    local frame = CreateFrame("Frame", nil, self.ui.frame, "BackdropTemplate")
    frame:SetHeight(HEX_BOX_HEIGHT)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.5)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local box = CreateFrame("EditBox", nil, frame)
    box:SetFontObject(ChatFontNormal)
    box:SetAllPoints(frame)
    box:SetAutoFocus(false)
    box:SetMaxLetters(6)
    box:SetJustifyH("CENTER")
    box:SetTextInsets(5, 5, 5, 5)

    frame:SetScript("OnMouseDown", function() box:SetFocus() end)

    box:SetScript("OnEnterPressed", function(self)
        local r, g, b = HexToColor(self:GetText())
        if r then lib.ui.colorSelect:SetColorRGB(r, g, b) end
        self:ClearFocus()
    end)

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    self.ui.hexBoxFrame = frame
    self.ui.hexBox = box
    return frame
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

    if self.ui.desatCheckbox then
        self.ui.desatCheckbox:SetParent(container)
        self.ui.desatCheckbox:ClearAllPoints()
        self.ui.desatCheckbox:SetPoint("TOP", classSwatch, "BOTTOM", 0, -(CLASS_SWATCH_GAP + 14))
        if self.hasDesaturation then self.ui.desatCheckbox:Show()
        else self.ui.desatCheckbox:Hide() end
    end

    local hexBoxFrame = self.ui.hexBoxFrame or self.ui.hexBox
    if hexBoxFrame then
        hexBoxFrame:ClearAllPoints()
        hexBoxFrame:SetPoint("TOP", cs, "BOTTOM", 0, -SWATCH_GAP)
        hexBoxFrame:SetPoint("LEFT", self.ui.frame, "LEFT", GRADIENT_BAR_PADDING, 0)
        hexBoxFrame:SetPoint("RIGHT", self.ui.frame, "RIGHT", -GRADIENT_BAR_PADDING, 0)
    end
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
    self:CreateTourButton()
    self:CreateDesaturationCheckbox()

    self.ui.initialized = true
end

-- [ TOUR SYSTEM ] ----------------------------------------------------------------------------------

local TOUR_ACCENT = { r = 0.3, g = 0.8, b = 0.3 }
local TOUR_BG = { r = 0.08, g = 0.08, b = 0.08, a = 0.95 }
local TOUR_BORDER_CLR = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 }
local TOUR_TEXT_CLR = { r = 0.85, g = 0.85, b = 0.85 }
local TOUR_TITLE_CLR = { r = TOUR_ACCENT.r, g = TOUR_ACCENT.g, b = TOUR_ACCENT.b }
local TOUR_PAD = 8
local TOUR_MAX_WIDTH = 220
local TOUR_BORDER = 1
local TOUR_BTN_H = 18
local TOUR_BTN_W = 60
local TOUR_BTN_GAP = 6
local TOUR_PULSE_LEVEL = 512

-- [ TOUR LOCALIZATION ]-----------------------------------------------------------------------------
local CP_LOCALE = {
    enUS = {
        TOUR_TIP = "Color Picker Tour",
        NEXT = "Next", DONE = "Done",
        WHEEL_TITLE = "Color Wheel",
        WHEEL_TEXT = "Select a hue and saturation on the wheel.\nThe vertical slider adjusts brightness.",
        SWATCH_TITLE = "Current Color",
        SWATCH_TEXT = "Your selected color preview.\nDrag it onto the gradient bar to add\na color stop.",
        CLASS_TITLE = "Class Color",
        CLASS_TEXT = "Your class color swatch.\nDrag onto the gradient bar to add a\nclass-colored stop that follows your spec.",
        GRADIENT_TITLE = "Gradient Bar",
        GRADIENT_TEXT = "Visualizes your color curve.\nDrag colors here to add stops.\nRight-click a pin to remove it.",
        PIN_TITLE = "Pin Controls",
        PIN_TEXT = "Use arrow keys to nudge a pin position.\nHold Shift for fine-grained precision.",
        APPLY_TITLE = "Apply / Clear",
        APPLY_TEXT = "Apply Color saves your gradient.\nClearing all pins resets the component\nto its default color.",
    },
    deDE = {
        TOUR_TIP = "Farbwähler-Tour",
        NEXT = "Weiter", DONE = "Fertig",
        WHEEL_TITLE = "Farbrad",
        WHEEL_TEXT = "Farbton und Sättigung auf dem Rad wählen.\nDer vertikale Regler passt die Helligkeit an.",
        SWATCH_TITLE = "Aktuelle Farbe",
        SWATCH_TEXT = "Vorschau der gewählten Farbe.\nAuf den Verlaufsbalken ziehen, um\neinen Farbstopp hinzuzufügen.",
        CLASS_TITLE = "Klassenfarbe",
        CLASS_TEXT = "Klassenfarbmuster.\nAuf den Verlaufsbalken ziehen für einen\nklassengebundenen Farbstopp.",
        GRADIENT_TITLE = "Verlaufsbalken",
        GRADIENT_TEXT = "Zeigt Ihre Farbkurve an.\nFarben hierher ziehen zum Hinzufügen.\nRechtsklick auf einen Pin zum Entfernen.",
        PIN_TITLE = "Pin-Steuerung",
        PIN_TEXT = "Pfeiltasten verschieben einen Pin.\nUmschalttaste für feine Schritte.",
        APPLY_TITLE = "Anwenden / Löschen",
        APPLY_TEXT = "Farbe anwenden speichert den Verlauf.\nAlle Pins entfernen setzt die Komponente\nauf die Standardfarbe zurück.",
    },
    frFR = {
        TOUR_TIP = "Visite du sélecteur",
        NEXT = "Suivant", DONE = "Terminé",
        WHEEL_TITLE = "Roue chromatique",
        WHEEL_TEXT = "Sélectionnez une teinte et saturation.\nLe curseur vertical ajuste la luminosité.",
        SWATCH_TITLE = "Couleur actuelle",
        SWATCH_TEXT = "Aperçu de la couleur sélectionnée.\nFaites glisser sur la barre de dégradé\npour ajouter un arrêt.",
        CLASS_TITLE = "Couleur de classe",
        CLASS_TEXT = "Échantillon de classe.\nFaites glisser sur la barre de dégradé\npour un arrêt lié à votre spé.",
        GRADIENT_TITLE = "Barre de dégradé",
        GRADIENT_TEXT = "Visualise votre courbe de couleur.\nFaites glisser des couleurs ici.\nClic droit sur un point pour le supprimer.",
        PIN_TITLE = "Contrôles des points",
        PIN_TEXT = "Utilisez les flèches pour ajuster un point.\nMaintenez Maj pour un réglage fin.",
        APPLY_TITLE = "Appliquer / Effacer",
        APPLY_TEXT = "Appliquer sauvegarde le dégradé.\nSupprimer tous les points réinitialise\nla couleur par défaut.",
    },
    esES = {
        TOUR_TIP = "Tour del selector",
        NEXT = "Siguiente", DONE = "Hecho",
        WHEEL_TITLE = "Rueda de color",
        WHEEL_TEXT = "Selecciona tono y saturación en la rueda.\nEl control vertical ajusta el brillo.",
        SWATCH_TITLE = "Color actual",
        SWATCH_TEXT = "Vista previa del color seleccionado.\nArrástralo a la barra de gradiente\npara añadir una parada.",
        CLASS_TITLE = "Color de clase",
        CLASS_TEXT = "Muestra de color de clase.\nArrástralo a la barra de gradiente para\nuna parada vinculada a tu especialización.",
        GRADIENT_TITLE = "Barra de gradiente",
        GRADIENT_TEXT = "Visualiza tu curva de color.\nArrastra colores aquí para añadir paradas.\nClic derecho en un pin para eliminarlo.",
        PIN_TITLE = "Controles de pines",
        PIN_TEXT = "Usa las flechas para ajustar un pin.\nMantén Mayús para precisión fina.",
        APPLY_TITLE = "Aplicar / Borrar",
        APPLY_TEXT = "Aplicar guarda el gradiente.\nEliminar todos los pines restablece\nel color predeterminado.",
    },
    ptBR = {
        TOUR_TIP = "Tour do seletor",
        NEXT = "Próximo", DONE = "Concluído",
        WHEEL_TITLE = "Roda de cores",
        WHEEL_TEXT = "Selecione matiz e saturação na roda.\nO controle vertical ajusta o brilho.",
        SWATCH_TITLE = "Cor atual",
        SWATCH_TEXT = "Prévia da cor selecionada.\nArraste para a barra de gradiente\npara adicionar uma parada.",
        CLASS_TITLE = "Cor de classe",
        CLASS_TEXT = "Amostra de cor da classe.\nArraste para a barra de gradiente para\numa parada vinculada à sua spec.",
        GRADIENT_TITLE = "Barra de gradiente",
        GRADIENT_TEXT = "Visualiza sua curva de cor.\nArraste cores aqui para adicionar paradas.\nClique direito em um pin para remover.",
        PIN_TITLE = "Controles de pinos",
        PIN_TEXT = "Use as setas para ajustar um pino.\nSegure Shift para precisão fina.",
        APPLY_TITLE = "Aplicar / Limpar",
        APPLY_TEXT = "Aplicar salva o gradiente.\nRemover todos os pins redefine\na cor padrão.",
    },
    ruRU = {
        TOUR_TIP = "Обзор палитры",
        NEXT = "Далее", DONE = "Готово",
        WHEEL_TITLE = "Цветовой круг",
        WHEEL_TEXT = "Выберите оттенок и насыщенность.\nВертикальный ползунок регулирует яркость.",
        SWATCH_TITLE = "Текущий цвет",
        SWATCH_TEXT = "Предпросмотр выбранного цвета.\nПеретащите на полосу градиента,\nчтобы добавить точку.",
        CLASS_TITLE = "Цвет класса",
        CLASS_TEXT = "Образец цвета класса.\nПеретащите на полосу градиента для\nточки, связанной с вашей специализацией.",
        GRADIENT_TITLE = "Полоса градиента",
        GRADIENT_TEXT = "Показывает вашу кривую цвета.\nПеретащите цвета сюда.\nПКМ по точке для удаления.",
        PIN_TITLE = "Управление точками",
        PIN_TEXT = "Стрелки для сдвига точки.\nShift для мелких шагов.",
        APPLY_TITLE = "Применить / Очистить",
        APPLY_TEXT = "Применить сохраняет градиент.\nУдаление всех точек сбрасывает\nцвет по умолчанию.",
    },
    koKR = {
        TOUR_TIP = "색상 선택기 안내",
        NEXT = "다음", DONE = "완료",
        WHEEL_TITLE = "색상 휠",
        WHEEL_TEXT = "휠에서 색조와 채도를 선택합니다.\n세로 슬라이더로 밝기를 조절합니다.",
        SWATCH_TITLE = "현재 색상",
        SWATCH_TEXT = "선택한 색상 미리보기입니다.\n그라데이션 바로 드래그하여\n색상 정지점을 추가합니다.",
        CLASS_TITLE = "직업 색상",
        CLASS_TEXT = "직업 색상 견본입니다.\n그라데이션 바로 드래그하여\n전문화에 연동되는 정지점을 추가합니다.",
        GRADIENT_TITLE = "그라데이션 바",
        GRADIENT_TEXT = "색상 곡선을 시각화합니다.\n색상을 여기로 드래그하여 추가합니다.\n핀을 우클릭하여 제거합니다.",
        PIN_TITLE = "핀 조작",
        PIN_TEXT = "화살표 키로 핀 위치를 조정합니다.\nShift를 누르면 미세 조정됩니다.",
        APPLY_TITLE = "적용 / 초기화",
        APPLY_TEXT = "색상 적용은 그라데이션을 저장합니다.\n모든 핀을 제거하면 기본 색상으로\n초기화됩니다.",
    },
    zhCN = {
        TOUR_TIP = "取色器导览",
        NEXT = "下一步", DONE = "完成",
        WHEEL_TITLE = "色轮",
        WHEEL_TEXT = "在色轮上选择色调和饱和度。\n垂直滑块调整亮度。",
        SWATCH_TITLE = "当前颜色",
        SWATCH_TEXT = "所选颜色预览。\n拖动到渐变条上\n添加颜色停靠点。",
        CLASS_TITLE = "职业颜色",
        CLASS_TEXT = "职业颜色样本。\n拖动到渐变条上添加\n跟随专精变化的停靠点。",
        GRADIENT_TITLE = "渐变条",
        GRADIENT_TEXT = "显示您的颜色曲线。\n将颜色拖到这里添加停靠点。\n右键点击图钉以移除。",
        PIN_TITLE = "图钉控制",
        PIN_TEXT = "方向键微调图钉位置。\n按住Shift进行精细调整。",
        APPLY_TITLE = "应用 / 清除",
        APPLY_TEXT = "应用颜色保存渐变。\n清除所有图钉将重置为\n默认颜色。",
    },
    zhTW = {
        TOUR_TIP = "取色器導覽",
        NEXT = "下一步", DONE = "完成",
        WHEEL_TITLE = "色輪",
        WHEEL_TEXT = "在色輪上選擇色調和飽和度。\n垂直滑桿調整亮度。",
        SWATCH_TITLE = "目前顏色",
        SWATCH_TEXT = "所選顏色預覽。\n拖動到漸層條上\n新增顏色停靠點。",
        CLASS_TITLE = "職業顏色",
        CLASS_TEXT = "職業顏色樣本。\n拖動到漸層條上新增\n跟隨專精變化的停靠點。",
        GRADIENT_TITLE = "漸層條",
        GRADIENT_TEXT = "顯示您的顏色曲線。\n將顏色拖到這裡新增停靠點。\n右鍵點擊圖釘以移除。",
        PIN_TITLE = "圖釘控制",
        PIN_TEXT = "方向鍵微調圖釘位置。\n按住Shift進行精細調整。",
        APPLY_TITLE = "套用 / 清除",
        APPLY_TEXT = "套用顏色儲存漸層。\n清除所有圖釘將重設為\n預設顏色。",
    },
}
CP_LOCALE.enGB = CP_LOCALE.enUS
CP_LOCALE.esMX = CP_LOCALE.esES
local CL = CP_LOCALE[GetLocale()] or CP_LOCALE.enUS

local isCJK_CP = ({ koKR = true, zhCN = true, zhTW = true })[GetLocale()]
if isCJK_CP then TOUR_MAX_WIDTH = 240 end

-- [ TOUR STOPS ]------------------------------------------------------------------------------------
local TOUR_STOPS_CP = {
    { anchor = function() return lib.ui.colorSelect end,
      tooltipPoint = "TOPLEFT", tooltipRel = "TOPRIGHT", tpX = 8, tpY = 0,
      title = CL.WHEEL_TITLE, text = CL.WHEEL_TEXT },
    { anchor = function() return lib.ui.currentSwatch end,
      tooltipPoint = "RIGHT", tooltipRel = "LEFT", tpX = -8, tpY = 0,
      title = CL.SWATCH_TITLE, text = CL.SWATCH_TEXT },
    { anchor = function() return lib.ui.classSwatch end,
      tooltipPoint = "RIGHT", tooltipRel = "LEFT", tpX = -8, tpY = 0,
      title = CL.CLASS_TITLE, text = CL.CLASS_TEXT },
    { anchor = function() return lib.ui.gradientBar end,
      tooltipPoint = "BOTTOM", tooltipRel = "TOP", tpX = 0, tpY = 8,
      title = CL.GRADIENT_TITLE, text = CL.GRADIENT_TEXT },
    { anchor = function() return lib.ui.gradientBar and lib.ui.gradientBar.PinsContainer end,
      tooltipPoint = "BOTTOM", tooltipRel = "TOP", tpX = 0, tpY = 8,
      title = CL.PIN_TITLE, text = CL.PIN_TEXT },
    { anchor = function() return lib.ui.applyButton end,
      tooltipPoint = "TOP", tooltipRel = "BOTTOM", tpX = 0, tpY = -8,
      title = CL.APPLY_TITLE, text = CL.APPLY_TEXT },
}

-- [ TOUR TOOLTIP ]---------------------------------------------------------------------------------
local cpTip = CreateFrame("Frame", nil, UIParent)
cpTip:SetFrameStrata("TOOLTIP")
cpTip:SetFrameLevel(999)
cpTip:Hide()

cpTip.bg = cpTip:CreateTexture(nil, "BACKGROUND")
cpTip.bg:SetAllPoints()
cpTip.bg:SetColorTexture(TOUR_BG.r, TOUR_BG.g, TOUR_BG.b, TOUR_BG.a)

local function MakeCPBorder(parent, horiz, p1, r1, p2, r2)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(TOUR_BORDER_CLR.r, TOUR_BORDER_CLR.g, TOUR_BORDER_CLR.b, TOUR_BORDER_CLR.a)
    t:SetPoint(p1, parent, r1)
    t:SetPoint(p2, parent, r2)
    if horiz then t:SetHeight(TOUR_BORDER) else t:SetWidth(TOUR_BORDER) end
end
MakeCPBorder(cpTip, true, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT")
MakeCPBorder(cpTip, true, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
MakeCPBorder(cpTip, false, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT")
MakeCPBorder(cpTip, false, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT")

-- Directional accent bars
local AW = 2
local B = TOUR_BORDER
cpTip.accents = {}
cpTip.accents.top = cpTip:CreateTexture(nil, "ARTWORK")
cpTip.accents.top:SetColorTexture(TOUR_ACCENT.r, TOUR_ACCENT.g, TOUR_ACCENT.b, 0.8)
cpTip.accents.top:SetHeight(AW)
cpTip.accents.top:SetPoint("TOPLEFT", B, -B); cpTip.accents.top:SetPoint("TOPRIGHT", -B, -B)
cpTip.accents.bottom = cpTip:CreateTexture(nil, "ARTWORK")
cpTip.accents.bottom:SetColorTexture(TOUR_ACCENT.r, TOUR_ACCENT.g, TOUR_ACCENT.b, 0.8)
cpTip.accents.bottom:SetHeight(AW)
cpTip.accents.bottom:SetPoint("BOTTOMLEFT", B, B); cpTip.accents.bottom:SetPoint("BOTTOMRIGHT", -B, B)
cpTip.accents.left = cpTip:CreateTexture(nil, "ARTWORK")
cpTip.accents.left:SetColorTexture(TOUR_ACCENT.r, TOUR_ACCENT.g, TOUR_ACCENT.b, 0.8)
cpTip.accents.left:SetWidth(AW)
cpTip.accents.left:SetPoint("TOPLEFT", B, -B); cpTip.accents.left:SetPoint("BOTTOMLEFT", B, B)
cpTip.accents.right = cpTip:CreateTexture(nil, "ARTWORK")
cpTip.accents.right:SetColorTexture(TOUR_ACCENT.r, TOUR_ACCENT.g, TOUR_ACCENT.b, 0.8)
cpTip.accents.right:SetWidth(AW)
cpTip.accents.right:SetPoint("TOPRIGHT", -B, -B); cpTip.accents.right:SetPoint("BOTTOMRIGHT", -B, B)

local function ApplyCPAccent(tooltipPoint)
    for _, bar in pairs(cpTip.accents) do bar:Hide() end
    local pt = tooltipPoint:upper()
    if pt == "CENTER" then for _, bar in pairs(cpTip.accents) do bar:Show() end; return end
    if pt:find("TOP") then cpTip.accents.top:Show() end
    if pt:find("BOTTOM") then cpTip.accents.bottom:Show() end
    if pt:find("LEFT") then cpTip.accents.left:Show() end
    if pt:find("RIGHT") then cpTip.accents.right:Show() end
end

cpTip.counter = cpTip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cpTip.counter:SetPoint("TOPLEFT", TOUR_PAD + 4, -TOUR_PAD)
cpTip.counter:SetTextColor(0.5, 0.5, 0.5)
cpTip.counter:SetJustifyH("LEFT")

cpTip.title = cpTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cpTip.title:SetPoint("TOPLEFT", cpTip.counter, "BOTTOMLEFT", 0, -2)
cpTip.title:SetTextColor(TOUR_TITLE_CLR.r, TOUR_TITLE_CLR.g, TOUR_TITLE_CLR.b)
cpTip.title:SetJustifyH("LEFT")
cpTip.title:SetWidth(TOUR_MAX_WIDTH - TOUR_PAD * 2 - 4)

cpTip.text = cpTip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cpTip.text:SetPoint("TOPLEFT", cpTip.title, "BOTTOMLEFT", 0, -3)
cpTip.text:SetTextColor(TOUR_TEXT_CLR.r, TOUR_TEXT_CLR.g, TOUR_TEXT_CLR.b)
cpTip.text:SetJustifyH("LEFT")
cpTip.text:SetWidth(TOUR_MAX_WIDTH - TOUR_PAD * 2 - 4)
cpTip.text:SetSpacing(2)

cpTip.nextBtn = CreateFrame("Button", nil, cpTip, "UIPanelButtonTemplate")
cpTip.nextBtn:SetSize(TOUR_BTN_W, TOUR_BTN_H)
cpTip.nextBtn:SetPoint("BOTTOMRIGHT", cpTip, "BOTTOMRIGHT", -TOUR_PAD, TOUR_PAD)
cpTip.nextBtn:SetScript("OnClick", function()
    if lib.info.tourIndex < #TOUR_STOPS_CP then
        lib:ShowTourStop(lib.info.tourIndex + 1)
    else
        lib:EndTour()
    end
end)

-- [ PULSE POOL ]-----------------------------------------------------------------------------------
local cpPulsePool = {}
local cpActivePulses = {}

local function CreateCPPulse()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(TOUR_PULSE_LEVEL)
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetColorTexture(TOUR_ACCENT.r, TOUR_ACCENT.g, TOUR_ACCENT.b, 0.3)
    f.ag = f:CreateAnimationGroup()
    f.ag:SetLooping("BOUNCE")
    local a = f.ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1); a:SetToAlpha(0.2); a:SetDuration(0.6); a:SetSmoothing("IN_OUT")
    f:Hide()
    return f
end

local function AcquireCPPulse()
    local p = table.remove(cpPulsePool) or CreateCPPulse()
    cpActivePulses[#cpActivePulses + 1] = p
    return p
end

local function ReleaseCPPulses()
    for i = #cpActivePulses, 1, -1 do
        local p = cpActivePulses[i]
        p.ag:Stop(); p:Hide()
        cpPulsePool[#cpPulsePool + 1] = p
        cpActivePulses[i] = nil
    end
end

local function ShowCPPulseOn(anchor)
    local p = AcquireCPPulse()
    p:ClearAllPoints(); p:SetAllPoints(anchor)
    p:SetParent(anchor:GetParent() or UIParent)
    p:SetFrameStrata("TOOLTIP")
    p:SetFrameLevel(TOUR_PULSE_LEVEL)
    p:Show(); p.ag:Play()
end

local function LayoutCPTooltip(anchor, stop, idx, total)
    cpTip.counter:SetText(idx .. " / " .. total)
    cpTip.title:SetText(stop.title)
    cpTip.text:SetText(stop.text)
    cpTip.nextBtn:SetText(idx == total and CL.DONE or CL.NEXT)
    local textH = cpTip.counter:GetStringHeight() + 2 + cpTip.title:GetStringHeight() + 3 + cpTip.text:GetStringHeight()
    cpTip:SetSize(TOUR_MAX_WIDTH, textH + TOUR_PAD * 2 + TOUR_BTN_GAP + TOUR_BTN_H + TOUR_PAD)
    cpTip:ClearAllPoints()
    cpTip:SetPoint(stop.tooltipPoint, anchor, stop.tooltipRel, stop.tpX, stop.tpY)
    ApplyCPAccent(stop.tooltipPoint)
    cpTip:Show()
    ReleaseCPPulses()
    ShowCPPulseOn(anchor)
end

-- [ TOUR CONTROL ]----------------------------------------------------------------------------------
function lib:ShowTourStop(idx)
    local stop = TOUR_STOPS_CP[idx]
    if not stop then self:EndTour(); return end
    local anchor = stop.anchor()
    if not anchor or not anchor:IsShown() then
        if idx < #TOUR_STOPS_CP then self:ShowTourStop(idx + 1) else self:EndTour() end
        return
    end
    self.info.tourIndex = idx
    LayoutCPTooltip(anchor, stop, idx, #TOUR_STOPS_CP)
end

function lib:StartTour()
    self.info.tourActive = true
    self.info.tourIndex = 0
    self:ShowTourStop(1)
end

function lib:EndTour()
    self.info.tourActive = false
    self.info.tourIndex = 0
    cpTip:Hide()
    ReleaseCPPulses()
end

function lib:EndTourCleanup()
    self:EndTour()
end

function lib:ToggleTour()
    if not self.info.tourActive then
        self:StartTour()
    elseif self.info.tourIndex < #TOUR_STOPS_CP then
        self:ShowTourStop(self.info.tourIndex + 1)
    else
        self:EndTour()
    end
end

function lib:CreateTourButton()
    if self.info.button then return self.info.button end
    local btn = CreateFrame("Button", nil, self.ui.frame)
    btn:SetSize(INFO_BUTTON_SIZE, INFO_BUTTON_SIZE)
    btn:SetPoint("TOPLEFT", self.ui.frame, "TOPLEFT", 6, -6)
    btn:SetFrameLevel(self.ui.frame:GetFrameLevel() + 10)
    btn.Icon = btn:CreateTexture(nil, "ARTWORK")
    btn.Icon:SetTexture("Interface\\common\\help-i")
    btn.Icon:SetSize(INFO_BUTTON_SIZE, INFO_BUTTON_SIZE)
    btn.Icon:SetPoint("CENTER")
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(CL.TOUR_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        lib:ToggleTour()
    end)
    self.info.button = btn
    return btn
end

-- [ PUBLIC API ] -----------------------------------------------------------------------------------

function lib:Open(options)
    options = options or {}
    self.wasCancelled = false
    self.callback = options.callback

    local data = options.initialData or options.initialCurve or options.initialColor
    self.multiPinMode = not options.forceSingleColor

    self.recentColors = options.recentColorsDb or self.recentColors or {}
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

    self.hasDesaturation = options.hasDesaturation or false
    self.desaturated = (data and data.desaturated) or false
    if self.ui.desatCheckbox then self.ui.desatCheckbox:SetChecked(self.desaturated) end

    self.snapshotPins = DeepCopyPins(self.pins)

    if self.ui.gradientBar then
        for _, handle in ipairs(self.ui.gradientBar.pinHandles) do handle:Hide() end
    end
    self:CreateRecentColorsBar()
    self:UpdateRecentColors()

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
        if options.onOpen then options.onOpen(lib) end
    end)
end

function lib:IsOpen() return self.ui.frame and self.ui.frame:IsShown() end
