---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- Key Bindings panel label for ORBIT_MINIMAP_TOGGLEVIEW (defined in Orbit/Bindings.xml).
-- Header is BINDING_HEADER_ORBIT (set by Spotlight); this binding appears under "Orbit" alongside it.
_G.BINDING_NAME_ORBIT_MINIMAP_TOGGLEVIEW = Orbit.L.PLU_MINIMAP_BINDING_TOGGLE_VIEW

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Minimap"

local Plugin = Orbit:RegisterPlugin("Minimap", SYSTEM_ID, {
    canvasMode = true,
    canvasDefaultZoom = 1.0,
    defaults = {
        View = "minimap",
        Hud_Size = 800,
        Hud_Opacity = 30,
        Hud_Rotate = false,
        Size = 220,
        Shape = "square",
        BorderRing = "none",
        BorderColor = { r = 0, g = 0, b = 0, a = 1 },
        DifficultyDisplay = "icon",
        LeftClickAction = "none",
        RotateMinimap = false,
        MiddleClickAction = "none",
        RightClickAction = "tracking",
        AutoZoomOut = true,
        ZoneTextColoring = true,
        DifficultyShowBackground = false,
        DisabledComponents = { "Status" },
        ComponentPositions = {
            Compartment = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 15, offsetY = -10, posX = 110.0000305175781, posY = -135.0000305175781, justifyH = "RIGHT", selfAnchorY = "BOTTOM" },
            Tracking    = { anchorX = "LEFT",  anchorY = "BOTTOM", offsetX = -15, offsetY = -10, posX = -110.0000305175781, posY = -135.0000305175781, justifyH = "LEFT",  selfAnchorY = "BOTTOM" },
            Zoom = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 15, offsetY = 35, posX = 110.0000305175781, posY = -90.00003051757812, justifyH = "RIGHT", selfAnchorY = "BOTTOM" },
            Missions = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 20, offsetY = 20, posX = -105.0000305175781, posY = -105.0000305175781, justifyH = "CENTER", selfAnchorY = "BOTTOM" },
            Coords = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 30, offsetY = 10, posX = 95.00003051757812, posY = -115.0000305175781, justifyH = "RIGHT", selfAnchorY = "BOTTOM" },
            CraftingOrder = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 20, offsetY = 38, posX = 105.0000305175781, posY = 87.00003051757812, justifyH = "CENTER", selfAnchorY = "TOP" },
            DifficultyIcon = { anchorX = "LEFT", anchorY = "TOP", offsetX = 20, offsetY = 20, posX = -105.0000305175781, posY = 105.0000305175781, justifyH = "LEFT", selfAnchorY = "TOP", overrides = { IconSize = 42 } },
            Mail = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 20, offsetY = 20, posX = 105.0000305175781, posY = 105.0000305175781, justifyH = "CENTER", selfAnchorY = "TOP" },
            DifficultyText = { anchorX = "LEFT", anchorY = "TOP", offsetX = 20, offsetY = 20, posX = -105.0000305175781, posY = 105.0000305175781, justifyH = "LEFT", selfAnchorY = "TOP" },
            Clock = { anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 10, posX = 0, posY = -115.0000305175781, justifyH = "CENTER", selfAnchorY = "BOTTOM" },
            ZoneText = { anchorX = "CENTER", anchorY = "TOP", offsetX = 0, offsetY = 10, posX = 0, posY = 115.0000305175781, justifyH = "CENTER", selfAnchorY = "TOP", overrides = { FontSize = 18 } },
        },
    },
})

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
-- All values sourced from MinimapConstants.lua via Orbit.MinimapConstants.

local C = Orbit.MinimapConstants
local DEFAULT_SIZE = C.DEFAULT_SIZE
local DEFAULT_TEXT_SIZE = C.DEFAULT_TEXT_SIZE
local BORDER_COLOR = C.BORDER_COLOR
local ZOOM_BUTTON_W = C.ZOOM_BUTTON_W
local MISSIONS_BASE_SIZE = C.MISSIONS_BASE_SIZE

local CLICK_ACTION_KEYS = {
    LeftButton = "LeftClickAction",
    MiddleButton = "MiddleClickAction",
    RightButton = "RightClickAction",
}
local DIFFICULTY_ICON_KEY = "DifficultyIcon"
local DIFFICULTY_TEXT_KEY = "DifficultyText"
local DIFFICULTY_COLORS = {
    M = "|cffff4d4dM|r",
    H = "|cff4db8ffH|r",
    N = "|cffffffffN|r",
    LFR = "|cffffd24dLFR|r",
}

