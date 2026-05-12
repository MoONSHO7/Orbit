-- [ OBJECTIVES SKIN ]--------------------------------------------------------------------------------
-- Hook-based skinning for Blizzard's ObjectiveTracker modules.
-- Applies Orbit's visual theme (fonts, bar textures, colors) via hooksecurefunc.
-- Idempotent — safe to call repeatedly via ApplySettings.
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local C = Orbit.ObjectivesConstants
local SYSTEM_ID = C.SYSTEM_ID

local pairs = pairs
local select = select
local hooksecurefunc = hooksecurefunc
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Retrieve the plugin (registered in ObjectivesPlugin.lua, loaded before this file)
local Plugin = Orbit:GetPlugin("Objectives")

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function GetGlobalFont()
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local fontName = gs and gs.Font
    return fontName and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
end

local function IsUnderObjectivesTracker(frame)
    local p = frame
    while p do
        if p == ObjectiveTrackerFrame or (ObjectiveTrackerManager and (ObjectiveTrackerManager.containers[p] or ObjectiveTrackerManager.moduleToContainerMap[p])) then
            return true
        end
        p = p:GetParent()
    end
    return false
end

-- [ SKIN: FONT ]-------------------------------------------------------------------------------------
local function ApplyFont(fontString, size)
    if not fontString or not fontString.SetFont then return end
    local fontPath = GetGlobalFont()
    fontString:SetFont(fontPath, size or select(2, fontString:GetFont()) or 12, Orbit.Skin:GetFontOutline())
    Orbit.Skin:ApplyFontShadow(fontString)
end

-- [ SKIN: HEADER ]-----------------------------------------------------------------------------------
local function SkinHeader(header)
    if not header or not header.Background then return end
    if header._orbitSkinned then return end

    header.Background:SetAtlas(nil)
    header._orbitSkinned = true
end

local function ApplyHeaderColors(header, classColor)
    if not header or not header.Text then return end
    if classColor then
        local color = C_ClassColor.GetClassColor(select(2, UnitClass("player")))
        if color then
            header.Text:SetTextColor(color.r, color.g, color.b)
            return
        end
    end
    header.Text:SetTextColor(1, 1, 1)
end

local function ApplyHeaderFont(header)
    if not header or not header.Text then return end
    ApplyFont(header.Text)
end

-- [ SKIN: HEADER SEPARATOR ]-------------------------------------------------------------------------
local function EnsureSeparator(header)
    if not header then return nil end
    if header._orbitSeparator then return header._orbitSeparator end

    local sep = header:CreateTexture(nil, "ARTWORK", nil, 1)
    sep:SetHeight(C.HEADER_SEPARATOR_HEIGHT)
    sep:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -2)
    sep:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, -2)
    sep:SetColorTexture(1, 1, 1, 0.15)
    header._orbitSeparator = sep
    return sep
end

local function ApplyHeaderSeparator(header, show, classColor)
    local sep = EnsureSeparator(header)
    if not sep then return end

    if not show then
        sep:Hide()
        return
    end

    if classColor then
        local color = C_ClassColor.GetClassColor(select(2, UnitClass("player")))
        if color then
            sep:SetColorTexture(color.r, color.g, color.b, 0.4)
            sep:Show()
            return
        end
    end
    sep:SetColorTexture(1, 1, 1, 0.15)
    sep:Show()
end

-- [ SKIN: MINIMIZE BUTTON ]--------------------------------------------------------------------------
local function UpdateMinimizeChevron(btn)
    if not btn._orbitChevron then return end
    local header = btn:GetParent()
    local collapsed = header and header.isCollapsed
    btn._orbitChevron:SetText(collapsed and "+" or "-")
end

local function SkinMinimizeButton(header)
    if not header or not header.MinimizeButton then return end
    local btn = header.MinimizeButton
    if btn._orbitSkinned then return end

    btn:SetSize(16, 16)

    -- Hide Blizzard atlas textures
    local nt = btn:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local pt = btn:GetPushedTexture()
    if pt then pt:SetAlpha(0) end
    local hl = btn:GetHighlightTexture()
    if hl then hl:SetAlpha(0) end

    -- Create chevron FontString
    local chevron = btn:CreateFontString(nil, "OVERLAY")
    chevron:SetFont(GetGlobalFont(), 14, Orbit.Skin:GetFontOutline())
    chevron:SetPoint("CENTER", btn, "CENTER", 0, 0)
    chevron:SetTextColor(0.8, 0.8, 0.8)
    btn._orbitChevron = chevron

    UpdateMinimizeChevron(btn)

    -- Hook SetCollapsed on the header to update the chevron direction
    if header.SetCollapsed then
        hooksecurefunc(header, "SetCollapsed", function()
            UpdateMinimizeChevron(btn)
        end)
    end

    btn._orbitSkinned = true
