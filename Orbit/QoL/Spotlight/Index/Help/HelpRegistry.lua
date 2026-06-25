-- [ SPOTLIGHT HELP REGISTRY ]------------------------------------------------------------------------
-- Topic files register their help entries here at load; the Help source reads GetAll() at build time.
local _, Orbit = ...

local Help = {}
Orbit.Spotlight.Index.Help = Help

Help._entries = {}

function Help:Register(entries)
    local list = self._entries
    for i = 1, #entries do list[#list + 1] = entries[i] end
end

function Help:GetAll() return self._entries end
