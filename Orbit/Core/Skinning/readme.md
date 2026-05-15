# skinning

visual rendering pipeline. transforms settings into pixels.

## purpose

all visual rendering — borders, textures, status bar coloring, icon styling, cast bar creation, and action button skinning — is centralized here. plugins never create visual elements directly; they call skinning methods.

## files

| file | responsibility |
|---|---|
| Skin.lua | core skinning api: `SkinBorder`, `SkinStatusBar`, `SkinText`, `ApplyGradientBackground`, `CreateBackdrop`, `DefaultSetBorderHidden`. `GetActiveBorderStyle` resolves frame border style, `GetActiveIconBorderStyle` resolves icon border style (action bars, cooldown manager, and tracked abilities). `ApplyIconGroupBorder`/`ClearIconGroupBorder` wraps an icon container in a single NineSlice border when Icon Padding = 0. **rounded masked-surface model:** a caller first registers each texture that should inherit rounded corners via `RegisterMaskedSurface(frame, texture)` (stored on `frame._maskedSurfaces`, deduplicated). rounded slice masks are then applied to every registered surface with `ApplyRoundedMaskToSurfaces(frame, isIcon)` and removed with `ClearRoundedMaskFromSurfaces(frame)`; the modern/legacy NineSlice paths call these automatically. `UpdateRoundedMask(frame, isIcon)` re-resolves the active style and applies or clears the mask in one call — for frames built outside the `SkinBorder` lifecycle (e.g. canvas-mode previews) where surfaces are registered after the border dispatch ran. `GetRoundedTier(isIcon)` returns the mask asset + slice margin for the configured corner roundness, and `GetRoundedSwipeTexture(isIcon)` returns that mask asset for routing into a cooldown `SetSwipeTexture` (C++ swipe widgets cannot take a MaskTexture). |
| HighlightBorder.lua | tinted border overlay for aggro/selection/dispel indicators: `ApplyHighlightBorder`, `ClearHighlightBorder`. respects group border merge state. |
| GroupBorder.lua | group border merging for anchored frames at zero padding: `UpdateGroupBorder`, `ClearGroupBorder`, `RefreshAllGroupBorders`, `DeferGroupBorderRefresh`. includes debounced `BORDER_LAYOUT_CHANGED` listener. |
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