end

-- Make the entire header act as a click target for collapse/expand
local function EnableHeaderClickCollapse(header)
    if not header or header._orbitClickCollapse then return end
    if not header.MinimizeButton then return end

    header:EnableMouse(true)
    header:SetScript("OnMouseDown", function(self)
        local btn = self.MinimizeButton
        if btn and btn:IsShown() then
            btn:Click()
        end
    end)

    header._orbitClickCollapse = true
end

-- [ SKIN: QUEST ITEM BUTTON ]------------------------------------------------------------------------
local function SkinQuestItemButton(button)
    if not button then return end
    if button._orbitSkinned then return end

    if button.SetNormalTexture then button:SetNormalTexture(0) end
    if button.SetPushedTexture then button:SetPushedTexture(0) end
    if button.GetHighlightTexture then
        local hl = button:GetHighlightTexture()
        if hl then hl:SetColorTexture(1, 1, 1, 0.25) end
    end

    local icon = button.icon or button.Icon
    if icon and OrbitEngine.Skin and OrbitEngine.Skin.SkinIcon then
        OrbitEngine.Skin:SkinIcon(icon)
    end

    button._orbitSkinned = true
end

-- [ SKIN: POI BUTTON (quest number / type badge) ]---------------------------------------------------
local POI_SIZE = 18

-- Quest classification → background color mapping
local POI_COLORS = {
    -- Important (orange)
    [Enum.QuestClassification.Important]      = { r = 0.90, g = 0.58, b = 0.18 },
    -- Legendary (orange-gold)
    [Enum.QuestClassification.Legendary]      = { r = 1.00, g = 0.50, b = 0.00 },
    -- Campaign (brown-gold)
    [Enum.QuestClassification.Campaign]       = { r = 0.80, g = 0.60, b = 0.20 },
    -- Calling (blue-teal)
    [Enum.QuestClassification.Calling]        = { r = 0.25, g = 0.70, b = 0.90 },
    -- Meta (purple)
    [Enum.QuestClassification.Meta]           = { r = 0.68, g = 0.38, b = 0.90 },
    -- Recurring / Daily (blue)
    [Enum.QuestClassification.Recurring]      = { r = 0.25, g = 0.50, b = 1.00 },
    -- Questline (light gold)
    [Enum.QuestClassification.Questline]      = { r = 0.85, g = 0.75, b = 0.35 },
    -- Normal (muted grey)
    [Enum.QuestClassification.Normal]         = { r = 0.45, g = 0.45, b = 0.45 },
    -- Bonus Objective (green)
    [Enum.QuestClassification.BonusObjective] = { r = 0.20, g = 0.80, b = 0.30 },
    -- Threat (red)
    [Enum.QuestClassification.Threat]         = { r = 0.85, g = 0.20, b = 0.20 },
    -- World Quest (teal-green)
    [Enum.QuestClassification.WorldQuest]     = { r = 0.20, g = 0.70, b = 0.55 },
}
local POI_COLOR_DEFAULT = { r = 0.45, g = 0.45, b = 0.45 }
local POI_COLOR_COMPLETE = { r = 0.90, g = 0.80, b = 0.10 }

-- Quest classification → atlas icon mapping (for Icon mode)
local POI_CLASSIFICATION_ATLAS = {
    [Enum.QuestClassification.Campaign]       = "questlog-questtypeicon-story",
    [Enum.QuestClassification.Important]      = "importantavailablequesticon",
    [Enum.QuestClassification.Legendary]      = "legendaryavailablequesticon",
    [Enum.QuestClassification.Calling]        = "questlog-questtypeicon-daily",
    [Enum.QuestClassification.Meta]           = "Wrapperavailablequesticon",
    [Enum.QuestClassification.Recurring]      = "questlog-questtypeicon-daily",
    [Enum.QuestClassification.BonusObjective] = "Bonus-Objective-Star",
    [Enum.QuestClassification.Threat]         = "questlog-questtypeicon-raid",
    [Enum.QuestClassification.WorldQuest]     = "Worldquest-icon",
    [Enum.QuestClassification.Questline]      = "questlog-questtypeicon-story",
}