local function GetDifficultyTextBounds(fontString)
    if not fontString then return 14, 14 end
    local width = math.floor((fontString:GetStringWidth() or 12) + 2.5)
    local _, fontSize = fontString:GetFont()
    local height = math.floor(((fontSize or fontString:GetStringHeight() or 12)) + 2.5)
    return math.max(width, 1), math.max(height, 1)
end

local function CopyTable(source)
    if type(source) ~= "table" then return source end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CopyTable(value)
    end
    return copy
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    Orbit.IconPreviewAtlases = Orbit.IconPreviewAtlases or {}
    Orbit.IconPreviewAtlases.Zoom = "common-icon-zoomin"
    Orbit.IconPreviewAtlases.Compartment = "Map-Filter-Button"
    Orbit.IconPreviewAtlases.Tracking = "ui-hud-minimap-tracking-up"
    Orbit.IconPreviewAtlases.Difficulty = nil
    Orbit.IconPreviewAtlases.Mail = "ui-hud-minimap-mail-up"
    Orbit.IconPreviewAtlases.CraftingOrder = "UI-HUD-Minimap-CraftingOrder-Over-2x"

    self.frame = CreateFrame("Frame", "OrbitMinimapContainer", UIParent)
    self.frame:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
    OrbitEngine.Pixel:Enforce(self.frame)
    self.frame:SetClampedToScreen(true)
    -- Match Blizzard's MinimapCluster strata so third-party buttons parented to Minimap land where they expect.
    self.frame:SetFrameStrata(Orbit.Constants.Strata.Base)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Minimap"
    -- Edit Mode drag-resize handle. The minimap is square, so square=true locks aspect and drives
    -- the single Size setting; bounds match the Size slider's range (clamped, can't exceed it).
    self.frame.orbitResizeBounds = { minW = C.MIN_SIZE, maxW = C.MAX_SIZE, widthKey = "Size", heightKey = "Size", square = true }

    -- HUD host: surface reparents here while HUD is active so self.frame stays put and FrameAnchor children don't follow.
    self.hudFrame = CreateFrame("Frame", "OrbitMinimapHUD", UIParent)
    self.hudFrame:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
    self.hudFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
    self.hudFrame:SetFrameStrata(Orbit.Constants.Strata.Base)
    self.hudFrame:Hide()
    OrbitEngine.Pixel:Enforce(self.hudFrame)

    self.frame:SetScript("OnSizeChanged", function(f, w, h)
        local minimapSurface = self:GetBlizzardMinimap()
        if minimapSurface and minimapSurface:GetParent() == f then
            local scale = minimapSurface:GetEffectiveScale()
            minimapSurface:SetSize(OrbitEngine.Pixel:Snap(w, scale), OrbitEngine.Pixel:Snap(h, scale))
        end
        -- Re-apply the border ring so it tracks the new container size (Edit Mode drag, slider, etc.).
        if self.ApplyBorderRing then
            self:ApplyBorderRing(self:GetResolvedBorderColor())
        end
    end)

    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
    }

    self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -5, 0)

    self.frame.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.bg:SetAllPoints(self.frame)
    self.frame.bg:SetColorTexture(0, 0, 0, 1)

    -- Overlay shares the container's LOW strata; interactive children raised above ClickCapture via explicit frame levels.
    self.frame.Overlay = CreateFrame("Frame", nil, self.frame)
    self.frame.Overlay:SetAllPoints()
    self.frame.Overlay:SetFrameStrata(Orbit.Constants.Strata.Base)
    self.frame.Overlay:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    -- No-op shim: reparented MiniMapMailFrameMixin/MiniMapCraftingOrderFrameMixin call self:GetParent():Layout() after their events.
    self.frame.Overlay.Layout = function() end

    self.frame.BorderRing = self.frame.Overlay:CreateTexture(nil, "OVERLAY", nil, 7)
    self.frame.BorderRing:Hide()
    OrbitEngine.Pixel:Enforce(self.frame.BorderRing)

    -- Solid-fill ring (BasicMinimap-style): a SetColorTexture backdrop clipped by the same
    -- Orbit_Circle.tga used as the minimap surface mask. Sized to minimap + BorderSize*2 so the
    -- visible "ring" around the masked map matches BorderSize exactly. BACKGROUND of the
    -- container so the captured Minimap surface draws above it.
    self.frame.SolidRing = self.frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    self.frame.SolidRing._mask = self.frame:CreateMaskTexture()
    self.frame.SolidRing._mask:SetTexture(C.MASK_ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    self.frame.SolidRing:AddMaskTexture(self.frame.SolidRing._mask)
    self.frame.SolidRing:Hide()
    OrbitEngine.Pixel:Enforce(self.frame.SolidRing)
    OrbitEngine.Pixel:Enforce(self.frame.SolidRing._mask)

    -- ClickCapture: transparent button covering the minimap at LOW strata; dispatches configured click actions.
    local clickCapture = CreateFrame("Button", "OrbitMinimapClickCapture", self.frame)
    clickCapture:SetAllPoints()
    clickCapture:SetFrameStrata(Orbit.Constants.Strata.Base)
    clickCapture:SetFrameLevel(self.frame:GetFrameLevel() + 50)
    clickCapture:EnableMouse(true)
    clickCapture:RegisterForClicks("AnyUp")
    clickCapture:SetPropagateMouseClicks(true)
    clickCapture:SetPropagateMouseMotion(true) -- pass OnEnter/OnLeave through so tooltips still work
    clickCapture:SetScript("OnClick", function(_, button)
        local action = self:GetMinimapClickAction(button)
        if action ~= "none" then self:RunMinimapClickAction(action, clickCapture) end
    end)
    self.frame.ClickCapture = clickCapture

    -- [ Zone Text component ] — clickable: opens World Map, tooltip shows zone/subzone/PvP info
    self.frame.ZoneText = CreateFrame("Button", "OrbitMinimapZoneText", self.frame.Overlay)
    self.frame.ZoneText:SetSize(1, 1) -- sized dynamically from text width
    OrbitEngine.Pixel:Enforce(self.frame.ZoneText)
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
    OrbitEngine.Pixel:Enforce(self.frame.Clock)
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

    -- Reapply border/ring tint when the user re-pins their class color (class pin only — flat colors are unaffected).
    Orbit.EventBus:On("COLORS_CHANGED", function() if self.frame then self:ApplyShape() end end, self)

    -- [ Coords component ] — wrapper frame holds the FontString so ComponentDrag can move it
    self.frame.Coords = CreateFrame("Frame", nil, self.frame.Overlay)
    self.frame.Coords:SetSize(1, 1) -- sized dynamically from text width on first tick
    OrbitEngine.Pixel:Enforce(self.frame.Coords)
    self.frame.Coords:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -4, 4)
    self.frame.Coords.Text = self.frame.Coords:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.Coords.Text:SetAllPoints()
    self.frame.Coords.Text:SetJustifyH("RIGHT")
    self.frame.Coords.visual = self.frame.Coords.Text -- canvas override target

    -- Raise interactive children above ClickCapture so OnClick fires before the configured action.
    self.frame.ZoneText:SetFrameLevel(clickCapture:GetFrameLevel() + 1)
    self.frame.Clock:SetFrameLevel(clickCapture:GetFrameLevel() + 1)

    -- Mouse-wheel zoom: propagate scroll to the Blizzard minimap zoom buttons.
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnMouseWheel", function(_, delta)
        local minimap = self:GetBlizzardMinimap()
        if not minimap then return end
        if delta > 0 then minimap.ZoomIn:Click() else minimap.ZoomOut:Click() end
    end)

    -- [ Compartment component ]
    self:CreateCompartmentButton()

    -- [ Tracking component ]
    self:CreateTrackingButton()

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
    OrbitEngine.ComponentDrag:Attach(self._compartmentButton, self.frame, {
        key = "Compartment",
        sourceOverride = self._compartmentButton.icon,
        onPositionChange = MPC("Compartment"),
    })
    OrbitEngine.ComponentDrag:Attach(self._trackingButton, self.frame, {
        key = "Tracking",
        sourceOverride = self._trackingButton.icon,
        onPositionChange = MPC("Tracking"),
    })
    OrbitEngine.ComponentDrag:Attach(self.frame.ZoomContainer, self.frame, { key = "Zoom", onPositionChange = MPC("Zoom") })
    if self.frame.DifficultyIcon then OrbitEngine.ComponentDrag:Attach(self.frame.DifficultyIcon, self.frame, { key = DIFFICULTY_ICON_KEY, onPositionChange = MPC(DIFFICULTY_ICON_KEY) }) end
    if self.frame.DifficultyText then
        OrbitEngine.ComponentDrag:Attach(self.frame.DifficultyText, self.frame, {
            key = DIFFICULTY_TEXT_KEY,
            sourceOverride = self.frame.DifficultyText.Text,
            isFontString = true,
            onPositionChange = MPC(DIFFICULTY_TEXT_KEY),
        })
    end
    if self.frame.Missions then OrbitEngine.ComponentDrag:Attach(self.frame.Missions, self.frame, { key = "Missions", onPositionChange = MPC("Missions") }) end
    if self.frame.Mail then OrbitEngine.ComponentDrag:Attach(self.frame.Mail, self.frame, { key = "Mail", onPositionChange = MPC("Mail") }) end
    if self.frame.CraftingOrder then OrbitEngine.ComponentDrag:Attach(self.frame.CraftingOrder, self.frame, { key = "CraftingOrder", onPositionChange = MPC("CraftingOrder") }) end

    -- Register with edit mode
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()

    -- Zone text update events
    local function OnZoneChanged()
        local positions = self:GetSetting(SYSTEM_ID, "ComponentPositions") or {}
        local zoneOverrides = (positions.ZoneText or {}).overrides or {}
        self:UpdateZoneText(self.frame.ZoneText, self:GetSetting(SYSTEM_ID, "ZoneTextColoring"), zoneOverrides)
    end
    Orbit.EventBus:On("ZONE_CHANGED", OnZoneChanged, self)
    Orbit.EventBus:On("ZONE_CHANGED_INDOORS", OnZoneChanged, self)
    Orbit.EventBus:On("ZONE_CHANGED_NEW_AREA", OnZoneChanged, self)

    -- HUD view isn't a positionable edit-mode frame; entering edit mode while in HUD forces minimap view.
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        if (self:GetSetting(SYSTEM_ID, "View") or "minimap") == "hud" then
            self:SetSetting(SYSTEM_ID, "View", "minimap")
            self:ApplySettings()
        end
    end, self)

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

        if shape == "round" or shape == "splatter" then
            local previewMask = shape == "splatter" and C.MASK_HUD or C.MASK_ROUND
            local bgMask = preview:CreateMaskTexture(nil, "BACKGROUND", nil, 0)
            bgMask:SetTexture(previewMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
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

    -- If Blizzard_HybridMinimap is already loaded, ApplyShape will handle it on PLAYER_ENTERING_WORLD.
    -- If it loads later (demand-loaded on first map open), reapply shape so CircleMask is correct.
    -- Force a map tile update after login/reload to ensure the inner graphics scale correctly to the container
    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0.5, function()
            local minimap = self:GetBlizzardMinimap()
            if minimap then
                local w = self.frame:GetWidth()
                local scale = minimap:GetEffectiveScale()
                local snappedW = OrbitEngine.Pixel:Snap(w, scale)
                local bounceW = OrbitEngine.Pixel:Snap(w - 1, scale)
                minimap:SetSize(bounceW, bounceW)
                minimap:SetSize(snappedW, snappedW)
                
                -- Force a mask refresh to flush texture vertices. HUD view is always splatter.
                local view = self:GetSetting(C.SYSTEM_ID, "View") or "minimap"
                local effectiveShape = view == "hud" and "splatter" or (self:GetSetting(C.SYSTEM_ID, "Shape") or "square")
                local mask = effectiveShape ~= "square" and self:GetRoundMaskSource() or C.MASK_SQUARE
                minimap:SetMaskTexture(mask)
                
                -- Global update if available
                if Minimap_Update then Minimap_Update() end
            end
        end)
    end, self)

    if not C_AddOns.IsAddOnLoaded("Blizzard_HybridMinimap") then
        self._hybridLoader = CreateFrame("Frame")
        self._hybridLoader:RegisterEvent("ADDON_LOADED")
        self._hybridLoader:SetScript("OnEvent", function(f, _, addonName)
            if addonName ~= "Blizzard_HybridMinimap" then return end
            f:UnregisterEvent("ADDON_LOADED")
            self:ApplyShape()
        end)
    end
