-- [ ORBIT SELECTION - POSITION TOOLTIP ]-----------------------------------------------------------
-- Handles the position tooltip shown during keyboard nudging

local _, Orbit = ...
local Engine = Orbit.Engine
local C = Orbit.Constants

local Tooltip = {}
Engine.SelectionTooltip = Tooltip

Tooltip.positionTooltip = nil
Tooltip.positionFadeTimer = nil

-- [ SHOW POSITION TOOLTIP ]-------------------------------------------------------------------------

function Tooltip:ShowPosition(frame, Selection, noFade)
    if not frame then
        return
    end

    -- Create tooltip frame if needed
    if not self.positionTooltip then
        local tooltip = CreateFrame("Frame", "OrbitNudgePositionTooltip", UIParent, "BackdropTemplate")
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
    end

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

    -- Calculate difference in screen pixels (scale-independent)
    -- This shows the actual pixel offset from screen center
    local relX = math.floor(frameCenterX - screenCenterX + 0.5)
    local relY = math.floor(frameCenterY - screenCenterY + 0.5)

    -- Update tooltip text
    local parent = Engine.FrameAnchor:GetAnchorParent(frame)
    if parent then
        local anchor = Engine.FrameAnchor.anchors[frame]
        local padding = anchor and anchor.padding or 0
        self.positionTooltip.text:SetText("Distance: " .. padding)
    else
        self.positionTooltip.text:SetText(string.format("%d, %d", relX, relY))
    end

    -- Resize tooltip to fit text
    local textWidth = self.positionTooltip.text:GetStringWidth()
    self.positionTooltip:SetWidth(textWidth + 16)

    -- Position near cursor (edge-aware)
    local cursorX, cursorY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    cursorX = cursorX / uiScale
    cursorY = cursorY / uiScale

    local screenWidth = GetScreenWidth()
    local tooltipWidth = self.positionTooltip:GetWidth()

    self.positionTooltip:ClearAllPoints()
    -- If cursor is in right portion of screen, position tooltip to LEFT of cursor
    if cursorX + tooltipWidth + 30 > screenWidth then
        self.positionTooltip:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", cursorX - 20, cursorY)
    else
        self.positionTooltip:SetPoint("LEFT", UIParent, "BOTTOMLEFT", cursorX + 20, cursorY)
    end

    -- Show and reset alpha
    self.positionTooltip:SetAlpha(1)
    self.positionTooltip:Show()

    -- Cancel existing fade timer
    if self.positionFadeTimer then
        self.positionFadeTimer:Cancel()
        self.positionFadeTimer = nil
    end

    -- If noFade is requested, we are done (tooltip stays shown until updated or faded later)
    if noFade then
        return
    end

    -- Start fade out
    self.positionFadeTimer = C_Timer.NewTimer(C.Selection.TooltipFadeDuration, function()
        if self.positionTooltip then
            UIFrameFadeOut(self.positionTooltip, C.Timing.FadeDuration, 1, 0)
        end
        self.positionFadeTimer = nil
    end)
end

-- [ SHOW COMPONENT POSITION TOOLTIP ]---------------------------------------------------------------
-- Shows tooltip during component drag/nudge with center-relative x,y coords

function Tooltip:ShowComponentPosition(component, key, alignment, x, y, parentWidth, parentHeight)
    if not component then
        return
    end

    -- Reuse the same tooltip frame
    if not self.positionTooltip then
        -- Create if not exists (same code as ShowPosition)
        local tooltip = CreateFrame("Frame", "OrbitNudgePositionTooltip", UIParent, "BackdropTemplate")
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
    end

    -- x, y are already center-relative from ComponentDrag
    local displayX = math.floor((x or 0) + 0.5)
    local displayY = math.floor((y or 0) + 0.5)

    -- Simple format: just x, y
    self.positionTooltip.text:SetText(string.format("%d, %d", displayX, displayY))

    -- Resize tooltip to fit text
    local textWidth = self.positionTooltip.text:GetStringWidth()
    local textHeight = self.positionTooltip.text:GetStringHeight()
    self.positionTooltip:SetSize(textWidth + 16, textHeight + 12)

    -- Position near cursor (edge-aware)
    local cursorX, cursorY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    cursorX = cursorX / uiScale
    cursorY = cursorY / uiScale

    local screenWidth = GetScreenWidth()
    local tooltipWidth = self.positionTooltip:GetWidth()

    self.positionTooltip:ClearAllPoints()
    if cursorX + tooltipWidth + 30 > screenWidth then
        self.positionTooltip:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", cursorX - 20, cursorY)
    else
        self.positionTooltip:SetPoint("LEFT", UIParent, "BOTTOMLEFT", cursorX + 20, cursorY)
    end

    -- Show and reset alpha
    self.positionTooltip:SetAlpha(1)
    self.positionTooltip:Show()

    -- Cancel existing fade timer
    if self.positionFadeTimer then
        self.positionFadeTimer:Cancel()
        self.positionFadeTimer = nil
    end

    -- Start fade out after delay
    self.positionFadeTimer = C_Timer.NewTimer(C.Selection.TooltipFadeDuration, function()
        if self.positionTooltip then
            UIFrameFadeOut(self.positionTooltip, C.Timing.FadeDuration, 1, 0)
        end
        self.positionFadeTimer = nil
    end)
end
