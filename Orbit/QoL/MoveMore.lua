-- [ MOVE MORE ]--------------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local FRAME_NAMES = {
    "CharacterFrame", "PlayerSpellsFrame", "ProfessionsBookFrame", "ProfessionsFrame",
    "FriendsFrame", "CommunitiesFrame", "CommunitiesGuildLogFrame",
    "CommunitiesGuildTextEditFrame", "CommunitiesGuildNewsFiltersFrame",
    "ClubFinderGuildRecruitmentDialog", "RaidBrowserFrame",
    "CollectionsJournal", "EncounterJournal", "AchievementFrame",
    "WorldMapFrame", "QuestFrame", "QuestLogPopupDetailFrame",
    "PVEFrame", "LFGListApplicationDialog",
    "GossipFrame", "MerchantFrame", "TradeFrame",
    "GuildRegistrarFrame", "PetitionFrame", "ItemTextFrame", "TabardFrame",
    "MailFrame", "AuctionHouseFrame", "BankFrame",
    "InspectFrame", "DressUpFrame", "TransmogFrame",
    "ItemUpgradeFrame",
    "LootFrame",
    "PVPMatchScoreboard", "PVPMatchResults", "DeathRecapFrame",
    "GarrisonLandingPage", "ExpansionLandingPage",
    "AddonList", "AlliedRacesFrame", "GuildControlUI",
    "ChatConfigFrame", "SettingsPanel", "GameMenuFrame",
    "WeeklyRewardsFrame", "InspectRecipeFrame",
    "ProfessionsCustomerOrdersFrame", "ChallengesKeystoneFrame", "MacroFrame",
    "DelvesCompanionConfigurationFrame", "DelvesCompanionAbilityListFrame",
    "DelvesDifficultyPickerFrame",
    "HousingDashboardFrame", "HouseFinderFrame", "HousingCornerstoneFrame",
    "HousingBulletinBoardFrame", "HouseEditorFrame",
    "MajorFactionRenownFrame", "PerksProgramFrame", "GenericTraitFrame",
    "VoidStorageFrame", "GuildBankFrame",
    "WarbandSceneEditor",
    "FlightMapFrame", "TaxiFrame",
    "HelpFrame", "ScrappingMachineFrame", "ItemSocketingFrame", "MacroPopupFrame",
    "ReadyCheckFrame", "RolePollPopup",
    "BarberShopFrame", "SoulbindViewer", "RuneforgeFrame",
}

local FRAME_NAMES_HASH = {}
for _, name in ipairs(FRAME_NAMES) do FRAME_NAMES_HASH[name] = true end

local NO_SCALE = {
    WorldMapFrame = true, FlightMapFrame = true,
    GarrisonLandingPage = true, ExpansionLandingPage = true,
    MajorFactionRenownFrame = true, PerksProgramFrame = true,
    GenericTraitFrame = true, WeeklyRewardsFrame = true,
    ChallengesKeystoneFrame = true, DelvesCompanionConfigurationFrame = true,
}

local LOGIN_DEFER = 0.5
local SCALE_MIN = 0.5
local SCALE_MAX = 2.0
local SCALE_STEP_PIXELS = 400
local HANDLE_SIZE = 18
local HANDLE_OFFSET = 2

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.MoveMore = {}
local MM = Orbit.MoveMore
MM._active = false
MM._armed = false
MM._pendingDisable = false
MM._installedShowHook = false
MM._installedUpdateHook = false

-- [ POINTS - DEFAULTS ]------------------------------------------------------------------------------
local function SaveDefaultPoints(frame)
    if frame._mmDefaultPoints then return end
    local n = frame:GetNumPoints()
    if n == 0 then return end
    local pts = {}
    for i = 1, n do pts[i] = { frame:GetPoint(i) } end
    frame._mmDefaultPoints = pts
end

local function RestoreDefaultPoints(frame)
    local pts = frame._mmDefaultPoints
    if not pts or InCombatLockdown() then return end
    frame:ClearAllPoints()
    for _, p in ipairs(pts) do frame:SetPoint(unpack(p)) end
end

-- [ POINTS - SAVED ]---------------------------------------------------------------------------------
local function IsSavingPositions()
    local s = Orbit.db and Orbit.db.AccountSettings
    return s and s.MoveMoreSavePositions or false
end

local function GetStore()
    if not Orbit.db.AccountSettings.MoveMorePositions then
        Orbit.db.AccountSettings.MoveMorePositions = {}
    end
    return Orbit.db.AccountSettings.MoveMorePositions
end

local function GetSavedEntry(name) return GetStore()[name] end

local function SavePosition(frame)
    local name = frame:GetName()
    if not name then return end
    local n = frame:GetNumPoints()
    if n == 0 then return end
    local serialized = {}
    for i = 1, n do
        local point, relTo, relPoint, x, y = frame:GetPoint(i)
        local relName = (relTo and relTo.GetName and relTo:GetName()) or "UIParent"
        serialized[i] = { point, relName, relPoint, x or 0, y or 0 }
    end
    local store = GetStore()
    store[name] = store[name] or {}
    store[name].points = serialized
end

