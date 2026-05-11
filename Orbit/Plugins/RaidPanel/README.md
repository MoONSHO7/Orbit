# raid panel

dock-style raid-leader panel: difficulty (shows current), ready check, role poll, 8 world markers, and ping restriction. visible only when in a group AND the player has lead or assist.

## purpose

one-click access to the raid-management actions a leader uses constantly. circular icons with dark-grey background fill and silver border. arc-wrap and edge-fade tunable from settings, same controls portal exposes.

## layout

```
Plugins/RaidPanel/
  RaidPanelData.lua          slot definitions, marker sprite mapping, difficulty/ping option lists, GetCurrentDifficultyAtlas()
  RaidPanelLayout.lua        pure arc-wrap and edge-fade math (mirrors PortalLayout)
  RaidPanelVisibility.lua    ShouldShow() — in-group AND (leader or assist)
  RaidPanelMenus.lua         MenuUtil dropdowns: Difficulty (dungeon/raid) + Ping Restriction
  RaidPanelIcon.lua          circular icon factory; PostClick opens menus, secure attrs bind macros
  RaidPanel.lua              plugin root: registration, dock frame, layout integration, events, lifecycle
  RaidPanel.xml              load-order bundle
```

## slot order

| # | slot | left click | shift+left |
|---|---|---|---|
| 1 | Difficulty   | open menu (Normal/Heroic/Mythic, +LFR in raid) | — |
| 2 | Ready Check  | `/readycheck` | — |
| 3 | Role Poll    | `/rolepoll` | — |
| 4-11 | Markers 1..8 | `/tm N` (target marker) | `/wm N` (place world marker) |
| 12 | Clear Markers | `/clearworldmarker all` (secure slash → `ClearRaidMarker(nil)`) + `/click OrbitRaidPanelClearTargets` (chains to a hidden `SecureActionButton` with `type=raidtarget action=clear-all` → `RemoveRaidTargets()`) | — |
| 13 | Restrict Pings | open menu (None / Leader / Tanks+Healers) | — |

## click handling

- **macro / marker slots** are `SecureActionButtonTemplate` buttons with `type1 + macrotext1` (left click) and `shift-type1 + shift-macrotext1` (shift+left). both type and macrotext are set explicitly for the shift modifier — relying on `shift-type` falling back to `type` is unreliable across patches.
- **menu slots** have no `type` attribute. the secure dispatch is a no-op, then `PostClick` fires and opens the menu via `MenuUtil.CreateContextMenu`. do **not** override `OnClick` on these — it replaces the template's secure dispatch and breaks the macro slots that share the factory.
- **`/run` inside a secure macrotext is NOT secure.** `ClearRaidMarker`, `SetRaidTarget`, `PlaceRaidMarker`, and `RemoveRaidTargets` are flagged `HasRestrictions = true` (see `Blizzard_APIDocumentationGenerated/RaidMarkersDocumentation.lua`) — they require a secure call site. `/run` is registered via `CheckAddSlashCommand` (non-secure) so calls to these functions from `/run` silently no-op. The Clear Markers slot routes through (a) `/clearworldmarker all`, which IS a `CheckAddSecureSlashCommand`, and (b) `/click OrbitRaidPanelClearTargets`, a hidden `SecureActionButton` whose built-in `raidtarget` action handler (see `Blizzard_FrameXML/SecureTemplates.lua`) calls `RemoveRaidTargets()` natively. Both paths stay inside the secure dispatcher.

## icon textures

each icon is a `Button` (via `SecureActionButtonTemplate`) with the engine's built-in three-state textures plus a sheen overlay matching Portal:

- background — dark-grey solid filled into the circular mask, behind the artwork
- **NormalTexture** — base atlas / sprite cell, always visible, sized to `iconSize × sizeMult`
- **HighlightTexture** — atlas hover variant at the same `sizeMult` as Normal (so the glyph doesn't grow/shrink on hover); or, for slots without an atlas hover variant, a yellow add-blend tint at full button size so the entire circle highlights
- **PushedTexture** — atlas variant at the same `sizeMult` while the mouse button is held
- **sheen** — `talents-sheen-node` atlas, ARTWORK sublevel 6, ADD blend, masked. Translation + alpha animation group plays on `PostClick`. Matches Portal's icon sweep.
- border — `talents-node-choiceflyout-circle-gray` (OVERLAY)
- click sound — `SOUNDKIT.IG_MAINMENU_OPTION` via `PlaySound` on `PostClick`

all three state textures are masked by the same circular mask. `SetNormalAtlas` / `SetHighlightAtlas` / `SetPushedAtlas` resolve through the atlas system, so atlases from `Interface/HUD/UIGroupManager2x` pick the 2x variant automatically.

| slot | normal | hover | pressed |
|---|---|---|---|
| Difficulty (Normal raid/dungeon) | `GM-icon-difficulty-normal` | `GM-icon-difficulty-normal-pressed` | `GM-icon-difficulty-normal-pressed` |
| Difficulty (Heroic) | `GM-icon-difficulty-heroicSelected` | `GM-icon-difficulty-heroicSelected-pressed` | `GM-icon-difficulty-heroicSelected-pressed` |
| Difficulty (Mythic) | `GM-icon-difficulty-mythic` | `GM-icon-difficulty-mythic-pressed` | `GM-icon-difficulty-mythic-pressed` |
| Ready Check | `GM-icon-readyCheck` | `GM-icon-readyCheck-hover` | `GM-icon-readyCheck-pressed` |
| Role Poll | `GM-icon-roles` | `GM-icon-roles-hover` | `GM-icon-roles-pressed` |
| Markers 1-8 | `Interface\TargetingFrame\UI-RaidTargetingIcons` sprite cells 1..8 | yellow add-blend tint | sprite cell dimmed to 85% |
| Clear Markers | `GM-raidMarker-reset` | `GM-raidMarker-reset-hover` | `GM-raidMarker-reset-pressed` |
| Restrict Pings | `Ping_Marker_Icon_NonThreat` | yellow add-blend tint | — |

markers use a raw texture file (no atlas) so they don't get automatic 2x. every other Orbit module that shows markers — [StatusIconMixin](../../Core/UnitDisplay/StatusIconMixin.lua), [BossFrame](../BossFrames/BossFrame.lua), [GroupFrameFactory](../GroupFrames/GroupFrameFactory.lua) — uses the same sprite sheet.

## visibility

```
ShouldShow = IsInGroup() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
```

re-evaluated on `GROUP_ROSTER_UPDATE`, `PARTY_LEADER_CHANGED`, `PLAYER_ENTERING_WORLD`, and after combat (`PLAYER_REGEN_ENABLED`).

**edit mode** overrides ShouldShow — the dock is always shown while `Orbit:IsEditMode()` is true, regardless of party state. Icons follow the standard Orbit edit-mode pattern (mouse disabled, secure attributes cleared) so the SelectionOverlay / anchor guides / snap previews fire unobstructed; clicking icons does nothing in edit mode. `UpdateVisibility` and `RefreshDock` both read `Orbit:IsEditMode()` directly each call — no cached sticky flag — so a `/reload` mid-edit-session and the `EditMode.Exit` transition both correctly hide the dock when nothing else demands it.

## blizzard CompactRaidFrameManager

When this plugin loads, `OrbitEngine.NativeFrame:Park(CompactRaidFrameManager)` hides Blizzard's raid manager UI (the panel with the difficulty / ready check / role poll / pings dropdown that this plugin replaces). When the plugin is disabled via the Orbit Plugin Manager and `/reload`d, `OnDisable` calls `Unpark` so the Blizzard panel reverts to normal behaviour.

This pairing replaces the per-tier `HideBlizzardRaidPanel` checkbox that previously lived on **Group Frames** — toggling this plugin is now the single switch.

The corresponding `VisibilityEngine` entries:
- `RaidPanel` (FRAME_REGISTRY) — exposes the dock to per-frame VE settings (oocFade, opacity, hideMounted, mouseOver, showWithTarget, alphaLock).
- `BlizzRaidManager` (BLIZZARD_REGISTRY, `ownedBy = "Raid Panel"`) — Blizzard's manager. Hidden from the VE config table while this plugin is enabled (no need to configure visibility of a frame we've parked); reappears in the table if the plugin is disabled so the user can configure the native frame directly.

VE settings are *applied* to the dock by `Orbit.OOCFadeMixin:ApplyOOCFade(dock, self, 1)` called once in `OnLoad`. That mixin registers the dock in its `ManagedFrames` table, hooks `SetAlpha` so VE-managed alpha overrides direct plugin writes, installs the hover ticker for `mouseOver` reveal, and re-evaluates on `ORBIT_VISIBILITY_CHANGED`. Without this call, VE writes to its DB but no alpha is ever applied to the dock — verified missing then added.

## orientation

auto-detected from the dock's centre relative to the four screen edges (`LEFT/RIGHT/TOP/BOTTOM`) — same pattern as the portal dock. drag close to a different edge and `Frame:RegisterOrientationCallback` triggers a re-layout.

## settings

| key | type | default |
|---|---|---|
| `DisplayShape` | slider 1..2 (Circle / Square) | 1 (Circle) |
| `DisplayMode`  | slider 1..3 (Hide / Markers / All) — labelled "Marker Display" in UI | 3 (All) |
| `FadeEffect`   | slider 0..100 | 0 (off) |
| `IconSize`     | slider 15..30 | 24 (base size; per-slot multipliers below) |
| `Spacing`      | slider 0..20  | 5  |
| `Compactness`  | slider 0..100 | 0 (linear; 100 wraps the chain onto a circle) |

