-- [ CANVAS MODE MODULE ]----------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.CanvasMode = Engine.CanvasMode or {}
local CanvasMode = Engine.CanvasMode

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local CANVAS_BORDER_COLOR = { r = 0.3, g = 0.8, b = 0.3, a = 1.0 }
local CANVAS_BORDER_SIZE = 3
local CANVAS_BACKGROUND_COLOR = { r = 0, g = 0, b = 0, a = 0.4 }
local OVERLAY_COLOR = { r = 0.3, g = 0.8, b = 0.3, a = 0.3 }
local CANVAS_PADDING = 25
local INSET = 4
local FLASH_INTERVAL = 0.1
local FLASH_TOTAL = 4
local FLASH_RED = { 1, 0.2, 0.2, 0.8 }
local FLASH_NEUTRAL = { 1, 1, 1, 1 }
local BORDER_FRAME_LEVEL = 150
local DIM_ALPHA = 0.3

-- [ STATE ]-----------------------------------------------------------------------------------------

CanvasMode.currentFrame = nil

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function GetFrameKey(frame)
    if not frame then return nil end
    if frame.editModeName then return frame.editModeName end
    if frame.GetName and frame:GetName() then return frame:GetName() end
    if frame.systemIndex then return "System_" .. tostring(frame.systemIndex) end
    return nil
end

local function TintSelectionTextures(sel, r, g, b, a)
    if sel.GetRegions then
        for i = 1, select("#", sel:GetRegions()) do
            local region = select(i, sel:GetRegions())
            if region:IsObjectType("Texture") and not region.isAnchorLine then
                region:SetVertexColor(r, g, b, a)
            end
        end
    elseif sel.SetVertexColor then
        sel:SetVertexColor(r, g, b, a)
    end
end

local function CreateBorderEdge(parent, c, isVertical, point1, rel1, point2, rel2)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetColorTexture(c.r, c.g, c.b, c.a)
    if isVertical then
        tex:SetWidth(CANVAS_BORDER_SIZE)
    else
        tex:SetHeight(CANVAS_BORDER_SIZE)
    end
    tex:SetPoint(point1, parent, rel1, 0, 0)
    tex:SetPoint(point2, parent, rel2, 0, 0)
    return tex
end

-- [ DENIED FEEDBACK ]-------------------------------------------------------------------------------

local flashPool = nil

local function PlayDeniedFeedback(frame)
    local selection
    if Engine.FrameSelection then selection = Engine.FrameSelection.selections[frame] end
    if not selection then selection = frame.Selection end
    if not selection then return end
    if flashPool and flashPool:GetScript("OnUpdate") then return end

    local wasShown = selection:IsShown()
    if not wasShown then selection:Show() end
    if not flashPool then flashPool = CreateFrame("Frame") end

    local flashCount = 0
    flashPool.elapsed = 0
    flashPool.targetFrame = frame
    flashPool.targetSelection = selection
    flashPool.wasShown = wasShown

    flashPool:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < FLASH_INTERVAL then return end
        self.elapsed = 0
        flashCount = flashCount + 1

        local sel = self.targetSelection
        local c = (flashCount % 2 == 1) and FLASH_RED or FLASH_NEUTRAL
        TintSelectionTextures(sel, c[1], c[2], c[3], c[4])

        if flashCount >= FLASH_TOTAL then
            if Engine.FrameSelection and Engine.FrameSelection.UpdateVisuals then
                Engine.FrameSelection:UpdateVisuals(self.targetFrame)
            else
                TintSelectionTextures(sel, FLASH_NEUTRAL[1], FLASH_NEUTRAL[2], FLASH_NEUTRAL[3], FLASH_NEUTRAL[4])
            end

            local shouldHide = not (EditModeManagerFrame and EditModeManagerFrame:IsShown()) or not self.wasShown
            if shouldHide and sel.Hide then
                sel:Hide()
                if self.wasShown == false and Engine.FrameSelection and Engine.FrameSelection.UpdateVisuals then
                    Engine.FrameSelection:UpdateVisuals(self.targetFrame)
                end
            end

            self:SetScript("OnUpdate", nil)
            self.targetFrame = nil
            self.targetSelection = nil
            self.wasShown = nil
        end
    end)
end

-- [ CORE API ]--------------------------------------------------------------------------------------

function CanvasMode:Enter(frame, updateVisualsCallback)
    if not frame then return end
    if InCombatLockdown() then return end

    if not (frame.orbitPlugin and frame.orbitPlugin.canvasMode == true) then
        PlayDeniedFeedback(frame)
        return
    end

    if self.currentFrame and self.currentFrame ~= frame then
        self:Exit(self.currentFrame)
    end

    self.currentFrame = frame

    local dialog = Engine.CanvasModeDialog or Orbit.CanvasModeDialog
    if dialog then
        local plugin = frame.orbitPlugin
        local systemIndex = frame.systemIndex or (plugin and plugin.system) or 1
        dialog:Open(frame, plugin, systemIndex)
    end

    if updateVisualsCallback then updateVisualsCallback(frame) end
end

function CanvasMode:Exit(frame, updateVisualsCallback)
    if not frame then return end
    if self.currentFrame ~= frame then return end

    self.currentFrame = nil

    local dialog = Engine.CanvasModeDialog or Orbit.CanvasModeDialog
    if dialog and dialog:IsShown() then dialog:Cancel() end

    if Engine.FrameSelection then Engine.FrameSelection:UpdateVisuals(frame) end
    if updateVisualsCallback then updateVisualsCallback(frame) end
end

function CanvasMode:IsActive(frame) return self.currentFrame == frame end

function CanvasMode:IsFrameInCanvasMode(frame)
    if frame then return self.currentFrame == frame end
    return self.currentFrame ~= nil
