# plugin

plugin lifecycle management. handles registration, profile persistence, and shared behavior mixins.

## purpose

defines how plugins register with orbit, how their settings are stored and retrieved, and the shared behavioral contracts (ooc fade, native bar behavior) that plugins can opt into.

## files

| file | responsibility |
|---|---|
| PluginMixin.lua | base mixin applied to all plugins. provides `GetSetting`, `SetSetting`, `IsComponentDisabled`, and spec-scoped storage (`GetCurrentSpecID`, `GetCharSpecStore`, `GetSpecData`, `SetSpecData`) layered under `Orbit.db.SpecData[charKey][specID][systemIndex][key]`. `RegisterStandardEvents()` subscribes the plugin's `ApplySettings` (debounced) to the EventBus events `ORBIT_PLAYER_ENTERING_WORLD`, `ORBIT_COLORS_CHANGED`, and `ORBIT_CANVAS_SETTINGS_CHANGED`. `Orbit:ReadPluginSetting(system, systemIndex, key)` is a separate method on the `Orbit` namespace, not a PluginMixin method. |
| Registry.lua | system registration table. `Engine:RegisterSystem` / `Engine:GetSystem` / `Engine.SystemMixin`. |
| ProfileManager.lua | profile crud (create, copy, delete, switch). fires `ORBIT_PROFILE_CHANGED`. |
| DefaultProfile.lua | **layout-only** seed: anchor graph, positions, per-instance state without a schema seed (DamageMeter MeterDefs, Datatexts placements, StrataEngine Z-order), and GlobalSettings theme. NOT a per-setting defaults dump — see "default values" rule below. |
| OOCFadeMixin.lua | out-of-combat fade behavior. frames register and auto-fade when not in combat. reads settings from VisibilityEngine. |
| VisibilityState.lua | `Orbit.Visibility:ApplyState` — applies a `visibility` state driver to a plugin frame from a numeric mode (show / hide / show-in-combat / hide-in-combat). defers the whole body via `CombatManager` when combat-locked and caches the last driver to skip redundant `RegisterStateDriver` calls. |
| VisibilityEngine.lua | centralized visibility settings for all orbit frames. stores oocFade, opacity, hideMounted, mouseOver, showWithTarget, alphaLock per-frame in `Orbit.db.VisibilityEngine`. fires `ORBIT_VISIBILITY_CHANGED`. |
| NativeBarMixin.lua | shared scale/layout/interaction for native blizzard bar wrappers. |

## adding a new mixin

1. create the mixin file in this directory
2. define the mixin as a table on `Orbit` (e.g., `Orbit.NewMixin = {}`)
3. plugins apply the mixin in their `ApplySettings` by calling the mixin directly
4. add a `<Script file="..."/>` entry to `Core/Plugin/Plugin.xml` after PluginMixin.lua — never list individual `.lua` files in `Orbit.toc` for a module that has its own XML bundle. profile-related files load via the sibling `Core/Plugin/Profiles.xml` bundle.

## adding a new plugin

plugins do not live here. they live in `Plugins/`. this domain only provides the infrastructure they consume.

## default values: where they live

Two layers, never duplicate between them:

1. **Plugin schema defaults** — the per-setting source of truth. Live inline in the `defaults = { ... }` block passed to `RegisterPlugin(name, system, { defaults = {...} })`, or for shared behaviors on a mixin table (e.g. `Orbit.UnitAuraGridMixin.sharedDebuffDefaults`, `Orbit.UnitPowerBarMixin.sharedDefaults`). Every per-setting fallback — `Scale`, `IconSize`, `IconPadding`, `Opacity`, `MaxRows`, color curves, ComponentPositions, DisabledComponents, glow type, etc. — belongs here. `ProfileManager` resolves an unset key by walking: active profile → schema default. If a new setting needs a default, add it here.

2. **`DefaultProfile.lua` — layout-only snapshot.** Seeds exactly what the schema cannot express on a clean install:
    - `Position` and `Anchor` — where each plugin frame sits on screen and what it docks to.
    - Per-instance state with no schema seed — `Orbit_DamageMeter.MeterDefs` array shape (NormalizeMeterDefs backfills field-level defaults from `DM.DefaultDef`), `Orbit_Datatexts.datatextPositions`, `Orbit_StrataEngine.entities` Z-order.
    - Cross-instance conflicts the shared mixin can't carry — e.g. `Orbit_TargetPower` wants Width=205 but FocusPower (same mixin) wants Width=200; the override lives in DefaultProfile because the mixin defaults can hold only one value.
    - `GlobalSettings` — theme seeds (Font, Texture, BorderSize, BarColorCurve, etc.) that ProfileManager clones on profile switch.

**Test before adding a key to DefaultProfile.lua**: *"could this value live in the plugin's `defaults = {}` block instead?"* If yes, put it there. Echoing the schema default in DefaultProfile is duplication that drifts the moment the schema changes.

**Never put in either site**: runtime caches (`_sorted`, `_hasClassPin` on color curves — `Engine.ColorCurve` builds them lazily from `pins`) or migration sentinels (`DisabledComponentsMigrated`, `TrackedMigrationComplete`).

## rules

- mixins must be stateless per-frame (state lives on the frame, not the mixin)
- `DefaultProfile.lua` is a saved-layout snapshot, not the plugin-schema default site. See the "default values" section above.
- never add plugin-specific logic to PluginMixin. if only one plugin needs it, it belongs in that plugin
- profile operations must fire `ORBIT_PROFILE_CHANGED` so consumers can react
- profiles are user-created with semantic names (e.g., "Healer", "Tank M+"), not auto-generated from spec names
- the "Global" profile is the global fallback — unmapped specs use Global
- active profile is tracked per-character in `Orbit.db.charActiveProfiles[charKey]`. new characters default to Global
- spec-to-profile mapping is stored in `Orbit.db.specMappings[specID] = profileName`
- plugins can declare `disabledSpecs = { [specID] = true }` in their registration mixin to disable for specific specializations. the plugin manager will grey out the checkbox and `IsPluginEnabled` returns false for locked specs
