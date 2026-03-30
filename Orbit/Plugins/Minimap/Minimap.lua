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
        Size = 220,
        Shape = "square",
        BorderColor = { r = 0, g = 0, b = 0, a = 1 },
        DifficultyDisplay = "icon",
        LeftClickAction = "none",
        RotateMinimap = false,
        MiddleClickAction = "none",
        RightClickAction = "tracking",
        AutoZoomOutDelay = 5,
        ZoneTextColoring = true,
        DifficultyShowBackground = false,
        DisabledComponents = { "Status" },
        ComponentPositions = {
            Compartment = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 15, offsetY = -10, posX = 110.0000305175781, posY = -135.0000305175781, justifyH = "RIGHT", selfAnchorY = "BOTTOM" },
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

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
-- All values sourced from MinimapConstants.lua via Orbit.MinimapConstants.

local C = Orbit.MinimapConstants
local DEFAULT_SIZE = C.DEFAULT_SIZE
local DEFAULT_TEXT_SIZE = C.DEFAULT_TEXT_SIZE
local BORDER_COLOR = C.BORDER_COLOR
local ZOOM_BUTTON_W = C.ZOOM_BUTTON_W
local MISSIONS_BASE_SIZE = C.MISSIONS_BASE_SIZE
local BORDER_RING_ATLAS = C.BORDER_RING_ATLAS

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

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------

function Plugin:OnLoad()
    Orbit.IconPreviewAtlases = Orbit.IconPreviewAtlases or {}
    Orbit.IconPreviewAtlases.Zoom = "common-icon-zoomin"
    Orbit.IconPreviewAtlases.Difficulty = nil
    Orbit.IconPreviewAtlases.Mail = "ui-hud-minimap-mail-up"
    Orbit.IconPreviewAtlases.CraftingOrder = "UI-HUD-Minimap-CraftingOrder-Over-2x"

    -- Create orbit container
    self.frame = CreateFrame("Frame", "OrbitMinimapContainer", UIParent)
    self.frame:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
    self.frame:SetClampedToScreen(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Minimap"
    
    self.frame:SetScript("OnSizeChanged", function(f, w, h)
        local minimapSurface = self:GetBlizzardMinimap()
        if minimapSurface and minimapSurface:GetParent() == f then
            minimapSurface:SetSize(w, h)
        end
    end)

    -- Anchor options for edit mode drag
    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
        syncScale = false,
        syncDimensions = false,
    }

    -- Default position
    self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -5, 0)

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

    -- Overlay for canvas components. Uses HIGH strata so our interactive children
    -- (ZoneText, Clock, zoom buttons, etc.) always take priority over ClickCapture
    -- (MEDIUM) and any external addon overlay that might sit over the minimap.
    self.frame.Overlay = CreateFrame("Frame", nil, self.frame)
    self.frame.Overlay:SetAllPoints()
    self.frame.Overlay:SetFrameStrata("HIGH")
    self.frame.Overlay:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    -- MiniMapMailFrameMixin and MiniMapCraftingOrderFrameMixin call self:GetParent():Layout()
    -- after UPDATE_PENDING_MAIL / CRAFTINGORDERS_UPDATED events. Since we reparent those
    -- frames here, we provide a no-op to prevent the error.
    self.frame.Overlay.Layout = function() end

    -- Top-level click-capture button: sits above everything (including third-party addon
    -- overlays) and intercepts all mouse clicks to dispatch our configured actions.
    -- SetPropagateMouseClicks(true) ensures clicks also fall through to whatever is
    -- underneath, so addon overlays (e.g. a "disable minimap" blackout) can still
    -- receive the same click and dismiss themselves normally.
    -- ClickCapture: a transparent MEDIUM-strata button that covers the whole minimap
    -- area. It sits above the minimap render surface and most third-party addon overlays
    -- (which are typically MEDIUM or LOW), but below our own HIGH-strata Overlay so
    -- ZoneText, Clock, zoom buttons etc. always take priority.
    -- SetPropagateMouseClicks(true) ensures the click also falls through to whatever is
    -- underneath, so addon overlays can still receive and dismiss themselves.
    local clickCapture = CreateFrame("Button", "OrbitMinimapClickCapture", self.frame)
    clickCapture:SetAllPoints()
    clickCapture:SetFrameStrata("MEDIUM")
    clickCapture:SetFrameLevel(self.frame:GetFrameLevel() + 50)
    clickCapture:EnableMouse(true)
    clickCapture:RegisterForClicks("AnyUp")
    clickCapture:SetPropagateMouseClicks(true)
    clickCapture:SetScript("OnClick", function(_, button)
        local action = self:GetMinimapClickAction(button)
        if action ~= "none" then self:RunMinimapClickAction(action, clickCapture) end
    end)
    self.frame.ClickCapture = clickCapture

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

    -- Mouse-wheel zoom: propagate scroll to the Blizzard minimap zoom buttons.
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnMouseWheel", function(_, delta)
        local minimap = self:GetBlizzardMinimap()
        if not minimap then return end
        if delta > 0 then minimap.ZoomIn:Click() else minimap.ZoomOut:Click() end
    end)

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

    -- If Blizzard_HybridMinimap is already loaded, ApplyShape will handle it on PLAYER_ENTERING_WORLD.
    -- If it loads later (demand-loaded on first map open), reapply shape so CircleMask is correct.
    -- Force a map tile update after login/reload to ensure the inner graphics scale correctly to the container
    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0.5, function()
            local minimap = self:GetBlizzardMinimap()
            if minimap then
                local w = self.frame:GetWidth()
                minimap._orbitRestoringPoint = true
                -- Force a micro-resize to trigger internal C++ redraw boundary allocation
                minimap:SetSize(w - 1, w - 1)
                minimap:SetSize(w, w)
                minimap._orbitRestoringPoint = nil
                
                -- Force a mask refresh to flush texture vertices
                local mask = self:GetSetting(C.SYSTEM_ID, "Shape") == "round" and C.MASK_ROUND or C.MASK_SQUARE
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

