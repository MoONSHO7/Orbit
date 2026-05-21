# unit frames

player, target, and focus unit frames with their associated sub-frames.

## purpose

displays the three primary singleton unit frames (player, target, focus) and their extensions: power bars, resource bars, buffs, debuffs, target-of-target, and pet frames.

## directory structure

```
UnitFrames/
  Player/
    Player.xml                   -- load-order bundle for Player/
    PlayerFrame.lua              -- player health frame
    PlayerPower.lua              -- player power bar (mana/energy/rage)
    PlayerResources.lua          -- class resource bar (combo points, holy power, etc.)
    PlayerResourceSettings.lua   -- resource bar settings schema
    PlayerResourceConstants.lua  -- resource bar constants
    ContinuousBarRenderer.lua    -- continuous bar rendering strategy (smooth fill)
    DiscreteBarRenderer.lua      -- discrete bar rendering strategy (segmented pips)
    PlayerPetFrame.lua           -- player pet frame
    PlayerCastBar.lua            -- player cast bar
    PlayerBuffs.lua              -- player buff display
    PlayerDebuffs.lua            -- player debuff display
  Target/
    Target.xml                   -- load-order bundle for Target/
    TargetFrame.lua              -- target health frame
    TargetBuffs.lua              -- target buff display
    TargetDebuffs.lua            -- target debuff display
    TargetOfTargetFrame.lua      -- target-of-target sub-frame
    TargetCastBar.lua            -- target cast bar
    TargetPower.lua              -- target power bar
  Focus/
    Focus.xml                    -- load-order bundle for Focus/
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
3. sub-frames manage their own enabled state independently
4. all frames use `UnitButton` from core/unitdisplay for secure targeting

## adding a new sub-frame

1. create the sub-frame file in the appropriate unit directory
2. register it as a separate plugin
3. share behavior via core/unitdisplay mixins (e.g., `UnitPowerBarMixin`, `CastBarMixin`)
4. declare plugin schema defaults inline in the `defaults = { ... }` block of the options table passed to `RegisterPlugin`. Do not edit `DefaultProfile.lua` — that file is a saved-layout snapshot owned by ProfileManager, not the plugin-schema default site.

## rules

- Player/Target/Focus share the structural template — some drift exists (`Player/` has additional buff/debuff/resource subsystems). if you add a feature to one, check if it should be added to all three.
- sub-frames (buffs, debuffs, power) are standalone plugins, not embedded in the parent
- sub-frame enable/disable is controlled by the parent plugin's settings
- new cast bars must use `CastBarMixin`, not duplicate the update loop. **known divergence:** `PlayerCastBar.lua` and `BossFrameCastBar.lua` predate the consolidation rule and currently reimplement the cast-bar update loop. Consolidating into `CastBarMixin` is tracked technical debt — until then, treat the rule as "new cast bars MUST use CastBarMixin; existing reimplementations are technical debt."
- target/focus frames must handle rapid unit changes gracefully (no stale data flash)