end

local function ApplyIconScale(frame, overrides, baseW)
    if not frame then return end
    local size = overrides and overrides.IconSize
    frame:SetScale((size and baseW and baseW > 0) and (size / baseW) or 1)
end

function Plugin:UsesAddonClickAction()
    for _, settingKey in pairs(CLICK_ACTION_KEYS) do
        if self:GetSetting(SYSTEM_ID, settingKey) == "addons" then
            return true
        end
    end
    return false
end

function Plugin:HasAnyClickAction()
    for _, settingKey in pairs(CLICK_ACTION_KEYS) do
        if self:GetSetting(SYSTEM_ID, settingKey) ~= "none" then
            return true
        end
    end
    return false
end

function Plugin:UsesTrackingClickAction()
    for _, settingKey in pairs(CLICK_ACTION_KEYS) do
        if self:GetSetting(SYSTEM_ID, settingKey) == "tracking" then
            return true
        end
    end
    return false
end

function Plugin:IsCanvasComponentHidden(componentKey)
    if componentKey == DIFFICULTY_ICON_KEY or componentKey == DIFFICULTY_TEXT_KEY then
        return componentKey ~= self:GetActiveDifficultyCanvasKey()
    end
    if componentKey == "Compartment" then return self:UsesAddonClickAction() end
    if componentKey == "Tracking"    then return self:UsesTrackingClickAction() end
    return false
