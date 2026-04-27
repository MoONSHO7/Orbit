-- [ CLICK OUTSIDE CATCHER ]--------------------------------------------------------------------------
local _, Orbit = ...
local Constants = Orbit.Constants
local Catcher = {}
Orbit.Spotlight.UI.ClickOutsideCatcher = Catcher

-- [ CREATE ]-----------------------------------------------------------------------------------------
-- Full-screen invisible frame behind the Spotlight. Any mouse-down outside the Spotlight hits this first.
function Catcher:Create(onClick)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(UIParent)
    f:EnableMouse(true)
    f:SetFrameStrata(Constants.Strata.Dialog)
    f:SetFrameLevel(1)
    f:Hide()
    f:SetScript("OnMouseDown", onClick)
    return f
end
