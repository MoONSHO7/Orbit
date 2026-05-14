-- [ OBJECTIVES SKIN ]--------------------------------------------------------------------------------
-- Hook-based skinning for ObjectiveTracker modules. Applies Orbit theme via hooksecurefunc. Idempotent.
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local C = Orbit.ObjectivesConstants
local SYSTEM_ID = C.SYSTEM_ID

local pairs = pairs
local select = select
local hooksecurefunc = hooksecurefunc
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT

-- Retrieve the plugin (registered in ObjectivesPlugin.lua, loaded before this file)
local Plugin = Orbit:GetPlugin("Objectives")

-- Module-level enabled flag — O(1) guard for hook callbacks.
local _enabled = false

function Plugin:SetSkinEnabled(state)
    _enabled = state
end

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function GetGlobalFont()
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local fontName = gs and gs.Font
    return fontName and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
end

-- Super-tracked quest ID (updated by SUPER_TRACKING_CHANGED)
local _superTrackedQuestID = nil

local function GetTitleFontSize()
    return Plugin:GetSetting(SYSTEM_ID, "TitleFontSize") or C.TITLE_FONT_SIZE_DEFAULT
end

local function GetObjectiveFontSize()
    return Plugin:GetSetting(SYSTEM_ID, "ObjectiveFontSize") or C.OBJECTIVE_FONT_SIZE_DEFAULT
end

local POI_COLOR_DEFAULT_FALLBACK  = C.TITLE_COLOR_DEFAULT
local POI_COLOR_COMPLETE_FALLBACK = C.COMPLETED_COLOR_DEFAULT

local function GetNormalQuestColor()
    return C.ValidateColor(Plugin:GetSetting(SYSTEM_ID, "TitleColor"), POI_COLOR_DEFAULT_FALLBACK)
end

local function GetCompletedQuestColor()
    return C.ValidateColor(Plugin:GetSetting(SYSTEM_ID, "CompletedColor"), POI_COLOR_COMPLETE_FALLBACK)
end

local function GetFocusQuestColor()
    return C.ValidateColor(Plugin:GetSetting(SYSTEM_ID, "FocusColor"), C.FOCUS_COLOR_DEFAULT)
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

    header.Background:SetTexture("")
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
    -- Collapse state lives on the module/tracker, not on the header itself
    local module = header and header:GetParent()
    local collapsed = module and module.isCollapsed
    btn._orbitChevron:SetText(collapsed and "+" or "-")
end

