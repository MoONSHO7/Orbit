---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Minimap"

local Plugin = Orbit:RegisterPlugin("Minimap", SYSTEM_ID, {
    liveToggle = true,
    canvasMode = true,
    defaults = {
        Scale = 100,
        Opacity = 100,
        Size = 200,
        ZoneTextSize = 12,
        ZoneTextColoring = false,
        DisabledComponents = {},
        ComponentPositions = {
            ZoneText = { anchorX = "CENTER", offsetX = 0, anchorY = "TOP", offsetY = 4, justifyH = "CENTER" },
            Clock = { anchorX = "CENTER", offsetX = 0, anchorY = "BOTTOM", offsetY = 4, justifyH = "CENTER" },
            Compartment = { anchorX = "RIGHT", offsetX = 2, anchorY = "BOTTOM", offsetY = 2 },
            Coords = { anchorX = "RIGHT", offsetX = 4, anchorY = "BOTTOM", offsetY = 4, justifyH = "RIGHT" },
            Zoom = { anchorX = "RIGHT", offsetX = -2, anchorY = "CENTER", offsetY = 0 },
            Difficulty = { anchorX = "LEFT", offsetX = 20, anchorY = "TOP", offsetY = 20 },
            Missions = { anchorX = "LEFT", offsetX = 20, anchorY = "BOTTOM", offsetY = 20 },
            Mail = { anchorX = "RIGHT", offsetX = 20, anchorY = "TOP", offsetY = 20 },
            CraftingOrder = { anchorX = "RIGHT", offsetX = 20, anchorY = "TOP", offsetY = 38 },
        },
    },
})

-- Apply NativeBarMixin for mouseOver / scale helpers
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local BORDER_COLOR = { r = 0, g = 0, b = 0, a = 1 }
local DEFAULT_SIZE = 200
local CLOCK_UPDATE_INTERVAL = 1
local COORDS_UPDATE_INTERVAL = 0.1
local ZOOM_BUTTON_SIZE = 20
local MISSIONS_BASE_SIZE = 36
local ZOOM_FADE_IN = 0.15
local ZOOM_FADE_OUT = 0.3

-- [ BLIZZARD FRAME REFERENCES ]---------------------------------------------------------------------

local function GetBlizzardMinimap() return Minimap end

local function GetBlizzardCluster() return MinimapCluster end

-- [ BLIZZARD ART STRIPPING ]------------------------------------------------------------------------

local function StripBlizzardArt()
    local cluster = GetBlizzardCluster()
    if not cluster then
        return
    end

    -- Hide the entire cluster frame (takes BorderTop, ZoneTextButton, Tracking, IndicatorFrame, InstanceDifficulty with it)
    OrbitEngine.NativeFrame:Hide(cluster, { unregisterEvents = false, clearScripts = false })

    -- Hide the compass frame / backdrop art that surrounds the minimap render
    if MinimapBackdrop then
        MinimapBackdrop:SetAlpha(0)
    end
    if MinimapCompassTexture then
        MinimapCompassTexture:Hide()
    end

    -- Suppress Blizzard's edit mode selection on the minimap cluster
    if cluster.Selection then
        cluster.Selection:SetAlpha(0)
        cluster.Selection:EnableMouse(false)
    end

    -- Hide Blizzard's native zoom buttons and hover area (we provide our own)
    local minimap = Minimap
    if minimap then
        if minimap.ZoomIn then
            minimap.ZoomIn:Hide()
            minimap.ZoomIn:SetScript("OnShow", minimap.ZoomIn.Hide)
        end
        if minimap.ZoomOut then
            minimap.ZoomOut:Hide()
            minimap.ZoomOut:SetScript("OnShow", minimap.ZoomOut.Hide)
        end
        if minimap.ZoomHitArea then
            minimap.ZoomHitArea:Hide()
            minimap.ZoomHitArea:EnableMouse(false)
        end
    end
end

-- [ ZONE TEXT UPDATER ]-----------------------------------------------------------------------------

local ZONE_PVP_COLORS = {
    sanctuary = { r = 0.41, g = 0.80, b = 0.94 },
    friendly = { r = 0.10, g = 1.00, b = 0.10 },
    hostile = { r = 1.00, g = 0.10, b = 0.10 },
    contested = { r = 1.00, g = 0.70, b = 0.00 },
}

local function UpdateZoneText(button, coloring, overrides)
    local fontString = button.Text or button
    fontString:SetText(GetMinimapZoneText())
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
    -- Resize the button to match text extents so tooltip/click area is accurate
    if button.Text then
        button:SetSize(fontString:GetStringWidth() + 2, fontString:GetStringHeight() + 2)
    end
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------

