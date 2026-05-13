-- Performance.lua
-- System performance datatext: FPS, latency, memory, addon usage, sparkline graph
local _, Orbit = ...
local DT = Orbit.Datatexts
local Fmt = DT.Formatting
local RingBuffer = Fmt.RingBuffer
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
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
local ADDON_CACHE_TTL = 1
local ORBIT_ADDON = "Orbit"
local PIN_REFRESH_INTERVAL = 1
local PIN_SCALE = 0.75

local COLORS = { GREEN = "|cff00ff00", YELLOW = "|cfffea300", ORANGE = "|cffff6600", RED = "|cffff0000" }

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Performance")

-- [ STATE ] -----------------------------------------------------------------------------------------
W.history = { fps = RingBuffer:New(HISTORY_SIZE), latency = RingBuffer:New(HISTORY_SIZE), memory = RingBuffer:New(HISTORY_SIZE) }
W.addonCache = nil
W.addonCacheTime = 0

-- [ HELPERS ] ---------------------------------------------------------------------------------------
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

-- [ UPDATE ] ----------------------------------------------------------------------------------------
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
    UpdateAddOnMemoryUsage()
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

-- [ TOOLTIP ] ---------------------------------------------------------------------------------------
function W:GetPinnedTooltip()
    if self.pinnedTooltip then return self.pinnedTooltip end
    local tip = CreateFrame("GameTooltip", "OrbitPerformancePinnedTooltip", UIParent, "GameTooltipTemplate")
    tip:SetScale(PIN_SCALE)
    tip:SetMovable(true)
    tip:EnableMouse(true)
    tip:RegisterForDrag("LeftButton")
    tip:SetScript("OnDragStart", function(f) f:StartMoving() end)
    tip:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint(1)
        local snappedX, snappedY = Orbit.Engine.Pixel:SnapPosition(x, y, point, f:GetWidth(), f:GetHeight(), f:GetEffectiveScale())
        self.pinnedPos = { point = point, relPoint = relPoint, x = snappedX, y = snappedY }
    end)
    self.pinnedTooltip = tip
    return tip
end

