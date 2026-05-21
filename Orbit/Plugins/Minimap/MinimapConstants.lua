-- [ MINIMAP CONSTANTS ]------------------------------------------------------------------------------
-- Single source of truth for constants shared across Minimap*.lua files.

---@type Orbit
local Orbit = Orbit
local SYSTEM_ID = "Orbit_Minimap"

Orbit.MinimapConstants = {
    SYSTEM_ID = SYSTEM_ID,
    DEFAULT_SIZE = 220,
    MIN_SIZE = 100,
    MAX_SIZE = 400,
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

    -- MASK_ROUND clips minimap + HybridMinimap + bg + border to the same pixel-identical circle (Orbit_Circle.tga).
    MASK_SQUARE = "Interface\\BUTTONS\\WHITE8x8",
    MASK_ROUND = "Interface\\AddOns\\Orbit\\Core\\assets\\Minimap\\Orbit_Circle",
    MASK_HUD = "Interface\\AddOns\\Orbit\\Core\\assets\\Minimap\\Orbit_Splatter",

    -- ratioX/ratioY scale the atlas to minimap diameter; padding/offset shift the centered anchor; Blizzard's Minimap.xml anchors at 215x226 CENTER on 198x198, so cardinal spikes hang outside the round map.
    BORDER_RING_OPTIONS = {
        blizzard    = { texture = "Interface\\AddOns\\Orbit\\Core\\assets\\Minimap\\Orbit_BlizzMinimapBorder", ratioX = 1, ratioY = 1, sublevel = 7, rotatable = true, mask = "Interface\\AddOns\\Orbit\\Core\\assets\\Minimap\\Orbit_BlizzMinimap" },
        round       = { fill = true },
        fadedcircle = { mask = "Interface\\AddOns\\Orbit\\Core\\assets\\Minimap\\Orbit_CircleFade" },
        void        = { atlas   = "wowlabs_minimapvoid-ring-single",               ratioX = 1,         ratioY = 1,         sublevel = 7, fill = true, padding = 2, offsetX = -1, offsetY = 1, spinSeconds = 60, pulse = { min = 0.8, max = 1.0, period = 4 } },
    },
}
