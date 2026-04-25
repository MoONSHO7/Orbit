-- [ ROW POOL ]---------------------------------------------------------------------------------------
local _, Orbit = ...
local ResultRow = Orbit.Spotlight.UI.ResultRow
local RowPool = {}
Orbit.Spotlight.UI.RowPool = RowPool

-- [ STATE ]------------------------------------------------------------------------------------------
RowPool._rows = {}
RowPool._parent = nil
RowPool._width = 0

function RowPool:Init(parent, width)
    self._parent = parent
    self._width = width
end

function RowPool:Acquire(index)
    local row = self._rows[index]
    if not row then
        row = ResultRow:Create(self._parent, self._width)
        self._rows[index] = row
    end
    return row
end

function RowPool:HideAll()
    for _, row in ipairs(self._rows) do row:Hide() end
end

function RowPool:SetWidth(width)
    self._width = width
    for _, row in ipairs(self._rows) do row:SetWidth(width) end
end