end

function CanvasMode:Toggle(frame, updateVisualsCallback)
    if self:IsActive(frame) then self:Exit(frame, updateVisualsCallback)
    else self:Enter(frame, updateVisualsCallback) end
end

function CanvasMode:ExitAll()
    if self.currentFrame then self:Exit(self.currentFrame) end
    if Engine.ComponentDrag then Engine.ComponentDrag:DisableAll() end
end

function CanvasMode:GetCurrentFrame() return self.currentFrame end

-- [ VISUAL UPDATES ]--------------------------------------------------------------------------------

local function CreateCanvasBorder(parent)
    return {
        top = CreateBorderEdge(parent, CANVAS_BORDER_COLOR, false, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT"),
        bottom = CreateBorderEdge(parent, CANVAS_BORDER_COLOR, false, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT"),
        left = CreateBorderEdge(parent, CANVAS_BORDER_COLOR, true, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT"),
        right = CreateBorderEdge(parent, CANVAS_BORDER_COLOR, true, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT"),
    }
end

local function SetCanvasBorderShown(border, shown)
    if not border then return end
    for _, edge in pairs(border) do edge:SetShown(shown) end
end

function CanvasMode:UpdateOrbitFrameVisual(frame)
    if not frame then return end
    local selection = frame.Selection
    if not selection then return end

    if self:IsActive(frame) then
        if not CanvasMode.backgroundFrame then
            CanvasMode.backgroundFrame = CreateFrame("Frame", "OrbitCanvasBackgroundFrame", UIParent)
            CanvasMode.backgroundFrame:SetFrameStrata("BACKGROUND")
            CanvasMode.backgroundFrame:SetFrameLevel(0)
            CanvasMode.backgroundTexture = CanvasMode.backgroundFrame:CreateTexture(nil, "BACKGROUND")
            CanvasMode.backgroundTexture:SetAllPoints()
            local bg = CANVAS_BACKGROUND_COLOR
            CanvasMode.backgroundTexture:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
        end

        if not CanvasMode.borderFrame then
            CanvasMode.borderFrame = CreateFrame("Frame", "OrbitCanvasBorderFrame", UIParent)
            CanvasMode.borderFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            CanvasMode.borderFrame:SetFrameLevel(BORDER_FRAME_LEVEL)
            CanvasMode.border = CreateCanvasBorder(CanvasMode.borderFrame)
        end

        local function UpdateCanvasPosition()
            if not frame or not frame:IsShown() then return end
            local scale = frame:GetEffectiveScale()
            local uiScale = UIParent:GetEffectiveScale()
            local scaleRatio = scale / uiScale

            local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
            if not left or not right or not top or not bottom then return end

            local padding = CANVAS_PADDING * scaleRatio
            local uiLeft = (left * scale / uiScale) - padding
            local uiBottom = (bottom * scale / uiScale) - padding
            local uiRight = (right * scale / uiScale) + padding
            local uiTop = (top * scale / uiScale) + padding
            local width, height = uiRight - uiLeft, uiTop - uiBottom

            CanvasMode.borderFrame:ClearAllPoints()
            CanvasMode.borderFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", uiLeft, uiBottom)
            CanvasMode.borderFrame:SetSize(width, height)

            CanvasMode.backgroundFrame:ClearAllPoints()
            CanvasMode.backgroundFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", uiLeft, uiBottom)
            CanvasMode.backgroundFrame:SetSize(width, height)
        end

        UpdateCanvasPosition()

        if not CanvasMode.borderFrame._sizeHooked then
            CanvasMode.borderFrame._sizeHooked = true
            frame:HookScript("OnSizeChanged", function()
                if CanvasMode.currentFrame == frame then UpdateCanvasPosition() end
            end)
        end

        CanvasMode.backgroundFrame:Show()
        CanvasMode.borderFrame:Show()
        SetCanvasBorderShown(CanvasMode.border, true)
    else
        if CanvasMode.backgroundFrame then CanvasMode.backgroundFrame:Hide() end
        if CanvasMode.borderFrame then
            CanvasMode.borderFrame:Hide()
            SetCanvasBorderShown(CanvasMode.border, false)
        end
    end
end

function CanvasMode:UpdateNativeFrameVisual(systemFrame)
    if InCombatLockdown() then return end
    if not systemFrame or not systemFrame.Selection then return end

    local selection = systemFrame.Selection

    if self:IsActive(systemFrame) then
        if not selection.CanvasModeOverlay then
            selection.CanvasModeOverlay = selection:CreateTexture(nil, "OVERLAY")
            selection.CanvasModeOverlay:SetAllPoints()
        end
        selection.CanvasModeOverlay:SetColorTexture(OVERLAY_COLOR.r, OVERLAY_COLOR.g, OVERLAY_COLOR.b, OVERLAY_COLOR.a)
        selection.CanvasModeOverlay:Show()

        for _, region in ipairs({ selection:GetRegions() }) do
            if region:IsObjectType("Texture") and region ~= selection.CanvasModeOverlay then
                region:SetAlpha(DIM_ALPHA)
            end
        end
    else
        if selection.CanvasModeOverlay then selection.CanvasModeOverlay:Hide() end
        for _, region in ipairs({ selection:GetRegions() }) do
            if region:IsObjectType("Texture") and region ~= selection.CanvasModeOverlay then
                region:SetAlpha(1)
            end
        end
    end
end

-- [ INITIALIZATION ]--------------------------------------------------------------------------------

function CanvasMode:Initialize()
    if not EditModeManagerFrame then return end
    EditModeManagerFrame:HookScript("OnHide", function() CanvasMode:ExitAll() end)
end

