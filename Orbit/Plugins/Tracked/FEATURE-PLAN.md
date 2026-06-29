# Tracked + CooldownManager modernization — feature plan

Status (Jun 2026): **accurate spell capture done for both targets, not yet `/reload`-verified.** Every drag source feeds API/learn-sourced spell metadata into **both** Tracked frames and the CDM `ViewerInjection` — no tooltip parsing for spells anywhere. Built: `Core/Shared/CooldownData.lua` (resolver), `Core/Shared/CooldownLearn.lua` (self-disabling aura-learn), `ResolveActiveDuration` shared helper, learn-drivers in `TrackedPlugin` + `ViewerInjection`. **Items still use `TooltipParser`** (no clean item base-cooldown API) so the file is retained. Source research: memory `project_cooldown_tracked_research_jun2026`. Targets retail 12.0.5/12.0.7.

### Goal (clarified): accurate spell info at drag time from every source into both targets

Drag sources — action bar, bags, equipped/inventory (`"item"` + `ResolveEquipmentSlot`), spellbook (book-bank unwrap), and the cooldown-settings panel (`CooldownSettingsDragBridge`) — all funnel through `ResolveCursorInfo`/the bridge → the three builders. **Spell** metadata in every builder is now API/learn-sourced for **both** Tracked and CDM `ViewerInjection`:

- **active-phase duration** — `CooldownData:ResolveActiveDuration` (override table → `IsSelfAura`-gated `CooldownLearn` aura watch). Shared by `TrackedPlugin:RequestActiveDurationLearn` and `Injection:RequestActiveDurationLearn`.
- **base cooldown** — `CooldownData:GetBaseCooldownSeconds` (`GetSpellBaseCooldown`, secret-guarded). The live swipe already used real DurationObjects.
- **charges / overrides** — `C_Spell.GetSpellCharges` + `CooldownData` override fields. No tooltips.

### Buff/debuff aura cells in Tracked containers (DONE, v1, not `/reload`-verified)

Tracked icon containers can now hold **buff/debuff cells mixed with cooldown cells** in the same grid/row. Why from-scratch (not reparent): the native CDM aura widgets are owned by the CooldownManager (it reparents the whole BuffIcon/BuffBar viewers) and a buff has exactly one native frame — it can't also live in a Tracked cell. Coolinator only gets away with reparent because it *replaces* the CDM; Orbit *skins* it, so Tracked must read the aura itself.

- **Detection**: `CooldownData:IsAuraCategory(spellID)` (category == TrackedBuff/TrackedBar). `BuildTrackedItemEntry` stamps `entry.aura`. Buffs/debuffs are sourced from the cooldown-settings drag (`OnCooldownSettingsDrop`), which bypasses `HasCooldown`.
- **Render** (`TrackedIconItem:UpdateAura`): secret-safe per `/wow-secrets` — presence via `GetPlayerAuraBySpellID` (nil-check), `auraInstanceID` `issecretvalue`-guarded, then `GetAuraDuration` → `Cooldown:SetCooldownFromDurationObject` (swipe), `GetAuraApplicationDisplayCount` → `ChargeText:SetText` (stacks, empty <2), `SetDesaturation(0/1)` for up/down. No Lua math on aura times.
- **Updates**: container `evtFrame` adds `RegisterUnitEvent("UNIT_AURA","player")`; aura events refresh only aura cells.
- **Mixing is free**: the size-based grid positions aura cells and cooldown cells identically.

**v1 limits (follow-ups):** player auras only (buffs + self-debuffs) — **target debuffs (DoTs) not yet** (need target scan + unit-identity handling); in restricted M+/raid combat non-whitelisted auras return nil (`RequiresNonSecretAura`) so the cell greys out (no crash, graceful); no aura mode for single `TrackedBar` yet; no dispel-color debuff border (uses desaturation).

