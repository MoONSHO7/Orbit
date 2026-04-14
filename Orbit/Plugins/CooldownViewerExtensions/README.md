# cooldown viewer extensions

shared plugin that adds extra side tabs to blizzard's `CooldownViewerSettings` frame. owns the `Blizzard_CooldownViewer` addon-loaded hook, the anchor chain that walks below `AurasTab`, and the click dispatch. consumers (currently `Orbit_Tracked`, future plugins later) call `RegisterTab` and the plugin handles the rest.

## why this exists separately

the tabs are not specific to the tracked plugin. anything that needs to spawn editable elements from the cooldown viewer settings panel should be able to add its own tab without coupling to tracked or knowing about blizzard's `LargeSideTabButtonTemplate`. keeping this as its own plugin also means tracked can be enabled/disabled (or rewritten again) without breaking the registration api.

## files

| file | responsibility |
|---|---|
| CooldownViewerExtensionsPlugin.lua | plugin registration (`Orbit_CooldownViewerExtensions`), `RegisterTab` api, `ADDON_LOADED` hook for `Blizzard_CooldownViewer`, deferred build queue, anchor chain below `AurasTab` |

## public api

```lua
local CVE = Orbit:GetPlugin("Orbit_CooldownViewerExtensions")
CVE:RegisterTab({
    id          = "Orbit_Tracked.Icons", -- unique key, dedupes across calls
    atlas       = "communities-chat-icon-plus",
    tooltipText = "Add a new tracked icon container",
    onClick     = function(tabFrame) ... end,
})
```

- if `CooldownViewerSettings` is already loaded, the tab is built immediately
- if not, the spec is queued and built when `Blizzard_CooldownViewer` fires `ADDON_LOADED`
- duplicate `id`s are ignored (idempotent — safe to call from `OnLoad` of multiple consumers)
- the click handler is what executes — these tabs do **not** call `SetDisplayMode`, so the parent frame's content panel stays on whatever the user last selected. each click is a fire-and-forget action.

## anchor chain

the first registered extension tab anchors `TOP -> BOTTOM` of `CooldownViewerSettings.AurasTab` with a `-3` y gap (matching blizzard's spell→auras spacing). subsequent extension tabs chain off the previously-built tab in registration order. registration order is deterministic at load time (tracked registers icons before bars), so the visual order is stable.

`Plugin._lastBuiltTab` tracks the running tail of the chain across multiple `BuildPendingTabs` flushes. consumers commonly call `RegisterTab` more than once in a row (tracked registers Icons and Bars in two separate calls), and if the cooldown viewer is already open the first call flushes `pendingTabs` before the second call is queued — without `_lastBuiltTab` the second tab would re-anchor to `AurasTab` and overlap the first.

## what this plugin does NOT do

- no displayMode switching — extension tabs are click buttons, not panel switchers
- no settings, no persistent state, no spec data
- no live toggle — `liveToggle = false`. you cannot disable this plugin from the orbit panel; it's pure infrastructure
- does not register tabs on its own — every tab comes from another plugin
