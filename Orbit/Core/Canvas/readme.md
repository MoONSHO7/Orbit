# canvas

canvas mode engine. handles frame positioning, anchoring, dragging, and the edit mode integration.

## purpose

provides the spatial management layer for all movable frames. when a user enters edit mode, canvas takes over to enable drag-and-drop positioning, anchor chains, snap guides, and position persistence.

## directory structure

```
Canvas/
  EditMode.lua          -- edit mode entry/exit hooks
  PositionManager.lua   -- position save/restore (session buffer)
  MountedVisibility.lua -- hide frames while mounted
  NativeFrame.lua       -- native blizzard frame suppression/reparenting
  Frame/                -- frame-level operations
    Frame.lua           -- frame factory, selection, dimension sync
    Position/           -- anchor chains, snap guides, position math
    Selection/          -- selection overlay, tooltips, native hooks
    Component/          -- component-level drag (text, icons within a frame)
  Handle/               -- resize handles
  Preview/              -- canvas preview frame generation
```

## adding a new positionable frame type

1. in your plugin, set `frame.anchorOptions` with the allowed behaviors
2. call `OrbitEngine.Frame:AttachSettingsListener(frame, plugin, systemIndex)`
3. the canvas system will automatically handle dragging, anchoring, and persistence
4. create a `CreateCanvasPreview` method on the frame for canvas mode dialog rendering

## rules

- canvas code must work without any specific plugin loaded
- position data format: `{ point, relativeTo, relativePoint, x, y }`
- anchor chains resolve recursively. guard against cycles with depth limits.
- all pixel offsets must be snapped via `Pixel:Snap()`
- mounted visibility checks belong in `MountedVisibility.lua`, not in plugins
