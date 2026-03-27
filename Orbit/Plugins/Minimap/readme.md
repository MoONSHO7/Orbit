# minimap

orbit's minimap plugin. reparents blizzard's `Minimap` into a clean, borderless orbit container and strips all default art/chrome. reparents several blizzard indicator frames (difficulty, missions, mail, crafting orders) into the container. supports **canvas mode** for fully customisable component placement.

## what it does

- strips blizzard's compass frame, border top, zone text button, and tracking button
- reparents the actual `Minimap` render surface into an orbit-managed frame
- reparents blizzard's instance difficulty, expansion landing page, mail, and crafting order indicators into the overlay
- creates custom zoom in/out buttons with hover-reveal behaviour
- applies orbit's border system (`Orbit.Skin:SkinBorder`) and backdrop
- integrates with edit mode for drag/position/anchor
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

canvas overrides (font, size, color) are supported for ZoneText, Clock, Coords, and Difficulty text mode via the canvas component settings panel. canvas always shows the difficulty background to make placement easier in icon mode. `Difficulty` icon mode and text mode are handled as separate internal components, so preview sizing/alignment no longer depends on switching one component between two different geometries.

## blizzard frames affected

| frame                                              | action                                   |
| -------------------------------------------------- | ---------------------------------------- |
| `MinimapCluster`                                   | hidden via `NativeFrame:Hide`            |
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
| `Opacity`          | slider  | 100     | out-of-hover opacity (%)                       |
| `Size`             | slider  | 220     | minimap diameter in pixels                     |
| `ZoneTextColoring` | boolean | true    | colour zone text by pvp type (canvas override) |
| `DifficultyShowBackground`| boolean | false   | show blizzard banner behind difficulty icon on the live minimap |
| `LeftClickAction` | dropdown | `none` | left-click action for the minimap |
| `MiddleClickAction` | dropdown | `none` | middle-click action for the minimap |
| `RightClickAction` | dropdown | `tracking` | right-click action for the minimap |

## data flow

savedvariables → `ApplySettings()` → sizes container, skins border, applies component visibility via `IsComponentDisabled()`, restores canvas positions via `ComponentDrag:RestoreFramePositions()`, applies canvas overrides via `OverrideUtils.ApplyOverrides()`, sets scale/opacity
