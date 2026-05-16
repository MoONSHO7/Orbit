# config

the schema-driven configuration ui. renders settings panels from declarative schemas.

## purpose

provides the entire settings interface for orbit. plugins declare their settings as schemas (using schemabuilder), and config renders them as tabs with controls (sliders, checkboxes, dropdowns, color pickers).

## layout

```
Config/
  Schema/    -- schema declaration + rendering pipeline
  Panels/    -- the Orbit Options dialog shell + tab content
    Tabs/    -- one file per tab (Global, Textures, Edit Mode, Profiles)
  Entry/     -- user entry points (slash command, minimap button, addon compartment button)
  Advanced/  -- addon-settings-panel content builders (plugin manager, visibility, QoL)
  Widgets/   -- individual control widgets
  WhatsNew.lua / ChangelogData.lua
```

## files

| file | responsibility |
|---|---|
| Schema/SchemaBuilder.lua | schema declaration api: `AddTab`, `AddSlider`, `AddCheckbox`, `AddDropdown`, `AddColorCurve`, etc. |
| Schema/ConfigRenderer.lua | renders a schema into ui frames. walks the schema tree and creates widgets. |
| Schema/ConfigLayout.lua | layout engine for settings panels (3-column grid, spacing, tab bar). |
| Panels/OrbitOptionsPanel.lua | dialog shell only: tab registry, open/hide/toggle/refresh lifecycle, and `Panel._helpers` (shared `CreateGlobalSettingsPlugin` / `RefreshAllPreviews` used by tab files). |
| Panels/OrbitSettingsDialog.lua | settings dialog frame. hosts the tab bar and content area. |
| Panels/OrbitAdvancedSettings.lua | orchestrator: tab bar, panel shell, settings registration for the addon settings panel. |
| Panels/Tabs/GlobalTab.lua | Global tab schema: font, border (size, style, edge size, offset), `IconBorderStyle`. Border Edge Size and Border Offset are conditionally hidden when Border Style is "Orbit Squared" (the legacy `value="flat"` style). The Font / Border Style / Icon Border Style rows carry a value-column color swatch (`valueColor`) for `FontColorCurve` / `BorderColor` / `IconBorderColor`; the border swatches hide for LibSharedMedia styles. |
| Panels/Tabs/ColorsTab.lua | "Textures" tab schema: textures and color curves (bar/backdrop). Font and border colors moved to the Global tab as value-column swatches. The tab key/label is `"Textures"`; the file keeps its `ColorsTab.lua` name (plugin id `OrbitColors`). |
| Panels/Tabs/EditModeTab.lua | Edit Mode tab schema: show/hide blizzard frames, anchoring, edit mode color curve. |
| Panels/Tabs/ProfilesTab.lua | Profiles tab schema + sub-views (export/import/clone/delete/reset). owns widget registrations only used here (`profileactive`, `profileselect`, `collapseheader`, `checkheader`, `statusmessage`). |
| Entry/SlashCommands.lua | `/orbit` slash command handler, confirmation popups, and debug utilities (help, version, profile, frames, inspect). |
| Entry/OrbitOptionsButton.lua | addon compartment button. |
| Advanced/PluginManager.lua | plugin enable/disable checkbox grid content builder. |
| Advanced/VisibilityEngine.lua | visibility engine scrollable table content builder. |
| Advanced/QoL.lua | quality-of-life expandable accordion sections content builder. |
| Widgets/ | individual control widgets (slider, checkbox, dropdown, color picker, font/texture pickers, etc.). `ValueSwatch.lua` holds the shared value-column helpers `Layout:ApplyValueColorSwatch` and `Layout:ApplyValueCheckbox` — every value-column control routes through these and right-aligns off `Constants.Widget.ValueInset`, so checkboxes/swatches stay consistent across Dropdown / ColorCurvePicker / TexturePicker / FontPicker. |
| WhatsNew.lua / ChangelogData.lua | post-update changelog popup. |

## adding a new tab

1. create `Panels/Tabs/MyTab.lua`
2. pull `local Panel = Orbit.OptionsPanel` and `local helpers = Panel._helpers`
3. build a plugin via `helpers.CreateGlobalSettingsPlugin("OrbitMyTab")` (or a custom table if you need bespoke GetSetting/SetSetting)
4. declare a `schema()` function returning the schema tree
5. register with `Panel.Tabs["My Tab"] = { plugin = ..., schema = ... }`
6. add `"My Tab"` to `TAB_ORDER` in `OrbitOptionsPanel.lua`
7. add `<Script file="Panels\Tabs\MyTab.lua"/>` to `Config.xml` **after** `OrbitOptionsPanel.lua` (tab files reference `Panel._helpers` at load time)

## adding a new widget type

1. create the widget file in `Widgets/`
2. implement the standard widget interface: `Create(parent, schema, onChange)`
3. register it in `ConfigRenderer.lua` so the renderer knows how to instantiate it
4. the widget must read from and write to the plugin's settings via `plugin:GetSetting/SetSetting`

## adding settings to a plugin

1. in your plugin, implement `AddSettings(schema, systemIndex)` or use `WL:AddSettingsTabs`
2. use `SchemaBuilder` methods to declare controls
3. the config system handles rendering, persistence, and live preview automatically

## rules

- widgets must be **self-contained**. they create their own frames, handle their own input, and call `onChange` when the value changes
- config never calls plugin methods directly. it calls `plugin:SetSetting` and the plugin reacts via `ApplySettings`
- schemas are declarative. no imperative ui code in schema definitions
- all widget dimensions must use constants, never magic numbers
