[start]

### Updates
- [ObjectiveFrame] Objective Frame Scroll works properly now if quest log is rather full.
- [ObjectiveFrame] Added "Blizzard Style" to Objective Frame
- [ObjectiveFrame] Added more behaviour options (Auto Add/Remove Quests & WQ - based on Zone)
- [CDM] Shift-Right clicking icons now brings up a menu (Tracked CD and CDM)
- [CDM] Custom Glows and Sounds for events per icon
- [ActionBars] A few bug fixes with how they are created/destroyed
- [Spotlight] Addeed more help commands to explain glows on CDM
- [ColorPicker] Fixed a rare combat lua error

[end]

<!-- Everything BELOW the [end] tag is ignored by .scripts/update_changelog.py.
     Keep this guide here — it is never published to the in-game window. -->

## Changelog formatting guide

`.scripts/update_changelog.py` reads only the text between `[start]` and `[end]`,
turns each `### Heading` into one card in the in-game **What's New** window, and
writes the result to `Orbit/Core/Config/ChangelogData.lua` at deploy time.

### What the script does
- **Only `[start]`…`[end]` is published.** Put each marker on its own line. Anything outside (including this guide) is ignored.
- **`### Title` = one card.** The text after `###` becomes the card title; everything down to the next `###` (or `[end]`) becomes that card's body.
- **Start with a `###`.** Any text between `[start]` and the first `###` is silently dropped.
- **Line breaks are kept.** Each new line in the body shows as a new line in-game — that is how you make multiple bullets in one card.
- **Quotes are safe.** A literal `"` is escaped automatically; type them freely.
- **Version is automatic.** The deploy injects the release number; never type a version.

### What is NOT supported (gotchas)
- **No markdown rendering in-game.** The What's New window is plain text, so `**bold**`, `` `backticks` ``, `[links](url)`, tables, and nested-bullet indentation all appear *literally*. (`-` bullets and indent spaces show exactly as typed.)
- **Use WoW escape codes for styling** — these pass straight through and DO render: colour `|cffffd100gold text|r`, line break `|n`, texture/icon `|TInterface\\Icons\\Foo:16|t`.
- **Avoid a lone backslash `\`.** Backslashes are not escaped and can corrupt the generated Lua — double them (`\\`) if you truly need one.
- **Use exactly three hashes, on their own line** (`### Title`). `####` or a `###` mid-line confuses the splitter.
