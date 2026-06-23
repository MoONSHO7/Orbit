# unit display

shared mixins for all unit frame types. these define the behavioral contracts that player, target, focus, party, raid, and boss frames all share.

## purpose

eliminates duplication across unit frame plugins. any behavior shared by two or more unit frame types lives here as a mixin.

## files

| file | responsibility |
|---|---|
| UnitFrameMixin.lua | base unit frame behavior: show/hide, unit events, health bar display. |
| UnitButton.lua | clickable unit button (secure frame). target, assist, focus on click. |
| UnitButton/UnitButtonCore.lua | unit button initialization and lifecycle orchestration. |
| UnitButton/UnitButtonHealth.lua | health bar display and update logic. |
| UnitButton/UnitButtonText.lua | name, level, and health text rendering. Health text is a **typed format string** (set via `SetHealthTextFormat`) that `ParseFormat` turns into an ordered **segment** list (`{t="value",v=tokenId}` / `{t="sep",v=text}` / `{t="mo"}` mouseover divider). The typed keys live in `UnitButton.HEALTH_TOKENS` (`%`→percentage, `Current`→full current `466095`, `CurrentK`→abbreviated current `466K`, `Max`→full max `500000`, `MaxK`→abbreviated max `500K`, plus `&` mouseover) — each token has a `key`, `sample`, and live `format(unit)`; Canvas Mode reads them as data for the input-box tooltip. Since `UnitHealth`/`UnitHealthMax` are secret in 12.0, the short tokens abbreviate via `AbbreviateNumbers` + a cached `CreateAbbreviateConfig` (which accept secret values, unlike Lua arithmetic) — custom breakpoints yield a clean `466K`/`1.5M` above 10,000 — and the full tokens forward the raw secret to the FontString sink, which renders a plain number with no separators. The parser matches keys longest-first, so `CurrentK`/`MaxK` win over the `Current`/`Max` prefixes. Everything between/around tokens is literal text; the whole string (and whitespace adjacent to `&`) is trimmed. An empty side of the `&` divider renders blank on the live frame (so `& Current` shows nothing until mouseover, and `Current &` shows nothing on mouseover); `HealthFormatRestSample` (the per-component Canvas Mode preview) falls back to the other side when the at-rest side is empty, so the component stays visible and selectable while editing; group-frame preview rows pass `noFallback=true` to instead mirror the live at-rest render exactly (blank when the rest side is empty), per that plugin's preview-parity rule. `UnitButton.ValidateHealthFormat` rejects more than one `&` or a value token repeated within the same side (used by the canvas input to drive a red border). When no custom string is set, the legacy `HealthTextMode` preset is mapped to segments by `LegacyModeToSegments` (and to a seed string by `LegacyHealthModeToFormatString`). `RenderHealthText` builds a `%s`-slot format string (values) + literal separators and fills it via `SetFormattedText`, which accepts secret arguments C-side — so several secret values combine (e.g. `466K - 500K`) without the Lua concatenation that would throw on a secret. The mouseover rest/hover split is cached per frame. `UpdateHealthText` applies status before value: a disconnected unit shows `PLAYER_OFFLINE` and a dead/ghost unit shows `DEAD` (Blizzard globals, both plain booleans from `UnitIsConnected`/`UnitIsDeadOrGhost`) regardless of the format string — including a blank one. The format distinguishes `""` (blank/whitespace → renders no value; status still shows) from `nil` (no custom string → falls back to the legacy `HealthTextMode` preset); `RecomputeHealthSegments` and `HealthFormatRestSample` both key off `type(fmt) == "string"` so the live frame and the Canvas Mode preview never diverge. |
| UnitButton/UnitButtonCanvas.lua | canvas mode component registration for unit buttons. |
| UnitButton/UnitButtonPortrait.lua | portrait frame creation and class/race portrait rendering. |
| UnitButton/UnitButtonPrediction.lua | incoming heal prediction overlay. |
| UnitButton/PortraitRingData.lua | portrait ring atlas coordinate data. |
| UnitPowerBarMixin.lua | power bar (mana/energy/rage) shared across player, target, focus. |
| ResourceBarMixin.lua | class resource bars (combo points, holy power, essence, etc.). |
| CastBarMixin.lua | cast bar update logic (channeling, empowering, interrupt detection). |
| AuraMixin.lua | aura (buff/debuff) display and filtering. caches per-container layout via `_auraFingerprint` keyed by aura instance IDs to skip unchanged rebuilds; settings-changing call sites (e.g. plugin `ApplySettings`) must call `Mixin:InvalidateContainerLayout(frame)` before the next update or the container will keep its old layout. reads `ComponentPositions` via `plugin:GetComponentPositions` (transaction-aware) — never via raw `GetSetting`. |
| AuraSnapshotCache.lua | per-frame harmful/helpful aura caches keyed by `auraInstanceID`, patched incrementally from partial `UNIT_AURA` `updateInfo` (added/updated/removed) so unchanged auras aren't re-fetched. extracted from `AuraMixin` so the mixin owns icon/container display, not cache bookkeeping. `Build` returns a single module-wide recycled scratch snapshot (harmful, helpful, and `spellId`-keyed maps); consumers must fully drain it before the next `Build` and never retain a reference past dispatch. |
| HealerAuraTicker.lua | singleton `C_Timer.NewTicker` (0.05s) driving healer-aura curve-based swipe/timer visuals. extracted from `AuraMixin` so the mixin owns icon/container display, not animation. samples each icon's remaining-percent through an identity `C_CurveUtil` curve (secret → numeric) and feeds `Engine.ColorCurve` to color the cooldown swipe and timer text; self-cancels when no icons remain registered. |
| AuraLayout.lua | aura icon grid layout math. |
| AuraPreview.lua | aura preview generation for canvas mode. |
| PreviewAnimator.lua | shared OnUpdate-throttled animator for edit-mode preview frames (health drift, shield/necrotic pulses, damage-bar decay, death-fade, periodic aura swap). per-owner enable list keeps the ticker idle when no preview is open. |
| GroupAuraFilters.lua | aura filter rules for party/raid (dispellable, defensive, etc.). |
| GroupFrameMixin.lua | shared group frame behavior (party/raid header management). |
| GroupFrameEventHandler.lua | shared OnEvent/OnShow handler factory for group frames. builds per-event aura snapshot (`_auraSnapshot`) via 2 `GetUnitAuras` calls (HARMFUL + HELPFUL). all aura consumers (containers, single icons, healer auras, dispel) read from the snapshot with zero additional C API aura fetches. |
| PrivateAuraMixin.lua | shared private aura anchor creation and management. |
| GroupCanvasRegistration.lua | shared canvas mode component registration and icon position application. |
| StatusIconMixin.lua | status indicators (defensive, crowd control, movement speed), selection/aggro highlight borders via `Skin:ApplyHighlightBorder`. |
| AggroIndicatorMixin.lua | threat/aggro border coloring via `Skin:ApplyHighlightBorder`. |
| DispelIndicatorMixin.lua | dispellable debuff type indication with `DispelOnlyByMe` filter support. drives both the dispel glow (via `GlowController`) and the optional `frame.DispelIcon` container (a Frame holding one sub-texture per dispel type — `aura.dispelName` is secret in encounters, so per-type alpha is driven via `GetAuraDispelTypeColor` with per-type alpha curves; `SetAlpha` accepts secret values, so the matching texture wins via C++ sink). caches the dispel color curve on plugin (`_dispelCurveCache`), invalidated via `InvalidateDispelCurve`. accepts pre-fetched harmful auras from snapshot. |
| PandemicGlow.lua | thin adapter for pandemic glow on UnitDisplay aura icons. evaluates pandemic curves and delegates rendering to `GlowController`. |
| UnitAuraGridMixin.lua | grid-based aura display with size categories (big/small). owns the mixin surface and the file-local helpers (`ResolveGrowthDirection`, `UpdateCollapseArrow`, `CropIconTexture`) which are re-exposed on `Mixin._Internal` for the split files below. |
| UnitAuraGridReparenting.lua | attaches `Mixin:_updateBlizzardBuffs()`. reparents Blizzard's native `BuffFrame.auraFrames` into an Orbit grid, suppresses stock borders/textures, and wires timer + stacks into Orbit's font/override system. reaches file-locals via `Mixin._Internal`. |
| SecondaryUnitFrameMixin.lua | secondary frames (target-of-target, focus-target). |

