-- Gold.lua
-- Currency display: cross-character tracking, session profit/loss, gold/hour, sparkline
local _, Orbit = ...
local DT = Orbit.Datatexts
local Fmt = DT.Formatting
local RingBuffer = Fmt.RingBuffer

-- [ CONSTANTS ] -------------------------------------------------------------------
local COPPER_PER_GOLD = 10000
local GRAPH_WIDTH = 200
local GRAPH_HEIGHT = 50
local GRAPH_OFFSET_Y = -5
local HISTORY_SIZE = 60
local HISTORY_INTERVAL_SEC = 60
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400
local BAG_COUNT = 4
local JUNK_QUALITY = 0
local MIN_HISTORY_POINTS = 2
local DAILY_HISTORY_DAYS = 7

-- [ datatext ] ----------------------------------------------------------------------
local W = DT.BaseDatatext:New("Gold")

-- [ STATE ] -----------------------------------------------------------------------
W.history = RingBuffer:New(HISTORY_SIZE)
W.sessionStart = 0
W.sessionStartTime = 0
W.lastHistoryTime = 0
W.autoSellEnabled = true

-- [ HELPERS ] ---------------------------------------------------------------------
local function FormatProfit(profit)
    local color = profit > 0 and "|cff00ff00+" or (profit < 0 and "|cffff0000" or "|cffffffff")
    return color .. Fmt:FormatMoney(math.abs(profit)) .. "|r"
end

