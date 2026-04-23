-- [ PRIVATE AURA MIXIN ] ----------------------------------------------------------------------------
-- Shared private aura anchor creation and management for group frames (Party, Raid)

local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local GF = Orbit.Constants.GroupFrames
local MAX_PRIVATE_AURA_ANCHORS = GF.MaxPrivateAuraAnchors
local BORDER_INSET = 2
local BORDER_SCALE_DIVISOR = 16

Orbit.PrivateAuraMixin = {}
local Mixin = Orbit.PrivateAuraMixin

-- [ ANCHOR REMOVAL ] --------------------------------------------------------------------------------
function Mixin:RemoveAnchors(frame)
    if not frame._privateAuraIDs then return end
    if InCombatLockdown() then return end
    for _, id in ipairs(frame._privateAuraIDs) do C_UnitAuras.RemovePrivateAuraAnchor(id) end
    wipe(frame._privateAuraIDs)
end

-- [ ANCHOR CREATION ] -------------------------------------------------------------------------------
function Mixin:CreateAnchors(frame, plugin, iconSize)
    local anchor = frame.PrivateAuraAnchor
    local unit = frame.unit
    self:RemoveAnchors(frame)
    frame._privateAuraIDs = {}
    frame._privateAuraUnit = unit

    local positions = plugin.GetSetting and plugin:GetSetting(1, "ComponentPositions") or {}
    local posData = positions.PrivateAuraAnchor or {}
    local overrides = posData.overrides
    local size = (overrides and overrides.IconSize) or iconSize
    local cellSize = size + BORDER_INSET * 2
    local spacing = 1
    local totalWidth = (MAX_PRIVATE_AURA_ANCHORS * cellSize) + ((MAX_PRIVATE_AURA_ANCHORS - 1) * spacing)
    local anchorX = posData.anchorX or "CENTER"
    local growDir = posData.justifyH or anchorX
    local eff = frame:GetEffectiveScale()

    anchor:SetSize(totalWidth, cellSize)

    for i = 1, MAX_PRIVATE_AURA_ANCHORS do
        local point, relPoint, xOff
        if growDir == "RIGHT" then
            xOff = OrbitEngine.Pixel:Snap(-((i - 1) * (cellSize + spacing)), eff)
            point, relPoint = "TOPRIGHT", "TOPRIGHT"
        elseif growDir == "LEFT" then
            xOff = OrbitEngine.Pixel:Snap((i - 1) * (cellSize + spacing), eff)
            point, relPoint = "TOPLEFT", "TOPLEFT"
        else
            local centeredStart = -(totalWidth - cellSize) / 2
            xOff = OrbitEngine.Pixel:Snap(centeredStart + (i - 1) * (cellSize + spacing), eff)
            point, relPoint = "CENTER", "CENTER"
        end
        local anchorID = C_UnitAuras.AddPrivateAuraAnchor({
            unitToken = unit, auraIndex = i, parent = anchor, isContainer = false,
            showCountdownFrame = true, showCountdownNumbers = true,
            iconInfo = {
                iconWidth = size, iconHeight = size, borderScale = size / BORDER_SCALE_DIVISOR,
                iconAnchor = { point = point, relativeTo = anchor, relativePoint = relPoint, offsetX = xOff, offsetY = 0 },
            },
        })
        if anchorID then frame._privateAuraIDs[#frame._privateAuraIDs + 1] = anchorID end
    end
end

-- [ UPDATE ] ----------------------------------------------------------------------------------------
function Mixin:Update(frame, plugin, iconSize)
    local anchor = frame.PrivateAuraAnchor
    if not anchor then return end
    if InCombatLockdown() then return end
    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("PrivateAuraAnchor") then
        anchor:Hide()
        return
    end

    -- Clear preview visuals from Canvas Mode
    if anchor.Icon then anchor.Icon:SetTexture(nil) end
    if anchor.SetBackdrop then anchor:SetBackdrop(nil) end
    if anchor.Border then anchor.Border:Hide() end
    if anchor.Shadow then anchor.Shadow:Hide() end
    if anchor._previewIcons then for _, sub in ipairs(anchor._previewIcons) do sub:Hide() end end

    local unit = frame.unit
    if not unit or not UnitExists(unit) then anchor:Hide() return end

    self:CreateAnchors(frame, plugin, iconSize)
    anchor:Show()
end
