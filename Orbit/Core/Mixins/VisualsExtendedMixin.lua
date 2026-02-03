-- [ ORBIT VISUALS EXTENDED MIXIN ]-----------------------------------------------------------------
-- Shared functionality for extended unit visuals (used by TargetFrame/FocusFrame)

local _, addonTable = ...
local Orbit = addonTable

Orbit.VisualsExtendedMixin = {}
local Mixin = Orbit.VisualsExtendedMixin

function Mixin:UpdateLevelDisplay(frame, systemIndex)
    if not frame or not frame.LevelText then
        return
    end
    if not UnitExists(frame.unit) then
        frame.LevelText:Hide()
        return
    end
    if self.IsComponentDisabled and self:IsComponentDisabled("LevelText") then
        frame.LevelText:Hide()
        return
    end
    local level = UnitLevel(frame.unit)
    if level == -1 then
        frame.LevelText:SetText("??")
        frame.LevelText:SetTextColor(1, 0, 0)
        frame.LevelText:Show()
    elseif level and level > 0 then
        local color = GetCreatureDifficultyColor(level)
        frame.LevelText:SetText(level)
        frame.LevelText:SetTextColor(color.r, color.g, color.b)
        frame.LevelText:Show()
    else
        frame.LevelText:SetText("??")
        frame.LevelText:SetTextColor(1, 0, 0)
        frame.LevelText:Show()
    end
end

function Mixin:StyleLevelText(frame, fontName)
    if not frame or not frame.LevelText then
        return
    end
    local LSM = LibStub("LibSharedMedia-3.0")
    local fontPath = LSM:Fetch("font", fontName or Orbit.db.GlobalSettings.Font) or "Fonts\\FRIZQT__.TTF"
    frame.LevelText:SetFont(fontPath, 10, "OUTLINE")
end

function Mixin:UpdateClassificationVisuals(frame, systemIndex)
    if not frame then
        return
    end
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
    if not frame then
        return
    end
    self:UpdateLevelDisplay(frame, systemIndex)
    self:StyleLevelText(frame)
    self:UpdateClassificationVisuals(frame, systemIndex)
end