function Plugin:OnLoad()
    -- Register canvas mode preview atlases for minimap components
    Orbit.IconPreviewAtlases = Orbit.IconPreviewAtlases or {}
    Orbit.IconPreviewAtlases.Zoom = "common-icon-zoomin"
    Orbit.IconPreviewAtlases.Difficulty = "UI-HUD-UnitFrame-Player-PVP-FFAIcon"
    Orbit.IconPreviewAtlases.Missions = "GarrLanding-MinimapIcon-Horde-Up"
    Orbit.IconPreviewAtlases.Mail = "ui-hud-minimap-mail-up"
    Orbit.IconPreviewAtlases.CraftingOrder = "UI-HUD-Minimap-CraftingOrder-Up"

    -- Create orbit container
    self.frame = CreateFrame("Frame", "OrbitMinimapContainer", UIParent)
    self.frame:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
    self.frame:SetClampedToScreen(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Minimap"

    -- Anchor options for edit mode drag
    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
        syncScale = false,
        syncDimensions = false,
    }

    -- Default position (top right, similar to Blizzard default)
    self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)

    -- Background
    self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.bg:SetAllPoints(self.frame)
    self.frame.bg:SetColorTexture(0, 0, 0, 1)

    -- Overlay for canvas components (sits above the minimap render but below DIALOG strata)
    self.frame.Overlay = CreateFrame("Frame", nil, self.frame)
    self.frame.Overlay:SetAllPoints()
    self.frame.Overlay:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    -- MiniMapMailFrameMixin and MiniMapCraftingOrderFrameMixin call self:GetParent():Layout()
    -- after UPDATE_PENDING_MAIL / CRAFTINGORDERS_UPDATED events. Since we reparent those
    -- frames here, we provide a no-op to prevent the error.
    self.frame.Overlay.Layout = function() end

    -- [ Zone Text component ] — clickable: opens World Map, tooltip shows zone/subzone/PvP info
    self.frame.ZoneText = CreateFrame("Button", "OrbitMinimapZoneText", self.frame.Overlay)
    self.frame.ZoneText:SetSize(1, 1) -- sized dynamically from text width
    self.frame.ZoneText:SetPoint("CENTER", self.frame, "TOP", 0, -4)

    self.frame.ZoneText.Text = self.frame.ZoneText:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.ZoneText.Text:SetAllPoints()
    self.frame.ZoneText.visual = self.frame.ZoneText.Text -- canvas override target

    self.frame.ZoneText:SetScript("OnClick", function() ToggleWorldMap() end)
    self.frame.ZoneText:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM")
        local zone = GetZoneText() or ""
        local subzone = GetSubZoneText() or ""
        GameTooltip:SetText(zone, 1, 1, 1)
        if subzone ~= "" and subzone ~= zone then
            GameTooltip:AddLine(subzone, 0.9, 0.9, 0.9)
        end
        local pvpType, _, factionName = GetZonePVPInfo()
        if pvpType and pvpType ~= "" then
            local color = ZONE_PVP_COLORS[pvpType] or { r = 1, g = 1, b = 1 }
            local label = pvpType:sub(1, 1):upper() .. pvpType:sub(2)
            if factionName and factionName ~= "" then
                GameTooltip:AddLine(label .. " (" .. factionName .. ")", color.r, color.g, color.b)
            else
                GameTooltip:AddLine(label, color.r, color.g, color.b)
            end
        end
        GameTooltip:AddLine("Click to open World Map", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    self.frame.ZoneText:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- [ Clock component ] — clickable: left = time manager, right = calendar
    self.frame.Clock = CreateFrame("Button", "OrbitMinimapClock", self.frame.Overlay)
    self.frame.Clock:SetSize(1, 1) -- sized dynamically from text width
    self.frame.Clock:SetPoint("CENTER", self.frame, "BOTTOM", 0, 4)
    self.frame.Clock:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    self.frame.Clock.Text = self.frame.Clock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.Clock.Text:SetAllPoints()
    self.frame.Clock.visual = self.frame.Clock.Text -- canvas override target

    -- Pending calendar invites glow (attached to clock since calendar opens from here)
    self.frame.Clock.InviteGlow = self.frame.Clock:CreateTexture(nil, "BACKGROUND")
    self.frame.Clock.InviteGlow:SetAllPoints()
    self.frame.Clock.InviteGlow:SetColorTexture(1, 0.82, 0, 0.35)
    self.frame.Clock.InviteGlow:Hide()

    self.frame.Clock:SetScript("OnClick", function(btn, button)
        if button == "RightButton" then
            ToggleCalendar()
        else
            TimeManager_Toggle()
        end
    end)
    self.frame.Clock:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText(TIMEMANAGER_TITLE or "Clock", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Time Manager", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: Calendar", 0.7, 0.7, 0.7)
        local pending = C_Calendar.GetNumPendingInvites and C_Calendar.GetNumPendingInvites() or 0
        if pending > 0 then
            GameTooltip:AddLine(string.format("%d pending calendar invite(s)", pending), 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    self.frame.Clock:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Orbit.EventBus:On("CALENDAR_UPDATE_PENDING_INVITES", function() self:UpdateCalendarInvites() end, self)

    -- [ Coords component ]
    self.frame.Coords = self.frame.Overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.Coords:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -4, 4)
    self.frame.Coords:SetJustifyH("RIGHT")

    -- [ Compartment component ]
    self:CreateCompartmentButton()

    -- [ Zoom component ] — two stacked buttons, shown on minimap hover
    self:CreateZoomButtons()

    -- [ Blizzard reparented components ]
    self:ReparentBlizzardComponents()

    -- Register all canvas components for drag
    local MPC = function(key) return OrbitEngine.ComponentDrag:MakePositionCallback(self, SYSTEM_ID, key) end
    OrbitEngine.ComponentDrag:Attach(self.frame.ZoneText, self.frame,
        { key = "ZoneText", onPositionChange = MPC("ZoneText") })
    OrbitEngine.ComponentDrag:Attach(self.frame.Clock, self.frame, { key = "Clock", onPositionChange = MPC("Clock") })
    OrbitEngine.ComponentDrag:Attach(self.frame.Coords, self.frame, { key = "Coords", onPositionChange = MPC("Coords") })
    OrbitEngine.ComponentDrag:Attach(self._compartmentButton, self.frame,
        { key = "Compartment", onPositionChange = MPC("Compartment") })
    OrbitEngine.ComponentDrag:Attach(self.frame.ZoomContainer, self.frame,
        { key = "Zoom", onPositionChange = MPC("Zoom") })
    if self.frame.Difficulty then
        OrbitEngine.ComponentDrag:Attach(self.frame.Difficulty, self.frame,
            { key = "Difficulty", onPositionChange = MPC("Difficulty") })
    end
    if self.frame.Missions then
        OrbitEngine.ComponentDrag:Attach(self.frame.Missions, self.frame,
            { key = "Missions", onPositionChange = MPC("Missions") })
    end
    if self.frame.Mail then
        OrbitEngine.ComponentDrag:Attach(self.frame.Mail, self.frame, { key = "Mail", onPositionChange = MPC("Mail") })
    end
    if self.frame.CraftingOrder then
        OrbitEngine.ComponentDrag:Attach(self.frame.CraftingOrder, self.frame,
            { key = "CraftingOrder", onPositionChange = MPC("CraftingOrder") })
    end

    -- Register with edit mode
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()

    -- Zone text update events
    local function OnZoneChanged()
        local positions = self:GetSetting(SYSTEM_ID, "ComponentPositions") or {}
        local zoneOverrides = (positions.ZoneText or {}).overrides or {}
        UpdateZoneText(self.frame.ZoneText, self:GetSetting(SYSTEM_ID, "ZoneTextColoring"), zoneOverrides)
    end
    Orbit.EventBus:On("ZONE_CHANGED", OnZoneChanged, self)
    Orbit.EventBus:On("ZONE_CHANGED_INDOORS", OnZoneChanged, self)
    Orbit.EventBus:On("ZONE_CHANGED_NEW_AREA", OnZoneChanged, self)

    -- Reparent Blizzard's minimap into our container
    self:CaptureBlizzardMinimap()

    -- Check for pending calendar invites at login
    self:UpdateCalendarInvites()
end

-- [ CLOCK UPDATER ]---------------------------------------------------------------------------------

function Plugin:UpdateClock()
    if not self.frame or not self.frame.Clock then
        return
    end
    local text = self.frame.Clock.Text
    if GetCVarBool("timeMgrUseLocalTime") then
        text:SetText(GameTime_GetLocalTime(GetCVarBool("timeMgrUseMilitaryTime")))
    else
        text:SetText(GameTime_GetGameTime(GetCVarBool("timeMgrUseMilitaryTime")))
    end
    -- Resize button to match text extents so tooltip/click area is accurate
    self.frame.Clock:SetSize(text:GetStringWidth() + 2, text:GetStringHeight() + 2)
end

function Plugin:StartClockTicker()
    if self._clockTicker then
        return
    end
    self._clockTicker = C_Timer.NewTicker(CLOCK_UPDATE_INTERVAL, function() self:UpdateClock() end)
end

function Plugin:StopClockTicker()
    if self._clockTicker then
        self._clockTicker:Cancel()
        self._clockTicker = nil
    end
end

-- [ COORDS UPDATER ]--------------------------------------------------------------------------------

function Plugin:UpdateCoords()
    if not self.frame or not self.frame.Coords then
        return
    end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then
        self.frame.Coords:SetText("")
        return
    end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then
        self.frame.Coords:SetText("")
        return
    end
    local x, y = pos:GetXY()
    self.frame.Coords:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
end

function Plugin:StartCoordsTicker()
    if self._coordsTicker then
        return
    end
    self._coordsTicker = C_Timer.NewTicker(COORDS_UPDATE_INTERVAL, function() self:UpdateCoords() end)
end

function Plugin:StopCoordsTicker()
    if self._coordsTicker then
        self._coordsTicker:Cancel()
        self._coordsTicker = nil
    end
end

-- [ ZOOM BUTTONS ]----------------------------------------------------------------------------------

function Plugin:UpdateZoomState()
    local container = self.frame and self.frame.ZoomContainer
    if not container then
        return
    end
    local minimap = GetBlizzardMinimap()
    if not minimap then
        return
    end
    local zoom = minimap:GetZoom()
    local maxZoom = minimap:GetZoomLevels() - 1

    -- Zoom In: disable at max
    local zoomIn = container.ZoomIn
    if zoomIn then
        local atMax = zoom >= maxZoom
        zoomIn:SetEnabled(not atMax)
        zoomIn:SetAlpha(atMax and 0.35 or 1)
        if zoomIn.icon then
            zoomIn.icon:SetDesaturated(atMax)
        end
    end

    -- Zoom Out: disable at min
    local zoomOut = container.ZoomOut
    if zoomOut then
        local atMin = zoom <= 0
        zoomOut:SetEnabled(not atMin)
        zoomOut:SetAlpha(atMin and 0.35 or 1)
        if zoomOut.icon then
            zoomOut.icon:SetDesaturated(atMin)
        end
    end
end

function Plugin:CreateZoomButtons()
    -- Container holds both buttons so they move as a single unit in canvas mode
    local container = CreateFrame("Frame", nil, self.frame.Overlay)
    container:SetSize(ZOOM_BUTTON_SIZE, ZOOM_BUTTON_SIZE * 2 + 2)
    container:SetPoint("RIGHT", self.frame, "RIGHT", -2, 0)
    self.frame.ZoomContainer = container

    -- Hidden icon for canvas mode dock preview (texture left empty; atlas resolved via IconPreviewAtlases)
    container.Icon = container:CreateTexture(nil, "ARTWORK")
    container.Icon:SetSize(16, 16)
    container.Icon:SetPoint("CENTER")
    container.Icon:SetAlpha(0)

    -- Zoom In
    local zoomIn = CreateFrame("Button", nil, container)
    zoomIn:SetSize(ZOOM_BUTTON_SIZE, ZOOM_BUTTON_SIZE)
    zoomIn:SetPoint("TOP", container, "TOP", 0, 0)
    local zoomInTex = zoomIn:CreateTexture(nil, "ARTWORK")
    zoomInTex:SetAllPoints()
    zoomInTex:SetAtlas("ui-hud-minimap-zoom-in")
    zoomIn.icon = zoomInTex
    zoomIn:SetScript("OnClick", function()
        local minimap = GetBlizzardMinimap()
        if minimap then
            local zoom = minimap:GetZoom()
            if zoom < minimap:GetZoomLevels() - 1 then
                minimap:SetZoom(zoom + 1)
            end
        end
        self:UpdateZoomState()
    end)
    zoomIn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText("Zoom In")
        GameTooltip:Show()
    end)
    zoomIn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    container.ZoomIn = zoomIn

    -- Zoom Out
    local zoomOut = CreateFrame("Button", nil, container)
    zoomOut:SetSize(ZOOM_BUTTON_SIZE, ZOOM_BUTTON_SIZE)
    zoomOut:SetPoint("TOP", zoomIn, "BOTTOM", 0, -2)
    local zoomOutTex = zoomOut:CreateTexture(nil, "ARTWORK")
    zoomOutTex:SetAllPoints()
    zoomOutTex:SetAtlas("ui-hud-minimap-zoom-out")
    zoomOut.icon = zoomOutTex
    zoomOut:SetScript("OnClick", function()
        local minimap = GetBlizzardMinimap()
        if minimap then
            local zoom = minimap:GetZoom()
            if zoom > 0 then
                minimap:SetZoom(zoom - 1)
            end
        end
        self:UpdateZoomState()
    end)
    zoomOut:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:SetText("Zoom Out")
        GameTooltip:Show()
    end)
    zoomOut:SetScript("OnLeave", function() GameTooltip:Hide() end)
    container.ZoomOut = zoomOut

    -- Hover-reveal: show on minimap mouseenter, hide on mouseleave
    container:SetAlpha(0)

    self.frame:HookScript("OnEnter", function()
        if not self:IsComponentDisabled("Zoom") then
            UIFrameFadeIn(container, ZOOM_FADE_IN, container:GetAlpha(), 1)
        end
    end)
    self.frame:HookScript("OnLeave", function()
        if not container:IsMouseOver() then
            UIFrameFadeOut(container, ZOOM_FADE_OUT, container:GetAlpha(), 0)
        end
    end)
    container:SetScript("OnLeave", function(f)
        if not self.frame:IsMouseOver() and not f:IsMouseOver() then
            UIFrameFadeOut(f, ZOOM_FADE_OUT, f:GetAlpha(), 0)
        end
    end)

    -- Also hook the minimap render surface for hover
    local minimap = GetBlizzardMinimap()
    if minimap then
        minimap:HookScript("OnEnter", function()
            if not self:IsComponentDisabled("Zoom") then
                UIFrameFadeIn(container, ZOOM_FADE_IN, container:GetAlpha(), 1)
            end
        end)
        minimap:HookScript("OnLeave", function()
            if not container:IsMouseOver() and not self.frame:IsMouseOver() then
                UIFrameFadeOut(container, ZOOM_FADE_OUT, container:GetAlpha(), 0)
            end
        end)
    end
