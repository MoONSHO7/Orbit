local addonName, addonTable = ...
local LSM = LibStub("LibSharedMedia-3.0")

-- Media Registration
-- We use the addonName to dynamically build the path, ensuring it works
-- regardless of what the addon folder is named (Orbit, Orbit_m7, etc.)

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

-- Statusbars
