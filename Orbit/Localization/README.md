# localization

all player-facing strings for the orbit addon suite live here. strings are resolved once at addon load time and exposed as `Orbit.L` — a flat table of `KEY = "translated string"` pairs.

## file layout

```
Localization/
  Localization.xml       -- load manifest (Boot + all domain files)
  Boot.lua               -- seeds Orbit.L + Orbit.Localization.Install()
  Domains/
    Common.lua           -- CMN_  : shared ui verbs (Cancel, Next, Done, ...)
    Config.lua           -- CFG_  : config panel labels, tab names, tooltips
    PluginManager.lua    -- PLG_  : plugin manager headers, tri-state tips
    Plugins.lua          -- PLU_  : per-plugin settings schema labels
    SlashCmds.lua        -- CMD_  : /orbit output, popup dialogs, minimap tips
    Messages.lua         -- MSG_  : print / error / status messages
    Tours.lua            -- TOUR_ : Canvas Mode + Edit Mode guided tours
```

each domain file owns its prefix and is self-contained. adding a new feature typically means adding keys to one or two domain files, not creating new ones.

## access pattern (consumers)

every consumer file does one line at the top:

```lua
local L = Orbit.L
```

then uses `L.KEY_NAME` at the call site. safe anywhere after `Localization.xml` has loaded, which is before every other orbit file.

## domain file pattern (authors)

each domain file is a locale-table declaration followed by one call to the installer:

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

`Install` handles alias resolution (`enGB` → `enUS`, `esMX` → `esES`), per-key fallback to enUS, cross-domain collision detection, and format-string placeholder validation for `_F` suffix keys. see `Boot.lua`.

## load order

`Orbit.toc` loads `Localization\Localization.xml` between `Core\Libs\Libs.xml` and `Core\Init.lua`. this guarantees `Orbit.L` exists when plugin schema `label = L.KEY` fields are evaluated at table-construction time during file load.

## key naming convention

keys are `SCREAMING_SNAKE` with a mandatory domain prefix:

| prefix | domain |
|---|---|
| `CMN_`  | common (Cancel, Next, Done, Reset, ...) |
| `CFG_`  | config panels and settings labels |
| `PLG_`  | plugin manager (headers, plugin names, tri-state) |
| `PLU_`  | plugin-specific settings labels (per plugin schema) |
| `CMD_`  | slash command output, popup dialog text, minimap button |
| `MSG_`  | print / error / status messages in chat |
| `TOUR_` | canvas mode (`TOUR_CM_*`) and edit mode (`TOUR_EM_*`) tour strings |

keys suffixed `_F` are **format strings**. use `:format()` at the call site, never concatenate:

```lua
Orbit:Print(L.MSG_PLUGIN_RESET_F:format(pluginName))
```

`Install` validates at load time that every locale's `_F` value has the same number of `%` placeholders as enUS. a translator who drops or adds a placeholder logs a warning via `geterrorhandler()` and the key falls back to enUS, so the runtime `:format()` call never throws.

## adding a string

1. decide which domain it belongs to by its prefix.
2. add the key to that domain file's `enUS` table.
3. use `L.NEW_KEY` at the call site.
4. other locales fall back to enUS automatically until translated.
5. run `.scripts/check-localization.py` to catch typos before commit.

## adding a translation

1. open the domain file you want to translate (e.g. `Domains/Common.lua`).
2. add a locale block (e.g. `deDE = { ... }`) or extend an existing one.
3. copy the keys from `enUS` and translate the values.
4. partial translations are valid — missing keys fall back to `enUS` per-key.
5. submit a pr with just your locale additions.

## supported locales

`enUS` (+ `enGB` alias), `deDE`, `frFR`, `esES` (+ `esMX` alias), `ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`.

aliases are handled inside `Install` — you don't need to declare them in every domain file.

## file encoding

all domain files contain non-ASCII characters (Cyrillic, CJK, accented Latin). wow's lua loader requires **UTF-8 without BOM**. an `.editorconfig` at the repo root enforces this for any editor that honors it. if your editor strips or adds a BOM, configure it to stop — otherwise the addon will silently fall back to enUS for that file.

## dev diagnostics

`Orbit.DEBUG_LOCALIZATION` — set to `true` in your own session via:

```
/run Orbit.DEBUG_LOCALIZATION = true
```

any `L.KEY` access that resolves to a nil value (typo, missing definition) logs via `geterrorhandler()`. off by default — zero runtime cost when disabled because the metatable `__index` only fires for undefined keys.

## lint script

`.scripts/check-localization.py` validates the system without launching the game:

- every `L.KEY` reference in the codebase resolves to a defined key.
- prefix isolation — each domain prefix lives in exactly one file.
- no cross-domain key collisions.
- reports unused keys (non-fatal; many are pre-populated for future migration).

run before every localization-touching commit. exit 0 on success, non-zero on any hard failure. safe to run in ci.

```bash
python .scripts/check-localization.py            # normal run
VERBOSE=1 python .scripts/check-localization.py  # list unused keys too
```

## what is NOT in this system

one existing localized subsystem keeps its file-local locale table because its strings are not ui text — they are runtime regex patterns for parsing tooltip duration keywords:

- `Core/Shared/TooltipParser.lua` — locale-specific regex patterns ("for X seconds", "pendant X s", etc.)

these patterns are consumed by `string.match()` / `string.gmatch()` calls and never displayed to the user. they belong with the parser code, not with ui localization.