end

-- [ BLIZZARD COMPONENT REPARENTING ]----------------------------------------------------------------

function Plugin:ReparentBlizzardComponents()
    local overlay = self.frame.Overlay

    -- Instance Difficulty indicator
    local difficulty = MinimapCluster and MinimapCluster.InstanceDifficulty
    if difficulty then
        self._origDifficultyParent = difficulty:GetParent()
        difficulty:SetParent(overlay)
        difficulty:ClearAllPoints()
        difficulty:SetPoint("CENTER", self.frame, "TOPLEFT", 20, -20)
        -- Hidden icon for canvas mode dock preview (texture left empty; atlas resolved via IconPreviewAtlases)
        if not difficulty.Icon then
            difficulty.Icon = difficulty:CreateTexture(nil, "ARTWORK")
            difficulty.Icon:SetSize(16, 16)
            difficulty.Icon:SetPoint("CENTER")
            difficulty.Icon:SetAlpha(0)
        end
        self.frame.Difficulty = difficulty
    end

    -- Expansion Landing Page (Missions) button
    local missions = ExpansionLandingPageMinimapButton
    if missions then
        self._origMissionsParent = missions:GetParent()
        missions:SetParent(overlay)
        missions:ClearAllPoints()
        missions:SetPoint("CENTER", self.frame, "BOTTOMLEFT", 20, 20)
        missions:SetSize(MISSIONS_BASE_SIZE, MISSIONS_BASE_SIZE) -- slightly smaller than default 53×53 to fit minimap
        -- Hidden icon for canvas mode dock preview (texture left empty; atlas resolved via IconPreviewAtlases)
        if not missions.Icon then
            missions.Icon = missions:CreateTexture(nil, "ARTWORK")
            missions.Icon:SetSize(16, 16)
            missions.Icon:SetPoint("CENTER")
            missions.Icon:SetAlpha(0)
        end
        self.frame.Missions = missions
    end

    -- New Mail indicator
    local mail = MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame
    if mail then
        self._origMailParent = mail:GetParent()
        mail:SetParent(overlay)
        mail:ClearAllPoints()
        mail:SetPoint("CENTER", self.frame, "TOPRIGHT", -20, -20)
        -- Hidden icon for canvas mode dock preview (texture left empty; atlas resolved via IconPreviewAtlases)
        if not mail.Icon then
            mail.Icon = mail:CreateTexture(nil, "ARTWORK")
            mail.Icon:SetSize(16, 16)
            mail.Icon:SetPoint("CENTER")
            mail.Icon:SetAlpha(0)
        end
        self.frame.Mail = mail
    end

    -- Crafting Order indicator
    local craftingOrder = MinimapCluster and MinimapCluster.IndicatorFrame and
        MinimapCluster.IndicatorFrame.CraftingOrderFrame
    if craftingOrder then
        self._origCraftingOrderParent = craftingOrder:GetParent()
        craftingOrder:SetParent(overlay)
        craftingOrder:ClearAllPoints()
        craftingOrder:SetPoint("CENTER", self.frame, "TOPRIGHT", -20, -38)
        -- Hidden icon for canvas mode dock preview (texture left empty; atlas resolved via IconPreviewAtlases)
        if not craftingOrder.Icon then
            craftingOrder.Icon = craftingOrder:CreateTexture(nil, "ARTWORK")
            craftingOrder.Icon:SetSize(16, 16)
            craftingOrder.Icon:SetPoint("CENTER")
            craftingOrder.Icon:SetAlpha(0)
        end
        self.frame.CraftingOrder = craftingOrder
    end
