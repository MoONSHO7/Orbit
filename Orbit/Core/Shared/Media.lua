local addonName, addonTable = ...
local LSM = LibStub("LibSharedMedia-3.0")

-- Media Registration

local mediaPath = "Interface\\AddOns\\" .. addonName .. "\\Core\\assets\\"

-- Fonts
LSM:Register("font", "PT Sans Narrow", mediaPath .. "Fonts\\PTSansNarrow.ttf")
LSM:Register("font", "Luckiest Guy", mediaPath .. "Fonts\\LuckiestGuy-Regular.ttf")
LSM:Register("font", "Barlow Condensed Black", mediaPath .. "Fonts\\BarlowCondensed-Black.ttf")
LSM:Register("font", "Barlow Condensed Bold", mediaPath .. "Fonts\\BarlowCondensed-Bold.ttf")
LSM:Register("font", "Barlow Condensed ExtraBold", mediaPath .. "Fonts\\BarlowCondensed-ExtraBold.ttf")
LSM:Register("font", "Black Han Sans", mediaPath .. "Fonts\\BlackHanSans-Regular.ttf")
LSM:Register("font", "Fira Sans Extra Condensed Bold", mediaPath .. "Fonts\\FiraSansExtraCondensed-Bold.ttf")
LSM:Register("font", "Fira Sans Extra Condensed SemiBold", mediaPath .. "Fonts\\FiraSansExtraCondensed-SemiBold.ttf")
LSM:Register("font", "Roboto Condensed ExtraBold", mediaPath .. "Fonts\\RobotoCondensed-ExtraBold.ttf")
LSM:Register("font", "Roboto Condensed SemiBold", mediaPath .. "Fonts\\RobotoCondensed-SemiBold.ttf")
LSM:Register("font", "Expressway", mediaPath .. "Fonts\\expressway.ttf")

-- Statusbars
LSM:Register("statusbar", "Orbit Absorb", mediaPath .. "Statusbar\\orbit-absorb.tga")
LSM:Register("statusbar", "Orbit Absorb Glossy", mediaPath .. "Statusbar\\orbit-absorb-glossy.tga")
LSM:Register("statusbar", "Orbit Absorb Darkened", mediaPath .. "Statusbar\\orbit-absorb-darkened.tga")
LSM:Register("statusbar", "Orbit Solid", mediaPath .. "Statusbar\\orbit-solid.tga")
LSM:Register("statusbar", "Orbit Gradient Left-Right", mediaPath .. "Statusbar\\orbit-gradient-lr.tga")
LSM:Register("statusbar", "Orbit Gradient Right-Left", mediaPath .. "Statusbar\\orbit-gradient-rl.tga")
LSM:Register("statusbar", "Orbit Gradient Bottom-Top", mediaPath .. "Statusbar\\orbit-gradient-bt.tga")
LSM:Register("statusbar", "Orbit Gradient Top-Bottom", mediaPath .. "Statusbar\\orbit-gradient-tb.tga")

-- Static bar overlays. Painted to sit on top of a coloured fill; Skin.lua's OVERLAY_RENDER
-- maps each name to its blend mode + alpha. "Overlay" in the name is load-bearing: texture
-- pickers partition statusbar media by whether the name contains "overlay" (case-insensitive)
-- -- bar-fill pickers list non-overlays, the Overlay Texture control lists overlays.
LSM:Register("statusbar", "Orbit Gloss Overlay", mediaPath .. "Statusbar\\orbit-gloss.tga")
LSM:Register("statusbar", "Orbit Frost Overlay", mediaPath .. "Statusbar\\orbit-frost.tga")

-- Borders
-- LSM:Register("border", "Dummy", mediaPath .. "Borders\\Dummy.tga")