-- Quest tag → atlas icon mapping (tag takes priority if matched)
local POI_TAG_ATLAS = {}
if Enum.QuestTag then
    POI_TAG_ATLAS[Enum.QuestTag.Dungeon]  = "questlog-questtypeicon-dungeon"
    POI_TAG_ATLAS[Enum.QuestTag.Raid]     = "questlog-questtypeicon-raid"
    POI_TAG_ATLAS[Enum.QuestTag.Group]    = "questlog-questtypeicon-group"
    POI_TAG_ATLAS[Enum.QuestTag.PvP]      = "questlog-questtypeicon-pvp"
    POI_TAG_ATLAS[Enum.QuestTag.Heroic]   = "questlog-questtypeicon-heroic"
    POI_TAG_ATLAS[Enum.QuestTag.Scenario] = "questlog-questtypeicon-scenario"
    if Enum.QuestTag.Account then
        POI_TAG_ATLAS[Enum.QuestTag.Account] = "questlog-questtypeicon-account"
    end
    if Enum.QuestTag.Delve then
        POI_TAG_ATLAS[Enum.QuestTag.Delve] = "questlog-questtypeicon-delves"
    end
end

local POI_ATLAS_DEFAULT = "questlog-questtypeicon-quest"
local POI_ATLAS_COMPLETE = "UI-QuestIcon-TurnIn-Normal"

-- Returns the atlas icon for a quest block
local function GetPOIAtlas(block)
    if block.poiIsComplete then return POI_ATLAS_COMPLETE end

    local questID = block.poiQuestID
    if not questID then return POI_ATLAS_DEFAULT end

    -- 1. Quest Tags override classification for type-specific icons
    if C_QuestLog.GetQuestTagInfo then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
        if tagInfo and tagInfo.tagID and POI_TAG_ATLAS[tagInfo.tagID] then
            return POI_TAG_ATLAS[tagInfo.tagID]
        end
    end

    -- 2. Campaign check
    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest(questID) then
        return POI_CLASSIFICATION_ATLAS[Enum.QuestClassification.Campaign]
    end

    -- 3. Classification
    local classification = C_QuestInfoSystem.GetQuestClassification(questID)
    if classification and POI_CLASSIFICATION_ATLAS[classification] then
        return POI_CLASSIFICATION_ATLAS[classification]
    end

    return POI_ATLAS_DEFAULT
end

local function GetPOIColor(block)
    if block.poiIsComplete then return POI_COLOR_COMPLETE end

    local questID = block.poiQuestID
    if not questID then return POI_COLOR_DEFAULT end

    -- 1. Campaign always gets priority to stay Orange-Gold
    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest(questID) then
        return POI_COLORS[Enum.QuestClassification.Campaign]
    end

    -- 2. Quest Tags (Group, Dungeon, Raid, PvP, Account/Warband) for richer colors
    if C_QuestLog.GetQuestTagInfo then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
        if tagInfo then
            local tagID = tagInfo.tagID
            if tagID == Enum.QuestTag.Group or tagID == Enum.QuestTag.Dungeon then
                return { r = 0.40, g = 0.70, b = 1.00 } -- Bright Blue for Group/Dungeons
            elseif tagID == Enum.QuestTag.Raid then
                return { r = 0.90, g = 0.30, b = 0.10 } -- Dark Red-Orange for Raids
            elseif tagID == Enum.QuestTag.PvP then
                return { r = 0.90, g = 0.20, b = 0.20 } -- Red for PvP
            elseif tagID == Enum.QuestTag.Account then
                return { r = 0.40, g = 0.80, b = 0.95 } -- Cyan for Warband/Account
            end
        end
    end

    -- 3. Base Classification
    local classification = C_QuestInfoSystem.GetQuestClassification(questID)
    if classification and classification ~= Enum.QuestClassification.Normal and POI_COLORS[classification] then
        return POI_COLORS[classification]
    end

    return POI_COLOR_DEFAULT
end

