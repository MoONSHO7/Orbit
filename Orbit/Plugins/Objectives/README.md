# objectives

reparents blizzard's `ObjectiveTrackerFrame` into a scrollable orbit container with configurable size, border, backdrop, and full skin overhaul. all skinning is hook-based and idempotent — no template replacements, no widget pool manipulation.

## purpose

replace the default objective tracker chrome with orbit's theme: global font, progress bar texture, quest-type-coloured titles, slim atlas POI icons, and per-module collapse persistence. the container is draggable via edit mode and respects visibility engine settings (oocFade, mouseOver, opacity).

## layout

```
Plugins/Objectives/
  ObjectivesConstants.lua    all constants + shared ValidateColor() utility
  ObjectivesPlugin.lua       plugin registration, lifecycle, capture, scroll, collapse, border, backdrop
  ObjectivesSkin.lua         hook-based skinning: headers, blocks, POI, progress bars, timer bars, widgets
  ObjectivesSettings.lua     settings UI: Layout / Behaviour / Colours tabs
  Objectives.xml             load-order bundle
```

## capture

`ObjectiveTrackerFrame` is reparented from `UIParent` (or `UIParentRightManagedFrameContainer`) into `OrbitObjectivesScrollChild`, a child of the main container `OrbitObjectivesContainer`. `OrbitEngine.FrameGuard:Protect` prevents blizzard or other addons from stealing it back. `InCombatLockdown()` is checked before any reparenting — deferred via `CombatManager:QueueUpdate` if locked.

the tracker's native `GetAvailableHeight` is overridden to return 50000, allowing blizzard to render all blocks regardless of visible area. `UpdateHeight` is replaced to track actual module content height and clamp the scroll offset when content shrinks.

## scrolling

mouse wheel scrolling on both the container and the tracker itself, routed through `Plugin:OnScroll` (with `MaxScroll` / `ApplyScrollOffset` / `ClampScroll` helpers). scroll offset is applied by moving the scroll child's anchors relative to the container. content is clipped to the container by `clipFrame` (`SetClipsChildren`). `SCROLL_SPEED = 60`, `SCROLL_BOTTOM_PADDING = 20` adds breathing room at the bottom.

## empty state

when no tracked module has content (`IsTrackerEmpty` — no module with `contentsHeight > 0`), the container's backdrop and border are hidden entirely, restored (per `ShowBorder` / `BackgroundOpacity`) when content returns. re-evaluated (transition-guarded via `RefreshEmptyState`) on the container **`Update` hook** — Blizzard only calls the container's `UpdateHeight` on `OnShow`, so when the last quest drops it hides the now-empty container without re-checking; hooking `Update` catches every relayout — plus at the end of `ApplySettings`. always treated as non-empty in edit mode so the frame stays grabbable.

`IsTrackerEmpty` keys off `tracker:IsCollapsed()`: while collapsed, Blizzard hides every module (`IsShown()` false) but their `contentsHeight` stays positive, so the empty check drops the `IsShown()` gate when collapsed — otherwise a collapsed-but-populated tracker would read as empty and lose its chrome.

## container sizing

the box **content-fits** with **symmetric** top/bottom inset. three pieces:

- **`tracker.UpdateHeight`** (overridden) sets the real content height: `topModulePadding + Σ(visible module contentsHeight) + moduleSpacing·(n−1)`. the master header lives *inside* `topModulePadding` so it isn't added separately; crucially the old formula (`header + ΣcontentsHeight`) omitted Blizzard's `topModulePadding` gap and inter-module `moduleSpacing`, under-counting by `(topModulePadding − header) + moduleSpacing·(n−1)` — which is why the last section got clipped.
- **`DesiredContentHeight`** = the uncapped box height: `tracker height + 2·inset` (full inset top and bottom). there's no divider to hug — when content ends on a collapsed header, that header's trailing separator is hidden by `UpdateSeparators`, so the box just pads evenly. the collapsed-master bar is the same shape: `header + 2·inset` (`CollapsedBarHeight`).
- **`ResolveContainerHeight`** = `min(Height, DesiredContentHeight)`; edit mode → full `Height` (grabbable; the resize handle drives the real setting, which is effectively a *max*).

