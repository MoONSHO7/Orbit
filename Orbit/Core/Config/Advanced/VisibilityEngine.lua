-- [ VISIBILITY ENGINE CONTENT ]---------------------------------------------------------------------
-- Scrollable table for frame visibility, opacity, and fade behavior.
local _, Orbit = ...

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local PADDING = 16
local HEADER_HEIGHT = 40
local FONT_HEADER = "GameFontNormalLarge"
local FONT_HIGHLIGHT = "GameFontHighlight"
local FONT_SMALL = "GameFontNormalSmall"
local FONT_TINY = "SystemFont_Tiny"
local FONT_GROUP = "GameFontNormal"
local GROUP_HEADER_COLOR = { r = 1, g = 0.82, b = 0 }
local TITLE_Y = -(HEADER_HEIGHT + 30)
local CONTENT_START_Y = -(HEADER_HEIGHT + 80)
local VE_ROW_HEIGHT = 30
local VE_LABEL_WIDTH = 140
local VE_CHECK_WIDTH = 26
local VE_CHECK_COL_WIDTH = 90
local VE_OPACITY_COL_WIDTH = 130
local VE_SLIDER_WIDTH = 85
local VE_VALUE_WIDTH = 36
local VE_COLUMNS = { "Opacity", "Out Of Combat Fade", "Hide When Mounted", "Show on Mouse Over", "Show on Target" }
local VE_SETTINGS = { "opacity",  "oocFade",  "hideMounted", "mouseOver", "showWithTarget" }

