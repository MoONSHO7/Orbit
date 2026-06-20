-- RaidPanel.lua: Plugin root — registration, dock frame, layout, events, lifecycle.

local _, Orbit = ...
local L = Orbit.L
local OrbitEngine = Orbit.Engine

local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local math_max = math.max

-- [ PLUGIN REGISTRATION ] ---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_RaidPanel"

local Plugin = Orbit:RegisterPlugin("Raid Panel", SYSTEM_ID, {
    displayName = L.PLG_NAME_RAID_PANEL,
    defaults = {
        IconSize     = 24,
        Spacing      = 5,
        DisplayMode  = 3,
        DisplayShape = 1,
        Compactness  = 0,
    },
})

-- [ DISPLAY MODE CONSTANTS ] ------------------------------------------------------------------------
local DISPLAY_ALWAYS  = 1
local DISPLAY_MARKERS = 2
local DISPLAY_ALL     = 3

local SHAPE_CIRCLE = 1
local SHAPE_SQUARE = 2

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local INITIAL_DOCK_WIDTH      = 44
local INITIAL_DOCK_HEIGHT     = 400
local INITIAL_DOCK_X_OFFSET   = 200
local DOCK_FRAME_LEVEL        = 100
local DOCK_FRAME_STRATA       = "MEDIUM"
local CLAMP_VISIBLE_MARGIN    = 30
local DOCK_THICKNESS_PAD      = 2
local EDIT_MODE_PREVIEW_OWNER = "OrbitRaidPanelEditModePreview"

-- [ STATE ] -----------------------------------------------------------------------------------------
local dock
local icons = {}
local currentOrientation = "LEFT"
local ctx = { isEditModeActive = false, pendingRefresh = false }

local function GetActiveSlots()
    local PD = Orbit.RaidPanelData
    local mode = Plugin:GetSetting(1, "DisplayMode") or DISPLAY_ALL
    local markersOnly = mode == DISPLAY_MARKERS
        or (mode == DISPLAY_ALWAYS and not Orbit.RaidPanelVisibility.IsRaidLeaderTier())
    if markersOnly then
        local filtered = {}
        for _, key in ipairs(PD.SLOT_ORDER) do
            if key == "CLEAR_MARKERS" or key:sub(1, 7) == "MARKER_" then
                table.insert(filtered, key)
            end
        end
        return filtered
    end
    return PD.SLOT_ORDER
end

-- [ ORIENTATION ] -----------------------------------------------------------------------------------

local function IsHorizontal()
    return currentOrientation == "TOP" or currentOrientation == "BOTTOM"
end

local function PositionIcon(icon, axial, arcOffset, iconSize)
    icon:ClearAllPoints()
    local halfIcon = iconSize / 2
    local scale = icon:GetEffectiveScale()
    local w, h = icon:GetSize()
    local SnapPosition = OrbitEngine.Pixel.SnapPosition
    if currentOrientation == "LEFT" then
        local x, y = SnapPosition(OrbitEngine.Pixel, halfIcon + arcOffset, -axial, "CENTER", w, h, scale)
        icon:SetPoint("CENTER", dock, "TOPLEFT", x, y)
    elseif currentOrientation == "RIGHT" then
        local x, y = SnapPosition(OrbitEngine.Pixel, -halfIcon - arcOffset, -axial, "CENTER", w, h, scale)
        icon:SetPoint("CENTER", dock, "TOPRIGHT", x, y)
    elseif currentOrientation == "TOP" then
        local x, y = SnapPosition(OrbitEngine.Pixel, axial, -halfIcon - arcOffset, "CENTER", w, h, scale)
        icon:SetPoint("CENTER", dock, "TOPLEFT", x, y)
    else
        local x, y = SnapPosition(OrbitEngine.Pixel, axial, halfIcon + arcOffset, "CENTER", w, h, scale)
        icon:SetPoint("CENTER", dock, "BOTTOMLEFT", x, y)
    end
end

