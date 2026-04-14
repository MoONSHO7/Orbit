## [@project-version@] - @project-date-iso@
### New Features
- Datatext Drawer - Click one of the four corners of the screen to open the datatext drawer. Drag and drop them anywhere on-screen. Drag them back into the drawer to disable. Drag the right hand corner to resize them. Will continue to expand on these and you're welcome to suggest more/improve whats been built.

- Meta Talents - Added a new QoL feature to help you keep track of the most popular talents for each spec. Find it in the Quality of Life tab in `/orbit plugins`.
    - Select bosses or dungeons to view the most popular talents for that specific encounter, data is fetched and averaged from Warcraft Logs top 100 parses. 
    - Directly Apply the meta talents to your talent tree with a single click.

- Tracked Cooldowns: Re-designed:
  - Create new Icon and Bars from the Cooldown Settings bar now (where you manage the CDM icons)
  - These frames can now be anchored to other Orbit frames again
  - Orbit will handle frame positioning when moving through different specs
  - Bars can be vertically aligned
  - Bars now in canvas mode with additional text options
  - Drag and Drop spells onto these frames to add abilities/items
  - Shift-Right Click to remove spells/items/frames (out of combat only)

- Localization: Add support for 8 language domains. Orbit now supports translated UI strings with per-key fallback to English. (feedback on this from our non-English speakers welcome :)
- VisibilityEngine: New Alpha Lock setting, plus search bar and UI polish in the visibility panel.
- MoveMore: Frame positions now saved between sessions (optional); expanded the list of movable Blizzard frames.
- Status Icons: New header-style role icons and leader icon variants.
- Performance datatext now shows Orbit CPU and can be pinned.

### Bugfixes
- Group Frames not saving position
- Disabled 'Save Positions' in Move More, needs more testing.

## [1.0.0] - 2026-03-10
### Added
- Initial release of Orbit.
- Core engine and basic UI plugins. 
