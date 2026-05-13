-- RaidPanel.lua: Plugin root — registration, dock frame, layout, events, lifecycle.

local _, Orbit = ...
local L = Orbit.L
local OrbitEngine = Orbit.Engine

local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local math_min = math.min
local math_max = math.max

-- [ PLUGIN REGISTRATION ] ---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_RaidPanel"

local Plugin = Orbit:RegisterPlugin("Raid Panel", SYSTEM_ID, {
    defaults = {
        IconSize     = 24,
        Spacing      = 5,
        DisplayMode  = 3,
        DisplayShape = 1,
        Compactness  = 0,
        FadeEffect   = 0,
        Position     = { y = 0, x = 200, point = "LEFT" },
        Anchor       = false,
    },
})

-- [ DISPLAY MODE CONSTANTS ] ------------------------------------------------------------------------
local DISPLAY_HIDE    = 1
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
local BACKDROP_FALLBACK_R     = 0.145
local BACKDROP_FALLBACK_G     = 0.145
local BACKDROP_FALLBACK_B     = 0.145
local BACKDROP_FALLBACK_A     = 0.7

-- [ STATE ] -----------------------------------------------------------------------------------------
local dock
local icons = {}
local currentOrientation = "LEFT"
local ctx = { isEditModeActive = false, pendingRefresh = false }

local function GetActiveSlots()
    local PD = Orbit.RaidPanelData
    local mode = Plugin:GetSetting(1, "DisplayMode") or DISPLAY_ALL
    if mode == DISPLAY_MARKERS then
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
local function DetectOrientation()
    if not dock then return "LEFT" end
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    local cx = dock:GetLeft() + (dock:GetWidth() / 2)
    local cy = dock:GetBottom() + (dock:GetHeight() / 2)
    local distLeft, distRight = cx, sw - cx
    local distTop, distBottom = sh - cy, cy
    local m = math_min(distLeft, distRight, distTop, distBottom)
    if m == distLeft then return "LEFT" end
    if m == distRight then return "RIGHT" end
    if m == distTop then return "TOP" end
    return "BOTTOM"
end

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
    local fadeAmount  = Plugin:GetSetting(1, "FadeEffect") or 0

    currentOrientation = DetectOrientation()
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
        icon:SetAlpha(Layout.EdgeAlphaForIndex(i - 1, count, fadeAmount))
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
        local c = Orbit.db.GlobalSettings.BackdropColour
        dock.backdrop:SetVertexColor(
            c and c.r or BACKDROP_FALLBACK_R,
            c and c.g or BACKDROP_FALLBACK_G,
            c and c.b or BACKDROP_FALLBACK_B,
            c and c.a or BACKDROP_FALLBACK_A)
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
    dock.editModeName = "Raid Panel"
    dock.systemIndex = 1
    dock.orbitNoSnap = true
    return dock
end

-- [ HIDDEN CHAIN BUTTON ] ---------------------------------------------------------------------------
local function CreateClearTargetsChainButton()
    local btn = CreateFrame("Button", "OrbitRaidPanelClearTargets", UIParent, "SecureActionButtonTemplate")
    btn:Hide()
    btn:SetAttribute("type", "raidtarget")
    btn:SetAttribute("action", "clear-all")
    return btn
end

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function Plugin:OnLoad()
    ctx.isEditModeActive = Orbit:IsEditMode() or false
    dock = CreateDock()
    self.frame = dock
    self.clearTargetsBtn = CreateClearTargetsChainButton()

    OrbitEngine.NativeFrame:Park(CompactRaidFrameManager)

    Orbit.OOCFadeMixin:ApplyOOCFade(dock, self, 1)

    OrbitEngine.Frame:AttachSettingsListener(dock, self, 1)
    OrbitEngine.Frame:RegisterOrientationCallback(dock, function(orientation)
        if currentOrientation == orientation then return end
        currentOrientation = orientation
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
        EventRegistry:RegisterCallback("EditMode.Enter", function() self:UpdateVisibility() end, self)
        EventRegistry:RegisterCallback("EditMode.Exit",  function() self:UpdateVisibility() end, self)
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
    local userWantsShow = mode ~= DISPLAY_HIDE and Orbit.RaidPanelVisibility.ShouldShow()
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
        EventRegistry:UnregisterCallback("EditMode.Enter", self)
        EventRegistry:UnregisterCallback("EditMode.Exit", self)
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
    [DISPLAY_HIDE]    = L.PLU_RAIDPANEL_DISPLAY_HIDE,
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
    table.insert(schema.controls, {
        type = "slider", key = "FadeEffect", label = L.PLU_PORTAL_FADE_EFFECT,
        min = 0, max = 100, step = 5, default = 0,
        formatter = function(v) return v == 0 and L.PLU_PORTAL_FADE_OFF or L.PLU_PORTAL_FADE_PCT_F:format(v) end,
    })
    table.insert(schema.controls, { type = "slider", key = "IconSize",    label = L.PLU_PORTAL_ICON_SIZE,    min = 15, max = 30,  step = 1, default = 24 })
    table.insert(schema.controls, { type = "slider", key = "Spacing",     label = L.PLU_PORTAL_ICON_PADDING, min = 0,  max = 20,  step = 1, default = 5  })
    table.insert(schema.controls, { type = "slider", key = "Compactness", label = L.PLU_PORTAL_COMPACTNESS,  min = 0,  max = 100, step = 1, default = 0  })
    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end
