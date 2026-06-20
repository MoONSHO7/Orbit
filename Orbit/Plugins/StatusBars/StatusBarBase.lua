---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Pixel = Orbit.Engine.Pixel
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local FALLBACK_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local OVERLAY_FRAME_OFFSET = 1
local BAR_FRAME_OFFSET = 2
local TEXT_FRAME_OFFSET_LEVEL = Constants.Levels.Overlay

local COMP_KEY_NAME = "Name"
local COMP_KEY_LEVEL = "BarLevel"
local COMP_KEY_VALUE = "BarValue"

-- [ CANVAS MODE COMPONENT SCHEMAS ]------------------------------------------------------------------
-- `plugin = true` on ValueMode routes the dropdown write to `plugin:SetSetting` instead of the canvas blob.
do
    local Schema = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.SettingsSchema
    if Schema and Schema.KEY_SCHEMAS then
        Schema.KEY_SCHEMAS[COMP_KEY_LEVEL] = { controls = {
            { type = "font", key = "Font", label = L.CMN_FONT },
            { type = "slider", key = "FontSize", label = L.CMN_SIZE, min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = L.CMN_COLOR, singleColor = true },
        } }
        Schema.KEY_SCHEMAS[COMP_KEY_VALUE] = { controls = {
            { type = "dropdown", key = "ValueMode", label = L.PLU_SB_VALUE, plugin = true,
              options = {
                  { text = L.PLU_SB_VAL_PERCENT,   value = "percent" },
                  { text = L.PLU_SB_VAL_CURMAX,    value = "currentmax" },
                  { text = L.PLU_SB_VAL_REMAINING, value = "tolevel" },
                  { text = L.PLU_SB_VAL_PERHOUR,   value = "perhour" },
                  { text = L.PLU_SB_VAL_ETA,       value = "eta" },
              }, default = "percent" },
            { type = "font", key = "Font", label = L.CMN_FONT },
            { type = "slider", key = "FontSize", label = L.CMN_SIZE, min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = L.CMN_COLOR, singleColor = true },
        } }
    end
end

-- [ STATUS BAR BASE ]--------------------------------------------------------------------------------
---@class OrbitStatusBarBase
Orbit.StatusBarBase = {}
local StatusBarBase = Orbit.StatusBarBase

StatusBarBase.ComponentKeys = { Name = COMP_KEY_NAME, Level = COMP_KEY_LEVEL, Value = COMP_KEY_VALUE }

local VALUE_MODE_TEMPLATES = {
    percent    = "{pct}",
    currentmax = "{cur}/{max}",
    tolevel    = "{tolevel}",
    perhour    = "{perhour}/hr",
    eta        = "{eta}",
}

function StatusBarBase:ResolveTemplate(plugin, systemIndex)
    local mode = plugin:GetSetting(systemIndex, "ValueMode") or "percent"
    return VALUE_MODE_TEMPLATES[mode] or VALUE_MODE_TEMPLATES.percent
end