local function EnsurePOIBackground(poiButton)
    if poiButton._orbitBG then return poiButton._orbitBG end
    local bg = poiButton:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetPoint("TOPRIGHT", poiButton, "TOPRIGHT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", poiButton, "BOTTOMRIGHT", 0, 0)
    bg:SetWidth(3) -- Thin vertical accent line
    poiButton._orbitBG = bg
    return bg
end

-- Returns "Icons" or "Simplified" based on the plugin setting
local function GetPOIMode()
    local mode = Plugin:GetSetting(SYSTEM_ID, "QuestMarkerStyle")
    return mode or "Simplified"
end

local function StripPOIButton(poiButton)
    if not poiButton then return end

    -- In Icon mode: leave Blizzard's native rendering intact, only strip the oversized glow
    if GetPOIMode() == "Icons" then
        if poiButton.Glow then poiButton.Glow:SetAlpha(0) end
        return
    end

    -- Simplified mode: strip all Blizzard decorations
    local nt = poiButton:GetNormalTexture() or poiButton.NormalTexture
    if nt then nt:SetAlpha(0) end

    -- Strip pushed state border
    local pt = poiButton:GetPushedTexture() or poiButton.PushedTexture
    if pt then pt:SetAlpha(0) end

    -- Strip highlight
    local hl = poiButton:GetHighlightTexture() or poiButton.HighlightTexture
    if hl then hl:SetAlpha(0) end

    -- Strip outer glow (50x50, extends way beyond button)
    if poiButton.Glow then poiButton.Glow:SetAlpha(0) end
end

-- Apply the correct Display.Icon content based on mode
-- In Simplified mode: show the quest number filling the button
-- In Icons mode: leave Blizzard's default Display.Icon alone (it shows quest type icons natively)
local function ApplyPOIDisplay(poiButton, block)
    if not poiButton or not poiButton.Display or not poiButton.Display.Icon then return end
    local icon = poiButton.Display.Icon
    local isIconMode = GetPOIMode() == "Icons"

    if isIconMode then
        -- Let Blizzard's native icon render untouched
        icon:SetAlpha(1)
    else
        -- Simplified: fill the button with the quest number
        icon:SetAlpha(1)
        icon:ClearAllPoints()
        icon:SetAllPoints(poiButton)
    end
end

