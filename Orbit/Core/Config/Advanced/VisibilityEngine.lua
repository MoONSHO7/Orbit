-- [ VISIBILITY ENGINE CONTENT ]---------------------------------------------------------------------
-- Scrollable table for frame visibility, opacity, and fade behavior.
local _, Orbit = ...
local L = Orbit.L
local Layout = Orbit.Engine.Layout
local A = Layout.Advanced

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local FONT_HIGHLIGHT = "GameFontHighlight"
local FONT_SMALL = "GameFontNormalSmall"
local FONT_TINY = "SystemFont_Tiny"
local FONT_GROUP = "GameFontNormal"
local GROUP_HEADER_COLOR = { r = 1, g = 0.82, b = 0 }
local VE_ROW_HEIGHT = 30
local VE_LABEL_WIDTH = 140
local VE_CHECK_WIDTH = 26
local VE_CHECK_COL_WIDTH = 72
local VE_OPACITY_COL_WIDTH = 130
local VE_EDGE_EXTEND = 5  -- Stretch table 5px beyond A.PADDING on both sides
local VE_SLIDER_WIDTH = 85
local VE_VALUE_WIDTH = 36
local VE_LABEL_PAD = 4
local VE_SECTION_GAP = 6
local VE_SLIDER_INSET = 10
local VE_COLUMNS = { L.CFG_ALPHA_LOCK, L.CFG_OPACITY, L.CFG_OOC_FADE, L.CFG_HIDE_MOUNTED, L.CFG_SHOW_MOUSEOVER, L.CFG_SHOW_TARGET }
local VE_COLUMN_TIPS = { L.CFG_ALPHA_LOCK_TIP, L.CFG_OPACITY_TIP, L.CFG_OOC_FADE_TIP, L.CFG_HIDE_MOUNTED_TIP, L.CFG_SHOW_MOUSEOVER_TIP, L.CFG_SHOW_TARGET_TIP }
-- i == 1 is Alpha Lock (check width), i == 2 is Opacity (slider width), rest are CHECK_SETTING_KEYS.
local CHECK_SETTING_KEYS = { "oocFade", "hideMounted", "mouseOver", "showWithTarget" }
local SEARCH_WIDTH = 200
local SEARCH_HEIGHT = 30
local SEARCH_RIGHT_INSET = 34

