# shared

project-wide constants and media registrations. loaded before all other core modules.

## purpose

provides the single source of truth for numeric constants, layer indices, color presets, and registered media assets (fonts/textures via libsharedmedia).

## files

| file | responsibility |
|---|---|
| Constants.lua | all project constants: colors, layer indices, cooldown system indices, padding values, glow configurations. |
| Media.lua | libsharedmedia registrations for custom fonts and textures. |

## adding a new constant

1. add it to the appropriate section in `Constants.lua`
2. reference it via `Orbit.Constants.YourSection.YourConstant`
3. never duplicate the value inline in another file

## rules

- no executable logic. only declarations.
- no references to any other module (no `require`, no `Orbit.Engine`)
- constants must be grouped by domain (colors, layers, cooldown indices, etc.)
- magic numbers found anywhere else in the codebase must be extracted here or to the consuming file's top-level constants
