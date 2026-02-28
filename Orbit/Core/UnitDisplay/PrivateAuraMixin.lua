-- [ PRIVATE AURA MIXIN ]---------------------------------------------------------------------------
-- Shared private aura anchor creation and management for group frames (Party, Raid)

local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local GF = Orbit.Constants.GroupFrames
local MAX_PRIVATE_AURA_ANCHORS = GF.MaxPrivateAuraAnchors

Orbit.PrivateAuraMixin = {}
local Mixin = Orbit.PrivateAuraMixin

-- [ ANCHOR REMOVAL ]-------------------------------------------------------------------------------
function Mixin:RemoveAnchors(frame)
    if not frame._privateAuraIDs then return end
    for _, id in ipairs(frame._privateAuraIDs) do C_UnitAuras.RemovePrivateAuraAnchor(id) end
    wipe(frame._privateAuraIDs)
end

-- [ ANCHOR CREATION ]------------------------------------------------------------------------------
function Mixin:CreateAnchors(frame, plugin, iconSize)
    local anchor = frame.PrivateAuraAnchor
    local unit = frame.unit
    self:RemoveAnchors(frame)
    frame._privateAuraIDs = {}
    frame._privateAuraUnit = unit

    local positions = plugin.GetSetting and plugin:GetSetting(1, "ComponentPositions") or {}
    local posData = positions.PrivateAuraAnchor or {}
    local overrides = posData.overrides
    local scale = (overrides and overrides.Scale) or 1
    local size = math.floor(iconSize * scale)
    local spacing = 1
    local totalWidth = (MAX_PRIVATE_AURA_ANCHORS * size) + ((MAX_PRIVATE_AURA_ANCHORS - 1) * spacing)
    local anchorX = posData.anchorX or "CENTER"
    local eff = frame:GetEffectiveScale()

    anchor:SetSize(totalWidth, size)

    for i = 1, MAX_PRIVATE_AURA_ANCHORS do
        local point, relPoint, xOff
        if anchorX == "RIGHT" then
            xOff = OrbitEngine.Pixel:Snap(-((i - 1) * (size + spacing)), eff)
            point, relPoint = "TOPRIGHT", "TOPRIGHT"
        elseif anchorX == "LEFT" then
            xOff = OrbitEngine.Pixel:Snap((i - 1) * (size + spacing), eff)
            point, relPoint = "TOPLEFT", "TOPLEFT"
        else
            local centeredStart = -(totalWidth - size) / 2
            xOff = OrbitEngine.Pixel:Snap(centeredStart + (i - 1) * (size + spacing), eff)
            point, relPoint = "CENTER", "CENTER"
        end
        local anchorID = C_UnitAuras.AddPrivateAuraAnchor({
            unitToken = unit, auraIndex = i, parent = anchor,
            showCountdownFrame = true, showCountdownNumbers = true,
            iconInfo = {
                iconWidth = size, iconHeight = size,
                iconAnchor = { point = point, relativeTo = anchor, relativePoint = relPoint, offsetX = xOff, offsetY = 0 },
                borderScale = 1,
            },
        })
        if anchorID then frame._privateAuraIDs[#frame._privateAuraIDs + 1] = anchorID end
    end
end

-- [ UPDATE ]--------------------------------------------------------------------------------------
function Mixin:Update(frame, plugin, iconSize)
    local anchor = frame.PrivateAuraAnchor
    if not anchor then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("PrivateAuraAnchor") then
        anchor:Hide()
        return
    end

    -- Clear preview visuals from Canvas Mode
    if anchor.Icon then anchor.Icon:SetTexture(nil) end
    if anchor.SetBackdrop then anchor:SetBackdrop(nil) end
    if anchor.Border then anchor.Border:Hide() end
    if anchor.Shadow then anchor.Shadow:Hide() end

    local unit = frame.unit
    if not unit or not UnitExists(unit) then anchor:Hide() return end

    if not frame._privateAuraIDs or frame._privateAuraUnit ~= unit then
        self:CreateAnchors(frame, plugin, iconSize)
    end
    anchor:Show()
end