## adding a new mixin

1. create the mixin file: `NewBehaviorMixin.lua`
2. define it as `Orbit.NewBehaviorMixin = {}`
3. implement methods that accept `(self, frame, settings)` — where self is the mixin, frame is the unit frame, settings is the plugin config
4. after the table is fully populated, freeze it with `if table.freeze then table.freeze(NewBehaviorMixin) end` (12.0.5+) so a stray runtime write errors immediately
5. plugins call the mixin in their `ApplySettings`
6. add the new file to `Core/UnitDisplay/UnitDisplay.xml` as a `<Script file="NewFile.lua"/>` entry; ensure it loads after its dependencies

## rules

- mixins must be **stateless**. state lives on the frame (`frame._mixinState`), not on the mixin table
- freeze the mixin table with `table.freeze` once it is fully populated (12.0.5+) so a stray runtime write fails loud instead of silently corrupting the shared table
- mixins must never reference a specific plugin by name
- a mixin is justified only when **two or more** plugins share the behavior. one-off logic stays in the plugin
- unit display mixins are **feature modules**: each owns its behavior *plus* the config schema and canvas preview for that feature. they may therefore render their own settings via `Engine.Config:Render` (from their `Add*Settings` methods) and build canvas preview components via `CanvasMode.CreateDraggableComponent` / read the active transaction — this is feature cohesion, not a layering inversion (the module already ships `UnitButtonCanvas`, `AuraPreview`, `GroupCanvasRegistration`).
- what they must NOT do: reach into a specific **plugin** by name, or read CanvasMode's runtime edit state through the module. for "is this frame being canvas-edited" read the shared `Orbit.canvasActiveFrame` namespace flag (published by CanvasMode), never `Orbit.Engine.CanvasMode:IsActive`/`.currentFrame`.
