-- [ ORBIT CLASS COLOR RESOLVER ]--------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
Engine.ClassColor = {}
local CC = Engine.ClassColor

local PREVIEW_PARTY_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "HUNTER", "ROGUE" }

function CC:GetCurrentClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    if color then return { r = color.r, g = color.g, b = color.b, a = 1 } end
    return { r = 1, g = 1, b = 1, a = 1 }
end

function CC:ResolveClassColorPin(pin)
    if pin.type == "class" then return self:GetCurrentClassColor() end
    return pin.color
end

function CC:GetClassColorForUnit(unit)
    if not unit or not UnitExists(unit) then
        if unit and (unit:match("^boss") or unit:match("^arena")) then return { r = 1, g = 0.1, b = 0.1, a = 1 } end
        if unit and unit:match("^party") then
            local index = tonumber(unit:match("party(%d)")) or 1
            local classFile = PREVIEW_PARTY_CLASSES[(index - 1) % #PREVIEW_PARTY_CLASSES + 1]
            local classColor = RAID_CLASS_COLORS[classFile]
            if classColor then return { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
        end
        if unit == "player" then
            local _, classFile = UnitClass("player")
            local classColor = classFile and RAID_CLASS_COLORS[classFile]
            if classColor then return { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
        end
        return { r = 1, g = 1, b = 1, a = 1 }
    end
    if UnitIsPlayer(unit) then
        local _, classFile = UnitClass(unit)
        local classColor = classFile and RAID_CLASS_COLORS[classFile]
        if classColor then return { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
        return { r = 1, g = 1, b = 1, a = 1 }
    end
    local reaction = UnitReaction(unit, "player")
    if reaction then return Engine.ReactionColor:GetReactionColor(reaction) end
    if UnitIsFriend("player", unit) then return Engine.ReactionColor.COLORS.FRIENDLY end
    if UnitCanAttack("player", unit) then return Engine.ReactionColor.COLORS.HOSTILE end
    return Engine.ReactionColor.COLORS.NEUTRAL
end

function CC:ResolveClassColorPinForUnit(pin, unit)
    if pin.type == "class" then return self:GetClassColorForUnit(unit) end
    return pin.color
end
