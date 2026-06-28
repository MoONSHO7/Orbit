# selection

interaction handlers for selected Edit Mode frames — drag, nudge, resize, and the selection tooltip.

## purpose

once a frame is selected (overlay wired in `../Selection.lua`), these files handle what the user can *do*
with it. they translate mouse and keyboard input into position/anchor/size changes, then hand off to the
anchor graph (`../Position/Anchor.lua`) and persistence.

## files

| file | responsibility |
|---|---|
| AnchorLines.lua | `Engine.AnchorLines` — the gradient edge-bar renderer (`Ensure`/`ShowOn`/`Hide`). builds two half-textures per edge for a centre-out fade; shared by Edit Mode selection overlays (`../Selection.lua`, `Drag.lua`) and the in-world datatext snap preview (`Plugins/Datatexts/BaseDatatext.lua`). |
| Drag.lua | drag-to-move, mouse-down selection, mouse-wheel padding adjustment. owns the drag lifecycle. |
| Nudge.lua | arrow-key pixel nudge of the selected frame. |
| Resize.lua | drag-to-resize handle; writes width/height settings. |
| Tooltip.lua | selection position/anchor tooltip display. |
| PeekHide.lua | temporary peek of hidden frames while editing. |

## drag lifecycle (Drag.lua)

a drag is three phases. all transient drag state lives in one table, `parent._drag`, created in
`OnDragStart` and destroyed in `OnDragStop` — except `parent.orbitIsDragging`, which stays a plain frame
flag because external code reads it (`../Position/Persistence.lua` uses it to refuse repositioning a
frame mid-drag; the tooltip and the onboarding tour also read it).

**frame move primitive** (`-- [ FRAME MOVE ]` section) — `BeginMove` → `UpdateMove` → `EndMove`:

- `BeginMove` calls WoW's `StartMoving`. if it fails to re-latch a follow point (`GetNumPoints() == 0`
  — an Orbit rounded-corner `MaskTexture` bound onto the frame can cause this), it falls back to
  **manual mode**: it clears WoW's internal moving-state and records a cursor offset.
- `UpdateMove` runs each frame from `OnDragUpdate`; in manual mode it tracks the cursor by hand. no-op
  in native mode (WoW drives the frame) or after the move ends.
- `EndMove` stops the native move and clears the mode flag. `drag.manual` selects the mode.

**drag stop** — `OnDragStop` is a thin orchestrator over three helpers:

- `TeardownDrag` — unconditional visual/state teardown (resume merge group, clear anchor lines, remove
  the `OnUpdate` handler, clear the Blizzard snap preview). always runs, even when the commit is blocked.
- `ResolveDrop` — decides what the drop does and returns a decision table: `kind = "anchor"`, `"free"`,
  or `"precision"`. runs snap detection.
- `CommitDrop` — applies the decision: anchors or positions the frame, persists via the drag callback,
  refreshes group borders.

combat handling is **two-tier**: `TeardownDrag` + `EndMove` always run; the position commit
(`BreakAnchor` + `ResolveDrop`/`CommitDrop`) is combat-guarded.

**fail-safe** — `OnDragStart` snapshots the frame's resolved position into `drag.restorePoint`. if the
drop can't otherwise resolve a position, the frame is restored to that snapshot rather than dumped to
screen origin.

## rules

- drag-internal state goes in `parent._drag`; do not add new loose drag fields to the frame or overlay.
- the move primitive (`StartMoving`/`StopMovingOrSizing`/manual follow) is owned by the `[ FRAME MOVE ]`
  section — do not call those WoW methods directly from the drag handlers.
- `OnDragStop` can fire without a matching `OnDragStart` — every `parent._drag` field is optional.
