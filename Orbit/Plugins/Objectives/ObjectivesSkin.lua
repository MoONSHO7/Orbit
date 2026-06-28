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

-- [ SETTING CACHES ]---------------------------------------------------------------------------------
-- Populated once per ApplySkins() call to avoid per-block GetSetting() / Orbit.db reads.
local _cachedFont              = nil  -- nil until first ApplySkins(); falls back to STANDARD_TEXT_FONT
local _cachedTitleFontSize     = C.TITLE_FONT_SIZE_DEFAULT
local _cachedObjectiveFontSize = C.OBJECTIVE_FONT_SIZE_DEFAULT
local _cachedHeaderFontSize    = C.HEADER_FONT_SIZE_DEFAULT
local _cachedProgressSegs      = nil
local _cachedNormalColor       = C.TITLE_COLOR_DEFAULT
local _cachedCompletedColor    = C.COMPLETED_COLOR_DEFAULT
local _cachedFocusColor        = C.FOCUS_COLOR_DEFAULT

-- Super-tracked quest ID (updated by SUPER_TRACKING_CHANGED)
local _superTrackedQuestID = nil

-- [ HELPERS ]----------------------------------------------------------------------------------------
-- Resolves a stored color value, including the class-color sentinel { type = "class", a = ... }.
local POI_COLOR_DEFAULT_FALLBACK  = C.TITLE_COLOR_DEFAULT
local POI_COLOR_COMPLETE_FALLBACK = C.COMPLETED_COLOR_DEFAULT

local function ResolveColor(raw, fallback)
    if type(raw) == "table" and raw.type == "class" and OrbitEngine.ClassColor then
        local cc = OrbitEngine.ClassColor:GetCurrentClassColor()
        return { r = cc.r, g = cc.g, b = cc.b, a = raw.a or 1 }
    end
    return C.ValidateColor(raw, fallback)
end

local function GetGlobalFont()
    return _cachedFont or STANDARD_TEXT_FONT
end

local function GetTitleFontSize()     return _cachedTitleFontSize     end
local function GetObjectiveFontSize() return _cachedObjectiveFontSize end
local function GetHeaderFontSize()    return _cachedHeaderFontSize    end
local function GetNormalQuestColor()    return _cachedNormalColor    end
local function GetCompletedQuestColor() return _cachedCompletedColor end
local function GetFocusQuestColor()     return _cachedFocusColor     end

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

local function ApplyHeaderColors(header, color)
    if not header or not header.Text then return end
    header.Text:SetTextColor(color.r, color.g, color.b)
end

-- Blizzard's header frames are a fixed 32/26px regardless of font; size them to the font (floored at the 16px minimize button) so the bar hugs the text. minHeight omitted = font only (Scenario keeps its native height — its slide math depends on it). Returns the applied height.
local function ApplyHeaderFont(header, minHeight)
    if not header or not header.Text then return end
    ApplyFont(header.Text, GetHeaderFontSize())
    if not minHeight then return end
    local target = OrbitEngine.Pixel:Snap(math.max(GetHeaderFontSize() + 2 * C.HEADER_VPADDING, minHeight), header:GetEffectiveScale())
    header:SetHeight(target)
    return target
end

-- [ SKIN: HEADER SEPARATOR ]-------------------------------------------------------------------------
local function EnsureSeparator(header)
    if not header then return nil end
    if header._orbitSeparator then return header._orbitSeparator end

    local sep = header:CreateTexture(nil, "ARTWORK", nil, 1)
    header._orbitSeparator = sep
    return sep
end

local function ApplyHeaderSeparator(header, show, color, isClass)
    local sep = EnsureSeparator(header)
    if not sep then return end

    if not show then
        sep:Hide()
        return
    end

    -- Pixel-perfect divider: an exact physical-pixel thickness sitting that same distance below the header, re-applied here so it tracks UI-scale changes.
    local thickness = OrbitEngine.Pixel:Multiple(C.HEADER_SEPARATOR_HEIGHT, header:GetEffectiveScale())
    sep:SetHeight(thickness)
    sep:ClearAllPoints()
    sep:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -thickness)
    sep:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, -thickness)

    local alpha = isClass and C.SEPARATOR_ALPHA_CLASS or C.SEPARATOR_ALPHA
    sep:SetColorTexture(color.r, color.g, color.b, alpha)
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
    chevron:SetTextColor(C.CHEVRON_COLOR.r, C.CHEVRON_COLOR.g, C.CHEVRON_COLOR.b)
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

    -- Route both the master "All Objectives" header and the sub-headers through the plugin's toggle (the master animates, sub-headers are instant).
    local target = header:GetParent()
    if target and target.SetCollapsed then
        header.MinimizeButton:SetScript("OnClick", function()
            Plugin:ToggleCollapse(target)
        end)
    end

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

    local fs = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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

