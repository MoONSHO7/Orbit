---@type Orbit
local Orbit = Orbit

-- [ PLAYER DUMMIES ] --------------------------------------------------------------------------------
-- Roster guarantees: all 13 classes represented, at least 5 tanks / 10 healers / 30 dps for World raid.

Orbit.PlayerDummies = {
    -- [ TANKS (5) ] ---------------------------------------------------------
    { name = "Bolvar",      classFilename = "PALADIN",     role = "TANK"    },
    { name = "Garrosh",     classFilename = "WARRIOR",     role = "TANK"    },
    { name = "Illidan",     classFilename = "DEMONHUNTER", role = "TANK"    },
    { name = "Chen",        classFilename = "MONK",        role = "TANK"    },
    { name = "Saurfang",    classFilename = "WARRIOR",     role = "TANK"    },

    -- [ HEALERS (10) ] ------------------------------------------------------
    { name = "Anduin",      classFilename = "PRIEST",      role = "HEALER"  },
    { name = "Tyrande",     classFilename = "PRIEST",      role = "HEALER"  },
    { name = "Velen",       classFilename = "PRIEST",      role = "HEALER"  },
    { name = "Aggra",       classFilename = "SHAMAN",      role = "HEALER"  },
    { name = "Moira",       classFilename = "PRIEST",      role = "HEALER"  },
    { name = "Calia",       classFilename = "PRIEST",      role = "HEALER"  },
    { name = "Liadrin",     classFilename = "PALADIN",     role = "HEALER"  },
    { name = "Talanji",     classFilename = "PRIEST",      role = "HEALER"  },
    { name = "Rehgar",      classFilename = "SHAMAN",      role = "HEALER"  },
    { name = "Nobundo",     classFilename = "SHAMAN",      role = "HEALER"  },

    -- [ DPS (30) ] ----------------------------------------------------------
    { name = "Arthas",      classFilename = "DEATHKNIGHT", role = "DAMAGER" },
    { name = "Jaina",       classFilename = "MAGE",        role = "DAMAGER" },
    { name = "Thrall",      classFilename = "SHAMAN",      role = "DAMAGER" },
    { name = "Sylvanas",    classFilename = "HUNTER",      role = "DAMAGER" },
    { name = "Khadgar",     classFilename = "MAGE",        role = "DAMAGER" },
    { name = "Gul'dan",     classFilename = "WARLOCK",     role = "DAMAGER" },
    { name = "Malfurion",   classFilename = "DRUID",       role = "DAMAGER" },
    { name = "Genn",        classFilename = "WARRIOR",     role = "DAMAGER" },
    { name = "Rexxar",      classFilename = "HUNTER",      role = "DAMAGER" },
    { name = "Alleria",     classFilename = "HUNTER",      role = "DAMAGER" },
    { name = "Vol'jin",     classFilename = "ROGUE",       role = "DAMAGER" },
    { name = "Maiev",       classFilename = "ROGUE",       role = "DAMAGER" },
    { name = "Rokhan",      classFilename = "ROGUE",       role = "DAMAGER" },
    { name = "Lor'themar",  classFilename = "HUNTER",      role = "DAMAGER" },
    { name = "Wrathion",    classFilename = "EVOKER",      role = "DAMAGER" },
    { name = "Wilfred",     classFilename = "WARLOCK",     role = "DAMAGER" },
    { name = "Broxigar",    classFilename = "WARRIOR",     role = "DAMAGER" },
    { name = "Chromie",     classFilename = "MAGE",        role = "DAMAGER" },
    { name = "Taran Zhu",   classFilename = "MONK",        role = "DAMAGER" },
    { name = "Magni",       classFilename = "SHAMAN",      role = "DAMAGER" },
    { name = "Nazgrim",     classFilename = "DEATHKNIGHT", role = "DAMAGER" },
    { name = "Halduron",    classFilename = "HUNTER",      role = "DAMAGER" },
    { name = "Yrel",        classFilename = "PALADIN",     role = "DAMAGER" },
    { name = "Alexstrasza", classFilename = "EVOKER",      role = "DAMAGER" },
    { name = "Turalyon",    classFilename = "PALADIN",     role = "DAMAGER" },
    { name = "Baine",       classFilename = "WARRIOR",     role = "DAMAGER" },
    { name = "Muradin",     classFilename = "WARRIOR",     role = "DAMAGER" },
    { name = "Kael'thas",   classFilename = "MAGE",        role = "DAMAGER" },
    { name = "Darion",      classFilename = "DEATHKNIGHT", role = "DAMAGER" },
    { name = "Drek'thar",   classFilename = "SHAMAN",      role = "DAMAGER" },
}

-- Fisher-Yates. Mutates indices in place, returns it.
local function Shuffle(indices)
    for i = #indices, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    return indices
end

function Orbit.PlayerDummies:ShuffleIndices(role)
    local out = {}
    for i, entry in ipairs(self) do
        if not role or entry.role == role then out[#out + 1] = i end
    end
    return Shuffle(out)
end