**header heights track the font.** Blizzard's header frames are a fixed 32px (master) / 26px (module) regardless of font, so a small label floats in a tall bar. `ApplyHeaderFont` instead sizes each header to `max(HeaderFontSize + 2·HEADER_VPADDING, floor)` — floor = the 16px minimize button (`HEADER_MIN_HEIGHT` 20 master, `MODULE_HEADER_MIN_HEIGHT` 18 module) — pixel-snapped. the master write also sets `topModulePadding = masterHeight + GetContentInset()` (replacing Blizzard's fixed 38) — the gap below the master equals the box's content inset, so master→module spacing is uniform with the top/bottom inset — and each module write sets `module.headerHeight` in lockstep, so `CollapsedBarHeight`/`DesiredContentHeight`/`UpdateHeight` (which read these live) all tighten with no gap or clip. `ScenarioObjectiveTracker` is left native (font only) — its collapse/slide math reads `headerHeight`.

**`UpdateSeparators`** owns header-separator visibility: the master separator hides only while the master itself is collapsed (genuinely nothing below it); module separators always show per the `HeaderSeparators` setting, so a collapsed sub-header keeps its divider and reads consistently with the master. `ApplyHeaderSeparator` (in `ApplySkins`) draws each divider pixel-perfect — `Pixel:Multiple(HEADER_SEPARATOR_HEIGHT)` thick, the same distance below the header, re-applied so it tracks UI-scale changes — and sets the colour; `ApplySkins` then calls `UpdateSeparators` synchronously to avoid a flash, and the container `Update` hook re-runs it so collapse/quest changes re-evaluate visibility.

`ContentOverflow` = `DesiredContentHeight − Height` is the single source of truth for "is the box capped": `MaxScroll` reads it — when content fits, overflow ≤ 0 so there's no scroll. driven from the container `Update` hook (every relayout), `tracker.UpdateHeight`, `ApplySettings`, and the `SetCollapsed` hooks; resizing the box can't feed back into the tracker (module-driven height, constant `GetAvailableHeight`), so no oscillation.

the container sets `orbitForceAnchorPoint = "TOPRIGHT"` so the anchor engine always persists a TOP-bearing point — otherwise `Snap:NormalizePosition` collapses the vertical token to center for a tall right-side frame, and `SetHeight` would grow symmetrically about the centre (the collapsed/wrapped box would appear centered). because a *previously* saved position is restored by `Persistence:RestorePosition` verbatim (it does not re-normalize), `HoldTopAnchor` (called from `ApplyContainerHeight`) re-pins a still-centered free anchor to the forced point — preserving the current spot, via the engine's own `FrameSnap:NormalizePosition` — so a stale save self-heals each session and a re-drag persists the TOP point for good. with a TOP anchor the box grows/shrinks downward from a fixed top edge.

## anchoring

the container sets `orbitWidthSync = true`: docked to another orbit frame's top/bottom edge, its width matches that parent. `ApplySettings` skips applying its own width whenever `IsWidthSynced` is true, letting the anchor engine own it.

## skinning

all hooks are installed once in `InstallSkinHooks()` via `hooksecurefunc`. no hooks run unless the `_enabled` flag is true (toggled by `SetSkinEnabled`).

### hooked targets

| target | hook | effect |
|---|---|---|
| `tracker.AddBlock` (per module) | `OnAddBlock` | skin item buttons, checkmarks, fonts; install per-block colour/POI hooks |
| `ObjectiveTrackerBlockMixin.AddObjective` | `OnAddObjective` | hide `ui-questtracker-objective-nub` atlas on objective line icons |
| `ObjectiveTrackerQuestPOIBlockMixin.AddPOIButton` | `SkinPOIButton` | strip native visuals, overlay slim atlas icon, colour title by quest type |
| `tracker.GetProgressBar` | `SkinProgressBar` | strip textures; orbit bar texture; global border + background (surfaces registered masked so a rounded style clips the fill — cast-bar pattern); 25px tall with the reward icon inset square at the left; label hook |
| `tracker.GetTimerBar` | `SkinTimerBar` | same treatment as progress bars |
| `UIWidgetTemplateStatusBarMixin.Setup` | `SkinWidgetStatusBar` | skin widget bars inside the tracker (filtered by `IsUnderObjectivesTracker`) |
| `UIWidgetTemplateIconAndTextMixin.Setup` | `SkinWidgetIconAndText` | hide widget icons, apply font |
| `UIWidgetBaseStateIconTemplateMixin.Setup` | `SkinWidgetStateIcon` | hide widget state icons |
| `UIWidgetTemplateIconTextAndBackgroundMixin.Setup` | `SkinWidgetIconTextAndBackground` | hide icon/glow/bg, apply font |
| `header.SetCollapsed` (per module) | chevron update | refresh `+`/`-` chevron, re-suppress native textures, persist state |
| `header.MinimizeButton.OnClick` (module + master) | replaced | route collapse through `Plugin:ToggleCollapse` (instant) |

### ScenarioObjectiveTracker

