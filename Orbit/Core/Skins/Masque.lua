local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin

-- [ MASQUE BRIDGE ]---------------------------------------------------------------------------------
local MasqueBridge = {}
Skin.Masque = MasqueBridge

local MSQ = LibStub and LibStub("Masque", true)
local ADDON_NAME = "Orbit"

MasqueBridge.enabled = MSQ ~= nil
MasqueBridge.groups = {}
MasqueBridge.buttonGroups = setmetatable({}, { __mode = "k" })

local function IsTexture(obj) return obj and type(obj) == "table" and obj.SetTexture end
local function IsFontString(obj) return obj and type(obj) == "table" and obj.SetFont end
local function Region(obj) return IsTexture(obj) and obj or false end
local function TextRegion(obj) return IsFontString(obj) and obj or false end

function MasqueBridge:GetGroup(groupName)
    if not MSQ then return nil end
    if not self.groups[groupName] then
        self.groups[groupName] = MSQ:Group(ADDON_NAME, groupName)
    end
    return self.groups[groupName]
end

function MasqueBridge:AddButton(groupName, button, regions, buttonType)
    local group = self:GetGroup(groupName)
    if not group then return end
    if self.buttonGroups[button] == group then return end
    group:AddButton(button, regions, buttonType)
    self.buttonGroups[button] = group
end

function MasqueBridge:RemoveButton(button)
    local group = self.buttonGroups[button]
    if not group then return end
    group:RemoveButton(button)
    self.buttonGroups[button] = nil
end

function MasqueBridge:AddActionButton(groupName, button)
    self:AddButton(groupName, button, {
        Icon = Region(button.icon) or Region(button.Icon),
        Cooldown = button.cooldown or button.Cooldown or false,
        Normal = button.GetNormalTexture and Region(button:GetNormalTexture()),
        Pushed = button.GetPushedTexture and Region(button:GetPushedTexture()),
        Highlight = button.GetHighlightTexture and Region(button:GetHighlightTexture()),
        Checked = Region(button.CheckedTexture) or (button.GetCheckedTexture and Region(button:GetCheckedTexture())),
        HotKey = TextRegion(button.HotKey),
        Count = TextRegion(button.Count),
        Name = TextRegion(button.Name),
        Flash = Region(button.Flash),
        Border = Region(button.Border),
        AutoCastOverlay = button.AutoCastOverlay or false,
    }, "Action")
end

function MasqueBridge:AddAuraButton(groupName, button, auraType)
    self:AddButton(groupName, button, {
        Icon = Region(button.Icon) or Region(button.icon),
        Cooldown = button.Cooldown or button.cooldown or false,
        Duration = TextRegion(button.Duration) or TextRegion(button.duration),
        Count = TextRegion(button.Count) or TextRegion(button.count),
        Border = Region(button.Border),
        DebuffBorder = Region(button.DebuffBorder),
    }, auraType or "Aura")
end

function MasqueBridge:ReSkinGroup(groupName)
    local group = self:GetGroup(groupName)
    if group then group:ReSkin() end
end

