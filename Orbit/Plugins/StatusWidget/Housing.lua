---@type Orbit
local Orbit = Orbit
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ HOUSE FAVOR SOURCE ]-----------------------------------------------------------------------------
-- WoW 12.0's House Favor status bar (StatusTrackingBarInfo.BarsEnum.HouseFavor). GetCurrentHouseLevelFavor is a request, not a getter — the favor arrives async via HOUSE_LEVEL_FAVOR_UPDATED — so cache the latest payload (_houseFavor) and let HousingRecord rebuild from it (mirrors Blizzard's HouseFavorBarMixin).
local HOUSE_EVENTS = { "HOUSE_LEVEL_FAVOR_UPDATED", "TRACKED_HOUSE_CHANGED", "PLAYER_ENTERING_WORLD" }

-- A WOWGUID when the player is tracking a house, else nil/"" — the gate Blizzard's CanShowBar(HouseFavor) uses.
function Plugin:_HousingTracked()
    local C = C_Housing
    if not (C and C.GetTrackedHouseGuid) then return false end
    local guid = C.GetTrackedHouseGuid()
    return guid ~= nil and guid ~= ""
end

-- Auto prefers housing only once a favor payload is cached, so the auto fill never blanks while the request is in flight.
function Plugin:_HousingReady()
    return self._houseFavor ~= nil and self:_HousingTracked()
end

-- The answer to this request arrives on HOUSE_LEVEL_FAVOR_UPDATED.
function Plugin:_RequestHouseFavor()
    local C = C_Housing
    if C and C.GetCurrentHouseLevelFavor and self:_HousingTracked() then
        C.GetCurrentHouseLevelFavor(C.GetTrackedHouseGuid())
    end
end

function Plugin:SetupHousing()
    if not C_Housing then return end   -- housing system absent on this client: no source to track
    local f = CreateFrame("Frame")
    for _, e in ipairs(HOUSE_EVENTS) do f:RegisterEvent(e) end
    f:SetScript("OnEvent", function(_, event, ...) self:_OnHouseEvent(event, ...) end)
    self._houseFrame = f
    self:_RequestHouseFavor()
end

function Plugin:_OnHouseEvent(event, ...)
    if event == "HOUSE_LEVEL_FAVOR_UPDATED" then
        local payload = ...
        if payload and payload.houseGUID == C_Housing.GetTrackedHouseGuid() then
            self._houseFavor = payload
            if self.frame then self:UpdateBar() end
        end
    elseif event == "TRACKED_HOUSE_CHANGED" then
        self._houseFavor = nil   -- a different (or no) house: the cached favor is for the old one
        self:_RequestHouseFavor()
        if self.frame then self:UpdateBar() end
    else   -- PLAYER_ENTERING_WORLD: refresh after a loading screen, but keep the cache so an auto-housing orb doesn't blank on every zone change
        self:_RequestHouseFavor()
    end
end
