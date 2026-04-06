-- Formatting.lua
-- Number, money, time formatting and RingBuffer for Datatexts datatexts
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------
local THRESHOLD_K = 1000
local THRESHOLD_M = 1000000
local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local MEM_DISPLAY_THRESHOLD_KB = 1000

-- [ FORMATTING ] ------------------------------------------------------------------
local Formatting = {}
DT.Formatting = Formatting

function Formatting:FormatNumber(num)
    if num >= THRESHOLD_M then return string.format("%.1fM", num / THRESHOLD_M)
    elseif num >= THRESHOLD_K then return string.format("%.1fK", num / THRESHOLD_K)
    else return string.format("%d", num) end
end

function Formatting:FormatMoney(copper, full)
    local gold = math.floor(copper / COPPER_PER_GOLD)
    local silver = math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local cop = copper % COPPER_PER_SILVER
    if full then return string.format("|cffffd700%d|rg |cffc0c0c0%d|rs |cffeda55f%d|rc", gold, silver, cop) end
    if gold >= THRESHOLD_M then return string.format("|cffffd700%.2fm|r", gold / THRESHOLD_M)
    elseif gold >= THRESHOLD_K then return string.format("|cffffd700%.1fk|r", gold / THRESHOLD_K)
    elseif gold > 0 then return string.format("|cffffd700%d|rg |cffc0c0c0%d|rs", gold, silver)
    else return string.format("|cffc0c0c0%d|rs |cffeda55f%d|rc", silver, cop) end
end

function Formatting:FormatTime(seconds)
    if not seconds or seconds == math.huge then return "N/A" end
    if seconds < SECONDS_PER_MINUTE then return string.format("%ds", math.floor(seconds)) end
    if seconds < SECONDS_PER_HOUR then return string.format("%dm", math.floor(seconds / SECONDS_PER_MINUTE)) end
    return string.format("%dh %dm", math.floor(seconds / SECONDS_PER_HOUR), math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE))
end

function Formatting:FormatTimeShort(seconds)
    if seconds < SECONDS_PER_MINUTE then return string.format("%d", math.floor(seconds)) end
    if seconds < SECONDS_PER_HOUR then return string.format("%d:%02d", math.floor(seconds / SECONDS_PER_MINUTE), math.floor(seconds % SECONDS_PER_MINUTE)) end
    return string.format("%d:%02d:%02d", math.floor(seconds / SECONDS_PER_HOUR), math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE), math.floor(seconds % SECONDS_PER_MINUTE))
end

function Formatting:GetColor(value, max, inverse)
    local pct = (value / max) * 100
    if inverse then
        if pct < 50 then return "|cff00ff00" end
        if pct < 80 then return "|cffffa500" end
        return "|cffff0000"
    else
        if pct < 20 then return "|cffff0000" end
        if pct < 50 then return "|cffffa500" end
        return "|cff00ff00"
    end
end

function Formatting:FormatMemory(kb)
    if kb > MEM_DISPLAY_THRESHOLD_KB then return string.format("%.2f MB", kb / MEM_DISPLAY_THRESHOLD_KB) end
    return string.format("%.0f KB", kb)
end

-- [ RING BUFFER ] -----------------------------------------------------------------
local RingBuffer = {}
RingBuffer.__index = RingBuffer
Formatting.RingBuffer = RingBuffer

function RingBuffer:New(capacity)
    return setmetatable({ data = {}, capacity = capacity, head = 0, count = 0 }, RingBuffer)
end

function RingBuffer:Push(value)
    self.head = (self.head % self.capacity) + 1
    self.data[self.head] = value
    if self.count < self.capacity then self.count = self.count + 1 end
end

function RingBuffer:Clear()
    self.head = 0
    self.count = 0
end

function RingBuffer:Iterate()
    local i = 0
    local start = (self.head - self.count) % self.capacity
    return function()
        i = i + 1
        if i > self.count then return nil end
        return i, self.data[(start + i - 1) % self.capacity + 1]
    end
end

function RingBuffer:Last(offset)
    offset = offset or 0
    if offset >= self.count then return nil end
    return self.data[(self.head - 1 - offset) % self.capacity + 1]
end

function RingBuffer:Nth(n)
    if n < 1 or n > self.count then return nil end
    local start = (self.head - self.count) % self.capacity
    return self.data[(start + n - 1) % self.capacity + 1]
end

function RingBuffer:Count() return self.count end
