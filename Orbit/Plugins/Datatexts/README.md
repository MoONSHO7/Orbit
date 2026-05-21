# datatexts

free-floating datatext system. provides screen-corner-triggered drawer panels to place informational datatexts anywhere on screen. each datatext is a self-contained entry that can be enabled, dragged out of the drawer, repositioned freely, and styled by orbit's global font / texture / border settings.

## purpose

successor to the old `MenuItems/Performance.lua` and `MenuItems/CombatTimer.lua` plugins, expanded into a richer ecosystem with stats readouts, gameplay info, social, and utility datatexts. positions persist per-profile in `OrbitDB`.

## directory structure

```
Datatexts/
  Datatexts.lua         -- plugin entry point (registration, lifecycle)
  Datatexts.xml         -- load order bundle
  BaseDatatext.lua      -- base class (frame creation, drag, tooltip, click, events)
  DatatextManager.lua   -- registry, position persistence, update scheduler, category metadata
  DrawerUI.lua          -- corner triggers, animated sliding drawer panel, lock/unlock. sorts datatexts alphabetically.
  Util/
    Formatting.lua      -- number / money / time formatting, RingBuffer
    Graph.lua           -- sparkline line graph for tooltips
    Menu.lua            -- context menu helper
  Elements/
    Elements.xml        -- datatext load manifest
    Performance.lua     -- fps / latency / memory (system)
    CombatTimer.lua     -- combat duration tracker (system)
    Gold.lua            -- currency with cross-character tracking
    Durability.lua      -- equipment durability
    BagSpace.lua        -- bag free / total slots
    Speed.lua           -- movement speed percentage
    Haste.lua           -- haste percentage (character stat)
    Crit.lua            -- crit percentage (character stat)
    Versatility.lua     -- versatility percentage (character stat)
    Mastery.lua         -- mastery percentage (character stat)
    Location.lua        -- zone name with pvp coloring
    Time.lua            -- local / realm time
    Volume.lua          -- master volume with scroll adjust
    Hearthstone.lua     -- hearthstone cooldown
    Mail.lua            -- new mail indicator
    Friends.lua         -- online friends count
    Guild.lua           -- online guild members
    ItemLevel.lua       -- equipped item level
    Spec.lua            -- specialization display (all specs with loadout menu and flipbook FX)
    Quest.lua           -- quest log count
```

## interaction model

| drawer state | datatext drag | datatext tooltip / click |
|---|---|---|
| closed | locked | enabled |
| open | unlocked (draggable) | enabled |

## corner triggers

4×4 pixel invisible buttons at each screen corner (`TOOLTIP` strata). clicking any corner toggles the drawer.

## persistence

datatext positions are stored in `OrbitDB.Profiles[activeProfile].Orbit_Datatexts.datatextPositions`. positions travel with profile switches.

## adding a new datatext

1. create a new lua file in `Elements/`
2. extend `DT.BaseDatatext:New("DatatextName")`
3. implement `Init()`: create the frame, set an update func, set any click/scroll handlers, then call `Register()`
4. add a `<Script file="Elements/YourDatatext.lua"/>` line to `Elements/Elements.xml`

## rules

- datatexts are NOT orbit plugins. they are internal objects managed by `DatatextManager`.
- no edit mode integration. the drawer handles lock / unlock state.
- all constants at file top. no magic numbers.
- each datatext file is self-contained. no cross-datatext dependencies.
- datatext state (position, enabled) is managed centrally by `DatatextManager`.
- user-visible strings go through `Orbit.L` (`PLU_DT_*` for datatext labels and tooltips).
- hover tooltips use the private `Orbit.Tooltip` frame, never the global `GameTooltip`. each file aliases it at the top: `local GameTooltip = Orbit.Tooltip`. owning the global tooltip from addon code taints it and breaks Blizzard's secret-handling unit-tooltip pipeline (WoW 12.0+).
