# menu items

native blizzard ui bar plugins: micro menu, bag bar, and queue status.

## purpose

captures and reskins blizzard's native utility bars. uses `NativeBarMixin` from core/plugin for shared scale, layout, and interaction behavior.

## files

| file | responsibility |
|---|---|
| MicroMenu.lua | micro menu bar (character, spellbook, talents, etc.). captures native buttons. |
| BagBar.lua | bag slot bar. captures native bag buttons. |
| QueueStatus.lua | dungeon/battleground queue status indicator. |

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

## migration note

`Performance` and `CombatTimer` were moved to the Datatexts plugin in `Plugins/Datatexts/` as richer, free-floating datatexts with sparkline graphs and encounter tracking. see `Plugins/Datatexts/README.md`.
