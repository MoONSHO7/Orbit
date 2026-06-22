---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Bar v2")

-- [ SOURCE MENU ]------------------------------------------------------------------------------------
-- Right-click the orb → a menu to pick what it shows at rest (PrimarySource) and what it swaps to on
-- hover+Shift (SecondarySource). This menu is the sole UI for both — the bar refreshes live on selection.
-- The Currency entry breaks out into its own picker submenu (only currencies with a known cap, so the
-- radial fill is meaningful), and the chosen currency is stored per slot (PrimaryCurrencyID / SecondaryCurrencyID).
local MENU_TAG = "ORBIT_STATUSBARV2_SOURCE"

-- The simple (non-currency) sources, shared by both submenus.
local SIMPLE_SOURCES = {
    { value = "xp",    label = L.PLU_XP_NAME },
    { value = "rep",   label = L.PLU_SB_V2_SOURCE_REP },
    { value = "honor", label = L.PLU_HONOR_NAME },
}

-- The Currency picker: a nested submenu of known-cap currencies. Selecting one sets the slot's source to
-- "currency" and records its id; a currency is checked only when this slot is on currency AND id matches.
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

-- One source submenu bound to a setting key: the head entry (Auto for the primary, None for the secondary),
-- the simple sources, then the Currency picker. Selecting a radio writes the setting and refreshes the bar
-- (the secondary only changes the live display while hovered+Shift).
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