-- [ SKIN: POI BUTTON / BLOCK ICON ]------------------------------------------------------------------
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
local POI_TAG_ATLAS = {
    [Enum.QuestTag.Dungeon]  = "questlog-questtypeicon-dungeon",
    [Enum.QuestTag.Raid]     = "questlog-questtypeicon-raid",
    [Enum.QuestTag.Group]    = "questlog-questtypeicon-group",
    [Enum.QuestTag.PvP]      = "questlog-questtypeicon-pvp",
    [Enum.QuestTag.Heroic]   = "questlog-questtypeicon-heroic",
    [Enum.QuestTag.Scenario] = "questlog-questtypeicon-scenario",
    [Enum.QuestTag.Account]  = "questlog-questtypeicon-account",
    [Enum.QuestTag.Delve]    = "questlog-questtypeicon-delves",
}
-- Quest tag → title color mapping (mirrors atlas table for consistency)
local POI_TAG_COLOR = {
    [Enum.QuestTag.Dungeon]  = C.TAG_COLOR_GROUP,
    [Enum.QuestTag.Raid]     = C.TAG_COLOR_RAID,
    [Enum.QuestTag.Group]    = C.TAG_COLOR_GROUP,
    [Enum.QuestTag.PvP]      = C.TAG_COLOR_PVP,
    [Enum.QuestTag.Heroic]   = C.TAG_COLOR_GROUP,
    [Enum.QuestTag.Scenario] = C.TAG_COLOR_GROUP,
    [Enum.QuestTag.Account]  = C.TAG_COLOR_ACCOUNT,
    [Enum.QuestTag.Delve]    = C.TAG_COLOR_GROUP,
}

local POI_ATLAS_DEFAULT  = "QuestNormal"
local POI_ATLAS_COMPLETE = "QuestTurnin"

local function GetPOIAtlas(block)
    if block.poiIsComplete then return POI_ATLAS_COMPLETE end
    local questID = block.poiQuestID
    if not questID then return POI_ATLAS_DEFAULT end

    if C_QuestLog.ReadyForTurnIn(questID) then
        return POI_ATLAS_COMPLETE
    end

    -- Classification first: Legendary/Campaign/Important outrank generic tags (Raid, Dungeon)
    if C_CampaignInfo.IsCampaignQuest(questID) then
        return POI_CLASSIFICATION_ATLAS[Enum.QuestClassification.Campaign]
    end

    local classification = C_QuestInfoSystem.GetQuestClassification(questID)
    if classification and POI_CLASSIFICATION_ATLAS[classification] then
        return POI_CLASSIFICATION_ATLAS[classification]
    end

    local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
    if tagInfo and tagInfo.tagID and POI_TAG_ATLAS[tagInfo.tagID] then
        return POI_TAG_ATLAS[tagInfo.tagID]
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

    -- Legendary outranks tags (a legendary raid quest is still legendary)
    local classification = C_QuestInfoSystem.GetQuestClassification(questID)
    if classification == Enum.QuestClassification.Legendary then
        return POI_COLORS[Enum.QuestClassification.Legendary]
    end

    -- Tag colour (Raid/Dungeon/PvP) beats campaign/questline so it stays distinguishable
    local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
    if tagInfo and tagInfo.tagID and POI_TAG_COLOR[tagInfo.tagID] then
        return POI_TAG_COLOR[tagInfo.tagID]
    end

    if C_CampaignInfo.IsCampaignQuest(questID) then
        return POI_COLORS[Enum.QuestClassification.Campaign]
    end

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
-- Progress values are non-secret, so the % math here is safe (unlike health bars).
local PB_FORMATTERS = {
    ["%"]        = function(cur, max) return string.format("%.0f%%", (cur / max) * 100) end,
    ["CurrentK"] = function(cur, max) return AbbreviateNumbers(math.floor(cur)) end,
    ["Current"]  = function(cur, max) return tostring(math.floor(cur)) end,
    ["MaxK"]     = function(cur, max) return AbbreviateNumbers(math.floor(max)) end,
    ["Max"]      = function(cur, max) return tostring(math.floor(max)) end,
}