-- [ BUILD ]-----------------------------------------------------------------------------------------
function Orbit._AC.CreateVEContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    content:Hide()
    local Layout = Orbit.Engine.Layout
    local header = Layout:CreateSectionHeader(content, "Visibility Engine")
    header:SetPoint("TOPLEFT", PADDING, TITLE_Y)
    header:SetPoint("TOPRIGHT", -PADDING, TITLE_Y)
    local desc = Layout:CreateDescription(content, "Configure frame visibility, opacity, and fade behavior.", { r = 0.53, g = 0.53, b = 0.53 })
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    -- Sticky column headers (frozen above scroll)
    local stickyTop = CONTENT_START_Y
    local headerRow = CreateFrame("Frame", nil, content)
    headerRow:SetHeight(VE_ROW_HEIGHT)
    headerRow:SetFrameLevel(content:GetFrameLevel() + 10)
    headerRow:SetPoint("TOPLEFT", PADDING, stickyTop)
    headerRow:SetPoint("TOPRIGHT", -PADDING - 14, stickyTop)
    local headerBG = headerRow:CreateTexture(nil, "BACKGROUND")
    headerBG:SetAllPoints()
    headerBG:SetColorTexture(0.08, 0.08, 0.08, 1)
    local colX = VE_LABEL_WIDTH
    for i, text in ipairs(VE_COLUMNS) do
        local colWidth = (i == 1) and VE_OPACITY_COL_WIDTH or VE_CHECK_COL_WIDTH
        local label = headerRow:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        label:SetPoint("LEFT", colX, 0)
        label:SetText("|cFFFFD100" .. text .. "|r")
        label:SetWidth(colWidth)
        label:SetJustifyH("CENTER")
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
    checkAllLabel:SetPoint("LEFT", 4, 0)
    checkAllLabel:SetText("|cFFFFD100Check All|r")
    content.checkAllRow = checkAllRow
    -- Modern scrollable data area (below sticky rows)
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", checkAllRow, "BOTTOMLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -PADDING - 14, PADDING + 10)
    if scrollFrame.ScrollBar then scrollFrame.ScrollBar:SetAlpha(0) end
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(1)
    scrollFrame:SetScrollChild(scrollChild)
    content.scrollChild = scrollChild
    content.scrollFrame = scrollFrame
    content.rows = {}

    function content:BuildTable()
        for _, row in ipairs(self.rows) do row:Hide() end
        wipe(self.rows)
        local VE = Orbit.VisibilityEngine
        if not VE then return end
        local frames = VE:GetAllFrames()
        local blizzFrames = VE:GetBlizzardFrames() or {}
        -- Rebuild Check All controls
        local caRow = self.checkAllRow
        for _, child in ipairs({ caRow:GetChildren() }) do child:Hide() end
        if self._gaValueText then self._gaValueText:Hide() end
        local caColPos = VE_LABEL_WIDTH
        -- Global opacity slider
        local gaWrapper = CreateFrame("Frame", nil, caRow, "MinimalSliderWithSteppersTemplate")
        gaWrapper:SetPoint("LEFT", caColPos - 10, 0)
        gaWrapper:SetSize(VE_SLIDER_WIDTH + 10, VE_ROW_HEIGHT)
        if gaWrapper.Back then gaWrapper.Back:Hide() end
        if gaWrapper.Forward then gaWrapper.Forward:Hide() end
        gaWrapper.Slider:ClearAllPoints()
        gaWrapper.Slider:SetPoint("LEFT", 4, 0)
        gaWrapper.Slider:SetPoint("RIGHT", -4, 0)
        local gaValueText = caRow:CreateFontString(nil, "OVERLAY", FONT_TINY)
        self._gaValueText = gaValueText
        gaValueText:SetPoint("LEFT", gaWrapper, "RIGHT", 2, 0)
        gaValueText:SetWidth(VE_VALUE_WIDTH)
        gaValueText:SetJustifyH("RIGHT")
        gaValueText:SetText("|cFFCCCCCC100%|r")
        gaWrapper._initGuard = true
        gaWrapper:Init(100, 0, 100, 20, {})
        gaWrapper._initGuard = false
        gaWrapper:RegisterCallback("OnValueChanged", function(_, val)
            if gaWrapper._initGuard then return end
            val = math.floor(val)
            gaValueText:SetText("|cFFCCCCCC" .. val .. "%|r")
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
        end, gaWrapper)
        caColPos = caColPos + VE_OPACITY_COL_WIDTH
        -- Check-All toggles
        local checkAllKeys = { "oocFade", "hideMounted", "mouseOver", "showWithTarget" }
        for _, settingKey in ipairs(checkAllKeys) do
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
            caCB:SetScript("OnClick", function(self)
                local newVal = self:GetChecked()
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
        local function CreateVERow(entry, isBlizzard)
            rowIndex = rowIndex + 1
            local row = CreateFrame("Frame", nil, scrollChild)
            row:SetHeight(VE_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 0, yOffset)
            row:SetPoint("TOPRIGHT", 0, yOffset)
            if rowIndex % 2 == 0 then
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(1, 1, 1, 0.03)
            end
            local nameLabel = row:CreateFontString(nil, "OVERLAY", FONT_HIGHLIGHT)
            nameLabel:SetPoint("LEFT", 4, 0)
            nameLabel:SetText(isBlizzard and ("|cFF9999BB" .. entry.display .. "|r") or entry.display)
            nameLabel:SetWidth(VE_LABEL_WIDTH - 8)
            nameLabel:SetJustifyH("LEFT")
            local colPos = VE_LABEL_WIDTH
            -- 1. Opacity slider
            local sliderWrapper = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
            sliderWrapper:SetPoint("LEFT", colPos - 10, 0)
            sliderWrapper:SetSize(VE_SLIDER_WIDTH + 10, VE_ROW_HEIGHT)
            if sliderWrapper.Back then sliderWrapper.Back:Hide() end
            if sliderWrapper.Forward then sliderWrapper.Forward:Hide() end
            sliderWrapper.Slider:ClearAllPoints()
            sliderWrapper.Slider:SetPoint("LEFT", 4, 0)
            sliderWrapper.Slider:SetPoint("RIGHT", -4, 0)
            local valueText = row:CreateFontString(nil, "OVERLAY", FONT_TINY)
            valueText:SetPoint("LEFT", sliderWrapper, "RIGHT", 2, 0)
            valueText:SetWidth(VE_VALUE_WIDTH)
            valueText:SetJustifyH("RIGHT")
            sliderWrapper._valueText = valueText
            sliderWrapper._initGuard = true
            local curOpacity = VE:GetFrameSetting(entry.key, "opacity")
            valueText:SetText("|cFFCCCCCC" .. curOpacity .. "%|r")
            sliderWrapper:Init(curOpacity, 0, 100, 20, {})
            sliderWrapper._initGuard = false
            sliderWrapper:RegisterCallback("OnValueChanged", function(_, val)
                if sliderWrapper._initGuard then return end
                val = math.floor(val)
                valueText:SetText("|cFFCCCCCC" .. val .. "%|r")
                VE:SetFrameSetting(entry.key, "opacity", val)
                VE:ApplyFrame(entry.key)
            end, sliderWrapper)
            table.insert(content.rowSliders, sliderWrapper)
            colPos = colPos + VE_OPACITY_COL_WIDTH
            if not entry.opacityOnly then
            -- 2. OOC Fade checkbox
            local oocCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            oocCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            oocCB:SetPoint("LEFT", colPos + (VE_CHECK_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            oocCB:SetChecked(VE:GetFrameSetting(entry.key, "oocFade"))
            oocCB:SetScript("OnClick", function(self) VE:SetFrameSetting(entry.key, "oocFade", self:GetChecked()); VE:ApplyFrame(entry.key) end)
            colPos = colPos + VE_CHECK_COL_WIDTH
            -- 3. Mounted checkbox
            local mountCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            mountCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            mountCB:SetPoint("LEFT", colPos + (VE_CHECK_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            mountCB:SetChecked(VE:GetFrameSetting(entry.key, "hideMounted"))
            mountCB:SetScript("OnClick", function(self) VE:SetFrameSetting(entry.key, "hideMounted", self:GetChecked()); VE:ApplyFrame(entry.key) end)
            colPos = colPos + VE_CHECK_COL_WIDTH
            -- 4. MouseOver checkbox
            local hoverCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            hoverCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            hoverCB:SetPoint("LEFT", colPos + (VE_CHECK_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            hoverCB:SetChecked(VE:GetFrameSetting(entry.key, "mouseOver"))
            hoverCB:SetScript("OnClick", function(self) VE:SetFrameSetting(entry.key, "mouseOver", self:GetChecked()); VE:ApplyFrame(entry.key) end)
            colPos = colPos + VE_CHECK_COL_WIDTH
            -- 5. Target checkbox
            local targetCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            targetCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            targetCB:SetPoint("LEFT", colPos + (VE_CHECK_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            targetCB:SetChecked(VE:GetFrameSetting(entry.key, "showWithTarget"))
            targetCB:SetScript("OnClick", function(self) VE:SetFrameSetting(entry.key, "showWithTarget", self:GetChecked()); VE:ApplyFrame(entry.key) end)
            colPos = colPos + VE_CHECK_COL_WIDTH
            end -- opacityOnly guard
            table.insert(self.rows, row)
            yOffset = yOffset - VE_ROW_HEIGHT
        end
        -- Orbit plugin rows
        for _, entry in ipairs(frames) do
            local plugin = VE:GetPlugin(entry)
            if plugin and Orbit:IsPluginEnabled(entry.plugin) then CreateVERow(entry, false) end
        end
        -- Blizzard Frames section
        if #blizzFrames > 0 then
            yOffset = yOffset - 6
            local sectionRow = CreateFrame("Frame", nil, scrollChild)
            sectionRow:SetHeight(VE_ROW_HEIGHT)
            sectionRow:SetPoint("TOPLEFT", 0, yOffset)
            sectionRow:SetPoint("TOPRIGHT", 0, yOffset)
            local sectionLabel = sectionRow:CreateFontString(nil, "OVERLAY", FONT_GROUP)
            sectionLabel:SetPoint("LEFT", 4, 0)
            sectionLabel:SetTextColor(GROUP_HEADER_COLOR.r, GROUP_HEADER_COLOR.g, GROUP_HEADER_COLOR.b)
            sectionLabel:SetText("Blizzard Frames")
            table.insert(self.rows, sectionRow)
            yOffset = yOffset - VE_ROW_HEIGHT
            for _, entry in ipairs(blizzFrames) do CreateVERow(entry, true) end
        end
        local totalHeight = math.abs(yOffset) + VE_ROW_HEIGHT
        scrollChild:SetHeight(totalHeight)
        if scrollFrame.ScrollBar then
            scrollFrame.ScrollBar:SetAlpha(totalHeight > scrollFrame:GetHeight() and 1 or 0)
        end
    end

    content:SetScript("OnShow", function(self) self:BuildTable() end)
    return content
end
