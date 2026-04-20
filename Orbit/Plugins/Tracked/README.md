# tracked

user-authored cooldown surfaces. spawns icon-grid containers and single-spell bars from tabs added to blizzard's `CooldownViewerSettings` frame. each container is a record under `OrbitDB.GlobalSettings.TrackedContainers`, keyed by a monotonic counter id that doubles as the system index.

## why it was rewritten

the old plugin was a single shared spec-scoped slot range with two frame types (icon grid + bar charges) reusing the same system indices across specs. that forced frames to "transform" between modes when the user swapped specs, and the spec-reconcile path was the most fragile area in the codebase. this rewrite drops the slot model entirely:

- **distinct frame types per record** — `mode = "icons"` or `mode = "bar"`. an icon container is never repurposed as a bar, and vice versa.
- **globally-unique counter ids** — each container gets its own system index, never reused. records carry their own `spec` field; only records matching the current spec get a live frame.
- **flat global record table** — `OrbitDB.GlobalSettings.TrackedContainers[id] = { id, mode, spec, grid|payload, settings }`. no per-spec sub-trees, no nested seeding, no nil-checks at every level.

## files

| file | responsibility |
|---|---|
| TrackedPlugin.lua | plugin registration (`Orbit_Tracked`), record store, counter id allocation, `CreateIconContainer`/`CreateBar`/`DeleteContainer`, `RefreshForCurrentSpec`, `GetSetting`/`SetSetting` redirect by systemIndex → record, `IsComponentDisabled` override for canvas mode (reads via active transaction's systemIndex), tab registration with `Orbit_CooldownViewerExtensions` |
| TrackedIconItem.lua | factory for individual icon-item buttons (icon + cooldown swipe + charge text + drop highlight). stateless factory, container owns the ticker. full cooldown display: phase-aware desaturation/alpha curves via `BuildPhaseCurve`, `ActiveCooldown` reverse swipe during active phase, charge caching with `issecretvalue` guard + `TrackChargeCompletion`, `useSpellId` fallback for items, non-usable item display. owns `ApplyCanvasComponents` for per-icon `ChargeText` positioning + `_chargeTextDisabled` caching |
| TrackedContainer.lua | icons-mode container frame. sparse 2D grid, neighbor-expansion drop zones, drop receive pipeline, per-container cursor watcher and event-driven update (SPELL_UPDATE_COOLDOWN, BAG_UPDATE_COOLDOWN, BAG_UPDATE, SPELLS_CHANGED + 0.3s visual poll). spell cast watcher (UNIT_SPELLCAST_SUCCEEDED → `_activeGlowExpiry` for active phase tracking, `OnChargeCast` for charge bookkeeping). equipment change handler (PLAYER_EQUIPMENT_CHANGED → item slot refresh). talent reparse (TRAIT_CONFIG_UPDATED → `ReparseActiveDurations` → rebuild phase curves). shift-right-click empty container → delete. installs `frame:CreateCanvasPreview` (via shared `IconCanvasPreview`) for the canvas dialog |
| TrackedBar.lua | single-payload bar frame. accepts spells OR items, renders in one of three modes (charges / active+cd / cd-only) determined at drop time. per-bar 0.05s update ticker + SPELL_UPDATE_CHARGES event listener for instant charge feedback. two-step shift-right-click ladder (clear payload → delete bar), drop hint texture states. owns `ApplyCanvasComponents` for `NameText`/`CountText` and installs `frame:CreateCanvasPreview` sized to the inner StatusBar width |
| TrackedSettings.lua | `AddSettings` dispatch — icons → Layout/Glow/Colors schema; bars → Layout/Colors schema. standalone, no shared schema with CooldownManager |
| Tracked.xml | load order: TrackedPlugin → TrackedIconItem → TrackedContainer → TrackedBar → TrackedSettings |

## record shape

```lua
OrbitDB.GlobalSettings.TrackedContainers[1042] = {
    id = 1042,
    mode = "icons",            -- "icons" | "bar"
    spec = 257,                -- specID, only frames for current spec are built
    grid = {                   -- only present for icons mode
        ["0,0"] = { type = "spell", id = 12345, x = 0, y = 0, ... },
        ["1,0"] = { type = "item",  id = 67890, x = 1, y = 0, ... },
    },
    payload = nil,             -- only present for bar mode (single spell or item)
    settings = {               -- per-container settings
        Position = { ... },
        IconSize = 36,
        IconPadding = 2,
    },
}

OrbitDB.GlobalSettings.NextTrackedContainerId = 1043
```

bar `payload` shape (built by `Orbit.CooldownDragDrop:BuildTrackedBarPayload` at drop time, captures everything the bar needs to pick a render mode without a second API/tooltip lookup):

```lua
record.payload = {
    type = "spell",            -- "spell" | "item"
    id = 12345,                -- spellID or itemID
    maxCharges = 2,            -- spell-only; nil for items and for non-charge spells
    activeDuration = 20,       -- tooltip-parsed seconds, nil if none
    cooldownDuration = 120,    -- tooltip-parsed seconds, nil if none
    useSpellId = nil,          -- item-only; the on-use spellID (for ItemSpell triggers)
    slotId = nil,              -- item-only; 13 or 14 if currently equipped in a trinket slot
}
```

settings live on the record, not under `Orbit.runtime.Layouts`. the plugin overrides `GetSetting`/`SetSetting` to redirect by systemIndex → record. anything that isn't a tracked container falls through to the standard layout DB so shared keys (Texture, Font, etc) keep flowing through global inheritance.

## tabs in the cooldown viewer settings

both tabs are registered with the `Orbit_CooldownViewerExtensions` plugin (see `Orbit/Plugins/CooldownViewerExtensions/`), which owns the blizzard `ADDON_LOADED` hook for `Blizzard_CooldownViewer` and the anchor chain below `AurasTab`. tracked itself does not touch blizzard frames.

| tab | atlas | action |
|---|---|---|
| Icons | `communities-chat-icon-plus` | spawn a new icon-grid container for the current spec |
| Bars  | `communities-chat-icon-plus` | spawn a new single-spell bar for the current spec |

tabs are click-to-spawn buttons, **not** panel switchers. clicking does not change `displayMode` on the parent frame; the cooldown viewer's content panel stays on whatever the user last selected.

## per-spec caps

- `Constants.Tracked.MaxIconContainers = 10` icon containers per spec
- `Constants.Tracked.MaxBars = 10` bars per spec

caps are independent (icons and bars don't share a budget). the plugin checks the cap on every create call and prints a message if it's reached.

## drag-and-drop visuals

both modes use the same three-layer drop zone treatment, so the visual language is consistent across the plugin:

- backdrop: `cdm-empty` (deepest, matches the cooldown viewer's empty slot art)
- tint: `talents-node-choiceflyout-square-green` (over the backdrop)
- plus glyph: `bags-icon-addslots`, centered

the whole zone is at **alpha 0.4 idle, 1.0 hover**. for icon containers each zone is its own child frame so we use frame-level `SetAlpha` (cascades to all child textures). bars share their drop hint textures with the bar frame itself, so they set per-texture alpha via a `SetDropHintAlpha(frame, a)` helper to avoid dimming the StatusBar.

each drop zone is also wrapped with `Orbit.DropZoneGlow:Attach` (see `Core/Shared/DropZoneGlow.lua`) — a 9-slice atlas glow that lights up when a cooldown ability is on the cursor AND the zone is visible. crucially, the glow is gated on `IsDraggingCooldownAbility()` via a shared ticker in the helper, NOT on zone visibility alone — so empty drop zones shown in edit mode / via the settings panel do NOT light the glow (they still show the backdrop/tint/plus treatment). icon containers use green (matches the talent atlas tint); bars use golden yellow (matches the `DropHintPlus` tint). the same helper also drives CooldownManager's viewer-injection drop zones, so all three surfaces share one visual language.

bars use the same three-layer treatment but the drop hint is sized to a `height x height` square anchored at the bar's TOPLEFT — the position the icon will land when a spell is dropped. stretching the talent atlas to the full bar width mangled the rounded corners (it was authored as a fixed ~76px square talent button face), so the square layout sidesteps the problem entirely. the green talent atlas is also `SetDesaturated(true)` and vertex-tinted blue (`0.3, 0.7, 1`, matching the StatusBar fill) so it reads as a neutral drop slot, and the plus glyph gets the same blue tint. the status bar to the right of the square stays as the dark `BarBg` so the empty bar still reads as a bar.

drop hints are shown whenever `Plugin:ShouldShowDropHints(isEmpty)` returns true, which is `IsDraggingCooldownAbility()` OR `CooldownViewerSettings:IsShown()` OR (`Orbit:IsEditMode()` AND the frame is empty). the settings-panel branch is a pure `IsShown()` read (no taint) — when the user opens the cooldown viewer settings, tracked frames light up their drop zones so the user can see where to drop spells. dropping from within the settings panel IS supported, via `Orbit.CooldownSettingsDragBridge` (see `Orbit/Plugins/CooldownViewerExtensions/`): the bridge captures the dragged spellID from `GameTooltip:GetSpell()` and dispatches to the receiving frame's `OnCooldownSettingsDrop(spellID)` handler. the edit-mode case is gated on emptiness so populated frames don't sprout hints in edit mode. each frame's cursor watcher recomputes its own emptiness every tick and polls the combined signal, so the hints toggle automatically when the user picks up/drops a cursor payload, opens/closes the settings panel, enters/exits edit mode, or adds/removes the last item.

drag sources are the spellbook and bags only. the cooldown viewer settings panel's open state is used purely as a discoverability signal for drop hints — dragging an icon out of the panel itself is a no-op; the panel keeps its own reorder UX.

## border merging

both modes set `anchorOptions.mergeBorders = true`. when two tracked frames (or a tracked frame and any other orbit frame with the same flag) are anchored at zero padding, `Orbit.Skin.GroupBorder:UpdateGroupBorder` walks the chain and draws a single wrapper border around the merged group instead of one border per frame. icon containers also set `frame._isIconContainer = true` so the wrapper picks the **Global Icon Border Style** (matching the cooldown manager's essential/utility group). bars do not flag themselves as icon containers, so a chain of bars uses the regular **Global Border Style** — same behavior as the cooldown manager's BuffBar group.

icon containers also merge their *internal* icon borders when `IconPadding == 0`. at zero padding, `Orbit.Skin.Icons:ApplyCustom` hides every per-icon border (its `mergeIconBorders` branch) and the container has to draw one wrapper border around the whole grid via `Skin:ApplyIconGroupBorder`. `TrackedContainer:Apply` does this at the end of every layout pass: applies the icon group border when padding is 0 and grid is non-empty, clears it otherwise. this matches the cooldown manager's essential/utility behavior — without it, padding 0 looks borderless.

## icon skinning

each icon item is skinned via `Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)` after every layout pass, with `skinSettings = OrbitEngine.CooldownUtils:BuildSkinSettings(plugin, record.id)`. that builder sets `iconBorder = true` and `borderSize = GlobalSettings.BorderSize`, so tracked icons inherit the **Global Icon Border Style** and **Border Size** the same way the cooldown manager does. each call also installs the swipe color hooks and pixel texcoord trim — we don't reimplement any of that.

## bar skinning

each bar calls `Orbit.Skin:SkinBorder(frame, frame, GlobalSettings.BorderSize)` in `Bar:Apply` so it inherits the **Global Border Style**, **Border Size**, and **Border Color** the same way `CastBar` and the buff bars do. `Bar:Build` assigns `frame.SetBorderHidden = Orbit.Skin.DefaultSetBorderHidden` so the chain border merging path in `Anchor.lua` (which toggles per-frame borders on/off when wrapping a chain in a single nine-slice) can hide and re-show the bar border without a method-missing error. the global texture is pulled per-Apply via `LSM:Fetch("statusbar", GlobalSettings.Texture)` and the per-bar `BarColor` curve is read via `OrbitEngine.ColorCurve:GetFirstColorFromCurve`. since `GlobalPlugin:ApplySettings` iterates `OrbitEngine.systems` and calls each plugin's `ApplySettings`, changing any global border or texture setting propagates to live bars without an explicit listener.

## docked bar width

bars set `frame.orbitWidthSync = true`, so when a bar is docked TOP/BOTTOM to another orbit frame `Anchor:SyncChild` calls `frame:SetWidth(parentWidth)` to match the chain. `Bar:Apply` would normally call `frame:SetSize(savedWidth, savedHeight)` and clobber that synced width — leaving dividers and recharge geometry stuck at the saved size while the bar visually grows. so Apply checks `FrameAnchor.anchors[frame]` and, when docked, calls `SetHeight(savedHeight)` only and reads `frame:GetWidth()` for downstream layout. this matches the buff-bar pattern in `CooldownLayout` ("when docked, anchor width is authoritative"). the Width slider in the settings panel still applies when the bar is undocked; once it joins a chain, the chain's width wins.

## visibility engine

both modes register with the Visibility Engine as **two separate umbrella entries** so the user can manage all icon containers and all bars with two rows in the VE config panel — not one row per record (which would be unmanageable since users routinely have several Tracked frames per spec).

| key | display | plugin | sentinel index |
|---|---|---|---|
| `TrackedIcons` | Tracked Icons | Tracked Items | 1 |
| `TrackedBars`  | Tracked Bars  | Tracked Items | 2 |

the entries live in `Core/Plugin/VisibilityEngine.lua` `FRAME_REGISTRY`. their **sentinel indices** (1 and 2) are intentionally below `Constants.Tracked.SystemIndexBase` (1000), so they can never collide with a live record id even though Tracked records use the same systemIndex namespace as the VE lookup.

`Container:Apply` calls `Orbit.OOCFadeMixin:ApplyOOCFade(frame, plugin, 1, "OutOfCombatFade", false)` and `Bar:Apply` calls the same with sentinel `2`. the OOCFade mixin resolves the sentinel via `VE:GetKeyForPlugin("Tracked Items", 1|2)` to get the umbrella key and reads opacity / oocFade / mouseOver / showWithTarget from the VE DB under that key. so all icon containers share one settings row, all bars share another, and the per-record `record.settings` is never touched by visibility settings.

`ApplyOOCFade` is idempotent (`ManagedFrames[frame] = ...` is a table assignment, the SetAlpha hook is guarded by `orbitOOCSetAlphaHooked`, and the hover ticker is created once), so calling it from the layout pass on every Apply is safe — there's no need for a separate "register once" path.

## global font / outline

charge text on icons and the name/timer text on bars read from `GlobalSettings.Font` and `GlobalSettings.FontOutline` on every Apply pass. fonts are pulled via `Plugin:GetGlobalFont()` (LSM-fetched) and outlines via `Orbit.Skin:GetFontOutline()`. since `PluginMixin` auto-subscribes to `SETTINGS_CHANGED` and reroutes to `ApplySettings`, changing the global font in the settings panel propagates to all live tracked frames without an explicit listener — the existing apply path handles it.

## canvas mode

both bars and icon containers opt into Canvas Mode (`Plugin.canvasMode = true`) so the user can right-click any tracked frame in edit mode and reposition / disable / restyle the text components on it. the components exposed are:

| frame type | components |
|---|---|
| `TrackedBar` | `NameText` (spell name), `CountText` (charge count, charges mode only) |
| `TrackedContainer` (icons mode) | `ChargeText` on every icon (one shared layout per container) |

per-component defaults live on the plugin's `defaults.ComponentPositions` table so the dialog has a starting anchor for any component the user has not yet dragged. saved positions land in `record.settings.ComponentPositions[componentKey]` and the disabled list in `record.settings.DisabledComponents`, both via the standard `GetSetting`/`SetSetting` redirect — no separate canvas store. **bars store one ComponentPositions table per record** so each bar can have its own NameText/CountText layout. **icon containers store one ComponentPositions table per container** so all icons in the same grid share the same ChargeText anchor.

### text overlay layering

text FontStrings have to render ABOVE the border or they get clipped behind the border 9-slice. the project standard is "create a child Frame at parent level + Overlay and parent the FontStrings to that child", which is what `CastBar.TextFrame` (`Constants.Levels.Overlay`) and `CooldownText:GetTextOverlay` (`Constants.Levels.IconOverlay`) both do.

- `TrackedBar` builds `frame.TextFrame` parented to `frame.StatusBar` at `frame.StatusBar:GetFrameLevel() + Constants.Levels.Overlay`. `NameText` and `CountText` are created on the TextFrame, not on the StatusBar directly. without this the text would sit at StatusBar level (`+1`) which is below the bar's border (`+5`).
- `TrackedIconItem` builds `icon.TextOverlay` parented to the icon at `icon:GetFrameLevel() + Constants.Levels.IconOverlay`. `ChargeText` is created on the TextOverlay, not on the icon directly. without this the text would sit at icon level (`+0`) which is below `IconBorder` (`+3`) and `IconSwipe` (`+2`), so the cooldown swipe and the per-icon nine-slice would both occlude it.

### `IsComponentDisabled` override

`PluginMixin`'s default implementation falls back to `self.frame.systemIndex` to look up the disabled list. that's wrong for Tracked: there is no single "current frame" — every record has its own systemIndex. `Plugin:IsComponentDisabled` overrides the default and reads from the active Canvas Mode transaction's systemIndex via `self:_ActiveTransaction()`. the transaction is the only reliable source of "which Tracked frame is currently being canvas-edited", and `ComponentDrag:IsDisabled` (called by the dialog and by the per-frame overlay) routes through this override so per-bar disable/enable works correctly.

`TrackedBar.ApplyCanvasComponents` itself does NOT use `ComponentDrag:IsDisabled` for the same reason — Apply runs outside any canvas transaction. it reads `DisabledComponents` directly via `plugin:GetSetting(record.id, ...)` with the explicit record id so the right list always loads.

### per-bar `CreateCanvasPreview`

`TrackedBar.Build` installs `frame:CreateCanvasPreview(options)` which the canvas dialog calls to render the editable preview. the bar's text FontStrings are children of the inner `StatusBar`, NOT the outer frame, so the preview must be sized to the StatusBar's inner width (frame width minus icon area), not the full frame width — otherwise drag offsets calibrated against a too-wide preview map back to the wrong live coordinates. `preview.sourceWidth` is set to that same inner width so the dialog's normalize/denormalize math agrees with the live frame. the decorative icon texture (when ShowIcon is on and the bar has a payload) is parented to the LEFT of the preview at `RIGHT->LEFT` so it visually represents the IconBg without inflating the draggable canvas area.

### per-container `CreateCanvasPreview` (icons)

`TrackedContainer.Build` installs `frame:CreateCanvasPreview(options)` which delegates to the shared `OrbitEngine.IconCanvasPreview:Create` builder for a single representative icon, then `:AttachTextComponents` for the ChargeText element. the sample icon texture is the first live `iconItems[*].Icon:GetTexture()` (or a placeholder if the grid is empty), and `preview.systemIndex` is set to `self.recordId` so the dialog's saved-position lookups land on the right record. the preview only shows ONE icon — there's no need to render the full grid because the saved layout is shared across every icon in the container.

### per-icon component apply

`TrackedIconItem.ApplyCanvasComponents(plugin, icon, systemIndex)` is called from `Container:Apply` for every icon in the grid, BEFORE `TrackedIconItem:Update`. it reads the container's saved `ComponentPositions.ChargeText` and applies font overrides via `OverrideUtils.ApplyOverrides`, then anchors the FontString via `OrbitEngine.PositionUtils.ApplyTextPosition` with a default of `BOTTOMRIGHT, -2, 2`. the disabled state is cached on each icon as `icon._chargeTextDisabled` so `Update` (item count path) and `UpdateChargeText` (spell charge path) both early-return from any `ChargeText:Show()` call when disabled — without the cache the per-tick path would silently re-show a hidden component on every refresh.

### per-bar text canvas apply

`Bar:ApplyCanvasComponents(plugin, frame, record)` is called from `Bar:Apply` after `ApplyFont`. it walks `DisabledComponents`, force-hides any disabled component, and applies font overrides for the rest via `OverrideUtils.ApplyOverrides`. for `CountText` the disabled state is cached on the frame as `frame._countTextDisabled` so `LayoutForMode`'s charges branch (which would otherwise unconditionally `CountText:Show()` when entering charges mode) checks the cache before re-showing. saved positions are applied at the end via `ComponentDrag:RestoreFramePositions(frame, savedPositions)`.

## icons mode — free-form 2D grid

the algorithm is the one from the pre-redesign tracked plugin (commit 8ed3a8c, `TrackedLayout.lua`). sparse grid keyed by `"x,y"` strings. when a user drags a cooldown ability over the container, every existing item exposes its empty cardinal neighbors as drop zones. the grid extends in any direction up to `MAX_GRID_REACH` (10 cells in any direction from origin).

`blockedDirections` walks `OrbitEngine.FrameAnchor.anchors` to find the container's parent edge and any docked children, and refuses to grow into those directions so the drag preview can't push the grid into another orbit frame.

dropping on the container body (not a specific zone) lands at the next free right-edge slot. dropping on an empty container lands at `0,0`.

## bars mode — single payload, two-step replacement, three render modes

each bar holds **one** payload — a spell OR an item. attempting to drop a second payload while one is already assigned does nothing. to replace a payload, the user must:

1. shift-right-click the bar → payload cleared, bar stays
2. drop the new spell/item on the empty bar

shift-right-clicking an already-empty bar deletes the bar entirely. this two-click ladder is intentional — it prevents accidental swaps when the user just wanted to remove.

### render modes

the render mode is determined by the dropped payload (see `DetermineMode` in `TrackedBar.lua`) and cached on the frame as `_barMode`. mode is recomputed on every `Apply` so a payload swap (clear + drop) re-evaluates without rebuilding the frame.

| mode | when | rendering |
|---|---|---|
| `charges` | spell with `maxCharges > 1` | bar split into N segments by dividers; the main `StatusBar` value is `currentCharges` (sink-style — secret value passed straight to `SetValue` and `CountText:SetText`). a `RechargePositioner` (an invisible `StatusBar` whose texture's RIGHT edge tracks `currentCharges/maxCharges`) anchors a visible `RechargeSegment` to fill the next charge slot as the recharge cooldown progresses. `CountText` is centered and shows the current charge count. **spells only** — items render as continuous bars even if their use-effect happens to have multiple charges. |
| `active_cd` | payload has both `activeDuration > 0` and `cooldownDuration > 0` (e.g. trinkets, Avenging Wrath) | bar drains full→empty during the active phase, then refills empty→full during the recharge phase. the active/recharge boundary is `_phaseBreakpoint = 1 - (activeDuration / cooldownDuration)` — a `remainingPercent` value computed once in `LayoutForMode` and reused on every tick. `pct >= breakpoint` is active phase, `pct < breakpoint` is cd phase. |
| `cd_only` | payload has no active duration (or no positive durations at all) | bar fills empty→full as the cooldown progresses. simplest mode — uses `INVERSE_CURVE` directly with `SetValue` for spells and `C_Container.GetItemCooldown` (numeric) for items. |

### tick mark

the `TickMixin` is built once against the main `StatusBar` in `Build`, and `LayoutForMode` re-anchors it per mode:

- **charges**: `TickBar` is sized to one charge-length and anchored to the `RechargePositioner` texture's leading edge (`LEFT→RIGHT` in horizontal, `BOTTOM→TOP` in vertical), so the tick floats at the leading edge of the recharging segment. `TickMixin:Apply(frame, tickSize, perpDim, RechargeSegment, orientation)` clips the tick to the recharging segment's bounds.
- **active_cd / cd_only**: `TickBar:SetAllPoints(StatusBar)` and `TickMixin:Apply(frame, tickSize, perpDim, StatusBar, orientation)` — tick tracks the leading edge of the main bar fill.

`TickSize` is a per-bar setting (slider in the Layout tab; `0` hides it, default `2`, max `6`). it shares the same constants as `PlayerPower` (`OrbitEngine.TickMixin.TICK_SIZE_DEFAULT` / `TICK_SIZE_MAX`). `TickMixin:Apply` takes a 5th `orientation` arg ("HORIZONTAL" default / "VERTICAL"); existing horizontal callers (`PlayerPower`, `PlayerResources`) need no change.

### layout (horizontal / vertical)

`Layout` dropdown (Layout tab, default `Horizontal`) flips the bar's fill direction. `Width` and `Height` sliders are interpreted as **long axis / short axis** rather than literal X/Y, so the same record can flip orientations without resizing — the slider ranges (80-400 long, 12-40 short) stay valid in both. internally `Bar:Apply` derives `frameW, frameH` from the orientation:

| layout | frame W | frame H | icon position | StatusBar fill |
|---|---|---|---|---|
| `Horizontal` | `Width` (long) | `Height` (short) | `TOPLEFT`, square sized to `Height` | `LEFT → RIGHT` |
| `Vertical`   | `Height` (short) | `Width` (long)  | `TOPLEFT`, square sized to `Width`  | `BOTTOM → TOP` |

vertical bars set `StatusBar:SetOrientation("VERTICAL")` plus the same on `RechargePositioner` and `RechargeSegment`. WoW's vertical fill is `BOTTOM→TOP`, which naturally gives the requested behavior in both continuous modes:

- **active_cd**: value drains from 1 → 0 during the active phase, so the texture's TOP edge moves downward → "active drains downward". value then refills from 0 → 1 during the cd phase, texture's TOP edge moves upward → "cd fills upward".
- **cd_only**: value goes from 0 → 1, texture's TOP edge moves upward → "cd fills upward".

the per-tick math in `UpdateActiveCdMode` / `UpdateCdOnlyMode` is unchanged — the same `barValue` works in both orientations because StatusBar handles the rendering flip.

`charges` mode also works in vertical. `LayoutChargesGeometry` reads the long-axis dimension (`barHeight` in vertical, `barWidth` in horizontal), splits it into `chargeLength = longAxis / maxCharges`, and anchors `RechargeSegment`/`TickBar` to the next-charge slot above the current fill (`BOTTOM → TOP of RechargePositioner texture` in vertical, `LEFT → RIGHT` in horizontal). `LayoutDividers` draws horizontal lines at proportional Y positions (vertical) or vertical lines at proportional X positions (horizontal). first charge is at the bottom of the bar, max charges fills the entire bar.

`orbitResizeBounds` flips its `widthKey`/`heightKey` to `Height`/`Width` in vertical, so dragging the resize handle horizontally writes the short-axis slider and dragging vertically writes the long-axis slider — the screen-axis to slider mapping stays consistent regardless of orientation. `anchorOptions` is unchanged: vertical bars chained via dock still extend top/bottom and inherit parent width via `orbitWidthSync`, which works best when chaining vertical bars with other vertical bars.

### show icon

the icon area to the left of the bar can be hidden via the `ShowIcon` checkbox (Layout tab, default on). when off, the `StatusBar` is anchored `TOPLEFT` to the frame instead of to `IconBg.TOPRIGHT`, and the icon textures are hidden — the bar uses the entire frame width. drop hints are still shown at the frame's `TOPLEFT` (always `height x height` square) regardless of the `ShowIcon` setting, so an empty bar always has a visible drop target.

### bar color

a single `BarColor` curve setting (Colors tab, single color). read on every `Apply` via `OrbitEngine.ColorCurve:GetFirstColorFromCurve(plugin:GetSetting(record.id, "BarColor"))` and cached on the frame as `_barColorR/G/B/A` so the per-tick update path can switch between **bright** (active counted state) and **dim** (recharging) without re-reading the curve.

`Bar:SetBarColorState(frame, dim)` is the single switch — it caches `_barColorIsDim` and only re-vertex-colors the StatusBar texture when the state actually flips, so the 0.05s ticker is a no-op when the bar isn't crossing a phase boundary. the dim multiplier is the same `RECHARGE_DIM = 0.35` used by the `RechargeSegment` in charges mode, so "filling toward ready" reads with the same darker tint regardless of which render mode is on screen:

| mode | bright | dim |
|---|---|---|
| `charges` | main StatusBar (charge count) — always bright | `RechargeSegment` (next-charge fill) — always dim, set in `Apply` |
| `cd_only` | bar at full (`SetBarFull`) | bar filling 0→1 while the cooldown elapses |
| `active_cd` | active phase (`pct >= breakpoint`) and full (`SetBarFull`) | cd phase (`pct < breakpoint`), bar refilling empty→full |

## deletion

| target | gesture | result |
|---|---|---|
| icon item inside a container | shift-right-click | item removed from grid, container resizes |
| empty icon container | shift-right-click on container body | container deleted |
| empty icon container (settings panel open) | shift-right-click on the visible drop zone | container deleted |
| populated bar | shift-right-click | payload cleared, bar stays |
| empty bar | shift-right-click | bar deleted |

there is no delete tab. all deletion goes through shift-right-click. records are removed from the store on delete; the counter id is never reused.

shift-right-click deletion is gated on `InCombatLockdown()` — the handler silently no-ops during combat. `DeleteContainer` tears down `FrameAnchor` graph edges which run `SetPoint`/`ClearAllPoints` on anchored descendants, and `RemoveIconAt` + `Container:Apply` rebuild the grid layout; both are protected-op paths that must not run mid-combat. bars also gate the payload-clear step (same handler) so the clear→delete ladder stays consistent.

**descendant cleanup on delete.** wow frames can never be destroyed — `frame:Hide()` plus `self.containers[id] = nil` removes our handle but the lua object and its `_G[name]` entry persist forever. without explicit cleanup, any frame that was anchored to (or logically routed past) the deleted container would still resolve `_G[oldName]` on the next `/reload` and re-attach to a hidden ghost. `DeleteContainer` walks two lists before tearing the frame down:

- `Anchor:GetAnchoredChildren(frame)` — physical children. For each: `BreakAnchor` (drops the graph entry and clears its logical anchor) then wipe its saved `Anchor` setting via `SetSpecData`/`SetSetting` (chosen by `IsSpecScopedIndex`). saved Position is left intact so the child falls back to its own free position on next `RestorePosition`.
- `Anchor:GetLogicalChildren(frame)` — frames whose *logical* parent is this container but whose *physical* parent is upstream (because this container was virtual). Their physical anchor is fine; we only need `ClearLogicalAnchor` so `RestoreLogicalChildren` doesn't try to pull them home to a deleted frame later.

note: when the cooldown viewer settings panel is open (or in edit mode), an empty icon container's drop zone covers the container body and intercepts mouse input, so the shift-right-click delete is handled on the drop zone itself (it routes to `DeleteContainer` when the grid is empty). bars don't have this problem because their drop hint is a child texture of the bar frame, not a separate child frame, so clicks bubble straight to the bar's mouse handler.

## bulk flush — `/orbit tracked flush`

`Plugin:FlushCurrentSpec` walks the store and calls `DeleteContainer` on every record whose `spec` field matches the current spec. records for other specs are left untouched. used to recover from a desync where the per-spec cap blocks new containers because the store holds dormant records the user can't see (e.g. seeded by an earlier dev iteration that never built into a frame). exposed via `/orbit tracked flush` (slash dispatch in `Core/Config/Entry/SlashCommands.lua`).

## spec switching

`PLAYER_ENTERING_WORLD`, `ACTIVE_TALENT_GROUP_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`, and `ORBIT_PROFILE_CHANGED` all trigger `RefreshForCurrentSpec`. the profile-changed hook matters for the cross-login case: swapping to another character on ProfileB and back to ProfileA activates ProfileA *after* `PLAYER_ENTERING_WORLD` has already fired against ProfileB's store, so without the profile hook the spec-scoped frames stay dormant until `/reload`. `RefreshForCurrentSpec`:

1. build a live frame for every record in the store that doesn't have one yet (across all specs, not just the current one)
2. **first pass**: disable every frame whose record's spec doesn't match the current spec, and tear down frames whose store entry vanished
3. **second pass**: enable every frame whose record's spec matches the current spec

the disable-then-enable split matters when two records sit at the "same logical slot" (one per spec, e.g. each spec has its own TrackedIcon between FrameA and FrameC). a single-pass loop iterates `pairs(self.containers)` in arbitrary order, so during the swap there could be a window where both records are live anchor targets — any intermediate `ReconcileChain` or saved-anchor lookup that runs in that window could route a child to the wrong target. the two-pass guarantees the off-spec frame is fully `SetFrameDisabled`'d before the on-spec frame is enabled.

frames are **not destroyed** on a spec swap. every record gets a long-lived frame that stays in the AnchorGraph as a routing node, and the per-spec toggle is just `Anchor:SetFrameDisabled`. this is what makes anchor chains survive spec swaps — see "anchor chains across spec swaps" below.

`Plugin:SetContainerActive(frame, active)`:

- **active = true**: `SetFrameDisabled(frame, false)` clears the skip flag and schedules a chain reconcile, then `RestorePosition` re-applies the saved Anchor (because `ParkFrame` only changed the visual SetPoint, not the graph entry — we need to re-wire the SetPoint), then `frame:Show()`.
- **active = false**: `SetFrameDisabled(frame, true)` marks the frame skipped, parks it at `defaultPosition`, and schedules a reconcile that promotes its children to the nearest non-skipped ancestor. then `frame:Hide()`.

this is the same pattern `PlayerResources` / `PlayerPower` use for plugin enable/disable.

## anchor chains across spec swaps

if the user builds a chain like `FrameA > TrackedIcon > FrameC`, then swaps to a spec where TrackedIcon doesn't belong, the chain collapses to `FrameA > FrameC` for the duration of the swap and snaps back when the user swaps home. the mechanism:

1. on swap, `SetContainerActive(TrackedIcon, false)` calls `Anchor:SetFrameDisabled(TrackedIcon, true)` which marks TrackedIcon as skipped in the AnchorGraph and schedules `ReconcileChain` from the chain root.
2. `ReconcileChain` walks from FrameA, hits TrackedIcon, sees `IsSkipped(TrackedIcon) == true`, and calls `PromoteGrandchild(FrameC, FrameA)` — which is `CreateAnchor(FrameC, FrameA, ..., skipLogical=true)`. the `skipLogical=true` keeps FrameC's *logical* anchor pointing at TrackedIcon even though the *physical* anchor now goes to FrameA. FrameC visually snaps under FrameA's content.
3. on swap home, `SetContainerActive(TrackedIcon, true)` calls `SetFrameDisabled(TrackedIcon, false)`. another `ReconcileChain` runs, walks the chain, and hits `RestoreLogicalChildren(TrackedIcon)`. that walks `logicalChildrenOf[TrackedIcon]`, finds FrameC (whose logical parent is still TrackedIcon but whose physical parent is now FrameA), and re-anchors it back to TrackedIcon.

this only works because TrackedIcon's frame stays alive across the swap. if we tore the frame down (the previous behavior), the AnchorGraph would lose the TrackedIcon node entirely, FrameC's logical pointer would dangle at a destroyed frame, and `ReconcileChain` would have nothing to walk through. that's why `BuildContainer` is now called for **every** record (not just current-spec), and `RefreshForCurrentSpec` toggles state instead of building/tearing.

### two-Tracked-frames per spec — what does and doesn't work

each Tracked record is its own globally-unique frame name (`OrbitTrackedContainer1042`, `OrbitTrackedContainer1043`, ...). when the user wants the SAME logical chain shape on two specs (e.g. `FrameA > TrackedIcon > FrameC` on both), each spec gets its own TrackedIcon record with its own name. all three cases now work via target-driven per-spec anchor routing (see "per-spec anchor routing for non-spec-scoped consumers" below):

- **FrameC is also a Tracked frame** ✅ each spec has its own FrameC record (Tracked frames are inherently per-spec via `record.spec`), each with its own `record.settings.Anchor` pointing to its own spec's TrackedIcon. no collision.
- **FrameC's plugin is spec-scoped** (`IsSpecScopedIndex` returns true — e.g. CooldownManager's injected viewer indices) ✅ FrameC's saved anchor is partitioned per-spec by `SetSpecData`, so the user can drag the chain together on each spec independently and the right anchor loads on swap.
- **FrameC's plugin is NOT spec-scoped** ✅ Tracked containers expose `frame.orbitAnchorTargetPerSpec = true`, so when FrameC anchors to a Tracked container, `Persistence:WriteAnchor` partitions FrameC's saved anchor per-spec via `SetSpecData` even though FrameC's plugin doesn't itself opt into spec-scoping. on swap, `Persistence:ReadAnchor` checks the current spec's spec-data slot first and falls back to the global plugin setting, so SpecA loads `OrbitTrackedContainer1042` and SpecB loads `OrbitTrackedContainer1043` from the same FrameC. specs the user never wired keep falling through to the global anchor (or to `defaultPosition` if there is none).

## per-spec anchor routing for non-spec-scoped consumers

a plugin's saved Anchor/Position normally lives in the global layout DB (one value across all specs). that's correct when the chain is stable across specs, but breaks when the **target** frame is per-spec — Tracked containers, where SpecA and SpecB own different frame names. a non-spec-scoped consumer like the player frame can name only ONE of those targets in its global Anchor field, so the chain renders on one spec and silently routes around the other.

`Engine.FramePersistence` solves this by **target-driven per-spec routing**: when the anchor target carries `orbitAnchorTargetPerSpec = true`, the consumer's saved anchor is written to the consumer plugin's per-spec store (`PluginMixin:SetSpecData`) regardless of whether the consumer plugin itself is spec-scoped. the consumer doesn't have to opt in or know the target is per-spec.

| helper | behavior |
|---|---|
| `Persistence:WriteAnchor(plugin, systemIndex, anchor)` | `IsSpecScopedIndex` true OR target has `orbitAnchorTargetPerSpec` → spec data only, global left untouched (so other specs without an override fall back to whatever global was). otherwise → global, current spec's spec-data override cleared. |
| `Persistence:WritePosition(plugin, systemIndex, pos)` | `IsSpecScopedIndex` true OR consumer already has current-spec data ("sticky") → spec data. otherwise → global, current spec's spec-data cleared. the sticky rule prevents dragging a per-spec-anchored frame off into open space from silently overwriting the chain on every spec. |
| `Persistence:ReadAnchor(plugin, systemIndex)` | spec data first, fall back to global plugin setting. plugins that never wrote spec data are unaffected. |
| `Persistence:ReadPosition(plugin, systemIndex)` | same — spec data first, fall back to global. |

`PositionManager:FlushToStorage` (edit-mode close) and the `Persistence:AttachSettingsListener` drag callback (immediate-write safety net for /reload between drag-stop and flush) both go through these helpers, so the routing stays consistent. the immediate-write path only fires when the routing would actually go to spec data — pure global writes are still left to FlushToStorage.

**spec-change re-restore.** writing the anchor to spec data is only half the story. on a spec swap, the consumer's *live* AnchorGraph entry still points at the previous spec's target frame; without a re-restore pass, width sync would still flow through `PromoteGrandchild`'s ancestor route but the visual position would land on the ancestor instead of the new spec's intended target. `Persistence._attachedFrames` is a weak-keyed registry of every frame that's been wired through `AttachSettingsListener`. on `PLAYER_SPECIALIZATION_CHANGED`, `Persistence:RestoreAffectedBySpecChange` walks the registry (deferred two frames so `RefreshForCurrentSpec` and the subsequent `ReconcileChain` flush both settle first) and re-runs `RestorePosition` for any consumer whose plugin uses spec-scoped storage. consumers with no per-spec data are no-ops (re-anchor to the same global target); consumers like the player frame anchored to a Tracked container pick up the new spec's saved entry and re-anchor to the right `OrbitTrackedContainer<id>`.

`Tracked` opts in by setting `frame.orbitAnchorTargetPerSpec = true` on both `TrackedContainer` and `TrackedBar` build paths. any future plugin whose frames are inherently per-spec can set the same flag to make non-spec-scoped consumers route correctly.

`Tracked` itself sets `plugin.settingsArePerSpec = true` in its registration block, which OPTS OUT of `Persistence`'s spec-data routing for the saving direction. each Tracked record carries its own `spec` field and `record.settings` is already partitioned per-spec at the storage layer (every spec gets its own record with its own `id`), so a second per-spec layer would silently desync from `record.settings` on subsequent edits and would not survive a profile export (spec data is per-character, record settings travel with the profile). when one Tracked container anchors to another Tracked container (which has `orbitAnchorTargetPerSpec`), the consumer-side write goes through `record.settings.Anchor` like any other Tracked setting, not through `SetSpecData`.

`DeleteContainer` cleans up dangling consumer references in BOTH stores: it walks `GetAnchoredChildren` and `GetLogicalChildren`, and for each one calls `ClearChildSavedAnchorIfTargets` which checks the consumer's spec data AND global setting and only nulls an entry if its `target` field actually names the deleted frame (so unrelated anchors aren't nuked).

## empty containers are virtual

an empty tracked frame (icon container with no grid items, or bar with no spell) must not be a valid anchor *target*. without this, `FrameA > TrackedIcons (empty) > FrameC` traps FrameC behind a content-less frame and FrameC has no way to promote up to FrameA — because TrackedIcons isn't *disabled*, it's just empty.

`Plugin:RefreshContainerVirtualState(frame)` toggles the AnchorGraph virtual flag on the frame based on record emptiness:

- icons mode: `not record.grid or next(record.grid) == nil`
- bar mode: `not record.payload or not record.payload.id`

it's hooked into both `Container:Apply` and `Bar:Apply`, which run on every content mutation (drop, item removal, spell clear, spec swap). a `frame._isVirtual` guard avoids redundant `SetFrameVirtual` calls — important because Apply runs on every settings change too, and `SetFrameVirtual(true)` re-parks the frame (even on no-change) per the engine's idempotency rule.

**empty containers stay selectable and movable in edit mode, but cannot anchor as children OR be valid snap targets for other frames.** four engine side effects need to be controlled to make this work:

1. **position park** — the engine parks the frame at `defaultPosition` as part of its idempotency contract. immediately after the virtual flip, `RefreshContainerVirtualState` calls `Orbit.Engine.Frame:RestorePosition` to undo the park and put the frame back at its saved Anchor/Position. the graph keeps the skip flag (so `ReconcileChain` still promotes children past the frame), but the frame's physical SetPoint is restored.
2. **orbitDisabled flag** — `Anchor:SetFrameVirtual` writes `frame.orbitDisabled = Graph:IsSkipped(frame)`, which conflates the virtual axis (content-empty) with the disabled axis (off-spec / plugin off). the Selection module reads `frame.orbitDisabled` to decide whether to render the edit-mode highlight, so virtual frames would show no selection ring and reject clicks. `Plugin:_SyncOrbitDisabledFlag` overrides the flag immediately after every `SetFrameVirtual` / `SetFrameDisabled` call, setting it to reflect ONLY the disabled axis (`Graph:IsDisabled`). virtual-but-on-spec frames stay clickable; truly disabled frames (off-spec, plugin off) still get the flag and stay hidden.
3. **no-snap as child** — virtual = "not a valid anchor target" handles the *target* direction (children of an empty frame promote past it), but does not stop the empty frame itself from snapping to *another* frame as a child during a drag. that would re-create the same trap from the other end: the user drags the empty container onto FrameA, the engine creates an anchor `EmptyTracked > FrameA`, and the moment they add content the chain is rooted in a frame that's not even meant to participate yet. `RefreshContainerVirtualState` sets `frame.orbitNoSnap = isEmpty`, which puts the Drag module into precision mode for this frame: snap detection is skipped during drag-update, and drag-stop saves a raw point/x/y instead of creating an anchor. once the user adds content, the flag clears and the container can re-join chains normally.
4. **filtered out of snap targets** — symmetrical to #3, but for frames being dragged ONTO an empty container. without filtering, the user could drop FrameC onto an empty TrackedIcon, the engine would create the anchor, then `ReconcileChain` would immediately promote FrameC up past the empty target. visually confusing (the drop point isn't where the frame ends up). `Selection:GetSnapTargets` excludes any frame where `Engine.AnchorGraph:IsSkipped(f)` is true, which catches both axes (virtual = empty, disabled = off-spec). disabled frames are already filtered by `IsVisible()` since `SetContainerActive(false)` calls `frame:Hide()`, but virtual frames are explicitly kept visible so users can position them — this is the only filter that catches them.

the virtual axis composes with the disabled axis: a frame is "skipped" when virtual OR disabled. so an empty TrackedIcons that's also off-spec is doubly-skipped. when the user swaps to its home spec, `SetContainerActive` clears the disabled axis and runs `RestorePosition`; the virtual flag stays on (set during the previous Apply), children stay routed past the frame, and the user can still see and drag the empty container at its restored position. once they add content, `Apply` → `RefreshContainerVirtualState` flips virtual off and `RestoreLogicalChildren` pulls FrameC back home in the next reconcile pass.

## position / anchor restore

`BuildContainer` sets `frame.defaultPosition` (CENTER of UIParent + per-mode offset) and then calls `Orbit.Engine.Frame:RestorePosition(frame, self, record.id)`. that walks the standard restore path: ephemeral PositionManager state → `record.settings.Anchor` → `record.settings.Position` → `defaultPosition`. anchors to other orbit frames are stashed in `Persistence.pendingByTarget` if the target hasn't loaded yet, and re-attached the moment the target's `AttachSettingsListener` fires. without this call, frames lose their anchor on /reload because the saved `Anchor` field on the record never gets read.

saving goes through `Persistence:WriteAnchor` / `WritePosition`, which `PositionManager:FlushToStorage` (called when edit mode closes) and the drag-callback immediate-write path both share. for a Tracked container as a CONSUMER (its own anchor save), `WriteAnchor` sees `IsSpecScopedIndex` is false but the plugin's `SetSetting` override still redirects the call into `record.settings.Anchor` — the per-record settings table acts as the global slot. for OTHER plugins anchoring TO a Tracked container as a TARGET, `WriteAnchor` sees `orbitAnchorTargetPerSpec` and partitions the consumer's anchor per-spec via `SetSpecData`.

## secret-value safety

`TrackedBar` uses a small library of pre-built numeric curves so `DurationObject:EvaluateRemainingPercent(curve)` returns a numeric (rather than the always-secret default) and the result can flow straight into `StatusBar:SetValue` / Lua arithmetic. all curves are file-locals built once at load time:

| curve | shape | used by |
|---|---|---|
| `IDENTITY_CURVE` | (0,0)→(1,1) | `active_cd` mode (spell path) — returns the raw remainingPercent as a numeric so the phase-breakpoint math can run in Lua |
| `INVERSE_CURVE` | (0,1)→(1,0) | `cd_only` mode (spell path) — returns `1 - pct` directly so the bar fill 0→1 is a single `SetValue` with no Lua arithmetic |
| `RECHARGE_PROGRESS_CURVE` | (0,1)→(1,0) | `charges` mode — recharge segment fill (input is the charge cooldown's remainingPercent, output is the segment fill 0→1) |
| `RECHARGE_ALPHA_CURVE` | (0,0)→(0.001,1)→(1,1) | `charges` mode — recharge segment alpha (instant 0→1 step at the start of a recharge so there's no fade-in over the first 0.1%) |

**charges mode** combines the curve trick with the sink pattern:

- `payload.maxCharges` is captured at drop time outside combat (stored on the record), so `SetMinMaxValues` always passes a non-secret max. `BuildTrackedBarPayload` guards the capture with `issecretvalue` so the field is left nil if the boundary was crossed somehow.
- talents can change a spell's max charges (or its active override target) without changing spec, so `TrackedPlugin` listens to `TRAIT_CONFIG_UPDATED` and runs `RefreshBarPayloads`, which walks every bar record, rebuilds its payload via `BuildTrackedBarPayload` (re-resolving `GetActiveSpellID` and re-parsing the tooltip), and re-applies the bar so dividers, `SetMinMaxValues`, and the recharge segment width pick up the new max. the event is debounced (0.1s) because `TRAIT_CONFIG_UPDATED` can fire several times per commit. without this refresh, `CountText` updates correctly (it pipes live `chargeInfo.currentCharges` straight to `SetText`) but the bar geometry stays frozen against the stale cached `maxCharges`.
- the size-dependent charges geometry (RechargeSegment width, TickBar width, divider boundaries) lives in `Bar:LayoutChargesGeometry`, which reads `frame.StatusBar:GetWidth()` as the single source of truth and is invoked from BOTH `LayoutForMode` AND a `frame.StatusBar:HookScript("OnSizeChanged", ...)` registered in `Build`. the hook is necessary because docked bars resize via the anchor chain (`SyncChild` sets the bar's width when the parent grows/shrinks), and edit-mode `SyncChildren` deliberately skips `ApplySettings` — without the hook, dividers and the recharge segment stayed pinned to the saved width while the bar visually grew. `frame._chargesMax` / `frame._chargesTickSize` are cached on the frame in charges mode and cleared in continuous modes, so the hook is a no-op when charges geometry doesn't apply.
- `chargeInfo.currentCharges` (always-secret in combat) is piped straight into `StatusBar:SetValue` and `CountText:SetText` — both are c++ sinks that accept secret values.
- the recharge cooldown's `DurationObject:EvaluateRemainingPercent(RECHARGE_PROGRESS_CURVE)` returns a numeric segment fill, and the same `DurationObject` evaluated against `RECHARGE_ALPHA_CURVE` returns a numeric alpha. both are passed to `RechargeSegment:SetValue` / `SetAlpha` without any Lua-side branching.

**active_cd mode** (spell path) needs Lua arithmetic for the phase-split, so it uses `IDENTITY_CURVE` to convert the secret remainingPercent into a numeric, then compares against the cached `_phaseBreakpoint` and computes `barValue` from there. degenerate cases (`activeRange == 0` or `breakpoint == 0`) are guarded so the division can't underflow. items use `C_Container.GetItemCooldown` which is numeric — no curve needed.

**cd_only mode** (spell path) is the simplest: `EvaluateRemainingPercent(INVERSE_CURVE)` is the bar fill, no arithmetic at all. items again use the numeric `C_Container.GetItemCooldown` path.

**icon mode** uses `Cooldown:SetCooldownFromDurationObject(durObj, true)` which is a c++ sink — the secret value never crosses into Lua. charge text uses `FontString:SetText(chargeInfo.currentCharges)` for the same reason.

## rules for future changes

- reuse `Orbit.CooldownDragDrop` (in `Core/Shared/CooldownDragDrop.lua`) for cursor resolution and saved-data builders. don't reimplement.
- each consumer owns its own cursor poll. do not introduce a cross-domain cursor watcher — see the previous incident where a single shared poll silently broke `ViewerInjection` when tracked was removed.
- container records are flat. do not add per-spec or per-mode sub-tables to the store; the `spec` and `mode` fields on each record are how you filter.
- shift-right-click is the deletion gesture across the entire plugin. do not add delete buttons or per-item context menus.
- counter ids are sparse and global. do not add an "id reuse" optimization; the engine handles arbitrary system index keys (verified — no contiguity assumptions in the orbit core).
- adding a new mode (e.g. "ring") means a new file (`TrackedRing.lua`) and a new branch in `TrackedPlugin:BuildContainer` / `ApplySettings` / `TrackedSettings:_Build*Settings`. do not transform existing frames between modes.
