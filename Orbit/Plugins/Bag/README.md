# bag

a spatial-grid inventory addon. the bag is a hidden grid of 40px cells. users carve out **categories** by marquee-dragging rectangular regions in empty grid space. items pinned to a region fill that region's cells. everything else falls into the implicit **All Items** pool that packs into the bottom of the workspace with no visible empty cells.

## design north star

> **the bag is a canvas. the user paints categories onto it spatially.**

- the grid is invisible until you interact with it. dragging in empty space draws a marquee that snaps to grid cells.
- a category = a rectangular region of grid cells + a list of pinned itemIDs + a color + a name.
- the **All Items** category is implicit, can't be created or deleted, has no rectangular region. it contains every item not pinned to another category and packs them into the bottom of the workspace.
- categories show empty cell backgrounds (so you can see the rectangle you drew). All Items shows only items — no empty cells.
- items pinned to a category fill its cells in bag-scan order (bag 0 slot 1, bag 0 slot 2, ..., bag 5 slot N). overflow items past the region's capacity are not rendered in v1.

## files

| file | responsibility |
|---|---|
| BagPlugin.lua | registration (`Orbit:RegisterPlugin("Bag", "Orbit_Bag", ...)`), lifecycle, visibility hooks (`OpenAllBags`/`CloseAllBags`/`OpenBackpack`/`CloseBackpack` mirror `_isOpen`; `UISpecialFrames` for Esc), event subscriptions, calls `BagHider:HideAll` to park blizzard's bags |
| BagFrame.lua | root frame `Build` using `PortraitFrameTemplate` (title bar + portrait + close + nineslice) at `DIALOG` strata, draggable by title bar, position persists to `OrbitDB.AccountSettings.BagPosition`. owns the search bar (`SearchBoxTemplate` → `C_Container.SetItemSearch`, inset past the portrait) and the free/total counter. delegates the workspace layout to `BagGrid`. |
| BagGrid.lua | the workspace itself. owns the slot button array (`CreateFrame("ItemButton", "OrbitBagSlot"..i, ...)`), category region frames + their empty-cell textures, the marquee overlay, and the per-refresh `Apply` (collects bag items, groups by category, renders each region with its cells, packs unpinned items into the All Items pool below). marquee gesture: `OnMouseDown` in empty workspace area → snap to grid → preview rectangle each frame → `OnMouseUp` creates a category via `BagCategoryStore:CreateCategory` if the rect doesn't overlap an existing region. |
| BagCategoryStore.lua | account-scoped data under `Orbit.db.AccountSettings.BagCategories` (`categories` keyed by id, `displayOrder` array, `nextId`). every category has a `region = {x, y, w, h}` in grid cells. methods: `CreateCategory`, `DeleteCategory`, `RenameCategory`, `RecolorCategory`, `PinItem`, `UnpinItem`, `GetCategoryForItem`, `GetOrderedCategories`, `GetCategory`, `RegionOverlapsAny`. fires `ORBIT_BAG_CATEGORIES_CHANGED` on every mutation. |
| BagContextMenu.lua | right-click menus + drag-to-pin. `OpenItemMenu` (shift-right-click on a slot → pin/unpin submenu), `OpenCategoryMenu` (right-click on a region → rename/color/delete), `OnRegionReceiveDrag` (drop a cursor item onto a region → pin via `CursorHasItem` + `GetCursorInfo`). owns the `ORBIT_BAG_RENAME_CATEGORY` `StaticPopupDialog` and the 8-color curated palette. |
| BagHider.lua | parks `ContainerFrameCombinedBags` + `ContainerFrame1..13` via `Orbit.Engine.NativeFrame:Park`. overrides `IsBackpackOpen`, `IsAnyBagOpen`, `IsAnyStandardHeldBagOpen`, `IsBagOpen` to return our plugin's `_isOpen` so blizzard's `ToggleBackpack_Combined` dispatches correctly. hooks `ContainerFrameCombinedBags:Hide` to mirror its close call back to our state. combat-guarded. |
| BagSettings.lua | `Plugin:AddSettings` schema (3 layout sliders — not directly used by `BagGrid` in v1, which uses fixed 40px cells; settings will return when configurability is needed). |
| Bag.xml | script bundle. load order: store → context menu → hider → grid → frame → plugin → settings. |
| README.md | this file. |

## grid model

- **cell size**: 40px (square). **padding**: 2px between cells. **stride** (cell + padding): 42px.
- **default workspace width**: 16 cells = 672px.
- **workspace height**: dynamic — `max(category bottoms) + gap + (allItems / cols) * stride`.
- **coordinate system**: grid cell `(0, 0)` is the top-left of the workspace. `col` increases right, `row` increases down.
- **categories** occupy grid cells from `(r.x, r.y)` to `(r.x + r.w, r.y + r.h)`. the header label floats *above* the region's top edge (in negative-y space). adjacent vertical regions without a gap will have header overlap — leave at least 1 row between them.

## data model

```lua
Orbit.db.AccountSettings.BagCategories = {
    categories = {
        ["1"] = {
            id = "1",
            name = "Raid Consumables",
            color = { r = 0.95, g = 0.6, b = 0.2 },
            region = { x = 0, y = 0, w = 4, h = 3 },   -- grid coordinates
            addedItems = { ["i:171280"] = true, ["i:191324"] = true },
        },
        ["2"] = { ... },
    },
    displayOrder = { "2", "1", ... },                  -- newest at index 1
    nextId = 3,
}
```

