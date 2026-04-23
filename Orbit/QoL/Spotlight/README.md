# Spotlight — Universal Search (QoL)

Hotkey-driven universal search across bags, equipped gear, spellbook, toys, mounts, pets, heirlooms, professions, currencies, macros, and quest items. Account-wide. No user-arranged UI.

## Layout

```
Spotlight.lua                   Namespace, BINDING_* globals, Toggle, PLAYER_LOGIN auto-enable
Spotlight.xml                   Script load order bundle
(Bindings live in Orbit/Bindings.xml at the addon root — WoW auto-loads that file and rejects <Binding> elsewhere.)
Search/
  Tokenize.lua                  Fold(name) → lowercase + diacritic strip (index-time, run once per entry)
  Matcher.lua                   exact > prefix > word-start > substring, with optional fuzzy fallback
Index/
  IndexManager.lua              Master index; per-source event registration; dirty-tracking + debounced rebuild
  Sources/                      One file per source. Each defines kind, events, persistent, Build, and signature.
UI/
  ResultRow.lua                 Secure-action-button row with Orbit-skinned icon + label
  RowPool.lua                   Lazy row creation and reuse
  KeyNav.lua                    EditBox arrow/enter/esc interception
  ClickOutsideCatcher.lua       Full-screen invisible mouse-down frame
  SpotlightFrame.lua            Open/close, cursor anchor, debounced query, 10s auto-close
```

## Contracts

**Source module** (one file in `Index/Sources/`):
```lua
Sources.<kind> = {
    kind       = "<kind>",               -- also set on each entry returned by Build
    events     = { "EVENT_A", ... },     -- registered/unregistered by IndexManager
    persistent = true | false,           -- true → cached in Orbit.db.AccountSettings.SpotlightIndex
    signature  = function(self) ... end, -- only when persistent: invalidate cache when value changes
}
function Sources.<kind>:Build() return { <entry>, ... } end
```

**Entry**:
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

## Combat

`Spotlight:Toggle()` and `SpotlightFrame:Open()` both short-circuit in combat with a print via `Orbit:Print(L.PLU_SPT_MSG_COMBAT)`. While Spotlight is closed, no secure attributes are rewritten, so combat lockdown cannot be tripped.

## Performance

- Lazy: indexers don't run at login. First build happens on first Open (or on source invalidation after Enable).
- Persistent cache in `Orbit.db.AccountSettings.SpotlightIndex` for account-wide sources (mounts, pets, toys, heirlooms). Version-gated; invalidated by source-declared signature change.
- Volatile sources (bags, equipped, spellbook, macros, quest items, currencies, professions) rebuild from live APIs on each invalidation — WoW events drive rebuilds, not the search loop.
- Query path: `Tokenize:Fold` on the input once, then a single pass over the master index. Matcher does a cheap substring check and a bounded fuzzy pass only when substring misses. Debounced by 50 ms on `OnTextChanged`.
- Result rows are created lazily up to the current `Max Results` count and reused across searches.

## Settings

All settings are account-scoped in `Orbit.db.AccountSettings`:
- `Spotlight` (boolean) — module enabled
- `Spotlight_Src_<Source>` (boolean, default true) — per-source toggle; disabled sources are filtered out of query results
- `Spotlight_MaxResults` (10-100, default 25)
- `Spotlight_Fuzzy` (boolean, default true)
- `SpotlightIndex` (internal cache)

## Adding a new source

1. Create `Index/Sources/<NewSource>.lua` following the source contract above.
2. Add a `<Script>` line to [Spotlight.xml](Spotlight.xml) in the Sources block before IndexManager.lua loads (order doesn't affect behaviour, but convention is alphabetical).
3. Add the source to the `SPOTLIGHT_SOURCES` list in [Orbit/Core/Config/Advanced/QoL.lua](../../Core/Config/Advanced/QoL.lua) so it gets a category toggle.
4. Add a matching `PLU_SPT_SRC_<NAME>` key to [Orbit/Localization/Domains/Plugins.lua](../../Localization/Domains/Plugins.lua).
5. Add the new kind to `GetEnabledKinds()` in [UI/SpotlightFrame.lua](UI/SpotlightFrame.lua) and to `KIND_PRIORITY` in [Search/Matcher.lua](Search/Matcher.lua).