local function SkinPOIButton(block)
    if not block then return end
    local poiButton = block.poiButton
    if not poiButton then return end

    -- Store block reference on the button so hooks can find it
    poiButton._orbitBlock = block

    -- Anchor to the left of the header text (Blizzard's original side, but properly inset)
    poiButton:ClearAllPoints()
    poiButton:SetPoint("TOPRIGHT", block.HeaderText, "TOPLEFT", -4, 0)

    -- Resize to consistent small badge
    poiButton:SetSize(POI_SIZE, POI_SIZE)

    -- Strip all Blizzard decorations
    StripPOIButton(poiButton)

    local color = GetPOIColor(block)
    local isIconMode = GetPOIMode() == "Icons"

    -- Apply quest-type background color as an accent line (Simplified only)
    local bg = EnsurePOIBackground(poiButton)
    if isIconMode then
        bg:SetColorTexture(0, 0, 0, 0)
    else
        bg:SetColorTexture(color.r, color.g, color.b, 1)
    end

    -- Apply the correct Display.Icon content (number or atlas icon)
    ApplyPOIDisplay(poiButton, block)

    -- Color the quest title text
    if block.HeaderText then
        block.HeaderText:SetTextColor(color.r, color.g, color.b)
    end

    -- Hook UpdateButtonStyle for stripping and color maintenance
    if not poiButton._orbitUpdateHooked then
        hooksecurefunc(poiButton, "UpdateButtonStyle", function(btn)
            StripPOIButton(btn)
            btn:SetSize(POI_SIZE, POI_SIZE)
            local blk = btn._orbitBlock
            if blk then
                local c = GetPOIColor(blk)
                local bg2 = btn._orbitBG
                if bg2 then
                    if GetPOIMode() == "Icons" then
                        bg2:SetColorTexture(0, 0, 0, 0)
                    else
                        bg2:SetColorTexture(c.r, c.g, c.b, 1)
                    end
                end
                if blk.HeaderText then
                    blk.HeaderText:SetTextColor(c.r, c.g, c.b)
                end
                ApplyPOIDisplay(btn, blk)
            end
        end)
        poiButton._orbitUpdateHooked = true
    end
end

-- [ SKIN: BLOCK (quest/achievement/etc) ]------------------------------------------------------------
local function SkinBlockFonts(block, skinFonts)
    if not block or not skinFonts then return end

    -- Header text
    if block.HeaderText then
        ApplyFont(block.HeaderText)
    end

    -- Objective lines
    if block.usedLines then
        for _, line in pairs(block.usedLines) do
            if line.Text then ApplyFont(line.Text) end
            if line.Dash then ApplyFont(line.Dash) end
        end
    end
end

-- Reapply POI color to a block's HeaderText based on highlight state
local function ReapplyBlockColor(block)
    if block.HeaderText and block.poiButton and block.poiButton._orbitBG then
        local c = GetPOIColor(block)
        if block.isHighlighted then
            block.HeaderText:SetTextColor(math.min(1, c.r * 1.3), math.min(1, c.g * 1.3), math.min(1, c.b * 1.3))
        else
            block.HeaderText:SetTextColor(c.r, c.g, c.b)
        end
    end
end

local function OnAddBlock(_, block)
    if not block then return end
    SkinQuestItemButton(block.ItemButton)
    SkinQuestItemButton(block.itemButton)

    -- Skin the checkmark on completed objectives
    local check = block.currentLine and block.currentLine.Check
    if check and not check._orbitSkinned then
        check:SetAtlas("checkmark-minimal")
        check:SetDesaturated(true)
        check:SetVertexColor(0, 1, 0)
        check._orbitSkinned = true
    end

    -- Hook per-instance UpdateHighlight and SetHeader to defend POI colors
    -- Mixin methods are shallow-copied to instances, so mixin-level hooks don't fire
    if not block._orbitColorHooked then
        if block.UpdateHighlight then
            hooksecurefunc(block, "UpdateHighlight", ReapplyBlockColor)
        end
        if block.SetHeader then
            hooksecurefunc(block, "SetHeader", ReapplyBlockColor)
        end
        block._orbitColorHooked = true
    end

    -- Apply font override to block text (always on)
    SkinBlockFonts(block, true)
end

local function OnAddObjective(block, key)
    local line = block:GetExistingLine(key)
    if line and line.Icon and not line._orbitNubHooked then
        hooksecurefunc(line.Icon, "SetAtlas", function(icon, atlas)
            if atlas == "ui-questtracker-objective-nub" then
                icon:SetAlpha(0)
            else
                icon:SetAlpha(1)
            end
        end)
        if line.Icon:GetAtlas() == "ui-questtracker-objective-nub" then
            line.Icon:SetAlpha(0)
        end
        line._orbitNubHooked = true
    end
end

-- [ SKIN: PROGRESS BAR ]-----------------------------------------------------------------------------
local function SkinProgressBar(tracker, key)
    local progressBar = tracker.usedProgressBars and tracker.usedProgressBars[key]
    local bar = progressBar and progressBar.Bar
    if not bar then return end
    if bar._orbitSkinned then return end

    -- Strip Blizzard textures
    if bar.StripTextures then
        bar:StripTextures()
    else
        for i = 1, bar:GetNumRegions() do
            local region = select(i, bar:GetRegions())
            if region and region:IsObjectType("Texture") and region ~= bar:GetStatusBarTexture() then
                region:SetTexture(nil)
            end
        end
    end

    -- Resize bar to fill the block width and set a clean height
    bar:SetHeight(14)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", progressBar, "TOPRIGHT", 0, 0)
    
    if tracker.ContentsFrame then
        progressBar:SetPoint("RIGHT", tracker.ContentsFrame, "RIGHT", -15, 0)
    end
    progressBar:SetHeight(16)

    -- Apply Orbit bar texture
    local texture = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Texture
    local barTexture = texture and LSM:Fetch("statusbar", texture) or LSM:Fetch("statusbar", "Solid")
    bar:SetStatusBarTexture(barTexture)

    -- Add solid background behind the bar
    if not bar._orbitBG then
        local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetAllPoints(bar)
        bar._orbitBG = bg
    end
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local bgColor = gs and gs.BackdropColour or { r = 0, g = 0, b = 0 }
    bar._orbitBG:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 0.85)

    -- Add Orbit border around the bar
    Orbit.Skin:SkinBorder(bar, bar, nil, nil, false, true)

    -- Skin the icon if present
    local icon = bar.Icon
    if icon and icon:IsShown() then
        if icon.SetMask then icon:SetMask("") end
        if OrbitEngine.Skin and OrbitEngine.Skin.SkinIcon then
            OrbitEngine.Skin:SkinIcon(icon)
        end
    end

    -- Skin label font
    if bar.Label then ApplyFont(bar.Label) end

    bar._orbitSkinned = true
