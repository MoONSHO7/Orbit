# boss frames

unit frames for boss encounters (boss1-boss5).

## purpose

displays boss health bars, cast bars, and auras during encounters. uses the shared unit display mixins from core.

## files

| file | responsibility |
|---|---|
| BossFrame.lua | main plugin. frame creation, event handling, settings application, aura display. |
| BossFrameCastBar.lua | boss cast bar creation and update logic. |
| BossFrameHelpers.lua | aura position helper (`AnchorToPosition`) shared with the canvas-mode aura preview. |
| BossFramePreview.lua | canvas mode preview for boss frames. |

## how it works

5 boss frames (boss1-boss5) are created eagerly in `OnLoad` via `for i = 1, MAX_BOSS_FRAMES` (`MAX_BOSS_FRAMES = 5`, defined at the top of `BossFrame.lua`). they use `UnitButton` from core/unitdisplay for secure targeting.

## adding a new boss frame feature

1. add the behavior to `BossFrame.lua` in `ApplySettings`
2. if it's a shared unit frame behavior, add it to core/unitdisplay instead
3. add schema entries in `AddSettings`

## rules

- boss frames share the aura `AnchorToPosition` helper via `BossFrameHelpers` for canvas-mode preview parity
- new cast bar features must use `CastBarMixin`. **known divergence:** `BossFrameCastBar.lua` predates the consolidation rule and currently reimplements the cast-bar update loop. Consolidating into `CastBarMixin` is tracked technical debt — until then, treat the rule as "new cast bars MUST use CastBarMixin; existing reimplementations are technical debt."
- boss cast bar uses the unified border pattern (single border wrapping icon + bar via `UpdateBarInsets`) matching the target/focus style from `Skin.CastBar`
- boss frame count is 5 (`MAX_BOSS_FRAMES = 5`); frames are allocated eagerly, not on demand