local function SaveScale(frame, scale)
    local name = frame:GetName()
    if not name then return end
    local store = GetStore()
    store[name] = store[name] or {}
    store[name].scale = scale
end

local function ApplySavedPoints(frame)
    if InCombatLockdown() then return end
    local entry = GetSavedEntry(frame:GetName() or "")
    local pts = entry and entry.points
    if not pts then return end
    frame:ClearAllPoints()
    for _, p in ipairs(pts) do
        local relTo = _G[p[2]] or UIParent
        frame:SetPoint(p[1], relTo, p[3], p[4], p[5])
    end
end

local function ApplySavedScale(frame)
    if InCombatLockdown() then return end
    if NO_SCALE[frame:GetName() or ""] then return end
    local entry = GetSavedEntry(frame:GetName() or "")
    if entry and entry.scale then
        frame:SetScale(entry.scale)
    end
end

-- [ DRAG HANDLERS ]----------------------------------------------------------------------------------
-- `_mmDragging` sentinel: a click-and-release without our StartMoving would still fire OnDragStop,
-- and StopMovingOrSizing on a protected frame in combat trips ADDON_ACTION_BLOCKED.
local function OnDragStart(frame)
    if InCombatLockdown() then return end
    frame._mmDragging = true
    frame:StartMoving()
end

local function OnDragStop(frame)
    if not frame._mmDragging then return end
    if InCombatLockdown() then return end
    frame._mmDragging = false
    frame:StopMovingOrSizing()
    if IsSavingPositions() then SavePosition(frame) end
end

-- [ SCALE HANDLE ]-----------------------------------------------------------------------------------
-- WoW's Y increases upward — invert so a diagonal outward drag from the bottom-right corner grows.
local function OnScaleDragUpdate(handle)
    if InCombatLockdown() then
        handle:SetScript("OnUpdate", nil)
        handle._dragging = false
        return
    end
    local frame = handle._target
    local mouseX, mouseY = GetCursorPosition()
    local delta = (mouseX - handle._startX) + (handle._startY - mouseY)
    local newScale = handle._startScale + (delta / SCALE_STEP_PIXELS)
    if newScale < SCALE_MIN then newScale = SCALE_MIN end
    if newScale > SCALE_MAX then newScale = SCALE_MAX end
    frame:SetScale(newScale)
end

local function OnScaleDragStart(handle)
    if InCombatLockdown() then return end
    local frame = handle._target
    handle._startX, handle._startY = GetCursorPosition()
    handle._startScale = frame:GetScale() or 1
    handle._dragging = true
    handle:SetScript("OnUpdate", OnScaleDragUpdate)
end

local function OnScaleDragStop(handle)
    if not handle._dragging then return end
    if InCombatLockdown() then return end
    handle._dragging = false
    handle:SetScript("OnUpdate", nil)
    local frame = handle._target
    if IsSavingPositions() then SaveScale(frame, frame:GetScale() or 1) end
end

local function AttachScaleHandle(frame)
    if frame._mmScaleHandle then return end
    if NO_SCALE[frame:GetName() or ""] then return end

    local handle = CreateFrame("Button", nil, frame)
    handle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -HANDLE_OFFSET, HANDLE_OFFSET)
    handle:SetFrameLevel((frame:GetFrameLevel() or 0) + 10)
    handle:SetNormalAtlas("damagemeters-scalehandle")
    handle:SetHighlightAtlas("damagemeters-scalehandle-hover")
    handle:SetPushedAtlas("damagemeters-scalehandle-pressed")
    handle:RegisterForDrag("LeftButton")
    handle._target = frame
    handle:SetScript("OnDragStart", OnScaleDragStart)
    handle:SetScript("OnDragStop", OnScaleDragStop)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.PLU_MM_SCALE_TT_F:format(frame:GetScale() or 1))
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame._mmScaleHandle = handle
end

local function DetachScaleHandle(frame)
    local h = frame._mmScaleHandle
    if not h then return end
    h:Hide()
    h:SetParent(nil)
    h:ClearAllPoints()
    frame._mmScaleHandle = nil
end

-- [ HOOKING ]----------------------------------------------------------------------------------------
-- Skip frames whose ancestor we hook: PVEFrame + its setAllPoints PVPUIFrame child would detach.
local function HasHookedAncestor(frame)
    local p = frame:GetParent()
    while p do
        if p._mmHooked then return true end
        local pname = p.GetName and p:GetName()
        if pname and FRAME_NAMES_HASH[pname] then return true end
        p = p:GetParent()
    end
    return false
end