end

-- [ SKIN: TIMER BAR ]--------------------------------------------------------------------------------
local function SkinTimerBar(tracker, key)
    local timerBar = tracker.usedTimerBars and tracker.usedTimerBars[key]
    local bar = timerBar and timerBar.Bar
    if not bar or bar._orbitSkinned then return end

    -- Strip Blizzard textures
    if bar.StripTextures then
        bar:StripTextures()
    else
        for i = 1, bar:GetNumRegions() do
            local region = select(i, bar:GetRegions())
            if region and region:IsObjectType("Texture") and region ~= bar:GetStatusBarTexture() then
                region:SetTexture(nil)
            end
        end
    end

    -- Resize
    bar:SetHeight(14)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", timerBar, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", timerBar, "TOPRIGHT", 0, 0)
    timerBar:SetHeight(16)

    -- Apply Orbit bar texture
    local texture = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Texture
    local barTexture = texture and LSM:Fetch("statusbar", texture) or LSM:Fetch("statusbar", "Solid")
    bar:SetStatusBarTexture(barTexture)

    -- Add solid background
    if not bar._orbitBG then
        local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetAllPoints(bar)
        bar._orbitBG = bg
    end
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local bgColor = gs and gs.BackdropColour or { r = 0, g = 0, b = 0 }
    bar._orbitBG:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 0.85)

    -- Add Orbit border
    Orbit.Skin:SkinBorder(bar, bar, nil, nil, false, true)

    bar._orbitSkinned = true
end

-- [ SKIN: UI WIDGET STATUS BAR ]---------------------------------------------------------------------
local function SkinWidgetStatusBar(self)
    if not IsUnderObjectivesTracker(self) then return end

    local bar = self.Bar
    if not bar then return end

    if self.Label then ApplyFont(self.Label) end

    -- ONE-TIME SETUP: Textures and backgrounds never reset
    if not bar._orbitSkinned then
        bar:SetHeight(14)

        if bar.BGLeft then bar.BGLeft:SetAlpha(0) end
        if bar.BGRight then bar.BGRight:SetAlpha(0) end
        if bar.BGCenter then bar.BGCenter:SetAlpha(0) end
        if bar.BorderLeft then bar.BorderLeft:SetAlpha(0) end
        if bar.BorderRight then bar.BorderRight:SetAlpha(0) end
        if bar.BorderCenter then bar.BorderCenter:SetAlpha(0) end
        if self.BG then self.BG:SetAlpha(0) end -- Sometimes widgets have their own BG
        if self.LabelBG then self.LabelBG:SetAlpha(0) end
        if self.LabelBGDivider then self.LabelBGDivider:SetAlpha(0) end

        local texture = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Texture
        local barTexture = texture and LSM:Fetch("statusbar", texture) or LSM:Fetch("statusbar", "Solid")
        bar:SetStatusBarTexture(barTexture)

        if not bar._orbitBG then
            local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
            bg:SetAllPoints(bar)
            bar._orbitBG = bg
        end
        local gs = Orbit.db and Orbit.db.GlobalSettings
        local bgColor = gs and gs.BackdropColour or { r = 0, g = 0, b = 0 }
        bar._orbitBG:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 0.85)

        Orbit.Skin:SkinBorder(bar, bar, nil, nil, false, true)
        bar._orbitSkinned = true
    end

    if self.LabelIcon then
        self.LabelIcon:SetTexture(nil)
        self.LabelIcon:SetAlpha(0)
    end
    if self.Icon then
        self.Icon:SetTexture(nil)
        self.Icon:SetAlpha(0)
    end
    if self.Label then
        self.Label:ClearAllPoints()
        if bar then
            self.Label:SetPoint("CENTER", bar, "CENTER", 0, 0)
        end
    end
end

