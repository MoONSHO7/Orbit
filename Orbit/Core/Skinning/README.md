# skinning

visual rendering pipeline. transforms settings into pixels.

## purpose

all visual rendering — borders, textures, status bar coloring, icon styling, cast bar creation, and action button skinning — is centralized here. plugins never create visual elements directly; they call skinning methods.

## files

| file | responsibility |
|---|---|
| Skin.lua | core skinning api: `SkinBorder`, `SkinStatusBar`, `ApplyAbsorbTexture`, `SkinText`, `ApplyGradientBackground`, `GetBackgroundColor`, `CreateBackdrop`, `DefaultSetBorderHidden`, `IsMediaFileValid`. `IsMediaFileValid(path)` reports whether a resolved font/texture path still exists on disk via `C_UIFileAsset.IsKnownFile` (12.0.7+) — the media pickers use it to flag LSM media whose file was removed while its registration lingers; on clients without the API it returns `true`, so it never regresses. `ApplyAbsorbTexture` sets an absorb bar's fill: a tiling fill texture (any name in `TILING_FILLS` — `Orbit Absorb`, `Orbit Honeycomb Absorb`) draws via the bar's clip-masked `TiledPattern` (a `horizTile`/`vertTile` texture MOD-blended over a plain fill) so its pattern holds a constant scale instead of shearing; any other texture is a normal stretched statusbar fill with the pattern hidden. `ApplyGradientBackground` paints the global "Background" colour curve (`GlobalSettings.UnitFrameBackdropColourCurve`, Textures tab) onto a frame's `.bg` texture, rendering multi-pin curves as a gradient; `GetBackgroundColor` resolves that same setting to a single flat colour for solid backdrop surfaces that can't take a gradient — both fall back to `Constants.Colors.Background`. `GetActiveBorderStyle` resolves frame border style, `GetActiveIconBorderStyle` resolves icon border style (action bars, cooldown manager, and tracked abilities). `ApplyIconGroupBorder`/`ClearIconGroupBorder` wraps an icon container in a single border when Icon Padding = 0. **border style:** one built-in style — `"orbit"`, a flat `WHITE8x8` outline driven by a single Border Size slider (`0`-`5`; `0` = no border). It is rectangular: no corner roundness, no segmented variant, no masks. `ResolveStyle` returns `nil` for the built-in `"orbit"` style and for unresolved LibSharedMedia borders — a `nil` styleEntry is the pipeline-wide signal for the flat pixel border (`SkinBorder`'s flat path, `GroupBorder`'s `isPixelMode`, `HighlightBorder`'s `"pixel"` path, `ApplyIconGroupBorder`'s else branch), so it renders with no extra branching. An `lsm:`-keyed LibSharedMedia border resolves to `{ edgeFile = ... }`, drawn as an edge-file backdrop by `ApplyNineSliceBorder` (frame edge-size/offset come from the `BorderEdgeSize`/`BorderOffset` sliders). **inert legacy surface API:** the prior roundness-driven and segmented border systems are gone, but a set of functions stays defined and callable for ~24 external sites — they are now no-ops or rectangular-only: `RegisterMaskedSurface`, `ApplyRoundedMaskToSurfaces` (only clears stale masks now), `ClearRoundedMaskFromSurfaces`, `ClearMaskFromSurfaces`, `_SetSurfaceMask`, `UpdateRoundedMask`, `EnsureSliceMask`, `GetRoundedSwipeTexture` (always `nil`). No active style produces a corner-clip mask, so the masked-surface model never attaches one. |
| HighlightBorder.lua | tinted border overlay for aggro/selection/dispel indicators: `ApplyHighlightBorder`, `ClearHighlightBorder`. respects group border merge state. |
| GroupBorder.lua | group border merging for anchored frames at zero padding: `UpdateGroupBorder`, `ClearGroupBorder`, `RefreshAllGroupBorders`, `DeferGroupBorderRefresh`. includes debounced `ORBIT_BORDER_LAYOUT_CHANGED` listener. `SuspendMergeGroup(frame)` / `ResumeMergeGroup(members)` flag a whole merge group `_mergeSuspended` so it un-merges for the duration of a drag (Edit Mode `Drag.lua` calls them on drag start/stop); a suspended frame is excluded from merge walks and rebuilds individually. |
| Icons.lua | icon frame skinning: borders, zoom, desaturation, glow anchoring. supports `iconBorder` flag in settings to opt into `GlobalSettings.IconBorderStyle` NineSlice routing. when `padding == 0`, per-icon NineSlice is skipped in favor of container-level group border. |
| IconLayout.lua | icon grid layout math (rows, columns, spacing). |
| IconMonitor.lua | monitors icon visibility changes for layout recalculation. |
| CastBar.lua | cast bar frame creation (`Create`) and settings application (`Apply`). |
| ClassBar.lua | class power bar skinning (combo points, runes, etc.). |
| ActionButtonSkinning.lua | action bar button visual overrides (border, highlight, keybind text). |
| Masque.lua | masque library integration for third-party icon skinning. |
| VisualsExtendedMixin.lua | extended visual indicators (rare/elite icon, level badge). |
| Skins.xml | xml template definitions. |

## adding a new skin function

1. add the function to `Skin.lua` as a method on `Orbit.Skin`
2. accept a frame and a settings table. apply visuals. return nothing.
3. all numeric parameters must come from constants or settings, never hardcoded
4. add the new file to `Core/Skinning/Skins.xml` as a `<Script file="NewFile.lua"/>` entry; ensure it loads after its dependencies

## rules

- skinning functions are **idempotent**. calling them twice with the same settings produces the same result.
- no frame creation outside this domain (except for internal overlay/backdrop frames)
- pixel-snapping must use `Orbit.Engine.Pixel:Snap()` or `Orbit.Engine.Pixel:Multiple()`
- border colors use `{ r, g, b, a }` tables, never raw numbers
- all constants at file top. no magic numbers.
