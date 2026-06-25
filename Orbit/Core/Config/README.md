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
| Schema/SchemaBuilder.lua | `Engine.SchemaBuilder`: composes the common per-plugin setting groups onto a schema tree — `AddSizeSettings`, `AddColorSettings`, `AddColorCurveSettings`, `AddOrientationSettings`, `AddGlowSettings`, and `AddSettingsTabs` (wires the standard tabs into a dialog). Individual controls (slider/checkbox/dropdown/colorpicker) are plain schema-tree tables, **not** builder methods. `MakePluginOnChange` / `SetTabRefreshCallback` are the live-apply plumbing. |
| Schema/ConfigRenderer.lua | renders a schema into ui frames. walks the schema tree and creates widgets. |
| Schema/ConfigLayout.lua | layout engine for settings panels (3-column grid, spacing, tab bar). |
| Panels/OrbitOptionsPanel.lua | dialog shell only: tab registry, open/hide/refresh lifecycle, `ToggleEditMode` (the shared Edit Mode + options toggle used by `/orbit` and Spotlight), and `Panel._helpers` (shared `CreateGlobalSettingsPlugin` / `RefreshAllPreviews` used by tab files). |
| Panels/OrbitSettingsDialog.lua | settings dialog frame. hosts the tab bar and content area. |
| Panels/OrbitAdvancedSettings.lua | orchestrator: tab bar, panel shell, settings registration for the addon settings panel. |
| Panels/Tabs/GlobalTab.lua | Global tab schema: font (+ outline dropdown with a Text Shadow value-checkbox; default font "PT Sans Narrow"), `BorderStyle`, `IconBorderStyle`. The four built-in styles come from `Constants.BorderStyle.Styles`: `"orbit"` ("Orbit Pixel", flat) shows a **Border Size** slider (0-5, `PixelBorderSize`); the three rounded slice styles `"orbit-soft"`/`"orbit-rounded"`/`"orbit-rounder"` show **no** slider (thickness baked into the texture); LibSharedMedia styles show **Border Edge Size** (4-16, step 4) + **Border Offset** (0-16) instead. Changing a style fires `ORBIT_BORDER_SIZE_CHANGED` and rebuilds the tab (conditional sliders). The Border Style / Icon Border Style dropdowns place the built-in entries above a divider, LibSharedMedia borders below it. The Font / Border Style / Icon Border Style rows carry a value-column color swatch (`valueColor`) for `FontColorCurve` / `BorderColor` / `IconBorderColor`; the border swatches hide for styles with no color (`StyleHasColor`). |
| Panels/Tabs/ColorsTab.lua | "Textures" tab schema: textures and color curves (bar/backdrop). Font and border colors moved to the Global tab as value-column swatches. The tab key/label is `"Textures"`; the file keeps its `ColorsTab.lua` name (plugin id `OrbitColors`). |
| Panels/Tabs/EditModeTab.lua | Edit Mode tab schema: show/hide blizzard frames, anchoring, edit mode color curve. |
| Panels/Tabs/ProfilesTab.lua | Profiles tab schema + sub-views (export/import/clone/delete/reset). owns widget registrations only used here (`profileactive`, `profileselect`, `collapseheader`, `checkheader`, `statusmessage`). |
| Entry/SlashCommands.lua | the `/orbit` (and `/orb`) slash — the only chat command; its entire body is `OptionsPanel:ToggleEditMode()`. Every former subcommand now lives in Spotlight, with its logic on the owning module (`Orbit.API` resets/version/inspect, `VisibilityEngine:ResetAll`, `Localization.SetLocaleOverride`). |
| Entry/OrbitOptionsButton.lua | addon compartment button. |
| Advanced/PluginManager.lua | plugin enable/disable checkbox grid content builder. |
| Advanced/FadeProfiles.lua | Fade Profiles tab content builder (`Orbit._AC.CreateFadeProfilesContent`) — named context-fade profiles; the tab is still titled "Visibility Engine". |
| Advanced/QoL.lua | quality-of-life expandable accordion sections content builder. |
| Widgets/ | individual control widgets (slider, checkbox, dropdown, color picker, font/texture pickers, etc.). `ValueSwatch.lua` holds the shared value-column helpers `Layout:ApplyValueColorSwatch` and `Layout:ApplyValueCheckbox` — every value-column control routes through these and right-aligns off `Constants.Widget.ValueInset`, so checkboxes/swatches stay consistent across Dropdown / ColorCurvePicker / TexturePicker / FontPicker. `ConfirmPopup.lua` holds `Layout:ShowConfirm({title, text, acceptText, cancelText, onAccept, data})` — a reusable confirmation dialog skinned to match the Canvas Mode frame (NineSlice metal panel + tiled rock background), used in place of Blizzard `StaticPopupDialogs`. |
| WhatsNew.lua / ChangelogData.lua | post-update changelog popup. |

## adding a new tab

1. create `Panels/Tabs/MyTab.lua`
2. pull `local Panel = Orbit.OptionsPanel` and `local CreateGlobalSettingsPlugin = Panel._helpers.CreateGlobalSettingsPlugin`
3. build a plugin via `CreateGlobalSettingsPlugin("OrbitMyTab")` (or a custom table if you need bespoke GetSetting/SetSetting)
4. declare a `schema()` function returning the schema tree
5. register with `Panel.Tabs[L.CFG_TAB_MYTAB] = { plugin = ..., schema = ... }` — tabs are keyed by the **localized** label (`Orbit.L`), never a raw English string
6. add `L.CFG_TAB_MYTAB` to `TAB_ORDER` in `OrbitOptionsPanel.lua` (exposed as `Panel.TabOrder`)
7. add `<Script file="Panels\Tabs\MyTab.lua"/>` to `Config.xml` **after** `OrbitOptionsPanel.lua` (tab files reference `Panel._helpers` at load time)

## adding a new widget type

1. create the widget file in `Widgets/`
2. implement the standard widget interface: `Create(parent, schema, onChange)`
3. register it in `ConfigRenderer.lua` so the renderer knows how to instantiate it
4. the widget must read from and write to the plugin's settings via `plugin:GetSetting/SetSetting`

## adding settings to a plugin

1. in your plugin, implement `function Plugin:AddSettings(dialog, systemFrame)` — receives the settings dialog and the system frame to populate; use `SchemaBuilder:AddSettingsTabs(dialog, systemFrame, schema)` to wire the standard tabs
2. use `SchemaBuilder` methods to declare controls
3. the config system handles rendering, persistence, and live preview automatically

## rules

- widgets must be **self-contained**. they create their own frames, handle their own input, and call `onChange` when the value changes
- config never calls plugin methods directly. it calls `plugin:SetSetting` and the plugin reacts via `ApplySettings`
- schemas are declarative. no imperative ui code in schema definitions
- all widget dimensions must use constants, never magic numbers
