# quality of life modules

the `QoL/` directory contains standalone, lightweight quality-of-life adjustments to the blizzard ui (e.g. making frames draggable, modifying default mouse behaviors, tweaking tooltips, hotkey-driven search).

these modules differ from standard orbit plugins because they are **account-wide** and do not participate in the orbit profile system. they also have no edit-mode or canvas-mode footprint — they're not user-arranged ui.

## naming structure

- **module name** — descriptive, concisely reflects the functionality (`MoveMore`, `FastLoot`, `EasyDelete`, `Spotlight`).
- **file name** — PascalCase matching the module name (`MoveMore.lua`).
- **namespace** — register the module under `Orbit.ModuleName` (e.g. `Orbit.MoveMore = {}`).
- **decomposed modules** — larger qol features may live in a folder (`QoL/ModuleName/`) with one file per bounded responsibility and a module-local `README.md`. files are loaded in dependency order via the `.toc` and share the `Orbit.ModuleName` namespace through sub-tables.

## configuration ui

qol settings are presented in the orbit configuration panel under the "quality of life" tab, grouped into expandable accordion sections.

to add a new section, update `Orbit/Core/Config/Advanced/QoL.lua`:

1. create a builder function: `local function BuildMySection(body) ... end`
2. the builder receives the accordion body frame. use `Layout:AddControl()` and `Layout:Stack()` to lay out widgets.
3. return the computed content height from the builder.
4. add the section to `sectionDefs`:
   ```lua
   local sectionDefs = {
       { "My Section", BuildMySection },
   }
   ```
5. the accordion and scroll infrastructure handle the rest.

## saving & reading settings

all qol settings **must** be account-wide. **do not** use `Orbit.db.profile` or generic `Orbit.db` keys — those tie the setting to the active character profile or risk data wipes on profile switch.

use the helpers defined in `QoL.lua`:

```lua
-- reading
local val = GetAccountSetting("MyCoolSetting", false)

-- saving
SetAccountSetting("MyCoolSetting", newValue)
```

## initialization & architecture

modules define `Enable()` and `Disable()` methods. use a delayed timer on `PLAYER_LOGIN` to read the setting from `Orbit.db.AccountSettings` and invoke `Enable()` if active:

```lua
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
        if Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.MyModuleEnabled then
            Orbit.MyModule:Enable()
        end
    end)
    loader:UnregisterAllEvents()
end)
```

keep modules combat-safe. use `Orbit:SafeAction(callback)` or `InCombatLockdown()` checks before modifying protected blizzard ui elements.

## rules

- account-wide only — never touch `Orbit.db.profile`.
- modules must not depend on other plugins or other qol modules.
- decomposed modules (`QoL/ModuleName/`) must keep all module-local state inside the `Orbit.ModuleName` namespace; no module-level mutable state in source files.
- user-visible strings go through `Orbit.L`. see `Orbit/Localization/README.md`.
