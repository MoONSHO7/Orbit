-- [ ORBIT SELECTION - POSITION TOOLTIP ]-----------------------------------------------------------
-- Handles the position tooltip shown during keyboard nudging and component editing

local _, Orbit = ...
local Engine = Orbit.Engine
local C = Orbit.Constants

local Tooltip = {}
Engine.SelectionTooltip = Tooltip

Tooltip.positionTooltip = nil
Tooltip.positionFadeTimer = nil

-------------------------------------------------
-- HELPERS
-------------------------------------------------

-- Ensure tooltip frame exists (lazy initialization)
local function EnsureTooltip(self)
    if self.positionTooltip then
        return self.positionTooltip
    end

    local tooltip = CreateFrame("Frame", "OrbitPositionTooltip", UIParent, "BackdropTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetSize(C.Selection.PositionTooltip.Width, C.Selection.PositionTooltip.Height)
    tooltip:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    tooltip:SetBackdropColor(0, 0, 0, 0.9)
    tooltip:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    tooltip.text = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tooltip.text:SetPoint("CENTER")
    tooltip.text:SetTextColor(1, 1, 1, 1)

    tooltip:Hide()
    self.positionTooltip = tooltip
    return tooltip
end

-- Position tooltip at cursor with screen edge awareness
-- @param anchor: "BOTTOMRIGHT" (default), "LEFT", or "RIGHT"
local function PositionAtCursor(tooltip, anchor)
    local cursorX, cursorY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    cursorX = cursorX / uiScale
    cursorY = cursorY / uiScale

    local tooltipWidth = tooltip:GetWidth()
    local tooltipHeight = tooltip:GetHeight()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()

    tooltip:ClearAllPoints()

    if anchor == "LEFT" then
        tooltip:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", cursorX - 20, cursorY)
    elseif anchor == "RIGHT" then
        tooltip:SetPoint("LEFT", UIParent, "BOTTOMLEFT", cursorX + 20, cursorY)
    else
        -- Default: BOTTOMRIGHT of cursor
        local offsetX = 15
        local offsetY = -15

        -- Adjust if would go off screen
        if cursorX + offsetX + tooltipWidth > screenWidth then
            offsetX = -tooltipWidth - 5
        end
        if cursorY + offsetY - tooltipHeight < 0 then
            offsetY = 15
        end

        tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX + offsetX, cursorY + offsetY)
    end
end

-- Show tooltip and manage fade timer
local function ShowAndFade(self, noFade)
    self.positionTooltip:SetAlpha(1)
    self.positionTooltip:Show()

    -- Cancel existing fade timer
    if self.positionFadeTimer then
        self.positionFadeTimer:Cancel()
        self.positionFadeTimer = nil
    end

    if noFade then
        return
    end

    -- Start fade out after delay
    self.positionFadeTimer = C_Timer.NewTimer(C.Selection.TooltipFadeDuration, function()
        if self.positionTooltip then
            UIFrameFadeOut(self.positionTooltip, C.Timing.FadeDuration, 1, 0)
        end
        self.positionFadeTimer = nil
    end)
end

-------------------------------------------------
-- SHOW FRAME POSITION TOOLTIP
-------------------------------------------------

function Tooltip:ShowPosition(frame, Selection, noFade)
    if not frame then
        return
    end

    local tooltip = EnsureTooltip(self)

    -- Calculate centers in screen pixels to handle scale differences
    local uiScale = UIParent:GetEffectiveScale()
    local uiWidth, uiHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local screenCenterX = (uiWidth * uiScale) / 2
    local screenCenterY = (uiHeight * uiScale) / 2

    local frameLeft, frameBottom, frameWidth, frameHeight = frame:GetRect()
    if not frameLeft then
        return
    end

    local frameScale = frame:GetEffectiveScale()
    local frameCenterX = (frameLeft + (frameWidth / 2)) * frameScale
    local frameCenterY = (frameBottom + (frameHeight / 2)) * frameScale

    local relX = math.floor(frameCenterX - screenCenterX + 0.5)
    local relY = math.floor(frameCenterY - screenCenterY + 0.5)

    -- Update tooltip text
    local parent = Engine.FrameAnchor:GetAnchorParent(frame)
    if parent then
        local anchor = Engine.FrameAnchor.anchors[frame]
        local padding = anchor and anchor.padding or 0
        tooltip.text:SetText("Distance: " .. padding)
    else
        tooltip.text:SetText(string.format("%d, %d", relX, relY))
    end

    -- Resize and position
    tooltip:SetWidth(tooltip.text:GetStringWidth() + 16)

    local screenWidth = GetScreenWidth()
    local cursorX = GetCursorPosition() / uiScale
    local anchor = (cursorX + tooltip:GetWidth() + 30 > screenWidth) and "LEFT" or "RIGHT"
    PositionAtCursor(tooltip, anchor)

    ShowAndFade(self, noFade)
end

-------------------------------------------------
-- SHOW COMPONENT POSITION TOOLTIP
-------------------------------------------------

function Tooltip:ShowComponentPosition(component, key, anchorX, anchorY, posX, posY, offsetX, offsetY, justifyH)
    if not component then
        return
    end

    local tooltip = EnsureTooltip(self)

    -- Build anchor string
    local anchorStr
    if anchorX == "CENTER" and anchorY == "CENTER" then
        anchorStr = "CENTER"
    elseif anchorY == "CENTER" then
        anchorStr = anchorX
    elseif anchorX == "CENTER" then
        anchorStr = anchorY
    else
        anchorStr = anchorX .. " " .. anchorY
    end

    -- Format display values
    local displayOffX = math.floor((offsetX or 0) + 0.5)
    local displayOffY = math.floor((offsetY or 0) + 0.5)
    local displayPosX = math.floor((posX or 0) + 0.5)
    local displayPosY = math.floor((posY or 0) + 0.5)
    local justifyStr = justifyH or "CENTER"

    -- Build tooltip text based on anchor type
    local tooltipText
    if anchorX == "CENTER" and anchorY == "CENTER" then
        tooltipText = string.format("%s\nJustify: %s\nPosition: %d, %d", anchorStr, justifyStr, displayPosX, displayPosY)
    else
        tooltipText = string.format("%s\nJustify: %s\nOffset: %d, %d", anchorStr, justifyStr, displayOffX, displayOffY)
    end

    tooltip.text:SetText(tooltipText)

    -- Resize tooltip to fit text
    local textWidth = tooltip.text:GetStringWidth()
    local textHeight = tooltip.text:GetStringHeight()
    tooltip:SetSize(textWidth + 16, textHeight + 12)

    PositionAtCursor(tooltip, "BOTTOMRIGHT")
    ShowAndFade(self)
end
