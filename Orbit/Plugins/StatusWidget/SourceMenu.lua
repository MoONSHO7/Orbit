---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ SOURCE MENU ]------------------------------------------------------------------------------------
local MENU_TAG = "ORBIT_STATUSBARV2_SOURCE"

-- The simple (non-currency) sources, shared by both submenus.
local SIMPLE_SOURCES = {
    { value = "xp",    label = L.PLU_XP_NAME },
    { value = "rep",   label = L.PLU_SB_V2_SOURCE_REP },
    { value = "honor", label = L.PLU_HONOR_NAME },
}

function Plugin:_AddCurrencySubmenu(parent, sourceKey, currencyKey)
    local sub = parent:CreateButton(L.PLU_SB_V2_FILL_CURRENCY)
    local currencies = self:_EligibleCurrencies()
    if #currencies == 0 then
        sub:CreateTitle(L.PLU_SB_V2_NO_CURRENCY)
        return
    end
    for _, currency in ipairs(currencies) do
        local id = currency.id
        sub:CreateRadio(currency.name,
            function() return self:GetSetting(self.system, sourceKey) == "currency"
                          and self:GetSetting(self.system, currencyKey) == id end,
            function()
                self:SetSetting(self.system, sourceKey, "currency")
                self:SetSetting(self.system, currencyKey, id)
                self:UpdateBar()
            end)
    end
end

function Plugin:_AddSourceSubmenu(root, title, sourceKey, currencyKey, headValue, headLabel)
    local submenu = root:CreateButton(title)
    submenu:CreateRadio(headLabel,
        function() return (self:GetSetting(self.system, sourceKey) or headValue) == headValue end,
        function() self:SetSetting(self.system, sourceKey, headValue); self:UpdateBar() end)
    for _, src in ipairs(SIMPLE_SOURCES) do
        local value = src.value
        submenu:CreateRadio(src.label,
            function() return self:GetSetting(self.system, sourceKey) == value end,
            function() self:SetSetting(self.system, sourceKey, value); self:UpdateBar() end)
    end
    -- Housing only appears while a house is tracked (matches Blizzard surfacing the House Favor bar only then).
    if self:_HousingTracked() then
        submenu:CreateRadio(L.PLU_SB_V2_SOURCE_HOUSE,
            function() return self:GetSetting(self.system, sourceKey) == "house" end,
            function() self:SetSetting(self.system, sourceKey, "house"); self:UpdateBar() end)
    end
    self:_AddCurrencySubmenu(submenu, sourceKey, currencyKey)
end

function Plugin:OpenSourceMenu()
    if not self.frame or Orbit:IsEditMode() then return end
    MenuUtil.CreateContextMenu(self.frame, function(_, root)
        root:SetTag(MENU_TAG)
        root:CreateTitle(L.PLU_STATUS_BAR_V2_NAME)
        self:_AddSourceSubmenu(root, L.PLU_SB_V2_PRIMARY_SOURCE,   "PrimarySource",   "PrimaryCurrencyID",   "auto", L.PLU_SB_V2_FILL_AUTO)
        self:_AddSourceSubmenu(root, L.PLU_SB_V2_SECONDARY_SOURCE, "SecondarySource", "SecondaryCurrencyID", "none", L.CMN_NONE)
    end)
end
