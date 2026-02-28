# unit frames

player, target, and focus unit frames with their associated sub-frames.

## purpose

displays the three primary singleton unit frames (player, target, focus) and their extensions: power bars, resource bars, buffs, debuffs, target-of-target, and pet frames.

## directory structure

```
UnitFrames/
  Player/
    PlayerFrame.lua              -- player health frame
    PlayerPower.lua              -- player power bar (mana/energy/rage)
    PlayerResources.lua          -- class resource bar (combo points, holy power, etc.)
    PlayerResourceSettings.lua   -- resource bar settings schema
    PlayerPetFrame.lua           -- player pet frame
    PlayerCastBar.lua            -- player cast bar
  Target/
    TargetFrame.lua              -- target health frame
    TargetBuffs.lua              -- target buff display
    TargetDebuffs.lua            -- target debuff display
    TargetOfTargetFrame.lua      -- target-of-target sub-frame
    TargetCastBar.lua            -- target cast bar
    TargetPower.lua              -- target power bar
  Focus/
    FocusFrame.lua               -- focus health frame
    FocusBuffs.lua               -- focus buff display
    FocusDebuffs.lua             -- focus debuff display
    TargetOfFocusFrame.lua       -- focus-target sub-frame
    FocusCastBar.lua             -- focus cast bar
    FocusPower.lua               -- focus power bar
```

## how it works

each unit frame type (player, target, focus) follows the same pattern:

1. main frame registers as a plugin and creates the health frame
2. sub-frames (power, cast bar, buffs, debuffs) register as separate plugins
3. sub-frames check their parent's enabled state via `ReadPluginSetting`
4. all frames use `UnitButton` from core/unitdisplay for secure targeting

## adding a new sub-frame

1. create the sub-frame file in the appropriate unit directory
2. register it as a separate plugin
3. use `ReadPluginSetting` to check the parent frame's enable toggle
4. share behavior via core/unitdisplay mixins (e.g., `UnitPowerBarMixin`, `CastBarMixin`)
5. add default settings in `DefaultProfile.lua`

## rules

- player, target, and focus follow mirrored structure. if you add a feature to one, check if it should be added to all three
- sub-frames (buffs, debuffs, power) are standalone plugins, not embedded in the parent
- sub-frame enable/disable is controlled by the parent plugin's settings
- cast bar logic must use `CastBarMixin`, not duplicate the update loop
- target/focus frames must handle rapid unit changes gracefully (no stale data flash)
