# Objectives — Feature Roadmap

*Research-backed plan (June 2026, patch 12.0.5/12.0.7). Distilled from a 13-agent study of Blizzard's `Blizzard_ObjectiveTracker` source + the addon landscape (Horizon Suite, Kaliel's Tracker, Syling, ExtraQuestButton, Quest Log Collapse, …). This file is a suggestion plan, not a contract — items gated on in-game verification are marked.*

---

## Where we stand

The plugin already reparents `ObjectiveTrackerFrame` into `OrbitObjectivesScrollChild`, skins entirely via `hooksecurefunc`, scrolls, persists per-module collapse, auto-collapses in combat, colors titles by classification/tag/super-track/completed, reskins the **quest item button** (`SkinQuestItemButton`), uses **sub-12pt fonts** (raw `SetFont`, min 8 — dodging Blizzard's 12pt `SetTextSize` floor), reformats progress bars (Percent/XY/Both), and integrates with VisibilityEngine.

**That is already ahead of most of the field on the hard parts.** The two "gold-standard" competitors take heavier architectures that we should *not* copy:

- **Kaliel's Tracker** *forks* Blizzard's tracker into a `KT_`-prefixed namespace and runs the copy. Deepest feature set, but carries an **open 12.0.5 secret-value arithmetic error** today and inherent combat dead-clicks.
- **Horizon Suite** *fully replaces* the tracker (`KillBlizzardFrame` + a custom provider→aggregator→renderer pipeline). Repeatedly shipping Midnight secret/taint/frame-leak fixes.

Our **reparent-and-skin-in-place** model is a defensible quality advantage. **Copy their features, not their architecture.**

## The one rule that shapes everything

**The binding constraint is taint, not secrets.** Quest/objective data (titles, objective text, `numFulfilled`/`numRequired`, percentages, classification, super-track ID, `GetDistanceSqToQuest`) is **plain Lua in and out of combat** — Blizzard's own non-secure code does arithmetic on it. Our `FormatProgressLabel` math is unconditionally safe; do **not** add `issecretvalue` guards in this plugin (cargo-cult). Secrets only appear if a feature pulls in unit/aura/cooldown APIs. See memory `reference_objective_tracker_nonsecret`.

What *does* require care: protected ops on the managed frame in combat (already gated via `CombatManager:QueueUpdate`), state drivers (must be on an **Orbit-owned** `SecureHandler*` frame, never `ObjectiveTrackerFrame`), the secure quest-item button, and the **Scenario widget-pool boundary** (header-only forever).

---

## Tier 1 — Quick wins (low effort, zero/low taint, on the existing plugin)

| # | Feature | What / endpoints | Settings | Effort |
|---|---|---|---|---|
| 1 | **Width text reflow** *(verify first — Open Q#1)* | Confirm the skin reflows `block.HeaderText` + `line.Text` to container width, not just the container box (the exact thing MoveAnything is reputed to fail at). If not: cache `containerWidth - inset` on resize/settings-change and `FontString:SetWidth(cached)` inside the existing `SetHeader`/`AddObjective` hooks. **This is the #2 most-begged feature.** | none (auto with Width) | S |
| 2 | **Extend quest-item-button skin** | We already zero the ornate textures + `SkinIcon` the icon. Add an Orbit flat/rounded **border**, tint the `HotKey` range indicator, theme `Cooldown`/`Glow`. All insecure; extend the function at `ObjectivesSkin.lua:463-464`. | Behaviour → "Skin Quest Items" | S |
| 3 | **Animation-suppression toggle** | `:Stop()` + alpha 0 on `block.HeaderGlow`, `line.Glow`, `line.CheckGlow`; cover **AutoQuestPopUp** blocks; optionally early-return `Manager:ShowRewardsToast`. All insecure regions. | Behaviour → "Suppress Animations" | S |
| 4 | **POI pin theming** | Hook `POIButtonMixin:UpdateButtonStyle` / `SetPinScale` for flat/colored/scaled pins matching Orbit's palette; `:Stop()` the `AddAnim` pop. We already overlay a slim atlas — add scale + optional flat mode. | Colours → "POI Style" / "POI Scale" | S–M |
| 5 | **LSM font-face picker** | Sub-12pt is already shipped; add an **LSM font face** (we already ship LibSharedMedia) feeding our existing per-region `SetFont`. Pick a face with CJK/RU coverage. | Colours → "Font Face" | S |
| 6 | **Thousands grouping on counts** | In `FormatProgressLabel` XY/Both mode (`ObjectivesSkin.lua:525-528`), locale-group large counts ("3 / 250"). Trivial string work. | fold into ProgressBarMode | XS |
| 7 | **Click-to-super-track + menu entries** | Additive `HookScript("OnMouseUp", …)` on the existing `block.HeaderButton` (**not** an overlay Button — that eats Blizzard's left-click-to-map) → `C_SuperTrack.SetSuperTrackedQuestID(block.id)`; `Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", …)` for Orbit context entries. These APIs aren't protected → combat-safe. Drive a "pinned" highlight off `GetSuperTrackedQuestID()` (we already re-skin on `SUPER_TRACKING_CHANGED`). | Behaviour → "Click to Pin" | S–M |

## Tier 2 — Medium (the differentiators)

| # | Feature | What / endpoints | Settings | Effort |
|---|---|---|---|---|
| 8 | **Per-context auto-hide/collapse** ⭐ *flagship gap* | Our clearest differentiation — KT has none of this. Create an **Orbit-owned `SecureHandlerStateTemplate`** container in the reparent chain; `RegisterStateDriver(container,"visibility",<composed conditional>)` set OOC. Contexts: raid / dungeon / M+ / scenario / arena / BG / pet-battle / delve / **neighbourhood/house** (mirror "Quest Log Collapse"), plus **boss-only** via `ENCOUNTER_START`/`ENCOUNTER_END`. Per-context choice of **hide vs collapse vs fade** (collapse reuses `SetCollapsed`; fade via VisibilityEngine `oocFade`). Compose the driver as a **PREFIX onto the base slot, never clobber** (see memory `project_visibility_groups`). Re-apply persisted collapse on Edit Mode exit (force-expand). | new **"Visibility" tab** | M |
| 9 | **Per-module enable/disable** | Primary path = **collapse/alpha**: `Hide()` the module header + skip its contribution in the `UpdateHeight` sum (taint-safe, reversible). `Manager:RemoveModule` mutates Blizzard registration state and is **not verified taint-free** — only with a `/wow-frames`+`/unsecreted` check, never as default. Cover all 11 modules incl. `InitiativeTasksObjectiveTracker`. **Scenario = header-suppress only.** | Behaviour → per-module checkboxes | M |
| 10 | **Structured per-objective mini-bars** | Read `C_QuestLog.GetQuestObjectives(block.id)` (non-secret `numFulfilled/numRequired`); render **Orbit-owned StatusBars** per objective line; refresh on `QUEST_LOG_CRITERIA_UPDATE`/`QUEST_WATCH_UPDATE`. No taint, no secrets. | Behaviour → "Objective Progress Bars" | M |
| 11 | **Hide completed / turn-in-ready marker** | Post-layout, `C_QuestLog.IsComplete`/`ReadyForTurnIn(block.id)` → hide block OR apply a distinct "ready" highlight. Players split — ship both as separate toggles. | Behaviour → "Hide Completed", "Turn-in Highlight" | M |
| 12 | **LSM bar texture + Masque** | Route progress/timer bar textures through LibSharedMedia (we already reskin bars); register quest item buttons with Masque (`Group:AddButton`) under `OptionalDeps`. | Colours → "Bar Texture" | M |
| 13 | **Reward toast + top banner theming/re-anchor** | Hook `Manager:ShowRewardsToast` to restyle/suppress; re-anchor `ObjectiveTrackerTopBannerFrame` to our moved container (it's UIParent-parented and currently floats detached). | Behaviour → "Theme Rewards" | M |

## Tier 3 — Ambitious (new sub-feature, higher effort/risk)

| # | Feature | What / endpoints | Placement | Effort |
|---|---|---|---|---|
| 14 | **Standalone keybindable quest-item bar** | Real `CreateFrame("Button",…,"SecureActionButtonTemplate")` + `type="item"`, populated **OOC only** from `GetQuestLogSpecialItemInfo` (queue if combat-locked — QBar's own limitation confirms this), with `SecureHandlerStateTemplate`+`RegisterStateDriver` for show/hide and an optional Extra-Action "closest quest item" + keybind (KT's signature; ExtraQuestButton/p3lim is the reference). **Do NOT reparent Blizzard's `block.ItemButton`.** | new `Plugins/` sibling (designable) | L |
| 15 | **Proximity / current-zone auto-track + sort** | `C_QuestLog.GetDistanceSqToQuest` (guard nil) for a **throttled** proximity sort (0.5–1s, never per-frame); auto-`AddQuestWatch`/`RemoveQuestWatch` by zone (SmartQuestTracker model; zQuestLog's "track nearest"). **Hardest to make stick** — Blizzard re-lays-out in its own order, so re-apply the reanchor on `QUEST_WATCH_LIST_CHANGED`/`QUEST_LOG_UPDATE`/`QUEST_POI_UPDATE`, combat-gated. The auto-track behavior is `QoL/`; the sort is a setting on this plugin — implement as one shared module surfaced in both. | `QoL/` + Behaviour toggle | L |
| 16 | **Multiple trackers w/ per-tracker filters** | Syling's headline. Second container via `Manager:AddContainer`/`SetModuleContainer` (+ `SetCanAddModules(false)` to fully own registration). High complexity; defer until Tier 2 ships. The one place registration mutation is unavoidable — gate behind a verified taint check. | new feature | XL |

---

## Verify in-game before building (gating)

1. **Does our skin reflow title/objective FontStrings to the custom width?** (Gates #1.) Test a long title at Width=400.
2. **Is the `GetAvailableHeight→50000` + `UpdateHeight` override still untainted in 12.0.5/12.0.7?** Run `/unsecreted` + the AzeriteUI5 #70 repro (Edit Mode → exit → combat → click tracker → watch for `SetPointBase()` blocked).
3. **WoWUIBugs #848** — header tooltip `SetPoint` anchor-family error spams in RBG Blitz, and we hook that exact header path. Add a defensive guard; prefer listening to `EventRegistry "OnQuestBlockHeader.OnEnter"` over a header `HookScript`.
4. **Does entering Edit Mode wipe persisted per-module collapse** (force-expand)? Confirm re-apply on exit.
5. **Does our Blizzard hider survive force-show** (map open / zone change / quest accept)? If not, apply **Carrot Objective Tracker's** pattern: `SetAlpha`-only (no `SetScale`/`SetPoint`), `IsProtected()` skip, `C_Timer.After(0)` deferral, hook the **re-show** path.
6. **Quest-counter accuracy** — `UpdateQuestCounter` reads raw `GetNumQuestWatches()/MAX_QUEST_WATCHES` (`ObjectivesSkin.lua:226-228`); that may over/under-count vs visible blocks given `ShouldDisplayQuest` filters and the **separate** WQ watch list (`GetNumWorldQuestWatches`).
7. **`SlidingMixin`/`SetClipsChildren` clip conflict** during quest accept/turn-in while scrolled.
8. **Follow-up research:** how Plumber injects Delve Nemesis counts into the tracker **without** widget-pool taint — not yet reverse-engineered.

## Explicitly out of scope

- **Theming the M+/scenario StatusBars** by re-enabling `AddBlock` on `ScenarioObjectiveTracker`. Its content frames share Blizzard's `UIWidgetManager` pool — touching them taints it. **Header-only forever.** M+/Delve richness ships as the separate **MythicPlus StatusWidget** plugin reading `C_ChallengeMode`/`C_Scenario` directly (already designed; "taint > secrets" verdict).

---

## Suggested sequencing

1. **De-risk:** run verify-items 1, 2, 5 (cheap, unblock Tier 1).
2. **Ship Tier 1** (#1–7) — visible polish, near-zero risk, broad appeal.
3. **Build #8 (per-context auto-hide)** — the headline differentiator vs Kaliel's Tracker, on the secure-state-driver foundation we'll reuse for #14.
4. **Then #9–11** — per-module toggles, objective bars, hide-completed round out the "control" story.
5. **Tier 3** as separate efforts once the medium tier is stable.
