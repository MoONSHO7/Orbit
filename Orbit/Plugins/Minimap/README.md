# minimap

orbit's minimap plugin. reparents blizzard's `Minimap` into a clean, borderless orbit container and strips all default art/chrome. reparents several blizzard indicator frames (difficulty, missions, mail, crafting orders) into the container. supports **canvas mode** for fully customisable component placement.

## what it does

- strips blizzard's compass frame, border top, zone text button, and tracking button
- reparents the actual `Minimap` render surface into an orbit-managed frame
- reparents blizzard's instance difficulty, expansion landing page, mail, and crafting order indicators into the overlay
- creates custom zoom in/out buttons with hover-reveal behaviour
- applies orbit's border system (`Orbit.Skin:SkinBorder`) and backdrop. the square shape always uses a square border (`forcePixel`) even under a rounded global Border Style — `Minimap:SetMaskTexture` stretches a flat mask, so the render surface can't be given rounded corners that match a nineslice border
- integrates with edit mode for drag/position/anchor, plus an aspect-locked drag-resize handle that drives the `Size` setting (clamped to the Size slider's 100–400 range)
- supports visibility in pet battles / vehicles via `RegisterVisibilityEvents`
- live-toggle support — can be disabled/enabled without a reload

## file structure

| file                     | responsibility                                                    |
| ------------------------ | ----------------------------------------------------------------- |
| `Minimap.lua`            | plugin registration, lifecycle, capture, components, teardown     |
| `MinimapCompartment.lua` | compartment button, flyout, button collection, hover orchestrator |
| `MinimapSettings.lua`    | settings UI (sliders)                                             |

## canvas mode components

all components below are individually positionable via canvas mode and can be disabled from the canvas mode dock. no settings checkboxes — canvas mode is the single source of truth for component visibility.

| component         | description                                                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **ZoneText**      | zone name button. click opens world map. tooltip shows zone, subzone, pvp status. optional pvp zone colouring via canvas settings |
| **Clock**         | game/local time, updates every second. left-click opens time manager, right-click opens calendar. pending invite glow             |
| **Coords**        | player map coordinates (x, y), updates every 0.1s. hides when no player position is available. supports canvas font/size/color overrides |
| **Compartment**   | collects all LibDBIcon + legacy minimap buttons into a hover-reveal drawer with icon, name, click/tooltip handlers. hidden if a minimap click is bound to `Addons` |
| **Zoom**          | zoom in/out buttons, fade in on minimap hover, fade out on leave. dimmed/disabled at min/max zoom                                 |
| **Difficulty**    | reparented blizzard instance difficulty indicator. icon mode and text mode now use separate internal canvas components, each with its own bounds and saved position |
| **Missions**      | reparented blizzard expansion landing page button (garrison/covenant/etc.)                                                        |
| **Mail**          | reparented blizzard new mail indicator                                                                                            |
| **CraftingOrder** | reparented blizzard crafting order indicator                                                                                      |

the minimap supports configurable left-, middle-, and right-click actions via plugin settings.

canvas overrides (font, size, color) are supported for ZoneText, Clock, Coords, and Difficulty text mode via the canvas component settings panel. canvas respects the `DifficultyShowBackground` toggle in icon mode and shows a placeholder group-size number beneath the skull. `Difficulty` icon mode and text mode are handled as separate internal components, so preview sizing/alignment no longer depends on switching one component between two different geometries.

## blizzard frames affected

| frame                                              | action                                   |
| -------------------------------------------------- | ---------------------------------------- |
| `MinimapCluster`                                   | hidden via `NativeFrame:Hide` (full reparent + event teardown) |
| `MinimapCluster.BorderTop`                         | hidden with cluster                      |
| `MinimapCluster.ZoneTextButton`                    | hidden with cluster                      |
| `MinimapCluster.Tracking`                          | hidden with cluster                      |
| `MinimapCluster.InstanceDifficulty`                | reparented to overlay                    |
| `MinimapCluster.IndicatorFrame.MailFrame`          | reparented to overlay                    |
| `MinimapCluster.IndicatorFrame.CraftingOrderFrame` | reparented to overlay                    |
| `ExpansionLandingPageMinimapButton`                | reparented to overlay (resized to 36×36) |
| `MinimapBackdrop`                                  | alpha set to 0 (hides compass frame art) |
| `MinimapCompassTexture`                            | hidden                                   |

## settings

| key                | type    | default | description                                    |
| ------------------ | ------- | ------- | ---------------------------------------------- |
| `Scale`            | slider  | 100     | overall minimap scale (%)                      |
| `Size`             | slider  | 220     | minimap diameter in pixels                     |
| `BorderRing`       | dropdown | `none`  | decorative ring around the round minimap (`none` / `blizzard` = `ui-hud-minimap-frame` / `round` = solid fill / `fadedcircle` = soft-edge mask / `void` = `wowlabs_minimapvoid-ring-single`). Tinted by `BorderColor`. Only shown when `Shape = round` |
| `ZoneTextColoring` | boolean | true    | colour zone text by pvp type (canvas override) |
| `DifficultyShowBackground`| boolean | false   | show blizzard banner behind difficulty icon on the live minimap |
| `LeftClickAction` | dropdown | `none` | left-click action for the minimap |
| `MiddleClickAction` | dropdown | `none` | middle-click action for the minimap |
| `RightClickAction` | dropdown | `tracking` | right-click action for the minimap |

## data flow

savedvariables → `ApplySettings()` → sizes container, skins border, applies component visibility via `IsComponentDisabled()`, restores canvas positions via `ComponentDrag:RestoreFramePositions()`, applies canvas overrides via `OverrideUtils.ApplyOverrides()`, sets scale

## third-party addon compatibility

### FarmHud

FarmHud reparents the `Minimap` surface to its own full-screen HUD frame while active, then restores it on hide. orbit cooperates via:

1. **`RegisterForeignAddOnObject`** — tells FarmHud about our container so it can move child frames to its dummy placeholder.
2. **`Guard:Suspend` / `Guard:Resume`** — on FarmHud show, FrameGuard protection (SetParent snap-back + enforce-show) is suspended so FarmHud can freely reparent and resize the surface. on hide, protection is resumed.
3. **SetPoint / SetSize hooks** — also check the suspension flag and yield while FarmHud is active.
4. **`ApplySettings()` guards** — minimap surface sync (size bounce, re-anchor) and the recapture check are skipped when `_farmHudActive` is set, so visibility events (mount/dismount/shapeshift) don't fight FarmHud's layout.
5. **No UI hiding needed** — FarmHud's HUD is a separate full-screen frame, not layered under our container. Our Overlay, ClickCapture, and compartment all remain functional on the minimap slot while FarmHud is open.
