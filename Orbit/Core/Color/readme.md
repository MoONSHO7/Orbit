# color

color resolution systems. converts abstract color identifiers into concrete rgb values.

## purpose

decouples color logic from rendering. plugins and skinning ask "what color should this be?" and color resolvers answer without knowing who asked.

## files

| file | responsibility |
|---|---|
| ClassColorResolver.lua | resolves player/unit class to rgb. handles class-specific overrides. |
| ReactionColorResolver.lua | resolves unit reaction (friendly/hostile/neutral) to rgb. |
| ColorCurveEngine.lua | evaluates multi-stop color curves at a given progress value (0-1). powers gradient bars and dynamic timer colors. |

## adding a new color resolver

1. create a new resolver file in this directory
2. implement it as a stateless function: `input -> { r, g, b, a }`
3. register it in the appropriate consumer (skinning or unitdisplay)
4. add to `Orbit.toc` in the color section

## rules

- resolvers must be pure functions (no side effects, no frame references)
- the color curve engine is the only system that evaluates gradients. do not implement gradient sampling elsewhere
- all color tables must use `{ r, g, b, a }` format, never indexed arrays