local function SkinMinimizeButton(header)
    if not header or not header.MinimizeButton then return end
    local btn = header.MinimizeButton
    if btn._orbitSkinned then return end

    btn:SetSize(16, 16)

    -- Hide Blizzard atlas textures — reapplied after every SetCollapsed (Blizzard calls SetAtlas).
    local function SuppressNativeTextures()
        local nt = btn:GetNormalTexture()
        if nt then nt:SetAlpha(0) end
        local pt = btn:GetPushedTexture()
        if pt then pt:SetAlpha(0) end
        local hl = btn:GetHighlightTexture()
        if hl then hl:SetAlpha(0) end
    end
    SuppressNativeTextures()

    -- Create chevron FontString
    local chevron = btn:CreateFontString(nil, "OVERLAY")
    chevron:SetFont(GetGlobalFont(), 14, Orbit.Skin:GetFontOutline())
    chevron:SetPoint("CENTER", btn, "CENTER", 0, 0)
    chevron:SetTextColor(0.8, 0.8, 0.8)
    btn._orbitChevron = chevron

    UpdateMinimizeChevron(btn)

    -- Hook SetCollapsed on the header to update the chevron and re-suppress native textures
    if header.SetCollapsed then
        hooksecurefunc(header, "SetCollapsed", function()
            SuppressNativeTextures()
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

-- [ SKIN: QUEST COUNTER ]----------------------------------------------------------------------------
local function EnsureQuestCounter(header)
    if not header then return nil end
    if header._orbitQuestCount then return header._orbitQuestCount end

    local fs = header:CreateFontString(nil, "OVERLAY")
    if header.MinimizeButton then
        fs:SetPoint("RIGHT", header.MinimizeButton, "LEFT", -5, 0)
    else
        fs:SetPoint("RIGHT", header, "RIGHT", -22, 0)
    end
    header._orbitQuestCount = fs
    return fs
end

local function UpdateQuestCounter(header)
    local fs = header and header._orbitQuestCount
    if not fs then return end
    local count = C_QuestLog.GetNumQuestWatches() or 0
    local max = (Constants and Constants.QuestWatchConsts and Constants.QuestWatchConsts.MAX_QUEST_WATCHES) or C.MAX_QUESTS
    fs:SetText(count .. "/" .. max)
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

-- [ SKIN: POI BUTTON / BLOCK ICON ]-----------------------------------------------------------------
-- Style native poiButton with slim atlas icon. Button stays functional for click-to-focus.

-- Quest classification → header text color mapping
local POI_COLORS = {
    [Enum.QuestClassification.Important]      = { r = 0.90, g = 0.58, b = 0.18 },
    [Enum.QuestClassification.Legendary]      = { r = 1.00, g = 0.50, b = 0.00 },
    [Enum.QuestClassification.Campaign]       = { r = 0.80, g = 0.60, b = 0.20 },
    [Enum.QuestClassification.Calling]        = { r = 0.25, g = 0.70, b = 0.90 },
    [Enum.QuestClassification.Meta]           = { r = 0.68, g = 0.38, b = 0.90 },
    [Enum.QuestClassification.Recurring]      = { r = 0.25, g = 0.50, b = 1.00 },
    [Enum.QuestClassification.Questline]      = { r = 0.85, g = 0.75, b = 0.35 },
    [Enum.QuestClassification.Normal]         = { r = 1.00, g = 0.82, b = 0.00 },
    [Enum.QuestClassification.BonusObjective] = { r = 0.20, g = 0.80, b = 0.30 },
    [Enum.QuestClassification.Threat]         = { r = 0.85, g = 0.20, b = 0.20 },
    [Enum.QuestClassification.WorldQuest]     = { r = 0.20, g = 0.70, b = 0.55 },
}
-- Quest classification → atlas icon mapping
local POI_CLASSIFICATION_ATLAS = {
    [Enum.QuestClassification.Campaign]       = "Quest-Campaign-Available",
    [Enum.QuestClassification.Important]      = "importantavailablequesticon",
    [Enum.QuestClassification.Legendary]      = "UI-QuestPoiLegendary-QuestBang",
    [Enum.QuestClassification.Calling]        = "Quest-DailyCampaign-Available",
    [Enum.QuestClassification.Meta]           = "quest-wrapper-available",
    [Enum.QuestClassification.Recurring]      = "quest-recurring-available",
    [Enum.QuestClassification.BonusObjective] = "Bonus-Objective-Star",
    [Enum.QuestClassification.Threat]         = "questlog-questtypeicon-raid",
    [Enum.QuestClassification.WorldQuest]     = "Worldquest-icon",
    [Enum.QuestClassification.Questline]      = "questlog-questtypeicon-story",
}

-- Quest tag → atlas icon mapping (tag takes priority over classification)
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

local POI_ATLAS_DEFAULT  = "QuestNormal"
local POI_ATLAS_COMPLETE = "QuestTurnin"

local function GetPOIAtlas(block)
    if block.poiIsComplete then return POI_ATLAS_COMPLETE end
    local questID = block.poiQuestID
    if not questID then return POI_ATLAS_DEFAULT end

    if C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID) then
        return POI_ATLAS_COMPLETE
    end

    -- Classification checked first — Legendary / Campaign / Important should
    -- take visual priority over generic tags like Raid or Dungeon.
    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest(questID) then
        return POI_CLASSIFICATION_ATLAS[Enum.QuestClassification.Campaign]
    end

    local classification = C_QuestInfoSystem.GetQuestClassification(questID)
    if classification and POI_CLASSIFICATION_ATLAS[classification] then
        return POI_CLASSIFICATION_ATLAS[classification]
    end

    if C_QuestLog.GetQuestTagInfo then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
        if tagInfo and tagInfo.tagID and POI_TAG_ATLAS[tagInfo.tagID] then
            return POI_TAG_ATLAS[tagInfo.tagID]
        end
    end

    return POI_ATLAS_DEFAULT
end

local function GetPOIColor(block)
    local questID = block.poiQuestID

    -- Focus colour overrides everything for the super-tracked quest
    if questID and questID == _superTrackedQuestID then
        local fc = GetFocusQuestColor()
        if fc then return fc end
    end

    if block.poiIsComplete then return GetCompletedQuestColor() end
    if not questID then return GetNormalQuestColor() end

    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest(questID) then
        return POI_COLORS[Enum.QuestClassification.Campaign]
    end

    if C_QuestLog.GetQuestTagInfo then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
        if tagInfo then
            local tagID = tagInfo.tagID
            if tagID == Enum.QuestTag.Group or tagID == Enum.QuestTag.Dungeon then
                return C.TAG_COLOR_GROUP
            elseif tagID == Enum.QuestTag.Raid then
                return C.TAG_COLOR_RAID
            elseif tagID == Enum.QuestTag.PvP then
                return C.TAG_COLOR_PVP
            elseif tagID == Enum.QuestTag.Account then
                return C.TAG_COLOR_ACCOUNT
            end
        end
    end

    local classification = C_QuestInfoSystem.GetQuestClassification(questID)
    if classification and classification ~= Enum.QuestClassification.Normal and POI_COLORS[classification] then
        return POI_COLORS[classification]
    end

    return GetNormalQuestColor()