-- [ REFRESH ] ---------------------------------------------------------------------------------------
local function RefreshDock()
    if not dock then return end
    if InCombatLockdown() then ctx.pendingRefresh = true; return end

    ctx.isEditModeActive = Orbit:IsEditMode()
    local PD = Orbit.RaidPanelData
    local IconModule = Orbit.RaidPanelIcon
    local Layout = Orbit.RaidPanelLayout
    local baseSize    = Plugin:GetSetting(1, "IconSize")
    local spacing     = Plugin:GetSetting(1, "Spacing")
    local compactness = (Plugin:GetSetting(1, "Compactness") or 0) / 100

    currentOrientation = OrbitEngine.FrameOrientation:DetectOrientation(dock)
    local activeSlots = GetActiveSlots()
    local count = #activeSlots

    local sizes = {}
    for i = 1, count do sizes[i] = baseSize end

    local shape = Plugin:GetSetting(1, "DisplayShape") or SHAPE_CIRCLE
    ctx.mergeBorders = shape == SHAPE_SQUARE and spacing == 0

    local axialPositions, arcOffsets, totalAxial, perpExtent = Layout.ComputeLayout(sizes, spacing, compactness)

    for i, slotKey in ipairs(activeSlots) do
        local icon = icons[i]
        if not icon then
            icon = IconModule.Create(Plugin, dock, ctx)
            icons[i] = icon
        end
        IconModule.Configure(Plugin, icon, PD.SLOTS[slotKey], ctx, baseSize)
        PositionIcon(icon, axialPositions[i], arcOffsets[i], baseSize)
        icon:Show()
    end

    for i = count + 1, #icons do
        local extra = icons[i]
        if extra then extra:Hide(); extra:ClearAllPoints() end
    end

    local thicknessPad = ctx.mergeBorders and 0 or DOCK_THICKNESS_PAD
    local dockLength = math_max(totalAxial, baseSize)
    local dockThickness = baseSize + perpExtent + thicknessPad

    if IsHorizontal() then
        dock:SetWidth(dockLength); dock:SetHeight(dockThickness)
    else
        dock:SetWidth(dockThickness); dock:SetHeight(dockLength)
    end

    local marginX = math_max(0, dock:GetWidth() - CLAMP_VISIBLE_MARGIN)
    local marginY = math_max(0, dock:GetHeight() - CLAMP_VISIBLE_MARGIN)
    dock:SetClampRectInsets(marginX, -marginX, -marginY, marginY)

    if ctx.mergeBorders then
        Orbit.Skin:ApplyIconGroupBorder(dock, Orbit.Skin:GetActiveIconBorderStyle())
    else
        Orbit.Skin:ClearIconGroupBorder(dock)
    end

    if ctx.mergeBorders then
        local c = Orbit.Skin:GetBackgroundColor()
        dock.backdrop:SetVertexColor(c.r, c.g, c.b, c.a)
        dock.backdrop:Show()
    else
        dock.backdrop:Hide()
    end
end

-- [ DOCK CREATION ] ---------------------------------------------------------------------------------
local function CreateDock()
    dock = CreateFrame("Frame", "OrbitRaidPanel", UIParent)
    dock:SetSize(INITIAL_DOCK_WIDTH, INITIAL_DOCK_HEIGHT)
    dock:SetPoint("LEFT", UIParent, "LEFT", INITIAL_DOCK_X_OFFSET, 0)
    OrbitEngine.Pixel:Enforce(dock)

    dock.backdrop = dock:CreateTexture(nil, "BACKGROUND")
    dock.backdrop:SetAllPoints()
    dock.backdrop:SetTexture("Interface\\Buttons\\WHITE8x8")
    dock.backdrop:Hide()

    dock:SetFrameStrata(DOCK_FRAME_STRATA)
    dock:SetFrameLevel(DOCK_FRAME_LEVEL)
    dock:SetClampedToScreen(true)
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    dock:SetClampRectInsets(sw, -sw, -sh, sh)
    dock:EnableMouse(true)
    dock:SetMovable(true)
    dock:RegisterForDrag("LeftButton")
    dock.orbitAutoOrient = true
    -- file-local function, not a Plugin method — use the Plugin upvalue directly (self would be nil here).
    dock.editModeName = Plugin.displayName
    dock.systemIndex = 1
    return dock
