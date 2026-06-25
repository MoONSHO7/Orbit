# plugin

plugin lifecycle management. handles registration, profile persistence, and shared behavior mixins.

## purpose

defines how plugins register with orbit, how their settings are stored and retrieved, and the shared behavioral contracts (ooc fade, native bar behavior) that plugins can opt into.

## files

| file | responsibility |
|---|---|
| PluginMixin.lua | base mixin applied to all plugins. provides `GetSetting`, `SetSetting`, `IsComponentDisabled`, and spec-scoped storage (`GetCurrentSpecID`, `GetCharSpecStore`, `GetSpecData`, `SetSpecData`) layered under `Orbit.db.SpecData[charKey][specID][systemIndex][key]`. `RegisterStandardEvents()` subscribes the plugin's `ApplySettings` (debounced) to the EventBus events `ORBIT_PLAYER_ENTERING_WORLD` and `ORBIT_COLORS_CHANGED`, plus EditMode Enter/Exit. Live Canvas preview is a separate opt-in via `WatchCanvasChanges()` (the single `ORBIT_CANVAS_SETTINGS_CHANGED` subscriber, dispatching through the `OnCanvasLivePreview` hook). `Orbit:ReadPluginSetting(system, systemIndex, key)` and `Orbit:GetTheme(key)` (globally-inherited theme reads) are methods on the `Orbit` namespace, not PluginMixin methods. |
| Registry.lua | system registration table. `Engine:RegisterSystem` / `Engine:GetSystem` / `Engine.SystemMixin`. |
| ProfileManager.lua | profile crud (create, copy, delete, switch). fires `ORBIT_PROFILE_CHANGED`. |
| DefaultProfile.lua | **layout-only** seed: anchor graph, positions, per-instance state without a schema seed (DamageMeter MeterDefs, Datatexts placements, StrataEngine Z-order), and GlobalSettings theme. NOT a per-setting defaults dump — see "default values" rule below. |
| OOCFadeMixin.lua | out-of-combat fade behavior. frames register and auto-fade when not in combat. reads settings from VisibilityEngine. |
| VisibilityState.lua | `Orbit.Visibility:ApplyState` — applies a `visibility` state driver to a plugin frame from a numeric mode (show / hide / show-in-combat / hide-in-combat). defers the whole body via `CombatManager` when combat-locked and caches the last driver to skip redundant `RegisterStateDriver` calls. |
| VisibilityEngine.lua | centralized visibility settings for all orbit frames. stores oocFade, opacity, hideMounted, mouseOver, showWithTarget, alphaLock per-frame in `Orbit.db.VisibilityEngine`. fires `ORBIT_VISIBILITY_CHANGED`. The engine holds **no plugin names** — Orbit-plugin frames are registered at load by `Plugins/VisibilityManifest.lua` (Plugins layer) via `VE:RegisterFrame{ key, display, plugin, index, opacityOnly }`. `BLIZZARD_REGISTRY` (Core's catalog of Blizzard frames) keeps `ownedBy` as a documented, graceful-degrading integration exception. |
| FadeProfiles.lua | named context→fade "groups": each profile fades its member frames to a target opacity when its condition set matches (evaluated via `SecureCmdOptionParse`, the secure game-state axis — NOT secret values). Action is always FADE, never hide. A frame may belong to several profiles; the resolved alpha is the **lowest firing target** (lowest-alpha-wins), and 0% is allowed (a faded-to-0 frame is invisible but still present/clickable — Reveal All and the per-frame note are the safety nets). The resolved value is consumed as a multiplicative **cap** (a `math.min`) by `OOCFadeMixin` (Orbit + insecure Blizzard frames) and `VisibilityEngine.ApplySecureBlizzardFrame` (secure Blizzard frames) — FadeProfiles runs no competing `SetAlpha` loop of its own. Stored in `Orbit.db.FadeProfiles`. Fires `ORBIT_VISIBILITY_CHANGED` (drives apply) and `ORBIT_FADE_PROFILES_CHANGED` (drives the config UI). The condition catalog is runtime-validated against `SecureCmdOptionParse` at load. The **Mouseover** condition is the one exception — it is `perFrame` (no macro conditional exists for "cursor over THIS frame"), resolved live against each member's hover state via the OOCFadeMixin hover ticker (`GetMouseoverAlpha`/`FrameHasMouseoverProfile`), and is unsupported on secure Blizzard frames (no hover ticker — matches VisibilityEngine's "secure frames, no mouseOver" rule). A profile that contains a Mouseover condition therefore applies **no** fade to its secure Blizzard members at all — not even the non-mouseover conditions' cap — because `GetResolvedAlpha` (the only thing `ApplySecureBlizzardFrame` reads) excludes mouseover profiles. This is intentional: pair Mouseover with Orbit/insecure frames; use a plain (no-Mouseover) profile to fade secure Blizzard frames. Mouseover has two modes carried in its condition `state`: `separate` (each member reveals on its own hover) and `group` (any member's hover reveals every member, tracked via `OnFrameHoverChanged`/`anyHovered`). In both modes the fade cap applies only while *not* hovered — i.e. always reveal-on-hover. Each profile carries two opacity values (the range slider in the config — dual-handle when the profile has a Mouseover condition, otherwise a single `fade` handle since `maxOpacity` is inert without one): `fade` (the dimmed opacity, low handle) and `maxOpacity` (the reveal ceiling, high handle, default 100). When mouseover-revealed the cap becomes `maxOpacity` instead of 1.0, so a profile can fade to e.g. 20% and reveal only up to 80%. `maxOpacity` only affects the mouseover-reveal path (`GetMouseoverAlpha`); non-mouseover profiles are pinned at `fade`. |
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