end

-- Strip native POI visuals and overlay slim atlas icon. Idempotent.
local function SkinPOIButton(block)
    if not _enabled then return end
    if not block then return end
    local pb = block.poiButton
    local questID = block.poiQuestID

    -- No POI button or no quest — hide our overlay icon if it exists
    if not pb or not questID then
        if block._orbitIcon then block._orbitIcon:Hide() end
        return
    end

    -- Reposition the button to the left of the header text
    pb:ClearAllPoints()
    if block.HeaderText then
        pb:SetPoint("TOPRIGHT", block.HeaderText, "TOPLEFT", -4, 0)
    else
        pb:SetPoint("TOPRIGHT", block, "TOPRIGHT", -2, 0)
    end
    pb:SetSize(C.POI_SIZE, C.POI_SIZE)

    -- Hide all native visual regions (background circle, number, glow, etc.)
    for i = 1, pb:GetNumRegions() do
        local region = select(i, pb:GetRegions())
        if region and region ~= pb._orbitIcon then
            region:SetAlpha(0)
        end
    end
    -- Also strip children's regions (e.g. Display sub-frame)
    for _, child in pairs({ pb:GetChildren() }) do
        if child.GetNumRegions then
            for i = 1, child:GetNumRegions() do
                local region = select(i, child:GetRegions())
                if region then region:SetAlpha(0) end
            end
        end
    end

    -- Create our overlay icon on the button (once per button instance)
    if not pb._orbitIcon then
        pb._orbitIcon = pb:CreateTexture(nil, "OVERLAY", nil, 7)
        pb._orbitIcon:SetAllPoints()
    end
    pb._orbitIcon:SetAtlas(GetPOIAtlas(block), false)
    pb._orbitIcon:SetAlpha(1)
    pb._orbitIcon:Show()

    -- Color the quest title text to match quest type / focus state
    if block.HeaderText then
        local c = GetPOIColor(block)
        block.HeaderText:SetTextColor(c.r, c.g, c.b)
    end
end

-- [ SKIN: BLOCK (quest/achievement/etc) ]------------------------------------------------------------
local function SkinBlockFonts(block, skinFonts)
    if not block or not skinFonts then return end

    -- Header text
    if block.HeaderText then
        ApplyFont(block.HeaderText, GetTitleFontSize())
    end

    -- Objective lines
    if block.usedLines then
        for _, line in pairs(block.usedLines) do
            if line.Text then ApplyFont(line.Text, GetObjectiveFontSize()) end
            if line.Dash then ApplyFont(line.Dash, GetObjectiveFontSize()) end
        end
    end
end

-- Reapply POI color to a block's HeaderText based on highlight state.
local function ReapplyBlockColor(block)
    if not _enabled then return end
    if not block.HeaderText then return end
    if not block.poiButton then return end
    local c = GetPOIColor(block)
    if block.isHighlighted then
        block.HeaderText:SetTextColor(math.min(1, c.r * C.HIGHLIGHT_BRIGHTEN), math.min(1, c.g * C.HIGHLIGHT_BRIGHTEN), math.min(1, c.b * C.HIGHLIGHT_BRIGHTEN))
    else
        block.HeaderText:SetTextColor(c.r, c.g, c.b)
    end
end

local function OnAddBlock(_, block)
    if not _enabled then return end
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

    -- Per-instance hooks required: mixin methods are shallow-copied, so mixin-level hooks miss re-renders.
    if not block._orbitColorHooked then
        if block.UpdateHighlight then
            hooksecurefunc(block, "UpdateHighlight", ReapplyBlockColor)
        end
        if block.SetHeader then
            hooksecurefunc(block, "SetHeader", ReapplyBlockColor)
        end
        block._orbitColorHooked = true
    end

    if not block._orbitPoiHooked then
        if block.AddPOIButton then
            hooksecurefunc(block, "AddPOIButton", SkinPOIButton)
        end
        block._orbitPoiHooked = true
    end

    -- Apply font override to block text (always on)
    SkinBlockFonts(block, true)
end

local function OnAddObjective(block, key)
    if not _enabled then return end
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