**DisplayShape** chooses the icon shell:

- `1` **Circle** — circular mask, background tinted with `GlobalSettings.BackdropColour`, silver atlas ring (`talents-node-choiceflyout-circle-gray`).
- `2` **Square** — non-clipping mask (`CLAMPTOBLACKADDITIVE` wrap on WHITE so anything past the icon bounds is clipped, same as circle just square-shaped), background tinted with `GlobalSettings.BackdropColour`, silver atlas ring hidden.

Both shapes share the same `GlobalSettings.BackdropColour` source for the per-icon background. Shape toggles by re-setting the mask texture (`CIRCULAR_MASK_PATH` vs `WHITE_TEXTURE`) — one swap reshapes everything (mask is shared by background / Normal / Highlight / Pushed / sheen).

**Square border modes** depend on `Spacing`:

| `Spacing` | per-icon border | container border | backdrop |
|---|---|---|---|
| `> 0` | `Orbit.Skin:SkinBorder(icon, icon, nil, nil, true)` per icon (`GlobalSettings.IconBorderStyle` + `IconBorderColor`) | — | per-icon `icon.background` tinted with `BackdropColour` |
| `= 0` | hidden (`_borderFrame:Hide`, `_edgeBorderOverlay:Hide`) | `Orbit.Skin:ApplyIconGroupBorder(dock, GetActiveIconBorderStyle())` — one merged border wraps the whole row | single `dock.backdrop` at BACKGROUND layer covers the whole dock; per-icon `icon.background` hidden to avoid alpha-overlap seams between adjacent icons |

Same convention as ActionBars / CooldownLayout / TrackedContainer — `padding == 0` flips per-icon → group border. Switching back to `Spacing > 0` calls `Skin:ClearIconGroupBorder(dock)`, hides the dock backdrop, and reapplies per-icon borders + per-icon background.

**DisplayMode** filters which slots render (edit mode preview respects the selected mode):

- `1` **Hide** — the dock is hidden entirely, edit mode included.
- `2` **Markers** — only Markers 1..8 and Clear Markers render (9 slots). Difficulty / Ready Check / Role Poll / Restrict Pings filtered out.
- `3` **All** — all 13 slots render.

FadeEffect is applied identically in edit mode and at runtime, so the user is positioning what they'll actually see.

reuses portal's `PLU_PORTAL_*` labels for Fade / IconSize / Spacing / Compactness because the strings are identical.

per-slot **inner-image** multiplier — the Button shell (background fill, silver border, hitbox, dock spacing) is always `IconSize × IconSize`; only the inner glyph texture is scaled:

| slot | sizeMult | inner glyph size at default IconSize=32 |
|---|---|---|
| Difficulty / Ready Check / Role Poll | 1.3 | 41.6 (overflows the ring — emphasised) |
| Markers 1..8 | 0.8 | 25.6 (inset within the ring) |
| Clear Markers / Restrict Pings | 1.0 (default) | 32 |

implemented by overriding the default `SetAllPoints` on Normal / Highlight / Pushed textures with `SetSize` + `SetPoint("CENTER")` after `SetNormalAtlas` / `SetHighlightAtlas` / `SetPushedAtlas`.

`Layout.ComputeLayout(sizes, spacing, compactness)` still accepts a per-icon size array — currently all slots pass the same `IconSize` so dock spacing is uniform.

## sprite-sheet cells

slot data can include `spriteSheetCell = { row, col, rows, cols }` (or `{ index, rows, cols }`) — applied via `Texture:SetSpriteSheetCell` after the atlas is set, so flipbook atlases pick a single frame. no slot currently uses this; the helper is in place for future flipbook-only atlases.

## events

| event | reaction |
|---|---|
| `GROUP_ROSTER_UPDATE`, `PARTY_LEADER_CHANGED`, `PLAYER_ENTERING_WORLD` | re-evaluate visibility |
| `PLAYER_DIFFICULTY_CHANGED` | full refresh so the Difficulty icon swaps to the new atlas |
| `PLAYER_REGEN_ENABLED` | flush any `pendingRefresh` queued during combat; re-evaluate visibility |
| `PLAYER_REGEN_DISABLED` | clear edit-mode flag (no rebinds during lockdown) |
| `EditMode.Enter` / `EditMode.Exit` | toggle drag/secure-attr clearing |

## rules

- secure-action bindings are written outside combat only. the plugin uses `pendingRefresh` to defer rebinds.
- the dock itself is not protected (`CreateFrame("Frame")`); only its `SecureActionButtonTemplate` children are.
- markers must remain interactive during combat. visibility transitions during combat are deferred.
- user-visible strings go through `Orbit.L`. shared labels reuse `PLU_PORTAL_*`; raid-panel-specific keys use `PLU_RAIDPANEL_*`.
