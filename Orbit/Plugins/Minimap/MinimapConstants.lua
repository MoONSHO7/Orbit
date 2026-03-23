-- [ MINIMAP CONSTANTS ]-----------------------------------------------------------------------------
-- Single source of truth for constants shared across Minimap*.lua files.

---@type Orbit
local Orbit = Orbit
local SYSTEM_ID = "Orbit_Minimap"

Orbit.MinimapConstants = {
    SYSTEM_ID = SYSTEM_ID,
    DEFAULT_SIZE = 200,
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

    -- Shape
    MASK_SQUARE = "Interface\\BUTTONS\\WHITE8x8",
    MASK_ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    -- Circular ring drawn over the minimap when Shape = "round" (Blizzard atlas, tintable)
    BORDER_RING_ATLAS = "MinimapBorder",
}
