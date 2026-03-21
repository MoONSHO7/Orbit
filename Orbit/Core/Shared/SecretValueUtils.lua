-- [ SECRET VALUE UTILS ]---------------------------------------------------------------------------
-- Centralised helpers for WoW 12.0 secret-value APIs (UnitHealthPercent, UnitPowerPercent, etc.).
-- pcall required per coding-rules.md §pcall Policy.
local Orbit = Orbit
local CurveConstants = CurveConstants
local CanUseUnitPowerPercent = (type(UnitPowerPercent) == "function" and CurveConstants and CurveConstants.ScaleTo100)
local function SafeUnitPowerPercent(unit, resource)
    if not CanUseUnitPowerPercent then return nil end
    local ok, pct = pcall(UnitPowerPercent, unit, resource, false, CurveConstants.ScaleTo100)
    return (ok and pct) or nil
end
Orbit.SecretValueUtils = { CanUseUnitPowerPercent = CanUseUnitPowerPercent, SafeUnitPowerPercent = SafeUnitPowerPercent }