header-only skinning. its content frames share blizzard's widget pool — calling methods on them taints the pool and breaks other UI. `AddBlock` / `GetProgressBar` / `GetTimerBar` hooks are skipped for this module.

## POI icons

each quest block's `poiButton` is stripped of native visuals and overlaid with a classification-based atlas icon. title text colour is always derived from quest classification, tag, or focus state, falling back to the plain `TitleColor` setting for normal quests.

| priority | source | colour |
|---|---|---|
| 1 | super-tracked quest | `FocusColor` setting |
| 2 | completed quest | `CompletedColor` setting |
| 3 | classification: Legendary | `POI_COLORS[Legendary]` (orange) |
| 4 | tag: Raid | `TAG_COLOR_RAID` (dark green) |
| 5 | tag: Group/Dungeon | `TAG_COLOR_GROUP` (blue) |
| 6 | tag: PvP | `TAG_COLOR_PVP` (red) |
| 7 | tag: Account | `TAG_COLOR_ACCOUNT` (cyan) |
| 8 | campaign (`C_CampaignInfo`) | `POI_COLORS[Campaign]` |
| 9 | other classification | `POI_COLORS` table |
| 10 | fallback | `TitleColor` setting |

atlas icon selection follows the same priority: campaign check via `C_CampaignInfo.IsCampaignQuest`, then classification via `C_QuestInfoSystem.GetQuestClassification`, then tag via `C_QuestLog.GetQuestTagInfo`, falling back to `QuestNormal` or `QuestTurnin`.

super-tracked quest ID is updated via `SUPER_TRACKING_CHANGED` event. when it changes, all existing POI buttons are re-skinned to refresh focus colours.

## collapse persistence

per-module collapse state is saved to `Orbit.db.AccountSettings.ObjectivesCollapseState` via hooks on each module header's `SetCollapsed`. restored on `ApplySettings`. the main tracker header and all 11 modules in `TRACKER_MODULES` are tracked independently.

clicking a header routes through `Plugin:ToggleCollapse(target)` — **instant** for both sub-headers and the master, no animation. it primes the tracker `dirty` flag (so `SetCollapsed`'s `MarkDirty` doesn't also queue a deferred relayout), calls `target:ToggleCollapsed()`, settles Blizzard's layout synchronously with `Update(true)`, then resizes the box via the `UpdateHeight` override. a transient `_orbitAnimating` flag suppresses Blizzard's header shine for the toggle (the `PlayAddAnimation` hook keys off it). `dirtyUpdate = true` keeps non-dirty siblings from re-laying-out their blocks. programmatic paths (collapse restore, combat auto-collapse) call `SetCollapsed` directly.

auto-collapse in combat is optional (`AutoCollapseCombat` setting). on `PLAYER_REGEN_DISABLED`, the tracker is collapsed and the pre-combat state is saved. on `PLAYER_REGEN_ENABLED`, the pre-combat state is restored.

## progress bar labels

progress bar label text is reformatted via a `SetText`/`SetFormattedText` hook on the bar's `Label` FontString. the `ProgressBarLabelFormat` setting is a token string (e.g. `Current / Max (%)`) edited through the shared `formatinput` config widget — the same control type as unit-frame health text. tokens match case-insensitively, longest-first:

| token | output |
|---|---|
| `%` | `75%` |
| `Current` / `CurrentK` | `150` / `8K` |
| `Max` / `MaxK` | `200` / `10K` |

any other text renders literally. the format is parsed once per settings change (`ParseProgressFormat` → cached segments) and rendered per bar update; the percentage arithmetic is safe because objective progress values are plain Lua (non-secret). a re-entrant guard (`_orbitUpdating`) prevents the hook from recursing when we write the label.

## blizzard frames affected

| frame | action |
|---|---|
| `ObjectiveTrackerFrame` | reparented into scroll child, FrameGuard-protected |
| `ObjectiveTrackerFrame.Selection` | alpha 0, mouse disabled (prevents double-highlight in edit mode) |
| `ObjectiveTrackerFrame.NineSlice` | hidden (orbit provides its own border/backdrop) |
| all module headers | background texture cleared, minimize button reskinned with `+`/`-` chevron |
| all module widths | resized to match container width (blizzard hardcodes 260px) |

## visibility engine