### Remaining
- **Items** still use `TooltipParser` (no clean item base-cooldown API). Spells were the priority; items are a follow-up via item-aura learn (`useSpellId`) + learn-on-cooldown for the base cooldown.
- `TooltipParser.lua` is therefore retained (items + the item branch of `BuildInjectedItemEntry`). Once items are migrated: delete it, move `BuildPhaseCurve` to a non-parser home (pure duration math), drop the `Parse*` aliases.
- Optional polish (Step 4 render sinks, Steps 5–6 picker/per-icon glows) unchanged — not required for capture accuracy.

## Goal

Retire Tracked's fragile tooltip-duration parsing, move the render path onto Blizzard's DurationObject C++ sinks (lower CPU than today), and add per-icon conditional glows (proc / pandemic / ready). CooldownManager already reparents+skins Blizzard's native viewer, so it inherits pandemic/proc/charge/aura for free — Tracked is the from-scratch surface carrying the debt and is the primary target. The metadata resolver lives in `Core/Shared/` and is consumed by both.

## Why not "build the spell list, then delete tooltip parsing"

The picker (acquisition) and the parser (duration metadata) are independent — the picker does not unblock parser removal. And the parser produces two values of very different difficulty:

- **`cooldownDuration`** — trivially replaceable (`C_Spell.GetSpellCooldownDuration` / `GetSpellBaseCooldown` / live `cdInfo.duration`).
- **`activeDuration`** (the buff window) — **no drop-time API.** It drives `DetermineMode` ([TrackedBar.lua:128](TrackedBar.lua)), `_phaseBreakpoint` ([TrackedBar.lua:650](TrackedBar.lua)), the icon active-phase reverse swipe ([TrackedIconItem.lua:365](TrackedIconItem.lua)), and the desat/alpha curves ([TrackedContainer.lua:199](TrackedContainer.lua)). Only learnable from the **live aura** on first cast.

The "learn active duration from the live aura" mechanism is the **same primitive pandemic needs** (base aura duration captured on first apply). Build it once → it unblocks parser removal *and* is the pandemic foundation. So the keystone is the resolver + the aura-learn primitive, not the picker.

---

## Performance contract (the optimum, applies to every step)

The win here is **deleting Lua hot paths that already exist** (TrackedBar's 0.1s ticker, TrackedContainer's 0.3s poll), not micro-tuning.

1. **Static metadata → build once on event, O(1) reads, wipe-don't-realloc.** Cooldown-info is static per spec; never call `C_CooldownViewer.*` in a hot path.
2. **Timers → C++ sinks, delete the Lua tickers.** `StatusBar:SetTimerDuration` self-animates the fill in C++; `Cooldown:SetCooldownFromDurationObject` (already used for the swipe) and `C_DurationUtil.CreateDurationTextBinding` self-update text. Touch them only on state-change events.
3. **Listeners → one shared, delta-based, self-disabling.** One plugin-level `UNIT_AURA`, registered only while something needs learning, unregistered when done → zero steady-state cost.
4. **Allocation → reuse, don't `new` per tick.** One DurationObject + one text binding per icon/bar, mutated via `:SetTimeFromStart`/`:SetDuration` — never a fresh allocation per update. Cache resolved settings/curves on the frame; keep the existing weak-valued curve caches.
5. **Lists/glows → pooled & virtualized.** Picker uses `CreateScrollBoxListGridView` (~30 recycled buttons); glow frames already pooled by GlowController/LibOrbitGlow.

---

## Step 1 — Metadata resolver `Orbit.CooldownData` (`Core/Shared/CooldownData.lua`)

**API:** `CooldownData:Get(itemType, id) -> info` returning cached fields (or multiple returns to avoid a table alloc): `hasCooldown, hasCharges, maxCharges, hasAura, selfAura, baseCooldown, overrideId, auraSpellIds, category`.

