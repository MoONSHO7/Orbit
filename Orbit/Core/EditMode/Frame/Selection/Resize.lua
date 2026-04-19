-- [ ORBIT SELECTION - RESIZE HANDLE ]--------------------------------------------------------------
-- Attaches a bottom-right resize handle to selection overlays for frames
-- whose orbitPlugin exposes size settings. Reads per-plugin config from
-- frame.orbitResizeBounds = { minW, maxW, minH, maxH, widthKey, heightKey }.
-- widthKey/heightKey default to "Width"/"Height" when omitted.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.SelectionResize = {}
local Resize = Engine.SelectionResize

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local HANDLE_SIZE = 30
local HANDLE_OFFSET_X = 5
local HANDLE_OFFSET_Y = -5
local DEFAULT_MIN_W = 50
local DEFAULT_MAX_W = 400
local DEFAULT_MIN_H = 20
local DEFAULT_MAX_H = 100
local DEFAULT_WIDTH_KEY = "Width"
local DEFAULT_HEIGHT_KEY = "Height"
local DRAG_DIVISOR_X = 2
local DRAG_DIVISOR_Y = 4
local SHIFT_DIVISOR_X = 6
local SHIFT_DIVISOR_Y = 12

-- Returns which axes are locked because the frame's anchor syncs that dimension from its parent.
-- TOP/BOTTOM anchors sync WIDTH (gated by orbitWidthSync); LEFT/RIGHT sync HEIGHT (gated by orbitHeightSync).
local function GetSyncLocks(frame)
    if not frame then return false, false end
    local anchors = Engine.FrameAnchor and Engine.FrameAnchor.anchors
    local anchor = anchors and anchors[frame]
    if not anchor then return false, false end
    local edgeAxis = Engine.Axis.ForEdge(anchor.edge)
    if not edgeAxis then return false, false end
    local crossAxis = edgeAxis.perpendicular
    if not Engine.Axis.SyncEnabled(frame, crossAxis) then
        return false, false
    end
    if crossAxis == Engine.Axis.vertical then
        return false, true   -- height locked
    end
    return true, false       -- width locked
end

-- [ SLIDER SYNC ]-----------------------------------------------------------------------------------
local function RefreshDialogSliders(plugin, newW, newH, wKey, hKey)
    local Layout = Engine.Layout
    if not Layout or not Layout.containerControls then return end
    for _, controls in pairs(Layout.containerControls) do
        for _, control in ipairs(controls) do
            if control.OrbitType == "Slider" and control:IsShown() and control.Label then
                local label = control.Label:GetText()
                local key = control.SettingKey or label
                local inner = control.Slider and control.Slider.Slider
                if not inner then break end
                if key == wKey or key == hKey then
                    control._isInitializing = true
                    local isWidth = (key == wKey)
                    inner:SetValue(isWidth and newW or newH)
                    if control.Value and control.valueFormatter then control.Value:SetText(control.valueFormatter(isWidth and newW or newH)) end
                    control._isInitializing = false
                end
            end
        end
    end
end

