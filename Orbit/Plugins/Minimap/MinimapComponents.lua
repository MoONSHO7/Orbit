-- [ MINIMAP COMPONENTS ]-----------------------------------------------------------------------------
-- Per-component updaters and creators: Clock, Coords, ZoomButtons, ZoneText, CalendarInvites.

---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local C = Orbit.MinimapConstants

local SYSTEM_ID = C.SYSTEM_ID
local MASK_SQUARE = C.MASK_SQUARE
local MASK_ROUND = C.MASK_ROUND
local COORDS_UPDATE_INTERVAL = C.COORDS_UPDATE_INTERVAL
local ZOOM_BUTTON_W = C.ZOOM_BUTTON_W
local ZOOM_BUTTON_IN_H = C.ZOOM_BUTTON_IN_H
local ZOOM_BUTTON_OUT_H = C.ZOOM_BUTTON_OUT_H
local ZOOM_FADE_IN = C.ZOOM_FADE_IN
local ZOOM_FADE_OUT = C.ZOOM_FADE_OUT

local Plugin = Orbit:GetPlugin(SYSTEM_ID)

-- [ SHAPE ] -----------------------------------------------------------------------------------------
function Plugin:ApplyShape()
    local frame = self.frame
    local shape = self:GetSetting(SYSTEM_ID, "Shape") or "square"
    local minimap = self:GetBlizzardMinimap()
    local isRound = shape == "round"

    -- Apply mask to the Blizzard minimap render surface and, if present, the HybridMinimap
    -- vector tile canvas. HybridMinimap uses its own CircleMask texture that must be updated
    -- independently; toggling SetUseMaskTexture off/on is required to flush the change.
    local mask = isRound and MASK_ROUND or MASK_SQUARE
    if minimap then minimap:SetMaskTexture(mask) end
    if HybridMinimap then
        HybridMinimap.MapCanvas:SetUseMaskTexture(false)
        HybridMinimap.CircleMask:SetTexture(mask)
        HybridMinimap.MapCanvas:SetUseMaskTexture(true)
    end

    -- Clip the background texture to the same shape.
    -- Textures use AddMaskTexture; we cache the mask texture object on the bg.
    if frame.bg then
        if isRound then
            if not frame.bg._orbitMask then
                frame.bg._orbitMask = frame:CreateMaskTexture()
                frame.bg._orbitMask:SetTexture(MASK_ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                frame.bg._orbitMask:SetAllPoints(frame.bg)
                frame.bg:AddMaskTexture(frame.bg._orbitMask)
            end
            frame.bg._orbitMask:Show()
        else
            if frame.bg._orbitMask then
                frame.bg._orbitMask:Hide()
            end
        end
    end

    -- Square border vs. round ring.
    -- For round: force-clear any NineSlice overlay and hide the border frame entirely,
    -- regardless of the global border style setting. The round shape uses the ring atlas instead.
    local borderSize = Orbit.db.GlobalSettings.BorderSize or 2
    local bc = self:GetSetting(SYSTEM_ID, "BorderColor") or Orbit.MinimapConstants.BORDER_COLOR
    if isRound then
        Orbit.Skin:ClearNineSliceBorder(frame)
        Orbit.Skin:SkinBorder(frame, frame, 0, bc, false, true)
        if frame.RoundBorder then
            frame.RoundBorder:SetVertexColor(bc.r, bc.g, bc.b, bc.a or 1)
            frame.RoundBorder:Show()
        end
    else
        Orbit.Skin:SkinBorder(frame, frame, borderSize, bc)
        if frame.RoundBorder then frame.RoundBorder:Hide() end
    end
end

-- [ ZONE TEXT ]--------------------------------------------------------------------------------------
local ZONE_PVP_COLORS = {
    sanctuary = { r = 0.41, g = 0.80, b = 0.94 }, -- blue/teal: Shattrath, Dalaran etc.
    friendly   = { r = 0.10, g = 1.00, b = 0.10 }, -- green: friendly faction territory
    hostile    = { r = 1.00, g = 0.10, b = 0.10 }, -- red: enemy faction territory
    contested  = { r = 1.00, g = 0.70, b = 0.00 }, -- orange: contested zones
    arena      = { r = 1.00, g = 0.10, b = 0.10 }, -- red: FFA / arena zones
    combat     = { r = 1.00, g = 0.10, b = 0.10 }, -- red: active combat zones
    pvp        = { r = 1.00, g = 0.70, b = 0.00 }, -- orange: opt-in PvP
}
Plugin.ZonePVPColors = ZONE_PVP_COLORS -- shared with Minimap.lua for tooltip colouring

-- [ ZONE TEXT ] -------------------------------------------------------------------------------------
local lastZoneText = nil

function Plugin:UpdateZoneText(button, coloring, overrides)
    local fontString = button.Text or button
    local newText = GetMinimapZoneText()
    if newText ~= lastZoneText then
        lastZoneText = newText
        fontString:SetText(newText)
    end
    if coloring then
        local pvpType = GetZonePVPInfo()
        local color = ZONE_PVP_COLORS[pvpType]
        if color then
            fontString:SetTextColor(color.r, color.g, color.b, 1)
        else
            fontString:SetTextColor(1, 1, 1, 1)
        end
    elseif overrides and next(overrides) then
        OrbitEngine.OverrideUtils.ApplyTextColor(fontString, overrides)
    else
        fontString:SetTextColor(1, 1, 1, 1)
    end
    if button.Text then
        button:SetSize(fontString:GetStringWidth() + 2, fontString:GetStringHeight() + 2)
    end
end

-- [ CLOCK ]------------------------------------------------------------------------------------------
-- Cache clock CVars so we don't call GetCVarBool on every tick.
local _clockUseLocal, _clockUseMilitary
local function RefreshClockCVars()
    _clockUseLocal    = GetCVarBool("timeMgrUseLocalTime")
    _clockUseMilitary = GetCVarBool("timeMgrUseMilitaryTime")
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("CVAR_UPDATE")
    f:SetScript("OnEvent", function(_, _, cvarName)
        if cvarName == "timeMgrUseLocalTime" or cvarName == "timeMgrUseMilitaryTime" then
            RefreshClockCVars()
        end
    end)
end

-- Format time using the cached military-time flag instead of re-reading the CVar.
-- GameTime_GetFormattedTime always calls GetCVarBool("timeMgrUseMilitaryTime") internally,
-- so if anything else flips that CVar the clock format can desync from the user's preference.
local function FormatClockTime(hour, minute)
    if _clockUseMilitary then
        return format(TIMEMANAGER_TICKER_24HOUR, hour, minute)
    else
        if hour == 0 then
            hour = 12
        elseif hour > 12 then
            hour = hour - 12
        end
        return format(TIMEMANAGER_TICKER_12HOUR, hour, minute)
    end
end

function Plugin:UpdateClock()
    if _clockUseLocal == nil then RefreshClockCVars() end
    local text = self.frame.Clock.Text
    local hour, minute
    if _clockUseLocal then
        hour, minute = tonumber(date("%H")), tonumber(date("%M"))
    else
        hour, minute = GetGameTime()
    end
    text:SetText(FormatClockTime(hour, minute))
    self.frame.Clock:SetSize(text:GetStringWidth() + 2, text:GetStringHeight() + 2)
end

function Plugin:StartClockTicker()
    if self._clockTicker then return end
    -- Warmup: poll every 0.1s until the minute boundary flips, then lock to 60s intervals.
    -- This ensures the clock is never more than ~0.1s stale regardless of when the addon loaded.
    local lastMin = -1
    local function onTick()
        self:UpdateClock()
        local _, min = GetGameTime()
        if _clockUseLocal then min = tonumber(date("%M")) end
        if lastMin == -1 then
            lastMin = min
        elseif min ~= lastMin then
            -- Minute boundary crossed: cancel warmup and start stable 60s ticker
            if self._clockWarmup then self._clockWarmup:Cancel(); self._clockWarmup = nil end
            self._clockTicker = C_Timer.NewTicker(60, function() self:UpdateClock() end)
            return
        end
        -- Still same minute, keep fast-polling via warmup ticker (set below)
    end
    self._clockWarmup = C_Timer.NewTicker(0.1, onTick)
    self._clockTicker = true -- sentinel so re-entry guard works
end

function Plugin:StopClockTicker()
    if self._clockWarmup then self._clockWarmup:Cancel(); self._clockWarmup = nil end
    if self._clockTicker and self._clockTicker ~= true then
        self._clockTicker:Cancel()
    end
    self._clockTicker = nil
end

-- [ COORDS ]-----------------------------------------------------------------------------------------
function Plugin:UpdateCoords()
    local coordsFrame = self.frame.Coords
    local fs = coordsFrame.Text
    local inCanvasMode = OrbitEngine.CanvasMode:IsActive(self.frame)
    local keepVisible = Orbit:IsEditMode() or inCanvasMode
    local unavailableText = inCanvasMode and "00, 00" or "--, --"
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then
        if keepVisible then
            coordsFrame:Show()
            fs:SetText(unavailableText)
            coordsFrame:SetSize(fs:GetStringWidth() + 2, fs:GetStringHeight() + 2)
        else
            coordsFrame:Hide()
        end
        return
    end
    coordsFrame:Show()
    local x, y = pos:GetXY()
    fs:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
    coordsFrame:SetSize(fs:GetStringWidth() + 2, fs:GetStringHeight() + 2)
end

function Plugin:StartCoordsTicker()
    if self._coordsTicker then return end
    self._coordsTicker = C_Timer.NewTicker(COORDS_UPDATE_INTERVAL, function() self:UpdateCoords() end)
end

function Plugin:StopCoordsTicker()
    if self._coordsTicker then
        self._coordsTicker:Cancel()
        self._coordsTicker = nil
    end
end

-- [ ZOOM BUTTONS ]-----------------------------------------------------------------------------------
function Plugin:UpdateZoomState()
    local container = self.frame.ZoomContainer
    local minimap = self:GetBlizzardMinimap()
    local zoom = minimap:GetZoom()
    local maxZoom = minimap:GetZoomLevels() - 1
    container.ZoomIn:SetEnabled(zoom < maxZoom)
    container.ZoomOut:SetEnabled(zoom > 0)
end

function Plugin:CreateZoomButtons()
    local container = CreateFrame("Frame", nil, self.frame.Overlay)
    container:SetSize(ZOOM_BUTTON_W, ZOOM_BUTTON_IN_H + 2 + ZOOM_BUTTON_OUT_H)
    OrbitEngine.Pixel:Enforce(container)
    container:SetPoint("RIGHT", self.frame, "RIGHT", -2, 0)
    self.frame.ZoomContainer = container
    container:SetFrameLevel(self.frame.ClickCapture:GetFrameLevel() + 1)

    -- Hidden icon for canvas mode dock preview (sized to match ZoomIn button)
    container.Icon = container:CreateTexture(nil, "ARTWORK")
    container.Icon:SetSize(ZOOM_BUTTON_W, ZOOM_BUTTON_W)
    container.Icon:SetPoint("CENTER")
    container.Icon:SetAlpha(0)

    -- Zoom In (17x17, matching Blizzard XML)
    local zoomIn = CreateFrame("Button", nil, container)
    zoomIn:SetSize(ZOOM_BUTTON_W, ZOOM_BUTTON_IN_H)
    zoomIn:SetPoint("TOP", container, "TOP", 0, 0)
    zoomIn:SetNormalAtlas("ui-hud-minimap-zoom-in")
    zoomIn:SetPushedAtlas("ui-hud-minimap-zoom-in-down")
    zoomIn:SetHighlightAtlas("ui-hud-minimap-zoom-in-mouseover")
    zoomIn:GetHighlightTexture():SetBlendMode("ADD")
    zoomIn:SetDisabledAtlas("ui-hud-minimap-zoom-in")
    zoomIn:GetDisabledTexture():SetDesaturated(true)
    zoomIn:SetScript("OnClick", function()
        local minimap = self:GetBlizzardMinimap()
        local zoom = minimap:GetZoom()
        if zoom < minimap:GetZoomLevels() - 1 then
            minimap:SetZoom(zoom + 1)
        end
        self:UpdateZoomState()
        self:StartAutoZoomOut()
    end)
    zoomIn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText("Zoom In")
        GameTooltip:Show()
    end)
    zoomIn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    container.ZoomIn = zoomIn

    -- Zoom Out (17x9, matching Blizzard XML)
    local zoomOut = CreateFrame("Button", nil, container)
    zoomOut:SetSize(ZOOM_BUTTON_W, ZOOM_BUTTON_OUT_H)
    zoomOut:SetPoint("TOP", zoomIn, "BOTTOM", 0, -2)
    zoomOut:SetNormalAtlas("ui-hud-minimap-zoom-out")
    zoomOut:SetPushedAtlas("ui-hud-minimap-zoom-out-down")
    zoomOut:SetHighlightAtlas("ui-hud-minimap-zoom-out-mouseover")
    zoomOut:GetHighlightTexture():SetBlendMode("ADD")
    zoomOut:SetDisabledAtlas("ui-hud-minimap-zoom-out")
    zoomOut:GetDisabledTexture():SetDesaturated(true)
    zoomOut:SetScript("OnClick", function()
        local minimap = self:GetBlizzardMinimap()
        local zoom = minimap:GetZoom()
        if zoom > 0 then
            minimap:SetZoom(zoom - 1)
        end
        self:UpdateZoomState()
        self:StartAutoZoomOut()
    end)
    zoomOut:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText("Zoom Out")
        GameTooltip:Show()
    end)
    zoomOut:SetScript("OnLeave", function() GameTooltip:Hide() end)
    container.ZoomOut = zoomOut

    -- Hover-reveal: fade in on minimap/container enter, fade out on leave
    container:SetAlpha(0)

    local function FadeIn()
        if not self:IsComponentDisabled("Zoom") then UIFrameFadeIn(container, ZOOM_FADE_IN, container:GetAlpha(), 1) end
    end
    local function FadeOut()
        if not container:IsMouseOver() and not self.frame:IsMouseOver() then UIFrameFadeOut(container, ZOOM_FADE_OUT, container:GetAlpha(), 0) end
    end

    self.frame:HookScript("OnEnter", FadeIn)
    self.frame:HookScript("OnLeave", FadeOut)
    container:SetScript("OnLeave", FadeOut)

    local minimap = self:GetBlizzardMinimap()
    minimap:HookScript("OnEnter", FadeIn)
    minimap:HookScript("OnLeave", FadeOut)