**Source of truth:** build a `spellID -> cooldownInfo` lookup from `C_CooldownViewer.GetCooldownViewerCategorySet(Essential|Utility|TrackedBuff|TrackedBar, true)` → `GetCooldownViewerCooldownInfo(id)`; fall back to `C_Spell.GetSpellCharges`/`GetSpellCooldown`/`GetSpellBaseCooldown` for spellbook spells not in any set. `linkedSpellIDs` → `auraSpellIds` for the aura-learn step.

**Perf:** one shared lookup table, **wiped and refilled** on `COOLDOWN_VIEWER_DATA_LOADED`, `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`, `COOLDOWN_VIEWER_TABLE_HOTFIXED`, `TRAIT_CONFIG_UPDATED`, spec change. Reads are O(1), allocation-free.

**Immediately replaces:** `CooldownDragDrop:HasCooldown`'s `ParseCooldownDuration` fallback, and the `cooldownDuration` parse for render-mode selection.

**Version guard:** `info.overrideSpellID`/`overrideTooltipSpellID` exist in 12.0.7 (local wow-ui-source + Coolinator use them) but are wiki-annotated 12.1.0 — guard with `info.overrideSpellID and …`. Do **not** assume `equipSlot`/`isInvisible`/`SpecAgnostic*`/`EquipSlot*` categories (12.1.0-only).

## Step 2 — Aura-observation primitive (shared with pandemic)

**Behavior:** when a tracked spell's aura first applies, capture its base `duration` onto the record (`record…learnedActiveDuration`). Lazy upgrade: bar renders `cd_only` until learned, then `active_cd`.