-- [ SKIN: PROGRESS BAR LABEL ]-----------------------------------------------------------------------
local function FormatProgressLabel(bar)
    if not bar or not bar.Label then return end
    local _, max = bar:GetMinMaxValues()
    local val = bar:GetValue()
    if not max or max == 0 then return end

    local mode = Plugin:GetSetting(SYSTEM_ID, "ProgressBarMode") or "Percent"
    local text
    if mode == "XY" then
        text = math.floor(val) .. " / " .. math.floor(max)
    elseif mode == "Both" then
        local pct = math.floor((val / max) * 100 + 0.5)
        text = math.floor(val) .. " / " .. math.floor(max) .. "  (" .. pct .. "%)"
    else -- "Percent"
        text = math.floor((val / max) * 100 + 0.5) .. "%"
    end

    bar._orbitUpdating = true
    bar.Label:SetText(text)
    bar._orbitUpdating = false
end

local function EnsureProgressLabelHook(bar)
    if not bar or not bar.Label then return end
    if bar._orbitLabelHooked then return end

    local function onBlizzardWrite(self, text)
        if not _enabled then return end
        if bar._orbitUpdating then return end
        if text and text ~= "" then
            FormatProgressLabel(bar)
        end
    end

    hooksecurefunc(bar.Label, "SetText", onBlizzardWrite)
    hooksecurefunc(bar.Label, "SetFormattedText", onBlizzardWrite)

    bar._orbitLabelHooked = true
    FormatProgressLabel(bar)
end

-- [ SKIN: PROGRESS BAR ]-----------------------------------------------------------------------------
local function SkinProgressBar(tracker, key)
    if not _enabled then return end
    if not Plugin:GetSetting(SYSTEM_ID, "SkinProgressBars") then return end
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
    bar:SetHeight(C.PROGRESS_BAR_HEIGHT)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", progressBar, "TOPRIGHT", 0, 0)
    
    if tracker.ContentsFrame then
        progressBar:SetPoint("RIGHT", tracker.ContentsFrame, "RIGHT", -15, 0)
    end
    progressBar:SetHeight(C.PROGRESS_BAR_CONTAINER_HEIGHT)

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
    bar._orbitBG:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, C.BAR_BG_ALPHA)

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
    if bar.Label then ApplyFont(bar.Label, C.PROGRESS_BAR_FONT_SIZE) end

    bar._orbitSkinned = true
    EnsureProgressLabelHook(bar)
end

-- [ SKIN: TIMER BAR ]--------------------------------------------------------------------------------
local function SkinTimerBar(tracker, key)
    if not _enabled then return end
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
    bar:SetHeight(C.PROGRESS_BAR_HEIGHT)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", timerBar, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", timerBar, "TOPRIGHT", 0, 0)
    timerBar:SetHeight(C.PROGRESS_BAR_CONTAINER_HEIGHT)

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
    bar._orbitBG:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, C.BAR_BG_ALPHA)

    -- Add Orbit border
    Orbit.Skin:SkinBorder(bar, bar, nil, nil, false, true)

    bar._orbitSkinned = true
end

-- [ SKIN: UI WIDGET STATUS BAR ]---------------------------------------------------------------------
local function SkinWidgetStatusBar(self)
    if not _enabled then return end
    if not IsUnderObjectivesTracker(self) then return end

    local bar = self.Bar
    if not bar then return end

    if self.Label then ApplyFont(self.Label) end

    -- ONE-TIME SETUP: Textures and backgrounds never reset
    if not bar._orbitSkinned then
        bar:SetHeight(C.PROGRESS_BAR_HEIGHT)

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
        bar._orbitBG:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, C.BAR_BG_ALPHA)

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

-- [ SKIN: UI WIDGET ICON AND TEXT ]----------------------------------------------------------------
local function SkinWidgetIconAndText(self)
    if not _enabled then return end
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
    if not _enabled then return end
    if not IsUnderObjectivesTracker(self) then return end
    if self.Icon then
        self.Icon:SetTexture(nil)
        self.Icon:SetAlpha(0)
    end
end

local function SkinWidgetIconTextAndBackground(self)
    if not _enabled then return end
    if not IsUnderObjectivesTracker(self) then return end
    if self.Icon then self.Icon:SetAlpha(0) end
    if self.Glow then self.Glow:SetAlpha(0) end
    if self.Text then ApplyFont(self.Text) end
    if self.Background then self.Background:SetAlpha(0) end
end