end

function Plugin:RestoreBlizzardComponents()
    -- Difficulty
    if self.frame.Difficulty and self._origDifficultyParent then
        self.frame.Difficulty:SetParent(self._origDifficultyParent)
        self.frame.Difficulty:ClearAllPoints()
        self.frame.Difficulty = nil
    end

    -- Missions
    if self.frame.Missions and self._origMissionsParent then
        self.frame.Missions:SetScript("OnShow", nil)
        self.frame.Missions:SetParent(self._origMissionsParent)
        self.frame.Missions:ClearAllPoints()
        self.frame.Missions:SetSize(53, 53) -- restore original size
        self.frame.Missions = nil
    end

    -- Mail
    if self.frame.Mail and self._origMailParent then
        self.frame.Mail:SetScript("OnShow", nil)
        self.frame.Mail:SetParent(self._origMailParent)
        self.frame.Mail:ClearAllPoints()
        self.frame.Mail = nil
    end

    -- Crafting Order
    if self.frame.CraftingOrder and self._origCraftingOrderParent then
        self.frame.CraftingOrder:SetScript("OnShow", nil)
        self.frame.CraftingOrder:SetParent(self._origCraftingOrderParent)
        self.frame.CraftingOrder:ClearAllPoints()
        self.frame.CraftingOrder = nil
    end
