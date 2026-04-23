---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local FALLBACK_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local DEFAULT_BG_COLOR = { r = 0.05, g = 0.05, b = 0.05, a = 0.85 }
local OVERLAY_FRAME_OFFSET = 1
local BAR_FRAME_OFFSET = 2
local TEXT_FRAME_OFFSET_LEVEL = Constants.Levels.Overlay

local COMP_KEY_NAME = "Name"
local COMP_KEY_LEVEL = "BarLevel"
local COMP_KEY_VALUE = "BarValue"

-- [ CANVAS MODE COMPONENT SCHEMAS ]-----------------------------------------------------------------
-- `Name` already exists in the shared KEY_SCHEMAS (STATIC_TEXT: font/size/color). `BarLevel` and
-- `BarValue` are status-bar specific — register them so each component's Canvas Mode dock shows
-- font/size/color, and `BarValue` exposes the ValueMode dropdown (current/max/percent) that drives
-- what the value text renders. `plugin = true` routes that dropdown to `plugin:SetSetting`.

do
    local Schema = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.SettingsSchema
    if Schema and Schema.KEY_SCHEMAS then
        Schema.KEY_SCHEMAS[COMP_KEY_LEVEL] = { controls = {
            { type = "font", key = "Font", label = "Font" },
            { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = "Color", singleColor = true },
        } }
        Schema.KEY_SCHEMAS[COMP_KEY_VALUE] = { controls = {
            { type = "dropdown", key = "ValueMode", label = "Value", plugin = true,
              options = {
                  { text = "Percentage",      value = "percent" },
                  { text = "Current / Max",   value = "currentmax" },
                  { text = "Remaining",       value = "tolevel" },
                  { text = "Per Hour",        value = "perhour" },
                  { text = "Time to Level",   value = "eta" },
              }, default = "percent" },
            { type = "font", key = "Font", label = "Font" },
            { type = "slider", key = "FontSize", label = "Size", min = 6, max = 32, step = 1 },
            { type = "colorcurve", key = "CustomColorCurve", label = "Color", singleColor = true },
        } }
    end
end

-- [ STATUS BAR BASE ]-------------------------------------------------------------------------------
-- Shared factory for StatusBars plugins. Each bar is a container Frame holding:
--   .Bar       : StatusBar — primary fill (XP/Rep/Honor)
--   .Overlay   : StatusBar — secondary fill beneath Bar (rested XP, paragon bonus)
--   .bg        : Texture   — solid backdrop behind both bars
--   .TextFrame : Frame     — parent for the 3 canvas-managed text components
--   .Name / .Level / .Value : per-component Frames with a .Text FontString child

---@class OrbitStatusBarBase
Orbit.StatusBarBase = {}
local StatusBarBase = Orbit.StatusBarBase

StatusBarBase.ComponentKeys = { Name = COMP_KEY_NAME, Level = COMP_KEY_LEVEL, Value = COMP_KEY_VALUE }

-- Preset token templates keyed by ValueMode. Plugins call `ResolveTemplate(plugin)` to get the
-- template string matching the user's current dropdown choice, then hand it to TextTemplate:Render.
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
    container:SetClampedToScreen(true)

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(container)
    container.bg = bg

    local overlay = CreateFrame("StatusBar", nil, container)
    overlay:SetAllPoints(container)
    overlay:SetFrameLevel(container:GetFrameLevel() + OVERLAY_FRAME_OFFSET)
    overlay:SetMinMaxValues(0, 1)
    overlay:SetValue(0)
    overlay:Hide()
    container.Overlay = overlay

    -- Pending-XP sub-fill: rendered between Overlay and Bar. Shows quest-turn-in XP as a green
    -- translucent fill extending past the current XP point. Hidden for rep/honor.
    local pending = CreateFrame("StatusBar", nil, container)
    pending:SetAllPoints(container)
    pending:SetFrameLevel(container:GetFrameLevel() + OVERLAY_FRAME_OFFSET + 1)
    pending:SetMinMaxValues(0, 1)
    pending:SetValue(0)
    pending:Hide()
    container.Pending = pending

    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetAllPoints(container)
    bar:SetFrameLevel(container:GetFrameLevel() + BAR_FRAME_OFFSET)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    container.Bar = bar

    -- Leading-edge tick: solid vertical line riding the fill's right edge. Width is driven by
    -- the plugin's TickWidth setting (0 = hidden). Anchored so height auto-tracks the bar and
    -- horizontal position tracks the fill without per-frame arithmetic.
    local tick = bar:CreateTexture(nil, "ARTWORK")
    tick:SetTexture("Interface\\Buttons\\WHITE8x8")
    tick:SetVertexColor(1, 1, 1, 1)
    tick:SetPoint("TOP",    bar:GetStatusBarTexture(), "TOPRIGHT",    0, 0)
    tick:SetPoint("BOTTOM", bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    tick:Hide()
    container.Tick = tick

    -- Tick-mark parent: overlays vertical marks across the bar (e.g. paragon cycle thresholds).
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

-- [ TEXT COMPONENTS ]-------------------------------------------------------------------------------
-- Creates three canvas-positionable text frames (Name, Level, Value) parented to the text frame.
-- Each is a Frame with a single OVERLAY FontString child so Canvas Mode can drag the frame and
-- OverrideUtils can apply font/size/color to the FontString via frame.visual.

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

-- Sets text and resizes the component frame to fit — FontString uses SetAllPoints, so the
-- parent frame must be at least the text's rendered size or the string clips. Mirrors Minimap
-- Clock/ZoneText's dynamic sizing.
function StatusBarBase:SetComponentText(component, text)
    if not component or not component.Text then return end
    component.Text:SetText(text or "")
    local w = component.Text:GetStringWidth() or 0
    local h = component.Text:GetStringHeight() or 0
    component:SetSize(w > 0 and w + 2 or 1, h > 0 and h + 2 or 1)
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

-- Resolves each text component's visibility from three inputs:
--   - `DisabledComponents` (canvas-mode per-component toggle) → force hide
--   - `TextOnMouseover` setting + hover state → hide when unhover (unless in edit mode)
--   - otherwise show
-- Called from ApplySettings and from the mouse enter/leave hooks.
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

-- Enables mouse on the container and hooks OnEnter/OnLeave to re-run ApplyComponentVisibility.
-- Idempotent — safe to call on every ApplySettings. Mouse stays enabled regardless of setting
-- state so edit-mode drag and the hover hooks share the same mouse-enabled frame.
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

-- Mirrors each live text component's current text into the canvas preview's cloned FontStrings.
-- `FontStringCreator` clones the FontString once at preview creation (reads source:GetText and
-- stores locally), so subsequent live-frame text changes never reach the preview. Call this
-- after SetComponentText to keep the preview in sync while the canvas dialog is open.
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

-- [ THEME ]-----------------------------------------------------------------------------------------
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

    local bgColor = options.bgColor or gs.BackdropColour or DEFAULT_BG_COLOR
    container.bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.85)

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

