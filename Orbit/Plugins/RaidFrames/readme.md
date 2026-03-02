# raid frames

unit frames for raid members (raid1-raid40).

## purpose

displays health, dispel indicators, auras, and role icons for raid groups. designed for high-density display with minimal overhead. uses secure group headers with sorting/filtering.

## files

| file | responsibility |
|---|---|
| RaidFrame.lua | main plugin. frame creation, event handling, aura display, settings application. |
| RaidFrameSettings.lua | settings schema builder with sub-tabs (layout, auras, colors). |
| RaidFrameFactory.lua | secure unit button factory for raid member frames. |
| RaidFrameHelpers.lua | layout helpers (grid stacking, border merging, group headers). |
| RaidFramePreview.lua | canvas mode preview with mock raid data. |

## how it works

raid frames use a grid layout driven by group count and sort order. performance is critical since up to 40 frames update simultaneously during encounters.

## adding a new raid frame feature

1. if shared with party/boss, add to core/unitdisplay
2. if raid-specific, add to `RaidFrame.lua`
3. add schema entries in `RaidFrameSettings.lua`

## rules

- raid frame update functions must be o(1) per frame. no iteration over all members during single-frame updates
- aura filtering must use the optimized grid mixin (`UnitAuraGridMixin`)
- frame recycling must properly reset all state. no stale data between unit assignments
- sort order changes must not trigger combat-unsafe operations
