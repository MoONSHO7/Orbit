-- [ CURRENCIES SOURCE ]------------------------------------------------------------------------------
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources

-- Currency rows open the currency tab; they are not "usable" actions.
local function OpenCurrencyTab()
    if not CharacterFrame then return end
    ToggleCharacter("TokenFrame")
end

local Currencies = {
    kind = "currencies",
    events = { "CURRENCY_DISPLAY_UPDATE" },
    persistent = false,
}
Sources.currencies = Currencies

-- Walk headers in reverse so earlier indices stay valid as later ones grow; restore originally-collapsed state at the end.
local function WithAllExpanded(fn)
    local originallyCollapsed = {}
    local headerNames = {}
    local size = C_CurrencyInfo.GetCurrencyListSize() or 0
    for i = size, 1, -1 do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader and not info.isHeaderExpanded then
            headerNames[info.name] = true
            C_CurrencyInfo.ExpandCurrencyList(i, true)
        end
    end
    fn()
    size = C_CurrencyInfo.GetCurrencyListSize() or 0
    for i = size, 1, -1 do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader and headerNames[info.name] then
            C_CurrencyInfo.ExpandCurrencyList(i, false)
        end
    end
end

function Currencies:Build()
    local entries = {}
    WithAllExpanded(function()
        local size = C_CurrencyInfo.GetCurrencyListSize() or 0
        local currentHeader
        for i = 1, size do
            local info = C_CurrencyInfo.GetCurrencyListInfo(i)
            if info and info.name and info.name ~= "" and not info.isTypeUnused then
                if info.isHeader then
                    -- Header is the expansion / category name (e.g. "The War Within"); propagate to children.
                    currentHeader = info.name
                else
                    local folded = Tokenize:Fold(info.name)
                    if currentHeader then folded = folded .. " " .. Tokenize:Fold(currentHeader) end
                    entries[#entries + 1] = {
                        kind = "currencies",
                        id = i,
                        name = info.name,
                        lowerName = folded,
                        icon = info.iconFileID,
                        count = info.quantity,
                        tooltipLink = C_CurrencyInfo.GetCurrencyListLink(i),
                        onClick = OpenCurrencyTab,
                    }
                end
            end
        end
    end)
    return entries
end
