local _, Orbit = ...
local DT = Orbit.Datatexts
local NumericOrNil = Orbit.SecretValueUtils.NumericOrNil
local L = Orbit.L

DT.StatDatatext:New({
    name = "Haste",
    nameKey = L.PLU_DT_HASTE_NAME,
    titleKey = L.PLU_DT_HASTE_TITLE,
    labelKey = L.PLU_DT_STAT_HASTE_LABEL,
    ratingIndex = 18,
    getPercent = function()
        return NumericOrNil(GetHaste and GetHaste()) or NumericOrNil(UnitSpellHaste and UnitSpellHaste("player"))
    end,
})