-- [ BUILD ]-----------------------------------------------------------------------------------------
function Orbit._AC.CreateVEContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    content:Hide()
    local header = Layout:CreateSectionHeader(content, L.CFG_VISIBILITY_ENGINE)
    header:SetPoint("TOPLEFT", A.PADDING, A.TITLE_Y)
    header:SetPoint("TOPRIGHT", -A.PADDING, A.TITLE_Y)
    local desc = Layout:CreateDescription(content, L.CFG_VISIBILITY_ENGINE_DESC, A.MUTED)
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)

    -- Search box (styled to match the QoL panel)
    local searchContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    searchContainer:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
    searchContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -A.PADDING - SEARCH_RIGHT_INSET, A.TITLE_Y + 4)
    searchContainer:SetBackdrop(Layout.ORBIT_INPUT_BACKDROP)
    searchContainer:SetBackdropColor(0, 0, 0, 0.5)
    searchContainer:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    searchContainer:SetFrameLevel(content:GetFrameLevel() + 20)

    local searchBox = CreateFrame("EditBox", nil, searchContainer, "SearchBoxTemplate")
    searchBox:SetPoint("TOPLEFT", searchContainer, "TOPLEFT", 8, 0)
    searchBox:SetPoint("BOTTOMRIGHT", searchContainer, "BOTTOMRIGHT", -4, 0)
    searchBox:SetFontObject(ChatFontNormal)
    searchBox:SetAutoFocus(false)
    if searchBox.Left then searchBox.Left:Hide() end
    if searchBox.Middle then searchBox.Middle:Hide() end
    if searchBox.Right then searchBox.Right:Hide() end
    content.searchBox = searchBox

    -- Sticky column headers (frozen above scroll)
    local stickyTop = A.CONTENT_START_Y
    local headerRow = CreateFrame("Frame", nil, content)
    headerRow:SetHeight(VE_ROW_HEIGHT)
    headerRow:SetFrameLevel(content:GetFrameLevel() + 10)
    headerRow:SetPoint("TOPLEFT", A.PADDING - VE_EDGE_EXTEND, stickyTop)
    headerRow:SetPoint("TOPRIGHT", -A.PADDING - 14 + VE_EDGE_EXTEND, stickyTop)
    local headerBG = headerRow:CreateTexture(nil, "BACKGROUND")
    headerBG:SetAllPoints()
    headerBG:SetColorTexture(0.08, 0.08, 0.08, 1)
    local colX = VE_LABEL_WIDTH
    for i, text in ipairs(VE_COLUMNS) do
        local colWidth = (i == 2) and VE_OPACITY_COL_WIDTH or VE_CHECK_COL_WIDTH
        local colHit = CreateFrame("Frame", nil, headerRow)
        colHit:SetPoint("LEFT", colX, 0)
        colHit:SetSize(colWidth, VE_ROW_HEIGHT)
        colHit:EnableMouse(true)
        local colLabel = colHit:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        colLabel:SetAllPoints()
        colLabel:SetText("|cFFFFD100" .. text .. "|r")
        colLabel:SetJustifyH("CENTER")
        local tipText = VE_COLUMN_TIPS[i]
        if tipText then
            colHit:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(text, 1, 0.82, 0, 1, true)
                GameTooltip:AddLine(tipText, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            colHit:SetScript("OnLeave", GameTooltip_Hide)
        end
        colX = colX + colWidth
    end
    local checkAllRow = CreateFrame("Frame", nil, content)
    checkAllRow:SetHeight(VE_ROW_HEIGHT)
    checkAllRow:SetFrameLevel(content:GetFrameLevel() + 10)
    checkAllRow:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, 0)
    checkAllRow:SetPoint("TOPRIGHT", headerRow, "BOTTOMRIGHT", 0, 0)
    local checkAllBG = checkAllRow:CreateTexture(nil, "BACKGROUND")
    checkAllBG:SetAllPoints()
    checkAllBG:SetColorTexture(0.12, 0.10, 0.06, 1)
    local checkAllLabel = checkAllRow:CreateFontString(nil, "OVERLAY", FONT_GROUP)
    checkAllLabel:SetPoint("LEFT", VE_LABEL_PAD, 0)
    checkAllLabel:SetText("|cFFFFD100" .. L.CFG_CHECK_ALL .. "|r")
    content.checkAllRow = checkAllRow
    -- Modern scrollable data area (below sticky rows)
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", checkAllRow, "BOTTOMLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -A.PADDING - 14 + VE_EDGE_EXTEND, A.PADDING + 10)
    if scrollFrame.ScrollBar then scrollFrame.ScrollBar:SetAlpha(0) end
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(1)
    scrollFrame:SetScrollChild(scrollChild)
    content.scrollChild = scrollChild
    content.scrollFrame = scrollFrame
    content.rows = {}

    -- Helper: create an opacity slider for a row
    local function CreateOpacitySlider(rowParent, colPos, curVal, onChange)
        local wrapper = CreateFrame("Frame", nil, rowParent, "MinimalSliderWithSteppersTemplate")
        wrapper:SetPoint("LEFT", colPos - VE_SLIDER_INSET, 0)
        wrapper:SetSize(VE_SLIDER_WIDTH + VE_SLIDER_INSET, VE_ROW_HEIGHT)
        if wrapper.Back then wrapper.Back:Hide() end
        if wrapper.Forward then wrapper.Forward:Hide() end
        wrapper.Slider:ClearAllPoints()
        wrapper.Slider:SetPoint("LEFT", VE_LABEL_PAD, 0)
        wrapper.Slider:SetPoint("RIGHT", -VE_LABEL_PAD, 0)
        local valueText = rowParent:CreateFontString(nil, "OVERLAY", FONT_TINY)
        valueText:SetPoint("LEFT", wrapper, "RIGHT", 2, 0)
        valueText:SetWidth(VE_VALUE_WIDTH)
        valueText:SetJustifyH("RIGHT")
        valueText:SetText("|cFFCCCCCC" .. curVal .. "%|r")
        wrapper._valueText = valueText
        wrapper._initGuard = true
        wrapper:Init(curVal, 0, 100, 20, {})
        wrapper._initGuard = false
        wrapper:RegisterCallback("OnValueChanged", function(_, val)
            if wrapper._initGuard then return end
            val = math.floor(val)
            valueText:SetText("|cFFCCCCCC" .. val .. "%|r")
            if onChange then onChange(val, wrapper) end
        end, wrapper)
        return wrapper, valueText
    end

    function content:BuildTable()
        for _, row in ipairs(self.rows) do row:Hide() end
        wipe(self.rows)
        local VE = Orbit.VisibilityEngine
        if not VE then return end
        local frames = VE:GetAllFrames()
        local blizzFrames = VE:GetBlizzardFrames() or {}
        local thirdPartyFrames = VE.GetThirdPartyFrames and VE:GetThirdPartyFrames() or {}
        -- Rebuild Check All controls
        local caRow = self.checkAllRow
        for _, child in ipairs({ caRow:GetChildren() }) do child:Hide() end
        if self._gaValueText then self._gaValueText:Hide() end
        local caColPos = VE_LABEL_WIDTH
        -- Check-All for Alpha Lock (leading column)
        do
            local caCB = CreateFrame("CheckButton", nil, caRow, "UICheckButtonTemplate")
            caCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            caCB:SetPoint("LEFT", caColPos + (VE_CHECK_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            local allOn = true
            for _, entry in ipairs(frames) do
                local plugin = VE:GetPlugin(entry)
                if plugin and Orbit:IsPluginEnabled(entry.plugin) then
                    if not VE:GetFrameSetting(entry.key, "alphaLock") then allOn = false; break end
                end
            end
            caCB:SetChecked(allOn)
            caCB:SetScript("OnClick", function(btn)
                local newVal = btn:GetChecked()
                for _, entry in ipairs(frames) do
                    local plugin = VE:GetPlugin(entry)
                    if plugin and Orbit:IsPluginEnabled(entry.plugin) then VE:SetFrameSetting(entry.key, "alphaLock", newVal) end
                end
                for _, entry in ipairs(blizzFrames) do VE:SetFrameSetting(entry.key, "alphaLock", newVal) end
                VE:ApplyAll()
                content:BuildTable()
            end)
            caColPos = caColPos + VE_CHECK_COL_WIDTH
        end
        -- Global opacity slider
        local gaWrapper, gaValueText = CreateOpacitySlider(caRow, caColPos, 100, function(val)
            for _, entry in ipairs(frames) do
                local plugin = VE:GetPlugin(entry)
                if plugin and Orbit:IsPluginEnabled(entry.plugin) then VE:SetFrameSetting(entry.key, "opacity", val) end
            end
            for _, entry in ipairs(blizzFrames) do VE:SetFrameSetting(entry.key, "opacity", val) end
            VE:ApplyAll()
            for _, rs in ipairs(self.rowSliders or {}) do
                rs._initGuard = true
                rs:SetValue(val)
                if rs._valueText then rs._valueText:SetText("|cFFCCCCCC" .. val .. "%|r") end
                rs._initGuard = false
            end
        end)
        self._gaValueText = gaValueText
        caColPos = caColPos + VE_OPACITY_COL_WIDTH
        -- Check-All toggles (loop instead of 4 duplicated blocks)
        for _, settingKey in ipairs(CHECK_SETTING_KEYS) do
            local caCB = CreateFrame("CheckButton", nil, caRow, "UICheckButtonTemplate")
            caCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            caCB:SetPoint("LEFT", caColPos + (VE_CHECK_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            local allOn = true
            for _, entry in ipairs(frames) do
                local plugin = VE:GetPlugin(entry)
                if plugin and Orbit:IsPluginEnabled(entry.plugin) and not entry.opacityOnly then
                    if not VE:GetFrameSetting(entry.key, settingKey) then allOn = false; break end
                end
            end
            caCB:SetChecked(allOn)
            caCB:SetScript("OnClick", function(btn)
                local newVal = btn:GetChecked()
                for _, entry in ipairs(frames) do
                    local plugin = VE:GetPlugin(entry)
                    if plugin and Orbit:IsPluginEnabled(entry.plugin) and not entry.opacityOnly then VE:SetFrameSetting(entry.key, settingKey, newVal) end
                end
                for _, entry in ipairs(blizzFrames) do VE:SetFrameSetting(entry.key, settingKey, newVal) end
                VE:ApplyAll()
                content:BuildTable()
            end)
            caColPos = caColPos + VE_CHECK_COL_WIDTH
        end
        -- Data rows
        self.rowSliders = {}
        local rowIndex = 0
        local yOffset = 0
        local function CreateVERow(entry, isBlizzard, section)
            rowIndex = rowIndex + 1
            local row = CreateFrame("Frame", nil, scrollChild)
            row:SetHeight(VE_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 0, yOffset)
            row:SetPoint("TOPRIGHT", 0, yOffset)
            row._searchName = (entry.display or ""):lower()
            row._section = section or "orbit"
            row._isData = true
            if rowIndex % 2 == 0 then
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(1, 1, 1, 0.03)
            end
            local nameLabel = row:CreateFontString(nil, "OVERLAY", FONT_HIGHLIGHT)
            nameLabel:SetPoint("LEFT", VE_LABEL_PAD, 0)
            nameLabel:SetText(isBlizzard and ("|cFF9999BB" .. entry.display .. "|r") or entry.display)
            nameLabel:SetWidth(VE_LABEL_WIDTH - VE_LABEL_PAD * 2)
            nameLabel:SetJustifyH("LEFT")
            local colPos = VE_LABEL_WIDTH
            -- Alpha Lock checkbox (leading column)
            do
                local alCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                alCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
                alCB:SetPoint("LEFT", colPos + (VE_CHECK_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
                alCB:SetChecked(VE:GetFrameSetting(entry.key, "alphaLock"))
                alCB:SetScript("OnClick", function(btn) VE:SetFrameSetting(entry.key, "alphaLock", btn:GetChecked()); VE:ApplyFrame(entry.key) end)
                colPos = colPos + VE_CHECK_COL_WIDTH
            end
            -- Opacity slider
            local sliderWrapper = CreateOpacitySlider(row, colPos, VE:GetFrameSetting(entry.key, "opacity"), function(val)
                VE:SetFrameSetting(entry.key, "opacity", val)
                VE:ApplyFrame(entry.key)
            end)
            table.insert(content.rowSliders, sliderWrapper)
            colPos = colPos + VE_OPACITY_COL_WIDTH
            -- Boolean setting checkboxes (loop instead of 4 duplicated blocks)
            if not entry.opacityOnly then
                for _, settingKey in ipairs(CHECK_SETTING_KEYS) do
                    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                    cb:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
                    cb:SetPoint("LEFT", colPos + (VE_CHECK_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
                    cb:SetChecked(VE:GetFrameSetting(entry.key, settingKey))
                    cb:SetScript("OnClick", function(btn) VE:SetFrameSetting(entry.key, settingKey, btn:GetChecked()); VE:ApplyFrame(entry.key) end)
                    colPos = colPos + VE_CHECK_COL_WIDTH
                end
            end
            table.insert(self.rows, row)
            yOffset = yOffset - VE_ROW_HEIGHT
        end
        -- Orbit plugin rows
        for _, entry in ipairs(frames) do
            local plugin = VE:GetPlugin(entry)
            if plugin and Orbit:IsPluginEnabled(entry.plugin) then CreateVERow(entry, false, "orbit") end
        end
        -- Blizzard Frames section
        if #blizzFrames > 0 then
            yOffset = yOffset - VE_SECTION_GAP
            local sectionRow = CreateFrame("Frame", nil, scrollChild)
            sectionRow:SetHeight(VE_ROW_HEIGHT)
            sectionRow:SetPoint("TOPLEFT", 0, yOffset)
            sectionRow:SetPoint("TOPRIGHT", 0, yOffset)
            local sectionLabel = sectionRow:CreateFontString(nil, "OVERLAY", FONT_GROUP)
            sectionLabel:SetPoint("LEFT", VE_LABEL_PAD, 0)
            sectionLabel:SetTextColor(GROUP_HEADER_COLOR.r, GROUP_HEADER_COLOR.g, GROUP_HEADER_COLOR.b)
            sectionLabel:SetText(L.CFG_BLIZZARD_FRAMES)
            sectionRow._isHeader = true
            sectionRow._sectionFor = "blizzard"
            table.insert(self.rows, sectionRow)
            yOffset = yOffset - VE_ROW_HEIGHT
            for _, entry in ipairs(blizzFrames) do CreateVERow(entry, true, "blizzard") end
        end
        -- Third-Party Addons section
        if #thirdPartyFrames > 0 then
            yOffset = yOffset - VE_SECTION_GAP
            local tpaRow = CreateFrame("Frame", nil, scrollChild)
            tpaRow:SetHeight(VE_ROW_HEIGHT)
            tpaRow:SetPoint("TOPLEFT", 0, yOffset)
            tpaRow:SetPoint("TOPRIGHT", 0, yOffset)
            local tpaLabel = tpaRow:CreateFontString(nil, "OVERLAY", FONT_GROUP)
            tpaLabel:SetPoint("LEFT", VE_LABEL_PAD, 0)
            tpaLabel:SetTextColor(GROUP_HEADER_COLOR.r, GROUP_HEADER_COLOR.g, GROUP_HEADER_COLOR.b)
            tpaLabel:SetText(L.CFG_THIRD_PARTY_ADDONS)
            tpaRow._isHeader = true
            tpaRow._sectionFor = "thirdparty"
            table.insert(self.rows, tpaRow)
            yOffset = yOffset - VE_ROW_HEIGHT
            for _, entry in ipairs(thirdPartyFrames) do CreateVERow(entry, true, "thirdparty") end
        end
        local totalHeight = math.abs(yOffset) + VE_ROW_HEIGHT
        scrollChild:SetHeight(totalHeight)
        if scrollFrame.ScrollBar then
            scrollFrame.ScrollBar:SetAlpha(totalHeight > scrollFrame:GetHeight() and 1 or 0)
        end
        self:ApplySearchFilter()
    end

    -- Filter visible rows based on the search text, then re-stack them.
    function content:ApplySearchFilter()
        local query = (self.searchBox and self.searchBox:GetText() or ""):lower()
        local isSearching = query ~= ""
        local sectionHasMatch = { orbit = false, blizzard = false, thirdparty = false }
        for _, row in ipairs(self.rows) do
            if row._isData then
                local match = (not isSearching) or string.find(row._searchName, query, 1, true) ~= nil
                row._visible = match
                if match then sectionHasMatch[row._section] = true end
            end
        end
        for _, row in ipairs(self.rows) do
            if row._isHeader then
                row._visible = sectionHasMatch[row._sectionFor] == true
            end
        end
        local y = 0
        for _, row in ipairs(self.rows) do
            if row._visible then
                if row._isHeader then y = y - VE_SECTION_GAP end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, y)
                row:SetPoint("TOPRIGHT", 0, y)
                row:Show()
                y = y - VE_ROW_HEIGHT
            else
                row:Hide()
            end
        end
        local total = math.abs(y) + VE_ROW_HEIGHT
        scrollChild:SetHeight(total)
        if scrollFrame.ScrollBar then
            scrollFrame.ScrollBar:SetAlpha(total > scrollFrame:GetHeight() and 1 or 0)
        end
    end

    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        content:ApplySearchFilter()
    end)

    content:SetScript("OnShow", function(self) self:BuildTable() end)
    return content
end