end

-- [ CAPTURE ]---------------------------------------------------------------------------------------

function Plugin:CaptureBlizzardMinimap()
    local minimap = GetBlizzardMinimap()
    if not minimap then
        return
    end

    -- Strip all default art/chrome
    StripBlizzardArt()

    -- Reparent the actual render surface into our container
    minimap:SetParent(self.frame)
    minimap:ClearAllPoints()
    minimap:SetAllPoints(self.frame)

    -- Ensure minimap stays interactive
    minimap:EnableMouse(true)
    minimap:SetArchBlobRingScalar(0)
    minimap:SetQuestBlobRingScalar(0)

    -- Apply mask for square clipping
    minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8x8")

    -- Protect against Blizzard trying to re-steal the minimap
    OrbitEngine.FrameGuard:Protect(minimap, self.frame)
    OrbitEngine.FrameGuard:UpdateProtection(minimap, self.frame, function() self:ApplySettings() end,
        { enforceShow = true })

    -- Hook SetPoint to prevent Blizzard from repositioning
    if not minimap._orbitSetPointHooked then
        hooksecurefunc(minimap, "SetPoint", function(f, ...)
            if f._orbitRestoringPoint then
                return
            end
            if f:GetParent() == self.frame then
                local point = ...
                if point ~= "TOPLEFT" or select(2, ...) ~= self.frame then
                    f._orbitRestoringPoint = true
                    local ok, err = pcall(function()
                        f:ClearAllPoints()
                        f:SetAllPoints(self.frame)
                    end)
                    f._orbitRestoringPoint = nil
                    if not ok then
                        print("|cffff0000Orbit Minimap SetPoint guard error:|r", err)
                    end
                end
            end
        end)
        minimap._orbitSetPointHooked = true
    end

    -- Right-click on the minimap opens the tracking menu
    if not minimap._orbitRightClickHooked then
        minimap:SetScript("OnMouseUp", function(f, button)
            if button == "RightButton" then
                local nativeButton = MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button
                if nativeButton and nativeButton.menuGenerator then
                    MenuUtil.CreateContextMenu(f, nativeButton.menuGenerator)
                end
            end
        end)
        minimap._orbitRightClickHooked = true
    end

    -- Update zoom button state after scroll-wheel zoom
    if not minimap._orbitScrollHooked then
        minimap:HookScript("OnMouseWheel", function() self:UpdateZoomState() end)
        minimap._orbitScrollHooked = true
    end

    self._captured = true
