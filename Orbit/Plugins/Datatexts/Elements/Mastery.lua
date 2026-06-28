local _, Orbit = ...
local DT = Orbit.Datatexts
local NumericOrNil = Orbit.SecretValueUtils.NumericOrNil
local L = Orbit.L

DT.StatDatatext:New({
    name = "Mastery",
    nameKey = L.PLU_DT_MASTERY_NAME,
    titleKey = L.PLU_DT_MASTERY_TITLE,
    labelKey = L.PLU_DT_STAT_MASTERY_LABEL,
    ratingIndex = 26,
    getPercent = function()
        return NumericOrNil(GetMasteryEffect and GetMasteryEffect())
    end,
})
