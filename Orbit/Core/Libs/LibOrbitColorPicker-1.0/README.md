# liborbitcolorpicker-1.0

extends blizzard's `ColorPickerFrame` with a gradient bar, drag-and-drop pin system, and class color swatch. supports two modes: single-color (one pin) and multi-color (gradient with multiple pins).

## usage

```lua
local lib = LibStub("LibOrbitColorPicker-1.0")
```

### opening the picker

```lua
lib:Open({
    initialData = curveData,       -- curve table { pins = {...} } or simple color { r, g, b, a }
    callback = function(result, wasCancelled)
        if wasCancelled then return end
        -- result = { curve = nativeCurve, pins = { { position, color, type? }, ... } }
    end,
    hasOpacity = true,             -- show opacity slider (default: true)
    forceSingleColor = false,      -- restrict to single pin mode (default: false)
})
```

the picker auto-detects the input format. if `initialData` has a `.pins` table, pins are loaded from it. if it's a simple `{ r, g, b, a }` table, a single pin is created.

### checking state

```lua
lib:IsOpen()  -- returns true if the picker is currently shown
```

## data format

### curve data (input and output)

```lua
{
    curve = <native ColorCurve>,   -- C_CurveUtil object (for engine use)
    pins = {
        { position = 0.0, color = { r = 1, g = 0, b = 0, a = 1 } },
        { position = 1.0, color = { r = 0, g = 0, b = 1, a = 1 }, type = "class" },
    },
}
```

- `position`: 0.0 (left) to 1.0 (right) on the gradient bar
- `color`: resolved rgba values
- `type`: optional — `"class"` pins dynamically resolve to the player's class color

## modes

### single-color mode (`forceSingleColor = true`)

one pin only. dragging from the current swatch or class color swatch replaces the existing pin. used by canvas mode component settings for per-element color overrides.

### multi-color mode (default)

unlimited pins. drag colors from the current swatch or class color swatch onto the gradient bar to add pins. drag pin handles to reposition. right-click a pin handle to remove it.

## interaction

- **drag from current swatch** to gradient bar to add a pin with the wheel's current color
- **drag from class color swatch** to add a pin that tracks the player's class color
- **drag pin handles** left/right to reposition (multi-color mode only)
- **right-click pin handle** to remove a pin
- **apply color** button commits the result; close/escape cancels

## callback behavior

the callback fires in two situations:

1. **on every pin change** (add, remove, drag) during the session — `wasCancelled = false`
2. **on picker close** — `wasCancelled` reflects whether the user applied or cancelled

## dependencies

- `LibStub` (standard wow library versioning)
- blizzard `ColorPickerFrame` (extended at runtime)
- `Orbit.Engine.Pixel` (optional, for pixel-snapped borders)
