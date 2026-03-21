# Canvas Mode Onboarding Guide

Practical guide for adding canvas mode to a standalone frame (e.g. cast bar, power bar, resource bar). This covers the **simple pattern** — registering FontString components directly, without a custom creator.

> [!NOTE]
> For composite unit frames (boss frames, party frames) that use sub-component creators (CastBarCreator, etc.), see the [canvas-creators skill](file:///c:/Users/benmo/Documents/git/.agent/skills/canvas-creators/SKILL.md) instead.

## Pattern Overview

Standalone frames register their text elements (FontStrings) directly as draggable components. No creator is needed. The frame provides a `CreateCanvasPreview()` function for the canvas viewport.

**Reference implementations:**
- [PlayerPower.lua](file:///c:/Users/benmo/Documents/git/Orbit/Orbit/Plugins/UnitFrames/Player/PlayerPower.lua) — single text component
- [PlayerCastBar.lua](file:///c:/Users/benmo/Documents/git/Orbit/Orbit/Plugins/UnitFrames/Player/PlayerCastBar.lua) — two text components + icon

## Step-by-Step

### 1. Plugin Registration

Set `canvasMode = true` and provide `ComponentPositions` + `DisabledComponents` defaults:

```lua
local Plugin = Orbit:RegisterPlugin("My Plugin", "Orbit_MyPlugin", {
    defaults = {
        DisabledComponents = {},
        ComponentPositions = {
            Text = { anchorX = "LEFT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "LEFT" },
            Timer = { anchorX = "RIGHT", offsetX = 5, anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" },
        },
        -- ... other defaults
    },
})
Plugin.canvasMode = true
```

> [!IMPORTANT]
> `ComponentPositions` keys are flat (e.g. `Text`, `Timer`), not nested under a parent component key. This is different from the boss frame sub-component pattern.

### 2. Register Components (OnLoad)

After the skin creates the FontStrings, register each one with `ComponentDrag:Attach`:

```lua
if OrbitEngine.ComponentDrag then
    if Frame.Text then
        OrbitEngine.ComponentDrag:Attach(Frame.Text, Frame, {
            key = "Text",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, systemIndex, "Text"),
        })
    end
    if Frame.Timer then
        OrbitEngine.ComponentDrag:Attach(Frame.Timer, Frame, {
            key = "Timer",
            onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(self, systemIndex, "Timer"),
        })
    end
end
```

- `MakePositionCallback` is a factory that creates the standard position save callback
- The second argument to `Attach` is the parent frame used for component discovery

### 3. Canvas Preview (OnLoad)

Attach a `CreateCanvasPreview` function to the frame. This renders the bar visual in the canvas viewport:

```lua
function Frame:CreateCanvasPreview(options)
    local scale = options.scale or 1
    local borderSize = options.borderSize or OrbitEngine.Pixel:DefaultBorderSize(scale)
    local preview = OrbitEngine.Preview.Frame:CreateBasePreview(self, scale, options.parent, borderSize)

    local bar = CreateFrame("StatusBar", nil, preview)
    bar:SetAllPoints()
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.5)
    -- Apply texture, color, etc.

    preview.StatusBar = bar
    return preview
end
```

### 4. Apply Settings

In `ApplySettings()`, after the skin layer runs:

```lua
-- Canvas Mode: visibility, overrides, and position restore
local savedPositions = self:GetComponentPositions(systemIndex)

if Frame.Text then
    if not OrbitEngine.ComponentDrag:IsDisabled(Frame.Text) then
        Frame.Text:Show()
        local overrides = savedPositions.Text and savedPositions.Text.overrides or {}
        OrbitEngine.OverrideUtils.ApplyOverrides(Frame.Text, overrides, { fontSize = textSize, fontPath = fontPath })
    else
        Frame.Text:Hide()
    end
end

if savedPositions and OrbitEngine.ComponentDrag then
    OrbitEngine.ComponentDrag:RestoreFramePositions(Frame, savedPositions)
end
```

**Order matters:**
1. Skin layer sets baseline font/color/position
2. `ApplyOverrides` applies canvas font/size/color overrides on top
3. `RestoreFramePositions` sets canvas positions last (overrides skin anchors)

### 5. Remove Redundant Settings UI

If text visibility was previously controlled by checkboxes (e.g. "Show Spell Name"), remove them. Canvas mode controls visibility via the dock (drag off = disable, click dock = restore). Remove:
- The checkbox from `AddSettings()`
- The default entry
- The `showText` / `showTimer` conditionals in the skin's `Apply()` method

## Coordinate Space Rules

> [!WARNING]
> The canvas preview and live frame must share the same coordinate space for text positioning. If they don't match, positions saved in canvas mode will appear at different locations on the live frame.

### The Problem

When a frame has an inset element (e.g. an icon that shifts the status bar), the text's coordinate space is smaller than the full frame. The canvas preview must represent the same area.

### The Solution

**TextFrame** — Create an overlay frame that tracks the text positioning area (the inner bar, not the full frame):

```lua
-- In the skin's Create() function:
bar.TextFrame = CreateFrame("Frame", nil, parent)
bar.TextFrame:SetAllPoints(bar)  -- tracks inner bar, not full parent
bar.TextFrame:SetFrameLevel(bar:GetFrameLevel() + Constants.Levels.Overlay)

bar.Text = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bar.Timer = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
```

**Canvas preview** — Size the preview to match the inner bar, with decorative elements (icon) outside:

```lua
function Frame:CreateCanvasPreview(options)
    local iconSize = showIcon and height or 0
    local barWidth = self:GetWidth() - iconSize

    local preview = OrbitEngine.Preview.Frame:CreateBasePreview(self, scale, options.parent, borderSize)
    preview:SetWidth(OrbitEngine.Pixel:Snap(barWidth * scale, preview:GetEffectiveScale()))
    preview.sourceWidth = barWidth  -- override so canvas uses inner bar dimensions

    -- Icon floats outside the preview
    if showIcon then
        local icon = preview:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSize * scale, iconSize * scale)
        icon:SetPoint("RIGHT", preview, "LEFT", 0, 0)  -- to the left, outside
    end
end
```

This ensures:
- `Text:GetParent()` returns TextFrame (sized to inner bar) on the live frame
- Canvas preview is also sized to the inner bar
- Saved positions translate 1:1 between canvas and live

## Frame Layering

Use `Constants.Levels` for frame level offsets. Never use strata changes to layer within a plugin.

| Level Offset | Constant | What |
|---|---|---|
| `+0` | — | Parent frame (background, borders) |
| `+1` | `Levels.StatusBar` | StatusBar (progress fill, spark, latency) |
| `+7` | `Levels.Overlay` | TextFrame overlay (Text, Timer) |

The TextFrame must be:
- A child of `parent` (not `bar`) — so it is NOT subject to `bar:SetClipsChildren(true)`
- At `bar:GetFrameLevel() + Levels.Overlay` — so text renders above all bar elements

## Checklist

- [ ] `Plugin.canvasMode = true`
- [ ] `defaults.ComponentPositions` with flat keys
- [ ] `defaults.DisabledComponents = {}`
- [ ] `ComponentDrag:Attach()` for each FontString after skin creates them
- [ ] `MakePositionCallback` for position save (not manual callback)
- [ ] `CreateCanvasPreview()` on the source frame
- [ ] Preview `sourceWidth` matches the text coordinate space (inner bar, not full frame)
- [ ] Decorative elements (icon) outside the preview area
- [ ] `IsDisabled()` check for visibility in `ApplySettings`
- [ ] `ApplyOverrides()` for font/size/color after the skin
- [ ] `RestoreFramePositions()` for position restore after everything else
- [ ] TextFrame at `Levels.Overlay`, child of outer parent (not clipping StatusBar)
- [ ] Redundant visibility checkboxes removed from settings UI

## Common Mistakes

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| FontStrings on the StatusBar | Clipped by `SetClipsChildren(true)` — text can't extend outside | Create a TextFrame overlay on the parent |
| TextFrame at same level as StatusBar | Text renders behind the bar fill | Use `Constants.Levels.Overlay` offset |
| Preview sized to full frame (with icon) | Coordinate mismatch — positions shift on live frame | Override `preview.sourceWidth` to inner bar width |
| Using sub-component creators for standalone frames | Adds Height/Width/Icon/Color settings that don't belong | Use direct FontString registration instead |
| Hardcoding icon offset in default positions | Breaks when user changes cast bar height | Anchor text relative to the inner bar, not the full frame |
| `showText`/`showTimer` checkboxes alongside canvas mode | Dual controls for the same thing — confusing | Remove checkboxes; use canvas dock for visibility |