function W:PopulateTooltip(tip)
    tip:SetOwner(self.frame, "ANCHOR_TOP")
    tip:ClearLines()
    tip:AddLine(L.PLU_DT_PERF_TITLE, 1, 0.82, 0)
    tip:AddLine(" ")
    local fps = GetFramerate()
    local _, _, home, world = GetNetStats()
    local mem = collectgarbage("count") / KB_PER_MB
    tip:AddDoubleLine(L.PLU_DT_PERF_FPS, string.format("%.1f", fps), 1, 1, 1, 1, 1, 1)
    tip:AddDoubleLine(L.PLU_DT_PERF_HOME_LATENCY, string.format("%dms", home), 1, 1, 1, 1, 1, 1)
    tip:AddDoubleLine(L.PLU_DT_PERF_WORLD_LATENCY, string.format("%dms", world), 1, 1, 1, 1, 1, 1)
    tip:AddDoubleLine(L.PLU_DT_PERF_MEMORY, string.format("%.2f MB %s", mem, MemoryTrend(self.history.memory)), 1, 1, 1, 1, 1, 1)
    if C_AddOnProfiler and C_AddOnProfiler.IsEnabled() then
        local M = Enum.AddOnProfilerMetric
        local recent = C_AddOnProfiler.GetApplicationMetric(M.RecentAverageTime)
        local peak = C_AddOnProfiler.GetApplicationMetric(M.PeakTime)
        local orbitRecent = C_AddOnProfiler.GetAddOnMetric(ORBIT_ADDON, M.RecentAverageTime)
        local orbitPeak = C_AddOnProfiler.GetAddOnMetric(ORBIT_ADDON, M.PeakTime)
        local pctAvg = recent > 0 and (orbitRecent / recent * 100) or 0
        local pctPeak = peak > 0 and (orbitPeak / peak * 100) or 0
        tip:AddDoubleLine(L.PLU_DT_PERF_ORBIT_CPU_AVG, string.format("%.1f%%", pctAvg), 1, 1, 1, 1, 1, 1)
        tip:AddDoubleLine(L.PLU_DT_PERF_ORBIT_CPU_PEAK, string.format("%.1f%%", pctPeak), 1, 1, 1, 1, 1, 1)
    else
        tip:AddDoubleLine(L.PLU_DT_PERF_ORBIT_CPU, "|cff888888" .. L.PLU_DT_PERF_PROFILER_DISABLED .. "|r", 1, 1, 1, 0.7, 0.7, 0.7)
    end
    local shiftHeld = IsShiftKeyDown() or self.isPinned
    if shiftHeld then
        tip:AddLine(" ")
        tip:AddLine(L.PLU_DT_PERF_EXTENDED, 0.7, 0.7, 0.7)
        local fMin, fMax, fAvg = HistoryStats(self.history.fps)
        tip:AddDoubleLine(L.PLU_DT_PERF_FPS_MIN_AVG_MAX, string.format("%.0f / %.0f / %.0f", fMin, fAvg, fMax), 1, 1, 1, 0.7, 0.7, 0.7)
        local _, peakMem = HistoryStats(self.history.memory)
        tip:AddDoubleLine(L.PLU_DT_PERF_PEAK_MEMORY, string.format("%.2f MB", peakMem), 1, 1, 1, 0.7, 0.7, 0.7)
        local _, _, _, jitter = HistoryStats(self.history.latency)
        local jitterColor = jitter > JITTER_THRESHOLD_MS and "|cffff0000" or "|cff00ff00"
        tip:AddDoubleLine(L.PLU_DT_PERF_NETWORK_JITTER, string.format("%s%.1fms|r %s", jitterColor, jitter, L.PLU_DT_PERF_STDDEV), 1, 1, 1, 0.7, 0.7, 0.7)
    end
    tip:AddLine(" ")
    local addonCount = shiftHeld and TOP_ADDON_SHIFT or TOP_ADDON_DEFAULT
    tip:AddLine(L.PLU_DT_PERF_TOP_ADDONS_F:format(addonCount), 0.7, 0.7, 0.7)
    if not self.addonCache or GetTime() - self.addonCacheTime > ADDON_CACHE_TTL then self:RefreshAddonCache() end
    local addons = self.addonCache or {}
    for i = 1, math.min(addonCount, #addons) do
        tip:AddDoubleLine(addons[i].name, Fmt:FormatMemory(addons[i].mem), 1, 1, 1, 1, 1, 1)
    end
    if not self.isPinned then
        tip:AddLine(" ")
        tip:AddDoubleLine(L.CMN_LEFT_CLICK, L.PLU_DT_PERF_COLLECT_GARBAGE, 0.7, 0.7, 0.7, 1, 1, 1)
        tip:AddDoubleLine(L.CMN_RIGHT_CLICK, L.PLU_DT_PERF_PIN_TOOLTIP, 0.7, 0.7, 0.7, 1, 1, 1)
        if not shiftHeld then tip:AddDoubleLine(L.PLU_DT_PERF_SHIFT_HOVER, L.PLU_DT_PERF_EXTENDED, 0.7, 0.7, 0.7, 1, 1, 1) end
    end
    tip:Show()
    if not self.graphFrame then
        self.graphFrame = CreateFrame("Frame", nil, UIParent)
        self.graphFrame:SetSize(GRAPH_WIDTH, GRAPH_HEIGHT)
        self.graph = DT.Graph:New(self.graphFrame, GRAPH_WIDTH, GRAPH_HEIGHT)
    end
    self.graphFrame:SetParent(tip)
    self.graphFrame:ClearAllPoints()
    self.graphFrame:SetPoint("TOP", tip, "BOTTOM", 0, GRAPH_OFFSET_Y)
    self.graphFrame:Show()
    self.graph:Clear()
    self.graph:SetColor(0, 1, 0, 1)
    for _, val in self.history.fps:Iterate() do self.graph:AddData(val) end
    self.graph:Draw()
end

function W:RefreshPinned()
    local tip = self:GetPinnedTooltip()
    self:PopulateTooltip(tip)
    if self.pinnedPos then
        tip:ClearAllPoints()
        tip:SetPoint(self.pinnedPos.point, UIParent, self.pinnedPos.relPoint, self.pinnedPos.x, self.pinnedPos.y)
    end
end

function W:ShowTooltip()
    if self.isPinned then return end
    self:PopulateTooltip(GameTooltip)
end

-- [ PIN ] -------------------------------------------------------------------------------------------
function W:TogglePin()
    self.isPinned = not self.isPinned
    if self.isPinned then
        GameTooltip:Hide()
        self:RefreshPinned()
        self.pinTicker = C_Timer.NewTicker(PIN_REFRESH_INTERVAL, function() self:RefreshPinned() end)
    else
        if self.pinTicker then self.pinTicker:Cancel(); self.pinTicker = nil end
        if self.graphFrame then self.graphFrame:Hide() end
        if self.pinnedTooltip then self.pinnedTooltip:Hide() end
    end
end

function W:OnLeave()
    if self.isPinned then self.isHovered = false; return end
    DT.BaseDatatext.OnLeave(self)
end

function W:HandleClick(button)
    if button == "RightButton" then self:TogglePin(); return end
    collectgarbage("collect"); self:RefreshAddonCache(); print("|cff00ff00" .. L.PLU_DT_PERF_GC_DONE .. "|r"); self:Update()
end

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function W:Init()
    self:CreateFrame(FRAME_WIDTH, FRAME_HEIGHT)
    self:SetUpdateFunc(function() self:Update() end)
    self:SetUpdateTier("NORMAL")
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:SetClickFunc(function(_, button) self:HandleClick(button) end)
    self.leftClickHint = L.PLU_DT_PERF_COLLECT_GARBAGE
    self.rightClickHint = L.PLU_DT_PERF_PIN_TOOLTIP
    self:SetCategory("SYSTEM")
    self:Register()
    DT.DatatextManager:RegisterForScheduler(self.name .. "_mem", "SLOW", function() self:UpdateMemory() end)
end

W:Init()
