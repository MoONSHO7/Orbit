# unit display

shared mixins for all unit frame types. these define the behavioral contracts that player, target, focus, party, raid, and boss frames all share.

## purpose

eliminates duplication across unit frame plugins. any behavior shared by two or more unit frame types lives here as a mixin.

## files

| file | responsibility |
|---|---|
| UnitFrameMixin.lua | base unit frame behavior: show/hide, unit events, health bar display. |
| UnitButton.lua | clickable unit button (secure frame). target, assist, focus on click. |
| UnitButton/ | sub-modules for unit button (text logic, orchestration, canvas). |
| UnitPowerBarMixin.lua | power bar (mana/energy/rage) shared across player, target, focus. |
| ResourceBarMixin.lua | class resource bars (combo points, holy power, essence, etc.). |
| CastBarMixin.lua | cast bar update logic (channeling, empowering, interrupt detection). |
| AuraMixin.lua | aura (buff/debuff) display and filtering. |
| AuraLayout.lua | aura icon grid layout math. |
| AuraPreview.lua | aura preview generation for canvas mode. |
| GroupAuraFilters.lua | aura filter rules for party/raid (dispellable, defensive, etc.). |
| GroupFrameMixin.lua | shared group frame behavior (party/raid header management). |
| GroupFrameEventHandler.lua | shared OnEvent/OnShow handler factory for group frames. |
| PrivateAuraMixin.lua | shared private aura anchor creation and management. |
| GroupCanvasRegistration.lua | shared canvas mode component registration and icon position application. |
| StatusIconMixin.lua | status indicators (defensive, crowd control, movement speed). |
| AggroIndicatorMixin.lua | threat/aggro border coloring. |
| DispelIndicatorMixin.lua | dispellable debuff type indication. |
| PandemicGlow.lua | pandemic window glow for dots/hots. |
| UnitAuraGridMixin.lua | grid-based aura display with size categories (big/small). |
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
