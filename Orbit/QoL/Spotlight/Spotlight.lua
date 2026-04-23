-- [ SPOTLIGHT ENTRY ]-------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

-- [ NAMESPACE ]-------------------------------------------------------------------------------------
Orbit.Spotlight = {}
local Spotlight = Orbit.Spotlight
Spotlight.Search = {}
Spotlight.Index = { Sources = {} }
Spotlight.UI = {}
Spotlight._active = false

-- [ KINDS ]-----------------------------------------------------------------------------------------
-- Canonical list of searchable source kinds. Every consumer (config panel, result row kind label,
-- enabled-kinds resolver, category token matcher) iterates this list so adding a new source only
-- requires adding one row here (and the matching Index/Sources/<Name>.lua).
Spotlight.Kinds = {
    { kind = "bags",        settingKey = "Bags",        labelKey = "PLU_SPT_SRC_BAGS" },
    { kind = "equipped",    settingKey = "Equipped",    labelKey = "PLU_SPT_SRC_EQUIPPED" },
    { kind = "spellbook",   settingKey = "Spellbook",   labelKey = "PLU_SPT_SRC_SPELLBOOK" },
    { kind = "toys",        settingKey = "Toys",        labelKey = "PLU_SPT_SRC_TOYS" },
    { kind = "mounts",      settingKey = "Mounts",      labelKey = "PLU_SPT_SRC_MOUNTS" },
    { kind = "pets",        settingKey = "Pets",        labelKey = "PLU_SPT_SRC_PETS" },
    { kind = "heirlooms",   settingKey = "Heirlooms",   labelKey = "PLU_SPT_SRC_HEIRLOOMS" },
    { kind = "professions", settingKey = "Professions", labelKey = "PLU_SPT_SRC_PROFESSIONS" },
    { kind = "currencies",  settingKey = "Currencies",  labelKey = "PLU_SPT_SRC_CURRENCIES" },
    { kind = "macros",      settingKey = "Macros",      labelKey = "PLU_SPT_SRC_MACROS" },
    { kind = "questitems",  settingKey = "QuestItems",  labelKey = "PLU_SPT_SRC_QUESTITEMS" },
}

-- [ BINDING GLOBALS ]-------------------------------------------------------------------------------
_G.BINDING_HEADER_ORBIT = _G.BINDING_HEADER_ORBIT or "Orbit"
_G.BINDING_NAME_ORBIT_SPOTLIGHT_TOGGLE = L.PLU_SPT_BINDING_NAME

-- [ PUBLIC API ]------------------------------------------------------------------------------------
function Spotlight:Toggle()
    if InCombatLockdown() then
        Orbit:Print(L.PLU_SPT_MSG_COMBAT)
        return
    end
    if not self._active then return end
    self.UI.SpotlightFrame:Toggle()
end

function Spotlight:Enable()
    if self._active then return end
    self._active = true
    self.Index.IndexManager:RegisterEvents()
end

function Spotlight:Disable()
    if not self._active then return end
    self._active = false
    self.Index.IndexManager:UnregisterEvents()
    if self.UI.SpotlightFrame._frame and self.UI.SpotlightFrame._frame:IsShown() then
        self.UI.SpotlightFrame:Close()
    end
end

-- [ DIAGNOSTIC ]------------------------------------------------------------------------------------
-- /run Orbit.Spotlight:Debug()        — counts per source
-- /run Orbit.Spotlight:Dump("currencies")  — first 20 entries' lowerName so you can see what tags were folded in
function Spotlight:Debug()
    local IM = self.Index.IndexManager
    IM:InvalidateAll()
    IM:Rebuild()
    local counts = IM:GetLastCounts()
    Orbit:Print("Spotlight index — master size: " .. #IM:GetMaster())
    for name, count in pairs(counts) do Orbit:Print("  " .. name .. ": " .. count) end
end

function Spotlight:Dump(kind, limit)
    limit = limit or 20
    local IM = self.Index.IndexManager
    IM:InvalidateAll()
    IM:Rebuild()
    Orbit:Print("Spotlight dump (" .. kind .. "):")
    local shown = 0
    for _, entry in ipairs(IM:GetMaster()) do
        if entry.kind == kind then
            shown = shown + 1
            if shown > limit then break end
            Orbit:Print(string.format("  [%s] %s", entry.name, entry.lowerName))
        end
    end
    if shown == 0 then Orbit:Print("  (no entries)") end
end

-- [ AUTO-ENABLE ON LOGIN ]--------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
        if Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.Spotlight then
            Spotlight:Enable()
        end
    end)
    loader:UnregisterAllEvents()
end)
