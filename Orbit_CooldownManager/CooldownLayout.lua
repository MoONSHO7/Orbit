---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap

-- [ PROCESS CHILDREN ]------------------------------------------------------------------------------
function CDM:ProcessChildren(anchor)
    if not anchor then return end

    local entry = VIEWER_MAP[anchor.systemIndex]
    local blizzFrame = entry and entry.viewer
    if not blizzFrame then return end

    local systemIndex = anchor.systemIndex
    local activeChildren = {}
    local plugin = self

    for _, child in ipairs({ blizzFrame:GetChildren() }) do
        if child.layoutIndex then
            if not child.orbitOnShowHooked then
                child:HookScript("OnShow", function(c)
                    local parent = c:GetParent()
                    local anc = parent and parent:GetParent()
                    if Orbit.Skin.Icons and Orbit.Skin.Icons.frameSettings then
                        local s = Orbit.Skin.Icons.frameSettings[parent]
                        if s then Orbit.Skin.Icons:ApplyCustom(c, s) end
                    end
                    if anc and plugin.ProcessChildren then plugin:ProcessChildren(anc) end
                end)
                child.orbitOnShowHooked = true
            end
            if child:IsShown() then table.insert(activeChildren, child) end
        end
    end

    table.sort(activeChildren, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)

    if Orbit.Skin.Icons and #activeChildren > 0 then
        local skinSettings = CooldownUtils:BuildSkinSettings(self, systemIndex, { verticalGrowth = self:GetGrowthDirection(anchor) })

        if not Orbit.Skin.Icons.frameSettings then Orbit.Skin.Icons.frameSettings = setmetatable({}, { __mode = "k" }) end
        Orbit.Skin.Icons.frameSettings[blizzFrame] = skinSettings

        for _, icon in ipairs(activeChildren) do
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
            self:HookGCDSwipe(icon, systemIndex)
            self:ApplyTextSettings(icon, systemIndex)
        end

        Orbit.Skin.Icons:ApplyManualLayout(blizzFrame, activeChildren, skinSettings)

        if not InCombatLockdown() then
            local w, h = blizzFrame:GetSize()
            if w and h and w > 0 and h > 0 then anchor:SetSize(w, h) end
            anchor.orbitRowHeight = blizzFrame.orbitRowHeight
            anchor.orbitColumnWidth = blizzFrame.orbitColumnWidth
        end
    end
end

-- [ GCD SWIPE HOOK ]--------------------------------------------------------------------------------
function CDM:HookGCDSwipe(icon, systemIndex)
    if icon.orbitGCDHooked or not icon.RefreshSpellCooldownInfo then return end
    icon.orbitSystemIndex = systemIndex
    icon.orbitPlugin = self

    hooksecurefunc(icon, "RefreshSpellCooldownInfo", function(self)
        local plugin = self.orbitPlugin
        local sysIdx = self.orbitSystemIndex
        if not plugin or not sysIdx then return end

        local showGCD = plugin:GetSetting(sysIdx, "ShowGCDSwipe")
        if showGCD then return end

        if self.isOnGCD and not self.wasSetFromAura then
            local cooldown = self:GetCooldownFrame()
            if cooldown then cooldown:SetDrawSwipe(false) end
        end
    end)
    icon.orbitGCDHooked = true
end

-- [ GROWTH DIRECTION ]------------------------------------------------------------------------------
function CDM:GetGrowthDirection(anchorFrame)
    if not anchorFrame then return "DOWN" end
    local anchorInfo = OrbitEngine.FrameAnchor and OrbitEngine.FrameAnchor.anchors[anchorFrame]
    if not anchorInfo then return "DOWN" end
    return anchorInfo.edge == "TOP" and "UP" or "DOWN"
end