-- [ SKIN: SCENARIO STAGE BLOCK ]---------------------------------------------------------------------
local function SkinScenarioStageBlock(block)
    if not block then return end
    if block.NormalBG then block.NormalBG:SetAlpha(0) end
    if block.GlowTexture then block.GlowTexture:SetAlpha(0) end
    if block.FinalBG then block.FinalBG:SetAlpha(0) end
    if block.Stage then ApplyFont(block.Stage) end
    if block.Name then ApplyFont(block.Name) end
    
    -- Reduce height to compress gap now that backgrounds are gone
    if block.SetHeight then block:SetHeight(45) end
    block.height = 45 
end

-- [ SKIN: UI WIDGET ICON AND TEXT ]----------------------------------------------------------------
local function SkinWidgetIconAndText(self)
    if not IsUnderObjectivesTracker(self) then return end

    if self.Icon then
        self.Icon:SetTexture(nil)
        self.Icon:SetAlpha(0)
    end
    if self.Text then
        ApplyFont(self.Text)
    end
    if self.DynamicIconTexture then
        self.DynamicIconTexture:SetTexture(nil)
        self.DynamicIconTexture:SetAlpha(0)
    end
end

local function SkinWidgetStateIcon(self)
    if not IsUnderObjectivesTracker(self) then return end
    if self.Icon then
        self.Icon:SetTexture(nil)
        self.Icon:SetAlpha(0)
    end
end

local function SkinWidgetIconTextAndBackground(self)
    if not IsUnderObjectivesTracker(self) then return end
    if self.Icon then self.Icon:SetAlpha(0) end
    if self.Glow then self.Glow:SetAlpha(0) end
    if self.Text then ApplyFont(self.Text) end
    if self.Background then self.Background:SetAlpha(0) end
end

-- [ SKIN: UI WIDGET SCENARIO HEADER ]----------------------------------------------------------
local function SkinWidgetScenarioHeader(self)
    if not IsUnderObjectivesTracker(self) then return end

    if self.Frame then self.Frame:SetAlpha(0) end
    if self.DecorationBottomLeft then self.DecorationBottomLeft:SetAlpha(0) end
    if self.DecorationBottomRight then self.DecorationBottomRight:SetAlpha(0) end
    
    if self.HeaderText then 
        ApplyFont(self.HeaderText)
        self.HeaderText:ClearAllPoints()
        self.HeaderText:SetPoint("TOPLEFT", self, "TOPLEFT", 15, -4)
    end
end

-- [ SKIN: UI WIDGET BUTTON HEADER ]------------------------------------------------------------
local function SkinWidgetButtonHeader(self)
    if not IsUnderObjectivesTracker(self) then return end

    if self.Frame then self.Frame:SetAlpha(0) end
    if self.HeaderText then 
        ApplyFont(self.HeaderText)
        self.HeaderText:ClearAllPoints()
        self.HeaderText:SetPoint("TOPLEFT", self, "TOPLEFT", 15, -4) 
    end
end

