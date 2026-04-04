# LibOrbitGlow-1.0

A high-performance utility library for creating and managing visual frame glows, animations, and particle effects. Designed for World of Warcraft 12.0.0 and above. Features unified resource pooling and native reverse playback computed mathematically.

> **Standalone library.** No external addon dependencies. Consumed exclusively via `LibStub("LibOrbitGlow-1.0")`.

## Usage

The library exposes a simplified facade that abstracts specific animation groups, textures, and geometry engines. Consumers only need to ask for a specific glow type and pass an options table.

### Showing a glow

```lua
local lib = LibStub("LibOrbitGlow-1.0", true)
if not lib then return end

lib.Show(frame, "Pixel", {
    key = "myComponentGlow",
    color = { 0.2, 0.8, 1, 1 },
    lines = 8,
    frequency = 0.5,
    thickness = 2,
    maskIcon = true,
    reverse = false
})
```

### Hiding a glow

It's crucial to hide glows using the exact same type and key you used to show them, so the library can gracefully stop animations and recycle frames back into the global pool.

```lua
lib.Hide(frame, "Pixel", "myComponentGlow")
```

### Combat and secret safety (alpha hiding)

When tracking auras, cooldowns, or power states that return WoW 12.0 'secret values', you **cannot** execute logic branches based on those values. This means you cannot conditionally call `lib.Hide()` in response to an aura dropping during combat.

To safely hide glows in these scenarios, rely on native alpha propagation or update the `options.color` alpha channel to `0` instead of calling `lib.Hide()`.

```lua
-- Safe: pass dynamic alpha directly to the library without branching
local alpha = isAuraActive and 1 or 0
lib.Show(frame, "Pixel", { color = { 1, 0, 0, alpha } })
```

## Glow types

Consumers pass these exact string identifiers to `lib.Show` as the second argument. The engine automatically resolves the underlying math, animation groups, and atlases. Passing an unknown type will `error()`.

| Type | Description | Engine |
|---|---|---|
| `"Thin"` | Thin swirling ants | Flipbook |
| `"Thick"` | Thick proc loop | Flipbook |
| `"Medium"` | Standard action bar proc | Flipbook |
| `"Static"` | Static cooldown manager glow | Static |
| `"Classic"` | Classic WoW action button flash and ant swirl | Manual stepper |
| `"Pixel"` | Modern pixel lines tracing the outer border | Geometry |
| `"Autocast"` | Native pet bar autocast shine squares | Geometry |

## Global options

These options act globally across almost all glow engines. They are passed as the 3rd argument to `lib.Show(frame, glowType, options)`.

| Field | Type | Description |
|---|---|---|
| `key` | `string` | Unique identifier used for tracking and hiding. Default: `"Default"` |
| `color` | `table` | `{r,g,b,a}` array or a 12.0 `Color` object. Default: white |
| `frameLevel` | `number` | Relative frame level above the parent frame. Default: `8` |
| `maskIcon` | `boolean` | Applies native corner rounding specifically for `frame.icon`. Prevents rendering out of bounds. |
| `maskInset` | `number` | Pixel distance to inset the mask from the edge. Default: `1` |
| `desaturated`| `boolean` | Explicitly desaturates underlying atlases. Default: `false` |
| `reverse` | `boolean` | Dynamically reverses the rotation or movement of the glow mathematically, avoiding mirrored atlases. |

## Engine-specific options

Specific glow engines support additional fine-tuning properties.

### Flipbook engines (`Thin`, `Thick`, `Medium`)
- `scale` (number): Multiplier applied to width and height.

### Pixel engine (`Pixel`)
- `lines` (number): How many tracing particles are generated. Default: `8`
- `frequency` (number): Speed scaler affecting the animation loop velocity. Default: `0.25`
- `thickness` (number): Width of the tracing particles. Default: `2`
- `border` (boolean): Renders a dark, translucent backdrop strictly inside the pixel bounds to obscure the parent frame slightly for contrast. Default: `true`
- `xOffset` / `yOffset` (number): Margin expanding the trace tracking box away from the edges.

### Autocast engine (`Autocast`)
- `particles` (number): Number of points mapping the border. Default: `4`
- `frequency` (number): Rotation speed multiplier. Default: `0` (base)
- `scale` (number): Scaling scalar on each particle. Default: `1`

## Best practices

- Always provide a specific `key`. If your addon renders multiple glows to the same frame (e.g. tracking multiple auras), failure to provide a key will overwrite the `"Default"` bucket.
- Always pair a single `lib.Show` explicitly with a single `lib.Hide` when out of combat. This returns frames to the pool explicitly.
- If passing `maskIcon = true`, ensure that `frame.icon` actually exists. The library utilizes `UI-Frame-IconMask` under the hood.
