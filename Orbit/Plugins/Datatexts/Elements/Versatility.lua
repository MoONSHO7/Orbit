local _, Orbit = ...
local DT = Orbit.Datatexts
local NumericOrNil = Orbit.SecretValueUtils.NumericOrNil
local L = Orbit.L

local CR_VERSATILITY_DAMAGE_DONE = 29

DT.StatDatatext:New({
    name = "Versatility",
    nameKey = L.PLU_DT_VERSATILITY_NAME,
    titleKey = L.PLU_DT_VERSATILITY_TITLE,
    labelKey = L.PLU_DT_STAT_VERSATILITY_LABEL,
    ratingIndex = CR_VERSATILITY_DAMAGE_DONE,
    getPercent = function()
        -- Each operand needs NumericOrNil before the add; one secret operand poisons the sum.
        local bonus = NumericOrNil(GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE))
        local flat = NumericOrNil(GetVersatilityBonus and GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE))
        if not bonus and not flat then return nil end
        return (bonus or 0) + (flat or 0)
    end,
})
