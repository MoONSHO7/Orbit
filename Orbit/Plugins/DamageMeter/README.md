# damage meter

multi-instance, minimal-chrome damage/healing/etc. meter on top of blizzard's native 12.0 data pipeline (`C_DamageMeter.*` + `DAMAGE_METER_*` events). the native blizzard UI is hidden; orbit-owned frames do all rendering; configuration is split between a small layout dialog (bar height / gap / icon position + **New Meter** button) and an in-world right-click menu (metric selector, reset sessions, delete).

## purpose

blizzard ships the data, we ship the UI. users create up to `MaxMeters` meters (one per metric, typically: one DPS, one HPS, one interrupts in a raid). each meter is a bar list with an orbit-theme border + font and mouse-wheel scrolling. a seed meter at id `1` is auto-created on load and cannot be deleted so there's always at least one meter on screen; additional meters are created from the **New Meter** button in the settings dialog footer and can be removed via the in-world context menu.

## files

| file | responsibility |
|---|---|
| DamageMeterConstants.lua | plugin constants (system id, meter/session enum values, event signal names, seed id, meter cap, border/background/title/icon-position enums, default def baseline, position templates, frame-level stride, stretch bounds, metric→label-key map, session-window count). every magic number used outside this file goes here first. |
| DamageMeter.lua | plugin registration, lifecycle, meter-def factory (`CreateMeter`, `DeleteMeter`, `UpdateMeterDef`, `EnsureSeedMeter`), view-mode transitions (`EnterBreakdown`/`ExitBreakdown`/`EnterHistory`/`ReturnToChart`), combat-start snap (`SnapAllMetersToCurrent`), blizzard addon bootstrap, session-window priming, per-meter Get/Set routing through `MeterDefs[id]`. |
| DamageMeterData.lua | thin adapter over `C_DamageMeter.*`. sink-only; never arithmetic on returned numbers. |
| DamageMeterEventBridge.lua | forwards `DAMAGE_METER_*` to `ORBIT_DAMAGEMETER_*` on `Orbit.EventBus`. |
| DamageMeterDisable.lua | neutralizes blizzard's `DamageMeter` frame and its session windows — offscreen, invisible, no mouse. hooks `UpdateShownState` to re-hide on every show attempt. the hidden session window keeps blizzard's event pipeline alive. |
| DamageMeterSettings.lua | two-tab settings dialog. footer carries a **New Meter** extraButton (labelled `New Meter (n/max)` at cap). **Layout**: per-meter styling (bar height, bar gap, icon position, title, border, background) routed through plugin Get/Set overrides into `MeterDefs[id]`. **Behaviour**: plugin-global toggles — `AutoSwitchToCurrent` (Orbit profile setting) and a CVar proxy for `damageMeterResetOnNewInstance`. |
| DamageMeterUI.lua | the meter. multi-instance factory: one frame per meter def, rendered from `C_DamageMeter` via sink-only writes. three view modes (chart / breakdown / history) toggled by clicks. mouse-wheel scrolls rank offset. edit-mode preview renders dummy class-colored data. drag-to-reposition stores absolute pixel offset; no quadrant snapping. `RenderBreakdownView` (the breakdown branch, extracted) plus the exposed `BuildBreakdownFrame`/`LayoutBreakdownFrame`/`RenderBreakdownFrame` trio let the popup module reuse the exact bar rendering for a separate frame. |
| DamageMeterBreakdownPopup.lua | transient breakdown windows for the **Mouseover** and **Detached** breakdown modes. owns the popup registry (one shared mouseover popup + one detached window per meter), builds a synthetic def = the live meter def's styling + the clicked/hovered source's breakdown target, and drives them via the UI's breakdown-frame API. border/background are coerced frame-wide (a popup is one panel, never per-bar). both popups show the **full** breakdown — `FitAllSpells` overrides the inherited bar count with the source's spell count (capped at `MaxBarsStretch`, the meter's own row ceiling), so they aren't limited to the meter's row count and need no scroll. `AnchorBeside` flips horizontally and vertically so a tall popup stays on screen. mouseover popup is non-interactive and follows the hovered bar; detached popup is draggable, right-click to close. `RenderBreakdownPopups` is combat-guarded (source GUIDs go secret in combat). nothing is persisted — popups self-hide on combat start, profile change, Edit Mode, meter delete, and `/reload`. |
| DamageMeterComparison.lua | popup `OrbitDamageMeterComparison` window opened by `Plugin:OpenSpecComparison(meterID, originSource)`. compares the meter's current source against per-spec averages — class-coloured stack bars per spell, M+ gold-timer crown atlas on the overall winner. amounts are `issecretvalue`-laundered at gather time (`GatherSpellMatrix`) so the layout math never touches a secret; `SafeFormatDuration` for the durations. |

removed vs the earlier draft: phases, session archive, chat report, smart-anchor quadrant flipping. if you're reintroducing any of these, update this table.

## secret value discipline

`source.totalAmount`, `amountPerSecond`, `maxAmount`, `durationSeconds`, `deathTimeSeconds` are potentially secret in combat. the render path only writes them to sinks:

- `StatusBar:SetMinMaxValues(0, maxAmount)` / `SetValue(totalAmount)` — status bar is a sink.
- `FontString:SetFormattedText("%s", AbbreviateLargeNumbers(totalAmount))` — `AbbreviateLargeNumbers` is the C-side formatter blizzard's own entry mixin uses on the same values.
- `FontString:SetFormattedText("%d. %s", rank, source.name)` — `source.name` is ConditionalSecret, safe for SetText sinks.

never compared, never arithmetic-ed. `combatSources` is already server-ranked so no lua sort needed.

**duration formatting** — `SafeFormatDuration(seconds)` is the only legal way to turn a `durationSeconds`/`deathTimeSeconds` into a rendered string. it guards with `issecretvalue()` before the `math.floor`/`%`/division inside `FormatDuration`; tainted values render as `""` until combat ends. history-view bar scaling skips the max-duration scan entirely when any entry is secret — bars fall back to 1.0 denominator (full width) rather than arithmeticing on tainted numbers.

**identifiers & the combat-transition race** — `sourceGUID`/`sourceCreatureID` and session/source `name` are secret in combat, and `name` is ConditionalSecret *independently* of the GUID (either can be secret while the other isn't, so guarding the GUID alone is not enough). `InCombatLockdown()` is **not** a sufficient gate: it can read `false` while a struct field is already secret, and a throttled hover/ticker or a click can fire in that window. so secret-prone identifiers are `issecretvalue()`-guarded at the boundaries where they would otherwise enter a throwing op:

- `DamageMeterData:ResolveSessionSource` is the single chokepoint for the `C_DamageMeter.GetCombatSession*` calls — all `AllowedWhenUntainted`, so a secret GUID/creatureID arg throws. it returns `nil` when either identifier is secret, covering every caller (breakdown render, mouse-wheel, row-count, comparison, popup `FitAllSpells`).
- capture sites (the `EnterBreakdown` drill-in call, `TargetFromSource`) reject or blank a secret GUID/name before it lands in a meter or synthetic def — otherwise it later throws in `UpdateMeterDef`'s `== Plugin.CLEAR` or `BuildTitleText`'s `~= ""`.
- gather / compare / atlas sites (`GetSpecMatches`, `GatherSpellMatrix`, `PickHistoryAtlas`) guard before the `~=` / table-key / `:sub`; downstream layout math then runs only on laundered plain numbers.
- combat-end re-fetch: each bar caches a `bar._source` whose `sourceGUID` was captured mid-fight (secret), and secrets never un-secret — so the drill-in's `issecretvalue` gate would stay tripped after combat even though `InCombatLockdown()` has cleared. `PLAYER_REGEN_ENABLED` sets `_renderDirty` so the next UITicker re-renders the bars from a fresh, now-non-secret `C_DamageMeter` fetch. without it the breakdown only un-blocks on a session reset or the next `DAMAGE_METER_*` update.

## lifecycle

```
RegisterPlugin → OnLoad → EnsureBlizzardAddonLoaded / cvar
                        → InitEventBridge → InitUI
                        → RebuildAllMeters
                        → RegisterStandardEvents → RegisterVisibilityEvents
PLAYER_ENTERING_WORLD   → EnsureBlizzardAddonLoaded / cvar
                        → (0.5s) EnsureSessionWindowShown → DisableBlizzardMeter
ORBIT_PROFILE_CHANGED   → (0.15s) RebuildAllMeters

RebuildAllMeters (internal) → EnsureSeedMeter → NormalizeMeterDefs → ScrubStaleAnchors → stale-frame teardown → layout all defs
```

NormalizeMeterDefs is the field-level self-heal: every def is backfilled from `DM.DefaultDef`
(barCount/Width/Height/Gap, iconPosition, style, border, background, title, titleSize) so partial
defs from legacy profiles can't hit the render path with nil styling fields. it also rewrites any
array-form `disabledComponents` into hash form so `IsComponentDisabled` stays O(1).

ScrubStaleAnchors is the child-side self-heal: every def whose `anchor.target` no longer
resolves to a live meter has its current visual position snapshotted into `def.position`
and its `anchor` cleared. Parent-deletion never walks into children — the child's def
detects the stale target on the next rebuild and reverts to a free position on its own.

frames are built eagerly at `OnLoad` (not deferred to `PLAYER_ENTERING_WORLD`) because the plugin can be enabled mid-session and nothing would otherwise draw until the next zone change. PEW stays on the critical path for `DisableBlizzardMeter` because `Blizzard_DamageMeter` loads lazily — the root `DamageMeter` frame isn't guaranteed to exist at our `OnLoad`.

`ApplySettings` (wired by `RegisterStandardEvents`) self-heals on profile reset / setting drift: if the live frame registry and `MeterDefs` disagree it rebuilds, otherwise it just relayouts. covers theme changes and edit-mode enter/exit.

## in-world controls

| input | action |
|---|---|
| left-drag | move frame; participates in the standard orbit anchor/snap system. |
| left-click on bar | chart view → drill into that source's spell breakdown — **how** depends on the per-meter **Breakdown** mode: `Click` flips the meter in place, `Detached` pops a draggable window (one per meter, repointed on each click). history view → jump the meter to that session. |
| mouseover bar | `Breakdown = Mouseover` (the **default**): hovering a chart bar pops out that source's breakdown beside the meter (non-interactive, hides on leave). other modes: no hover effect. |
| right-click | chart view → enter history picker. any other view → return to chart. on a **detached** breakdown window → close it. |
| shift + right-click | context menu: metric selector (checkbox of 8 types), reset sessions, delete meter (hidden on the seed id=1). new meters come from the settings dialog footer. |
| left-click on title | opens the same context menu — a discoverable alias for shift + right-click. mouse is disabled on the title in edit mode so it never intercepts selection/drag. |
| mouse-wheel | scroll through ranks (shifts `scrollOffset`, clamped to `[0, sources - barCount]`). |
| edit mode | selectable frame (standard orbit protocol: `systemIndex`, `editModeName`, `orbitPlugin`, `.Selection` overlay, `AttachSettingsListener`). preview populates with dummy data at full bar count. vertical resize writes `TotalHeight`, which the plugin converts into barCount. |

## rules

- layout dialog has two tabs: **Layout** for per-meter styling, **Behaviour** for plugin-global toggles (auto-switch on combat, auto-reset-on-instance CVar proxy). the footer's **New Meter** button is the only create path (cap `DM.MaxMeters`, label suffixed `(n/max)` at cap); metric + delete live in the in-world right-click menu.
- meter id `1` is the seed: auto-created on load and persisted. `DeleteMeter` is a no-op for it, and its context menu has no Delete entry.
- skin inherits `Orbit.db.GlobalSettings` — font, bar texture, border size/style. no per-meter override.
- `Plugin:ApplySettings` only re-renders / relayouts; it NEVER calls into blizzard's DamageMeter mutators (that taints the entry data provider — see DamageMeterDisable.lua comment).
- bars always stack top-to-bottom (rank 1 at the top); fill always grows left-to-right.

## anchoring

meters support anchoring to any edge (TOP, BOTTOM, LEFT, RIGHT) via the standard orbit snap/anchor system. only `orbitWidthSync` is set — T/B stacking propagates root width down the stack; L/R placement is a plain anchor with no cross-axis sync (height is owned by the DM, not the parent).

**vertical stacking (T/B anchor).** DPS → HPS → Interrupts stacked:
- `orbitWidthSync` propagates the root meter's width down the chain — change the top meter's BarWidth and all stacked meters follow.
- engine treats the stack as one rectangle — other orbit frames snap against the full stack's outer edges, not individual members.

**lateral placement (L/R anchor, no sync).** dropping a DM onto the LEFT or RIGHT edge of another orbit frame (UnitFrames, Tracked, another DM, etc.) parks the DM beside it. No height sync runs: DM height is derived from `barCount × barHeight + gaps` and stays under the plugin's control. Users resize via the stretch tab / TotalHeight, bar height, or bar gap — a parent frame's height never overrides these.

drag uses the standard orbit anchor/snap flow; there is no quadrant-flip or auto-mirror on drop.
