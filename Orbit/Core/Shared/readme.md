# shared

project-wide constants, media registrations, and shared glow infrastructure. loaded before all other core modules.

## purpose

provides the single source of truth for numeric constants, layer indices, color presets, registered media assets (fonts/textures via libsharedmedia), and the unified glow controller that all plugins use for rendering and managing glows.

## files

| file | responsibility |
|---|---|
| Constants.lua | all project constants: colors, layer indices (`C.Levels`), border style definitions (`C.BorderStyle`), cooldown system indices, padding values, glow configurations, aura skin presets. |
| Media.lua | libsharedmedia registrations for custom fonts and textures. |
| WhitelistedSpells.lua | Blizzard-whitelisted spell IDs where aura/cooldown fields are non-secret in combat. categorized tables (`CLASS_RESOURCES`, `HEALER_AURAS`, `RAID_BUFFS`, etc.) plus a merged `IsWhitelisted` lookup and query API (`IsSpellWhitelisted`, `IsClassResource`, `IsHealerAura`, `IsCombatRes`). consumed by `GroupAuraFilters` for exclusion lists. no executable logic beyond table construction. |
| SecretValueUtils.lua | helpers for WoW 12.0+ secret value detection. |
| TooltipParser.lua | tooltip scanning for active duration and cooldown duration extraction. |
| CooldownUtils.lua | icon dimension calculation, skin settings builder. |
| CooldownDragDrop.lua | `Orbit.CooldownDragDrop` — pure cursor → cooldown-ability resolver. cursor unwrap, `HasCooldown`/`IsDraggingCooldownAbility` (secret-value guarded), equipment slot lookup, cursor texture resolve, and saved-data entry builders for `TrackedItems` / `InjectedItems` / `TrackedBarSpell`. no plugin references — consumed by `CooldownManager/ViewerInjection.lua` and the (future) redesigned Tracked plugin. |
| GlowUtils.lua | pure data utility for constructing LibOrbitGlow option tables from DB settings. no frame manipulation. |
| GlowController.lua | single authoritative owner for all glow operations. all consumers call this module — no other file touches LibOrbitGlow directly. handles native blizzard overlay suppression, pandemic wrapper frames, proc glow lifecycle, and centralized state tracking via `frame._orbitGlow`. |
| StrataEngine.lua | dynamic Z-index management for root-level containers. persists entity ordering to profiles. provides `GetFrameLevel()` for plugin containers and `BumpUp/BumpDown` for future UI controls. sub-component offsets and frame strata remain in Constants. |
| TooltipStrata.lua | hooks `GameTooltip:OnShow` to raise its frame level above the TOOLTIP-strata dialogs (Canvas Mode, Settings). prevents mouseover tooltips from being buried under those dialogs. |

## adding a new constant

1. add it to the appropriate section in `Constants.lua`
2. reference it via `Orbit.Constants.YourSection.YourConstant`
3. never duplicate the value inline in another file

## rules

- no executable logic in Constants.lua or Media.lua. only declarations.
- no references to any other module (no `require`, no `Orbit.Engine`) in Constants.lua or Media.lua
- constants must be grouped by domain (colors, layers, cooldown indices, etc.)
- magic numbers found anywhere else in the codebase must be extracted here or to the consuming file's top-level constants
- all glow rendering must go through `GlowController`. never call `LCG.Show`/`LCG.Hide` directly from consumer code

