# liborbitcolorpicker-1.0

standalone color picker with gradient bar, drag-and-drop pins, and class color swatch. supports single-color and multi-color (gradient) modes. includes a built-in sequential guided tour with localization for 9 languages.

## usage

### multi-color mode (gradient)

```lua
local lib = LibStub("LibOrbitColorPicker-1.0", true)
if not lib then return end

lib:Open({
    initialData = self.curveData,
    forceSingleColor = self.singleColorMode,
    callback = function(result)
        if result and result.pins and #result.pins > 0 then
            self.curveData = result
        else
            self.curveData = nil
        end
        self:UpdatePreview()
        if self.onChangeCallback then self.onChangeCallback(self.curveData) end
    end,
})
```

### single-color mode

```lua
lib:Open({
    initialData = { r = frame.r, g = frame.g, b = frame.b, a = frame.a },
    forceSingleColor = true,
    callback = function(result)
        if not result then return end
        local pin = result.pins and result.pins[1]
        if pin and pin.color then
            frame.UpdateColor(pin.color.r, pin.color.g, pin.color.b, pin.color.a)
        end
    end,
})
```

### first-time tour via onOpen hook

the library exposes a generic `onOpen` callback. consumers use this to trigger the built-in tour on first open, using their own persistence:

```lua
lib:Open({
    initialData = myData,
    onOpen = function(picker)
        if not mySavedVars.colorPickerTourSeen then
            mySavedVars.colorPickerTourSeen = true
            C_Timer.After(0.1, function()
                if picker:IsOpen() then picker:StartTour() end
            end)
        end
    end,
    callback = function(result) ... end,
})
```

the tour can always be started manually via the info button in the top-left corner.

### checking state

```lua
lib:IsOpen()
```

## open options

| key | type | description |
|---|---|---|
| `initialData` | `table` or `nil` | curve table `{ pins = {...} }` or simple color `{ r, g, b, a }` |
| `forceSingleColor` | `boolean` | restrict to one pin when `true` (default: `false`) |
| `hasDesaturation` | `boolean` | show desaturation checkbox when `true` (default: `false`) |
| `callback` | `function(result)` | called on picker close with result or `nil` |
| `onOpen` | `function(picker)` | called after picker is fully shown and initialized |

## callback result

| scenario | result |
|---|---|
| apply with pins | `{ curve = <native>, pins = { ... }, desaturated = bool }` |
| clear all pins ("clear color") | `nil` |
| cancel (escape / close) | `{ curve, pins, desaturated }` from snapshot before edits |

`desaturated` is only present when `hasDesaturation = true` was set in open options.

### handling nil (default color fallback)

when the user removes all pins, the callback receives `nil`. consumers must provide a fallback:

```lua
local color = GetFirstColorFromCurve(savedData.colorCurve) or DEFAULT_COLOR
element:SetTextColor(color.r, color.g, color.b, color.a or 1)
```

## data format

```lua
{
    curve = <native ColorCurve>,
    pins = {
        { position = 0.0, color = { r = 1, g = 0, b = 0, a = 1 } },
        { position = 1.0, color = { r = 0, g = 0, b = 1, a = 1 }, type = "class" },
    },
}
```

- `position`: 0.0 (left) to 1.0 (right) on the gradient bar
- `color`: resolved rgba values
- `type`: optional, `"class"` pins resolve to the player's current class color
- `desaturated`: optional `boolean`, present when `hasDesaturation` was used

## modes

### single-color (`forceSingleColor = true`)

one pin only. dragging from swatches replaces the existing pin. used for static text components (stacks, keybind, charges).

### multi-color (default)

unlimited pins. drag colors onto the gradient bar to add stops. drag handles to reposition. right-click a handle to remove it. used for timer texts and health bars where color maps to a progress value.

## interaction

- drag from current swatch to gradient bar to add a pin
- drag from class color swatch to add a class-tracking pin
- drag pin handles to reposition (multi-color only)
- arrow keys to nudge a focused pin, shift for fine precision
- right-click a pin handle to remove it
- "apply color" commits the result, "clear color" appears when no pins remain
- close / escape cancels and restores the previous state

## tour system

a built-in sequential guided tour with 6 stops:

1. **color wheel** — hue, saturation, and brightness controls
2. **current color swatch** — drag to gradient bar to add pin
3. **class color swatch** — spec-tracking pin
4. **gradient bar** — color curve visualization, pin management
5. **pin controls** — arrow key nudging, shift for fine precision
6. **apply / clear** — save gradient or reset to default

the tour is localized for: english, german, french, spanish, portuguese, russian, korean, simplified chinese, traditional chinese.

### public tour api

| method | description |
|---|---|
| `lib:StartTour()` | begin the tour at stop 1 |
| `lib:EndTour()` | dismiss the tour |
| `lib:ToggleInfoMode()` | cycle: start → next stop → ... → end |

the info button (top-left corner) calls `ToggleInfoMode()`.

## bundled assets

- `checkerboard.tga` — alpha transparency preview pattern (auto-detected via `debugstack`)

## dependencies

- `LibStub`
