# statusbars

progression bars with canvas-managed text components. experience bar auto-switches across three modes — **xp** (while leveling), **delve companion** (while inside a delve), **watched reputation** (at max level or when xp is user-disabled). honor is a separate bar. both support canvas mode with three independently-positionable text components (Name / Level / Value).

supporting features: rich tooltips, session rate + eta, pending-quest xp overlay, percentage block tick marks, warband-rep indicator, smooth fill animation, spark, level-up flash + sound, chat ding announce, click-to-open-panel, shift-click chat link, right-click context menu, scroll to cycle watched factions, configurable text templates, minimum-level gate.

## plugins

| system id | name | display |
| --- | --- | --- |
| `Orbit_ExperienceBar` | experience bar | xp while leveling → watched reputation at max level. handles paragon + major-faction (renown) branches |
| `Orbit_HonorBar` | honor bar | pvp honor progress and honor level |

## file structure

| file | responsibility |
| --- | --- |
| `TextTemplate.lua` | token engine for value rendering (`{cur}`, `{pct}`, `{rested}`, `{tolevel}`, `{perhour}`, `{eta}`, `{session}`, `{cycles}`, `{pending}`, `{pendingpct}`) |
| `PendingXP.lua` | quest-log scanner: sums XP rewards for quests that are ready to turn in |
| `SessionTracker.lua` | per-bar session state persisted in `AccountSettings.StatusBarSessions`; survives `/reload`, new session after 30m idle |
| `Tooltip.lua` | rich hover tooltips for XP / Rep / Honor / Delve with session stats, ETA, pending-xp, warband indicator, paragon cycles |
| `StatusBarBase.lua` | shared factory: container + bar/overlay/bg/pending/spark/flash/ticks, canvas attachment, smooth-fill mixin, click dispatch, blizzard hide helper. registers `BarLevel` + `BarValue` canvas-dock schemas at file load. block ticks via `SetTickMarks(container, percent)` — percent ∈ {10, 25, 33, 50}. |
| `ExperienceBar.lua` | three-mode (xp / delve / rep) plugin: auto-switch, rested overlay, percentage block tick marks, warband indicator, auto-watched faction, scroll to cycle recent factions, tabbed schema (Layout + Color + Behaviour) |
| `HonorBar.lua` | honor plugin: honor value + level, optional pvp-only gate, tabbed schema |
| `StatusBars.xml` | load bundle — helpers (TextTemplate/PendingXP/SessionTracker/Tooltip) load first so they're available when plugins register; then StatusBarBase; then the two plugins. |

## canvas text components

each bar container holds three canvas-managed text frames — `container.Name`, `container.Level`, `container.Value` — each a `Frame` with a single `OVERLAY` `FontString` child. each exposes its FontString as `frame.visual` so `OverrideUtils.ApplyOverrides` can apply font / size / color overrides per component.

| component key | schema source | content (xp) | content (rep) | content (honor) |
| --- | --- | --- | --- | --- |
| `Name` | existing `STATIC_TEXT` (`Core/CanvasMode/ComponentSettingsSchema.lua`) | "Experience" | faction name | "Honor" |
| `BarLevel` | registered by `StatusBarBase.lua` | `Lvl N` | `Renown N` or reaction label ("Revered" etc.) | `Honor N` |
| `BarValue` | registered by `StatusBarBase.lua`, includes `ValueMode` dropdown (`plugin = true`) | current / max / percent of xp | current / max / percent of rep tier | current / max / percent of honor |

the `ValueMode` dropdown lives in the Value component's canvas-dock panel. because it's `plugin = true`, changing it writes to `plugin:SetSetting(systemIndex, "ValueMode", value)` and applies to the selected plugin's bar only.

## settings dialog (Layout / Color tabs)

both plugins use `SB:AddSettingsTabs` with `{ "Layout", "Color" }`:

- **Layout**: Width (100–1200), Height (4–40), `Tick` (leading-edge tick width, 0–10), `Blocks` (block-tick interval — 10/25/33/50%, xp bar only), `Hide Below Level` (xp bar only), + honor-only `OnlyInPvP` checkbox
- **Color**: `BarColor` (`colorcurve`, `singleColor = true`) — fill colour. experience-bar reputation mode still uses reaction / renown / paragon colours (user colour is only applied in xp mode).

per-component font / size / color live in each component's canvas dock (not in the main settings dialog).

## default component positions

configured in `Core/Plugin/DefaultProfile.lua`:

```
Name     → LEFT edge,   offset  +5, justify LEFT
BarLevel → CENTER,      offset   0, justify CENTER
BarValue → RIGHT edge,  offset  -5, justify RIGHT
```

positions persist per-plugin-per-profile and auto-save on drag via `ComponentDrag:MakePositionCallback`.

## data sources & secret-value handling

bar fill goes through `StatusBar` sinks guarded with `issecretvalue()` in `StatusBarBase:SetFill`. arithmetic for percent/rested overlay runs only when both xp values are non-secret; inside encounters the bar keeps its last non-secret fill and the rested overlay hides. `FontString:SetText` is guarded for the current/max display modes.

