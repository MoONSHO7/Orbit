# config

the schema-driven configuration ui. renders settings panels from declarative schemas.

## purpose

provides the entire settings interface for orbit. plugins declare their settings as schemas (using schemabuilder), and config renders them as tabs with controls (sliders, checkboxes, dropdowns, color pickers).

## files

| file | responsibility |
|---|---|
| SchemaBuilder.lua | schema declaration api: `AddTab`, `AddSlider`, `AddCheckbox`, `AddDropdown`, `AddColorCurve`, etc. |
| ConfigRenderer.lua | renders a schema into ui frames. walks the schema tree and creates widgets. |
| ConfigLayout.lua | layout engine for settings panels (3-column grid, spacing, tab bar). |
| OrbitOptionsPanel.lua | main orbit settings panel. slash command handler. tab navigation. |
| OrbitSettingsDialog.lua | settings dialog frame. hosts the tab bar and content area. |
| OrbitOptionsButton.lua | minimap/addon compartment button. |
| PluginManager.lua | plugin enable/disable ui (wow addons settings tab). |
| Widgets/ | individual control widgets (slider, checkbox, dropdown, color picker, font/texture pickers, etc.). |

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
