-- [ MOVE MORE ]-------------------------------------------------------------------------------------
-- QoL feature: makes Blizzard UI frames freely draggable.
-- Positions are NOT persisted — closing a frame resets it to its default position.
-- Toggle via Quality of Life > Move More in the Orbit settings panel.

local _, Orbit = ...

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local FRAME_NAMES = {
    -- Core character panels
    "CharacterFrame", "PlayerSpellsFrame", "ProfessionsBookFrame", "ProfessionsFrame",
    -- Social / guild
    "FriendsFrame", "CommunitiesFrame", "CommunitiesGuildLogFrame",
    "CommunitiesGuildTextEditFrame", "CommunitiesGuildNewsFiltersFrame",
    "ClubFinderGuildRecruitmentDialog", "RaidParentFrame", "RaidBrowserFrame",
    -- Collections / journal
    "CollectionsJournal", "EncounterJournal", "AchievementFrame",
    -- Map / quests
    "WorldMapFrame", "QuestFrame", "QuestLogPopupDetailFrame", "QuestMapFrame",
    -- Group finder / PvP
    "PVEFrame", "PVPUIFrame", "GroupFinderFrame", "LFGListApplicationDialog",
    -- NPC interaction
    "GossipFrame", "MerchantFrame", "TradeFrame", "QuestFrame",
    "GuildRegistrarFrame", "PetitionFrame", "ItemTextFrame", "TabardFrame",
    -- Mail / auction / bank
    "MailFrame", "AuctionHouseFrame", "BankFrame", "AccountBankPanel",
    -- Inspect / dressing
    "InspectFrame", "DressUpFrame", "TransmogFrame",
    -- Talents / upgrades
    "ClassTalentFrame", "ItemUpgradeFrame", "OrderHallTalentFrame",
    -- Loot
    "LootFrame",
    -- PvP results
    "PVPMatchScoreboard", "PVPMatchResults", "DeathRecapFrame",
    -- Garrison / mission tables
    "GarrisonLandingPage", "ExpansionLandingPage",
    -- Misc panels
    "AddonList", "AlliedRacesFrame", "GuildControlUI",
    "ChatConfigFrame", "SettingsPanel", "GameMenuFrame",
    "WeeklyRewardsFrame", "InspectRecipeFrame",
    "ProfessionsCustomerOrdersFrame", "ChallengesKeystoneFrame", "MacroFrame",
    -- Delves
    "DelvesCompanionConfigurationFrame", "DelvesCompanionAbilityListFrame",
    "DelvesDifficultyPickerFrame",
    -- Housing
    "HousingDashboardFrame", "HouseFinderFrame", "HousingCornerstoneFrame",
    "HousingBulletinBoardFrame",
}

local FRAME_NAMES_HASH = {}
for _, name in ipairs(FRAME_NAMES) do
    FRAME_NAMES_HASH[name] = true
end

-- [ MODULE ]----------------------------------------------------------------------------------------
Orbit.MoveMore = {}
local MM = Orbit.MoveMore
MM._hooked = {}
MM._active = false

local function SaveDefaultPoints(frame)
    if frame._maDefaultPoints then return end
    frame._maDefaultPoints = {}
    for i = 1, frame:GetNumPoints() do
        frame._maDefaultPoints[i] = { frame:GetPoint(i) }
    end
end

local function RestoreDefaultPoints(frame)
    if not frame._maDefaultPoints then return end
    if InCombatLockdown() then return end
    frame:ClearAllPoints()
    for _, pt in ipairs(frame._maDefaultPoints) do
        frame:SetPoint(unpack(pt))
    end
    frame._maDefaultPoints = nil
end

local function OnDragStart(frame)
    if InCombatLockdown() then return end
    frame:StartMoving()
end

local function OnDragStop(frame)
    frame:StopMovingOrSizing()
    frame:SetUserPlaced(false)
end

local function HookFrame(frame)
    if frame._maHooked then return end
    frame._maHooked = true
    
    local dragFrame = frame
    if frame.TitleContainer and type(frame.TitleContainer.RegisterForDrag) == "function" then
        dragFrame = frame.TitleContainer
    end
    
    frame._maDragFrame = dragFrame

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    
    if not dragFrame:IsMouseEnabled() then
        dragFrame:EnableMouse(true)
    end
    
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:SetScript("OnDragStart", function() OnDragStart(frame) end)
    dragFrame:SetScript("OnDragStop", function() OnDragStop(frame) end)
    
    frame:HookScript("OnShow", function(f)
        if not MM._active then return end
        SaveDefaultPoints(f)
    end)
    frame:HookScript("OnHide", function(f)
        RestoreDefaultPoints(f)
    end)
    if frame:IsShown() then SaveDefaultPoints(frame) end
end

local function UnhookFrame(frame)
    if not frame._maHooked then return end
    if InCombatLockdown() then return end
    frame:SetMovable(false)
    
    local dragFrame = frame._maDragFrame or frame
    dragFrame:SetScript("OnDragStart", nil)
    dragFrame:SetScript("OnDragStop", nil)
    
    RestoreDefaultPoints(frame)
    frame._maHooked = nil
    frame._maDragFrame = nil
end

hooksecurefunc("ShowUIPanel", function(frame)
    if not MM._active then return end
    if not frame then return end
    local name = frame:GetName()
    if name and FRAME_NAMES_HASH[name] then
        HookFrame(frame)
    end
end)

function MM:Enable()
    if self._active then return end
    self._active = true
    for name in pairs(FRAME_NAMES_HASH) do
        local frame = _G[name]
        if frame then HookFrame(frame) end
    end
end

function MM:Disable()
    if not self._active then return end
    self._active = false
    if InCombatLockdown() then
        Orbit:SafeAction(function() MM:Disable() end)
        return
    end
    for name in pairs(FRAME_NAMES_HASH) do
        local frame = _G[name]
        if frame then UnhookFrame(frame) end
    end
end

-- [ AUTO-ENABLE ON LOGIN ]--------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
        if Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.MoveMore then
            MM:Enable()
        end
    end)
    loader:UnregisterAllEvents()
end)
