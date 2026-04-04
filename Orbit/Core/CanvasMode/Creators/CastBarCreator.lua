-- [ CANVAS MODE - CAST BAR CREATOR ]----------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local CC = CanvasMode.CreatorConstants
local LSM = LibStub("LibSharedMedia-3.0")

local CalculateAnchorWithWidthCompensation = OrbitEngine.PositionUtils.CalculateAnchorWithWidthCompensation
local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint
local BuildComponentSelfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor
local SmartGuides = OrbitEngine.SmartGuides
local ApplyTextAlignment = CanvasMode.ApplyTextAlignment

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local DEFAULT_CB_WIDTH = 120
local DEFAULT_CB_HEIGHT = 18
local DEFAULT_CB_COLOR = { r = 1, g = 0.7, b = 0 }
local CB_CAST_VALUE = 1.2
local CB_MAX_VALUE = 2.0
local CB_ICON_TEXTURE = 136116
local CB_ICON_TEXCOORD = 0.1
local CB_ICON_TEXCOORD_MAX = 0.9
local CB_TEXT_SIZE_MIN = 10

local SUB_LEVEL_BOOST = 5
local SUB_TEXT_MIN_WIDTH = 20
local SUB_TEXT_PADDING = 4
local SUB_TEXT_HEIGHT_PADDING = 2
local SUB_PAD_X = 20
local SUB_PAD_Y = 10
local SnapEngine = OrbitEngine.CanvasMode.SnapEngine
local SUB_SNAP_OPTIONS = { edgeThreshold = SnapEngine.EDGE_THRESHOLD }
local CLICK_THRESHOLD = 0.3
local DEFAULT_TEXT_OFFSET_X = 4

-- [ SUB-COMPONENT DRAG ]----------------------------------------------------------------------------

