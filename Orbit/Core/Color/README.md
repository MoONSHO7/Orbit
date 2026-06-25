# color

color resolution systems. converts abstract color identifiers into concrete rgb values.

## purpose

decouples color logic from rendering. plugins and skinning ask "what color should this be?" and color resolvers answer without knowing who asked.

## files

| file | responsibility |
|---|---|
| ClassColorResolver.lua | `Engine.ClassColor`: resolves player/unit class to rgb (`GetOverrides`). reads/writes per-class user overrides in `AccountSettings` (`ClassColor_<CLASS>`); PRIEST defaults to near-white. |
| ReactionColorResolver.lua | `Engine.ReactionColor`: resolves unit reaction (hostile/neutral/friendly) plus renown/paragon to rgb (`GetOverride`). reads/writes per-reaction overrides in `AccountSettings` (`ReactionColor_<TYPE>`). |
| ColorCurveEngine.lua | `Engine.ColorCurve`: evaluates multi-pin color curves at a clamped progress value (0-1) via `SampleColorCurve`; `class`-typed pins resolve through `ClassColor`. powers gradient bars and dynamic timer colors. |

## adding a new color resolver

1. create a new resolver file in this directory, exposing `Engine.<Name>`
2. resolution is `input -> { r, g, b, a }`; user overrides live in `AccountSettings` (account-wide, profile-immune), never in `OrbitDB` layout
3. register the table on `Engine` and call it from the consumer (skinning or unitdisplay)
4. add a `<Script file="..."/>` entry to `Core/Color/Color.xml` in dependency order — never list individual `.lua` files in `Orbit.toc` for a module that has its own XML bundle

## rules

- resolvers hold no frame references and no per-call mutable state; persistent override state belongs in `AccountSettings`
- the color curve engine is the only system that evaluates gradients/curves. do not implement curve sampling elsewhere
- all color tables must use `{ r, g, b, a }` format, never indexed arrays
