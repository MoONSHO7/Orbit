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

-- Borders — edge-file format (256x32, 8-segment Blizzard layout). Grayscale (Orbit draws them at white
-- vertex = identity multiply, so the grayscale IS the look). Each is a crisp keyline-defined metal
-- cross-section (black silhouette edge + body) modelled on ls_Borders. Thickness via Border Edge Size.
Reg("border", "Orbit Silver", mediaPath .. "Border\\orbit-edge-silver.tga")
Reg("border", "Orbit Steel", mediaPath .. "Border\\orbit-edge-steel.tga")
Reg("border", "Orbit Bold", mediaPath .. "Border\\orbit-edge-bold.tga")
Reg("border", "Orbit Notch", mediaPath .. "Border\\orbit-edge-notch.tga")
Reg("border", "Orbit Groove", mediaPath .. "Border\\orbit-edge-groove.tga")
Reg("border", "Orbit Ornate", mediaPath .. "Border\\orbit-edge-ornate.tga")
Reg("border", "Orbit Glow", mediaPath .. "Border\\orbit-edge-glow.tga")
-- Decorative-corner borders (ornament + a matching edge).
Reg("border", "Orbit Spike", mediaPath .. "Border\\orbit-edge-spike.tga")
Reg("border", "Orbit Bracket", mediaPath .. "Border\\orbit-edge-bracket.tga")
Reg("border", "Orbit Bolt", mediaPath .. "Border\\orbit-edge-bolt.tga")
Reg("border", "Orbit Arrow", mediaPath .. "Border\\orbit-edge-arrow.tga")
Reg("border", "Orbit Gem", mediaPath .. "Border\\orbit-edge-gem.tga")
Reg("border", "Orbit Flare", mediaPath .. "Border\\orbit-edge-flare.tga")
Reg("border", "Orbit Cross", mediaPath .. "Border\\orbit-edge-cross.tga")
Reg("border", "Orbit Anchor", mediaPath .. "Border\\orbit-edge-anchor.tga")
Reg("border", "Orbit Fan", mediaPath .. "Border\\orbit-edge-fan.tga")