end

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function Plugin:OnLoad()
    ctx.isEditModeActive = Orbit:IsEditMode() or false
    dock = CreateDock()
    self.frame = dock

    OrbitEngine.NativeFrame:Park(CompactRaidFrameManager)

    Orbit.OOCFadeMixin:ApplyOOCFade(dock, self, 1)

    OrbitEngine.Frame:AttachSettingsListener(dock, self, 1)
    OrbitEngine.Frame:RegisterOrientationCallback(dock, function(orientation)
        if currentOrientation == orientation then return end
        -- RefreshDock re-resolves currentOrientation via DetectOrientation; no manual write needed.
        RefreshDock()
    end)
    OrbitEngine.Frame:RestorePosition(dock, self, 1)

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if ctx.pendingRefresh then ctx.pendingRefresh = false; RefreshDock() end
            self:UpdateVisibility()
        elseif event == "PLAYER_DIFFICULTY_CHANGED" then
            RefreshDock()
        else
            self:UpdateVisibility()
        end
    end)

    if EventRegistry then
        -- Unique owner so RegisterStandardEvents' (event, self) ApplySettings callbacks don't clobber these.
        EventRegistry:RegisterCallback("EditMode.Enter", function() self:UpdateVisibility() end, EDIT_MODE_PREVIEW_OWNER)
        EventRegistry:RegisterCallback("EditMode.Exit",  function() self:UpdateVisibility() end, EDIT_MODE_PREVIEW_OWNER)
    end

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    self:UpdateVisibility()
end

function Plugin:UpdateVisibility()
    if not dock then return end
    if InCombatLockdown() then ctx.pendingRefresh = true; return end
    ctx.isEditModeActive = Orbit:IsEditMode()
    local mode = Plugin:GetSetting(1, "DisplayMode") or DISPLAY_ALL
    local userWantsShow = mode == DISPLAY_ALWAYS or Orbit.RaidPanelVisibility.ShouldShow()
    if ctx.isEditModeActive or userWantsShow then
        dock:Show()
        RefreshDock()
    else
        dock:Hide()
    end
end

function Plugin:ApplySettings()
    if not dock then return end
    self:UpdateVisibility()
end

function Plugin:OnDisable()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end
    if EventRegistry then
        EventRegistry:UnregisterCallback("EditMode.Enter", EDIT_MODE_PREVIEW_OWNER)
        EventRegistry:UnregisterCallback("EditMode.Exit", EDIT_MODE_PREVIEW_OWNER)
    end
    OrbitEngine.NativeFrame:Unpark(CompactRaidFrameManager)
    -- Reset module-level state so re-enable (without /reload) builds a fresh dock.
    if dock then dock:Hide() end
    for _, icon in ipairs(icons) do icon:Hide(); icon:ClearAllPoints() end
    dock = nil
    icons = {}
    currentOrientation = "LEFT"
    ctx.isEditModeActive = false
    ctx.pendingRefresh = false
    ctx.mergeBorders = nil
end

-- [ SETTINGS UI ] -----------------------------------------------------------------------------------
local DISPLAY_LABELS = {
    [DISPLAY_ALWAYS]  = L.PLU_RAIDPANEL_DISPLAY_ALWAYS,
    [DISPLAY_MARKERS] = L.PLU_RAIDPANEL_DISPLAY_MARKERS,
    [DISPLAY_ALL]     = L.PLU_RAIDPANEL_DISPLAY_ALL,
}

local SHAPE_LABELS = {
    [SHAPE_CIRCLE] = L.PLU_RAIDPANEL_SHAPE_CIRCLE,
    [SHAPE_SQUARE] = L.PLU_RAIDPANEL_SHAPE_SQUARE,
}

function Plugin:AddSettings(dialog, systemFrame)
    local schema = { controls = {} }
    table.insert(schema.controls, {
        type = "slider", key = "DisplayShape", label = L.PLU_RAIDPANEL_SHAPE,
        min = 1, max = 2, step = 1, default = SHAPE_CIRCLE,
        formatter = function(v) return SHAPE_LABELS[v] or "" end,
    })
    table.insert(schema.controls, {
        type = "slider", key = "DisplayMode", label = L.PLU_RAIDPANEL_DISPLAY,
        min = 1, max = 3, step = 1, default = DISPLAY_ALL,
        formatter = function(v) return DISPLAY_LABELS[v] or "" end,
    })
    table.insert(schema.controls, { type = "slider", key = "IconSize",    label = L.PLU_PORTAL_ICON_SIZE,    min = 15, max = 30,  step = 1, default = 24 })
    table.insert(schema.controls, { type = "slider", key = "Spacing",     label = L.PLU_PORTAL_ICON_PADDING, min = 0,  max = 20,  step = 1, default = 5  })
    table.insert(schema.controls, { type = "slider", key = "Compactness", label = L.PLU_PORTAL_COMPACTNESS,  min = 0,  max = 100, step = 1, default = 0  })
    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