key shape `"i:<itemID>"` matches baganator's portable identifier. bonus/enchant ids are not part of the key — the same item at different upgrade ranks collapses into one pin.

the **All Items** category is not stored. it's everything in bags whose itemID has no entry in any `category.addedItems`.

## interactions

| gesture | effect |
|---|---|
| press `B` / click bag micromenu | toggle the bag (hooks `OpenBackpack`/`CloseBackpack`; state stored as `plugin._isOpen`) |
| press `Esc` | close the bag (`UISpecialFrames` membership) |
| drag the title bar | move the bag; position saved on drop to `OrbitDB.AccountSettings.BagPosition` |
| left-click-drag in empty workspace | marquee a new category region; snaps to grid; release creates if region doesn't overlap an existing one |
| left-click an item slot | pickup (`C_Container.PickupContainerItem`); combat-guarded |
| right-click an item slot | use item (`C_Container.UseContainerItem`); combat-guarded |
| shift + right-click an item slot | open item menu: pin to existing category / unpin |
| modifier + click an item slot | falls through to `HandleModifiedItemClick` (chat link, dressing room, etc.) |
| drag an item onto a category region | pin the item to that category (via `OnRegionReceiveDrag`) |
| right-click a category region | open category menu: rename / color (8-color palette submenu) / delete |
| left-click a category region while holding an item on cursor | shortcut: same as drag-drop pin |

## event surface

| event | response |
|---|---|
| `BAG_UPDATE_DELAYED` | full refresh — debounced burst event from wow |
| `BAG_CONTAINER_UPDATE` | slot count changed (bag swapped) — full refresh |
| `ITEM_LOCK_CHANGED` | per-slot lock visual — refresh |
| `GET_ITEM_INFO_RECEIVED` | async info backstop — refresh |
| `INVENTORY_SEARCH_UPDATE` | filter changed — refresh, filtered items dim to 30% alpha |
| `ORBIT_BAG_CATEGORIES_CHANGED` | fired by `BagCategoryStore` on every crud — full refresh |

bank/warband events (`BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED`) belong to a future `bag-bank` plugin and are not subscribed here.

## secret-value posture

- `C_Container.GetContainerItemInfo` returns (quality, stackCount, itemLink, isFiltered, itemID, etc.) are non-secret in 12.0.5. plain arithmetic and comparison are fine.
- **`C_Container.GetContainerItemCooldown`** returns `(startTime, duration)` in the conditional-secret family — pass directly to `CooldownFrame_Set`, never compute `expirationTime - GetTime()` in lua. v1 doesn't render slot cooldowns; when it does, route through the cooldown frame.
- run `/wow-secrets` before adding any new c-api call; classifications drift between patches.

## decisions made

| decision | rationale |
|---|---|
| **no edit-mode integration** | the bag is too large to manage through edit mode. dragging the title bar persists position to `AccountSettings.BagPosition`. |
| **40px fixed cell size** | matches the user's request; no per-user sizing in v1. settings module exists for future use. |
| **All Items at the bottom, no header** | matches the "this category does not show empty bag space, only all items" spec; visually distinct from explicit regions. |
| **categories stored with grid coords, not pixel coords** | survives any future cell-size change without migration; the grid is the contract. |
| **header floats above the region (negative y)** | keeps the marqueed rectangle's cells aligned exactly to the grid the user drew. adjacent regions without a row gap will have header overlap — accepted tradeoff. |
| **overlap prevention on create** | `RegionOverlapsAny` check on `EndMarquee`; overlapping marquees are dropped silently. |
| **right-click for region crud, not modal dialogs** | direct manipulation everywhere; no settings panel reaches a category. |
| **insecure frames + parented to `UIParent`** | bag interaction (`UseContainerItem`, `PickupContainerItem`) is already protected at the c entry point. wrapping it in secure templates just creates taint vectors. |
| **blizzard suppression via `NativeFrame:Park`** | parks the combined bag + 13 individual container frames; overrides `Is*BagOpen` queries so blizzard's `ToggleBackpack_Combined` correctly toggles our frame instead of trying to open parked frames. |

## what's deferred

- **resize / move existing categories** — v1 lets you create and delete; resize is a v2 feature (drag edges).
- **drag-reorder items inside a category** — items currently fill in bag-scan order. spatial within-region arrangement is v2.
- **overflow handling** — items pinned to a category beyond its cell capacity are not rendered. v2: spill into the All Items pool or auto-grow the region.
- **bank / warband / reagent bank** — separate `bag-bank` plugin (different event surface, different apis).
- **search bar dimming** — filtered items dim to 30% alpha, but the search box itself doesn't get focus when opening the bag. v2: auto-focus on open.
- **smart category suggestions** — auto-grouping by item class/subclass is deferred; users manually marquee regions in v1.
- **freeform color picker** — v1 uses an 8-color curated palette via right-click submenu. `LibOrbitColorPicker-1.0` integration would let users pick any color.
- **persisted column count / cell size** — `BagSettings.lua` defines the schema but `BagGrid` uses hardcoded 40px / 16 cols. wire settings through when configurability is needed.
- **cooldown overlays / new-item glow / upgrade arrow / junk coin** — none rendered in v1; the `ContainerFrameItemButtonTemplate` provides hooks for them.

## extending

every change must remain localization-lint clean: `python .scripts/check-localization.py`. all user-facing strings live in `Orbit/Localization/Domains/Plugins.lua` (`PLU_BAGS_*` prefix) or `PluginManager.lua` (`PLG_NAME_BAG`).
