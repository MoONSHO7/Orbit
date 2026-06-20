# skinning

visual rendering pipeline. transforms settings into pixels.

## purpose

all visual rendering — borders, textures, status bar coloring, icon styling, cast bar creation, and action button skinning — is centralized here. plugins never create visual elements directly; they call skinning methods.

## files

| file | responsibility |
|---|---|
| Skin.lua | core skinning api: `SkinBorder`, `SkinStatusBar`, `ApplyAbsorbTexture`, `SkinText`, `ApplyGradientBackground`, `GetBackgroundColor`, `CreateBackdrop`, `DefaultSetBorderHidden`, `IsMediaFileValid`. `IsMediaFileValid(path)` reports whether a resolved font/texture path still exists on disk via `C_UIFileAsset.IsKnownFile` (12.0.7+) — the media pickers use it to flag LSM media whose file was removed while its registration lingers; on clients without the API it returns `true`, so it never regresses. `ApplyAbsorbTexture` sets an absorb bar's fill: the Orbit absorb textures (`Orbit Absorb`, `Orbit Honeycomb Absorb`) render as plain stretched statusbar fills — maskable, so they round under a rounded border. `TILING_FILLS` is currently empty; a name added to it would instead draw via the bar's `TiledPattern` (UV-repeat — `REPEAT` wrap + `SetTexCoord` > 1, not `SetHorizTile` — so it stays maskable while holding a constant tile scale), with all other textures staying plain stretched fills. `ApplyGradientBackground` paints the global "Background" colour curve (`GlobalSettings.UnitFrameBackdropColourCurve`, Textures tab) onto a frame's `.bg` texture, rendering multi-pin curves as a gradient; `GetBackgroundColor` resolves that same setting to a single flat colour for solid backdrop surfaces that can't take a gradient — both fall back to `Constants.Colors.Background`. `GetActiveBorderStyle` resolves frame border style, `GetActiveIconBorderStyle` resolves icon border style (action bars, cooldown manager, and tracked abilities). `ApplyIconGroupBorder`/`ClearIconGroupBorder` wraps an icon container in a single border when Icon Padding = 0. **border style:** four built-in styles — `"orbit"`, a flat `WHITE8x8` outline driven by a single Border Size slider (`0`-`5`; `0` = no border), plus `"orbit-soft"`/`"orbit-rounded"`/`"orbit-rounder"` (labels "Orbit Pixel Soft"/"Rounded"/"Rounder"; slice radius 4/8/12px, all a 2px line) — rounded "pixel" borders that round the frame and its bars. `ResolveStyle` returns `nil` for the built-in `"orbit"` style and for unresolved LibSharedMedia borders — a `nil` styleEntry is the pipeline-wide signal for the flat pixel border (`SkinBorder`'s flat path, `GroupBorder`'s `isPixelMode`, `HighlightBorder`'s `"pixel"` path, `ApplyIconGroupBorder`'s else branch), so it renders with no extra branching. The two rounded styles resolve (via `Constants.BorderStyle.Rounded`) to a slice styleEntry `{ edgeFile, mask, sliceMargin, rounded = true }` — their thickness is baked into the texture, so they show no size slider. An `lsm:`-keyed LibSharedMedia border resolves to `{ edgeFile = ... }`, drawn as an edge-file backdrop by `ApplyNineSliceBorder` (frame edge-size/offset come from the `BorderEdgeSize`/`BorderOffset` sliders). Edge-file textures and the rounded slice border are grayscale and vertex-tinted by `BorderColor` via `ResolveBorderTint`, which returns nil for the "no tint" state (`{ none = true }` — the default; set by right-clicking the colour swatch) so the texture renders its natural art; any real colour, black included, tints. The color swatch is enabled for `lsm:` and rounded styles. `ResolveBorderColor` still maps `none` to black for solid-fill borders (pixel WHITE8x8, tick marks) that always need a colour. **rounded surface-mask system:** the two rounded styles re-activate the slice-mask pipeline. `RegisterMaskedSurface(frame, tex)` records the fill/bg/icon surfaces a frame owns (~24 sites: unit bars, cast bars, tracked bars, cooldown/damage-meter previews). When a rounded style is active, `SkinBorder` → `ApplyRoundedBorder` renders the slice border on an inset overlay (`_RenderSliceTexture`) and `ApplyRoundedMaskToSurfaces` attaches a shared `SetTextureSliceMargins` mask (`EnsureSliceMask`) to every registered surface via `_SetSurfaceMask` (one mask per surface, removed before re-add). `GroupBorder` does the same over the merged bounding box (`_groupRoundedMask`), so a merged group rounds only its four outer corners; un-merging restores each frame's own mask. The flat `"orbit"` and edge-file `lsm:` styles attach no mask (`ClearRoundedMaskFromSurfaces`/`_ClearGroupRoundedMask` clear any stale one). `GetRoundedSwipeTexture` returns the active rounded style's mask texture, used as the cooldown swipe fill so Orbit's own cooldown swipes round too (Blizzard-named cooldowns stay square to avoid taint). **Tiled fills** — Orbit's absorb/necrotic patterns tile via **UV-repeat** (`SetTexCoord` > 1 over a `REPEAT`-wrapped texture, constant tile scale, no shear) rather than `SetHorizTile`. `SetHorizTile` textures cannot be corner-masked by WoW; UV-repeat ones can, so the patterns are registered masked surfaces (`UnitButton.lua`) and round under a rounded style like any other fill. |
| HighlightBorder.lua | tinted border overlay for aggro/selection/dispel indicators: `ApplyHighlightBorder`, `ClearHighlightBorder`. respects group border merge state. |
| SelectionOutline.lua | flat pixel-perfect outline overshooting a frame (not the themed border): `ApplySelectionOutline(frame, storageKey, color)`, `ClearSelectionOutline`. shared by Canvas Mode component selection and the datatext drawer-active highlight so both read identically. `Skin.SELECTION_ACCENT` is the canonical bright-green default. |
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