- the **Orbit container** is registered as an Orbit-plugin VE frame in `Plugins/VisibilityManifest.lua` (`key = "Objectives"`, `plugin = "Objectives"`, category HUD), so it appears in the VE frame list while the plugin is enabled. `ApplySettings` calls `Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, SYSTEM_ID)` — the full VE integration (opacity, oocFade, mouseOver reveal, showWithTarget, hideMounted, alphaLock + the SetAlpha hook so VE-managed alpha wins). This supersedes the older `ApplyMouseOver`, which only did opacity + always-on hover.
- `ObjectiveTracker` (BLIZZARD_REGISTRY, `ownedBy = "Objectives"`) is the *Blizzard* frame's row — hidden from VE while the Objectives plugin is enabled (the Orbit row above takes its place), shown when the plugin is disabled so the raw tracker can still be controlled.
- blizzard hider registered: when objectives plugin is disabled, `NativeFrame:SecureHide(ObjectiveTrackerFrame)` hides the tracker entirely.

## colour migration

on first load, `MigrateColorSettings` converts any legacy colour-curve format (`{pins={...}}`) stored in saved variables to plain `{r, g, b, a}` tables. `ValidateColor` (on `ObjectivesConstants`) handles both formats and returns the fallback if the value is corrupt. `MigrateLegacySettings` then folds the retired `ClassColorHeaders` bool onto `HeaderColor` (`{type="class"}`) and the `ProgressBarMode` dropdown onto `ProgressBarLabelFormat`, clearing the old keys so it runs once.

## settings

| key | type | default | description |
|---|---|---|---|
| `Scale` | slider 50..200 | 100 | container scale (%) |
| `Width` | slider 180..400 | 300 | container width (px) |
| `Height` | slider 200..1200 | 334 | container height (px) |
| `ShowBorder` | checkbox | false | orbit border around container |
| `BackgroundOpacity` | slider 0..100 | 0 | solid backdrop opacity (%) |
| `HeaderSeparators` | checkbox | true | thin line under each module header |
| `HeaderColor` | solidcolor | white | module header + separator colour (supports the picker's Class Color pin) |
| `ProgressBarLabelFormat` | formatinput | `%` | progress label token format (e.g. `Current / Max (%)`) |
| `AutoCollapseCombat` | checkbox | false | collapse tracker on combat enter, restore on exit |
| `Opacity` | VE-controlled | 100 | overall container opacity — set via the Visibility Engine, not a plugin control (fallback default only) |
| `TitleFontSize` | slider 8..18 | 12 | quest title font size (px) |
| `ObjectiveFontSize` | slider 8..16 | 10 | objective line font size (px) |
| `HeaderFontSize` | slider 8..20 | 14 | module/section header font size (px) |
| `TitleColor` | solidcolor | `{1.00, 0.82, 0.00}` | default quest title colour |
| `CompletedColor` | solidcolor | `{0.90, 0.80, 0.10}` | completed quest title colour |
| `FocusColor` | solidcolor | `{1.00, 1.00, 1.00}` | super-tracked quest title colour |

settings UI is split into three tabs: **Layout** (Width, Height, TitleFontSize, ObjectiveFontSize, HeaderFontSize, BackgroundOpacity, ShowBorder), **Behaviour** (ProgressBarLabelFormat, HeaderSeparators, AutoCollapseCombat, ShowQuestCount), **Colours** (HeaderColor, TitleColor, CompletedColor, FocusColor). colour-tab labels drop the redundant "colour" word; quest titles are always coloured by quest type (classification / tag / super-track / completed).

## events

| event | reaction |
|---|---|
| `ADDON_LOADED` (Blizzard_ObjectiveTracker) | capture + install hooks + apply settings |
| `SUPER_TRACKING_CHANGED` | update focus quest ID, re-skin all POI buttons |
| `QUEST_WATCH_LIST_CHANGED` | update quest counter on main header |
| `PLAYER_REGEN_DISABLED` | auto-collapse tracker (if enabled) |
| `PLAYER_REGEN_ENABLED` | restore pre-combat collapse state (if enabled) |

## rules

- all skinning runs through `hooksecurefunc` — never replace or override blizzard methods directly.
- `_enabled` flag gates every hook callback. disabled hooks are O(1) no-ops.
- `InCombatLockdown()` is checked before `SetParent`, `ClearAllPoints`, `SetPoint`, `Show` on the tracker. deferred via `CombatManager:QueueUpdate`.
- ScenarioObjectiveTracker is header-only to avoid widget pool taint.
- user-visible strings go through `Orbit.L` (`PLU_OBJ_*` keys in `Localization/Domains/Plugins.lua`, all 9 locales at parity).

/run local q=29135; local t=C_QuestLog.GetQuestTagInfo(q); local c=C_QuestInfoSystem.GetQuestClassification(q); local g=C_QuestLog.GetSuggestedGroupSize(q); print("Tag:", t and t.tagID, t and t.tagName, "Class:", c, "Group:", g)