function Plugin:IsCanvasComponentHidden(componentKey)
    if componentKey == DIFFICULTY_ICON_KEY or componentKey == DIFFICULTY_TEXT_KEY then
        return componentKey ~= self:GetActiveDifficultyCanvasKey()
    end
    return componentKey == "Compartment" and self:UsesAddonClickAction()
end

function Plugin:IsComponentDisabled(componentKey)
    if componentKey == DIFFICULTY_ICON_KEY or componentKey == DIFFICULTY_TEXT_KEY then
        componentKey = "Difficulty"
    end
    if self:IsCanvasComponentHidden(componentKey) then return true end
    return Orbit.PluginMixin.IsComponentDisabled(self, componentKey)
end

function Plugin:GetMinimapClickAction(button)
    local settingKey = CLICK_ACTION_KEYS[button]
    return settingKey and self:GetSetting(SYSTEM_ID, settingKey) or "none"
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
    local size = self:GetSetting(SYSTEM_ID, "Size") or DEFAULT_SIZE
    local borderSize = Orbit.db.GlobalSettings.BorderSize or 2

    -- Size (square minimap)
    frame:SetSize(size, size)
    -- Sync the edit mode selection overlay to the new size immediately
    if isEditMode then OrbitEngine.FrameSelection:ForceUpdate(frame) end

    -- Rotate minimap
    local shape = self:GetSetting(SYSTEM_ID, "Shape") or "square"
    local rotate = self:GetSetting(SYSTEM_ID, "RotateMinimap") and true or false
    if shape == "square" then rotate = false end -- Disable rotation for square maps
    SetCVar("rotateMinimap", rotate and "1" or "0")

    -- Keep the Minimap render surface in sync with the container.
    local minimapSurface = self:GetBlizzardMinimap()
    if minimapSurface then
        minimapSurface._orbitIntendedSize = size
        -- Micro-size bounce for C++ redraw
        minimapSurface:SetSize(size - 1, size - 1)
        minimapSurface:SetSize(size, size)
        minimapSurface:ClearAllPoints()
        minimapSurface:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end

    -- Shape + Border
    self:ApplyShape()

    -- Background
    local backdropColor = Orbit.db.GlobalSettings.BackdropColour or { r = 0.145, g = 0.145, b = 0.145, a = 0.7 }
    if frame.bg then frame.bg:SetColorTexture(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a) end

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

    -- Opacity / Mouse-over fade
    local baseAlpha = (self:GetSetting(SYSTEM_ID, "Opacity") or 100) / 100
    local isEditMode = Orbit:IsEditMode()
    Orbit.Animation:ApplyHoverFade(frame, baseAlpha, 1, isEditMode)
    if isEditMode then frame:SetAlpha(baseAlpha) end

    -- Restore position from saved variables
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)

    -- Ensure minimap is captured (e.g. after reload).
    local minimap = self:GetBlizzardMinimap()
    if minimap and minimap:GetParent() ~= frame then
        self:CaptureBlizzardMinimap()
    end

    -- Show the container
    frame:Show()

    -- Addon compartment (debounced to avoid C stack overrides during sliders)
    if self._compartmentTimer then self._compartmentTimer:Cancel() end
    self._compartmentTimer = C_Timer.NewTimer(0.2, function()
        self:ApplyAddonCompartment()
    end)

    self._applyingSettings = nil
end

-- [ TEARDOWN ]--------------------------------------------------------------------------------------

function Plugin:OnDisable()
    -- Toggling the Minimap plugin requires a UI reload (Blizzard hooks cannot be cleanly undone).
    -- The reload button in the Plugin Manager handles this; nothing to do at runtime.
end
