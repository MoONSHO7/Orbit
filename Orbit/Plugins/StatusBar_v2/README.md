# statusbar_v2

a circular (radial) progression bar. shows **experience** while leveling, **reputation** (watched faction) at max level or when xp is disabled, and **honor** while the cursor is over the bar **and Shift is held**. the fill sweeps from the bottom clockwise inside a metal border. the hollow center is a **flourish slot** — it plays an Orbit animation on Great Vault unlock today, and is the home for future level-up / reward FX.

this is a standalone plugin — it does **not** share code with the linear `StatusBars/` plugin (plugins may not depend on other plugins). it reuses only Core: `OrbitEngine.Frame` (edit-mode persistence), `OrbitEngine.ColorCurve`, `OrbitEngine.SchemaBuilder` / `Config`, `OrbitEngine.Pixel`, `Orbit.EventBus`, and `PluginMixin` settings.

## files

| file | responsibility |
| --- | --- |
| `StatusBar_v2.lua` | the orb: frame build, mode resolution (xp/rep/honor), radial fill, tooltip, settings, and the center-FX hub (`SetupCenterFX` + `PlayVaultFlourish`) |
| `GreatVault.lua` | Great Vault integration: replaces Blizzard's vault EventToast with `PlayVaultFlourish`. loads after the main file so `Orbit:GetPlugin("Status Bar v2")` resolves; attaches `Plugin:SetupGreatVault` |

## great vault flourish

the Great Vault "objective complete" animation is an **insecure** `EventToast` (`Enum.EventToastDisplayType.WeeklyRewardUnlock` / `WeeklyRewardUpgrade`), queued through `C_EventToastManager`. with **Replace Great Vault Popup** on (Behaviour tab, default), `GreatVault.lua` wraps `EventToastManagerFrame.DisplayToast`: it replicates the original's advance-remove, drains vault toasts off the front via `RemoveCurrentToast` (firing `PlayVaultFlourish(info.title, info.subtitle)` for each), then displays the front via `orig(self, true)`. every non-vault toast (level-up, scenario, M+ keystone) is untouched. toggling the setting off restores Blizzard's popup live (the hook stays installed but no-ops).

the event text (`info.title` / `info.subtitle`) is Blizzard's own localized string for the event ("you unlocked vault slot…", etc.). for the **Upgrade** toast `info.subtitle` is an item link, which a FontString renders as the item name (Blizzard's own toast resolves it to an item level instead — a future refinement if wanted).

no secret/taint/combat concerns — the EventToast system is pure insecure UI. `C_WeeklyRewards.GetActivities()` (non-secret) is available for a future vault-progress display mode but is not used yet.

## center FX hub

`SetupCenterFX` builds three things, played together by `PlayVaultFlourish(title, subtitle)`:

- `frame.Flourish` — an additive glow underlay (`orbit-radial-glow.tga`, tinted gold), quick scale + alpha pulse (`frame.FlourishAnim`).
- `frame.FlourishFX` — Blizzard's **authentic** unlock FX: a texture on the `greatVault-anim-unlocked-FX` atlas driven by a `FlipBook` animation (9 rows × 9 cols, 77 frames, 2.57s — the exact params from `EventToastManager.xml`). `frame.FlourishFXAnim`.
- `frame.FlourishFXFinal` — a **separate static** texture that holds the final frame during the linger. needed because a FlipBook reverts the flipbook texture's texcoords *after* `OnFinished`, so the live texture can't be pinned (the whole sheet flashes). `HoldVaultFX` copies the flipbook's exact texcoords — `FlourishFXFinal:SetTexCoord(FlourishFX:GetTexCoord())`, read in `OnFinished` before the revert — onto this static texture, so the held frame is byte-identical to where the burst ended (no cell math, no jump). `frame.FlourishFXHold` then lingers `FLOURISH_HOLD` (5s) and fades.
- `frame.FlourishText` — a `Title`/`SubTitle` FontString block just right of the ring (`FLOURISH_TEXT_GAP`), in the **global Orbit font** via `ApplyFlourishFont` (`Orbit.Skin:SkinText`, re-applied on theme change in `ApplySettings`). single line, `SetWordWrap(false)`, no fixed width → auto-sized, never wraps. vertically centered (`PlayVaultFlourish` re-anchors: one line on the orb's middle, two lines straddle it). holds for `VAULT_FX_DURATION + FLOURISH_HOLD` to linger with the held frame.

sizing knobs: `FLOURISH_SIZE` (glow), `VAULT_FX_W/H` (atlas), `FLOURISH_TITLE_SIZE` / `FLOURISH_SUB_SIZE` (text), `FLOURISH_TEXT_GAP` (distance from ring), `FLOURISH_HOLD` (linger seconds). the text parents to the orb frame, so it scales with `Scale`.

it's a hub — add new center animations / flourish types here as they arrive. the text block parents to the orb frame, so it scales with `Scale` (tune `FLOURISH_TEXT_*` if you want it unscaled / repositioned).

**`/orbitvault`** — dev/test command (in `GreatVault.lua`) that fires `PlayVaultFlourish` with sample text (`PLU_SB_V2_VAULT_TEST`) so you can preview the FX + side text. no-ops if the plugin is disabled (no frame); the orb must be visible to see it.

## plugin

| system id | name | display |
| --- | --- | --- |
| `Orbit_StatusBar_v2` | status bar v2 | radial xp/rep fill; honor on hover+Shift |

## mode resolution

`ResolveMode()` picks the data source each update:

1. **Honor** — `_hovered` AND `IsShiftKeyDown()`. driven by `OnEnter`/`OnLeave` (hover state) plus a `MODIFIER_STATE_CHANGED` subscription that re-resolves while hovered, so pressing/releasing Shift over the bar flips it live.
2. **XP** — `UnitLevel < GetMaxPlayerLevel()` and xp not user-disabled.
3. **Reputation** — otherwise (max level / xp disabled): the watched faction, handling major-faction renown, paragon, and standard reaction thresholds via Core `OrbitEngine.ReactionColor`. reputation spans are plain non-secret numbers, reduced to a 0-based `current/max` for the fill.

## how the radial fill works

the fill is a paused `Cooldown` swipe (the same mechanism Blizzard uses for the renown radial in `Blizzard_Journeys`), not a pre-rendered animation:

- `frame.Track` — static dark groove (BACKGROUND), the unfilled state
- `frame.Fill` — a `CooldownFrameTemplate` with `SetSwipeTexture(orbit-radial-fill)`, revealed by `CooldownFrame_SetDisplayAsPercentage(fill, current/max)` and tinted per-mode with `SetSwipeColor`
- `frame.Border` — static metal border drawn **above** the fill so the sweep can't spill over the rim
- `frame.Center` — empty child frame sized to `CENTER_RATIO` of the diameter; reserved for level-up content

`SetRotation(math.pi)` + `SetReverse(true)` align the engine's reveal to the asset's baked bottom-origin, clockwise, dark→light gradient.

## secret values

`CooldownFrame_SetDisplayAsPercentage` does `Saturate(current/max)` arithmetic in Lua, so `RenderFill` guards `issecretvalue(current)`/`issecretvalue(max)` (and `max <= 0`) before calling it. when a value is secret the swipe simply **holds its last displayed percentage** — same contract as `StatusBars/StatusBarBase:SetFill`. XP/Honor are not currently in the secret set, but the guard keeps the bar correct if Blizzard reclassifies them.

## assets

`Core/assets/Radial/orbit-radial-{track,fill,border,glow}.tga` (512², 32-bit straight alpha, ~1 MB each). generated procedurally with Pillow/numpy from `_scratch_renown/gen_v5.py` (the radial set) and a soft gaussian disc (`orbit-radial-glow`, the flourish). the fill texture is white luminance (gloss + dark→light angular gradient baked in) so `SetSwipeColor` can tint it any mode color; the glow is white so `SetVertexColor` tints it.

**filtering** — the track and border are set with `SetTexture(path, nil, nil, "TRILINEAR")` so mipmap filtering minifies the high-res art cleanly at low Scale (default `LINEAR` aliases / looks "pixelly" when a 512² texture is shown at ~70px). the fill is a Cooldown swipe and `SetSwipeTexture` has no filterMode arg, but the band's edges have a soft luminance falloff baked in, so the alias-prone sharp edges (border rims, groove walls) are the ones that get trilinear. if the swipe itself ever looks rough at very small Scale, convert the three TGAs to **BLP** (carries a real mipmap chain for every render path); requires an external BLP tool — Pillow can't write it.

## settings (Layout / Color / Behaviour tabs)

- **Layout**: `Scale` (%) via `SchemaBuilder:AddSizeSettings(..., scaleParams)` → `frame:SetScale`. the widget is square art with fixed `BASE_SIZE` geometry, so it sizes by scale (like MinimapButton / TalkingHead / BagBar), not a pixel width/height — `CreateScaleOnChange` re-centers the frame on scale change. the 512² source keeps it crisp well past the default 50–150% range.
- **Color**: `XPColor` and `HonorColor` (`colorcurve`, `singleColor`) — the fill tint for each mode.
- **Behaviour**: `ReplaceVaultToast` (checkbox, default on) — replace Blizzard's Great Vault popup with the center flourish.

## notes / future

- honor (hover+Shift) requires honor to exist; at very low level `UnitHonorMax` can be 0 and the sweep holds the last value (color still swaps).
- there is no on-screen hint that Shift shows honor — a tooltip hint line would need a new localized key; left out for now.
- the rotation/reverse pair is tuned to the baked asset; if an in-game `/reload` shows the sweep mirrored or starting at the wrong origin, flip `FILL_REVERSE` or adjust `FILL_ROTATION`.
- the hollow center is deliberately contentless. a level-up animation (model/AnimationGroup) should parent to `frame.Center`.