local function CreateSubText(parent, parentContainer, subKey, subPos, text, justify, fontPath, cbTextSize, fontFlags)
    local subFrame = CreateFrame("Frame", nil, parent)
    subFrame:SetFrameLevel(parent:GetFrameLevel() + SUB_LEVEL_BOOST)
    subFrame:EnableMouse(true)
    subFrame:SetMovable(true)
    subFrame:RegisterForDrag("LeftButton")

    local fs = subFrame:CreateFontString(nil, "OVERLAY")
    fs:SetFont(fontPath, cbTextSize, fontFlags)
    Orbit.Skin:ApplyFontShadow(fs)
    fs:SetText(text)
    fs:SetJustifyH(justify)
    fs:SetPoint(justify, subFrame, justify, 0, 0)

    local textWidth = math.max(SUB_TEXT_MIN_WIDTH, (fs:GetStringWidth() or SUB_TEXT_MIN_WIDTH) + SUB_TEXT_PADDING)
    subFrame:SetSize(textWidth, cbTextSize + SUB_TEXT_HEIGHT_PADDING)

    subFrame.visual = fs
    subFrame.key = subKey
    subFrame.isFontString = true
    subFrame.isSubComponent = true
    subFrame.subComponentParent = parent
    subFrame.parentKey = "CastBar"

    subFrame.border = subFrame:CreateTexture(nil, "BACKGROUND")
    subFrame.border:SetAllPoints()
    CanvasMode.SetBorderColor(subFrame.border, CC.BORDER_COLOR_IDLE)

    local anchorX = subPos.anchorX or justify
    local anchorY = subPos.anchorY or "CENTER"
    local offX = subPos.offsetX or DEFAULT_TEXT_OFFSET_X
    local offY = subPos.offsetY or 0
    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
    local selfAnchor = BuildComponentSelfAnchor(true, false, anchorY, justify)
    local finalX = anchorX == "RIGHT" and -offX or offX
    local finalY = anchorY == "TOP" and -offY or offY

    subFrame:ClearAllPoints()
    subFrame:SetPoint(selfAnchor, parent, anchorPoint, finalX, finalY)

    subFrame.anchorX = anchorX
    subFrame.anchorY = anchorY
    subFrame.offsetX = offX
    subFrame.offsetY = offY
    subFrame.justifyH = justify

    if SmartGuides then subFrame.guides = SmartGuides:Create(parent) end

    subFrame:SetScript("OnEnter", function(s)
        CanvasMode.SetBorderColor(s.border, CC.BORDER_COLOR_HOVER)
        Dialog.hoveredComponent = s
    end)
    subFrame:SetScript("OnLeave", function(s)
        CanvasMode.SetBorderColor(s.border, CC.BORDER_COLOR_IDLE)
        if Dialog.hoveredComponent == s then Dialog.hoveredComponent = nil end
    end)

    subFrame:SetScript("OnMouseDown", function(s, button)
        if button ~= "LeftButton" then return end
        s.mouseDownTime = GetTime()
        s.wasDragged = false
    end)

    subFrame:SetScript("OnMouseUp", function(s, button)
        if button ~= "LeftButton" then return end
        if not s.wasDragged and s.mouseDownTime and (GetTime() - s.mouseDownTime) < CLICK_THRESHOLD then
            OrbitEngine.CanvasComponentSettings:Open("CastBar", parentContainer, Dialog.targetPlugin, Dialog.targetSystemIndex)
        end
        s.mouseDownTime = nil
    end)

    subFrame:SetScript("OnDragStart", function(s)
        s.isDragging = true
        s.wasDragged = true
        CanvasMode.SetBorderColor(s.border, CC.BORDER_COLOR_DRAG)
        local mx, my = GetCursorPosition()
        local sc = s:GetEffectiveScale()
        local cx, cy = s:GetCenter()
        s.dragOffX = cx - mx / sc
        s.dragOffY = cy - my / sc
    end)

    subFrame:SetScript("OnDragStop", function(s)
        s.isDragging = false
        CanvasMode.SetBorderColor(s.border, CC.BORDER_COLOR_IDLE)
        if SmartGuides and s.guides then SmartGuides:Hide(s.guides) end

        if Dialog.DisabledDock and Dialog.DisabledDock:IsMouseOver() then
            Dialog.DisabledDock.DropHighlight:Hide()
            s:Hide()
            local dockKey = "CastBar." .. subKey
            Dialog:AddToDock(dockKey, s.visual)
            Dialog.dockComponents[dockKey].storedSubFrame = s
            Dialog.dockComponents[dockKey].parentContainer = parentContainer
            return
        end

        local parentW, parentH = parent:GetWidth(), parent:GetHeight()
        local halfW, halfH = parentW / 2, parentH / 2
        local cx, cy = s:GetCenter()
        local px, py = parent:GetCenter()
        local aX, aY, oX, oY, jH = CalculateAnchorWithWidthCompensation(cx - px, cy - py, halfW, halfH, true, s:GetWidth())
        s.anchorX = aX
        s.anchorY = aY
        s.offsetX = oX
        s.offsetY = oY
        s.justifyH = jH
        ApplyTextAlignment(s, s.visual, jH)
    end)

    subFrame:SetScript("OnUpdate", function(s)
        if not s.isDragging then return end
        local mx, my = GetCursorPosition()
        local sc = s:GetEffectiveScale()
        local targetX = mx / sc + s.dragOffX
        local targetY = my / sc + s.dragOffY
        local px, py = parent:GetCenter()
        local relX, relY = targetX - px, targetY - py
        local halfW, halfH = parent:GetWidth() / 2, parent:GetHeight() / 2
        relX = math.max(-halfW - SUB_PAD_X, math.min(halfW + SUB_PAD_X, relX))
        relY = math.max(-halfH - SUB_PAD_Y, math.min(halfH + SUB_PAD_Y, relY))

        local snapX, snapY
        local compHalfW = (s:GetWidth() or 40) / 2
        local compHalfH = (s:GetHeight() or 12) / 2
        if not IsShiftKeyDown() then
            relX, relY, snapX, snapY = SnapEngine:Calculate(relX, relY, halfW, halfH, compHalfW, compHalfH, SUB_SNAP_OPTIONS)
        end

        if SmartGuides and s.guides then SmartGuides:Update(s.guides, snapX, snapY, parent:GetWidth(), parent:GetHeight()) end
        if Dialog.DisabledDock then Dialog.DisabledDock.DropHighlight:SetShown(Dialog.DisabledDock:IsMouseOver()) end

        local aX, aY, oX, oY, jH = CalculateAnchorWithWidthCompensation(relX, relY, halfW, halfH, true, s:GetWidth())
        OrbitEngine.SelectionTooltip:ShowComponentPosition(s, subKey, aX, aY, relX, relY, oX, oY, jH)

        s:ClearAllPoints()
        s:SetPoint("CENTER", parent, "CENTER", relX, relY)
    end)

    return subFrame
end

-- [ CREATOR ]---------------------------------------------------------------------------------------

