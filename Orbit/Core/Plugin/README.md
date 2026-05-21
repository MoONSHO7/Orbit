# plugin

plugin lifecycle management. handles registration, profile persistence, and shared behavior mixins.

## purpose

defines how plugins register with orbit, how their settings are stored and retrieved, and the shared behavioral contracts (ooc fade, native bar behavior) that plugins can opt into.

## files

| file | responsibility |
|---|---|
| PluginMixin.lua | base mixin applied to all plugins. provides `GetSetting`, `SetSetting`, `IsComponentDisabled`, and spec-scoped storage (`GetCurrentSpecID`, `GetCharSpecStore`, `GetSpecData`, `SetSpecData`) layered under `Orbit.db.SpecData[charKey][specID][systemIndex][key]`. auto-subscribes to `PLAYER_ENTERING_WORLD`, `COLORS_CHANGED`, and `CANVAS_SETTINGS_CHANGED` via debounced `ApplySettings`. `Orbit:ReadPluginSetting(system, systemIndex, key)` is a separate method on the `Orbit` namespace, not a PluginMixin method. |
| Registry.lua | system registration table. `Engine:RegisterSystem` / `Engine:GetSystem` / `Engine.SystemMixin`. |
| ProfileManager.lua | profile crud (create, copy, delete, switch). fires `ORBIT_PROFILE_CHANGED`. |
| DefaultProfile.lua | default settings for every plugin and system index. |
| OOCFadeMixin.lua | out-of-combat fade behavior. frames register and auto-fade when not in combat. reads settings from VisibilityEngine. |
| VisibilityState.lua | `Orbit.Visibility:ApplyState` — applies a `visibility` state driver to a plugin frame from a numeric mode (show / hide / show-in-combat / hide-in-combat). defers the whole body via `CombatManager` when combat-locked and caches the last driver to skip redundant `RegisterStateDriver` calls. |
| VisibilityEngine.lua | centralized visibility settings for all orbit frames. stores oocFade, opacity, hideMounted, mouseOver, showWithTarget per-frame in `Orbit.db.VisibilityEngine`. fires `ORBIT_VISIBILITY_CHANGED`. |
| NativeBarMixin.lua | shared scale/layout/interaction for native blizzard bar wrappers. |

## adding a new mixin

1. create the mixin file in this directory
2. define the mixin as a table on `Orbit` (e.g., `Orbit.NewMixin = {}`)
3. plugins apply the mixin in their `ApplySettings` by calling the mixin directly
4. add a `<Script file="..."/>` entry to `Core/Plugin/Plugin.xml` after PluginMixin.lua — never list individual `.lua` files in `Orbit.toc` for a module that has its own XML bundle. profile-related files load via the sibling `Core/Plugin/Profiles.xml` bundle.

## adding a new plugin

plugins do not live here. they live in `Plugins/`. this domain only provides the infrastructure they consume.

## rules

- mixins must be stateless per-frame (state lives on the frame, not the mixin)
- `DefaultProfile.lua` is a saved-layout snapshot owned by ProfileManager, not the plugin-schema default site. plugin schema defaults belong inline in the `defaults = { ... }` block passed to `RegisterPlugin`.
- never add plugin-specific logic to PluginMixin. if only one plugin needs it, it belongs in that plugin
- profile operations must fire `ORBIT_PROFILE_CHANGED` so consumers can react
- profiles are user-created with semantic names (e.g., "Healer", "Tank M+"), not auto-generated from spec names
- the "Global" profile is the global fallback — unmapped specs use Global
- active profile is tracked per-character in `Orbit.db.charActiveProfiles[charKey]`. new characters default to Global
- spec-to-profile mapping is stored in `Orbit.db.specMappings[specID] = profileName`
- plugins can declare `disabledSpecs = { [specID] = true }` in their registration mixin to disable for specific specializations. the plugin manager will grey out the checkbox and `IsPluginEnabled` returns false for locked specs
