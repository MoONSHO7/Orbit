-- [ LOCALIZATION - BOOT ] ---------------------------------------------------------------------------
-- Loaded before Core/Init.lua so plugin schema `label = L.KEY` resolves at table-construction time.
local _, Orbit = ...

-- /run Orbit.DEBUG_LOCALIZATION = true → logs reads of undefined L keys; off by default (__index fires only when missing).
Orbit.DEBUG_LOCALIZATION = false

Orbit.L = setmetatable({}, {
    __index = function(_, k)
        if Orbit.DEBUG_LOCALIZATION then
            geterrorhandler()(("Orbit.L.%s is undefined"):format(tostring(k)))
        end
        return nil
    end,
})

-- [ LOCALIZATION MODULE ] ---------------------------------------------------------------------------
Orbit.Localization = {}
Orbit.Localization.SUPPORTED_LOCALES = { "enUS", "deDE", "frFR", "esES", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
Orbit.Localization._domains = {}

local function ResolveActiveLocale()
    local override = OrbitDB and OrbitDB.AccountSettings and OrbitDB.AccountSettings.LocaleOverride
    if override then
        for _, code in ipairs(Orbit.Localization.SUPPORTED_LOCALES) do
            if code == override then return override, true end
        end
    end
    return GetLocale(), false
end

Orbit.Localization.activeLocale, Orbit.Localization.localeIsOverridden = ResolveActiveLocale()

local function CountPlaceholders(s)
    local stripped = s:gsub("%%%%", "")
    local _, count = stripped:gsub("%%", "")
    return count
end

local function MergeDomain(LOCALE_STRINGS, domainName, isRebuild)
    LOCALE_STRINGS.enGB = LOCALE_STRINGS.enGB or LOCALE_STRINGS.enUS
    LOCALE_STRINGS.esMX = LOCALE_STRINGS.esMX or LOCALE_STRINGS.esES

    local enUS = LOCALE_STRINGS.enUS
    local resolved = LOCALE_STRINGS[Orbit.Localization.activeLocale] or enUS

    for k, enValue in pairs(enUS) do
        if not isRebuild and rawget(Orbit.L, k) ~= nil then
            geterrorhandler()(("Orbit.L collision: key %q from domain %q already defined"):format(k, domainName))
        else
            local value = resolved[k] or enValue
            if k:sub(-2) == "_F" and value ~= enValue then
                if CountPlaceholders(value) ~= CountPlaceholders(enValue) then
                    geterrorhandler()(("Orbit.L format string mismatch: %q in %s has a different placeholder count than enUS; falling back"):format(k, Orbit.Localization.activeLocale))
                    value = enValue
                end
            end
            rawset(Orbit.L, k, value)
        end
    end
end

function Orbit.Localization.Install(LOCALE_STRINGS, domainName)
    table.insert(Orbit.Localization._domains, { strings = LOCALE_STRINGS, name = domainName })
    MergeDomain(LOCALE_STRINGS, domainName, false)
end

-- Re-resolves activeLocale from OrbitDB and re-merges every registered domain.
function Orbit.Localization.Rebuild()
    Orbit.Localization.activeLocale, Orbit.Localization.localeIsOverridden = ResolveActiveLocale()
    for _, d in ipairs(Orbit.Localization._domains) do
        MergeDomain(d.strings, d.name, true)
    end
    if Orbit.EventBus then Orbit.EventBus:Fire("ORBIT_LOCALE_REBUILT") end
end

-- ADDON_LOADED is the SavedVariables-guaranteed moment; rebuild if the override wasn't visible at file-load.
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= "Orbit" then return end
    self:UnregisterEvent("ADDON_LOADED")
    local override = OrbitDB and OrbitDB.AccountSettings and OrbitDB.AccountSettings.LocaleOverride
    if override and override ~= Orbit.Localization.activeLocale then
        Orbit.Localization.Rebuild()
    end
end)
