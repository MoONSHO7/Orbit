# minimap

orbit's minimap plugin. reparents blizzard's `Minimap` into a clean, borderless orbit container and strips all default art/chrome. supports **canvas mode** for fully customisable component placement.

## what it does

- strips blizzard's compass frame, border top, zone text button, tracking button, indicator frame, instance difficulty indicator, and expansion landing page button
- reparents the actual `Minimap` render surface into an orbit-managed frame
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

| component       | description                                                                                                              |
| --------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **ZoneText**    | zone name font string. optional pvp zone colouring via canvas component settings toggle                                  |
| **Clock**       | game/local time, updates every second. left-click opens time manager, right-click opens calendar. pending invite glow     |
| **Coords**      | player map coordinates (x, y), updates every 0.1s. supports canvas font/size/color overrides                             |
| **Compartment** | collects all LibDBIcon + legacy minimap buttons into a hover-reveal drawer with icon, name, click/tooltip handlers       |

right-click on the minimap itself opens blizzard's native tracking context menu.

canvas overrides (font, size, color) are supported for ZoneText, Clock, and Coords via the canvas component settings panel.

## blizzard frames affected

| frame                               | action                                   |
| ----------------------------------- | ---------------------------------------- |
| `MinimapCluster`                    | hidden via `NativeFrame:Hide`            |
| `MinimapCluster.BorderTop`          | hidden with cluster                      |
| `MinimapCluster.ZoneTextButton`     | hidden with cluster                      |
| `MinimapCluster.Tracking`           | hidden with cluster                      |
| `MinimapCluster.IndicatorFrame`     | hidden with cluster                      |
| `MinimapCluster.InstanceDifficulty` | hidden with cluster                      |
| `MinimapBackdrop`                   | alpha set to 0 (hides compass frame art) |
| `MinimapCompassTexture`             | hidden                                   |
| `ExpansionLandingPageMinimapButton` | hidden + OnShow suppressed               |

## settings

| key                | type    | default | description                                    |
| ------------------ | ------- | ------- | ---------------------------------------------- |
| `Scale`            | slider  | 100     | overall minimap scale (%)                      |
| `Opacity`          | slider  | 100     | out-of-hover opacity (%)                       |
| `Size`             | slider  | 200     | minimap diameter in pixels                     |
| `ZoneTextSize`     | slider  | 12      | font size for zone text                        |
| `ZoneTextColoring` | boolean | false   | colour zone text by pvp type (canvas override) |

## data flow

savedvariables → `ApplySettings()` → sizes container, skins border, applies component visibility via `IsComponentDisabled()`, restores canvas positions via `ComponentDrag:RestoreFramePositions()`, applies canvas overrides via `OverrideUtils.ApplyOverrides()`, sets scale/opacity
