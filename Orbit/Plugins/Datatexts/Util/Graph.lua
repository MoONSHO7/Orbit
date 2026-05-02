-- Graph.lua
-- Lightweight line graph renderer for datatext tooltip sparklines
local _, Orbit = ...
local DT = Orbit.Datatexts
local RingBuffer = DT.Formatting.RingBuffer

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local LINE_THICKNESS = 1
local BG_ALPHA = 0.5
local MIN_POINTS = 2

-- [ GRAPH ] -----------------------------------------------------------------------------------------
local Graph = {}
DT.Graph = Graph

function Graph:New(parent, width, height)
    local graph = { ring = RingBuffer:New(width), lines = {}, color = { r = 0, g = 1, b = 0, a = 1 }, width = width, height = height }
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    graph.frame = f
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, BG_ALPHA)

    function graph:SetColor(r, g, b, a) self.color = { r = r, g = g, b = b, a = a or 1 } end

    function graph:Clear()
        for _, line in ipairs(self.lines) do line:Hide() end
        self.ring:Clear()
    end

    function graph:AddData(value) self.ring:Push(value) end

    function graph:Draw()
        local count = self.ring:Count()
        if count < MIN_POINTS then return end
        local first = self.ring:Nth(1)
        local min, max = first, first
        for _, v in self.ring:Iterate() do
            if v < min then min = v end
            if v > max then max = v end
        end
        local range = max - min
        if range == 0 then range = 1 end
        local stepX = self.width / (count - 1)
        local idx = 0
        local prev = nil
        local graphScale = self.frame:GetEffectiveScale()
        for _, v in self.ring:Iterate() do
            if prev then
                if not self.lines[idx] then
                    self.lines[idx] = f:CreateLine()
                    self.lines[idx]:SetThickness(Orbit.Engine.Pixel:Multiple(LINE_THICKNESS, graphScale))
                end
                local line = self.lines[idx]
                line:SetColorTexture(self.color.r, self.color.g, self.color.b, self.color.a)
                local sx = Orbit.Engine.Pixel:Snap((idx - 1) * stepX, graphScale)
                local sy = Orbit.Engine.Pixel:Snap(((prev - min) / range) * self.height, graphScale)
                local ex = Orbit.Engine.Pixel:Snap(idx * stepX, graphScale)
                local ey = Orbit.Engine.Pixel:Snap(((v - min) / range) * self.height, graphScale)
                line:SetStartPoint("BOTTOMLEFT", sx, sy)
                line:SetEndPoint("BOTTOMLEFT", ex, ey)
                line:Show()
            end
            prev = v
            idx = idx + 1
        end
        for i = idx, #self.lines do self.lines[i]:Hide() end
    end

    return graph
end
