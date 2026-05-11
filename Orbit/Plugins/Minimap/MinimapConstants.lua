-- [ MINIMAP CONSTANTS ]------------------------------------------------------------------------------
-- Single source of truth for constants shared across Minimap*.lua files.

---@type Orbit
local Orbit = Orbit
local SYSTEM_ID = "Orbit_Minimap"

Orbit.MinimapConstants = {
    SYSTEM_ID = SYSTEM_ID,
    DEFAULT_SIZE = 220,
    DEFAULT_TEXT_SIZE = 12,
    BORDER_COLOR = { r = 0, g = 0, b = 0, a = 1 },

    CLOCK_UPDATE_INTERVAL = 1,
    COORDS_UPDATE_INTERVAL = 0.1,

    ZOOM_BUTTON_W = 17,
    ZOOM_BUTTON_IN_H = 17,
    ZOOM_BUTTON_OUT_H = 9,
    ZOOM_FADE_IN = 0.15,
    ZOOM_FADE_OUT = 0.3,

    MISSIONS_BASE_SIZE = 36,

    -- Shape. MASK_ROUND uses our shipped high-res Circle.tga (filled white disk) so the
    -- minimap surface, HybridMinimap canvas, bg backdrop, and round border all clip to the same
    -- pixel-identical circle edge — no visible mismatch between layers.
    MASK_SQUARE = "Interface\\BUTTONS\\WHITE8x8",
    MASK_ROUND = "Interface\\AddOns\\Orbit\\Core\\assets\\Circle",
    MASK_HUD = "Interface\\AddOns\\Orbit\\Core\\assets\\splatter",

    -- Ring sizing only — no per-ring mask. The Minimap render surface uses TempPortraitAlphaMask
    -- so its visible terrain fills most of its bounds; the atlas-based mask experiment produced a
    -- dark border in the area Blizzard's C++ Minimap renders outside the mask alpha (the mask
    -- clips terrain but doesn't punch alpha-transparent — there's no API to flip that).
    -- ratioX/ratioY scale the atlas relative to the minimap diameter. padding adds absolute pixels to
    -- the rendered size; offsetX/offsetY shift the centered anchor. Blizzard's Minimap.xml anchors
    -- ui-hud-minimap-frame at 215x226 CENTER on a 198x198 Minimap, so the cardinal spike
    -- decorations hang outside the round map onto the game world. No mask atlas needed.
    BORDER_RING_OPTIONS = {
        blizzard = { texture = "Interface\\AddOns\\Orbit\\Core\\assets\\minimap2", ratioX = 1,       ratioY = 1,         sublevel = 7, rotatable = true, mask = "Interface\\AddOns\\Orbit\\Core\\assets\\minimap" },
        round    = { fill = true },
        void     = { atlas   = "wowlabs_minimapvoid-ring-single",               ratioX = 1,         ratioY = 1,         sublevel = 7, fill = true, padding = 2, offsetX = -1, offsetY = 1, spinSeconds = 60, pulse = { min = 0.8, max = 1.0, period = 4 } },
    },
}
