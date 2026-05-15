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
| UnitButton/UnitButtonText.lua | name, level, and status text rendering. |
| UnitButton/UnitButtonCanvas.lua | canvas mode component registration for unit buttons. |
| UnitButton/UnitButtonPortrait.lua | portrait frame creation and class/race portrait rendering. |
| UnitButton/UnitButtonPrediction.lua | incoming heal prediction overlay. |
| UnitButton/PortraitRingData.lua | portrait ring atlas coordinate data. |
| UnitPowerBarMixin.lua | power bar (mana/energy/rage) shared across player, target, focus. |
| ResourceBarMixin.lua | class resource bars (combo points, holy power, essence, etc.). |
| CastBarMixin.lua | cast bar update logic (channeling, empowering, interrupt detection). |
| AuraMixin.lua | aura (buff/debuff) display and filtering. caches per-container layout via `_auraFingerprint` keyed by aura instance IDs to skip unchanged rebuilds; settings-changing call sites (e.g. plugin `ApplySettings`) must call `Mixin:InvalidateContainerLayout(frame)` before the next update or the container will keep its old layout. reads `ComponentPositions` via `plugin:GetComponentPositions` (transaction-aware) — never via raw `GetSetting`. |
| AuraLayout.lua | aura icon grid layout math. |
| AuraPreview.lua | aura preview generation for canvas mode. |
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
| UnitAuraGridExpirationPulse.lua | shared expiration pulse ticker. attaches `Mixin._RegisterExpirationPulse(icon, durObj)`. owns the pulse list and lazy `C_Timer.NewTicker` that cancels when the list drains. lives outside the mixin file because mixins must be stateless. |
| UnitAuraGridReparenting.lua | attaches `Mixin:_updateBlizzardBuffs()`. reparents Blizzard's native `BuffFrame.auraFrames` into an Orbit grid, suppresses stock borders/textures, and wires timer + stacks into Orbit's font/override system. reaches file-locals via `Mixin._Internal` and registers expirations via `Mixin._RegisterExpirationPulse`. |
| SecondaryUnitFrameMixin.lua | secondary frames (target-of-target, focus-target). |

## adding a new mixin

1. create the mixin file: `NewBehaviorMixin.lua`
2. define it as `Orbit.NewBehaviorMixin = {}`
3. implement methods that accept `(self, frame, settings)` — where self is the mixin, frame is the unit frame, settings is the plugin config
4. plugins call the mixin in their `ApplySettings`
5. add to `Orbit.toc` in the unitdisplay section

## rules

- mixins must be **stateless**. state lives on the frame (`frame._mixinState`), not on the mixin table
- mixins must never reference a specific plugin by name
- a mixin is justified only when **two or more** plugins share the behavior. one-off logic stays in the plugin
- unit display modules may depend on skinning and infrastructure, never on config or canvas
