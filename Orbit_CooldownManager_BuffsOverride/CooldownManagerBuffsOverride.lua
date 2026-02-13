---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon

local overridenCooldowns = {
    -- Blade Flurry
    [11873] = {
        point = "BOTTOMRIGHT",
        relativeTo = "OrbitPlayerResources",
        relativePoint = "TOPRIGHT",
        offsetX = 0,
        offsetY = 2,
    },
    -- Roll the Bones
    [42743] = {
        point = "BOTTOMLEFT",
        relativeTo = "OrbitPlayerResources",
        relativePoint = "TOPLEFT",
        offsetX = 0,
        offsetY = 2,
    },
}

local original_CDM_ProcessChildren = CDM.ProcessChildren;
function CDM:ProcessChildren(...)
    original_CDM_ProcessChildren(self, ...)

    local anchor = ...;
    if not anchor or anchor.systemIndex ~= BUFFICON_INDEX then return end
    local entry = VIEWER_MAP[anchor.systemIndex]
    local blizzFrame = entry and entry.viewer
    if not blizzFrame then return end

    local activeChildren = {}

    for i, child in ipairs({ blizzFrame:GetChildren() }) do
        if child.layoutIndex then
            if child:IsShown() then
                table.insert(activeChildren, child)
            end
        end
    end

    table.sort(activeChildren, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)

    if Orbit.Skin.Icons and #activeChildren > 0 then
        local hGrowth = CDM:GetHorizontalGrowth(anchor) or nil
        local vGrowth = CDM:GetGrowthDirection(anchor)
        local skinSettings = CooldownUtils:BuildSkinSettings(CDM, anchor.systemIndex, { verticalGrowth = vGrowth, horizontalGrowth = hGrowth })

        local activeChildrenWithoutOverride = {}
        for _, child in ipairs(activeChildren) do
            if not (overridenCooldowns and overridenCooldowns[child:GetCooldownID()]) then
                table.insert(activeChildrenWithoutOverride, child)
            else
                local cd = overridenCooldowns[child:GetCooldownID()]
                child:ClearAllPoints()
                child:SetPoint(cd.point, cd.relativeTo, cd.relativePoint, cd.offsetX, cd.offsetY)
            end
        end

        Orbit.Skin.Icons:ApplyManualLayout(blizzFrame, activeChildrenWithoutOverride, skinSettings)
    end
end