function StatusBarBase:Create(globalName, parent)
    local container = CreateFrame("Frame", globalName, parent or UIParent)
    Pixel:Enforce(container)
    container:SetClampedToScreen(true)

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(container)
    container.bg = bg
    Orbit.Skin:RegisterMaskedSurface(container, bg)

    local overlay = CreateFrame("StatusBar", nil, container)
    overlay:SetAllPoints(container)
    overlay:SetFrameLevel(container:GetFrameLevel() + OVERLAY_FRAME_OFFSET)
    overlay:SetStatusBarTexture(FALLBACK_TEXTURE)
    overlay:SetMinMaxValues(0, 1)
    overlay:SetValue(0)
    overlay:Hide()
    container.Overlay = overlay
    Orbit.Skin:RegisterMaskedSurface(container, overlay:GetStatusBarTexture())

    -- Pending-XP sub-fill: layered between Overlay and Bar; hidden for rep/honor.
    local pending = CreateFrame("StatusBar", nil, container)
    pending:SetAllPoints(container)
    pending:SetFrameLevel(container:GetFrameLevel() + OVERLAY_FRAME_OFFSET + 1)
    pending:SetStatusBarTexture(FALLBACK_TEXTURE)
    pending:SetMinMaxValues(0, 1)
    pending:SetValue(0)
    pending:Hide()
    container.Pending = pending
    Orbit.Skin:RegisterMaskedSurface(container, pending:GetStatusBarTexture())

    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetAllPoints(container)
    bar:SetFrameLevel(container:GetFrameLevel() + BAR_FRAME_OFFSET)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    -- Must precede the Tick's SetPoint anchor — otherwise GetStatusBarTexture() is nil and the Tick silently anchors to UIParent (screen-tall line).
    bar:SetStatusBarTexture(FALLBACK_TEXTURE)
    container.Bar = bar
    Orbit.Skin:RegisterMaskedSurface(container, bar:GetStatusBarTexture())

    -- Leading-edge tick anchored to the StatusBarTexture so position/height track the fill without per-frame arithmetic.
    local tick = bar:CreateTexture(nil, "ARTWORK")
    tick:SetTexture("Interface\\Buttons\\WHITE8x8")
    tick:SetVertexColor(1, 1, 1, 1)
    tick:SetPoint("TOP",    bar:GetStatusBarTexture(), "TOPRIGHT",    0, 0)
    tick:SetPoint("BOTTOM", bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    tick:Hide()
    container.Tick = tick

    -- Tick-mark parent: overlays vertical block dividers at fixed percentage intervals.
    local tickFrame = CreateFrame("Frame", nil, container)
    tickFrame:SetAllPoints(container)
    tickFrame:SetFrameLevel(container:GetFrameLevel() + BAR_FRAME_OFFSET + 1)
    container.TickFrame = tickFrame
    container._ticks = {}

    local textFrame = CreateFrame("Frame", nil, container)
    textFrame:SetAllPoints(container)
    textFrame:SetFrameLevel(container:GetFrameLevel() + TEXT_FRAME_OFFSET_LEVEL)
    container.TextFrame = textFrame

    return container
end

-- [ TEXT COMPONENTS ]--------------------------------------------------------------------------------
-- Each component is a Frame wrapping a FontString — Canvas Mode drags the Frame, OverrideUtils restyles `frame.visual`.
local function MakeTextComponent(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(1, 1)
    local fs = frame:CreateFontString(nil, "OVERLAY")
    fs:SetAllPoints()
    frame.Text = fs
    frame.visual = fs
    return frame
end

function StatusBarBase:CreateTextComponents(container)
    container.Name = MakeTextComponent(container.TextFrame)
    container.Level = MakeTextComponent(container.TextFrame)
    container.Value = MakeTextComponent(container.TextFrame)
end

-- Parent frame must size to the rendered text — FontString uses SetAllPoints, so an undersized parent clips the string.
function StatusBarBase:SetComponentText(component, text)
    if not component or not component.Text then return end
    component.Text:SetText(text or "")
    local w = component.Text:GetStringWidth() or 0
    local h = component.Text:GetStringHeight() or 0
    local scale = component:GetEffectiveScale()
    component:SetSize(w > 0 and Pixel:Snap(w + 2, scale) or 1, h > 0 and Pixel:Snap(h + 2, scale) or 1)
end

function StatusBarBase:AttachCanvasComponents(plugin, container, systemIndex)
    local MPC = function(key) return OrbitEngine.ComponentDrag:MakePositionCallback(plugin, systemIndex, key) end
    OrbitEngine.ComponentDrag:Attach(container.Name, container,
        { key = COMP_KEY_NAME, sourceOverride = container.Name.Text, isFontString = true, onPositionChange = MPC(COMP_KEY_NAME) })
    OrbitEngine.ComponentDrag:Attach(container.Level, container,
        { key = COMP_KEY_LEVEL, sourceOverride = container.Level.Text, isFontString = true, onPositionChange = MPC(COMP_KEY_LEVEL) })
    OrbitEngine.ComponentDrag:Attach(container.Value, container,
        { key = COMP_KEY_VALUE, sourceOverride = container.Value.Text, isFontString = true, onPositionChange = MPC(COMP_KEY_VALUE) })
end

function StatusBarBase:ApplyComponentVisibility(plugin, container)
    local mouseOverOnly = plugin:GetSetting(plugin.system, "TextOnMouseover")
    if Orbit:IsEditMode() then mouseOverOnly = false end
    local hoverHidden = mouseOverOnly and not container._hovered

    local function resolve(key, frame)
        if plugin:IsComponentDisabled(key) then frame:Hide()
        elseif hoverHidden then frame:Hide()
        else frame:Show() end
    end
    resolve(COMP_KEY_NAME, container.Name)
    resolve(COMP_KEY_LEVEL, container.Level)
    resolve(COMP_KEY_VALUE, container.Value)
end

-- Mouse stays enabled regardless of mouseover setting so edit-mode drag shares the same hooked frame; idempotent.
function StatusBarBase:SetupMouseoverHooks(plugin, container)
    if container._mouseoverHooked then return end
    container._mouseoverHooked = true
    container:EnableMouse(true)
    container:HookScript("OnEnter", function(self)
        self._hovered = true
        StatusBarBase:ApplyComponentVisibility(plugin, self)
    end)
    container:HookScript("OnLeave", function(self)
        self._hovered = false
        StatusBarBase:ApplyComponentVisibility(plugin, self)
    end)
end

-- FontStringCreator clones GetText once at preview creation, so later live-frame text changes don't reach the preview — call this after SetComponentText.
function StatusBarBase:SyncPreviewText(plugin, container)
    local Dialog = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.Dialog
    if not Dialog or not Dialog.IsShown or not Dialog:IsShown() then return end
    if Dialog.targetPlugin ~= plugin then return end
    local previews = Dialog.previewComponents
    if not previews then return end
    local function sync(previewKey, sourceFrame)
        local preview = previews[previewKey]
        if preview and preview.visual and preview.visual.SetText and sourceFrame and sourceFrame.Text then
            preview.visual:SetText(sourceFrame.Text:GetText() or "")
        end
    end
    sync(COMP_KEY_NAME, container.Name)
    sync(COMP_KEY_LEVEL, container.Level)
    sync(COMP_KEY_VALUE, container.Value)
end

-- [ THEME ]------------------------------------------------------------------------------------------
function StatusBarBase:ApplyTheme(container, options)
    options = options or {}
    local gs = Orbit.db.GlobalSettings
    local textureName = options.texture or gs.Texture
    local texturePath = LSM:Fetch("statusbar", textureName) or FALLBACK_TEXTURE

    container.Bar:SetStatusBarTexture(texturePath)
    container.Overlay:SetStatusBarTexture(texturePath)

    if options.color then
        local c = options.color
        container.Bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    end
    if options.overlayColor then
        local c = options.overlayColor
        container.Overlay:SetStatusBarColor(c.r, c.g, c.b, c.a or 0.5)
    end

    Orbit.Skin:ApplyGradientBackground(container, gs.UnitFrameBackdropColourCurve, Constants.Colors.Background)

    local borderSize = gs.BorderSize or Constants.Settings.BorderSize.Default
    Orbit.Skin:SkinBorder(container, container, borderSize)
end

-- Applies the base font to a text component and layers per-component overrides on top.
function StatusBarBase:ApplyTextComponent(component, overrides, defaultSize)
    if not component or not component.Text then return end
    local gs = Orbit.db.GlobalSettings
    Orbit.Skin:SkinText(component.Text, { font = gs.Font, textSize = defaultSize or Constants.Settings.TextSize.Default })
    OrbitEngine.OverrideUtils.ApplyOverrides(component.Text, overrides or {}, {
        fontSize = defaultSize or Constants.Settings.TextSize.Default,
        fontPath = LSM:Fetch("font", gs.Font),
    })
end

-- [ FILL HELPERS ]-----------------------------------------------------------------------------------
-- Guard secret inputs so widget state stays non-secret (taint risk during edit-mode traversal) — bar holds its last non-secret fill through encounters.
function StatusBarBase:SetFill(container, current, max)
    if issecretvalue(current) or issecretvalue(max) then return end
    container.Bar:SetMinMaxValues(0, max)
    container.Bar:SetValue(current)
end

function StatusBarBase:SetOverlayFill(container, current, max)
    if issecretvalue(current) or issecretvalue(max) then return end
    container.Overlay:SetMinMaxValues(0, max)
    container.Overlay:SetValue(current)
    container.Overlay:Show()
end

function StatusBarBase:HideOverlay(container)
    container.Overlay:Hide()
end

-- [ PENDING-XP SUB-FILL ]----------------------------------------------------------------------------
function StatusBarBase:SetPendingFill(container, current, max, pending, color)
    if issecretvalue(current) or issecretvalue(max) then container.Pending:Hide(); return end
    if not pending or pending <= 0 or not max or max <= 0 then container.Pending:Hide(); return end
    local value = current + pending
    if value > max then value = max end
    container.Pending:SetMinMaxValues(0, max)
    container.Pending:SetValue(value)
    if color then
        container.Pending:SetStatusBarColor(color.r, color.g, color.b, color.a or 0.5)
    end
    local tex = container.Pending:GetStatusBarTexture()
    if tex then tex:SetAlpha(0.55) end
    container.Pending:Show()
end

function StatusBarBase:HidePending(container) container.Pending:Hide() end

-- [ LEADING-EDGE TICK ]------------------------------------------------------------------------------
-- Width in pixels. 0 (or nil) hides the tick entirely.
function StatusBarBase:SetTickWidth(container, width)
    width = tonumber(width) or 0
    if width <= 0 then container.Tick:Hide(); return end
    container.Tick:SetWidth(Pixel:Multiple(width, container:GetEffectiveScale()))
    container.Tick:Show()
end

-- [ FILL ANIMATION ]---------------------------------------------------------------------------------
-- No-op: SmoothStatusBarMixin's OnUpdate keeps the bar Orbit-tainted, which propagates into Blizzard's secure edit-mode iteration and trips HideSystemSelections on exit.
function StatusBarBase:EnableSmoothFill(container)
end

-- [ BLOCK TICK MARKS ]-------------------------------------------------------------------------------
function StatusBarBase:SetTickMarks(container, percent, color)
    percent = tonumber(percent) or 0
    local pool = container._ticks
    local count = (percent > 0 and percent < 100) and (math.floor(100 / percent) - 1) or 0
    color = color or Orbit.Skin:ResolveBorderColor(false)
    local scale = container:GetEffectiveScale()
    local containerWidth = container:GetWidth() or 0
    local tickWidth = Pixel:Multiple(2, scale)
    for i = 1, count do
        local t = pool[i]
        if not t then
            t = container.TickFrame:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(1, 1, 1, 1)
            t:SetWidth(tickWidth)
            pool[i] = t
        end
        t:SetColorTexture(color.r, color.g, color.b, color.a or 0.5)
        t:ClearAllPoints()
        local x = Pixel:Snap((i * percent / 100) * containerWidth, scale)
        t:SetPoint("TOP",    container, "TOPLEFT",    x, 0)
        t:SetPoint("BOTTOM", container, "BOTTOMLEFT", x, 0)
        t:Show()
    end
    for i = count + 1, #pool do pool[i]:Hide() end
end

-- [ CLICK DISPATCH ]---------------------------------------------------------------------------------
function StatusBarBase:SetupClickDispatch(container, options)
    if container._clickDispatchHooked then return end
    container._clickDispatchHooked = true
    options = options or {}
    container:EnableMouseWheel(options.onScroll and true or false)
    container:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            if IsShiftKeyDown() and options.onShiftClick then options.onShiftClick()
            elseif options.onLeftClick then options.onLeftClick() end
        elseif button == "RightButton" then
            if IsShiftKeyDown() and options.onShiftRightClick then options.onShiftRightClick() end
        end
    end)
    if options.onScroll then
        container:HookScript("OnMouseWheel", function(_, delta) options.onScroll(delta) end)
    end
end

-- [ BLIZZARD NATIVE HIDE ]---------------------------------------------------------------------------
-- Children Main/SecondaryStatusTrackingBarContainer are EditMode system frames with their own SetPoint to UIParent — must disable each, hiding the manager alone leaves them visible.
function StatusBarBase:HideBlizzardTrackingBars()
    if InCombatLockdown() then return end
    if not StatusTrackingBarManager then return end
    OrbitEngine.NativeFrame:SecureHide(StatusTrackingBarManager)
    if StatusTrackingBarManager.MainStatusTrackingBarContainer then
        OrbitEngine.NativeFrame:SecureHide(StatusTrackingBarManager.MainStatusTrackingBarContainer)
    end
    if StatusTrackingBarManager.SecondaryStatusTrackingBarContainer then
        OrbitEngine.NativeFrame:SecureHide(StatusTrackingBarManager.SecondaryStatusTrackingBarContainer)
    end
end
