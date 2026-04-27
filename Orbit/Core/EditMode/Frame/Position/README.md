# position

anchor graph, cross-axis size sync, persistence, and pixel utilities for orbit frames. axis-parameterized: one implementation handles both orientations.

## files

| file | responsibility |
|---|---|
| Axis.lua | first-class `horizontal` / `vertical` axis primitives (edges, accessors, row-dim field, independent-flag name, sync-flag name). `Axis.ForEdge` / `Axis.SyncEnabled` helpers. exposed as `OrbitEngine.Axis`. |
| AnchorGraph.lua | pure-data directed graph: virtual / disabled state, cycle detection, targeted reconciliation. |
| Anchor.lua | physical + logical anchor graph, parent→child cross-axis size sync, merge-border state. |
| Persistence.lua | position / anchor save+restore to saved variables; pending queue for load-order races; per-spec routing. |
| PositionUtils.lua | position math helpers (offset calculation, bounds). |

## axis model

the engine treats orientation as a first-class domain primitive. anchor / sync operations are one implementation parameterized by an axis table:

```lua
Engine.Axis.horizontal = {
    edges           = { LEFT = true, RIGHT = true },
    forward         = "RIGHT",        -- direction of increasing coord
    backward        = "LEFT",
    getSize         = GetWidth, setSize = SetWidth,
    getMin          = GetLeft,  getMax  = GetRight,
    minSize         = 10,
    rowDim          = "orbitColumnWidth",
    independentFlag = "independentWidth",
    syncFlag        = "orbitWidthSync",
    perpendicular   = Engine.Axis.vertical,
}
```

`Engine.Axis.vertical` mirrors with `{TOP, BOTTOM}`, height accessors, `orbitRowHeight`, `independentHeight`, `orbitHeightSync`. the Axis namespace is public (`OrbitEngine.Axis`) — plugins can use it in their own layout code instead of hardcoding `SetWidth` / `SetHeight`.

### how axis flows through anchor code

`CreateAnchor` / `SyncChild` / `ApplyAnchorPosition` / `BreakAnchor` all derive the axis from the anchor's edge via `Axis.ForEdge(edge)` and use `edgeAxis.perpendicular` for cross-axis size sync. there is no "horizontal path" and "vertical path" — one code path, axis flows through.

**the anchor graph is strictly one-directional: the parent is the source of truth, the child is positioned relative to it.** no chain-walking, no extent aggregation, no visual-center rebalance. a frame's dimensions and position are influenced only by its immediate parent (if anchored) or its own saved settings (if a root). siblings do not see each other through the engine.

## sync flags

two independent boolean frame fields control whether a frame's size syncs from its anchor parent:

| flag | effect |
|---|---|
| `frame.orbitWidthSync = true`  | when T/B-anchored, child.width syncs to the **direct** parent's width |
| `frame.orbitHeightSync = true` | when L/R-anchored, child.height syncs to the **direct** parent's height |

both can be set independently. `Axis.SyncEnabled(frame, axis)` reads `frame[axis.syncFlag]` — the single resolver every sync check routes through.

the sync is **immediate parent only**. no chain extent, no combined widths, no propagation across siblings. if PlayerFrame and a cooldown viewer are L/R-anchored and both have `orbitWidthSync`, they don't form a width-chain that leaks into their T/B children — each child still reads its own direct parent's size.

## cross-axis size opt-outs

two symmetric anchor options that block an otherwise-active sync:

| flag | effect |
|---|---|
| `independentHeight` | L/R-anchored child with `orbitHeightSync=true` keeps its own height (blocks height sync from parent) |
| `independentWidth`  | T/B-anchored child with `orbitWidthSync=true` keeps its own width (blocks width sync from parent) |

preserved legacy quirk: when the independent flag is set AND `suppressApplySettings` is false, the engine DOES sync cross-axis size AND records the result back to the plugin's saved `Height` / `Width` setting. used by UnitFrames to "normalize" height when chaining live. extended symmetrically to `independentWidth` → `Width` setting.

## load order

from `EditFrame.xml`:

1. `Guard.lua` (combat safety)
2. `Position/PositionUtils.lua`
3. `Position/Axis.lua` — must load before AnchorGraph / Anchor since they import `Engine.Axis` at file scope
4. `Position/AnchorGraph.lua`
5. `Position/Anchor.lua` — initializes graph via `Graph:Init()`
6. `Position/Persistence.lua`

## rules

- axis-aware code must never branch on hardcoded `LEFT`/`RIGHT`/`TOP`/`BOTTOM` — always `axis.edges[edge]` / `axis.forward` / `axis.backward`.
- new axis-dependent behavior goes in the Axis table, not as a branch in a consumer.
- cycle detection runs through `Graph:WouldCreateCycle` before any `CreateAnchor`.
- parent frames are authoritative: attaching or detaching a child never moves the parent.
- opt into cross-axis size sync per axis: `frame.orbitWidthSync = true` and/or `frame.orbitHeightSync = true`. each flag only affects sync FROM the frame's own direct parent — siblings never propagate size.
