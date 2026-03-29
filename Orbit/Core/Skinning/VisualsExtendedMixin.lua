-- [ VISUALS EXTENDED MIXIN ]------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable

Orbit.VisualsExtendedMixin = {}
local Mixin = Orbit.VisualsExtendedMixin
local LSM = LibStub("LibSharedMedia-3.0")

local LEVEL_TEXT_SIZE = 10
local RARE_ELITE_ICON_SIZE = 16
local RARE_ELITE_ICON_OFFSET = 2

function Mixin:GetComponentOverrides(systemIndex, key)
    if not self.GetSetting then return nil end
    local positions = self:GetSetting(systemIndex, "ComponentPositions")
    return positions and positions[key] and positions[key].overrides
end

function Mixin:UpdateLevelDisplay(frame, systemIndex, overrideLevel)
    if not frame or not frame.LevelText then return end
    if not UnitExists(frame.unit) then frame.LevelText:Hide() return end
    if self.IsComponentDisabled and self:IsComponentDisabled("LevelText") then frame.LevelText:Hide() return end
    local level = overrideLevel or UnitLevel(frame.unit)
    if level and level > 0 then
        local color = GetCreatureDifficultyColor(level)
        frame.LevelText:SetText(level)
        frame.LevelText:SetTextColor(color.r, color.g, color.b)
    else
        frame.LevelText:SetText("??")
        frame.LevelText:SetTextColor(1, 0, 0)
    end
    frame.LevelText:Show()
end

function Mixin:StyleLevelText(frame, systemIndex)
    if not frame or not frame.LevelText then return end
    local fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font) or "Fonts\\FRIZQT__.TTF"
    frame.LevelText:SetFont(fontPath, LEVEL_TEXT_SIZE, Orbit.Skin:GetFontOutline())
    local overrides = self:GetComponentOverrides(systemIndex, "LevelText")
    if overrides then Orbit.Engine.OverrideUtils.ApplyFontOverrides(frame.LevelText, overrides, LEVEL_TEXT_SIZE, fontPath) end
end

function Mixin:UpdateClassificationVisuals(frame, systemIndex)
    if not frame then return end
    if self.IsComponentDisabled and self:IsComponentDisabled("RareEliteIcon") then
        if frame.RareEliteIcon then
            frame.RareEliteIcon:Hide()
        end
        return
    end
    local classification = UnitClassification(frame.unit)
    local isElite = (classification == "elite" or classification == "worldboss")
    local isRare = (classification == "rare" or classification == "rareelite")
    if self.isEditing and not (isElite or isRare) then
        isElite = true
    end
    if not frame.RareEliteIcon then
        frame.RareEliteIcon = frame:CreateTexture(nil, "OVERLAY")
        frame.RareEliteIcon:SetSize(RARE_ELITE_ICON_SIZE, RARE_ELITE_ICON_SIZE)
    end
    local icon = frame.RareEliteIcon
    local positions = self:GetSetting(systemIndex, "ComponentPositions")
    if not (positions and positions.RareEliteIcon) then
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", RARE_ELITE_ICON_OFFSET, 0)
    end
    if isElite then
        if icon.SetAtlas then
            icon:SetAtlas("nameplates-icon-elite-gold")
        else
            icon:SetTexture("Interface\\AddOns\\Orbit\\Media\\Textures\\EliteDragonGold")
        end
        icon:Show()
    elseif isRare then
        if icon.SetAtlas then
            icon:SetAtlas("nameplates-icon-elite-silver")
        else
            icon:SetTexture("Interface\\AddOns\\Orbit\\Media\\Textures\\EliteDragonSilver")
        end
        icon:Show()
    else
        icon:Hide()
    end
end

function Mixin:UpdateVisualsExtended(frame, systemIndex, overrideLevel)
    if not frame then return end
    self:StyleLevelText(frame, systemIndex)
    self:UpdateLevelDisplay(frame, systemIndex, overrideLevel)
    self:UpdateClassificationVisuals(frame, systemIndex)
end
