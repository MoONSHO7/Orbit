# infrastructure

low-level systems that the entire addon depends on. these have no knowledge of plugins, skinning, or ui.

## purpose

provides foundational services: event dispatch, pixel-perfect math, combat state tracking, animation utilities, and async scheduling.

## files

| file | responsibility |
|---|---|
| EventBus.lua | pub/sub event system. wraps both wow events and custom orbit events. |
| Pixel.lua | pixel-snapping math. enforces crisp rendering at any ui scale. fires `ORBIT_DISPLAY_SIZE_CHANGED`. |
| CombatManager.lua | tracks combat state. provides safe-to-mutate guards. |
| Animation.lua | reusable animation utilities (fade, slide, pulse). |
| Async.lua | deferred execution helpers (throttle, debounce). |
| KeybindSystem.lua | keybind resolution for action bar buttons and tracked abilities. |
| TickMixin.lua | tick mark overlay for status bars (recharge segments). |

## adding a new system

1. create a new lua file in this directory
2. attach it to `Orbit.Engine` or `Orbit` namespace as appropriate
3. add the file to `Orbit.toc` in the infrastructure section
4. the system must not reference any plugin, skinning module, or config widget

## rules

- infrastructure files load before everything except shared and libs
- no ui frame creation except for internal event frames
- all systems must be stateless or use explicit init/teardown
- prefer `EventBus:Fire()` over direct function calls for cross-system communication
