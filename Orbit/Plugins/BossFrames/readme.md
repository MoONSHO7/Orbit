# boss frames

unit frames for boss encounters (boss1-boss8).

## purpose

displays boss health bars, cast bars, and auras during encounters. uses the shared unit display mixins from core.

## files

| file | responsibility |
|---|---|
| BossFrame.lua | main plugin. frame creation, event handling, settings application, aura display. |
| BossFrameCastBar.lua | boss cast bar creation and update logic. |
| BossFrameHelpers.lua | layout helpers (merged borders, stacking). |
| BossFramePreview.lua | canvas mode preview for boss frames. |

## how it works

boss frames are created on demand when `INSTANCE_ENCOUNTER_ENGAGE_UNIT` fires. they use `UnitButton` from core/unitdisplay for secure targeting and `CastBarMixin` for cast bar updates.

## adding a new boss frame feature

1. add the behavior to `BossFrame.lua` in `ApplySettings`
2. if it's a shared unit frame behavior, add it to core/unitdisplay instead
3. add schema entries in `AddSettings`

## rules

- boss frames share layout merging with party/raid via `BossFrameHelpers`
- cast bar logic must not duplicate `CastBarMixin` — extend the mixin if needed
- boss frame count is dynamic (1-8), driven by encounter data
