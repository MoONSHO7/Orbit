[start]

### New!
- Added `Objectives Frame` — a movable, resizable, restylable quest/objective tracker. Colour quests by type, set custom title/objective/header colours and font sizes, hover-fade, collapse-in-combat, show quest count.
- Added `Automation` (QoL > Automation):
  - Auto-accept quests
  - Auto-turn-in quests (hold Shift to skip)
  - Auto-select single gossip options
  - Auto-sell junk (grey items) at merchants
  - Auto-repair (uses guild funds when they cover it, otherwise your own)

The above thanks to `LarsMartin`

### Updates
- `Damage Meter`: "Switch to Current on combat" is now a per-meter toggle, so each meter can be set independently (was one shared setting).
- `Minimap`: the square minimap now follows your global Border Style and colour.
- `Datatexts` can now be dragged onto another Orbit frame's edge to anchor to it, resized with a corner grip, and scrolled to change their distance. Alignment guide lines now show while you drag.
- Added Repair summary to the `Status Widget` (shows your repair total after auto-repair).

### Bugfixes
- VE Engine Sliders with multiple profiles were broken
- Previous VE settings where bleeding into the new VE Engine
- Multi-opacity select only show if mouseover condition is active
- VE Profiles are now weighted by position, added an arrow to move positions of profiles.
- Minimap Missions button would not load after switching to and from HUD map
- All fonts across orbit now inherit the Shadow option if selected

Previous Update:

  devnote: I do plan on making some different shapes in the future & onboarding to canvas mode.

- **New Addon: Orbit Pack: Glows**
  - Download on Curseforge for 46 new glow types to add to your CDM & Action Bars.
  - It's a large addon that won't be updated often, so better to keep it out of Orbit.
  - Check out all glows with `/Orbitglow`

## Updates
- Slight Performance Hack to Group Frames
- Minor Adjustments to StatusWidget

Remember, can use the Spotlight feature and type 'Help' to query things about Orbit.

Things will only get better with YOUR feedback! Jump on the Discord and let me know your pain points

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
