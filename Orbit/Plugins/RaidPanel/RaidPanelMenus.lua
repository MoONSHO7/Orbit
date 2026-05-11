-- RaidPanelMenus.lua: MenuUtil dropdowns for Difficulty and Ping Restriction.

local _, Orbit = ...
local L = Orbit.L

local IsInRaid = IsInRaid
local IsInInstance = IsInInstance
local InCombatLockdown = InCombatLockdown

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local MENU_TAG = "ORBIT_RAIDPANEL_MENU"

-- [ MODULE ] ----------------------------------------------------------------------------------------
Orbit.RaidPanelMenus = {}
local Menus = Orbit.RaidPanelMenus

-- [ DIFFICULTY ] ------------------------------------------------------------------------------------
local function DifficultyDisabledReason()
    if IsInInstance() then return L.PLU_RAIDPANEL_DIFF_LOCK_INSTANCE end
    if InCombatLockdown() then return L.PLU_RAIDPANEL_DIFF_LOCK_COMBAT end
    return nil
end

local function BuildDifficultyMenu(rootDescription)
    rootDescription:SetTag(MENU_TAG .. "_difficulty")
    local PD = Orbit.RaidPanelData
    local disabledReason = DifficultyDisabledReason()
    local isRaid = IsInRaid()

    rootDescription:CreateTitle(isRaid and L.PLU_RAIDPANEL_DIFF_SECTION_RAID or L.PLU_RAIDPANEL_DIFF_SECTION_DUNGEON)
    local list = isRaid and PD.RAID_DIFFICULTIES or PD.DUNGEON_DIFFICULTIES
    local current = isRaid and GetRaidDifficultyID() or GetDungeonDifficultyID()
    local setter = isRaid and SetRaidDifficultyID or SetDungeonDifficultyID

    for _, opt in ipairs(list) do
        local id = opt.id
        local btn = rootDescription:CreateRadio(opt.label,
            function() return current == id end,
            function() setter(id) end)
        if disabledReason then btn:SetEnabled(false) end
    end

    if disabledReason then
        rootDescription:CreateDivider()
        rootDescription:CreateTitle(disabledReason)
    end
end

-- [ PINGS ] -----------------------------------------------------------------------------------------
local function BuildPingsMenu(rootDescription)
    rootDescription:SetTag(MENU_TAG .. "_pings")
    local PD = Orbit.RaidPanelData

    rootDescription:CreateTitle(L.PLU_RAIDPANEL_PINGS_TITLE)
    for _, opt in ipairs(PD.PING_RESTRICTIONS) do
        local value = opt.value
        rootDescription:CreateRadio(opt.label,
            function() return C_PartyInfo.GetRestrictPings() == value end,
            function() C_PartyInfo.SetRestrictPings(value) end)
    end
end

-- [ DISPATCH ] --------------------------------------------------------------------------------------
function Menus.Open(menuKey, anchorFrame, ctx)
    if menuKey == "difficulty" then
        MenuUtil.CreateContextMenu(anchorFrame, function(_, root) BuildDifficultyMenu(root) end)
    elseif menuKey == "pings" then
        MenuUtil.CreateContextMenu(anchorFrame, function(_, root) BuildPingsMenu(root) end)
    end
end
