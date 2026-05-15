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

mouse wheel scrolling on both the container and the tracker itself. scroll offset is applied by moving the scroll child's anchors relative to the container. `SCROLL_SPEED = 60`, `SCROLL_BOTTOM_PADDING = 20` adds breathing room at the bottom.

## skinning

all hooks are installed once in `InstallSkinHooks()` via `hooksecurefunc`. no hooks run unless the `_enabled` flag is true (toggled by `SetSkinEnabled`).

### hooked targets

| target | hook | effect |
|---|---|---|
| `tracker.AddBlock` (per module) | `OnAddBlock` | skin item buttons, checkmarks, fonts; install per-block colour/POI hooks |
| `ObjectiveTrackerBlockMixin.AddObjective` | `OnAddObjective` | hide `ui-questtracker-objective-nub` atlas on objective line icons |
| `ObjectiveTrackerQuestPOIBlockMixin.AddPOIButton` | `SkinPOIButton` | strip native visuals, overlay slim atlas icon, colour title by quest type |
| `tracker.GetProgressBar` | `SkinProgressBar` | strip textures, apply orbit bar texture + border + label hook |
| `tracker.GetTimerBar` | `SkinTimerBar` | same treatment as progress bars |
| `UIWidgetTemplateStatusBarMixin.Setup` | `SkinWidgetStatusBar` | skin widget bars inside the tracker (filtered by `IsUnderObjectivesTracker`) |
| `UIWidgetTemplateIconAndTextMixin.Setup` | `SkinWidgetIconAndText` | hide widget icons, apply font |
| `UIWidgetBaseStateIconTemplateMixin.Setup` | `SkinWidgetStateIcon` | hide widget state icons |
| `UIWidgetTemplateIconTextAndBackgroundMixin.Setup` | `SkinWidgetIconTextAndBackground` | hide icon/glow/bg, apply font |
| `header.SetCollapsed` (per module) | chevron update | refresh `+`/`-` chevron, re-suppress native textures, persist state |

### ScenarioObjectiveTracker

header-only skinning. its content frames share blizzard's widget pool — calling methods on them taints the pool and breaks other UI. `AddBlock` / `GetProgressBar` / `GetTimerBar` hooks are skipped for this module.

## POI icons

each quest block's `poiButton` is stripped of native visuals and overlaid with a classification-based atlas icon. title text colour is derived from quest classification, tag, or focus state. when `CustomColors` is disabled, only focus and completed colours apply — everything else falls through to the plain `TitleColor` setting.

| priority | source | colour |
|---|---|---|
| 1 | super-tracked quest | `FocusColor` setting |
| 2 | completed quest | `CompletedColor` setting |
| 3 | `CustomColors` gate | if off → `TitleColor` (skip 4-8) |
| 4 | classification: Legendary | `POI_COLORS[Legendary]` (orange) |
| 5 | tag: Raid | `TAG_COLOR_RAID` (dark green) |
| 6 | tag: Group/Dungeon | `TAG_COLOR_GROUP` (blue) |
| 7 | tag: PvP | `TAG_COLOR_PVP` (red) |
| 8 | tag: Account | `TAG_COLOR_ACCOUNT` (cyan) |
| 9 | campaign (`C_CampaignInfo`) | `POI_COLORS[Campaign]` |
| 10 | other classification | `POI_COLORS` table |
| 11 | fallback | `TitleColor` setting |

atlas icon selection follows the same priority: campaign check via `C_CampaignInfo.IsCampaignQuest`, then classification via `C_QuestInfoSystem.GetQuestClassification`, then tag via `C_QuestLog.GetQuestTagInfo`, falling back to `QuestNormal` or `QuestTurnin`.

super-tracked quest ID is updated via `SUPER_TRACKING_CHANGED` event. when it changes, all existing POI buttons are re-skinned to refresh focus colours.

## collapse persistence

per-module collapse state is saved to `Orbit.db.AccountSettings.ObjectivesCollapseState` via hooks on each module header's `SetCollapsed`. restored on `ApplySettings`. the main tracker header and all 11 modules in `TRACKER_MODULES` are tracked independently.

auto-collapse in combat is optional (`AutoCollapseCombat` setting). on `PLAYER_REGEN_DISABLED`, the tracker is collapsed and the pre-combat state is saved. on `PLAYER_REGEN_ENABLED`, the pre-combat state is restored.

