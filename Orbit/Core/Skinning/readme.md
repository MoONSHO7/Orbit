# skinning

visual rendering pipeline. transforms settings into pixels.

## purpose

all visual rendering — borders, textures, status bar coloring, icon styling, cast bar creation, and action button skinning — is centralized here. plugins never create visual elements directly; they call skinning methods.

## files

| file | responsibility |
|---|---|
| Skin.lua | core skinning api: `SkinBorder`, `SkinStatusBar`, `SkinText`, `ApplyGradientBackground`, `CreateBackdrop`, `DefaultSetBorderHidden`. `GetActiveBorderStyle` resolves frame border style, `GetActiveIconBorderStyle` resolves icon border style (action bars, cooldown manager, and tracked abilities). `ApplyIconGroupBorder`/`ClearIconGroupBorder` wraps an icon container in a single NineSlice border when Icon Padding = 0. **border style:** two built-in styles. `"orbit"` is roundness-driven, with two orthogonal sliders — Corner Roundness (`Square`/`Subtle`/`Round`/`Heavy` = `0`/`1`/`2`/`3`, drives the corner-clip `mask`) and Border Thickness (`None`/`Slim`/`Medium`/`Thick` = `0`/`1`/`2`/`3`, drives the outline `edgeFile`). The two are independent: thickness `None` = no outline, so a rounded-corner `mask` with no border line is a valid state. `"pixel"` ("Orbit Pixel (Legacy)") is the pre-consolidation flat border — a plain `WHITE8x8` outline driven by a single Border Size slider (`0`-`5`). `ResolveStyle` returns: an orbit style table (`sliceMargin`, `roundness`, `thickness`, `baseEdgeFile`, `isIcon`) where `edgeFile` is present only when thickness > None and `mask` only for rounded tiers; an `lsm:`-keyed LibSharedMedia border; or `nil` for the `"pixel"` style and for unresolved LibSharedMedia borders — a `nil` styleEntry is the pipeline-wide signal for pixel mode (`SkinBorder`'s flat path, `GroupBorder`'s `isPixelMode`, `HighlightBorder`'s `"pixel"` path), so the flat WHITE8x8 border renders with no extra branching. **rounded masked-surface model:** a caller first registers each texture that should inherit rounded corners via `RegisterMaskedSurface(frame, texture)` (stored on `frame._maskedSurfaces`, deduplicated). `ApplyRoundedMaskToSurfaces(frame, styleEntry)` applies (or clears) the mask on every registered surface from a style — always the SAME style the outline used, so the outline and the mask can never disagree; `ClearRoundedMaskFromSurfaces(frame)` releases **only that frame's own mask** (`frame._roundedMask`) — an icon texture is registered on both the icon and its container, sharing one mask slot, so a container's clear must not wipe a per-icon mask that owns the surface after an un-merge (and vice versa). every mask attach/detach routes through `_SetSurfaceMask`, so a surface carries at most one Orbit mask (tracked as `tex._orbitRoundedMask`) — switching mask always clears the previous occupant, so stale per-frame or ex-group masks never stack. `ApplyRoundedMaskToSurfaces` is group-aware: a frame flagged `_groupBorderActive` defers to its group root's mask instead of applying its own. `UpdateRoundedMask(frame, isIcon)` applies/clears the mask in one call — for frames built outside the `SkinBorder` lifecycle (e.g. canvas-mode previews) where surfaces are registered after the border dispatch ran. `GetRoundedSwipeTexture(isIcon)` returns the style's mask asset for routing into a cooldown `SetSwipeTexture` (C++ swipe widgets cannot take a MaskTexture) — `nil` for Square, which carries no mask. |
| HighlightBorder.lua | tinted border overlay for aggro/selection/dispel indicators: `ApplyHighlightBorder`, `ClearHighlightBorder`. respects group border merge state. |
| GroupBorder.lua | group border merging for anchored frames at zero padding: `UpdateGroupBorder`, `ClearGroupBorder`, `RefreshAllGroupBorders`, `DeferGroupBorderRefresh`. includes debounced `BORDER_LAYOUT_CHANGED` listener. `SuspendMergeGroup(frame)` / `ResumeMergeGroup(members)` flag a whole merge group `_mergeSuspended` so it un-merges for the duration of a drag (Edit Mode `Drag.lua` calls them on drag start/stop); a suspended frame is excluded from merge walks and rebuilds individually. |
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
4. add the file to `Orbit.toc` in the skinning section

## rules

- skinning functions are **idempotent**. calling them twice with the same settings produces the same result.
- no frame creation outside this domain (except for internal overlay/backdrop frames)
- pixel-snapping must use `Orbit.Engine.Pixel:Snap()` or `Orbit.Engine.Pixel:Multiple()`
- border colors use `{ r, g, b, a }` tables, never raw numbers
- all constants at file top. no magic numbers.
