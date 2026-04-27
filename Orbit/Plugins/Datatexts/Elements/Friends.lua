-- Friends.lua
-- Friends datatext: online friends count
local _, Orbit = ...
local DT = Orbit.Datatexts
local L = Orbit.L

local BNET_CLIENT_NAMES = {
    ["App"] = "Battle.net Desktop App",
    ["WoW"] = "World of Warcraft",
    ["WTCG"] = "Hearthstone",
    ["Hero"] = "Heroes of the Storm",
    ["Pro"] = "Overwatch",
    ["OSI"] = "Diablo II: Resurrected",
    ["D3"] = "Diablo III",
    ["ANBS"] = "Diablo Immortal",
    ["Fen"] = "Diablo IV",
    ["S1"] = "StarCraft",
    ["S2"] = "StarCraft II",
    ["W3"] = "Warcraft III: Reforged",
    ["VIPR"] = "Call of Duty: Black Ops 4",
    ["ODIN"] = "Call of Duty: Modern Warfare",
    ["LAZR"] = "Call of Duty: MW2 Campaign Remastered",
    ["ZEUS"] = "Call of Duty: Black Ops Cold War",
    ["WLBY"] = "Crash Bandicoot 4",
    ["GRY"] = "Warcraft Arclight Rumble",
}

local locToClass = {}
local function GetClassColorFromLocalized(localizedName)
    if not localizedName or localizedName == "" then return 1, 1, 1 end
    if not next(locToClass) then
        for i = 1, GetNumClasses() do
            local classDisplayName, classTag = GetClassInfo(i)
            if classDisplayName then locToClass[classDisplayName] = classTag end
        end
        if LOCALIZED_CLASS_NAMES_MALE then
            for classFile, locClass in pairs(LOCALIZED_CLASS_NAMES_MALE) do locToClass[locClass] = classFile end
        end
        if LOCALIZED_CLASS_NAMES_FEMALE then
            for classFile, locClass in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do locToClass[locClass] = classFile end
        end
    end
    local classFile = locToClass[localizedName]
    if classFile and Orbit.Engine.ClassColor then
        return Orbit.Engine.ClassColor:GetOverridesUnpacked(classFile)
    end
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local color = RAID_CLASS_COLORS[classFile]
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Friends")

function W:Update()
    local _, bnetOnline = BNGetNumFriends()
    local wowOnline = C_FriendList.GetNumOnlineFriends()
    local total = (bnetOnline or 0) + (wowOnline or 0)
    if total > 0 then
        self:SetText(string.format("|cff00ff00%d|r Online", total))
    else
        self:SetText("|cff888888No Friends|r")
    end
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_FRIENDS_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    
    local numBnet = BNGetNumFriends()
    local wowTotal = C_FriendList.GetNumFriends()
    local wowOnline = C_FriendList.GetNumOnlineFriends()
    
    local friendsByGame = {}
    local wowCount = 0
    local bnetTotalOnline = 0
    
    -- WoW Friends (Character)
    if wowOnline > 0 then
        friendsByGame["World of Warcraft (Character)"] = {}
        for i = 1, wowTotal do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then
                table.insert(friendsByGame["World of Warcraft (Character)"], info)
                wowCount = wowCount + 1
            end
        end
    end

    -- BNet Friends
    for i = 1, numBnet do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAccountInfo and info.gameAccountInfo.isOnline then
            local client = info.gameAccountInfo.clientProgram or "App"
            bnetTotalOnline = bnetTotalOnline + 1
            
            if client ~= "App" and client ~= "BSv" and client ~= "BSAp" then
                local gameName = BNET_CLIENT_NAMES[client] or client
                if not friendsByGame[gameName] then friendsByGame[gameName] = {} end
                table.insert(friendsByGame[gameName], info)
            end
        end
    end

    GameTooltip:AddDoubleLine("Battle.net:", string.format("%d Online", bnetTotalOnline or 0), 1, 1, 1, 0.7, 0.7, 0.7)
    GameTooltip:AddDoubleLine("WoW Character:", string.format("%d / %d online", wowCount or 0, wowTotal or 0), 1, 1, 1, 0.7, 0.7, 0.7)
    
    local gameOrder = {}
    for game in pairs(friendsByGame) do table.insert(gameOrder, game) end
    table.sort(gameOrder, function(a, b)
        if a == "World of Warcraft" and b ~= "World of Warcraft" then return true end
        if b == "World of Warcraft" and a ~= "World of Warcraft" then return false end
        if a == "World of Warcraft (Character)" and b ~= "World of Warcraft (Character)" then return true end
        if b == "World of Warcraft (Character)" and a ~= "World of Warcraft (Character)" then return false end
        if a:match("Battle%.net") and not b:match("Battle%.net") then return false end
        if b:match("Battle%.net") and not a:match("Battle%.net") then return true end
        return a < b
    end)
    
    for _, gameName in ipairs(gameOrder) do
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(gameName, 0.2, 0.8, 1)
        
        for _, friend in ipairs(friendsByGame[gameName]) do
            if gameName == "World of Warcraft (Character)" then
                local r, g, b = GetClassColorFromLocalized(friend.className)
                local name = friend.name
                if friend.level then name = name .. " |cffaaaaaa" .. friend.level .. "|r" end
                GameTooltip:AddDoubleLine(name, friend.area or "", r, g, b, 0.7, 0.7, 0.7)
            else
                local name = friend.accountName or "Unknown"
                local infoText = friend.gameAccountInfo.richPresence or ""
                local r, g, b = 0.5, 0.5, 0.5
                
                if friend.gameAccountInfo.clientProgram == "WoW" then
                    local charName = friend.gameAccountInfo.characterName or ""
                    if charName ~= "" then
                        local charLevel = friend.gameAccountInfo.characterLevel or ""
                        local charClass = friend.gameAccountInfo.className or ""
                        local zone = friend.gameAccountInfo.areaName or ""
                        r, g, b = GetClassColorFromLocalized(charClass)
                        name = string.format("%s (|cffffffff%s|r)", name, charName)
                        if charLevel ~= "" and charLevel ~= 0 then name = name .. " |cffaaaaaa" .. charLevel .. "|r" end
                        infoText = zone
                    end
                else
                    r, g, b = 1, 1, 1
                end
                
                GameTooltip:AddDoubleLine(name, infoText, r, g, b, 0.7, 0.7, 0.7)
            end
        end
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Friends List", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function() ToggleFriendsFrame() end)
    self.leftClickHint = "Friends List"
    self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    self:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    self:RegisterEvent("FRIENDLIST_UPDATE")
    self:SetCategory("SOCIAL")
    self:Register()
    self:Update()
end

W:Init()
