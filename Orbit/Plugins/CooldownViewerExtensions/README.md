# cooldown viewer extensions

shared plugin that adds extra side tabs to blizzard's `CooldownViewerSettings` frame. owns the `Blizzard_CooldownViewer` addon-loaded hook, the anchor chain that walks below `AurasTab`, and the click dispatch. consumers (currently `Orbit_Tracked`, future plugins later) call `RegisterTab` to add a tab.

## why this exists separately

the tabs are not specific to the tracked plugin. anything that needs to spawn editable elements from the cooldown viewer settings panel should be able to add its own tab without coupling to tracked or knowing about blizzard's `LargeSideTabButtonTemplate`. keeping this as its own plugin also means tracked can be enabled/disabled (or rewritten again) without breaking the registration api.

## files

| file | responsibility |
|---|---|
| CooldownViewerExtensionsPlugin.lua | plugin registration (`Orbit_CooldownViewerExtensions`), `RegisterTab` api, `ADDON_LOADED` hook for `Blizzard_CooldownViewer`, deferred build queue, anchor chain below `AurasTab` |
| CooldownSettingsDragBridge.lua | captures the spellID of a spell dragged out of the `CooldownViewerSettings` panel and dispatches to any Orbit frame exposing `:OnCooldownSettingsDrop(spellID)`. installed from the plugin's settings-ready path. |

## drag bridge

Blizzard's internal panel drag (`BeginOrderChange`) never populates `GetCursorInfo`, so the normal cursor-based Orbit drop path can't see spells dragged out of the settings panel. The bridge uses the **Spellid addon pattern**: `GameTooltip:HookScript("OnUpdate", ...)` continuously reads `tooltip:GetSpell()` into a local cache. On `GLOBAL_MOUSE_DOWN` over a panel spell (verified by walking the tooltip owner's parent chain to `CooldownViewerSettings`), the cached spellID is armed; on `GLOBAL_MOUSE_UP` the bridge walks `GetMouseFoci()` and calls `frame:OnCooldownSettingsDrop(spellID)` on the first match.

**No mixin hooks.** The deleted first-generation bridge used `hooksecurefunc(CooldownViewerSettingsItemMixin, "OnDragStart", ...)` — a mixin-table hook that tainted every panel item and propagated into CDM viewer children. The tooltip approach is a pure-read pattern (`HookScript` is a script-handler hook; `tooltip:GetSpell()` is read-only), so zero taint surface.

**Spell-only.** The cooldown viewer settings panel never shows items. The bridge always dispatches `(type="spell", spellID)` through `DragDrop:BuildTrackedItemEntry` / `BuildTrackedBarPayload`, reusing the same builders as the spellbook/action-bar drop paths.

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

## parenting

tabs are parented to `UIParent`, **not** `CooldownViewerSettings`. the `hooksecurefunc(tab, "SetChecked", ...)` and `SetCustomOnMouseUpHandler` hooks that live on each tab can be called by blizzard's click dispatch; if the tabs were children of `CooldownViewerSettings`, those callbacks would be writing to a child of a secure blizzard frame while on the panel's secure call stack, and the taint would propagate into the panel's attribute chain. strata and frame level are matched to the panel via `SetFrameStrata` / `SetFrameLevel(parent:GetFrameLevel() + 10)` so the tabs still render above the panel. visibility is synced via `parent:HookScript("OnShow"/"OnHide")` — script-handler hooks, not method hooks, which don't propagate method-level taint.

`Plugin._lastBuiltTab` tracks the running tail of the chain across multiple `BuildPendingTabs` flushes. consumers commonly call `RegisterTab` more than once in a row (tracked registers Icons and Bars in two separate calls), and if the cooldown viewer is already open the first call flushes `pendingTabs` before the second call is queued — without `_lastBuiltTab` the second tab would re-anchor to `AurasTab` and overlap the first.

## what this plugin does NOT do

- no displayMode switching — extension tabs are click buttons, not panel switchers
- no settings, no persistent state, no spec data
- no live toggle — `liveToggle = false`. you cannot disable this plugin from the orbit panel; it's pure infrastructure
- does not register tabs on its own — every tab comes from another plugin
- does not bridge drags out of the cooldown viewer. tracked accepts drops from the spellbook and bags only (via the normal cursor path). dragging an icon out of the cooldown viewer settings panel is a no-op.
