---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_PlayerPrivateAura"
local SYSTEM_INDEX = 1
local ICON_SIZE = 24
local MAX_ANCHORS = Orbit.Constants.GroupFrames.MaxPrivateAuraAnchors

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Player Private Auras", SYSTEM_ID, {
    liveToggle = true,
    defaults = {},
})

local Frame

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    Frame = CreateFrame("Frame", "OrbitPlayerPrivateAuraFrame", UIParent)
    Frame:SetSize(MAX_ANCHORS * ICON_SIZE, ICON_SIZE)
    Frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    Frame.editModeName = "Player Private Auras"
    Frame.systemIndex = SYSTEM_INDEX
    Frame.system = SYSTEM_ID
    Frame.orbitPlugin = self
    Frame.unit = "player"
    Frame.anchorOptions = { horizontal = false, vertical = false }

    -- Private aura anchor child
    Frame.PrivateAuraAnchor = Frame
    Frame._privateAuraIDs = {}

    self._agFrame = Frame
    self.frame = Frame

    OrbitEngine.Frame:AttachSettingsListener(Frame, self, SYSTEM_INDEX)
    OrbitEngine.Frame:RestorePosition(Frame, self, SYSTEM_INDEX)

    -- Register for aura change events
    Frame:RegisterUnitEvent("UNIT_AURA", "player")
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    Frame:SetScript("OnEvent", function() self:UpdateAnchors() end)

    -- Edit Mode
    OrbitEngine.EditMode:RegisterCallbacks({
        Enter = function() Frame:Show() end,
        Exit = function() self:UpdateAnchors() end,
    }, self)

    self:UpdateAnchors()
    self:RegisterStandardEvents()
end

-- [ ANCHOR MANAGEMENT ]-----------------------------------------------------------------------------
function Plugin:UpdateAnchors()
    if not Frame then return end
    Orbit.PrivateAuraMixin:Update(Frame, self, ICON_SIZE)
end
