# Orbit Quality of Life (QoL) Modules

The `QoL` directory contains standalone, lightweight quality-of-life adjustments to the Blizzard UI (e.g., making frames draggable, modifying default mouse behaviors, tweaking tooltips).

These modules differ from standard Orbit plugins because they are **Account-Wide** and do not participate in the Orbit Profile system.

## 1. Naming Structure
- **Module Name:** Should be descriptive and concisely reflect the functionality (e.g., `MoveMore`, `FastLoot`, `EasyDelete`).
- **File Name:** PascalCase matching the module name (e.g., `MoveMore.lua`).
- **Namespace:** Register the module under `Orbit.ModuleName` (e.g., `Orbit.MoveMore = {}`).

## 2. Setting Up the Configuration UI
QoL settings are presented in the Orbit configuration panel under the "Quality of Life" tab. They are grouped into expandable accordion sections.

To add a new section, update `Orbit/Core/Config/Advanced/QoL.lua`:

1. Create a builder function: `local function BuildMySection(body) ... end`
2. The builder receives the accordion body frame. Use `Layout:AddControl()` and `Layout:Stack()` to lay out widgets.
3. Return the computed content height from the builder.
4. Add the section to `sectionDefs`:
   ```lua
   local sectionDefs = {
       { "My Section", BuildMySection },
   }
   ```
5. The accordion and scroll infrastructure handle the rest.

## 3. Saving & Reading Settings
All QoL settings **MUST** be Account-Wide. 

**Do NOT** use `Orbit.db.profile` or generic `Orbit.db` keys, as this ties the setting to the currently active character profile or risks data wipes.

**Use the helpers defined in QoL.lua:**
```lua
-- Reading:
local val = GetAccountSetting("MyCoolSetting", false)

-- Saving:
SetAccountSetting("MyCoolSetting", newValue)
```

## 4. Initialization & Architecture
Modules should define `Enable()` and `Disable()` methods.
Use a delayed timer on `PLAYER_LOGIN` to read the setting from `Orbit.db.AccountSettings` and invoke your `Enable()` method if active.

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

Keep your modules combat-safe. Use `Orbit:SafeAction(callback)` or `InCombatLockdown()` checks before modifying protected Blizzard UI elements.
