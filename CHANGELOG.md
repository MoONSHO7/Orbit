[start]

### New Features
- `Added Damage Meters`
    - Master meter that shows only your character
    - Shift-Right Click Damage Meters for the options menu (Create, Delete, Reset, Select Metrics)
    - Shift-Left Click Damage Meters for Damage Comparisons (if available)
    - Left click to drill down
    - Right click to select History

- Other Stuff
    - Added Guidelines in Edit Mode for easier positioning
    - `Orbit Portal` has been updated! Go download on Curse to check it out
    - Press Left-Alt in Edit Mode to hide selection frames
    - Added Icon Positioning to Cast Bars
    - Added all Blizzard Frames to the VE Engine for more control if you disable Orbit stuff

### Previous Feature Reminders
- Datatext Drawer 
    - Click one of the four corners of the screen to open the datatext drawer. Drag and drop them anywhere on-screen. Drag them back into the drawer to disable. Drag the right hand corner to resize them. Will continue to expand on these and you're welcome to suggest more/improve whats been built.

- Meta Talents - Added a new QoL feature to help you keep track of the most popular talents for each spec. Find it in the Quality of Life tab in `/orbit plugins`.
    - Select bosses or dungeons to view the most popular talents for that specific encounter, data is fetched and averaged from Warcraft Logs top 100 parses. 
    - Directly Apply the meta talents to your talent tree with a single click.
    - `Turned on by Default now`
  
- Tracked Cooldowns: Re-designed:
    - Create new Icon and Bars from the Cooldown Settings bar now (where you manage the CDM icons)
    - These frames can now be anchored to other Orbit frames again
    - Orbit will handle frame positioning when moving through different specs
    - Bars can be vertically aligned
    - Bars now in canvas mode with additional text options
    - Drag and Drop spells onto these frames to add abilities/items `(From Spellbook or Bags)`
    - Shift-Right Click to remove spells/items/frames (out of combat only)

### Bugfixes
- Source of magic on groupframe fix (havent been able to test)
- Vehicle Exit Button Circular Dependency fix (this was causing frames to lose their positions on /reload)
- Minimap Fixes
- Canvas Mode Fixes (Some components not resizing/settings stuff)
- Target/Focus buffs sometimes not able to be mouseovered
- Attempt to make priest out of range opacity more noticable
- Unit Health color not impacting Group/Boss frames edit mode

### Hints
You can always open this window again by typing `/orbit whatsnew`
You can always disable a plugin in `/orbit plugins`
Visibility settings are found in the VE Engine `/orbit ve`

[end]