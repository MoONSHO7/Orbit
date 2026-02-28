# skinning

visual rendering pipeline. transforms settings into pixels.

## purpose

all visual rendering — borders, textures, status bar coloring, icon styling, cast bar creation, and action button skinning — is centralized here. plugins never create visual elements directly; they call skinning methods.

## files

| file | responsibility |
|---|---|
| Skin.lua | core skinning api: `SkinBorder`, `SkinStatusBar`, `SkinText`, `ApplyGradientBackground`, `CreateBackdrop`. |
| Icons.lua | icon frame skinning: borders, zoom, desaturation, glow anchoring. |
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