end

function Plugin:IsComponentDisabled(componentKey)
    if componentKey == DIFFICULTY_ICON_KEY or componentKey == DIFFICULTY_TEXT_KEY then
        componentKey = "Difficulty"
    end
    -- HUD view hides all decorative components — it's a clean navigation overlay.
    if (self:GetSetting(SYSTEM_ID, "View") or "minimap") == "hud" then return true end
    if self:IsCanvasComponentHidden(componentKey) then return true end
    return Orbit.PluginMixin.IsComponentDisabled(self, componentKey)
end

function Plugin:GetMinimapClickAction(button)
    local settingKey = CLICK_ACTION_KEYS[button]
    return settingKey and self:GetSetting(SYSTEM_ID, settingKey) or "none"
end

-- Override PluginMixin's VE handler so HUD view is invisible to the Visibility Engine —
-- no mounted-hide, no vehicle/pet-battle alpha override, no opacity setting re-application.
-- Normal Minimap view falls through to the default behavior.
function Plugin:UpdateVisibility()
    if (self:GetSetting(SYSTEM_ID, "View") or "minimap") == "hud" then return end
    return Orbit.PluginMixin.UpdateVisibility(self)
end

-- Hide/show third-party addon minimap buttons (LibDBIcon + legacy minimap-parented buttons).
-- Used by HUD view to keep the overlay clean. State is remembered per-button so we only restore
-- what we actually hid, never force-show a button the user had previously hidden in their addon.
function Plugin:SetAddonIconsShown(shown)
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.objects then
        for _, btn in pairs(lib.objects) do
            if shown then
                if btn._orbitHudHidden then btn:Show(); btn._orbitHudHidden = nil end
            elseif btn:IsShown() then
                btn._orbitHudHidden = true; btn:Hide()
            end
        end
    end
    if Minimap and Minimap.GetChildren then
        for _, child in ipairs({ Minimap:GetChildren() }) do
            local name = child.GetName and child:GetName() or ""
            local isAddonButton = name:match("^LibDBIcon10_") or (child.IsObjectType and child:IsObjectType("Button") and not name:lower():find("^minimap"))
            if isAddonButton then
                if shown then
                    if child._orbitHudHidden then child:Show(); child._orbitHudHidden = nil end
                elseif child:IsShown() then
                    child._orbitHudHidden = true; child:Hide()
                end
            end
        end
    end
