local _, Orbit = ...
local DT = Orbit.Datatexts
local NumericOrNil = Orbit.SecretValueUtils.NumericOrNil
local L = Orbit.L

DT.StatDatatext:New({
    name = "Crit",
    nameKey = L.PLU_DT_CRIT_NAME,
    titleKey = L.PLU_DT_CRIT_TITLE,
    labelKey = L.PLU_DT_STAT_CRIT_LABEL,
    ratingIndex = 9,
    getPercent = function()
        return NumericOrNil(GetCritChance and GetCritChance()) or NumericOrNil(GetMeleeCritChance and GetMeleeCritChance())
    end,
})