**Perf:** one plugin-level `UNIT_AURA` (player) handler; process `updateInfo.addedAuras` **delta only** (no `GetUnitAuras` rescan); filter against a shared "interested spellIDs" set (union of unlearned records' `auraSpellIds`). Register the handler only while the set is non-empty; **unregister when empty**. As records learn, the set shrinks to zero → no steady-state cost.

**Secret-value:** `aura.duration` is `SecretWhenUnitAuraRestricted` (secret in combat) — guard with `issecretvalue` before storing; if secret, skip and catch the next out-of-combat application. Capture once, cache permanently (drop-time-capture doctrine, see `/unsecreted`).

**Optional:** a *tiny* curated seed table for a handful of marquee spells where waiting for first cast is bad UX — far smaller than today's 9 locale tables + `ACTIVE_DURATION_OVERRIDES`.

## Step 3 — Delete `Core/Shared/TooltipParser.lua`

Both outputs now covered (cooldownDuration from step 1, activeDuration from step 2). Remove the file, the locale pattern tables, and `ACTIVE_DURATION_OVERRIDES`. Repoint `CooldownDragDrop:BuildTrackedBarPayload`/`BuildTrackedItemEntry`/`BuildInjectedItemEntry` at `CooldownData`. Keep `BuildPhaseCurve` (move to a non-parser home) — it consumes durations, not tooltips.

## Step 4 — DurationObject render path (TrackedBar + TrackedIconItem)

Replace the 0.1s ticker's bar-fill curve+`SetValue` and the manual `pct * cooldownDuration` text ([TrackedBar.lua:835-849](TrackedBar.lua)) with:
- `StatusBar:SetTimerDuration(durObj, modRate, Enum.StatusBarTimerDirection.RemainingTime)` — C++ animates the fill; called on cooldown-start/charge events, not per tick.
- `C_DurationUtil.CreateDurationTextBinding()` per text FontString (built once, `:SetDuration` on state change) — C++ updates the countdown. Use `:SetFormatter(FormatTime)` to preserve Orbit's existing time-format fidelity; revisit the `CreateDurationTextBinding` deferral noted in `project_patch_12_0_7`.
- TrackedIconItem already uses `SetCooldownFromDurationObject` for the swipe — keep.

**Memory:** one reused DurationObject per icon/bar (`:SetTimeFromStart`), one binding per FontString. `charges` mode keeps its existing curve trick (RechargeSegment) — those curves are already pooled. The ticker shrinks to event-driven state checks (or self-suspends entirely where the C++ timer covers it). Overlaps with step 3.

**Charges caveat:** `GetSpellChargeDuration` returns a **zero-span** DurationObject at max charges (12.0.5) — treat zero-span as "full", not "0s cooldown".

## Step 5 — Spell picker grid (acquisition; orthogonal)

"+ Add" grid populated from the resolver's cached category sets + a spellbook/flyout/racial sweep, built on Blizzard's `CreateScrollBoxListGridView` (the virtualized grid pattern Blizzard's own pickers use): pooled buttons, already-added entries filtered out, unusable/unknown desaturated. Keep drag-and-drop as the alternate path. Can land any time after step 1; gates nothing.

## Step 6 — Per-icon conditional glows

**Storage:** per-icon override on the record (`record.grid["x,y"].glows` / `record.payload.glows`), resolved with fallback to the viewer/plugin default. CooldownManager needs a new per-spell override → systemIndex-default map.

**UI:** **Ctrl/Alt-click** an icon → popup (shift-right-click is taken by delete — hard rule). Rows gated by `C_CooldownViewer.GetValidAlertTypes(cooldownID)` + resolver `hasAura`/`hasCharges`, so a non-DoT never shows a Pandemic row.

**Render:** route `GlowUtils:BuildOptionsFromLookup` at the per-icon table; `GlowController` already runs multiple **keyed** concurrent glows ("proc"/"pandemic"/"ready"). Conditions are event-driven (proc: `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE` + `C_SpellActivationOverlay.IsSpellOverlayed`; pandemic: aura events + `DurationObject:EvaluateRemainingPercent(stepCurve)` for a secret-safe in-window value → glow alpha / `SetAlphaFromBoolean`). Compile each record's rules into a small per-icon lookup on settings-change; runtime events just flip a glow by key.

---

## Sequencing & risk

| order | step | risk | notes |
|---|---|---|---|
| 1 | Metadata resolver | Low | additive; shared by picker + render |
| 2 | Aura-learn primitive | Med | secret guard + self-disabling listener; pandemic foundation |
| 3 | Delete TooltipParser | Low (after 1+2) | pure removal once covered |
| 4 | DurationObject sinks | Med | net CPU win; verify charges zero-span + text fidelity in-game |
| 5 | Picker grid | Low | orthogonal, any time after 1 |
| 6 | Per-icon glows | Med | the headline feature; built on 1 + 2 |

## Originality

Every module here is written from scratch against Blizzard's public API surface (`C_CooldownViewer`, `C_Spell`, `C_DurationUtil`, `C_UnitAuras`, `C_SpellActivationOverlay`, StatusBar/Cooldown sinks) and Orbit's own existing patterns (`GlowController`, `PluginMixin`, the engine's anchor/canvas systems). No third-party addon source is referenced, copied, or adapted — only Blizzard's documented API names and WoW domain vocabulary (cooldown, charges, pandemic, aura) are shared, as they must be.

## Combat-lockdown / standards

- Tracked frames are `UIParent`-parented and insecure → most layout ops are safe; existing shift-right-click delete already gates on `InCombatLockdown()`. New per-icon glow edits are insecure config — no combat gate needed for the glow itself, but a record-mutation that triggers `Container:Apply` (relayout) must stay out of combat (same as today).
- All new player-facing strings go through `Orbit.L` (new keys in the right domain file, 9 locales).
- No comments beyond genuinely non-obvious WHY (PostToolUse hook enforces). Read this directory's README before editing.

## Open questions

- Pandemic for Tracked: ship as part of step 6, or as its own step? (It's the differentiation play — nobody else ships it.)
- Seed table in step 2: which spells justify it, or skip entirely and accept first-cast learning?
- Picker: replace drag-drop or keep both? (Plan assumes both.)
