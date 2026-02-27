-- [ VISUALS EXTENDED MIXIN ]------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable

Orbit.VisualsExtendedMixin = {}
local Mixin = Orbit.VisualsExtendedMixin

function Mixin:GetComponentOverrides(systemIndex, key)
    if not self.GetSetting then return nil end
    local positions = self:GetSetting(systemIndex, "ComponentPositions")
    return positions and positions[key] and positions[key].overrides
end

function Mixin:UpdateLevelDisplay(frame, systemIndex)
    if not frame or not frame.LevelText then return end
    if not UnitExists(frame.unit) then frame.LevelText:Hide() return end
    if self.IsComponentDisabled and self:IsComponentDisabled("LevelText") then frame.LevelText:Hide() return end
    local level = UnitLevel(frame.unit)
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
    local fontPath = LibStub("LibSharedMedia-3.0"):Fetch("font", Orbit.db.GlobalSettings.Font) or "Fonts\\FRIZQT__.TTF"
    frame.LevelText:SetFont(fontPath, 10, Orbit.Skin:GetFontOutline())
    local overrides = self:GetComponentOverrides(systemIndex, "LevelText")
    if overrides then Orbit.Engine.OverrideUtils.ApplyFontOverrides(frame.LevelText, overrides, 10, fontPath) end
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
        frame.RareEliteIcon:SetSize(16, 16)
    end
    local icon = frame.RareEliteIcon
    local positions = self:GetSetting(systemIndex, "ComponentPositions")
    if not (positions and positions.RareEliteIcon) then
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 2, 0)
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

function Mixin:UpdateVisualsExtended(frame, systemIndex)
    if not frame then return end
    self:StyleLevelText(frame, systemIndex)
    self:UpdateLevelDisplay(frame, systemIndex)
    self:UpdateClassificationVisuals(frame, systemIndex)
end