end

-- [ APPLY SETTINGS ]--------------------------------------------------------------------------------

local function ApplyIconScale(frame, overrides, baseW)
    if not frame then return end
    local size = overrides and overrides.IconSize
    frame:SetScale((size and baseW and baseW > 0) and (size / baseW) or 1)
end

function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then
        return
    end
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:ApplySettings() end)
        return
    end

    local isEditMode = Orbit:IsEditMode()
    local scale = (self:GetSetting(SYSTEM_ID, "Scale") or 100) / 100
    local size = self:GetSetting(SYSTEM_ID, "Size") or DEFAULT_SIZE
    local zoneTextSize = self:GetSetting(SYSTEM_ID, "ZoneTextSize") or 12
    local borderSize = Orbit.db.GlobalSettings.BorderSize or 2

    -- Scale
    frame:SetScale(scale)

    -- Size (square minimap)
    frame:SetSize(size, size)

    -- Border
    local backdropColor = Orbit.db.GlobalSettings.BackdropColour or { r = 0.145, g = 0.145, b = 0.145, a = 0.7 }
    Orbit.Skin:SkinBorder(frame, frame, borderSize, BORDER_COLOR)

    -- Background
    if frame.bg then
        frame.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a)
    end

    local s = Orbit.db.GlobalSettings.TextScale
    local textMultiplier = s == "Small" and 0.85 or s == "Large" and 1.15 or s == "ExtraLarge" and 1.30 or 1

    local savedPositions = self:GetSetting(SYSTEM_ID, "ComponentPositions") or {}

    -- Zone Text (disabled via Canvas Mode dock)
    if not self:IsComponentDisabled("ZoneText") then
        frame.ZoneText:Show()
        local zoneOverrides = (savedPositions.ZoneText or {}).overrides or {}
        Orbit.Skin:SkinText(frame.ZoneText.Text, {
            font = Orbit.db.GlobalSettings.Font,
            textSize = zoneTextSize * textMultiplier,
        })
        OrbitEngine.OverrideUtils.ApplyOverrides(frame.ZoneText.Text, zoneOverrides, {
            fontSize = zoneTextSize * textMultiplier,
            fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font),
        })
        UpdateZoneText(frame.ZoneText, self:GetSetting(SYSTEM_ID, "ZoneTextColoring"), zoneOverrides)
    else
        frame.ZoneText:Hide()
    end

    -- Clock (disabled via Canvas Mode dock)
    if not self:IsComponentDisabled("Clock") then
        frame.Clock:Show()
        local clockOverrides = (savedPositions.Clock or {}).overrides or {}
        Orbit.Skin:SkinText(frame.Clock.Text, {
            font = Orbit.db.GlobalSettings.Font,
            textSize = (zoneTextSize - 1) * textMultiplier,
        })
        OrbitEngine.OverrideUtils.ApplyOverrides(frame.Clock.Text, clockOverrides, {
            fontSize = (zoneTextSize - 1) * textMultiplier,
            fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font),
        })
        self:StartClockTicker()
        self:UpdateClock()
    else
        self:StopClockTicker()
        frame.Clock:Hide()
    end

    -- Coords (disabled via Canvas Mode dock)
    if not self:IsComponentDisabled("Coords") then
        frame.Coords:Show()
        local coordsOverrides = (savedPositions.Coords or {}).overrides or {}
        Orbit.Skin:SkinText(frame.Coords, {
            font = Orbit.db.GlobalSettings.Font,
            textSize = (zoneTextSize - 1) * textMultiplier,
        })
        OrbitEngine.OverrideUtils.ApplyOverrides(frame.Coords, coordsOverrides, {
            fontSize = (zoneTextSize - 1) * textMultiplier,
            fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font),
        })
        self:StartCoordsTicker()
        self:UpdateCoords()
    else
        self:StopCoordsTicker()
        frame.Coords:Hide()
    end

    -- Zoom buttons (disabled via Canvas Mode dock)
    if frame.ZoomContainer then
        if not self:IsComponentDisabled("Zoom") then
            frame.ZoomContainer:Show()
            ApplyIconScale(frame.ZoomContainer, (savedPositions.Zoom or {}).overrides, ZOOM_BUTTON_SIZE)
            self:UpdateZoomState()
        else
            frame.ZoomContainer:Hide()
        end
    end

    -- Instance Difficulty indicator (disabled via Canvas Mode dock)
    if frame.Difficulty then
        if not self:IsComponentDisabled("Difficulty") then
            frame.Difficulty:Show()
            ApplyIconScale(frame.Difficulty, (savedPositions.Difficulty or {}).overrides, frame.Difficulty:GetWidth())
        else
            frame.Difficulty:Hide()
        end
    end

    -- Missions / Expansion Landing Page button (disabled via Canvas Mode dock)
    if frame.Missions then
        if not self:IsComponentDisabled("Missions") then
            -- Don't force-show; the button has its own visibility logic (hidden when no active expansion feature)
            frame.Missions:SetScript("OnShow", nil)
            ApplyIconScale(frame.Missions, (savedPositions.Missions or {}).overrides, MISSIONS_BASE_SIZE)
        else
            frame.Missions:Hide()
            frame.Missions:SetScript("OnShow", function(f) f:Hide() end)
        end
    end

    -- Mail indicator (disabled via Canvas Mode dock)
    if frame.Mail then
        if not self:IsComponentDisabled("Mail") then
            frame.Mail:SetScript("OnShow", nil)
            ApplyIconScale(frame.Mail, (savedPositions.Mail or {}).overrides, frame.Mail:GetWidth())
        else
            frame.Mail:Hide()
            frame.Mail:SetScript("OnShow", function(f) f:Hide() end)
        end
    end

    -- Crafting Order indicator (disabled via Canvas Mode dock)
    if frame.CraftingOrder then
        if not self:IsComponentDisabled("CraftingOrder") then
            frame.CraftingOrder:SetScript("OnShow", nil)
            ApplyIconScale(frame.CraftingOrder, (savedPositions.CraftingOrder or {}).overrides,
            frame.CraftingOrder:GetWidth())
        else
            frame.CraftingOrder:Hide()
            frame.CraftingOrder:SetScript("OnShow", function(f) f:Hide() end)
        end
    end

    -- Restore component positions from saved variables
    local isInCanvasMode = OrbitEngine.CanvasMode:IsActive(frame)
    if not isInCanvasMode then
        if savedPositions then
            OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions)
        end
    end

    -- Opacity / Mouse-over fade
    self:ApplyMouseOver(frame, SYSTEM_ID)

    -- Restore position from saved variables
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)

    -- Ensure minimap is parented correctly (in case of reload)
    local minimap = GetBlizzardMinimap()
    if minimap and minimap:GetParent() ~= frame then
        self:CaptureBlizzardMinimap()
    end

    -- Show the container
    frame:Show()

    -- Addon compartment
    self:ApplyAddonCompartment()

    -- In edit mode, always full alpha
    if isEditMode then
        frame:SetAlpha(1)
    end
