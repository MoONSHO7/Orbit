-- [ LOCALIZATION - BOOT ] ---------------------------------------------------------------------------
-- Seeds Orbit.L and provides Orbit.Localization.Install used by every domain file
-- under Domains/. Loaded before Core/Init.lua so plugin schema `label = L.KEY`
-- fields evaluated at table-construction time see a populated L.
local _, Orbit = ...

-- [ DEV DIAGNOSTIC ] --------------------------------------------------------------------------------
-- Set true via `/run Orbit.DEBUG_LOCALIZATION = true` to log every read of an
-- undefined L key. Off by default. The metatable is always installed but costs
-- nothing for resolved keys — __index only fires when the raw table has no entry.
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

-- Counts format specifiers in a string, treating %% as a literal.
local function CountPlaceholders(s)
    local stripped = s:gsub("%%%%", "")
    local _, count = stripped:gsub("%%", "")
    return count
end

-- Install merges a domain's resolved locale strings into Orbit.L with:
--   * alias resolution (enGB -> enUS, esMX -> esES fallback to enUS)
--   * per-key fallback to enUS so partial translations are valid
--   * cross-domain collision detection (fail loud, first-writer-wins)
--   * format string placeholder validation for _F suffix keys
function Orbit.Localization.Install(LOCALE_STRINGS, domainName)
    LOCALE_STRINGS.enGB = LOCALE_STRINGS.enGB or LOCALE_STRINGS.enUS
    LOCALE_STRINGS.esMX = LOCALE_STRINGS.esMX or LOCALE_STRINGS.esES

    local enUS = LOCALE_STRINGS.enUS
    local resolved = LOCALE_STRINGS[GetLocale()] or enUS

    for k, enValue in pairs(enUS) do
        if rawget(Orbit.L, k) ~= nil then
            geterrorhandler()(("Orbit.L collision: key %q from domain %q already defined"):format(k, domainName))
        else
            local value = resolved[k] or enValue
            if k:sub(-2) == "_F" and value ~= enValue then
                if CountPlaceholders(value) ~= CountPlaceholders(enValue) then
                    geterrorhandler()(("Orbit.L format string mismatch: %q in %s has a different placeholder count than enUS; falling back"):format(k, GetLocale()))
                    value = enValue
                end
            end
            rawset(Orbit.L, k, value)
        end
    end
end