local function Create(container, preview, key, source, data)
    local plugin = Dialog.targetPlugin
    local sysIdx = Dialog.targetSystemIndex or 1
    local cbWidth = (plugin and plugin:GetSetting(sysIdx, "CastBarWidth")) or DEFAULT_CB_WIDTH
    local cbHeight = (plugin and plugin:GetSetting(sysIdx, "CastBarHeight")) or DEFAULT_CB_HEIGHT

    container:SetSize(cbWidth + cbHeight, cbHeight)

    local borderSize = plugin and (plugin:GetSetting(sysIdx, "BorderSize") or plugin:GetPlayerSetting("BorderSize"))
        or Orbit.Engine.Pixel:DefaultBorderSize(UIParent:GetEffectiveScale() or 1)
    local Pixel = Orbit.Engine.Pixel

    -- Icon: texture on container (positioned by UpdateBarInsets)
    container.Icon = container:CreateTexture(nil, "ARTWORK")
    container.Icon:SetSize(cbHeight, cbHeight)
    container.Icon:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    container.Icon:SetTexture(CB_ICON_TEXTURE)
    container.Icon:SetTexCoord(CB_ICON_TEXCOORD, CB_ICON_TEXCOORD_MAX, CB_ICON_TEXCOORD, CB_ICON_TEXCOORD_MAX)
    container.Icon:Show()

    -- StatusBar: fills the space to the right of the icon
    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", cbHeight, 0)
    bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    bar:SetMinMaxValues(0, CB_MAX_VALUE)
    bar:SetValue(CB_CAST_VALUE)

    local textureName = plugin and (plugin:GetSetting(sysIdx, "Texture") or plugin:GetPlayerSetting("Texture"))
    local texturePath = textureName and LSM:Fetch("statusbar", textureName)
    if texturePath then bar:SetStatusBarTexture(texturePath) end

    local cbColorCurve = plugin and plugin:GetSetting(sysIdx, "CastBarColorCurve")
    local cbColor = plugin and plugin:GetSetting(sysIdx, "CastBarColor") or DEFAULT_CB_COLOR
    if cbColorCurve then
        local c = OrbitEngine.ColorCurve:GetFirstColorFromCurve(cbColorCurve)
        if c then bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1) end
    else
        bar:SetStatusBarColor(cbColor.r, cbColor.g, cbColor.b, 1)
    end

    -- Background on container (fills behind both icon and bar uniformly)
    container.bg = container:CreateTexture(nil, "BACKGROUND")
    container.bg:SetAllPoints()
    local gs = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(container, gs.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)

    -- Single unified border on container (wraps icon + bar together)
    if Orbit.Skin and Orbit.Skin.SkinBorder then
        Orbit.Skin:SkinBorder(container, container, borderSize)
        if container._borderFrame then container._borderFrame:SetBackdropColor(0, 0, 0, 0) end
        if container._edgeBorderOverlay then container._edgeBorderOverlay:SetBackdropColor(0, 0, 0, 0) end
    end

    -- UpdateBarInsets: keeps icon + bar layout in sync with container size
    local function UpdateBarInsets()
        local height = container:GetHeight()
        local scale = container:GetEffectiveScale()
        local iconSize = container.Icon and container.Icon:IsShown() and Pixel:Snap(height, scale) or 0
        if container.Icon then
            container.Icon:ClearAllPoints()
            container.Icon:SetSize(iconSize, iconSize)
            container.Icon:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        end
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", iconSize, 0)
        bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    end
    UpdateBarInsets()

    local fontName = plugin and (plugin:GetSetting(sysIdx, "Font") or plugin:GetPlayerSetting("Font"))
    local fontPath = fontName and LSM:Fetch("font", fontName)
        or LSM:Fetch("font", Orbit.db.GlobalSettings.Font)
        or Orbit.Constants.Settings.Font.FallbackPath
    local cbTextSize = CB_TEXT_SIZE_MIN
    local fontFlags = Orbit.Skin:GetFontOutline()

    local subData = data and data.subComponents or {}
    local textData = subData.Text or { anchorX = "LEFT", anchorY = "CENTER", offsetX = DEFAULT_TEXT_OFFSET_X, offsetY = 0 }
    local timerData = subData.Timer or { anchorX = "RIGHT", anchorY = "CENTER", offsetX = DEFAULT_TEXT_OFFSET_X, offsetY = 0 }
    container.TextSub = CreateSubText(bar, container, "Text",
        { anchorX = textData.anchorX, anchorY = textData.anchorY, offsetX = textData.offsetX or DEFAULT_TEXT_OFFSET_X, offsetY = textData.offsetY },
        "Boss Ability", "LEFT", fontPath, cbTextSize, fontFlags)
    container.TimerSub = CreateSubText(bar, container, "Timer", timerData, "1.5", "RIGHT", fontPath, cbTextSize, fontFlags)

    return bar
end

CanvasMode:RegisterCreator("CastBar", Create)