| source | api | secret in combat? |
| --- | --- | --- |
| xp | `UnitXP`, `UnitXPMax`, `GetXPExhaustion`, `UnitLevel`, `GetMaxPlayerLevel`, `IsXPUserDisabled` | xp values secret inside m+/raid encounters |
| reputation | `C_Reputation.GetWatchedFactionData`, `C_Reputation.IsFactionParagon`, `C_Reputation.GetFactionParagonInfo`, `C_MajorFactions.GetMajorFactionData` | non-secret |
| honor | `UnitHonor`, `UnitHonorMax`, `UnitHonorLevel` | honor values secret inside encounters |

## events

| plugin | wow events |
| --- | --- |
| experience | `PLAYER_XP_UPDATE`, `UPDATE_EXHAUSTION`, `PLAYER_LEVEL_UP`, `DISABLE_XP_GAIN`, `ENABLE_XP_GAIN`, `UPDATE_FACTION`, `QUEST_FINISHED`, `MAJOR_FACTION_UNLOCKED` |
| honor | `HONOR_XP_UPDATE`, `HONOR_LEVEL_UPDATE`, `ZONE_CHANGED_NEW_AREA` |

both also inherit `RegisterStandardEvents` (apply on `PLAYER_ENTERING_WORLD`, colours changed, edit mode enter/exit) and `RegisterVisibilityEvents` (hide in pet battles / vehicles). `canvasMode = true` auto-subscribes to `CANVAS_SETTINGS_CHANGED` for live preview.

## edit-mode integration & taint

- both plugins register via `OrbitEngine.Frame:AttachSettingsListener` / `RestorePosition`; they're independently draggable with their own edit-mode handles. `orbitWidthSync` / `orbitHeightSync` = true so chained bars inherit dimension changes.
- `anchorOptions` sets `mergeBorders = true` — when the two bars are snapped edge-to-edge at padding 0, their adjacent borders collapse into a single group border (`Orbit.Skin:UpdateGroupBorder`). `StatusBarBase:ApplyTheme`'s `SkinBorder` call installs the `SetBorderHidden` hook the merge mechanism needs.
- `ApplySettings` does its non-secret work synchronously (size / theme / overrides / position) and defers `UpdateBar` via `C_Timer.After(0, …)` — secret reads then happen outside blizzard's synchronous edit-mode-exit callback (see `Core/Plugin/PluginMixin.lua`: Exit is non-debounced).
- `StatusBarBase:SetFill` / `SetOverlayFill` guard with `issecretvalue()` so the StatusBar widget never stores secret internal state.
- `orbitResizeBounds = { minW=100, maxW=1200, minH=4, maxH=40 }` clamps drag-resize to the same range as the layout sliders.

## blizzard native hide

both plugins replace slots in blizzard's `StatusTrackingBarManager`. because that manager is shared:

- `StatusBarBase:HideBlizzardTrackingBars()` calls `NativeFrame:SecureHide(StatusTrackingBarManager)`. idempotent, combat-safe no-op.
- each plugin's `OnLoad` calls it (state 1: orbit on → blizzard manager hidden).
- each plugin registers `Orbit:RegisterBlizzardHider(<name>, fn)` so state 2 (orbit off + blizzard hidden) fires on login via `Core/Init.lua`.

tri-state checkbox (plugin manager → ui):
- **checked** — orbit bar on; blizzard manager hidden by `OnLoad`.
- **empty** — orbit bar off; blizzard manager visible.
- **cross** — orbit bar off; blizzard manager hidden via registered hider at login.

state transitions require a ui reload (standard for tri-state plugins).

## visibility engine

both plugins are registered in `Core/Plugin/VisibilityEngine.lua`'s `FRAME_REGISTRY` (`ExperienceBar` → `Experience Bar`, `HonorBar` → `Honor Bar`) so the standard opacity / out-of-combat fade / mounted-hide / mouseover / show-with-target / alpha lock columns apply to each bar independently. `ApplySettings` calls `Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, SYSTEM_ID)` on the container so VE settings flow through the same `SetAlpha` hook used by every other Orbit frame.

the blizzard `StatusTrackingBar` entry uses multi-owner `ownedBy = { "Experience Bar", "Honor Bar" }` — when **either** orbit bar is enabled, the blizzard slider entry is filtered out of the visibility-engine table (it's already secure-hidden anyway). only when both orbit bars are disabled does the blizzard entry appear so the user can configure it directly.

## container layout

```
container (Frame, edit-mode handle)
├── bg        (Texture BACKGROUND)
├── Overlay   (StatusBar, level + 1)    — rested xp overlay (hidden in rep/honor)
├── Bar       (StatusBar, level + 2)    — primary fill; colour from BarColor (xp/honor) or faction (rep)
└── TextFrame (Frame, level + Overlay)
    ├── Name   (Frame with .Text FontString) — canvas component
    ├── Level  (Frame with .Text FontString) — canvas component key `BarLevel`
    └── Value  (Frame with .Text FontString) — canvas component key `BarValue`
```

border + backdrop come from `Orbit.Skin:SkinBorder` + `GlobalSettings.BackdropColour`; bar texture + base font come from `LSM:Fetch` on `GlobalSettings.Texture` / `GlobalSettings.Font`. per-component overrides stack on top.