end

function Plugin:GetComponentPositions(systemIndex)
    local positions = Orbit.PluginMixin.GetComponentPositions(self, systemIndex) or {}
    local normalized = CopyTable(positions)

    if normalized[DIFFICULTY_ICON_KEY] == nil then
        normalized[DIFFICULTY_ICON_KEY] = CopyTable(self.defaults.ComponentPositions[DIFFICULTY_ICON_KEY])
    end
    if normalized[DIFFICULTY_TEXT_KEY] == nil then
        normalized[DIFFICULTY_TEXT_KEY] = CopyTable(self.defaults.ComponentPositions[DIFFICULTY_TEXT_KEY])
    end

    return normalized
end

function Plugin:GetActiveDifficultyCanvasKey()
    return self:GetDifficultyDisplay() == "text" and DIFFICULTY_TEXT_KEY or DIFFICULTY_ICON_KEY
end

function Plugin:GetDifficultyDisplay()
    local display = self:GetSetting(SYSTEM_ID, "DifficultyDisplay")
    if display ~= nil then return display end
    return "icon"
end

function Plugin:NormalizeCanvasComponentPositions(positions, systemIndex)
    local normalized = self:GetComponentPositions(systemIndex)
    for key, value in pairs(positions or {}) do
        normalized[key] = CopyTable(value)
    end
    return normalized
end

