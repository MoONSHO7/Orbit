# liborbitcolorpicker-1.0

standalone color picker with gradient bar, drag-and-drop pins, and class color swatch. supports single-color and multi-color (gradient) modes.

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
    callback = function(result)
        if not result then
            if callback then callback(nil) end
            return
        end
        local pin = result.pins and result.pins[1]
        if pin and pin.color then
            frame.UpdateColor(pin.color.r, pin.color.g, pin.color.b, pin.color.a)
        end
    end,
})
```

### checking state

```lua
lib:IsOpen()
```

## open options

| key | type | description |
|---|---|---|
| `initialData` | `table` or `nil` | curve table `{ pins = {...} }` or simple color `{ r, g, b, a }` |
| `forceSingleColor` | `boolean` | restrict to one pin when `true` (default: `false`) |
| `callback` | `function(result)` | called on picker close with result or `nil` |

## callback result

| scenario | result |
|---|---|
| apply with pins | `{ curve = <native>, pins = { ... } }` |
| clear all pins ("clear color") | `nil` |
| cancel (escape / close) | `{ curve, pins }` from snapshot before edits |

### handling nil (default color fallback)

when the user removes all pins, the callback receives `nil`. consumers must provide a fallback:

```lua
local color = Engine.WidgetLogic:GetFirstColorFromCurve(savedData.colorCurve) or DEFAULT_COLOR
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

## modes

### single-color (`forceSingleColor = true`)

one pin only. dragging from swatches replaces the existing pin. used for static text components (stacks, keybind, charges).

### multi-color (default)

unlimited pins. drag colors onto the gradient bar to add stops. drag handles to reposition. right-click a handle to remove it. used for timer texts and health bars where color maps to a progress value.

## interaction

- drag from current swatch to gradient bar to add a pin
- drag from class color swatch to add a class-tracking pin
- drag pin handles to reposition (multi-color only)
- right-click a pin handle to remove it
- "apply color" commits the result, "clear color" appears when no pins remain
- close / escape cancels and restores the previous state

## dependencies

- `LibStub`
