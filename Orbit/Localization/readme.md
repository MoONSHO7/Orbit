# Localization

All player-facing strings for the Orbit addon suite live here.
Strings are resolved once at addon load time and exposed as `Orbit.L` — a flat table of `KEY = "translated string"` pairs.

## File layout

```
Localization/
  Localization.xml       load manifest (Boot + all domain files)
  Boot.lua               seeds Orbit.L + Orbit.Localization.Install()
  Domains/
    Common.lua           CMN_  : shared UI verbs (Cancel, Next, Done, ...)
    Config.lua           CFG_  : config panel labels, tab names, tooltips
    PluginManager.lua    PLG_  : plugin manager headers, tri-state tips
    Plugins.lua          PLU_  : per-plugin settings schema labels
    SlashCmds.lua        CMD_  : /orbit output, popup dialogs, minimap tips
    Messages.lua         MSG_  : print / error / status messages
    Tours.lua            TOUR_ : Canvas Mode + Edit Mode guided tours
```

Each domain file owns its prefix and is self-contained. Adding a new feature typically means adding keys to one or two domain files, not creating new ones.

## Access pattern (consumers)

Every consumer file does one line at the top:
```lua
local L = Orbit.L
```
Then uses `L.KEY_NAME` at the call site. Safe anywhere after `Localization.xml` has loaded, which is before every other Orbit file.

## Domain file pattern (authors)

Each domain file is a locale-table declaration followed by one call to the installer:
```lua
local _, Orbit = ...

local LOCALE_STRINGS = {
    enUS = {
        CMN_CANCEL = "Cancel",
        -- ...
    },
    deDE = {
        CMN_CANCEL = "Abbrechen",
        -- partial is fine; missing keys fall back to enUS
    },
    -- frFR = {},
}

Orbit.Localization.Install(LOCALE_STRINGS, "Common")
```
`Install` handles alias resolution (`enGB` → `enUS`, `esMX` → `esES`), per-key fallback to enUS, cross-domain collision detection, and format-string placeholder validation for `_F` suffix keys. See `Boot.lua`.

## Load order

`Orbit.toc` loads `Localization\Localization.xml` between `Core\Libs\Libs.xml` and `Core\Init.lua`. This guarantees `Orbit.L` exists when plugin schema `label = L.KEY` fields are evaluated at table-construction time during file load.

## Key naming convention

Keys are `SCREAMING_SNAKE` with a mandatory domain prefix:

| Prefix | Domain |
|--------|--------|
| `CMN_`  | Common (Cancel, Next, Done, Reset, ...) |
| `CFG_`  | Config panels and settings labels |
| `PLG_`  | Plugin manager (headers, plugin names, tri-state) |
| `PLU_`  | Plugin-specific settings labels (per plugin schema) |
| `CMD_`  | Slash command output, popup dialog text, minimap button |
| `MSG_`  | Print / error / status messages in chat |
| `TOUR_` | Canvas Mode (`TOUR_CM_*`) and Edit Mode (`TOUR_EM_*`) tour strings |

Keys suffixed `_F` are **format strings**. Use `:format()` at the call site, never concatenate:
```lua
Orbit:Print(L.MSG_PLUGIN_RESET_F:format(pluginName))
```
`Install` validates at load time that every locale's `_F` value has the same number of `%` placeholders as enUS. A translator who drops or adds a placeholder logs a warning via `geterrorhandler()` and the key falls back to enUS, so the runtime `:format()` call never throws.

## Adding a string

1. Decide which domain it belongs to by its prefix.
2. Add the key to that domain file's `enUS` table.
3. Use `L.NEW_KEY` at the call site.
4. Other locales fall back to enUS automatically until translated.
5. Run `.scripts/check-localization.sh` to catch typos before commit.

## Adding a translation

1. Open the domain file you want to translate (e.g. `Domains/Common.lua`).
2. Add a locale block (e.g. `deDE = { ... }`) or extend an existing one.
3. Copy the keys from `enUS` and translate the values.
4. Partial translations are valid — missing keys fall back to `enUS` per-key.
5. Submit a PR with just your locale additions.

## Supported locales

`enUS` (+ `enGB` alias), `deDE`, `frFR`, `esES` (+ `esMX` alias), `ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`.

Aliases are handled inside `Install` — you don't need to declare them in every domain file.

## File encoding

All domain files contain non-ASCII characters (Cyrillic, CJK, accented Latin). WoW's Lua loader requires **UTF-8 without BOM**. An `.editorconfig` at the repo root enforces this for any editor that honors it. If your editor strips or adds a BOM, configure it to stop — otherwise the addon will silently fall back to enUS for that file.

## Dev diagnostics

`Orbit.DEBUG_LOCALIZATION` — set to `true` in your own session via:
```
/run Orbit.DEBUG_LOCALIZATION = true
```
Any `L.KEY` access that resolves to a nil value (typo, missing definition) logs via `geterrorhandler()`. Off by default — zero runtime cost when disabled because the metatable `__index` only fires for undefined keys.

## Lint script

`.scripts/check-localization.sh` validates the system without launching the game:

- Every `L.KEY` reference in the codebase resolves to a defined key.
- Prefix isolation — each domain prefix lives in exactly one file.
- No cross-domain key collisions.
- Reports unused keys (non-fatal; many are pre-populated for Phase 4 migration).

Run before every localization-touching commit. Exit 0 on success, non-zero on any hard failure. Safe to run in CI.

```bash
.scripts/check-localization.sh           # normal run
VERBOSE=1 .scripts/check-localization.sh  # list unused keys too
```

## What is NOT in this system

One existing localized subsystem keeps its file-local locale table because its strings are not UI text — they are runtime regex patterns for parsing tooltip duration keywords:

- `Core/Shared/TooltipParser.lua` — locale-specific regex patterns ("for X seconds", "pendant X s", etc.)

These patterns are consumed by `string.match()` / `string.gmatch()` calls and never displayed to the user. They belong with the parser code, not with UI localization.

## Current coverage

- **enUS** for every domain (the source of truth, 320 keys).
- **Full 9-locale coverage** for `TOUR_*` keys (Canvas Mode + Edit Mode tours) and `CMN_NEXT` / `CMN_DONE`, migrated from the old file-local tables.
- **enUS-only** for all other domains — translators can fill in incrementally.

Consumer files (plugin schemas, config panels, slash commands) will be migrated to read from `Orbit.L` in Phase 2–5. Until a consumer is migrated it continues to display its hardcoded English string.

## Before migrating plugin schemas

Read [PHASE_0_DROPDOWN_AUDIT.md](PHASE_0_DROPDOWN_AUDIT.md) first. Several dropdown schemas in the codebase use the same English string as both the display label and the saved-data value. Naively localizing those labels will corrupt user settings. The audit lists every known collision, the correct fix pattern, and which files are safe to migrate without Phase 0 work.
