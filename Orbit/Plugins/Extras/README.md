# extras

small, standalone plugins that do not fit into a larger bounded context.

## purpose

self-contained features that enhance the hud but aren't big enough to justify their own domain folder. if a file here grows to need siblings, promote it to its own domain directory instead of expanding this folder.

## files

| file | responsibility |
|---|---|
| TalkingHead.lua | reskins and repositions the talking head npc dialog frame. |
| MinimapButton.lua | custom animated launcher icon. Standard edit-mode frame (UIParent-parented, draggable in Edit Mode). Layered atlases: black round-masked backdrop, ChallengeMode circle glow, rotating round-masked Darktrait-Glow, rotating UF-Arcane orb, hover-pulse UF-Arcane OuterFX, looping rotating round-masked shop-toast sparkles, and a static rotating dragonriding sgvigor burst. Left-click toggles Edit Mode + Global options; right-click opens advanced settings. Listed in `PLUGIN_GROUPS` as "Minimap Button". Single setting: Scale (50–150%). Position persisted via the standard Orbit `AttachSettingsListener` / `RestorePosition` flow. |

## adding a new extras plugin

1. create a new lua file in this directory
2. register via `Orbit:RegisterPlugin("New Extra", SYSTEM_ID, { defaults = { ... }, OnLoad = function(self) ... end })`
3. keep it self-contained. if it grows to need multiple files, promote it to its own domain directory
4. declare plugin schema defaults inline in the `defaults = { ... }` block of the options table passed to `RegisterPlugin`. Do not edit `DefaultProfile.lua` — that file is a saved-layout snapshot owned by ProfileManager, not the plugin-schema default site.
5. add the new file to the extras module's `.xml` bundle as a `<Script file="NewFile.lua"/>` entry; ensure it loads after its dependencies

## rules

- extras plugins must not depend on other plugins
- if an extras plugin grows to need multiple files, promote it to its own domain directory
