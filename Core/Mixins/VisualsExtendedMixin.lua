-- [ ORBIT VISUALS EXTENDED MIXIN ]-----------------------------------------------------------------
-- Shared functionality for extended unit visuals (level, classification)
-- Used by TargetFrame and FocusFrame

local _, addonTable = ...
local Orbit = addonTable

Orbit.VisualsExtendedMixin = {}
local Mixin = Orbit.VisualsExtendedMixin

-- [ LEVEL DISPLAY ]---------------------------------------------------------------------------------

function Mixin:UpdateLevelDisplay(frame, systemIndex)
    if not frame or not frame.LevelText then
        return
    end
    if not UnitExists(frame.unit) then
        frame.LevelText:Hide()
        return
    end

    local showLevel = self:GetSetting(systemIndex, "ShowLevel")
    -- Handle legacy boolean or new string
    if showLevel == false or showLevel == "Hide" then
        frame.LevelText:Hide()
        return
    end

    -- Positioning
    frame.LevelText:ClearAllPoints()
    if showLevel == "Left" then
        -- Anchor TopRight of text to TopLeft of Frame (outside left)
        frame.LevelText:SetPoint("TOPRIGHT", frame, "TOPLEFT", -4, 0)
        frame.LevelText:SetJustifyH("RIGHT")
    else
        -- Default / "Right" / true
        -- Anchor TopLeft of text to TopRight of Health (standard)
        frame.LevelText:SetPoint("TOPLEFT", frame.Health, "TOPRIGHT", 4, 0)
        frame.LevelText:SetJustifyH("LEFT")
    end

    local level = UnitLevel(frame.unit)

    if level == -1 then
        -- Boss level
        frame.LevelText:SetText("??")
        frame.LevelText:SetTextColor(1, 0, 0)
        frame.LevelText:Show()
    elseif level and level > 0 then
        -- Standard level
        local color = GetCreatureDifficultyColor(level)
        frame.LevelText:SetText(level)
        frame.LevelText:SetTextColor(color.r, color.g, color.b)
        frame.LevelText:Show()
    else
        -- Fallback / Unknown
        frame.LevelText:SetText("??")
        frame.LevelText:SetTextColor(1, 0, 0)
        frame.LevelText:Show()
    end
end

-- [ LEVEL TEXT STYLING ]----------------------------------------------------------------------------

function Mixin:StyleLevelText(frame, fontName)
    if not frame or not frame.LevelText then
        return
    end

    local LSM = LibStub("LibSharedMedia-3.0")
    local globalFontName = fontName or (Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font)
    local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"

    frame.LevelText:SetFont(fontPath, 10, "OUTLINE")
end

-- [ CLASSIFICATION VISUALS ]-------------------------------------------------------------------------

function Mixin:UpdateClassificationVisuals(frame, systemIndex)
    if not frame then
        return
    end

    local showElite = self:GetSetting(systemIndex, "ShowElite")
    -- Handle legacy boolean or new string
    if showElite == false or showElite == "Hide" then
        if frame.RareEliteIcon then
            frame.RareEliteIcon:Hide()
        end
        return
    end

    local classification = UnitClassification(frame.unit)
    local isElite = (classification == "elite" or classification == "worldboss")
    local isRare = (classification == "rare" or classification == "rareelite")

    -- Preview Mode: Force elite visual if in Edit Mode to allow toggling/positioning
    if self.isEditing and not (isElite or isRare) then
        isElite = true
    end

    -- [ ICON IMPLEMENTATION ] ------------------------------

    if not frame.RareEliteIcon then
        frame.RareEliteIcon = frame:CreateTexture(nil, "OVERLAY")
        frame.RareEliteIcon:SetSize(16, 16)
    end

    local icon = frame.RareEliteIcon

    -- Positioning
    icon:ClearAllPoints()
    if showElite == "Left" then
        -- Anchor BottomRight of icon to BottomLeft of frame (outside left)
        icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -2, 0)
    else
        -- Default / "Right" / true
        -- Anchor BottomLeft of icon to BottomRight of frame (outside right)
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

-- [ COMBINED UPDATE ]-------------------------------------------------------------------------------

function Mixin:UpdateVisualsExtended(frame, systemIndex)
    if not frame then
        return
    end

    self:UpdateLevelDisplay(frame, systemIndex)
    self:StyleLevelText(frame)
    self:UpdateClassificationVisuals(frame, systemIndex)
end
