local _, Orbit = ...
local DT = Orbit.Datatexts
local GameTooltip = Orbit.Tooltip
local NumericOrNil = Orbit.SecretValueUtils.NumericOrNil
local L = Orbit.L

-- Combat-rating stat scaffold (Crit/Haste/Mastery/Versatility); per-stat getPercent owns the percent secret-guard, the rating-side guard lives here once.
DT.StatDatatext = {}

function DT.StatDatatext:New(cfg)
    local W = DT.BaseDatatext:New(cfg.name, cfg.nameKey)
    W.showPercentage = true

    function W:Update()
        local pct = cfg.getPercent()
        local rating = NumericOrNil(GetCombatRating(cfg.ratingIndex))
        if pct == self._lastPct and rating == self._lastRating and self.showPercentage == self._lastShowPct then return end
        self._lastPct, self._lastRating, self._lastShowPct = pct, rating, self.showPercentage
        local value
        if self.showPercentage then
            value = pct and string.format("|cffffffff%.2f%%|r", pct)
        else
            value = rating and string.format("|cffffffff%d|r", rating)
        end
        self:SetText(cfg.labelKey .. (value or ("|cffffffff" .. L.CMN_HIDDEN_VALUE .. "|r")))
    end

    function W:ShowTooltip()
        GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(cfg.titleKey, 1, 0.82, 0)

        local pct = cfg.getPercent()
        local rating = NumericOrNil(GetCombatRating(cfg.ratingIndex))
        GameTooltip:AddDoubleLine(L.PLU_DT_STAT_RATING, rating and string.format("%d", rating) or L.CMN_HIDDEN_VALUE, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.PLU_DT_STAT_PERCENT, pct and string.format("%.2f%%", pct) or L.CMN_HIDDEN_VALUE, 1, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end

    function W:Init()
        self:CreateFrame()

        self:SetClickFunc(function(datatext, button)
            if button == "LeftButton" then
                datatext.showPercentage = not datatext.showPercentage
                datatext:Update()
                if datatext.isHovered then datatext:UpdateTooltip() end
            end
        end)

        self:SetUpdateFunc(function() self:Update() end)
        self:RegisterUnitEvent("UNIT_STATS", "player")
        self:RegisterUnitEvent("UNIT_AURA", "player")
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        self:SetTooltipFunc(function() self:ShowTooltip() end)
        self.leftClickHint = L.PLU_DT_STAT_TOGGLE
        self:Register()
        self:Update()
    end

    W:Init()
    return W
end
