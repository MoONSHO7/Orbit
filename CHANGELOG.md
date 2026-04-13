## [@project-version@] - @project-date-iso@
### New Features
- Datatext Drawer - Click one of the four corners of the screen to open the datatext drawer. Drag and drop them anywhere on-screen. Drag them back into the drawer to disable. Drag the right hand corner to resize them. Will continue to expand on these and you're welcome to suggest more/improve whats been built.

- Meta Talents - Added a new QoL feature to help you keep track of the most popular talents for each spec. Find it in the Quality of Life tab in `/orbit plugins`.
    - Select bosses or dungeons to view the most popular talents for that specific encounter, data is fetched and averaged from Warcraft Logs top 100 parses. 
    - Directly Apply the meta talents to your talent tree with a single click.

### Bugfixes
- Static Cooldown Timer Texts
- Player Buff Item Enhancements now draw a pixel border for item enhancements (weapon oils, etc)
- Player Buffs/Debuffs swipe now start at low alpha and fill as their duration expires
- Player Buffs/Debuffs now pulse in and out when expiring
- Minimap compartment flyout now stays open correctly when used alongside FarmHud
- FarmHud compatibility - Orbit no longer fights FarmHud's minimap takeover, resource nodes should now display correctly after mount/dismount/shapeshift
- Minimap compartment no longer shows a question mark icon for the Plumber addon; duplicate entries removed; right-click context menu now appears at the correct position
- Minimap no longer renders on top of bags, the settings panel, and other UI windows
- Minimap zoom buttons are now always interactive and not obscured by the click capture overlay
- The Missions widget in canvas mode now displays a text label instead of a gray square
- QueueStatus frame is now selectable in edit mode when positioned over the minimap; selecting another frame no longer obscures its selection handle

## [1.0.0] - 2026-03-10
### Added
- Initial release of Orbit.
- Core engine and basic UI plugins. 