## progress bar labels

progress bar label text is reformatted via a `SetText`/`SetFormattedText` hook on the bar's `Label` FontString. three modes controlled by the `ProgressBarMode` setting:

| mode | output |
|---|---|
| `Percent` | `75%` |
| `XY` | `150 / 200` |
| `Both` | `150 / 200  (75%)` |

a re-entrant guard (`_orbitUpdating`) prevents the hook from recursing when we write the label.

## blizzard frames affected

| frame | action |
|---|---|
| `ObjectiveTrackerFrame` | reparented into scroll child, FrameGuard-protected |
| `ObjectiveTrackerFrame.Selection` | alpha 0, mouse disabled (prevents double-highlight in edit mode) |
| `ObjectiveTrackerFrame.NineSlice` | hidden (orbit provides its own border/backdrop) |
| all module headers | background texture cleared, minimize button reskinned with `+`/`-` chevron |
| all module widths | resized to match container width (blizzard hardcodes 260px) |

## visibility engine

- `ObjectiveTracker` (BLIZZARD_REGISTRY, `ownedBy = "Objectives"`) — VE controls opacity, oocFade, mouseOver for the blizzard frame via the plugin.
- `NativeBarMixin` provides mouseOver fade helpers via `ApplyMouseOver(frame, SYSTEM_ID)`.
- blizzard hider registered: when objectives plugin is disabled, `NativeFrame:SecureHide(ObjectiveTrackerFrame)` hides the tracker entirely.

## colour migration

on first load, `MigrateColorSettings` converts any legacy colour-curve format (`{pins={...}}`) stored in saved variables to plain `{r, g, b, a}` tables. `ValidateColor` (on `ObjectivesConstants`) handles both formats and returns the fallback if the value is corrupt.

## settings

| key | type | default | description |
|---|---|---|---|
| `Scale` | slider 50..200 | 100 | container scale (%) |
| `Width` | slider 180..400 | 248 | container width (px) |
| `Height` | slider 200..1200 | 700 | container height (px) |
| `ShowBorder` | checkbox | true | orbit border around container |
| `BackgroundOpacity` | slider 0..100 | 0 | solid backdrop opacity (%) |
| `HeaderSeparators` | checkbox | true | thin line under each module header |
| `ClassColorHeaders` | checkbox | false | tint headers + separators with class colour |
| `SkinProgressBars` | checkbox | true | apply orbit texture/border to progress bars |
| `ProgressBarMode` | dropdown | `Percent` | progress label format (Percent / XY / Both) |
| `AutoCollapseCombat` | checkbox | false | collapse tracker on combat enter, restore on exit |
| `Opacity` | slider 0..100 | 100 | overall container opacity (via NativeBarMixin) |
| `TitleFontSize` | slider 8..18 | 12 | quest title font size (pt) |
| `ObjectiveFontSize` | slider 8..16 | 10 | objective line font size (pt) |
| `TitleColor` | solidcolor | `{1.00, 0.82, 0.00}` | default quest title colour |
| `CompletedColor` | solidcolor | `{0.90, 0.80, 0.10}` | completed quest title colour |
| `FocusColor` | solidcolor | `{1.00, 1.00, 1.00}` | super-tracked quest title colour |
| `CustomColors` | checkbox | true | enable classification/tag quest title colouring |

settings UI is split into three tabs: **Layout** (Width, Height, ShowBorder, BackgroundOpacity), **Behaviour** (HeaderSeparators, SkinProgressBars, ProgressBarMode, AutoCollapseCombat), **Colours** (CustomColors, ClassColorHeaders, TitleFontSize, ObjectiveFontSize, TitleColor, CompletedColor, FocusColor).

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
- user-visible strings go through `Orbit.L`. no localisation keys exist yet for this plugin (settings labels are hardcoded english in `ObjectivesSettings.lua`).

/run local q=29135; local t=C_QuestLog.GetQuestTagInfo(q); local c=C_QuestInfoSystem.GetQuestClassification(q); local g=C_QuestLog.GetSuggestedGroupSize(q); print("Tag:", t and t.tagID, t and t.tagName, "Class:", c, "Group:", g)