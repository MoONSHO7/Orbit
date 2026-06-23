local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin

-- [ MEDIA VALIDATION ]-------------------------------------------------------------------------------
-- C_UIFileAsset (12.0.7+) flags media whose LSM registration outlives the file on disk. Absent API → assume valid, so this never regresses clients without it.
function Skin:IsMediaFileValid(path)
    if not path or path == "" then return false end
    if C_UIFileAsset and C_UIFileAsset.IsKnownFile then
        return C_UIFileAsset.IsKnownFile(path)
    end
    return true
end