function Plugin:NormalizeCanvasDisabledComponents(keys)
    local normalized, seenDifficulty = {}, false
    for _, key in ipairs(keys or {}) do
        if key == DIFFICULTY_ICON_KEY or key == DIFFICULTY_TEXT_KEY then
            if not seenDifficulty then
                normalized[#normalized + 1] = "Difficulty"
                seenDifficulty = true
            end
        else
            normalized[#normalized + 1] = key
        end
    end
    return normalized
end

function Plugin:GetDifficultyText()
    local _, instanceType, difficultyID, difficultyName, maxPlayers = GetInstanceInfo()
    local difficultyKey = difficultyName and difficultyName:lower() or ""
    local label
    if difficultyKey:find("follower") then
        label = DIFFICULTY_COLORS.N
    elseif difficultyID == 8 or difficultyKey:find("mythic") then
        label = DIFFICULTY_COLORS.M
    elseif difficultyKey:find("heroic") then
        label = DIFFICULTY_COLORS.H
    elseif difficultyKey:find("raid finder") or difficultyKey:find("looking for raid") or difficultyKey:find("lfr") then
        label = DIFFICULTY_COLORS.LFR
    elseif difficultyKey:find("normal") then
        label = DIFFICULTY_COLORS.N
    end
    if label then
        local size = type(maxPlayers) == "number" and maxPlayers > 0 and tostring(maxPlayers) or ""
        if instanceType == "party" or instanceType == "raid" or size ~= "" then
            return size .. label
        end
        return label
    end
    return difficultyName or ""
end

function Plugin:UpdateDifficultyVisuals(textMultiplier)
    local difficulty = self.frame and self.frame.Difficulty
    local iconFrame = self.frame and self.frame.DifficultyIcon
    local textFrame = self.frame and self.frame.DifficultyText
    if not (difficulty and iconFrame and textFrame) then return end
    if textMultiplier == nil then
        local scaleSetting = Orbit.db.GlobalSettings.TextScale
        textMultiplier = scaleSetting == "Small" and 0.85 or scaleSetting == "Large" and 1.15 or scaleSetting == "ExtraLarge" and 1.30 or 1
    end

    local positions = self:GetComponentPositions(SYSTEM_ID)
    local iconOverrides = (positions[DIFFICULTY_ICON_KEY] or {}).overrides or {}
    local textOverrides = (positions[DIFFICULTY_TEXT_KEY] or {}).overrides or {}
    local mode = self:GetDifficultyDisplay()
    local showBg = self:GetSetting(SYSTEM_ID, "DifficultyShowBackground")
    local keepVisible = Orbit:IsEditMode() or OrbitEngine.CanvasMode:IsActive(self.frame)

    local text = self:GetDifficultyText()
    if text == "" and keepVisible then text = "5" .. DIFFICULTY_COLORS.N end
    textFrame.orbitDifficultyText = text

    for _, sub in ipairs({ difficulty.Default, difficulty.Guild, difficulty.ChallengeMode }) do
        if sub then
            local alpha = mode == "icon" and 1 or 0
            sub:SetAlpha(alpha)
            if sub.Background then sub.Background:SetAlpha(alpha > 0 and showBg and 1 or 0) end
            if sub.Border then sub.Border:SetAlpha(alpha > 0 and showBg and 1 or 0) end
        end
    end

    if not iconFrame.PreviewIcon then
        iconFrame.PreviewIcon = iconFrame:CreateTexture(nil, "OVERLAY")
        -- Use the 25 player difficulty skull
        iconFrame.PreviewIcon:SetTexture("Interface\\Minimap\\UI-DungeonDifficulty-Button")
        iconFrame.PreviewIcon:SetTexCoord(0.5, 0.75, 0.0703125, 0.4140625)
        iconFrame.PreviewIcon:SetSize(18, 18)
        iconFrame.PreviewIcon:SetPoint("CENTER", iconFrame, "CENTER", 0.5, 0.5)
    end
    if not iconFrame.PreviewText then
        iconFrame.PreviewText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        iconFrame.PreviewText:SetText("25")
        iconFrame.PreviewText:SetPoint("TOP", iconFrame.PreviewIcon, "BOTTOM", -1, 4)
    end

    local realIconShown = false
    if difficulty:IsShown() or mode == "icon" then
        for _, sub in ipairs({ difficulty.Default, difficulty.Guild, difficulty.ChallengeMode }) do
            if sub and sub:IsShown() then
                for _, region in ipairs({ sub:GetRegions() }) do
                    if region and region:GetObjectType() == "Texture" and region:IsShown() and region ~= sub.Background and region ~= sub.Border then
                        realIconShown = true
                        break
                    end
                end
            end
        end
    end

    if keepVisible and not realIconShown and mode == "icon" then
        iconFrame.PreviewIcon:Show()
        iconFrame.PreviewText:Show()
    else
        iconFrame.PreviewIcon:Hide()
        iconFrame.PreviewText:Hide()
    end

    iconFrame.orbitOriginalWidth = difficulty.orbitOriginalWidth or iconFrame.orbitOriginalWidth or 16
    iconFrame.orbitOriginalHeight = difficulty.orbitOriginalHeight or iconFrame.orbitOriginalHeight or 16
    iconFrame:SetScale(1)
    iconFrame:SetSize(iconFrame.orbitOriginalWidth, iconFrame.orbitOriginalHeight)
    ApplyIconScale(iconFrame, iconOverrides, iconFrame.orbitOriginalWidth)

    Orbit.Skin:SkinText(textFrame.Text, {
        font = Orbit.db.GlobalSettings.Font,
        textSize = DEFAULT_TEXT_SIZE * (textMultiplier or 1),
    })
    OrbitEngine.OverrideUtils.ApplyOverrides(textFrame.Text, textOverrides, {
        fontSize = DEFAULT_TEXT_SIZE * (textMultiplier or 1),
        fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font),
    })
    textFrame.Text:SetText(text)
    textFrame.Text:SetShown(text ~= "")
    textFrame.orbitOriginalWidth, textFrame.orbitOriginalHeight = GetDifficultyTextBounds(textFrame.Text)
    textFrame:SetSize(textFrame.orbitOriginalWidth, textFrame.orbitOriginalHeight)

    iconFrame:SetShown(mode == "icon")
    difficulty:SetShown(mode == "icon")
    textFrame:SetShown(mode == "text")
end

function Plugin:ApplySettings()
    local frame = self.frame
    if InCombatLockdown() then Orbit.CombatManager:QueueUpdate(function() self:ApplySettings() end); return end
    if self._applyingSettings then return end
    self._applyingSettings = true

    local isEditMode = Orbit:IsEditMode()
    local view = self:GetSetting(SYSTEM_ID, "View") or "minimap"
    local isHud = view == "hud"

    local minimapSize = self:GetSetting(SYSTEM_ID, "Size") or DEFAULT_SIZE
    local hudSize = self:GetSetting(SYSTEM_ID, "Hud_Size") or 800
    local size = isHud and hudSize or minimapSize
    local surfaceParent = isHud and self.hudFrame or self.frame

    -- self.frame always reflects its saved size; hudFrame only sizes when active.
    frame:SetSize(minimapSize, minimapSize)
    if isHud then self.hudFrame:SetSize(hudSize, hudSize) end
    if isEditMode then OrbitEngine.FrameSelection:ForceUpdate(frame) end

    -- Rotate minimap. HUD has its own toggle; in minimap view only round/splatter shapes can rotate.
    local rotate
    if isHud then
        rotate = self:GetSetting(SYSTEM_ID, "Hud_Rotate") and true or false
    else
        local shape = self:GetSetting(SYSTEM_ID, "Shape") or "square"
        rotate = (shape == "round" or shape == "splatter") and self:GetSetting(SYSTEM_ID, "RotateMinimap") and true or false
    end
    SetCVar("rotateMinimap", rotate and "1" or "0")

    -- Reparent + size the Minimap surface to whichever host is active. FarmHud owns it while open.
    local minimapSurface = self:GetBlizzardMinimap()
    if minimapSurface and not self._farmHudActive then
        if minimapSurface:GetParent() ~= surfaceParent then
            OrbitEngine.FrameGuard:UpdateProtection(minimapSurface, surfaceParent, function() self:ApplySettings() end, { enforceShow = true })
            minimapSurface:SetParent(surfaceParent)
        end
        local surfaceScale = minimapSurface:GetEffectiveScale()
        local snappedSize = OrbitEngine.Pixel:Snap(size, surfaceScale)
        local bounceSize = OrbitEngine.Pixel:Snap(size - 1, surfaceScale)
        minimapSurface._orbitIntendedSize = snappedSize
        minimapSurface:SetSize(bounceSize, bounceSize)
        minimapSurface:SetSize(snappedSize, snappedSize)
        minimapSurface:ClearAllPoints()
        minimapSurface:SetPoint("CENTER", surfaceParent, "CENTER", 0, 0)
    end

    -- Shape + Border
    self:ApplyShape()

    -- Background. Suppressed in round/splatter/HUD — ApplyShape already hid the bg so the masked
    -- surface sits over the game world cleanly without a square backdrop bleeding through.
    local shape = self:GetSetting(SYSTEM_ID, "Shape") or "square"
    if frame.bg and shape == "square" and not isHud then
        local backdropColor = Orbit.db.GlobalSettings.BackdropColour or { r = 0.145, g = 0.145, b = 0.145, a = 0.7 }
        frame.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a)
    end

    local s = Orbit.db.GlobalSettings.TextScale
    local textMultiplier = s == "Small" and 0.85 or s == "Large" and 1.15 or s == "ExtraLarge" and 1.30 or 1

    local savedPositions = self:GetComponentPositions(SYSTEM_ID) or {}

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

    -- Instance Difficulty components (disabled via Canvas Mode dock)
    if frame.Difficulty and frame.DifficultyIcon and frame.DifficultyText then
        if not self:IsComponentDisabled("Difficulty") then
            self:UpdateDifficultyVisuals(textMultiplier)
            OrbitEngine.ComponentDrag:RestoreFramePositions(frame, {
                [DIFFICULTY_ICON_KEY] = savedPositions[DIFFICULTY_ICON_KEY],
                [DIFFICULTY_TEXT_KEY] = savedPositions[DIFFICULTY_TEXT_KEY],
            })
        else
            frame.Difficulty:Hide()
            frame.DifficultyIcon:Hide()
            frame.DifficultyText:Hide()
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

    -- Position: hudFrame is centered (non-movable); self.frame restores its saved position regardless of view.
    self.hudFrame:ClearAllPoints()
    self.hudFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)

    -- Force-perturb zoom so the C++ terrain renderer re-scales after a view swap even if the target == current zoom.
    local function SetZoomWithRefresh(m, target)
        if not (m and m.SetZoom and m.GetZoom and m.GetZoomLevels) then return end
        local maxZ = m:GetZoomLevels() - 1
        local bump = target < maxZ and target + 1 or target - 1
        m:SetZoom(bump)
        m:SetZoom(target)
    end

    -- View swap: hudFrame hosts surface + opacity; self.frame stays in place but hidden when HUD is on.
    if isHud then
        if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RemoveOOCFade(frame) end
        local opacity = (self:GetSetting(SYSTEM_ID, "Hud_Opacity") or 30) / 100
        self.hudFrame:SetAlpha(opacity)
        self.hudFrame:EnableMouse(false)
        self.hudFrame:EnableMouseWheel(false)
        if minimapSurface then
            self._preHudZoom = minimapSurface.GetZoom and minimapSurface:GetZoom() or nil
            SetZoomWithRefresh(minimapSurface, 0)
            minimapSurface:EnableMouse(false)
            minimapSurface:EnableMouseWheel(false)
        end
        self.frame:Hide()
        self.hudFrame:Show()
        self:SetAddonIconsShown(false)
    else
        if minimapSurface then
            if self._preHudZoom then SetZoomWithRefresh(minimapSurface, self._preHudZoom); self._preHudZoom = nil end
            minimapSurface:EnableMouse(true)
            minimapSurface:EnableMouseWheel(true)
        end
        self.hudFrame:Hide()
        self.frame:Show()
        self:SetAddonIconsShown(true)
    end

    -- Re-capture if the surface ended up outside our two hosts (e.g. lost on reload). FarmHud is its own.
    local minimap = self:GetBlizzardMinimap()
    local currentParent = minimap and minimap:GetParent()
    if minimap and currentParent ~= self.frame and currentParent ~= self.hudFrame and not self._farmHudActive then
        self:CaptureBlizzardMinimap()
    end

    -- ClickCapture: only intercept mouse clicks when at least one action is configured.
    if frame.ClickCapture then
        frame.ClickCapture:EnableMouse(self:HasAnyClickAction())
    end

    -- Addon compartment (debounced to avoid C stack overrides during sliders)
    if self._compartmentTimer then self._compartmentTimer:Cancel() end
    self._compartmentTimer = C_Timer.NewTimer(0.2, function()
        self:ApplyAddonCompartment()
        self:ApplyTrackingButton()
    end)

    -- Visibility Engine integration (opacity, OOC fade, mounted, mouseover).
    -- Skipped in HUD view — the OOC fade hooks SetAlpha and overrides our Hud_Opacity slider.
    if Orbit.OOCFadeMixin and not isHud then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, SYSTEM_ID) end

    self._applyingSettings = nil
end

-- [ VIEW TOGGLE ]------------------------------------------------------------------------------------
-- Hotkey-driven swap between the normal Minimap layout and the centered HUD overlay.
-- Debounced (0.3s) so rapid mashing doesn't cause overlapping ApplySettings calls and the position/size
-- jitter that produces.
function Plugin:ToggleView()
    if InCombatLockdown() then Orbit.CombatManager:QueueUpdate(function() self:ToggleView() end); return end
    if self._viewToggleDebounce then return end
    self._viewToggleDebounce = true
    C_Timer.After(0.3, function() self._viewToggleDebounce = nil end)
    local current = self:GetSetting(SYSTEM_ID, "View") or "minimap"
    self:SetSetting(SYSTEM_ID, "View", current == "hud" and "minimap" or "hud")
    self:ApplySettings()
end

-- [ TEARDOWN ]---------------------------------------------------------------------------------------
function Plugin:OnDisable()
    -- Toggling the Minimap plugin requires a UI reload (Blizzard hooks cannot be cleanly undone).
    -- The reload button in the Plugin Manager handles this; nothing to do at runtime.
end
