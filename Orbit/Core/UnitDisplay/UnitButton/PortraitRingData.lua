-- [ PORTRAIT RING DATA ]----------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local DEFAULT_OVERSHOOT = 3
local FLIPBOOK_ROWS = 6
local FLIPBOOK_COLS = 6
local FLIPBOOK_FRAMES = 36
local FLIPBOOK_DURATION = 4

-- [ FLIPBOOK FACTORY ]------------------------------------------------------------------------------
local function FlipbookRing(atlas)
    return { atlas = atlas, overshoot = DEFAULT_OVERSHOOT, rows = FLIPBOOK_ROWS, cols = FLIPBOOK_COLS, frames = FLIPBOOK_FRAMES, duration = FLIPBOOK_DURATION }
end

-- [ RING DATA ]-------------------------------------------------------------------------------------
local GOLD_ENTRY = { atlas = "hud-PlayerFrame-portraitring-large", overshoot = DEFAULT_OVERSHOOT }

Engine.PortraitRingData = {
    none = {},
    gold = GOLD_ENTRY,
    ["hud-PlayerFrame-portraitring-large"] = GOLD_ENTRY,
    alchemy = FlipbookRing("SpecDial_Fill_Flipbook_Alchemy"),
    blacksmithing = FlipbookRing("SpecDial_Fill_Flipbook_Blacksmithing"),
    enchanting = FlipbookRing("SpecDial_Fill_Flipbook_Enchanting"),
    engineering = FlipbookRing("SpecDial_Fill_Flipbook_Engineering"),
    herbalism = FlipbookRing("SpecDial_Fill_Flipbook_Herbalism"),
    inscription = FlipbookRing("SpecDial_Fill_Flipbook_Inscription"),
    jewelcrafting = FlipbookRing("SpecDial_Fill_Flipbook_Jewelcrafting"),
    leatherworking = FlipbookRing("SpecDial_Fill_Flipbook_Leatherworking"),
    mining = FlipbookRing("SpecDial_Fill_Flipbook_Mining"),
    skinning = FlipbookRing("SpecDial_Fill_Flipbook_Skinning"),
    tailoring = FlipbookRing("SpecDial_Fill_Flipbook_Tailoring"),
}

Engine.PortraitRingOptions = {
    { text = "None", value = "none" },
    { text = "Gold Ring", value = "gold" },
    { text = "Alchemy", value = "alchemy" },
    { text = "Blacksmithing", value = "blacksmithing" },
    { text = "Enchanting", value = "enchanting" },
    { text = "Engineering", value = "engineering" },
    { text = "Herbalism", value = "herbalism" },
    { text = "Inscription", value = "inscription" },
    { text = "Jewelcrafting", value = "jewelcrafting" },
    { text = "Leatherworking", value = "leatherworking" },
    { text = "Mining", value = "mining" },
    { text = "Skinning", value = "skinning" },
    { text = "Tailoring", value = "tailoring" },
}

Engine.PORTRAIT_RING_OVERSHOOT = DEFAULT_OVERSHOOT