end

-- [ CALENDAR PENDING INVITES ]----------------------------------------------------------------------

function Plugin:UpdateCalendarInvites()
    if not self.frame or not self.frame.Clock then
        return
    end
    local glow = self.frame.Clock.InviteGlow
    if not glow then
        return
    end
    local pending = C_Calendar.GetNumPendingInvites and C_Calendar.GetNumPendingInvites() or 0
    if pending > 0 then
        glow:Show()
    else
        glow:Hide()
    end
end

-- [ TEARDOWN ]--------------------------------------------------------------------------------------
-- Called when the plugin is live-toggled off. Restores Blizzard state and cancels timers.

function Plugin:OnDisable()
    -- Stop tickers
    self:StopClockTicker()
    self:StopCoordsTicker()

    -- Restore collected addon buttons
    self._compartmentActive = false
    self:RestoreCollectedButtons()

    -- Hide our frames
    if self._compartmentFlyout then
        self._compartmentFlyout:Hide()
    end

    -- Restore reparented Blizzard components to their original parents
    self:RestoreBlizzardComponents()

    -- Restore Blizzard minimap to its original parent
    local minimap = GetBlizzardMinimap()
    local cluster = GetBlizzardCluster()
    if minimap and cluster then
        minimap:SetParent(cluster)
        minimap:ClearAllPoints()
        -- Default Blizzard minimap offset within MinimapCluster as of 12.0
        minimap:SetPoint("CENTER", cluster, "CENTER", 9, -1)
    end

    -- Re-show the Blizzard cluster
    if cluster then
        cluster:Show()
    end
end
