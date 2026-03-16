# onboarding

first-run guided experiences that teach new users how orbit works.

## directory structure

```
Onboarding/
  TourPlugin.lua      -- Orbit plugin (RegisterPlugin) for playground frames
  EditModeTour.lua     -- tour flow: dark overlay, tour stops, snap isolation
  Onboarding.xml       -- xml script bundle
  readme.md
```

## edit mode tour

a first-login-only anchoring playground that fires on Edit Mode entry:

- `TourPlugin.lua` registers `"Orbit_Tour"` via `Orbit:RegisterPlugin`, creates frames with `FrameFactory:Create`, defines `AddSettings` with `SchemaBuilder` (width/height)
- `EditModeTour.lua` drives the tour flow: dark overlay, 8 sequential stops, task-gated Next buttons, snap isolation, drag/anchor/nudge tracking, welcome title, canvas mode hint
- selecting a playground frame opens Orbit's real settings dialog
- on completion, sets `Orbit.db.GlobalSettings.TourComplete = true` to prevent re-triggering
- after Done, shows a canvas mode hint tooltip above the PlayerFrame; right-clicking any frame dismisses it
- `/orbittour` force-starts the tour for testing, bypassing the completion flag

## rules

- **all onboarding UI must share the same strata.** overlay, playground frames, selection overlays, settings dialog, and tooltips must all be at `FULLSCREEN_DIALOG` strata during the tour. this ensures everything is clickable and draggable above the darkened background.
- **save and restore strata.** any frame elevated for the tour must have its original strata/level saved on tour start and restored on tour end.
- **use the OnUpdate poller to enforce strata.** other systems (DeselectAll, UpdateVisuals, dialog open/close) continuously reset strata. the poller re-elevates every frame on each tick.
- **no custom settings UI.** playground frames are a real plugin. clicking them opens `OrbitSettingsDialog` with standard `SchemaBuilder` controls. do not create custom sliders or panels.
- **hide all other UI.** all other Orbit plugin frames, containers, and Blizzard Edit Mode chrome must be hidden while onboarding is active. restore them on tour end. only the overlay, playground frames, settings dialog, and tooltip should be visible.
- **snap isolation.** playground frames must only snap to each other, not to other Orbit frames. this is done by overriding `GetSnapTargets` during the tour.
- **preserve factory registrations.** never destroy `Selection.selections`, `dragCallbacks`, or `selectionCallbacks` for tour frames — the factory owns them. just hide/show the overlays.
- **HookScript must be one-shot.** use a flag to prevent stacking hooks on frames like `EditModeManagerFrame` across multiple `ShowCanvasHint` calls.

## dependencies

loads after `EditMode.xml` (needs `FrameSelection`, `FrameAnchor`, `SelectionResize`, `FrameFactory`).
