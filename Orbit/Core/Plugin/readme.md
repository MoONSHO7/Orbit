# plugin

plugin lifecycle management. handles registration, profile persistence, and shared behavior mixins.

## purpose

defines how plugins register with orbit, how their settings are stored and retrieved, and the shared behavioral contracts (ooc fade, native bar behavior) that plugins can opt into.

## files

| file | responsibility |
|---|---|
| PluginMixin.lua | base mixin applied to all plugins. provides `GetSetting`, `SetSetting`, `IsComponentDisabled`, `ReadPluginSetting`. |
| Registry.lua | plugin registration table. `RegisterPlugin` and `GetPlugin`. |
| ProfileManager.lua | profile crud (create, copy, delete, switch). fires `ORBIT_PROFILE_CHANGED`. |
| DefaultProfile.lua | default settings for every plugin and system index. |
| OOCFadeMixin.lua | out-of-combat fade behavior. frames register and auto-fade when not in combat. |
| NativeBarMixin.lua | shared scale/layout/interaction for native blizzard bar wrappers. |

## adding a new mixin

1. create the mixin file in this directory
2. define the mixin as a table on `Orbit` (e.g., `Orbit.NewMixin = {}`)
3. plugins apply the mixin in their `ApplySettings` by calling the mixin directly
4. add the file to `Orbit.toc` after PluginMixin.lua

## adding a new plugin

plugins do not live here. they live in `Plugins/`. this domain only provides the infrastructure they consume.

## rules

- mixins must be stateless per-frame (state lives on the frame, not the mixin)
- `DefaultProfile.lua` is the single source of truth for all default values
- never add plugin-specific logic to PluginMixin. if only one plugin needs it, it belongs in that plugin
- profile operations must fire `ORBIT_PROFILE_CHANGED` so consumers can react