-- [ FILL HELPERS ]----------------------------------------------------------------------------------
-- Guard secret inputs so widget internal state never holds secret values (taint risk during edit
-- mode traversal); the bar keeps its last non-secret fill during encounters instead.

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

-- [ PENDING-XP SUB-FILL ]---------------------------------------------------------------------------
-- Draws a secondary green fill from 0 to (current + pending), clamped to max. Rendered under the
-- main bar so the visible slice between current and current+pending appears green — signalling
-- "XP waiting in completed quests." Guarded for secret inputs.
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

-- [ LEADING-EDGE TICK ]-----------------------------------------------------------------------------
-- Width in pixels. 0 (or nil) hides the tick entirely.
function StatusBarBase:SetTickWidth(container, width)
    width = tonumber(width) or 0
    if width <= 0 then container.Tick:Hide(); return end
    container.Tick:SetWidth(width)
    container.Tick:Show()
end

-- [ FILL ANIMATION ]--------------------------------------------------------------------------------
-- SmoothStatusBarMixin self-registers an OnUpdate script on the bar, which leaves the frame
-- running Orbit-tainted Lua every frame and keeps the execution context flagged for as long as
-- the bar exists. That flag propagates into Blizzard's secure edit-mode iteration and trips
-- HideSystemSelections on exit. Keep the API surface but no-op the hook — fills land directly
-- through the plain-value path.
function StatusBarBase:EnableSmoothFill(container)
    -- Intentionally noop: see notes above.
end

function StatusBarBase:SetSmoothFill(container, current, max)
    self:SetFill(container, current, max)
end

-- [ PARAGON TICK MARKS ]----------------------------------------------------------------------------
-- Draws N vertical tick marks across the bar width. Used to show paragon cycle thresholds on
-- the bar. Reuses textures across calls — keeps the pool on container._ticks.
function StatusBarBase:SetTickMarks(container, count, color)
    count = count or 0
    color = color or { r = 1, g = 0.8, b = 0, a = 0.7 }
    local pool = container._ticks
    for i = 1, count do
        local t = pool[i]
        if not t then
            t = container.TickFrame:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(1, 1, 1, 1)
            t:SetWidth(2)
            pool[i] = t
        end
        t:SetColorTexture(color.r, color.g, color.b, color.a or 0.7)
        t:ClearAllPoints()
        local offset = (i / (count + 1)) -- evenly spaced, excluding edges
        t:SetPoint("TOP",    container, "TOPLEFT",    offset * container:GetWidth(), 0)
        t:SetPoint("BOTTOM", container, "BOTTOMLEFT", offset * container:GetWidth(), 0)
        t:Show()
    end
    for i = count + 1, #pool do pool[i]:Hide() end
end

-- [ CLICK DISPATCH ]--------------------------------------------------------------------------------
-- Wires left / shift-left / shift-right-click behaviors to the container. Each plugin supplies the
-- concrete handlers via an options table so we don't hard-code XP-specific logic here.
--   onLeftClick        : open the relevant native panel
--   onShiftClick       : paste a chat-linkable string representing the bar's current state
--   onShiftRightClick  : reset session stats
--   onScroll           : (direction) → cycle watched faction, etc.
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

-- [ BLIZZARD NATIVE HIDE ]--------------------------------------------------------------------------
function StatusBarBase:HideBlizzardTrackingBars()
    if InCombatLockdown() then return end
    if not StatusTrackingBarManager then return end
    OrbitEngine.NativeFrame:SecureHide(StatusTrackingBarManager)
end
