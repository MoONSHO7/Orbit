-- [ TOOLTIP STRATA ]-------------------------------------------------------------------------------
-- OrbitCanvasModeDialog and OrbitSettingsDialog live in TOOLTIP strata at frame level 200 so they
-- render above edit-mode anchor lines (also TOOLTIP strata). GameTooltip defaults to a low frame
-- level in the same strata, so without this hook it gets buried under the dialogs.

local TOOLTIP_LEVEL = 500

GameTooltip:HookScript("OnShow", function(self)
    self:SetFrameLevel(TOOLTIP_LEVEL)
end)
