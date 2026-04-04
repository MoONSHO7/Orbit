# liborbitglow-1.0

a high-performance utility library for creating and managing visual frame glows, animations, and particle effects. designed primarily for world of warcraft 12.0.0 and above. features unified resource pooling, combat safety, and native reverse playback mathematically.

## usage

the library exposes a simplified facade that abstracts specific animation groups, textures, and geometry engines. consumers only need to ask for a specific glow type and pass an options table.

### showing a glow

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

### hiding a glow

it's crucial to hide glows using the exact same type and key you used to show them, so the library can gracefully stop animations and recycle frames back into the global pool.

```lua
lib.Hide(frame, "Pixel", "myComponentGlow")
```

### combat and secret safety (alpha hiding)

when tracking auras, cooldowns, or power states that return wow 12.0 'secret values', you **cannot** execute logic branches based on those values. this means you cannot conditionally call `lib.Hide()` in response to an aura dropping during combat.

to safely hide glows in these scenarios, you must rely on native alpha propagation or securely update the `options.color` alpha channel to `0` instead of calling `lib.Hide()`.

```lua
-- safe: pass dynamic alpha directly to the library without branching
local alpha = isAuraActive and 1 or 0
lib.Show(frame, "Pixel", { color = { 1, 0, 0, alpha } })
```

## glow types

consumers pass these exact string identifiers to `lib.Show` as the second argument. the engine automatically resolves the underlying math, animation groups, and atlases.

| type | description | engine |
|---|---|---|
| `"Thin"` | thin swirling ants | flipbook |
| `"Thick"` | thick proc loop | flipbook |
| `"Medium"` | standard action bar proc | flipbook |
| `"Static"` | static cooldown manager glow | static |
| `"Classic"` | classic world of warcraft action button flash and ant swirl | manual stepper |
| `"Pixel"` | modern pixel lines tracing the outer border | geometry |
| `"Autocast"` | native pet bar autocast shine squares | geometry |

## global options

these options act globally across almost all glow engines. they are passed as the 3rd argument to `lib.Show(frame, glowType, options)`.

| field | type | description |
|---|---|---|
| `key` | `string` | unique identifier used for tracking and hiding. default: `"Default"` |
| `color` | `table` | `{r,g,b,a}` array or a 12.0 `Color` object. default: white |
| `frameLevel` | `number` | relative frame level above the parent frame. default: `8` |
| `maskIcon` | `boolean` | applies native corner rounding specifically for `frame.icon`. prevents rendering out of bounds. |
| `maskInset` | `number` | pixel distance to inset the mask from the edge. default: `1` |
| `desaturated`| `boolean` | explicitly desaturates underlying atlases. default: `false` |
| `reverse` | `boolean` | dynamically reverses the rotation or movement of the glow mathematically, avoiding mirrored atlases. |

## engine-specific options

specific glow engines support additional fine-tuning properties.

### flipbook engines (`Thin`, `Thick`, `Medium`)
- `scale` (number): multiplier applied to width and height.

### pixel engine (`Pixel`)
- `lines` (number): how many tracing particles are generated. default: `8`
- `frequency` (number): speed scaler affecting the animation loop velocity. default: `0.25`
- `thickness` (number): width of the tracing particles. default: `2`
- `border` (boolean): renders a dark, translucent backdrop strictly inside the pixel bounds to obscure the parent frame slightly for contrast. default: `true`
- `xOffset` / `yOffset` (number): margin expanding the trace tracking box away from the edges.

### autocast engine (`Autocast`)
- `particles` (number): number of points mapping the border. default: `4`
- `frequency` (number): rotation speed multiplier. default: `0` (base)
- `scale` (number): scaling scalar on each particle. default: `1`

## best practices

- always provide a specific `key`. if your plugin renders multiple glows to the same frame (e.g. tracking multiple auras), failure to provide a key will overwrite the `"Default"` bucket.
- always pair a single `lib.Show` explicitly with a single `lib.Hide` when out of combat. this returns frames to the garbage collector explicitly.
- if passing `maskIcon = true`, ensure that `frame.icon` actually exists. the library utilizes `UI-Frame-IconMask` under the hood.