-- [ SUPER TRACKING ]---------------------------------------------------------------------------------
-- Track which quest is super-tracked so GetPOIColor can apply the focus colour.
local _superTrackFrame = CreateFrame("Frame")
_superTrackFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
_superTrackFrame:SetScript("OnEvent", function()
    _superTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID()
    if not _enabled then return end
    Plugin:ReSkinExistingPOIButtons()
end)

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

    -- Quest counter: update whenever the quest log changes
    local questCountFrame = CreateFrame("Frame")
    questCountFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    questCountFrame:SetScript("OnEvent", function()
        if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header then
            UpdateQuestCounter(ObjectiveTrackerFrame.Header)
        end
    end)

    -- Skin each module's header and hook AddBlock / GetProgressBar / GetTimerBar.
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker then
            if tracker.Header then
                SkinHeader(tracker.Header)
                SkinMinimizeButton(tracker.Header)
                EnableHeaderClickCollapse(tracker.Header)
            end

            -- ScenarioObjectiveTracker: header only — its frames share Blizzard's widget pool (taints on method call).
            if moduleName ~= "ScenarioObjectiveTracker" then
                hooksecurefunc(tracker, "AddBlock", OnAddBlock)

                if tracker.GetProgressBar then
                    hooksecurefunc(tracker, "GetProgressBar", SkinProgressBar)
                end

                if tracker.GetTimerBar then
                    hooksecurefunc(tracker, "GetTimerBar", SkinTimerBar)
                end
            end
        end
    end

    if ObjectiveTrackerBlockMixin and ObjectiveTrackerBlockMixin.AddObjective then
        hooksecurefunc(ObjectiveTrackerBlockMixin, "AddObjective", OnAddObjective)
    end

    self._hooksInstalled = true

    -- Hook POI button creation at the mixin level
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
            -- MawBuffsBlock is a FixedBlock with hardcoded width 243. Its Container button is
            -- anchored TOPRIGHT, so if ContentsFrame is wider the button drifts off-center.
            if tracker.MawBuffsBlock then
                tracker.MawBuffsBlock:SetWidth(width)
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

        -- Quest counter
        local showCount = self:GetSetting(SYSTEM_ID, "ShowQuestCount") ~= false
        if showCount then
            local counter = EnsureQuestCounter(trackerFrame.Header)
            if counter then
                ApplyFont(counter, GetObjectiveFontSize())
                counter:SetTextColor(0.6, 0.6, 0.6)
                UpdateQuestCounter(trackerFrame.Header)
                counter:Show()
            end
        elseif trackerFrame.Header._orbitQuestCount then
            trackerFrame.Header._orbitQuestCount:Hide()
        end
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

    -- Propagate live setting changes to already-rendered blocks and bars
    self:ReSkinExistingBlocks()
    self:ReSkinExistingPOIButtons()
    -- Deferred pass: catches blocks Blizzard populates after our immediate call
    C_Timer.After(C.DEFERRED_RESKIN_DELAY, function() self:ReSkinExistingPOIButtons() end)
end

-- [ RE-SKIN EXISTING BLOCKS ]------------------------------------------------------------------------
-- Re-applies font sizes and progress label hooks to all rendered blocks.
function Plugin:ReSkinExistingBlocks()
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker then
            -- Always re-skin block fonts so font size changes apply live
            if tracker.usedBlocks then
                for _, blocks in pairs(tracker.usedBlocks) do
                    for _, block in pairs(blocks) do
                        if block then SkinBlockFonts(block, true) end
                    end
                end
            end

            -- Progress bar label hooks (gated on SkinProgressBars)
            if self:GetSetting(SYSTEM_ID, "SkinProgressBars") and tracker.usedProgressBars then
                for _, progressBar in pairs(tracker.usedProgressBars) do
                    local bar = progressBar and progressBar.Bar
                    if bar then
                        EnsureProgressLabelHook(bar)
                        FormatProgressLabel(bar)
                    end
                end
            end
        end
    end
end

-- [ RE-SKIN EXISTING POI BUTTONS ]-------------------------------------------------------------------
-- Re-skin pre-existing POI buttons and refresh focus colors on SUPER_TRACKING_CHANGED.
function Plugin:ReSkinExistingPOIButtons()
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker and tracker.usedBlocks then
            for _, blocks in pairs(tracker.usedBlocks) do
                for _, block in pairs(blocks) do
                    if block then
                        -- Install per-instance hook for blocks that existed before OnAddBlock fired.
                        if not block._orbitPoiHooked then
                            if block.AddPOIButton then
                                hooksecurefunc(block, "AddPOIButton", SkinPOIButton)
                            end
                            block._orbitPoiHooked = true
                        end
                        SkinPOIButton(block)
                    end
                end
            end
        end
    end
end
