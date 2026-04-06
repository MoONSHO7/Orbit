-- Performance.lua
-- System performance datatext: FPS, latency, memory, addon usage, sparkline graph
local _, Orbit = ...
local DT = Orbit.Datatexts
local Fmt = DT.Formatting
local RingBuffer = Fmt.RingBuffer

-- [ CONSTANTS ] -------------------------------------------------------------------
local FPS_CRITICAL = 15
local FPS_LOW = 30
local FPS_HIGH = 60
local LATENCY_LOW = 100
local LATENCY_HIGH = 200
local KB_PER_MB = 1024
local TOP_ADDON_DEFAULT = 5
local TOP_ADDON_SHIFT = 10
local GRAPH_WIDTH = 200
local GRAPH_HEIGHT = 50
local GRAPH_OFFSET_Y = -5
local HISTORY_SIZE = 60
local FRAME_WIDTH = 120
local FRAME_HEIGHT = 20
local TREND_WINDOW = 10
local JITTER_THRESHOLD_MS = 50
local ADDON_CACHE_TTL = 10

local COLORS = { GREEN = "|cff00ff00", YELLOW = "|cfffea300", ORANGE = "|cffff6600", RED = "|cffff0000" }

-- [ datatext ] ----------------------------------------------------------------------
local W = DT.BaseDatatext:New("Performance")

-- [ STATE ] -----------------------------------------------------------------------
W.history = { fps = RingBuffer:New(HISTORY_SIZE), latency = RingBuffer:New(HISTORY_SIZE), memory = RingBuffer:New(HISTORY_SIZE) }
W.addonCache = nil
W.addonCacheTime = 0

-- [ HELPERS ] ---------------------------------------------------------------------
local function FPSColor(fps)
    if fps >= FPS_HIGH then return COLORS.GREEN
    elseif fps >= FPS_LOW then return COLORS.YELLOW
    elseif fps >= FPS_CRITICAL then return COLORS.ORANGE
    else return COLORS.RED end
end

local function LatencyColor(ms)
    if ms <= LATENCY_LOW then return COLORS.GREEN
    elseif ms <= LATENCY_HIGH then return COLORS.YELLOW
    else return COLORS.RED end
end

local function MemoryTrend(hist)
    if hist:Count() < TREND_WINDOW then return "" end
    local recent, older = hist:Last(0), hist:Last(TREND_WINDOW - 1)
    if recent > older then return "|cffff0000(+)|r"
    elseif recent < older then return "|cff00ff00(-)|r"
    else return "" end
end

local function HistoryStats(ring)
    if ring:Count() == 0 then return 0, 0, 0, 0 end
    local min, max, sum = ring:Nth(1), ring:Nth(1), 0
    for _, v in ring:Iterate() do
        if v < min then min = v end
        if v > max then max = v end
        sum = sum + v
    end
    local avg = sum / ring:Count()
    local variance = 0
    for _, v in ring:Iterate() do variance = variance + (v - avg) * (v - avg) end
    return min, max, avg, math.sqrt(variance / ring:Count())
end

-- [ UPDATE ] ----------------------------------------------------------------------
function W:Update()
    local fps = GetFramerate()
    local _, _, _, world = GetNetStats()
    self.history.fps:Push(fps)
    self.history.latency:Push(world)
    self:SetText(string.format("%s%d|rfps %s%d|rms", FPSColor(fps), math.floor(fps), LatencyColor(world), world))
end

function W:UpdateMemory()
    self.history.memory:Push(collectgarbage("count") / KB_PER_MB)
end

function W:RefreshAddonCache()
    local addons = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local m = GetAddOnMemoryUsage(i)
        if m > 0 then
            local name, title = C_AddOns.GetAddOnInfo(i)
            addons[#addons + 1] = { name = title or name, mem = m }
        end
    end
    table.sort(addons, function(a, b) return a.mem > b.mem end)
    self.addonCache = addons
    self.addonCacheTime = GetTime()
end

-- [ TOOLTIP ] ---------------------------------------------------------------------
function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("System Performance", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    local fps = GetFramerate()
    local _, _, home, world = GetNetStats()
    local mem = collectgarbage("count") / KB_PER_MB
    GameTooltip:AddDoubleLine("FPS:", string.format("%.1f", fps), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Home Latency:", string.format("%dms", home), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("World Latency:", string.format("%dms", world), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Memory:", string.format("%.2f MB %s", mem, MemoryTrend(self.history.memory)), 1, 1, 1, 1, 1, 1)
    local shiftHeld = IsShiftKeyDown()
    if shiftHeld then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Extended Stats", 0.7, 0.7, 0.7)
        local fMin, fMax, fAvg = HistoryStats(self.history.fps)
        GameTooltip:AddDoubleLine("FPS Min/Avg/Max:", string.format("%.0f / %.0f / %.0f", fMin, fAvg, fMax), 1, 1, 1, 0.7, 0.7, 0.7)
        local _, peakMem = HistoryStats(self.history.memory)
        GameTooltip:AddDoubleLine("Peak Memory:", string.format("%.2f MB", peakMem), 1, 1, 1, 0.7, 0.7, 0.7)
        local _, _, _, jitter = HistoryStats(self.history.latency)
        local jitterColor = jitter > JITTER_THRESHOLD_MS and "|cffff0000" or "|cff00ff00"
        GameTooltip:AddDoubleLine("Network Jitter:", string.format("%s%.1fms|r stddev", jitterColor, jitter), 1, 1, 1, 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(" ")
    local addonCount = shiftHeld and TOP_ADDON_SHIFT or TOP_ADDON_DEFAULT
    GameTooltip:AddLine(string.format("Top %d Addons (Memory):", addonCount), 0.7, 0.7, 0.7)
    if not self.addonCache or GetTime() - self.addonCacheTime > ADDON_CACHE_TTL then self:RefreshAddonCache() end
    local addons = self.addonCache or {}
    for i = 1, math.min(addonCount, #addons) do
        GameTooltip:AddDoubleLine(addons[i].name, Fmt:FormatMemory(addons[i].mem), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Click", "Collect Garbage", 0.7, 0.7, 0.7, 1, 1, 1)
    if not shiftHeld then GameTooltip:AddDoubleLine("Shift+Hover", "Extended Stats", 0.7, 0.7, 0.7, 1, 1, 1) end
    GameTooltip:Show()
    -- Graph
    if not self.graphFrame then
        self.graphFrame = CreateFrame("Frame", nil, GameTooltip)
        self.graphFrame:SetSize(GRAPH_WIDTH, GRAPH_HEIGHT)
        self.graph = DT.Graph:New(self.graphFrame, GRAPH_WIDTH, GRAPH_HEIGHT)
    end
    self.graphFrame:SetParent(GameTooltip)
    self.graphFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, GRAPH_OFFSET_Y)
    self.graphFrame:Show()
    self.graph:Clear()
    self.graph:SetColor(0, 1, 0, 1)
    for _, val in self.history.fps:Iterate() do self.graph:AddData(val) end
    self.graph:Draw()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------
function W:Init()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetUpdateTier("NORMAL")
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function() collectgarbage("collect"); self:RefreshAddonCache(); print("|cff00ff00Memory Garbage Collected|r"); self:Update() end)
    self.leftClickHint = "Collect Garbage"
    self:SetCategory("SYSTEM")
    self:Register()
    DT.DatatextManager:RegisterForScheduler(self.name .. "_mem", "SLOW", function() self:UpdateMemory() end)
end

W:Init()
