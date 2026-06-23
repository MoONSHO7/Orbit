# help — authored help entries (spotlight source)

the `help` Spotlight kind: a curated catalog of Orbit actions and hidden interactions, surfaced only when a query leads with `help` or `orbit`. the kind is `prefixOnly`, so it never appears in normal item / spell search. three entry shapes share the one kind:

- **action** — `onClick` calls the owning Orbit module directly (e.g. `Orbit.API:PrintVersion()`, `Orbit.ViewerInjection:FlushAll()`, `Orbit.OptionsPanel:ToggleEditMode()`); the row closes after firing. Never route through the chat parser — `/orbit` only toggles Edit Mode.
- **menu** — `onClick` opens a `MenuUtil.CreateContextMenu(row, ...)` anchored to the row (e.g. *Orbit Reset* lists Account Settings + each enabled plugin). Set `keepOpen = true` so Spotlight stays under the menu; `onClick` receives `(entry, row)` — the row is the menu anchor. Long lists call `root:SetScrollMode(...)` to cap height (~10 rows, mouse-wheel scroll) and hide the bar via `menu.ScrollBar:Hide()` on the returned frame.
- **explainer** — `trigger` + `desc` (+ optional `note`) render a custom tooltip teaching a non-obvious interaction; `keepOpen = true` leaves Spotlight open so the user can read several in a row.

## layout

```
HelpRegistry.lua     -- Orbit.Spotlight.Index.Help:Register(entries) / GetAll(); collects topic entries at load
Topics/              -- one file per topic, pure localized data
  Reset.lua          -- actions + the Orbit Reset context menu (account + per-plugin)
  Open.lua           -- actions: edit mode, plugin manager, visibility engine, what's new, replay tour
  Anchoring.lua      -- explainers: how anchoring works, snap, break, gap, grid
  EditMode.lua       -- explainers: canvas, precision drag, nudge, resize, group-select
  CanvasMode.lua     -- explainers
  DataTexts.lua      -- explainers
  Minimap.lua        -- explainers
  RaidMarkers.lua    -- explainers
  DamageMeter.lua    -- explainers
  CooldownManager.lua -- explainers (topic "CDM": inject/remove cooldowns, edit-mode vs. move/style)
  Tracked.lua        -- explainers (topic "CDM": create/fill/remove tracked icons & bars)
  PortalDock.lua     -- explainers + rescan action
  Profiles.lua       -- explainers
  ColorPicker.lua    -- explainers
  SpotlightTips.lua  -- explainers (Spotlight's own tricks)
  Tools.lua          -- actions: version info, inspect-plugin menu, Orbit language, performance profiler start/stop
```

the source itself lives at `../Sources/Help.lua` — it reads the registry and stamps `kind` / `icon` / `lowerName` on each entry at build time.

## entry contract

```lua
{
    id      = "<unique>",              -- Recents key; stable string
    topic   = L.PLU_SPT_HELP_TOP_*,    -- shown right-aligned on the row; also folded into the search bag
    name    = L.PLU_SPT_HELP_*,        -- row label and tooltip title
    desc    = L.PLU_SPT_HELP_*_TT,     -- wrapped white tooltip body (Blizzard HIGHLIGHT_FONT_COLOR)
    note    = L.PLU_SPT_HELP_*_NOTE,   -- optional second white body section, separated by a blank line
    keywords = L.PLU_SPT_HELP_*,       -- optional extra search terms folded into lowerName (not displayed)
    trigger = L.PLU_SPT_HELP_T_*,      -- explainer only: green accent line ("Shift + Right-click")
    onClick = function(entry, row) end,-- action/menu only: call an Orbit module or open a context menu anchored to row
    keepOpen = true,                   -- explainer & menu: don't close Spotlight on click
}
```

`kind`, `icon`, and `lowerName` are set by the source, not the topic file. `lowerName = Fold(topic .. " " .. name .. " " .. keywords)`, so `help damage meter` (topic), `help reset` (label), and `help cooldown manager` (keywords on a "CDM"-topic entry) all match.

## adding a topic / entry

1. add entries to an existing `Topics/<X>.lua`, or create a new topic file that calls `Orbit.Spotlight.Index.Help:Register({ ... })`.
2. if new, add a `<Script>` line to `Spotlight.xml` after `HelpRegistry.lua` and before `Sources\Help.lua`.
3. add the `PLU_SPT_HELP_*` keys to `Localization/Domains/Plugins.lua` in every locale; reuse the shared `PLU_SPT_HELP_T_*` trigger keys for modifier/click phrases.
4. run `python .scripts/check-localization.py`.

actions are nearly free to add (descriptions can be terse); explainers must be accurate against the real interaction — cite the owning plugin's code when authoring one.
