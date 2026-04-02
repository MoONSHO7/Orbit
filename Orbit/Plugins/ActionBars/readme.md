# action bars

replaces blizzard's action bars with a configurable grid-based system.

## purpose

suppresses native blizzard action bars and reparents their buttons into orbit containers. supports up to 8 standard bars (wow 12.0 hard limit of 180 slots) plus a pet bar.

## files

| file | responsibility |
|---|---|
| ActionBars.lua | main plugin. bar creation, button reparenting, visibility drivers, ooc fade, grid layout, spell state coloring (range/usable/mana). |
| ActionBarsContainer.lua | individual bar container frame. manages button grid within a single bar. |
| ActionBarsPreview.lua | canvas mode preview generation. |
| ActionBarsText.lua | text overlay settings (keybind, macro name, count) and canvas mode text styling. |

## how it works

```mermaid
graph LR
    blizzard[blizzard bars] -->|suppressed| orbit[orbit containers]
    orbit --> grid[grid layout engine]
    grid --> buttons[reparented buttons]
    buttons --> skin[ActionButtonSkinning]
```

1. native bars are hidden and their buttons reparented into orbit container frames
2. each container uses a grid layout engine for button positioning
3. `ActionButtonSkinning` (in core/skinning) handles visual overrides
4. skin settings include `iconBorder = true` to opt into `GlobalSettings.IconBorderStyle` (NineSlice/LSM icon borders). when `IconPadding = 0`, a single group border wraps the container instead of per-icon borders. containers set `mergeBorders = true` in `anchorOptions`, enabling cross-bar group borders when anchored at padding=0
5. visibility is driven by combat state and ooc fade settings
6. spell state hooks (`UpdateUsable`, `ActionBarButtonRangeCheckFrame`, `PLAYER_TARGET_CHANGED`) tint icons for out-of-range, out-of-mana, and not-usable states

## adding a new bar feature

1. if it affects all bars, add it to `ActionBars.lua` in the `ApplySettings` section
2. if it affects individual bar containers, add it to `ActionBarsContainer.lua`
3. text/font features go in `ActionBarsText.lua`
4. always add schema entries in `AddSettings` for user configuration

## rules

- pet bar has special handling (index-based, no ooc fade)
- pet bar listens for `UNIT_PET` with a 0.3s debounce to call `ApplySettings` after summon/dismiss (re-registers the state driver to force `[nopet]` re-evaluation)
- button reparenting must preserve secure frame references for combat
- all grid math must use pixel-snapped values
- bar visibility uses macro conditional drivers (`RegisterStateDriver`)