end

-- [ AUTO ZOOM-OUT TIMER ]----------------------------------------------------------------------------
function Plugin:CancelAutoZoomOut()
    if self._autoZoomTimer then self._autoZoomTimer:Cancel(); self._autoZoomTimer = nil end
end

function Plugin:StartAutoZoomOut()
    if not self:GetSetting(SYSTEM_ID, "AutoZoomOut") then return end

    -- No-op if already at minimum zoom
    local minimap = self:GetBlizzardMinimap()
    if minimap and minimap:GetZoom() == 0 then return end

    self:CancelAutoZoomOut()

    self._autoZoomTimer = C_Timer.NewTimer(5, function()
        self._autoZoomTimer = nil
        local minimap = self:GetBlizzardMinimap()
        if not minimap then return end
        -- Step zoom out one level at a time until we reach 0
        local function StepOut()
            local zoom = minimap:GetZoom()
            if zoom > 0 then
                minimap:SetZoom(zoom - 1)
                self:UpdateZoomState()
                if zoom - 1 > 0 then
                    C_Timer.After(0.3, StepOut)
                end
            end
        end
        StepOut()
    end)
end

-- [ TRACKING BUTTON ]-------------------------------------------------------------------------------

local TRACKING_BUTTON_SIZE = 24
local TRACKING_FADE_IN = 0.15
local TRACKING_FADE_OUT = 0.3