-- [ INSTALL HOOKS ]----------------------------------------------------------------------------------
function Plugin:InstallSkinHooks()
    if self._hooksInstalled then return end

    -- Skin the main container header
    local trackerFrame = ObjectiveTrackerFrame
    if trackerFrame and trackerFrame.Header then
        SkinHeader(trackerFrame.Header)
        SkinMinimizeButton(trackerFrame.Header)
        EnableHeaderClickCollapse(trackerFrame.Header)
    end

    -- Skin each module's header and hook AddBlock / GetProgressBar / GetTimerBar
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker then
            if tracker.Header then
                SkinHeader(tracker.Header)
                SkinMinimizeButton(tracker.Header)
                EnableHeaderClickCollapse(tracker.Header)
            end

            hooksecurefunc(tracker, "AddBlock", OnAddBlock)

            if tracker.GetProgressBar then
                hooksecurefunc(tracker, "GetProgressBar", SkinProgressBar)
            end

            if tracker.GetTimerBar then
                hooksecurefunc(tracker, "GetTimerBar", SkinTimerBar)
            end

            if tracker.StageBlock and tracker.StageBlock.UpdateStageBlock then
                hooksecurefunc(tracker.StageBlock, "UpdateStageBlock", SkinScenarioStageBlock)
            end
        end
    end

    if ObjectiveTrackerBlockMixin and ObjectiveTrackerBlockMixin.AddObjective then
        hooksecurefunc(ObjectiveTrackerBlockMixin, "AddObjective", OnAddObjective)
    end

    self._hooksInstalled = true

    -- Hook POI button creation (shared mixin used by all quest-displaying modules)
    if ObjectiveTrackerQuestPOIBlockMixin and ObjectiveTrackerQuestPOIBlockMixin.AddPOIButton then
        hooksecurefunc(ObjectiveTrackerQuestPOIBlockMixin, "AddPOIButton", SkinPOIButton)
    end

    -- Hook UI widget status bars (globally, then filter to Objectives inside the function)
    if UIWidgetTemplateStatusBarMixin and UIWidgetTemplateStatusBarMixin.Setup then
        hooksecurefunc(UIWidgetTemplateStatusBarMixin, "Setup", SkinWidgetStatusBar)
    end
    if UIWidgetTemplateIconAndTextMixin and UIWidgetTemplateIconAndTextMixin.Setup then
        hooksecurefunc(UIWidgetTemplateIconAndTextMixin, "Setup", SkinWidgetIconAndText)
    end
    if UIWidgetBaseStateIconTemplateMixin and UIWidgetBaseStateIconTemplateMixin.Setup then
        hooksecurefunc(UIWidgetBaseStateIconTemplateMixin, "Setup", SkinWidgetStateIcon)
    end
    if UIWidgetTemplateIconTextAndBackgroundMixin and UIWidgetTemplateIconTextAndBackgroundMixin.Setup then
        hooksecurefunc(UIWidgetTemplateIconTextAndBackgroundMixin, "Setup", SkinWidgetIconTextAndBackground)
    end
    if UIWidgetBaseScenarioHeaderTemplateMixin and UIWidgetBaseScenarioHeaderTemplateMixin.Setup then
        hooksecurefunc(UIWidgetBaseScenarioHeaderTemplateMixin, "Setup", SkinWidgetScenarioHeader)
    end
    if UIWidgetTemplateButtonHeaderMixin and UIWidgetTemplateButtonHeaderMixin.Setup then
        hooksecurefunc(UIWidgetTemplateButtonHeaderMixin, "Setup", SkinWidgetButtonHeader)
    end
end

-- [ FIT WIDTHS ]--------------------------------------------------------------------------------------
-- Blizzard hardcodes headers/modules to 260px. Resize them to match our container.
function Plugin:FitTrackerWidths()
    local trackerFrame = ObjectiveTrackerFrame
    if not trackerFrame then return end

    local width = trackerFrame:GetWidth()
    if width <= 0 then return end

    -- Hide the Blizzard NineSlice background (we provide our own backdrop/border)
    if trackerFrame.NineSlice then
        trackerFrame.NineSlice:Hide()
    end

    -- Resize main header
    if trackerFrame.Header then
        trackerFrame.Header:SetWidth(width)
    end

    -- Resize each module and its header
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker then
            tracker:SetWidth(width)
            if tracker.Header then
                tracker.Header:SetWidth(width)
            end
            -- ContentsFrame holds blocks
            if tracker.ContentsFrame then
                tracker.ContentsFrame:SetWidth(width)
            end
        end
    end
end

-- [ RE-APPLY SKINS (called from ApplySettings) ]-----------------------------------------------------
function Plugin:ApplySkins()
    if not self._hooksInstalled then return end

    local classColorHeaders = self:GetSetting(SYSTEM_ID, "ClassColorHeaders")
    local headerSeparators = self:GetSetting(SYSTEM_ID, "HeaderSeparators")

    -- Fit all widths to our container
    self:FitTrackerWidths()

    -- Main tracker header
    local trackerFrame = ObjectiveTrackerFrame
    if trackerFrame and trackerFrame.Header then
        ApplyHeaderColors(trackerFrame.Header, classColorHeaders)
        ApplyHeaderFont(trackerFrame.Header)
        ApplyHeaderSeparator(trackerFrame.Header, headerSeparators ~= false, classColorHeaders)
    end

    -- Per-module headers
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker and tracker.Header then
            ApplyHeaderColors(tracker.Header, classColorHeaders)
            ApplyHeaderFont(tracker.Header)
            ApplyHeaderSeparator(tracker.Header, headerSeparators ~= false, classColorHeaders)
        end
    end
end
