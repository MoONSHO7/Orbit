# widget drawer

experimental free-floating widget system. provides a screen-corner-triggered drawer panel to place informational widgets anywhere on screen.

## purpose

replaces the old Performance and CombatTimer plugins with a richer widget ecosystem. widgets are free-floating frames that can be placed anywhere on screen via drag-and-drop. positions persist per-profile in OrbitDB.

## architecture

```
WidgetDrawer/
  WidgetDrawer.lua      -- plugin entry point (registration, lifecycle)
  BaseWidget.lua        -- widget base class (frame creation, drag, tooltip, events)
  WidgetManager.lua     -- registry, position persistence, update scheduler
  DrawerUI.lua          -- corner triggers, animated sliding panel, lock/unlock
  Util/
    Formatting.lua      -- number/money/time formatting, RingBuffer
    Graph.lua           -- sparkline line graph for tooltips
    Menu.lua            -- context menu helper
  Widgets/
    Widgets.xml         -- widget load manifest
    Performance.lua     -- fps/latency/memory (replaces old MenuItems/Performance.lua)
    CombatTimer.lua     -- combat duration tracker (replaces old MenuItems/CombatTimer.lua)
    Gold.lua            -- currency with cross-character tracking
    Durability.lua      -- equipment durability
    BagSpace.lua        -- bag free/total slots
    Speed.lua           -- movement speed percentage
    Location.lua        -- zone name with pvp coloring
    Time.lua            -- local/realm time
    Volume.lua          -- master volume with scroll adjust
    Hearthstone.lua     -- hearthstone cooldown
    Mail.lua            -- new mail indicator
    Friends.lua         -- online friends count
    Guild.lua           -- online guild members
    ItemLevel.lua       -- equipped item level
    Spec.lua            -- specialization display
    Quest.lua           -- quest log count
```

## interaction model

| drawer state | widget drag | widget tooltip/click |
|---|---|---|
| closed | locked | enabled |
| open | unlocked (draggable) | enabled |

## corner triggers

4x4 pixel invisible buttons at each screen corner (TOOLTIP strata). clicking any corner toggles the drawer.

## persistence

widget positions stored in `OrbitDB.Profiles[activeProfile].Orbit_WidgetDrawer.widgetPositions`. positions travel with profile switches.

## adding a new widget

1. create a new lua file in `Widgets/`
2. extend `WD.BaseWidget:New("WidgetName")`
3. implement `Init()` with `CreateFrame()`, `SetUpdateFunc()`, `SetCategory()`, `Register()`
4. add to `Widgets/Widgets.xml`

## rules

- widgets are NOT orbit plugins. they are internal objects managed by WidgetManager.
- no edit mode integration. drawer handles lock/unlock state.
- all constants at file top. no magic numbers.
- each widget file is self-contained. no cross-widget dependencies.
- widget state (position, enabled) managed centrally by WidgetManager.