local function HookFrame(frame)
    if frame._mmHooked then return end
    if HasHookedAncestor(frame) then return end
    if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
    frame._mmHooked = true

    local dragFrame = frame
    if frame.TitleContainer and type(frame.TitleContainer.RegisterForDrag) == "function" then
        dragFrame = frame.TitleContainer
    end
    frame._mmDragFrame = dragFrame
    frame._mmPrevClamped = frame:IsClampedToScreen()
    frame._mmDefaultScale = frame:GetScale() or 1
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    if not dragFrame:IsMouseEnabled() then dragFrame:EnableMouse(true) end
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:SetScript("OnDragStart", function() OnDragStart(frame) end)
    dragFrame:SetScript("OnDragStop", function() OnDragStop(frame) end)

    if not frame._mmScriptHooksInstalled then
        frame._mmScriptHooksInstalled = true
        frame:HookScript("OnShow", function(f)
            if not (MM._armed and f._mmHooked) then return end
            SaveDefaultPoints(f)
            if IsSavingPositions() then
                ApplySavedScale(f)
                ApplySavedPoints(f)
            end
        end)
        frame:HookScript("OnHide", function(f)
            if not (MM._armed and f._mmHooked) then return end
            if IsSavingPositions() then return end
            if InCombatLockdown() then return end
            RestoreDefaultPoints(f)
            if f._mmDefaultScale then f:SetScale(f._mmDefaultScale) end
            f._mmDefaultPoints = nil
        end)
    end

    AttachScaleHandle(frame)

    if frame:IsShown() then
        SaveDefaultPoints(frame)
        if IsSavingPositions() then
            ApplySavedScale(frame)
            ApplySavedPoints(frame)
        end
    end
end

local function UnhookFrame(frame)
    if not frame._mmHooked then return end
    if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
    frame:SetMovable(false)
    if frame._mmPrevClamped ~= nil then frame:SetClampedToScreen(frame._mmPrevClamped) end

    local d = frame._mmDragFrame or frame
    d:SetScript("OnDragStart", nil)
    d:SetScript("OnDragStop", nil)

    DetachScaleHandle(frame)
    RestoreDefaultPoints(frame)
    if frame._mmDefaultScale then frame:SetScale(frame._mmDefaultScale) end
    frame._mmDefaultPoints = nil
    frame._mmDefaultScale = nil
    frame._mmHooked = nil
    frame._mmDragFrame = nil
    frame._mmPrevClamped = nil
end

-- [ GLOBAL HOOKS ]-----------------------------------------------------------------------------------
local function InstallGlobalHooks()
    if not MM._installedShowHook then
        MM._installedShowHook = true
        hooksecurefunc("ShowUIPanel", function(frame)
            if not (MM._armed and frame) then return end
            pcall(function()
                local name = frame.GetName and frame:GetName()
                if name and FRAME_NAMES_HASH[name] then HookFrame(frame) end
            end)
        end)
    end
    if not MM._installedUpdateHook then
        MM._installedUpdateHook = true
        hooksecurefunc("UpdateUIPanelPositions", function()
            if not (MM._armed and IsSavingPositions()) then return end
            pcall(function()
                for name in pairs(FRAME_NAMES_HASH) do
                    local f = _G[name]
                    if f and f._mmHooked and f:IsShown() then
                        ApplySavedScale(f)
                        ApplySavedPoints(f)
                    end
                end
            end)
        end)
    end
end

-- [ PUBLIC API ]-------------------------------------------------------------------------------------
function MM:Enable()
    if self._active then return end
    self._active = true
    self._armed = true
    self._pendingDisable = false
    InstallGlobalHooks()
    for name in pairs(FRAME_NAMES_HASH) do
        local frame = _G[name]
        if frame then HookFrame(frame) end
    end
end

function MM:_TearDown()
    self._armed = false
    self._pendingDisable = false
    for name in pairs(FRAME_NAMES_HASH) do
        local f = _G[name]
        if f and f._mmHooked then UnhookFrame(f) end
    end
end

function MM:Disable()
    if not self._active then return end
    self._active = false
    if InCombatLockdown() then
        self._pendingDisable = true
        return
    end
    self:_TearDown()
end

function MM:ClearSavedPositions()
    if Orbit.db and Orbit.db.AccountSettings then
        Orbit.db.AccountSettings.MoveMorePositions = nil
    end
    if not self._armed then return end
    if InCombatLockdown() then return end
    for name in pairs(FRAME_NAMES_HASH) do
        local f = _G[name]
        if f and f._mmHooked then
            RestoreDefaultPoints(f)
            if f._mmDefaultScale then f:SetScale(f._mmDefaultScale) end
        end
    end
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
local function IsBlizzardLoD(addonName)
    return type(addonName) == "string" and addonName:sub(1, 9) == "Blizzard_"
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(LOGIN_DEFER, function()
            if Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.MoveMore then
                MM:Enable()
            end
        end)
    elseif event == "ADDON_LOADED" then
        if not MM._armed or not IsBlizzardLoD(arg1) then return end
        for name in pairs(FRAME_NAMES_HASH) do
            local f = _G[name]
            if f and not f._mmHooked then HookFrame(f) end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if MM._pendingDisable then MM:_TearDown(); return end
        for name in pairs(FRAME_NAMES_HASH) do
            local f = _G[name]
            if f then
                if f._mmDragging then
                    f._mmDragging = false
                    f:StopMovingOrSizing()
                    if IsSavingPositions() then SavePosition(f) end
                end
                local h = f._mmScaleHandle
                if h and h._dragging then
                    h._dragging = false
                    h:SetScript("OnUpdate", nil)
                    if IsSavingPositions() then SaveScale(f, f:GetScale() or 1) end
                end
            end
        end
    end
end)
