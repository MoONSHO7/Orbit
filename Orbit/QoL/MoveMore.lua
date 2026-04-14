-- [ MOVE MORE ]-------------------------------------------------------------------------------------
-- QoL feature: makes Blizzard UI frames freely draggable.
-- Positions reset on close unless "Save Positions" is enabled, in which case drag-stop writes the
-- frame's current points to Orbit.db.AccountSettings.MoveMorePositions and OnShow re-applies them.
-- Toggle via Quality of Life > Move More in the Orbit settings panel.

local _, Orbit = ...

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local FRAME_NAMES = {
    -- Core character panels
    "CharacterFrame", "PlayerSpellsFrame", "ProfessionsBookFrame", "ProfessionsFrame",
    -- Social / guild
    "FriendsFrame", "CommunitiesFrame", "CommunitiesGuildLogFrame",
    "CommunitiesGuildTextEditFrame", "CommunitiesGuildNewsFiltersFrame",
    "ClubFinderGuildRecruitmentDialog", "RaidBrowserFrame",
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
    -- Renown / trading post / traits
    "MajorFactionRenownFrame", "PerksProgramFrame", "GenericTraitFrame",
    -- Storage
    "VoidStorageFrame", "GuildBankFrame",
    -- Warband
    "WarbandSceneEditor",
    -- Travel
    "FlightMapFrame", "TaxiFrame",
    -- Misc interactions
    "HelpFrame", "ScrappingMachineFrame", "ItemSocketingFrame", "MacroPopupFrame",
    -- Popups
    "ReadyCheckFrame", "RolePollPopup",
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

local function SavePositionIfEnabled(frame)
    if not (Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.MoveMoreSavePositions) then return end
    local name = frame:GetName()
    if not name then return end
    local points = {}
    for i = 1, frame:GetNumPoints() do
        points[i] = { frame:GetPoint(i) }
    end
    Orbit.db.AccountSettings.MoveMorePositions = Orbit.db.AccountSettings.MoveMorePositions or {}
    Orbit.db.AccountSettings.MoveMorePositions[name] = points
end

local function ApplySavedPosition(frame)
    if not (Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.MoveMoreSavePositions) then return end
    local name = frame:GetName()
    if not name then return end
    local store = Orbit.db.AccountSettings.MoveMorePositions
    local saved = store and store[name]
    if not saved or InCombatLockdown() then return end
    frame:ClearAllPoints()
    for _, pt in ipairs(saved) do
        frame:SetPoint(unpack(pt))
    end
end

local function IsSavingPositions()
    return Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.MoveMoreSavePositions
end

local function OnDragStop(frame)
    frame:StopMovingOrSizing()
    frame:SetUserPlaced(IsSavingPositions() and true or false)
    SavePositionIfEnabled(frame)
end

function MM:ClearSavedPositions()
    if Orbit.db and Orbit.db.AccountSettings then
        Orbit.db.AccountSettings.MoveMorePositions = nil
    end
end

function MM:OnSavePositionsChanged(enabled)
    if InCombatLockdown() then return end
    for name in pairs(FRAME_NAMES_HASH) do
        local f = _G[name]
        if f and f._maHooked then
            f:SetUserPlaced(enabled and true or false)
            if enabled and f:IsShown() then ApplySavedPosition(f) end
        end
    end
end

local function HookFrame(frame)
    if frame._maHooked then return end
    if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
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
        if IsSavingPositions() then
            f:SetUserPlaced(true)
            ApplySavedPosition(f)
        end
    end)
    frame:HookScript("OnHide", function(f)
        if IsSavingPositions() then
            SavePositionIfEnabled(f)
            return
        end
        RestoreDefaultPoints(f)
    end)
    if frame:IsShown() then
        SaveDefaultPoints(frame)
        if IsSavingPositions() then
            ApplySavedPosition(frame)
            frame:SetUserPlaced(true)
        end
    end
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
        if IsSavingPositions() then
            frame:SetUserPlaced(true)
            ApplySavedPosition(frame)
        end
    end
end)

hooksecurefunc("UpdateUIPanelPositions", function()
    if not MM._active or not IsSavingPositions() then return end
    for name in pairs(FRAME_NAMES_HASH) do
        local f = _G[name]
        if f and f._maHooked and f:IsShown() then
            ApplySavedPosition(f)
        end
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
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0.5, function()
            if Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.MoveMore then
                MM:Enable()
            end
        end)
    elseif event == "ADDON_LOADED" and MM._active then
        for name in pairs(FRAME_NAMES_HASH) do
            local f = _G[name]
            if f and not f._maHooked then HookFrame(f) end
        end
    end
end)
