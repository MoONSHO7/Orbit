# LibOrbitGlow-1.0

A high-performance utility library for creating and managing visual frame glows, animations, and particle effects. Designed for World of Warcraft 12.0.0 and above. Features unified resource pooling.

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
    thickness = 2
})
```

### Hiding a glow

It's crucial to hide glows using the exact same type and key you used to show them, so the library can gracefully stop animations and recycle frames back into the global pool.

```lua
lib.Hide(frame, "Pixel", "myComponentGlow")
```

### Combat and secret safety (alpha hiding)

When tracking auras, cooldowns, or power states that return WoW 12.0 'secret values', you **cannot** execute logic branches based on those values. This means you cannot conditionally call `lib.Hide()` in response to an aura dropping during combat.

To safely hide glows in these scenarios, rely on native alpha propagation or update the `options.color` alpha channel instead of calling `lib.Hide()`. Pass only a plain (non-secret) number as the alpha — `x and 1 or 0` on a secret boolean is itself a Lua-side branch and will throw.

```lua
-- Safe: alpha is a plain number sourced from a non-secret read (e.g. a numeric curve)
lib.Show(frame, "Pixel", { color = { 1, 0, 0, alpha } })
```

If show/hide must follow a secret boolean, derive visibility through a C++ sink on the glow's parent (`parent:SetAlphaFromBoolean(secretBool, 1.0, 0.0)`) rather than branching the secret in Lua to compute an alpha.

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
| `desaturated`| `boolean` | Explicitly desaturates underlying atlases. Default: `false` |

## Engine-specific options

Specific glow engines support additional fine-tuning properties.

### Flipbook engines (`Thin`, `Thick`, `Medium`)
- `scale` (number): Multiplier applied to width and height.

### Pixel engine (`Pixel`)
- `lines` (number): How many tracing particles are generated. Default: `8`
- `frequency` (number): Speed scaler. Positive = faster than baseline (`period = 0.25 / frequency`); `0` or unset = engine baseline (4s); negative = slower than baseline (`period = baseline * (1 + |frequency| * 8)`). Default: unset.
- `thickness` (number): Width of the tracing particles. Default: `2`
- `border` (boolean): Renders a dark, translucent backdrop strictly inside the pixel bounds to obscure the parent frame slightly for contrast. Default: `true`
- `xOffset` / `yOffset` (number): Margin expanding the trace tracking box away from the edges.

### Autocast engine (`Autocast`)
- `particles` (number): Number of points mapping the border. Default: `4`
- `frequency` (number): Rotation speed scaler. Same sign convention as Pixel — positive = faster (`period = 1 / frequency`); `0` or unset = engine baseline (8s); negative = slower (`period = baseline * (1 + |frequency| * 8)`). Default: unset.
- `scale` (number): Scaling scalar on each particle. Default: `1`

## Best practices

- Always provide a specific `key`. If your addon renders multiple glows to the same frame (e.g. tracking multiple auras), failure to provide a key will overwrite the `"Default"` bucket.
- Always pair a single `lib.Show` explicitly with a single `lib.Hide` when out of combat. This returns frames to the pool explicitly.
