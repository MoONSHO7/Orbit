# misc

standalone utility plugins that do not fit into other domains.

## purpose

small, self-contained features that enhance the hud without belonging to any major system.

## files

| file | responsibility |
|---|---|
| TalkingHead.lua | reskins and repositions the talking head npc dialog frame. |

## adding a new misc plugin

1. create a new lua file in this directory
2. register via `Orbit:RegisterPlugin("Orbit_NewMisc", { ... })`
3. keep it self-contained. if it grows beyond ~200 loc, consider promoting it to its own domain
4. add to `Orbit.toc` and `DefaultProfile.lua`

## rules

- misc plugins must not depend on other plugins
- if a misc plugin grows to need multiple files, promote it to its own domain directory