-- [ ATTACH ]----------------------------------------------------------------------------------------
function Resize:Attach(selection, frame)
    if not selection or not frame then return end
    local plugin = frame.orbitPlugin
    if not plugin or not plugin.GetSetting or not plugin.SetSetting then return end

    local sysIdx = frame.systemIndex or 1
    local bounds = frame.orbitResizeBounds or {}
    local wKey = bounds.widthKey or DEFAULT_WIDTH_KEY
    local hKey = bounds.heightKey or DEFAULT_HEIGHT_KEY

    local w = plugin:GetSetting(sysIdx, wKey)
    if not w then return end

    if selection.resizeHandle then return end

    local handle = CreateFrame("Button", nil, selection)
    handle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    handle:SetPoint("BOTTOMRIGHT", selection, "BOTTOMRIGHT", HANDLE_OFFSET_X, HANDLE_OFFSET_Y)
    handle:SetFrameLevel(selection:GetFrameLevel() + 10)
    handle:SetNormalAtlas("damagemeters-scalehandle")
    handle:SetHighlightAtlas("damagemeters-scalehandle-hover")
    handle:SetPushedAtlas("damagemeters-scalehandle-pressed")
    handle:RegisterForDrag("LeftButton")
    handle:Hide()

    handle.plugin = plugin
    handle.parentFrame = frame
    handle.sysIdx = sysIdx
    selection.resizeHandle = handle

    handle:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        local b = self.parentFrame.orbitResizeBounds or {}
        self.wKey = b.widthKey or DEFAULT_WIDTH_KEY
        self.hKey = b.heightKey or DEFAULT_HEIGHT_KEY
        self.minW = b.minW or DEFAULT_MIN_W
        self.maxW = b.maxW or DEFAULT_MAX_W
        self.minH = b.minH or DEFAULT_MIN_H
        self.maxH = b.maxH or DEFAULT_MAX_H
        self.widthLocked, self.heightLocked = GetSyncLocks(self.parentFrame)
        local mx, my = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self.startMouseX = mx / scale
        self.startMouseY = my / scale
        self.startWidth = self.plugin:GetSetting(self.sysIdx, self.wKey) or 100
        self.startHeight = self.plugin:GetSetting(self.sysIdx, self.hKey) or 40
        -- If both axes are anchor-synced, drag would do nothing — short-circuit cleanly.
        if self.widthLocked and self.heightLocked then
            self.isDragging = false
            return
        end
        self.isDragging = true
    end)

    handle:SetScript("OnDragStop", function(self)
        self.isDragging = false
        -- Snapshot the live anchor-synced dimension into stored settings so a future unanchor
        -- doesn't snap the frame back to the pre-anchor width/height (which was stale).
        if self.widthLocked then
            local liveW = self.parentFrame:GetWidth()
            if liveW and liveW > 0 then
                self.plugin:SetSetting(self.sysIdx, self.wKey, math.floor(liveW + 0.5))
            end
        end
        if self.heightLocked then
            local liveH = self.parentFrame:GetHeight()
            if liveH and liveH > 0 then
                self.plugin:SetSetting(self.sysIdx, self.hKey, math.floor(liveH + 0.5))
            end
        end
        if self.plugin.ApplySettings then self.plugin:ApplySettings() end
        Engine.SelectionTooltip:ShowResizeInfo(self.parentFrame, self.plugin:GetSetting(self.sysIdx, self.wKey) or 100, self.plugin:GetSetting(self.sysIdx, self.hKey) or 40)
    end)

    handle:SetScript("OnUpdate", function(self)
        if not self.isDragging then return end
        local mx, my = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mx, my = mx / scale, my / scale

        local shift = IsShiftKeyDown()
        if shift ~= self.wasShift then
            self.startMouseX = mx
            self.startMouseY = my
            self.startWidth = self.plugin:GetSetting(self.sysIdx, self.wKey) or self.startWidth
            self.startHeight = self.plugin:GetSetting(self.sysIdx, self.hKey) or self.startHeight
            self.wasShift = shift
        end

        local dx = (mx - self.startMouseX) / (shift and SHIFT_DIVISOR_X or DRAG_DIVISOR_X)
        local dy = (self.startMouseY - my) / (shift and SHIFT_DIVISOR_Y or DRAG_DIVISOR_Y)
        -- Anchor-synced axes are pinned: the user's drag delta is discarded.
        local rawW = self.widthLocked  and self.startWidth  or (self.startWidth + dx)
        local rawH = self.heightLocked and self.startHeight or (self.startHeight + dy)
        local newW = math.max(self.minW, math.min(self.maxW, math.floor(rawW + 0.5)))
        local newH = math.max(self.minH, math.min(self.maxH, math.floor(rawH + 0.5)))

        local curW = self.plugin:GetSetting(self.sysIdx, self.wKey)
        local curH = self.plugin:GetSetting(self.sysIdx, self.hKey)
        if curW == newW and curH == newH then return end

        -- Per-axis writes: locked axes never touch SetSetting OR the frame's live dimension,
        -- so the anchor-sync value stays authoritative — no visual jump from stored-vs-synced mismatch.
        if not self.widthLocked then
            self.plugin:SetSetting(self.sysIdx, self.wKey, newW)
            self.parentFrame:SetWidth(newW)
        end
        if not self.heightLocked then
            self.plugin:SetSetting(self.sysIdx, self.hKey, newH)
            self.parentFrame:SetHeight(newH)
        end
        if self.plugin.ApplySettings then self.plugin:ApplySettings() end

        RefreshDialogSliders(self.plugin, newW, newH, self.wKey, self.hKey)
        Engine.SelectionTooltip:ShowResizeInfo(self.parentFrame, newW, newH, true)
    end)

    handle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:GetScript("OnDragStart")(self) end
    end)

    handle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then self:GetScript("OnDragStop")(self) end
    end)
end

-- [ SHOW / HIDE ]-----------------------------------------------------------------------------------
function Resize:Show(selection)
    if selection and selection.resizeHandle then selection.resizeHandle:Show() end
end

function Resize:Hide(selection)
    if selection and selection.resizeHandle then selection.resizeHandle:Hide() end
end
