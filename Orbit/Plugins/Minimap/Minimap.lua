---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Minimap"

local Plugin = Orbit:RegisterPlugin("Minimap", SYSTEM_ID, {
    canvasMode = true,
    defaults = {
        Opacity = 100,
        Size = 200,
        Shape = "square",
        BorderColor = { r = 0, g = 0, b = 0, a = 1 },
        RotateMinimap = false,
        MiddleClickAction = "none",
        AutoZoomOutDelay = 5,
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

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
-- All values sourced from MinimapConstants.lua via Orbit.MinimapConstants.

local C = Orbit.MinimapConstants
local DEFAULT_SIZE = C.DEFAULT_SIZE
local DEFAULT_TEXT_SIZE = C.DEFAULT_TEXT_SIZE
local BORDER_COLOR = C.BORDER_COLOR
local ZOOM_BUTTON_W = C.ZOOM_BUTTON_W
local MISSIONS_BASE_SIZE = C.MISSIONS_BASE_SIZE
local BORDER_RING_ATLAS = C.BORDER_RING_ATLAS

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------

function Plugin:OnLoad()
    Orbit.IconPreviewAtlases = Orbit.IconPreviewAtlases or {}
    Orbit.IconPreviewAtlases.Zoom = "common-icon-zoomin"
    Orbit.IconPreviewAtlases.Difficulty = "ui-hud-minimap-guildbanner-normal-large"
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

    -- Round border ring (visible only when Shape = "round").
    -- Drawn on the OVERLAY layer so it sits above the minimap render surface.
    self.frame.RoundBorder = self.frame:CreateTexture(nil, "OVERLAY", nil, 7)
    self.frame.RoundBorder:SetAtlas(BORDER_RING_ATLAS, true)
    self.frame.RoundBorder:SetAllPoints(self.frame)
    self.frame.RoundBorder:Hide()

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
            local color = self.ZonePVPColors and self.ZonePVPColors[pvpType] or { r = 1, g = 1, b = 1 }
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

    -- [ Coords component ] — wrapper frame holds the FontString so ComponentDrag can move it
    self.frame.Coords = CreateFrame("Frame", nil, self.frame.Overlay)
    self.frame.Coords:SetSize(1, 1) -- sized dynamically from text width on first tick
    self.frame.Coords:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -4, 4)
    self.frame.Coords.Text = self.frame.Coords:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.Coords.Text:SetAllPoints()
    self.frame.Coords.Text:SetJustifyH("RIGHT")
    self.frame.Coords.visual = self.frame.Coords.Text -- canvas override target

    -- [ Compartment component ]
    self:CreateCompartmentButton()

    -- [ Zoom component ] — two stacked buttons, shown on minimap hover
    self:CreateZoomButtons()

    -- [ Blizzard reparented components ]
    self:ReparentBlizzardComponents()

    -- Register all canvas components for drag
    local MPC = function(key) return OrbitEngine.ComponentDrag:MakePositionCallback(self, SYSTEM_ID, key) end
    OrbitEngine.ComponentDrag:Attach(self.frame.ZoneText, self.frame, { key = "ZoneText", sourceOverride = self.frame.ZoneText.Text, isFontString = true, onPositionChange = MPC("ZoneText") })
    OrbitEngine.ComponentDrag:Attach(self.frame.Clock, self.frame, { key = "Clock", sourceOverride = self.frame.Clock.Text, isFontString = true, onPositionChange = MPC("Clock") })
    OrbitEngine.ComponentDrag:Attach(self.frame.Coords, self.frame, {
        key = "Coords",
        sourceOverride = self.frame.Coords.Text,
        isFontString = true,
        onPositionChange = MPC("Coords"),
    })
    OrbitEngine.ComponentDrag:Attach(self._compartmentButton, self.frame, { key = "Compartment", onPositionChange = MPC("Compartment") })
    OrbitEngine.ComponentDrag:Attach(self.frame.ZoomContainer, self.frame, { key = "Zoom", onPositionChange = MPC("Zoom") })
    if self.frame.Difficulty then OrbitEngine.ComponentDrag:Attach(self.frame.Difficulty, self.frame, { key = "Difficulty", onPositionChange = MPC("Difficulty") }) end
    if self.frame.Missions then OrbitEngine.ComponentDrag:Attach(self.frame.Missions, self.frame, { key = "Missions", onPositionChange = MPC("Missions") }) end
    if self.frame.Mail then OrbitEngine.ComponentDrag:Attach(self.frame.Mail, self.frame, { key = "Mail", onPositionChange = MPC("Mail") }) end
    if self.frame.CraftingOrder then OrbitEngine.ComponentDrag:Attach(self.frame.CraftingOrder, self.frame, { key = "CraftingOrder", onPositionChange = MPC("CraftingOrder") }) end

    -- Register with edit mode
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()

    -- Zone text update events
    local function OnZoneChanged()
        local positions = self:GetSetting(SYSTEM_ID, "ComponentPositions") or {}
        local zoneOverrides = (positions.ZoneText or {}).overrides or {}
        self:UpdateZoneText(self.frame.ZoneText, self:GetSetting(SYSTEM_ID, "ZoneTextColoring"), zoneOverrides)
    end
    Orbit.EventBus:On("ZONE_CHANGED", OnZoneChanged, self)
    Orbit.EventBus:On("ZONE_CHANGED_INDOORS", OnZoneChanged, self)
    Orbit.EventBus:On("ZONE_CHANGED_NEW_AREA", OnZoneChanged, self)

    -- Canvas preview: renders a live snapshot of the minimap container for the canvas viewport.
    -- The real live frames (ZoneText, Clock, Coords, icons) are already children of self.frame
    -- and are registered as draggable components — so the canvas dialog picks them up directly.
    -- We only need to provide the bg preview frame and seed live data into text components.
    self.frame.CreateCanvasPreview = function(frame, options)
        options = options or {}
        local parent = options.parent or UIParent
        local w = frame:GetWidth()
        local h = frame:GetHeight()
        local shape = self:GetSetting(SYSTEM_ID, "Shape") or "square"
        local borderSize = Orbit.db.GlobalSettings.BorderSize or 2
        local bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 1 }

        local preview = CreateFrame("Frame", nil, parent)
        preview:SetFrameLevel(parent:GetFrameLevel() + 5)
        preview:SetSize(w, h)
        preview:SetPoint("CENTER", parent, "CENTER", 0, 0)
        preview.sourceFrame = frame
        preview.sourceWidth = w
        preview.sourceHeight = h
        preview.previewScale = 1
        preview.components = {}

        -- Dark bg texture matching the live minimap backdrop
        preview.bg = preview:CreateTexture(nil, "BACKGROUND", nil, 1)
        preview.bg:SetAllPoints()
        preview.bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)

        if shape == "round" then
            local bgMask = preview:CreateMaskTexture(nil, "BACKGROUND", nil, 0)
            bgMask:SetTexture(MASK_ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            bgMask:SetAllPoints(preview.bg)
            preview.bg:AddMaskTexture(bgMask)
        end

        -- Seed live data into text components so they show real content in the canvas viewport
        local positions = self:GetSetting(SYSTEM_ID, "ComponentPositions") or {}
        self:UpdateZoneText(frame.ZoneText, self:GetSetting(SYSTEM_ID, "ZoneTextColoring"), (positions.ZoneText or {}).overrides or {})
        self:UpdateClock()
        self:UpdateCoords()

        return preview
    end

    self:CaptureBlizzardMinimap()
    self:UpdateCalendarInvites()
end

local function ApplyIconScale(frame, overrides, baseW)
    if not frame then return end
    local size = overrides and overrides.IconSize
    frame:SetScale((size and baseW and baseW > 0) and (size / baseW) or 1)
end

function Plugin:ApplySettings()
    local frame = self.frame
    if InCombatLockdown() then Orbit.CombatManager:QueueUpdate(function() self:ApplySettings() end); return end
    if self._applyingSettings then return end
    self._applyingSettings = true

    local isEditMode = Orbit:IsEditMode()
    local size = self:GetSetting(SYSTEM_ID, "Size") or DEFAULT_SIZE
    local borderSize = Orbit.db.GlobalSettings.BorderSize or 2

    -- Size (square minimap)
    frame:SetSize(size, size)
    -- Sync the edit mode selection overlay to the new size immediately
    if isEditMode then OrbitEngine.FrameSelection:ForceUpdate(frame) end

    -- Rotate minimap
    local rotate = self:GetSetting(SYSTEM_ID, "RotateMinimap") and true or false
    SetCVar("rotateMinimap", rotate and "1" or "0")

    -- Keep the Minimap render surface in sync with the container.
    -- When rotating in square mode the map turns inside the square: expand the surface to
    -- size * sqrt(2) so the full rotated map always fills all four corners of the square.
    local minimapSurface = self:GetBlizzardMinimap()
    if minimapSurface and minimapSurface:GetParent() == frame then
        local shape = self:GetSetting(SYSTEM_ID, "Shape") or "square"
        local surfaceSize = (rotate and shape == "square") and math.ceil(size * 1.4143) or size
        minimapSurface:SetSize(surfaceSize, surfaceSize)
    end

    -- Shape + Border
    self:ApplyShape()

    -- Background
    local backdropColor = Orbit.db.GlobalSettings.BackdropColour or { r = 0.145, g = 0.145, b = 0.145, a = 0.7 }
    if frame.bg then frame.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a) end

    local s = Orbit.db.GlobalSettings.TextScale
    local textMultiplier = s == "Small" and 0.85 or s == "Large" and 1.15 or s == "ExtraLarge" and 1.30 or 1

    local savedPositions = self:GetSetting(SYSTEM_ID, "ComponentPositions") or {}

    -- Zone Text (disabled via Canvas Mode dock)
    if not self:IsComponentDisabled("ZoneText") then
        frame.ZoneText:Show()
        local zoneOverrides = (savedPositions.ZoneText or {}).overrides or {}
        Orbit.Skin:SkinText(frame.ZoneText.Text, {
            font = Orbit.db.GlobalSettings.Font,
            textSize = DEFAULT_TEXT_SIZE * textMultiplier,
        })
        OrbitEngine.OverrideUtils.ApplyOverrides(frame.ZoneText.Text, zoneOverrides, {
            fontSize = DEFAULT_TEXT_SIZE * textMultiplier,
            fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font),
        })
        self:UpdateZoneText(frame.ZoneText, self:GetSetting(SYSTEM_ID, "ZoneTextColoring"), zoneOverrides)
    else
        frame.ZoneText:Hide()
    end

    -- Clock (disabled via Canvas Mode dock)
    if not self:IsComponentDisabled("Clock") then
        frame.Clock:Show()
        local clockOverrides = (savedPositions.Clock or {}).overrides or {}
        Orbit.Skin:SkinText(frame.Clock.Text, {
            font = Orbit.db.GlobalSettings.Font,
            textSize = (DEFAULT_TEXT_SIZE - 1) * textMultiplier,
        })
        OrbitEngine.OverrideUtils.ApplyOverrides(frame.Clock.Text, clockOverrides, {
            fontSize = (DEFAULT_TEXT_SIZE - 1) * textMultiplier,
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
        local coordsText = frame.Coords.Text
        Orbit.Skin:SkinText(coordsText, {
            font = Orbit.db.GlobalSettings.Font,
            textSize = (DEFAULT_TEXT_SIZE - 1) * textMultiplier,
        })
        OrbitEngine.OverrideUtils.ApplyOverrides(coordsText, coordsOverrides, {
            fontSize = (DEFAULT_TEXT_SIZE - 1) * textMultiplier,
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
            ApplyIconScale(frame.ZoomContainer, (savedPositions.Zoom or {}).overrides, ZOOM_BUTTON_W)
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
            ApplyIconScale(frame.CraftingOrder, (savedPositions.CraftingOrder or {}).overrides, frame.CraftingOrder:GetWidth())
        else
            frame.CraftingOrder:Hide()
            frame.CraftingOrder:SetScript("OnShow", function(f) f:Hide() end)
        end
    end

    -- Restore component positions from saved variables
    local isInCanvasMode = OrbitEngine.CanvasMode:IsActive(frame)
    if not isInCanvasMode then
        if savedPositions then OrbitEngine.ComponentDrag:RestoreFramePositions(frame, savedPositions) end
    end

    -- Opacity / Mouse-over fade
    local baseAlpha = (self:GetSetting(SYSTEM_ID, "Opacity") or 100) / 100
    Orbit.Animation:ApplyHoverFade(frame, baseAlpha, 1, Orbit:IsEditMode())

    -- Restore position from saved variables
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)

    -- Ensure minimap is captured (e.g. after reload).
    local minimap = self:GetBlizzardMinimap()
    if minimap and minimap:GetParent() ~= frame then
        self:CaptureBlizzardMinimap()
    end

    -- Show the container
    frame:Show()

    -- Addon compartment
    self:ApplyAddonCompartment()

    -- In edit mode, always full alpha
    if isEditMode then frame:SetAlpha(1) end
    self._applyingSettings = nil
end

-- [ TEARDOWN ]--------------------------------------------------------------------------------------

function Plugin:OnDisable()
    -- Toggling the Minimap plugin requires a UI reload (Blizzard hooks cannot be cleanly undone).
    -- The reload button in the Plugin Manager handles this; nothing to do at runtime.
end
