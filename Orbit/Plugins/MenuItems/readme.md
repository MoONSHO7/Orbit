# menu items

native blizzard ui bar plugins: micro menu, bag bar, performance display, queue status, and combat timer.

## purpose

captures and reskins blizzard's native utility bars. uses `NativeBarMixin` from core/plugin for shared scale, layout, and interaction behavior.

## files

| file | responsibility |
|---|---|
| MicroMenu.lua | micro menu bar (character, spellbook, talents, etc.). captures native buttons. |
| BagBar.lua | bag slot bar. captures native bag buttons. |
| Performance.lua | fps/latency display widget. |
| QueueStatus.lua | dungeon/battleground queue status indicator. |
| CombatTimer.lua | in-combat duration timer. |

## adding a new menu item plugin

1. create a new lua file in this directory
2. register via `Orbit:RegisterPlugin("Orbit_NewItem", { ... })`
3. use `NativeBarMixin` if capturing native blizzard buttons
4. add default settings in `DefaultProfile.lua`
5. add to `Orbit.toc`

## rules

- all native bar plugins must use `NativeBarMixin` for consistent behavior
- button capture must null-check before reparenting (some buttons may not exist in all game modes)
- hover fade uses the implicit hover pattern (geometry polling), not wow's native mouse events
