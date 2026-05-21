local addonName, addonTable = ...
local LSM = LibStub("LibSharedMedia-3.0")

-- Media Registration

local mediaPath = "Interface\\AddOns\\" .. addonName .. "\\Core\\assets\\"

-- MediaMenu reads OwnedMedia to bucket Orbit-bundled assets above the user's other LSM media.
Orbit.OwnedMedia = {}
local function Reg(mediaType, name, path)
    LSM:Register(mediaType, name, path)
    Orbit.OwnedMedia[name] = true
end

-- Fonts
Reg("font", "PT Sans Narrow", mediaPath .. "Fonts\\PTSansNarrow.ttf")
Reg("font", "Luckiest Guy", mediaPath .. "Fonts\\LuckiestGuy-Regular.ttf")
Reg("font", "Barlow Condensed Black", mediaPath .. "Fonts\\BarlowCondensed-Black.ttf")
Reg("font", "Barlow Condensed Bold", mediaPath .. "Fonts\\BarlowCondensed-Bold.ttf")
Reg("font", "Barlow Condensed ExtraBold", mediaPath .. "Fonts\\BarlowCondensed-ExtraBold.ttf")
Reg("font", "Black Han Sans", mediaPath .. "Fonts\\BlackHanSans-Regular.ttf")
Reg("font", "Fira Sans Extra Condensed Bold", mediaPath .. "Fonts\\FiraSansExtraCondensed-Bold.ttf")
Reg("font", "Fira Sans Extra Condensed SemiBold", mediaPath .. "Fonts\\FiraSansExtraCondensed-SemiBold.ttf")
Reg("font", "Roboto Condensed ExtraBold", mediaPath .. "Fonts\\RobotoCondensed-ExtraBold.ttf")
Reg("font", "Roboto Condensed SemiBold", mediaPath .. "Fonts\\RobotoCondensed-SemiBold.ttf")
Reg("font", "Changa One", mediaPath .. "Fonts\\ChangaOne-Regular.ttf")
Reg("font", "Expressway", mediaPath .. "Fonts\\expressway.ttf")

-- Statusbars — substrings "overlay" / "absorb" route to dedicated controls (TexturePicker); Orbit Absorb / Honeycomb Absorb MUST tile (Skin.lua's TILING_FILLS) or their pattern shears.
Reg("statusbar", "Orbit Absorb", mediaPath .. "Statusbar\\orbit-absorb.tga")
Reg("statusbar", "Orbit Honeycomb Absorb", mediaPath .. "Statusbar\\orbit-honeycomb.tga")
Reg("statusbar", "Orbit Solid", mediaPath .. "Statusbar\\orbit-solid.tga")
Reg("statusbar", "Orbit Gradient Left-Right", mediaPath .. "Statusbar\\orbit-gradient-lr.tga")
Reg("statusbar", "Orbit Gradient Right-Left", mediaPath .. "Statusbar\\orbit-gradient-rl.tga")
Reg("statusbar", "Orbit Gradient Bottom-Top", mediaPath .. "Statusbar\\orbit-gradient-bt.tga")
Reg("statusbar", "Orbit Gradient Top-Bottom", mediaPath .. "Statusbar\\orbit-gradient-tb.tga")

-- Overlays painted over coloured fill; Skin.lua's OVERLAY_RENDER maps each to blend/tile. "Overlay" suffix routes them to the Overlay Texture control.
Reg("statusbar", "Orbit Gloss Overlay", mediaPath .. "Statusbar\\orbit-gloss.tga")
Reg("statusbar", "Orbit Frost Overlay", mediaPath .. "Statusbar\\orbit-frost.tga")
Reg("statusbar", "Orbit Galaxy Overlay", mediaPath .. "Statusbar\\orbit-galaxy.tga")
Reg("statusbar", "Orbit Starfield Overlay", mediaPath .. "Statusbar\\orbit-starfield.tga")

-- Borders (none currently registered)