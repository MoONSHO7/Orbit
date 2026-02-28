# canvas ui

the user-facing canvas mode dialog. this is the visual layer on top of the canvas engine.

## purpose

renders the canvas mode dialog window: frame preview, component dragging, dock (disabled components), viewport controls, and per-component settings (overrides, fonts, colors).

## files

| file | responsibility |
|---|---|
| Init.lua | dialog frame creation and initialization. |
| Dialog.lua | main dialog logic: open/close, tab filtering, frame selection. |
| DialogActions.lua | dialog button handlers (apply, reset, cancel). |
| Viewport.lua | viewport controls (zoom, pan, sync toggle, preview frame switching). |
| Dock.lua | disabled component dock (drag-to-disable, click-to-restore). |
| DragComponent.lua | component drag-and-drop within the preview frame. |
| ComponentSettings.lua | per-component override panel (font, size, color, position). |
| Creators/ | component creator registry (how to create draggable previews for each component type). |

## adding a new component type to canvas mode

see the `canvas-creators` skill for the full pattern. in brief:

1. create a creator function in `Creators/`
2. register it via `OrbitEngine.CanvasMode.RegisterCreator(key, creatorFn)`
3. the creator receives the source component and returns a draggable preview

## rules

- canvas ui may depend on canvas engine and skinning, never on specific plugins
- all color constants for the dock and dialog must be at file top
- component settings modifications are applied via `OrbitEngine.OverrideUtils`
- the dialog must render correctly regardless of which plugin is active