-- Token keys longest-first so "CurrentK"/"MaxK" match before "Current"/"Max".
local PB_KEYS = {}
for _, t in ipairs(C.PROGRESS_TOKENS) do PB_KEYS[#PB_KEYS + 1] = t.key end
table.sort(PB_KEYS, function(a, b) return #a > #b end)

local function ParseProgressFormat(str)
    str = strtrim(str or "")
    local segs, buffer = {}, ""
    local function flush()
        if buffer ~= "" then segs[#segs + 1] = { sep = buffer }; buffer = "" end
    end
    local i, n = 1, #str
    while i <= n do
        local matched
        for _, key in ipairs(PB_KEYS) do
            if str:sub(i, i + #key - 1):lower() == key:lower() then matched = key; break end
        end
        if matched then
            flush()
            segs[#segs + 1] = { token = matched }
            i = i + #matched
        else
            buffer = buffer .. str:sub(i, i)
            i = i + 1
        end
    end
    flush()
    return segs
end

-- Valid when the format contains at least one value token — drives the input's valid/invalid border.
function Plugin:ValidateProgressFormat(str)
    if type(str) ~= "string" then return false end
    for _, seg in ipairs(ParseProgressFormat(str)) do
        if seg.token then return true end
    end
    return false
end

local function FormatProgressLabel(bar)
    if not bar or not bar.Label then return end
    local _, max = bar:GetMinMaxValues()
    local cur = bar:GetValue()
    if not max or max == 0 then return end

    local segs = _cachedProgressSegs
    if not segs then return end

    local out = {}
    for _, seg in ipairs(segs) do
        if seg.token then
            out[#out + 1] = tostring(PB_FORMATTERS[seg.token](cur, max))
        else
            out[#out + 1] = seg.sep
        end
    end

    bar._orbitUpdating = true
    bar.Label:SetText(table.concat(out))
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

local function ApplyOrbitBarStyle(bar)
    local texture = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Texture
    local barTexture = texture and LSM:Fetch("statusbar", texture) or LSM:Fetch("statusbar", "Solid")
    bar:SetStatusBarTexture(barTexture)
    if not bar._orbitBG then
        local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetAllPoints(bar)
        bar._orbitBG = bg
    end
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local bgColor = Orbit.Skin:GetBackgroundColor()
    bar._orbitBG:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a or C.BAR_BG_ALPHA)

    -- Register surfaces so a rounded border style masks them (cast-bar pattern).
    Orbit.Skin:RegisterMaskedSurface(bar, bar._orbitBG)
    local fill = bar:GetStatusBarTexture()
    if fill then Orbit.Skin:RegisterMaskedSurface(bar, fill) end

    local borderSize = gs and gs.BorderSize or 1
    Orbit.Skin:SkinBorder(bar, bar, borderSize)
end

-- [ SKIN: PROGRESS BAR ]-----------------------------------------------------------------------------
-- Size the progressBar container off the stable Orbit tracker frame (the width FitTrackerWidths applies to modules/headers), NOT the per-module ContentsFrame, which Blizzard resets to 260 mid-layout. The Bar anchors to this container so it follows; a RIGHT anchor instead would fight the lone TOPLEFT into the block chain and flicker during the collapse slide.
local function FitProgressBarWidth(progressBar, trackerWidth)
    if not progressBar or not trackerWidth or trackerWidth <= 0 then return end
    progressBar:SetWidth(OrbitEngine.Pixel:Snap(trackerWidth - C.PROGRESS_BAR_WIDTH_INSET, progressBar:GetEffectiveScale()))
end

local function SkinProgressBar(tracker, key)
    if not _enabled then return end
    local progressBar = tracker.usedProgressBars and tracker.usedProgressBars[key]
    local bar = progressBar and progressBar.Bar
    if not bar then return end

    -- While our slide owns this module (or the master), leave an already-skinned bar untouched — re-fitting it on the frames it is being translated reads as a flicker. Width is constant across a collapse (only height animates), so the prior fit still holds.
    if bar._orbitSkinned and (tracker._orbitAnimating or ObjectiveTrackerFrame._orbitAnimating) then return end

    FitProgressBarWidth(progressBar, ObjectiveTrackerFrame and ObjectiveTrackerFrame:GetWidth() or 0)

    if bar._orbitSkinned then return end

    -- Strip Blizzard textures
    if bar.StripTextures then
        bar:StripTextures()
    else
        for i = 1, bar:GetNumRegions() do
            local region = select(i, bar:GetRegions())
            if region and region:IsObjectType("Texture") and region ~= bar:GetStatusBarTexture() and region ~= bar.Icon then
                region:SetTexture(nil)
            end
        end
    end

    bar:SetHeight(C.PROGRESS_BAR_HEIGHT)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", progressBar, "TOPRIGHT", 0, 0)

    progressBar:SetHeight(C.PROGRESS_BAR_CONTAINER_HEIGHT)

    -- Icon at the bar's left; set even when hidden — Blizzard shows the reward icon after GetProgressBar but never re-anchors.
    local icon = bar.Icon
    local iconWidth = 0
    if icon then
        if icon.SetMask then icon:SetMask("") end
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        icon:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        icon:SetWidth(C.PROGRESS_BAR_HEIGHT)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetDrawLayer("OVERLAY")
        Orbit.Skin:RegisterMaskedSurface(bar, icon)
        iconWidth = C.PROGRESS_BAR_HEIGHT
    end

    -- Plain glow (drop the reward-ring cut-out), inset from the bar edges.
    if bar.BarGlow and not bar.BarGlow._orbitGlowHooked then
        local function styleGlow(glow)
            glow:ClearAllPoints()
            glow:SetPoint("TOPLEFT", bar, "TOPLEFT", C.BAR_GLOW_INSET, 0)
            glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -C.BAR_GLOW_INSET, 0)
        end
        hooksecurefunc(bar.BarGlow, "SetAtlas", function(self, atlas)
            if atlas == "bonusobjectives-bar-glow-ring" then
                self:SetAtlas("bonusobjectives-bar-glow")
            elseif atlas == "bonusobjectives-bar-glow" then
                styleGlow(self)
            end
        end)
        if bar.BarGlow:GetAtlas() == "bonusobjectives-bar-glow-ring" then
            bar.BarGlow:SetAtlas("bonusobjectives-bar-glow")
        end
        bar.BarGlow._orbitGlowHooked = true
    end

    ApplyOrbitBarStyle(bar)

    -- Label centred in the space to the right of the icon
    if bar.Label then
        ApplyFont(bar.Label, C.PROGRESS_BAR_FONT_SIZE)
        bar.Label:ClearAllPoints()
        bar.Label:SetPoint("LEFT", bar, "LEFT", iconWidth + C.PROGRESS_BAR_LABEL_PADDING, 0)
        bar.Label:SetPoint("RIGHT", bar, "RIGHT", -C.PROGRESS_BAR_LABEL_PADDING, 0)
        bar.Label:SetJustifyH("CENTER")
    end

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

    ApplyOrbitBarStyle(bar)

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

        ApplyOrbitBarStyle(bar)
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

-- [ SKIN: UI WIDGET ICON AND TEXT ]------------------------------------------------------------------
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

-- [ FIT WIDTHS ]-------------------------------------------------------------------------------------
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
            -- MawBuffsBlock is a 243px FixedBlock whose TOPRIGHT-anchored Container drifts if ContentsFrame is wider
            if tracker.MawBuffsBlock then
                tracker.MawBuffsBlock:SetWidth(width)
            end
            -- Reflow already-rendered progress bars (they size explicitly now, not via a RIGHT anchor) so a live Width change resizes them without waiting for a re-layout.
            if tracker.usedProgressBars then
                for _, pb in pairs(tracker.usedProgressBars) do
                    FitProgressBarWidth(pb, width)
                end
            end
        end
    end
end

-- [ RE-APPLY SKINS (called from ApplySettings) ]-----------------------------------------------------
function Plugin:ApplySkins()
    if not self._hooksInstalled then return end

    -- Refresh all caches before any skin pass reads them
    do
        local gs = Orbit.db and Orbit.db.GlobalSettings
        local fontName = gs and gs.Font
        _cachedFont = fontName and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    end
    _cachedTitleFontSize     = self:GetSetting(SYSTEM_ID, "TitleFontSize") or C.TITLE_FONT_SIZE_DEFAULT
    _cachedObjectiveFontSize = self:GetSetting(SYSTEM_ID, "ObjectiveFontSize") or C.OBJECTIVE_FONT_SIZE_DEFAULT
    _cachedHeaderFontSize    = self:GetSetting(SYSTEM_ID, "HeaderFontSize") or C.HEADER_FONT_SIZE_DEFAULT
    local pbFormat = self:GetSetting(SYSTEM_ID, "ProgressBarLabelFormat")
    if not pbFormat or pbFormat == "" then pbFormat = C.PROGRESS_FORMAT_DEFAULT end
    _cachedProgressSegs      = ParseProgressFormat(pbFormat)
    _cachedNormalColor       = ResolveColor(self:GetSetting(SYSTEM_ID, "TitleColor"), POI_COLOR_DEFAULT_FALLBACK)
    _cachedCompletedColor    = ResolveColor(self:GetSetting(SYSTEM_ID, "CompletedColor"), POI_COLOR_COMPLETE_FALLBACK)
    _cachedFocusColor        = ResolveColor(self:GetSetting(SYSTEM_ID, "FocusColor"), C.FOCUS_COLOR_DEFAULT)

    local headerRaw = self:GetSetting(SYSTEM_ID, "HeaderColor")
    local headerColor = ResolveColor(headerRaw, C.HEADER_COLOR_DEFAULT)
    local headerIsClass = type(headerRaw) == "table" and headerRaw.type == "class"
    local headerSeparators = self:GetSetting(SYSTEM_ID, "HeaderSeparators")

    -- Fit all widths to our container
    self:FitTrackerWidths()

    -- Main tracker header
    local trackerFrame = ObjectiveTrackerFrame
    if trackerFrame and trackerFrame.Header then
        ApplyHeaderColors(trackerFrame.Header, headerColor)
        -- Size the master header to the font and lockstep topModulePadding (the first-module offset Blizzard reserves). The gap below the master uses the content inset so master->module spacing matches the box's top/bottom inset — uniform throughout, and the master's divider clears its neighbour by the same margin the last divider clears the border.
        local masterH = ApplyHeaderFont(trackerFrame.Header, C.HEADER_MIN_HEIGHT)
        if masterH then trackerFrame.topModulePadding = masterH + self:GetContentInset() end
        ApplyHeaderSeparator(trackerFrame.Header, headerSeparators ~= false, headerColor, headerIsClass)

        -- Quest counter
        local showCount = self:GetSetting(SYSTEM_ID, "ShowQuestCount") ~= false
        if showCount then
            local counter = EnsureQuestCounter(trackerFrame.Header)
            if counter then
                ApplyFont(counter, GetObjectiveFontSize())
                counter:SetTextColor(C.QUEST_COUNT_COLOR.r, C.QUEST_COUNT_COLOR.g, C.QUEST_COUNT_COLOR.b)
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
            ApplyHeaderColors(tracker.Header, headerColor)
            -- Scenario derives its collapse/slide math from headerHeight, so leave it native (font only); every other module's header tracks the font and updates headerHeight in lockstep so its content height stays correct.
            if moduleName == "ScenarioObjectiveTracker" then
                ApplyHeaderFont(tracker.Header)
            else
                local mH = ApplyHeaderFont(tracker.Header, C.MODULE_HEADER_MIN_HEIGHT)
                if mH then tracker.headerHeight = mH end
            end
            ApplyHeaderSeparator(tracker.Header, headerSeparators ~= false, headerColor, headerIsClass)
        end
    end

    -- Separators are coloured/shown above; hide the trailing one (collapsed header at the box bottom) synchronously so it doesn't flash before the next relayout's UpdateSeparators.
    self:UpdateSeparators()

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

            -- Re-apply bar styling so global texture/border/background changes apply live
            if tracker.usedProgressBars then
                for _, progressBar in pairs(tracker.usedProgressBars) do
                    local bar = progressBar and progressBar.Bar
                    if bar then
                        ApplyOrbitBarStyle(bar)
                        EnsureProgressLabelHook(bar)
                        FormatProgressLabel(bar)
                    end
                end
            end

            -- Timer bars: same restyle for live global changes
            if tracker.usedTimerBars then
                for _, timerBar in pairs(tracker.usedTimerBars) do
                    local bar = timerBar and timerBar.Bar
                    if bar then ApplyOrbitBarStyle(bar) end
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