function Plugin:CreateTrackingButton()
    if self._trackingButton then return end
    local frame = self.frame

    -- Toggle button — parented to Overlay so it renders above the Minimap surface.
    local btn = CreateFrame("Button", "OrbitMinimapTrackingButton", frame.Overlay or frame)
    btn:SetSize(TRACKING_BUTTON_SIZE, TRACKING_BUTTON_SIZE)
    btn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
    btn:SetFrameLevel(frame.ClickCapture:GetFrameLevel() + 2)
    btn.orbitOriginalWidth  = TRACKING_BUTTON_SIZE
    btn.orbitOriginalHeight = TRACKING_BUTTON_SIZE

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints(btn)
    btn.highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    btn.highlight:SetAlpha(0.5)
    btn.highlight:SetBlendMode("ADD")

    -- Atlas icon: Blizzard's tracking binoculars
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetAtlas("ui-hud-minimap-tracking-up", false)

    -- Visual used by canvas mode dock preview
    btn.visual = btn.icon

    btn:SetScript("OnMouseDown", function() btn.icon:SetAlpha(0.6) end)
    btn:SetScript("OnMouseUp",   function() btn.icon:SetAlpha(1) end)

    -- Start hidden; revealed on minimap hover.
    btn:SetAlpha(0)

    btn:SetScript("OnClick", function(b) self:RunMinimapClickAction("tracking", b) end)
    btn:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(Orbit.L.PLU_MINIMAP_ACT_TRACK, 1, 1, 1)
        GameTooltip:AddLine("Click to open tracking menu", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self._trackingButton = btn
end

function Plugin:ApplyTrackingButton()
    local frame = self.frame
    local btn = self._trackingButton
    if not btn then return end

    local useClickAction = self:UsesTrackingClickAction()

    if not useClickAction and not self:IsComponentDisabled("Tracking") then
        btn:Show()

        if not frame._trackingHoverHooked then
            local minimap = Minimap
            local function ShowTrackingButton()
                if not btn:IsShown() then return end
                UIFrameFadeIn(btn, TRACKING_FADE_IN, btn:GetAlpha(), 1)
            end
            local function HideTrackingButton()
                if not btn:IsShown() then return end
                if btn:IsMouseOver() then return end
                if minimap and minimap:IsMouseOver() then return end
                UIFrameFadeOut(btn, TRACKING_FADE_OUT, btn:GetAlpha(), 0)
            end
            frame:HookScript("OnEnter", ShowTrackingButton)
            frame:HookScript("OnLeave", HideTrackingButton)
            if minimap then
                minimap:HookScript("OnEnter", ShowTrackingButton)
                minimap:HookScript("OnLeave", HideTrackingButton)
            end
            btn:HookScript("OnEnter", ShowTrackingButton)
            btn:HookScript("OnLeave", HideTrackingButton)
            frame._trackingHoverHooked = true
        end
    else
        btn:SetAlpha(0)
        btn:Hide()
    end
end

-- [ CALENDAR PENDING INVITES ]----------------------------------------------------------------------

function Plugin:UpdateCalendarInvites()
    local glow = self.frame.Clock.InviteGlow
    local pending = C_Calendar.GetNumPendingInvites and C_Calendar.GetNumPendingInvites() or 0
    if pending > 0 then glow:Show() else glow:Hide() end
end
