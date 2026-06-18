-- [ SPOTLIGHT HELP SOURCE ]--------------------------------------------------------------------------
-- Static authored content. No events: builds once on first Open. Entries come from the Help registry.
local _, Orbit = ...
local Tokenize = Orbit.Spotlight.Search.Tokenize
local Sources = Orbit.Spotlight.Index.Sources
local Help = Orbit.Spotlight.Index.Help

local HELP_ICON = "Interface\\common\\help-i"

local HelpSource = {
    kind = "help",
    events = {},
    persistent = false,
}
Sources.help = HelpSource

function HelpSource:Build()
    local entries = Help:GetAll()
    for i = 1, #entries do
        local e = entries[i]
        e.kind = "help"
        e.icon = e.icon or HELP_ICON
        -- lowerName is the search bag: topic + label + optional keywords so "help cooldown manager" hits too.
        e.lowerName = Tokenize:Fold((e.topic or "") .. " " .. (e.name or "") .. " " .. (e.keywords or ""))
    end
    return entries
end
