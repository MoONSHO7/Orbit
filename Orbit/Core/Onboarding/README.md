# onboarding

first-run guided experiences that teach new users how orbit works.

## directory structure

```
Onboarding/
  TourPlugin.lua      -- Orbit plugin (RegisterPlugin) for playground frames
  EditModeTour.lua     -- tour flow: dark overlay, tour stops, snap isolation
  WelcomeDialog.lua    -- first-login welcome + keybind setup, then launches the tour
  Onboarding.xml       -- xml script bundle
  README.md
```

## edit mode tour

a first-login-only anchoring playground that fires on Edit Mode entry:

- `TourPlugin.lua` registers `"Orbit_Tour"` via `Orbit:RegisterPlugin`, creates frames with `FrameFactory:Create`, defines `AddSettings` with `SchemaBuilder` (width/height)
- `EditModeTour.lua` drives the tour flow: dark overlay, 9 sequential stops (`TOUR_STOPS`, `TOUR_EM_STEP1..9`), task-gated Next buttons, snap isolation, drag/anchor/nudge tracking, welcome title, post-tour hints
- selecting a playground frame opens Orbit's real settings dialog
- while the tour is active the overlay captures `ESCAPE` (consumes it so it never reaches Edit Mode's close) and shows `OrbitTourExitDialog`, a confirmation styled to match the Canvas Mode frame (`NineSlicePanelTemplate` with the `ButtonFrameTemplateNoPortrait` layout, tiled `UI-Background-Rock` background, `_UI-Frame-TopTileStreaks`). **Return to Tour** dismisses it; **Exit Tour** calls `EndTour` then `securecall("HideUIPanel", EditModeManagerFrame)` — the taint-safe exit Orbit uses elsewhere, never a bare `:Hide()`/`HideUIPanel`. Non-`ESCAPE` keys still propagate, so arrow-key nudging keeps working.
- `StartTour` sets `Orbit.db.AccountSettings.TourComplete = true` on tour entry to prevent re-triggering across reloads
- ending the tour (Done **or** an early Exit) marks both hints pending (`CanvasHintComplete`/`DrawerHintComplete` `nil → false` in `EndTour`), so they always get shown at least once even on early exit
- the two hints live in **different contexts**:
  - **Canvas Mode hint** (above the PlayerFrame) is an Edit Mode hint — shown on `EditMode.Enter` while pending, hidden on `EditMode.Exit` (sticky). Opening Canvas Mode (`Engine.CanvasMode:Toggle`) sets `CanvasHintComplete = true`.
  - **Datatext Drawer hint** (screen TOPLEFT) is a **main-screen** hint — shown on `EditMode.Exit` while pending (i.e. once the tour is over and the user is back on the main screen), and hidden again on `EditMode.Enter` so it never appears inside Edit Mode. Opening the Datatext Drawer (`Orbit.Datatexts.DrawerUI:Toggle`) sets `DrawerHintComplete = true`. `ShowDrawerHint` is gated on `Orbit:IsPluginEnabled("Datatexts")` — the only way to dismiss the hint is to open the drawer, which is impossible while the plugin is disabled, so the hint is suppressed (and stays pending) until Datatexts is re-enabled.
  - both stay pending (re-show) until the user opens the corresponding feature
- `Tour:OpenAndStart()` is the external entry: opens Edit Mode if closed (`securecall("ShowUIPanel", EditModeManagerFrame)`), then defers `StartTour(true)` by `EDIT_MODE_OPEN_DELAY` so entry can build the frame selections the tour depends on. It is combat-guarded (Edit Mode can't be entered in combat). Both Spotlight (**Open → Replay the Tour**, which force-starts bypassing the completion flag) and the welcome dialog's **Start Tour** button call it.

## welcome dialog

a first-login-only dialog (`WelcomeDialog.lua`) shown `SHOW_DELAY` after `PLAYER_LOGIN`, gated on `Orbit.db.AccountSettings.WelcomeComplete` (nil by default, set `true` on dismiss). On a fresh install `WhatsNew` suppresses itself, so this fills the first-run slot.

- shares the Canvas Mode frame skin via the local `BuildChrome` helper (NineSlice `ButtonFrameTemplateNoPortrait` + tiled `UI-Background-Rock` + `_UI-Frame-TopTileStreaks` + a title above the NineSlice). `OrbitWelcomeDialog` and the keybind sub-box `OrbitWelcomeKeybinds` both use it.
- **ESC handling** is via per-frame `OnKeyDown`, not `UISpecialFrames`: the welcome dialog deliberately does **not** close on ESC (it swallows ESC so it can't reach the game menu behind this Topmost dialog) — it closes only via **Start Tour** or the **X**. The keybind box (higher frame level) does close on ESC while open; during an active capture the listening button consumes ESC first to cancel.
- two buttons (`Layout:CreateButton`, stretched): **Set Keybinds** opens `OrbitWelcomeKeybinds`; **Start Tour** starts `:Disable()`d with a locked tooltip (`SetMotionScriptsWhileDisabled(true)` so the tooltip fires while greyed) and enables when the keybind box closes, then dismisses the dialog and calls `Tour:OpenAndStart()`.
- **keybind rows** replicate the in-game Keybinds menu button: `UIMenuButtonStretchTemplate` + a `UI-Silver-Button-Select` highlight, with capture mirroring Blizzard's `KeybindListener` (`GetConvertedKeyOrButton` → `IsKeyPressIgnoredForBinding` → `CreateKeyChordStringUsingMetaKeyState` → `SetBinding` → `SaveBindings(GetCurrentBindingSet())`). While listening the button consumes keyboard so ESC cancels the capture instead of closing the box. Row labels come from `GetBindingName(action)`. The button only references the binding **action strings** (`ORBIT_SPOTLIGHT_TOGGLE`, `ORBIT_MINIMAP_TOGGLEVIEW`), not the Spotlight/Minimap modules — so the inward-only dependency rule holds.
- **default binds** (`ApplyDefaultBinds`, run when the keybind box opens, idempotent — only binds an action that has no current key): Spotlight → `NUMPADMINUS` (fallback `SHIFT-=`), HUD Map → `NUMPADPLUS` (fallback `SHIFT--`). "Skip if taken": if the primary key is already bound to another action, try the fallback; if that's also taken, leave it unbound for the player to set. There is no API to detect a physical numpad, so the fallback is a conflict heuristic, not numpad detection.

## rules

- **all onboarding UI must share the same strata.** overlay, playground frames, selection overlays, settings dialog, and tooltips must all be at `TOOLTIP` strata during the tour. this ensures everything is clickable and draggable above the darkened background.
- **save and restore strata.** any frame elevated for the tour must have its original strata/level saved on tour start and restored on tour end.
- **use the OnUpdate poller to enforce strata.** other systems (DeselectAll, UpdateVisuals, dialog open/close) continuously reset strata. the poller re-elevates every frame on each tick.
- **no custom settings UI.** playground frames are a real plugin. clicking them opens `OrbitSettingsDialog` with standard `SchemaBuilder` controls. do not create custom sliders or panels.
- **hide all other UI.** all other Orbit plugin frames and containers must be hidden while onboarding is active. `EditModeManagerFrame` is hidden visually via `:SetAlpha(0)` + `:EnableMouse(false)` on tour start and restored to `:SetAlpha(1)` + `:EnableMouse(true)` on tour end. **NEVER use `:Hide()`, `HideUIPanel(EMF)`, or `CheckHideAndLockEditMode` on EMF** — all three fire `OnHide` → `OnEditModeExit` → `ResetPartyFrames` → tainted `CompactUnitFrame_UpdateHealthColor` (secret-value compare crash in 12.0.5+). `SetAlpha`/`EnableMouse` do not fire `OnHide` and do not enter the UI panel system, so they avoid the cascade. only the overlay, playground frames, settings dialog, and tooltip should be visible.
- **snap isolation.** playground frames must only snap to each other, not to other Orbit frames. this is done by overriding `GetSnapTargets` during the tour.
- **preserve factory registrations.** never destroy `Selection.selections`, `dragCallbacks`, or `selectionCallbacks` for tour frames — the factory owns them. just hide/show the overlays.
- **HookScript must be one-shot.** EditModeManagerFrame OnShow/OnHide hooks for hint lifecycle are installed at module load (single-fire registration). The `originalCanvasToggle` / `originalDrawerToggle` upvalues guard against stacking the per-feature Toggle hooks across re-shows.

## dependencies

loads after `EditMode.xml` (needs `FrameSelection`, `FrameAnchor`, `SelectionResize`, `FrameFactory`).