local function GetAccountData()
    if not OrbitDB or not OrbitDB._datatextAccountData then return {} end
    local result = {}
    for realm, chars in pairs(OrbitDB._datatextAccountData) do
        for name, data in pairs(chars) do
            result[#result + 1] = { name = name, realm = realm, class = data.class, level = data.level, gold = data.gold }
        end
    end
    table.sort(result, function(a, b) return a.gold > b.gold end)
    return result
end

-- [ CROSS-CHARACTER ] -------------------------------------------------------------
function W:SaveCharacterGold(copper)
    if not OrbitDB then return end
    if not OrbitDB._datatextAccountData then OrbitDB._datatextAccountData = {} end
    local realm = GetRealmName()
    if not OrbitDB._datatextAccountData[realm] then OrbitDB._datatextAccountData[realm] = {} end
    local name = UnitName("player")
    local _, class = UnitClass("player")
    OrbitDB._datatextAccountData[realm][name] = { gold = copper, class = class, level = UnitLevel("player") }
    self:UpdateDailyHistory(copper)
end

function W:UpdateDailyHistory(copper)
    if not OrbitDB._datatextDailyGold then OrbitDB._datatextDailyGold = {} end
    local today = math.floor(time() / SECONDS_PER_DAY)
    local hist = OrbitDB._datatextDailyGold
    if #hist == 0 or hist[#hist].day ~= today then
        hist[#hist + 1] = { day = today, gold = copper }
        if #hist > DAILY_HISTORY_DAYS then table.remove(hist, 1) end
    else
        hist[#hist].gold = copper
    end
end

function W:GetDailyDeltas()
    if not OrbitDB or not OrbitDB._datatextDailyGold then return {} end
    local hist = OrbitDB._datatextDailyGold
    local deltas = {}
    for i = 2, #hist do deltas[#deltas + 1] = { day = hist[i].day, delta = hist[i].gold - hist[i - 1].gold } end
    return deltas
end

-- [ UPDATE ] ----------------------------------------------------------------------
function W:Update()
    local money = GetMoney()
    self:SetText(Fmt:FormatMoney(money))
    local t = GetTime()
    if t - self.lastHistoryTime > HISTORY_INTERVAL_SEC then
        self.history:Push(money)
        self.lastHistoryTime = t
    end
end

function W:OnMoneyChange()
    self:Update()
    self:SaveCharacterGold(GetMoney())
end

-- [ AUTO SELL ] -------------------------------------------------------------------
function W:AutoSellJunk()
    if not self.autoSellEnabled then return end
    local profit = 0
    for bag = 0, BAG_COUNT do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == JUNK_QUALITY and not info.isLocked then
                local price = select(11, GetItemInfo(info.hyperlink))
                if price and price > 0 then C_Container.UseContainerItem(bag, slot); profit = profit + (price * info.stackCount) end
            end
        end
    end
    if profit > 0 then print(string.format("|cff00ff00Auto-Sold Junk for %s|r", Fmt:FormatMoney(profit))) end
end

-- [ CONTEXT MENU ] ----------------------------------------------------------------
function W:GetMenuItems()
    return {
        { text = "Auto-Sell Grey Items", checked = self.autoSellEnabled, func = function() self.autoSellEnabled = not self.autoSellEnabled end, closeOnClick = false },
        { text = "Reset Session", func = function() self.sessionStart = GetMoney(); self.sessionStartTime = GetTime(); self.history:Clear(); self:Update() end },
    }
end

-- [ TOOLTIP ] ---------------------------------------------------------------------
function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Wealth", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local current = GetMoney()
    GameTooltip:AddDoubleLine("Current:", Fmt:FormatMoney(current), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session:", FormatProfit(current - self.sessionStart), 1, 1, 1, 1, 1, 1)
    local elapsed = GetTime() - self.sessionStartTime
    if elapsed > 0 then
        GameTooltip:AddDoubleLine("Gold/Hour:", FormatProfit((current - self.sessionStart) / elapsed * SECONDS_PER_HOUR), 1, 1, 1, 1, 1, 1)
    end
    local deltas = self:GetDailyDeltas()
    if #deltas > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Daily History", 0.7, 0.7, 0.7)
        for _, d in ipairs(deltas) do GameTooltip:AddDoubleLine(date("%m/%d", d.day * SECONDS_PER_DAY), FormatProfit(d.delta), 1, 1, 1, 1, 1, 1) end
    end
    local chars = GetAccountData()
    if #chars > 1 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Account Gold", 0.7, 0.7, 0.7)
        local total = 0
        for _, char in ipairs(chars) do
            local cc = RAID_CLASS_COLORS[char.class]
            GameTooltip:AddDoubleLine(string.format("%s (%d)", char.name, char.level), Fmt:FormatMoney(char.gold), cc and cc.r or 1, cc and cc.g or 1, cc and cc.b or 1, 1, 1, 1)
            total = total + char.gold
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total:", Fmt:FormatMoney(total), 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Open Bags", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Settings", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:Show()
    -- Graph
    if self.history:Count() > MIN_HISTORY_POINTS then
        if not self.graphFrame then
            self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
            self.graphFrame:SetSize(GRAPH_WIDTH, GRAPH_HEIGHT)
            self.graph = DT.Graph:New(self.graphFrame, GRAPH_WIDTH, GRAPH_HEIGHT)
        end
        self.graphFrame:SetParent(GameTooltip)
        self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, GRAPH_OFFSET_Y)
        self.graphFrame:Show()
        self.graph:Clear()
        self.graph:SetColor(1, 0.84, 0, 1)
        for _, val in self.history:Iterate() do self.graph:AddData(val) end
        self.graph:Draw()
    elseif self.graphFrame then
        self.graphFrame:Hide()
    end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------
function W:Init()
    self:CreateFrame()
    self.sessionStart = GetMoney()
    self.sessionStartTime = GetTime()
    self.lastHistoryTime = GetTime()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, btn) if btn == "RightButton" then self:ShowContextMenu() else ToggleAllBags() end end)
    self.leftClickHint = "Open Bags"
    self.rightClickHint = "Settings"
    self:RegisterEvent("PLAYER_MONEY", function() self:OnMoneyChange() end)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:OnMoneyChange() end)
    self:RegisterEvent("MERCHANT_SHOW", function() self:AutoSellJunk() end)
    self:SetCategory("GAMEPLAY")
    self:Register()
    self:Update()
end

W:Init()
