# spotlight — universal search (qol)

hotkey-driven universal search across bags, equipped gear, spellbook, toys, mounts, pets, heirlooms, professions, currencies, macros, and quest items. account-wide. no user-arranged ui.

## layout

```
Spotlight.lua                   -- namespace, BINDING_* globals, Toggle, PLAYER_LOGIN auto-enable
Spotlight.xml                   -- script load order bundle
(bindings live in Orbit/Bindings.xml at the addon root — wow auto-loads that file and rejects <Binding> elsewhere.)
Search/
  Tokenize.lua                  -- Fold(name) → lowercase + diacritic strip (index-time, run once per entry)
  Matcher.lua                   -- exact > prefix > word-start > substring, with optional fuzzy fallback
Index/
  IndexManager.lua              -- master index; per-source event registration; dirty-tracking + debounced rebuild
  Favorites.lua                 -- right-click favorite toggle for kinds that support it (mounts, pets, toys)
  Recents.lua                   -- recent-activation tracking for sort priority
  MountTypeTags.lua             -- ground / flying / aquatic / dragonriding tags for mount filtering
  Sources/                      -- one file per source. each defines kind, events, persistent, Build, signature.
UI/
  ResultRow.lua                 -- secure-action-button row with orbit-skinned icon + label; mouse-only activation
  RowPool.lua                   -- lazy row creation and reuse
  ClickOutsideCatcher.lua       -- full-screen invisible mouse-down frame
  SpotlightFrame.lua            -- open / close, cursor anchor, debounced query, EditBox input filter
```

## contracts

**source module** (one file in `Index/Sources/`):

```lua
Sources.<kind> = {
    kind       = "<kind>",               -- also set on each entry returned by Build
    events     = { "EVENT_A", ... },     -- registered / unregistered by IndexManager
    persistent = true | false,           -- true → cached in Orbit.db.AccountSettings.SpotlightIndex
    signature  = function(self) ... end, -- only when persistent: invalidate cache when value changes
}
function Sources.<kind>:Build() return { <entry>, ... } end
```

**entry**:

```lua
{
    kind      = "<kind>",       -- matches source kind; used by enabledKinds filter and sort priority
    id        = <number|string>,-- identity (itemID, spellID, mountID, macroIndex, etc.)
    name      = "<display>",    -- user-visible name
    lowerName = "<folded>",     -- Tokenize:Fold(name) — precomputed once
    icon      = <fileID|path>,  -- texture for the row icon
    secure    = { type = "...", <verb> = <value> }, -- for clickable activation; nil for non-secure rows
    onClick   = function(entry) ... end,             -- non-secure fallback (currencies etc.)
}
```

## combat

`Spotlight:Toggle()` and `SpotlightFrame:Open()` both short-circuit in combat with a print via `Orbit:Print(L.PLU_SPT_MSG_COMBAT)`. while spotlight is closed no secure attributes are rewritten, so combat lockdown cannot be tripped.

## activation

activation is mouse-only. left-clicking a row fires the hardware-originated secure dispatch, which is untainted and works for every entry kind — including `type="macro"` (`RunMacroText`). programmatic `row:Click()` from a lua keyboard handler would taint the dispatch and trigger `ADDON_ACTION_FORBIDDEN` on protected verbs, so spotlight does not intercept arrow keys or Enter. `ResultRow:Bind`'s `PostClick` closes spotlight after any activation; ESC closes via the EditBox's `OnEscapePressed`.

right-click toggles the entry's favorite for kinds that support it (`mounts`, `pets`, `toys` — see [Index/Favorites.lua](Index/Favorites.lua)). sources declare their secure verb as bare `type = "..."`, but `SecureActionButtonTemplate` resolves that as a fallback for *any* button (including right) — so `Bind` rebinds `type` as `type1` when copying attributes onto the row. with only `type1` set, right-click has no secure attribute to dispatch and falls through to `PostClick` in lua. the handler mutates `entry.favorite` in place (the same table is shared with IndexManager's master list and the persistent SavedVariables cache), updates the star texture, and leaves spotlight open. right-click on any other kind is a no-op. mounts whose `canFavorite` flag is false (faction-restricted, etc.) are skipped silently. mounts hidden by the journal's filter cannot be toggled here because `C_MountJournal.SetIsFavorite` is index-based on the *displayed* list.

## performance

- lazy — indexers don't run at login. first build happens on first Open (or on source invalidation after Enable).
- persistent cache in `Orbit.db.AccountSettings.SpotlightIndex` for account-wide sources (mounts, pets, toys, heirlooms). version-gated; invalidated by source-declared signature change.
- volatile sources (bags, equipped, spellbook, macros, quest items, currencies, professions) rebuild from live apis on each invalidation — wow events drive rebuilds, not the search loop.
- query path — `Tokenize:Fold` on the input once, then a single pass over the master index. `Matcher` does a cheap substring check and a bounded fuzzy pass only when substring misses. debounced by 50 ms on `OnTextChanged`.
- result rows are created lazily up to the current `Max Results` count and reused across searches.

## settings

all settings are account-scoped in `Orbit.db.AccountSettings`:

- `Spotlight` (boolean) — module enabled
- `Spotlight_Src_<Source>` (boolean, default true) — per-source toggle; disabled sources are filtered out of query results
- `Spotlight_MaxResults` (10 – 100, default 25)
- `Spotlight_Scale` (0.70 – 1.30 in 0.05 steps, default 1.00) — applied via `root:SetScale` on each Open; borders re-skin against the new effective scale so edge thickness stays at constant physical pixels
- `Spotlight_Fuzzy` (boolean, default true)
- `SpotlightIndex` (internal cache)

## adding a new source

1. create `Index/Sources/<NewSource>.lua` following the source contract above.
2. add a `<Script>` line to [Spotlight.xml](Spotlight.xml) in the Sources block before `IndexManager.lua` loads (order doesn't affect behaviour, but convention is alphabetical).
3. add the source to the `SPOTLIGHT_SOURCES` list in [Orbit/Core/Config/Advanced/QoL.lua](../../Core/Config/Advanced/QoL.lua) so it gets a category toggle.
4. add a matching `PLU_SPT_SRC_<NAME>` key to [Orbit/Localization/Domains/Plugins.lua](../../Localization/Domains/Plugins.lua).
5. add the new kind to `GetEnabledKinds()` in [UI/SpotlightFrame.lua](UI/SpotlightFrame.lua) and to `KIND_PRIORITY` in [Search/Matcher.lua](Search/Matcher.lua).
