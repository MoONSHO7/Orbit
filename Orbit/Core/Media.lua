local addonName, addonTable = ...
local LSM = LibStub("LibSharedMedia-3.0")

-- Media Registration
-- We use the addonName to dynamically build the path, ensuring it works
-- regardless of what the addon folder is named (Orbit, Orbit_m7, etc.)

local mediaPath = "Interface\\AddOns\\" .. addonName .. "\\Core\\assets\\"

-- Fonts
LSM:Register("font", "Archivo Narrow Bold", mediaPath .. "Fonts\\ArchivoNarrow-Bold.ttf")
LSM:Register("font", "PT Sans Narrow", mediaPath .. "Fonts\\PTSansNarrow.ttf")

-- Statusbars
