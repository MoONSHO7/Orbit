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
  ObjectivesZoneFilter.lua   optional current-zone quest filter + area world-quest tracker (watch-list management)
  ObjectivesSettings.lua     settings UI: Layout / Behaviour / Colours tabs
  Objectives.xml             load-order bundle
```

## capture

`ObjectiveTrackerFrame` is reparented from `UIParent` (or `UIParentRightManagedFrameContainer`) into `OrbitObjectivesScrollChild`, a child of the main container `OrbitObjectivesContainer`. `OrbitEngine.FrameGuard:Protect` prevents blizzard or other addons from stealing it back. `InCombatLockdown()` is checked before any reparenting — deferred via `CombatManager:QueueUpdate` if locked.

the tracker's native `GetAvailableHeight` is overridden to return 50000, allowing blizzard to render all blocks regardless of visible area. `UpdateHeight` is replaced to track actual module content height and clamp the scroll offset when content shrinks.

## scrolling

a native Blizzard **`ScrollFrame`** (`OrbitObjectivesScroll`) is the viewport — the proven Kaliel's-Tracker pattern, replacing the old hand-rolled clip-frame + SetPoint-offset hack that fought us repeatedly. The ScrollFrame fills the box interior (inset for border + content padding), `SetClipsChildren(true)` clips overflow, and `SetScrollChild(OrbitObjectivesScrollChild)` hosts the reparented tracker. The scroll child's height is set to the measured content height in `tracker.UpdateHeight`, so the engine derives `GetVerticalScrollRange()` itself (content − viewport) — no hand math. `Plugin:OnScroll` steps `SetVerticalScroll` by `SCROLL_SPEED = 60`, clamped to the engine range; `OnScrollRangeChanged` re-clamps when content shrinks; `OnSizeChanged` keeps the scroll child's width matched to the viewport (vertical-only scroll). Wheel is bound on the ScrollFrame, the box, and the tracker. The ScrollFrame clips only its own child, so the Edit Mode selection/resize handles (sibling children of the box) stay visible — the reason the old design needed a separate clip frame.

**Two non-obvious requirements for the reparented `ObjectiveTrackerFrame` (both in `CaptureTracker`), the actual root cause of the long scroll saga:** (1) it inherits `UIParentRightManagedFrameTemplate`, which is **screen-clamped** — inside a scroll viewport that clamp pins it to the screen edge so it stops scrolling there (and detaches from the scroll child, corrupting `GetVerticalScrollRange`); `SetClampedToScreen(false)` lets it ride the scroll child past the screen edge into the clipped region. (2) it's `frameStrata="LOW"`; `SetClipsChildren` does **not** clip a child whose strata differs from the clipping frame, so the LOW tracker escaped the (MEDIUM) ScrollFrame's clip and rendered outside the box — `tracker:SetFrameStrata(scrollFrame:GetFrameStrata())` puts them in the same strata so the clip applies (modules inherit the tracker's strata).

## empty state

when no tracked module has content (`IsTrackerEmpty` — no module with `contentsHeight > 0`), the container's backdrop and border are hidden entirely, restored (per `ShowBorder` / `BackgroundOpacity`) when content returns. re-evaluated (transition-guarded via `RefreshEmptyState`) on the container **`Update` hook** — Blizzard only calls the container's `UpdateHeight` on `OnShow`, so when the last quest drops it hides the now-empty container without re-checking; hooking `Update` catches every relayout — plus at the end of `ApplySettings`. always treated as non-empty in edit mode so the frame stays grabbable.

`IsTrackerEmpty` keys off `tracker:IsCollapsed()`: while collapsed, Blizzard hides every module (`IsShown()` false) but their `contentsHeight` stays positive, so the empty check drops the `IsShown()` gate when collapsed — otherwise a collapsed-but-populated tracker would read as empty and lose its chrome.

## container sizing

the box **content-fits** with **symmetric** top/bottom inset. three pieces:

- **`tracker.UpdateHeight`** (overridden) sets the real content height: `topModulePadding + Σ(visible module contentsHeight) + moduleSpacing·(n−1)`. the master header lives *inside* `topModulePadding` so it isn't added separately; crucially the old formula (`header + ΣcontentsHeight`) omitted Blizzard's `topModulePadding` gap and inter-module `moduleSpacing`, under-counting by `(topModulePadding − header) + moduleSpacing·(n−1)` — which is why the last section got clipped.
- **`DesiredContentHeight`** = the uncapped box height: `tracker height + 2·inset` (full inset top and bottom). every header keeps its divider (including the last/trailing one), so `tracker.UpdateHeight` reserves a `HEADER_SEPARATOR_HEIGHT`-sized sliver of content height for it — the trailing separator hangs just below the last header, which on a collapsed last section would otherwise land in the bottom inset and get clipped by the ScrollFrame. the collapsed-master bar is `header + 2·inset` (`CollapsedBarHeight`).
- **`ResolveContainerHeight`** = `min(Height, DesiredContentHeight)`; edit mode → full `Height` (grabbable; the resize handle drives the real setting, which is effectively a *max*). **Position-independent** — there is deliberately no screen-relative cap: an earlier attempt capped to "on-screen space below the box top," which made the box height (and therefore the scroll range) depend on *where on screen the frame sat* (placed high → huge box, nothing to scroll; placed low → tiny box). The native `ScrollFrame` scrolls anything beyond the box, so the box is simply the user's chosen height clamped to content, the same everywhere — matching Kaliel's Tracker's `maxHeight` model.

**header heights track the font.** Blizzard's header frames are a fixed 32px (master) / 26px (module) regardless of font, so a small label floats in a tall bar. `ApplyHeaderFont` instead sizes each header to `max(HeaderFontSize + 2·HEADER_VPADDING, floor)` — floor = the 16px minimize button (`HEADER_MIN_HEIGHT` 20 master, `MODULE_HEADER_MIN_HEIGHT` 18 module) — pixel-snapped. the master write also sets `topModulePadding = masterHeight + GetContentInset()` (replacing Blizzard's fixed 38) — the gap below the master equals the box's content inset, so master→module spacing is uniform with the top/bottom inset — and each module write sets `module.headerHeight` in lockstep, so `CollapsedBarHeight`/`DesiredContentHeight`/`UpdateHeight` (which read these live) all tighten with no gap or clip. `ScenarioObjectiveTracker` is left native (font only) — its collapse/slide math reads `headerHeight`.

**`UpdateSeparators`** owns header-separator visibility: the master separator hides only while the master itself is collapsed (genuinely nothing below it); module separators always show per the `HeaderSeparators` setting, so a collapsed sub-header keeps its divider and reads consistently with the master. `ApplyHeaderSeparator` (in `ApplySkins`) draws each divider pixel-perfect — `Pixel:Multiple(HEADER_SEPARATOR_HEIGHT)` thick, the same distance below the header, re-applied so it tracks UI-scale changes — and sets the colour; `ApplySkins` then calls `UpdateSeparators` synchronously to avoid a flash, and the container `Update` hook re-runs it so collapse/quest changes re-evaluate visibility.

"is the box capped, and by how much" is now owned by the `ScrollFrame` itself: the box height is `ResolveContainerHeight` (the viewport), the scroll child is the content height, and `GetVerticalScrollRange()` = content − viewport. Height recompute is driven from the container `Update` hook (every relayout), `tracker.UpdateHeight`, `ApplySettings`, and the `SetCollapsed` hooks; resizing the box can't feed back into the tracker (module-driven height, constant `GetAvailableHeight`), so no oscillation.

the container sets `orbitForceAnchorPoint = "TOPRIGHT"` so the anchor engine always persists a TOP-bearing point — otherwise `Snap:NormalizePosition` collapses the vertical token to center for a tall right-side frame, and `SetHeight` would grow symmetrically about the centre (the collapsed/wrapped box would appear centered). because a *previously* saved position is restored by `Persistence:RestorePosition` verbatim (it does not re-normalize), `HoldTopAnchor` (called from `ApplyContainerHeight`) re-pins a still-centered free anchor to the forced point — preserving the current spot, via the engine's own `FrameSnap:NormalizePosition` — so a stale save self-heals each session and a re-drag persists the TOP point for good. with a TOP anchor the box grows/shrinks downward from a fixed top edge.

## anchoring

the container sets `orbitWidthSync = true`: docked to another orbit frame's top/bottom edge, its width matches that parent. `ApplySettings` skips applying its own width whenever `IsWidthSynced` is true, letting the anchor engine own it.

## skinning

all hooks are installed once in `InstallSkinHooks()` via `hooksecurefunc`. no hooks run unless the `_enabled` flag is true (toggled by `SetSkinEnabled`, which `ApplySettings` sets to `IsOrbitStyle()`).

**style gate.** `Plugin:IsOrbitStyle()` (false only when `StyleMode == "Blizzard"`) is the single source of truth for whether the cosmetic skin applies. It gates: `SetSkinEnabled` (so the `GetProgressBar`/`AddBlock`/widget hook callbacks no-op in Blizzard style); the cosmetic chrome in `InstallSkinHooks` (header background clear, `+`/`-` chevron, whole-header click-collapse, quest counter — skipped, so Blizzard's native minimize button + collapse animation are kept); the header colour/font/separator + re-skin passes in `ApplySkins` (early-returns after the structural `FitTrackerWidths`); the progress-bar refit loop in `FitTrackerWidths`; and the trailing-separator height reservation in `tracker.UpdateHeight`. **Structural machinery is style-independent** — reparent/capture, the ScrollFrame viewport, the `UpdateHeight` content-height system (reads Blizzard's native `topModulePadding`/`headerHeight` in Blizzard style), width-fit, border/backdrop, collapse persistence, empty-state, and VE all run in both styles. The gate is read fresh each session (reload-gated), so `InstallSkinHooks` installing the dormant self-gating hooks in Blizzard style is harmless.

Two Blizzard-style fit-ups handle the native left-edge clip (Orbit style sidesteps both — it clears header backgrounds in `SkinHeader` and repositions the POI in `SkinPOIButton`):

- **Block content shift.** Blizzard hangs each block's POI button ~7px left of the module edge (`blockOffsetX` 20 − 7 anchor − 20px POI width), which the ScrollFrame clips ("icons cut off on the left"). In Blizzard style `ApplySettings` anchors the tracker into the scroll child with a `BLIZZARD_LEFT_PAD` (12px) left offset so the icons clear the clip.
- **Header background fit + compensation.** The native header `Background` is a fixed-width atlas anchored CENTER, so once `FitTrackerWidths` sizes the header narrower than the atlas it bleeds and clips ("gold bars cut on the left"). In Blizzard style `FitNativeHeaderBackground` re-anchors each `Background` to the header `LEFT`/`RIGHT` (keeping its atlas height); the `LEFT` extends back by `-BLIZZARD_LEFT_PAD` to undo the content shift, so the bar still spans the full box width edge-to-edge while the blocks below sit shifted-right.

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

## zone filter

`ObjectivesZoneFilter.lua` holds two independent, default-off toggles that share one event frame and the current-map math, reconciled by `UpdateZoneFilters` (called from `ApplySettings`, idempotent — each acts only on its own enabled-state transition): **`ZoneFilter`** (current-zone quest filter, below) and **`ZoneWorldQuests`** (area world-quest tracker, end of section).

`ZoneFilter` shows only quests for the player's current zone. The tracker only renders **watched** quests and there is no taint-safe way to override Blizzard's `QuestObjectiveTrackerMixin:ShouldDisplayQuest` (it's a mixin method whose return value `hooksecurefunc` can't change, and a full override would taint), so the filter works the way SmartQuestTracker/zQuestLog do: by **managing the watch list**. Quest data is non-secret and the watch APIs (`AddQuestWatch`/`RemoveQuestWatch`/`GetQuestWatchType`) are `AllowedWhenUntainted` and unprotected, so this is taint-light and combat-safe (no `CombatManager` gating needed).

`EvaluateZoneFilter` walks the quest log once (`GetNumQuestLogEntries`/`GetInfo`, skipping headers/hidden/task/bounty entries) and, against the current map set:

- **in-zone, unwatched →** `AddQuestWatch`, flagged in `_zoneAutoTracked`
- **in-zone, watched & engine-Automatic →** claimed into `_zoneAutoTracked`
- **out-of-zone, watched, ours, not always-kept →** `RemoveQuestWatch` (recorded in `_zoneAutoRemoved`)

**Why a flag set, not the watch type.** `C_QuestLog.AddQuestWatch(questID)` is 1-arg and can't request a type (only the World-Quest variant `AddWorldQuestWatch(questID, watchType)` takes one), so quests we add read back as **`Manual`** — indistinguishable by type from a real user pin. Relying on `GetQuestWatchType == Manual` therefore made our own auto-tracks un-removable. Instead, **"ours to manage" = flagged in `_zoneAutoTracked` (we added/claimed it) OR `GetQuestWatchType == Enum.QuestWatchType.Automatic` (engine auto-watch)**, and only those are ever untracked.

The **current map set** = `C_Map.GetBestMapForUnit("player")` plus its ancestors up to and including the continent (`BuildZoneMapSet`); a quest matches when `GetQuestUiMapID(questID)` is in that set — sibling zones are excluded, continent-level quests show continent-wide. **Always-kept** (never auto-removed even when ours): a genuine manual pin we never claimed, the super-tracked quest, complete/turn-in-ready quests (`IsComplete`/`ReadyForTurnIn`), and zoneless/account quests (`GetQuestUiMapID == 0`).

Driven by `ZONE_CHANGED*` + `QUEST_ACCEPTED`/`QUEST_TURNED_IN`/`QUEST_REMOVED`/`QUEST_WATCH_LIST_CHANGED` + `PLAYER_ENTERING_WORLD`, coalesced to the next frame (`ScheduleZoneFilterUpdate`). A `_zoneFilterUpdating` guard plus the idempotent evaluation prevent the watch-change feedback loop (our own `Add`/`Remove` fire `QUEST_WATCH_LIST_CHANGED`, which converges in one extra no-op pass). `autoQuestWatch` re-adds out-of-zone quests on objective updates; the `QUEST_WATCH_LIST_CHANGED` re-evaluation drops them again (minor churn only on actual progress, no global CVar change). Disabling re-watches the `_zoneAutoRemoved` quests (this session) so turning the filter off restores what it hid.

**`ZoneWorldQuests`** (`EvaluateWorldQuestZone`) auto-tracks every world quest on the current map. World quests are a separate watch list (`AddWorldQuestWatch`/`RemoveWorldQuestWatch`, enumerated by `C_TaskQuest.GetQuestsOnMap(mapID)` → `.questID`, filtered to `C_QuestLog.IsWorldQuest`). `GetQuestsOnMap` can bleed in WQs from adjacent/child areas (Zul'Aman into Eversong Woods), so each WQ is additionally gated on `GetQuestUiMapID(questID)` being in a **zone-level** `BuildZoneMapSet(ZONE)` (current zone only, never the continent) — tighter than the quest filter's continent-level set. `AddWorldQuestWatch` *does* take a type, but **Automatic** WQ watches are engine-capped (only a few survive), so we add as **Manual** to keep them all and flag them in `_zoneAutoTrackedWQ`; WQs you pinned yourself (watched, never flagged) are left alone. Each pass adds the on-map WQs not yet watched and removes flagged WQs that left the map. Same `_zoneFilterUpdating` guard, same coalesced events. It's purely additive, so disabling untracks the WQs it added (`RemoveAutoTrackedWorldQuests`). One caveat: a freshly-entered zone's WQ data loads asynchronously, so newly-revealed WQs may track a beat late (on the next zone/quest event) rather than instantly.

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
| `StyleMode` | dropdown `Orbit`/`Blizzard` | `Orbit` | skin mode — `Orbit` applies the custom skin; `Blizzard` leaves the native tracker chrome (larger bars/headers) inside the Orbit container. Reload-gated. |
| `Scale` | slider 50..200 | 100 | container scale (%) |
| `Width` | slider 180..400 | 300 | container width (px) |
| `Height` | slider 200..1200 | 334 | container height (px) |
| `ShowBorder` | checkbox | false | orbit border around container |
| `BackgroundOpacity` | slider 0..100 | 0 | solid backdrop opacity (%) |
| `HeaderSeparators` | checkbox | true | thin line under each module header |
| `HeaderColor` | solidcolor | white | module header + separator colour (supports the picker's Class Color pin) |
| `ProgressBarLabelFormat` | formatinput | `%` | progress label token format (e.g. `Current / Max (%)`) |
| `AutoCollapseCombat` | checkbox | false | collapse tracker on combat enter, restore on exit |
| `ZoneFilter` | checkbox | false | auto-track current-zone quests, untrack others (see *zone filter*) |
| `ZoneWorldQuests` | checkbox | false | auto-track every world quest on the current map (see *zone filter*) |
| `Opacity` | VE-controlled | 100 | overall container opacity — set via the Visibility Engine, not a plugin control (fallback default only) |
| `TitleFontSize` | slider 8..18 | 12 | quest title font size (px) |
| `ObjectiveFontSize` | slider 8..16 | 10 | objective line font size (px) |
| `HeaderFontSize` | slider 8..20 | 14 | module/section header font size (px) |
| `TitleColor` | solidcolor | `{1.00, 0.82, 0.00}` | default quest title colour |
| `CompletedColor` | solidcolor | `{0.90, 0.80, 0.10}` | completed quest title colour |
| `FocusColor` | solidcolor | `{1.00, 1.00, 1.00}` | super-tracked quest title colour |

settings UI is split into three tabs: **Layout** (StyleMode, Width, Height, TitleFontSize, ObjectiveFontSize, HeaderFontSize, BackgroundOpacity, ShowBorder), **Behaviour** (ProgressBarLabelFormat, HeaderSeparators, AutoCollapseCombat, ZoneFilter, ZoneWorldQuests, ShowQuestCount), **Colours** (HeaderColor, TitleColor, CompletedColor, FocusColor). colour-tab labels drop the redundant "colour" word; quest titles are always coloured by quest type (classification / tag / super-track / completed).

`StyleMode` is the master switch, first on the **Layout** tab. In `Blizzard` style the skin-only controls (font sizes, ProgressBarLabelFormat, HeaderSeparators, ShowQuestCount) hide via `visibleIf`, and the **Colours** tab drops out of the tab list entirely (its `dialog.orbitCurrentTab` falls back to Layout); container/box controls (Width, Height, BackgroundOpacity, ShowBorder) and AutoCollapseCombat stay, since they apply in both styles. Changing the mode prompts a UI reload (`MSG_PROFILE_RELOAD_REQUIRED` confirm) — the skin strips Blizzard textures irreversibly within a session, so a clean swap needs a reload either direction; the dialog re-renders immediately to preview the pending mode.

## events

| event | reaction |
|---|---|
| `ADDON_LOADED` (Blizzard_ObjectiveTracker) | capture + install hooks + apply settings |
| `SUPER_TRACKING_CHANGED` | update focus quest ID, re-skin all POI buttons |
| `QUEST_ACCEPTED` / `QUEST_REMOVED` | update quest counter on main header (count of visible log quests — headers/hidden/tasks/bounties excluded) |
| `PLAYER_REGEN_DISABLED` | auto-collapse tracker (if enabled) |
| `PLAYER_REGEN_ENABLED` | restore pre-combat collapse state (if enabled) |
| `ORBIT_PLAYER_SPECIALIZATION_CHANGED` | `ReassertLayout` — re-`RestorePosition` + `ApplySettings` so recovery no longer needs an Edit Mode toggle. Profile changes are handled by the shared `Persistence` restore + `RefreshAllPlugins`; the shared **spec**-restore (`RestoreAffectedBySpecChange`) only covers spec-scoped plugins, and Objectives isn't one despite reparenting a Blizzard-managed frame Blizzard re-anchors on spec |
| `ZONE_CHANGED*` / `QUEST_ACCEPTED` / `QUEST_TURNED_IN` / `QUEST_REMOVED` / `QUEST_WATCH_LIST_CHANGED` / `PLAYER_ENTERING_WORLD` | re-evaluate the zone filter (if `ZoneFilter` enabled) — see *zone filter* |

## rules

- all skinning runs through `hooksecurefunc` — never replace or override blizzard methods directly.
- `_enabled` flag gates every hook callback. disabled hooks are O(1) no-ops.
- `IsOrbitStyle()` gates the *cosmetic* skin (false in `Blizzard` style); *structural* machinery (capture, scroll, content-height, width-fit, border, collapse, VE) is style-independent. Style changes are reload-gated.
- `InCombatLockdown()` is checked before `SetParent`, `ClearAllPoints`, `SetPoint`, `Show` on the tracker. deferred via `CombatManager:QueueUpdate`.
- ScenarioObjectiveTracker is header-only to avoid widget pool taint.
- user-visible strings go through `Orbit.L` (`PLU_OBJ_*` keys in `Localization/Domains/Plugins.lua`, all 9 locales at parity).

/run local q=29135; local t=C_QuestLog.GetQuestTagInfo(q); local c=C_QuestInfoSystem.GetQuestClassification(q); local g=C_QuestLog.GetSuggestedGroupSize(q); print("Tag:", t and t.tagID, t and t.tagName, "Class:", c, "Group:", g)