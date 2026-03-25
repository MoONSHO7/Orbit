-- [ PLUGIN MANAGER ]--------------------------------------------------------------------------------
-- WoW AddOns settings panel for Orbit. Contains three tabs:
-- 1. Plugin Manager — enable/disable Orbit plugins
-- 2. Visibility Engine — centralized frame visibility settings
-- 3. Quality of Life — future features (Coming Soon)
-- Accessible via /orbit plugins or Game Menu > Options > AddOns > Orbit.

local _, Orbit = ...
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local CHECKBOX_HEIGHT = 26
local CHECKBOX_WIDTH = 170
local PADDING = 16
local HEADER_HEIGHT = 40
local GROUP_HEADER_HEIGHT = 22
local GROUP_SPACING = 8
local COLUMNS = 3
local RELOAD_BUTTON_WIDTH = 160
local RELOAD_BUTTON_HEIGHT = 32
local FONT_HEADER = "GameFontNormalLarge"
local FONT_HIGHLIGHT = "GameFontHighlight"
local FONT_SMALL = "GameFontNormalSmall"
local FONT_GROUP = "GameFontNormal"
local GROUP_HEADER_COLOR = { r = 1, g = 0.82, b = 0 }
local TAB_HEIGHT = 28
local TAB_PADDING = 4
local TAB_FONT = "GameFontNormal"
local TAB_ACTIVE_COLOR = { r = 1, g = 0.82, b = 0 }
local TAB_INACTIVE_COLOR = { r = 0.6, g = 0.6, b = 0.6 }
local VE_ROW_HEIGHT = 30
local VE_LABEL_WIDTH = 160
local VE_CHECK_WIDTH = 26
local VE_COL_WIDTH = 90
local VE_SLIDER_WIDTH = 60
local VE_VALUE_WIDTH = 28
local VE_HEADER_Y = -(HEADER_HEIGHT + 50)

local PLUGIN_GROUPS = {
    { header = "Unit Frames", names = {
        "Player Frame", "Player Power", "Player Cast Bar", "Player Resources", "Pet Frame",
        "Player Buffs", "Player Debuffs",
        { label = "Target Frame", plugins = { "Target Frame", "Target Power", "Target Cast Bar", "Target Buffs", "Target Debuffs", "Target of Target" } },
        { label = "Focus Frame",  plugins = { "Focus Frame", "Focus Power", "Focus Cast Bar", "Focus Buffs", "Focus Debuffs", "Target of Focus" }, triState = true },
    }},
    { header = "Group Frames", names = { "Group Frames", "Boss Frames" } },
    { header = "Combat",       names = { "Action Bars", "Cooldown Manager" } },
    { header = "UI",           names = {
        { label = "Menu Bar", plugins = { "Menu Bar" }, triState = true },
        { label = "Bag Bar",  plugins = { "Bag Bar" },  triState = true },
        "Queue Status", "Performance Info", "Combat Timer",
        { label = "Talking Head", plugins = { "Talking Head" }, triState = true },
    }},
}

-- [ TRI-STATE VISUALS ]-----------------------------------------------------------------------------
local TRI_COLOR_YELLOW = { r = 1, g = 0.82, b = 0 }
local CHECK_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"
local CROSS_TEXTURE = "Interface\\RAIDFRAME\\ReadyCheck-NotReady"
local TRI_TOOLTIPS = {
    [0] = "Blizzard default frame will show.",
    [1] = "Orbit replaces Blizzard frame.",
    [2] = "Both Orbit and Blizzard frames disabled.",
}

-- [ TAB BAR FACTORY ]-------------------------------------------------------------------------------
local function CreateTabBar(parent, tabs, onTabSelected)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TAB_HEIGHT)
    bar:SetPoint("TOPLEFT", PADDING, -PADDING)
    bar:SetPoint("TOPRIGHT", -PADDING, -PADDING)
    bar.buttons = {}
    local xOffset = 0
    for i, tabName in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, bar)
        btn:SetHeight(TAB_HEIGHT)
        btn.label = btn:CreateFontString(nil, "OVERLAY", TAB_FONT)
        btn.label:SetPoint("CENTER")
        btn.label:SetText(tabName)
        local textW = btn.label:GetStringWidth()
        btn:SetWidth(textW + TAB_PADDING * 2 + 16)
        btn:SetPoint("TOPLEFT", xOffset, 0)
        xOffset = xOffset + btn:GetWidth() + 2
        btn.underline = btn:CreateTexture(nil, "ARTWORK")
        btn.underline:SetHeight(2)
        btn.underline:SetPoint("BOTTOMLEFT", 0, 0)
        btn.underline:SetPoint("BOTTOMRIGHT", 0, 0)
        btn.underline:SetColorTexture(TAB_ACTIVE_COLOR.r, TAB_ACTIVE_COLOR.g, TAB_ACTIVE_COLOR.b, 1)
        btn.underline:Hide()
        btn:SetScript("OnClick", function() onTabSelected(tabName) end)
        btn:SetScript("OnEnter", function(self) if not self.active then self.label:SetTextColor(1, 1, 1) end end)
        btn:SetScript("OnLeave", function(self) if not self.active then self.label:SetTextColor(TAB_INACTIVE_COLOR.r, TAB_INACTIVE_COLOR.g, TAB_INACTIVE_COLOR.b) end end)
        bar.buttons[i] = btn
        bar.buttons[tabName] = btn
    end
    function bar:SetActiveTab(name)
        for _, b in ipairs(self.buttons) do
            if b.label:GetText() == name then
                b.active = true
                b.label:SetTextColor(TAB_ACTIVE_COLOR.r, TAB_ACTIVE_COLOR.g, TAB_ACTIVE_COLOR.b)
                b.underline:Show()
            else
                b.active = false
                b.label:SetTextColor(TAB_INACTIVE_COLOR.r, TAB_INACTIVE_COLOR.g, TAB_INACTIVE_COLOR.b)
                b.underline:Hide()
            end
        end
    end
    return bar
end

-- [ PLUGIN MANAGER CONTENT ]------------------------------------------------------------------------
local function CreateCheckbox(parent, index)
    local cb = CreateFrame("CheckButton", "OrbitPluginToggle" .. index, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb.text = cb.text or cb:CreateFontString(nil, "OVERLAY", FONT_HIGHLIGHT)
    cb.text:SetTextColor(1, 1, 1)
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    return cb
end

local function ApplyTriStateVisual(cb, state)
    if state == 0 then
        cb:SetChecked(false)
        cb:SetCheckedTexture(CHECK_TEXTURE)
    elseif state == 1 then
        cb:SetChecked(true)
        cb:SetCheckedTexture(CHECK_TEXTURE)
        cb:GetCheckedTexture():SetVertexColor(TRI_COLOR_YELLOW.r, TRI_COLOR_YELLOW.g, TRI_COLOR_YELLOW.b)
    else
        cb:SetChecked(true)
        cb:SetCheckedTexture(CROSS_TEXTURE)
        cb:GetCheckedTexture():SetVertexColor(1, 0.3, 0.3)
    end
end

local function GetTriState(primaryPlugin, pluginNames)
    if Orbit:IsBlizzardHidden(primaryPlugin) then return 2 end
    for _, name in ipairs(pluginNames) do
        if not Orbit:IsPluginEnabled(name) then return 0 end
    end
    return 1
end

-- [ VISIBILITY ENGINE CONTENT ]---------------------------------------------------------------------
local VE_COLUMNS = { "Opacity", "Out Of Combat Fade", "Hide When Mounted", "Show on Mouse Over", "Show on Target" }
local VE_SETTINGS = { "opacity",  "oocFade",  "hideMounted", "mouseOver", "showWithTarget" }

local function CreateVEContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    content:Hide()
    local header = content:CreateFontString(nil, "OVERLAY", FONT_HEADER)
    header:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + 30))
    header:SetText("Visibility Engine")
    local desc = content:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetText("|cFF888888Configure frame visibility, opacity, and fade behavior.|r")
    -- Sticky column headers (frozen above scroll)
    local stickyTop = VE_HEADER_Y - 30
    local headerRow = CreateFrame("Frame", nil, content)
    headerRow:SetHeight(VE_ROW_HEIGHT)
    headerRow:SetFrameLevel(content:GetFrameLevel() + 10)
    headerRow:SetPoint("TOPLEFT", PADDING, stickyTop)
    headerRow:SetPoint("TOPRIGHT", -PADDING - 14, stickyTop)
    local headerBG = headerRow:CreateTexture(nil, "BACKGROUND")
    headerBG:SetAllPoints()
    headerBG:SetColorTexture(0.08, 0.08, 0.08, 1)
    local colX = VE_LABEL_WIDTH
    for _, text in ipairs(VE_COLUMNS) do
        local label = headerRow:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        label:SetPoint("LEFT", colX, 0)
        label:SetText("|cFFFFD100" .. text .. "|r")
        label:SetWidth(VE_COL_WIDTH)
        label:SetJustifyH("CENTER")
        colX = colX + VE_COL_WIDTH
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
        local gaValueText = caRow:CreateFontString(nil, "OVERLAY", FONT_SMALL)
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
            gaValueText:SetText("|cFFCCCCCC" .. val .. "%%|r")
            for _, entry in ipairs(frames) do
                local plugin = VE:GetPlugin(entry)
                if plugin and Orbit:IsPluginEnabled(entry.plugin) then VE:SetFrameSetting(entry.key, "opacity", val) end
            end
            for _, entry in ipairs(blizzFrames) do VE:SetFrameSetting(entry.key, "opacity", val) end
            VE:ApplyAll()
            for _, rs in ipairs(self.rowSliders or {}) do
                rs._initGuard = true
                rs:SetValue(val)
                if rs._valueText then rs._valueText:SetText("|cFFCCCCCC" .. val .. "%%|r") end
                rs._initGuard = false
            end
        end, gaWrapper)
        caColPos = caColPos + VE_COL_WIDTH
        -- Check-All toggles
        local checkAllKeys = { "oocFade", "hideMounted", "mouseOver", "showWithTarget" }
        for _, settingKey in ipairs(checkAllKeys) do
            local caCB = CreateFrame("CheckButton", nil, caRow, "UICheckButtonTemplate")
            caCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            caCB:SetPoint("LEFT", caColPos + (VE_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
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
            caColPos = caColPos + VE_COL_WIDTH
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
            local valueText = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
            valueText:SetPoint("LEFT", sliderWrapper, "RIGHT", 2, 0)
            valueText:SetWidth(VE_VALUE_WIDTH)
            valueText:SetJustifyH("RIGHT")
            sliderWrapper._valueText = valueText
            sliderWrapper._initGuard = true
            local curOpacity = VE:GetFrameSetting(entry.key, "opacity")
            valueText:SetText("|cFFCCCCCC" .. curOpacity .. "%%|r")
            sliderWrapper:Init(curOpacity, 0, 100, 20, {})
            sliderWrapper._initGuard = false
            sliderWrapper:RegisterCallback("OnValueChanged", function(_, val)
                if sliderWrapper._initGuard then return end
                val = math.floor(val)
                valueText:SetText("|cFFCCCCCC" .. val .. "%%|r")
                VE:SetFrameSetting(entry.key, "opacity", val)
                VE:ApplyFrame(entry.key)
            end, sliderWrapper)
            table.insert(content.rowSliders, sliderWrapper)
            colPos = colPos + VE_COL_WIDTH
            if not entry.opacityOnly then
            -- 2. OOC Fade checkbox
            local oocCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            oocCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            oocCB:SetPoint("LEFT", colPos + (VE_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            oocCB:SetChecked(VE:GetFrameSetting(entry.key, "oocFade"))
            oocCB:SetScript("OnClick", function(self) VE:SetFrameSetting(entry.key, "oocFade", self:GetChecked()); VE:ApplyFrame(entry.key) end)
            colPos = colPos + VE_COL_WIDTH
            -- 3. Mounted checkbox
            local mountCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            mountCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            mountCB:SetPoint("LEFT", colPos + (VE_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            mountCB:SetChecked(VE:GetFrameSetting(entry.key, "hideMounted"))
            mountCB:SetScript("OnClick", function(self) VE:SetFrameSetting(entry.key, "hideMounted", self:GetChecked()); VE:ApplyFrame(entry.key) end)
            colPos = colPos + VE_COL_WIDTH
            -- 4. MouseOver checkbox
            local hoverCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            hoverCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            hoverCB:SetPoint("LEFT", colPos + (VE_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            hoverCB:SetChecked(VE:GetFrameSetting(entry.key, "mouseOver"))
            hoverCB:SetScript("OnClick", function(self) VE:SetFrameSetting(entry.key, "mouseOver", self:GetChecked()); VE:ApplyFrame(entry.key) end)
            colPos = colPos + VE_COL_WIDTH
            -- 5. Target checkbox
            local targetCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            targetCB:SetSize(VE_CHECK_WIDTH, VE_CHECK_WIDTH)
            targetCB:SetPoint("LEFT", colPos + (VE_COL_WIDTH - VE_CHECK_WIDTH) / 2, 0)
            targetCB:SetChecked(VE:GetFrameSetting(entry.key, "showWithTarget"))
            targetCB:SetScript("OnClick", function(self) VE:SetFrameSetting(entry.key, "showWithTarget", self:GetChecked()); VE:ApplyFrame(entry.key) end)
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

-- [ QOL CONTENT ]-----------------------------------------------------------------------------------
local function CreateQoLContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    content:Hide()
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER", 0, 0)
    text:SetText("|cFF888888Coming Soon|r")
    return content
end

-- [ PANEL CREATION ]--------------------------------------------------------------------------------
local function CreatePluginPanel()
    local frame = CreateFrame("Frame", "OrbitPluginManagerPanel")
    frame:Hide()

    local TAB_NAMES = { "Plugin Manager", "Visibility Engine", "Quality of Life" }
    local activeTab = TAB_NAMES[1]

    -- Content containers
    local pluginContent = CreateFrame("Frame", nil, frame)
    pluginContent:SetAllPoints()
    local veContent = CreateVEContent(frame)
    local qolContent = CreateQoLContent(frame)
    local contentFrames = { ["Plugin Manager"] = pluginContent, ["Visibility Engine"] = veContent, ["Quality of Life"] = qolContent }

    -- Tab bar
    local tabBar
    local function SwitchTab(tabName)
        activeTab = tabName
        for name, content in pairs(contentFrames) do
            if name == tabName then content:Show() else content:Hide() end
        end
        if tabBar then tabBar:SetActiveTab(tabName) end
    end
    Orbit._openVETab = function() SwitchTab("Visibility Engine") end
    tabBar = CreateTabBar(frame, TAB_NAMES, SwitchTab)

    -- Plugin Manager content (uses pluginContent as parent)
    local header = pluginContent:CreateFontString(nil, "OVERLAY", FONT_HEADER)
    header:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + 30))
    header:SetText("Plugin Manager")
    local desc = pluginContent:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetText("|cFF888888Toggle plugins on or off. Some changes require a UI reload.|r")

    local checkboxPool = {}
    local headerPool = {}
    local checkboxes = {}
    local pendingChanges = false
    local reloadButton
    local cbIndex = 0
    local headerIndex = 0

    local function UpdateReloadButton()
        if not reloadButton then return end
        reloadButton:SetEnabled(pendingChanges)
        reloadButton:SetText(pendingChanges and "|cFFFF8800Reload UI to Apply|r" or "Reload UI")
    end

    local function CheckPendingChanges()
        pendingChanges = false
        for _, existing in ipairs(checkboxes) do
            if existing._allLiveToggle then
            elseif existing._isTriState then
                if existing._initialTriState ~= existing._triState then pendingChanges = true; break end
            else
                if existing._initialState ~= existing:GetChecked() then pendingChanges = true; break end
            end
        end
        UpdateReloadButton()
    end

    local function BuildPluginMap()
        local map = {}
        if not OrbitEngine.systems then return map end
        for _, plugin in ipairs(OrbitEngine.systems) do
            map[plugin.name] = plugin
        end
        return map
    end

    local function AddCheckbox(pluginMap, displayName, pluginNames, yOffset, col, isTriState)
        local exists = false
        for _, name in ipairs(pluginNames) do
            if pluginMap[name] then exists = true; break end
        end
        if not exists then return yOffset, col end
        cbIndex = cbIndex + 1
        local cb = checkboxPool[cbIndex] or CreateCheckbox(pluginContent, cbIndex)
        checkboxPool[cbIndex] = cb
        cb:Enable()
        local xOffset = PADDING + (col * CHECKBOX_WIDTH)
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", xOffset, yOffset)
        cb.text:SetText(displayName)
        cb.text:SetTextColor(1, 1, 1)
        cb._isTriState = isTriState
        if isTriState then
            local primaryPlugin = pluginNames[1]
            local state = GetTriState(primaryPlugin, pluginNames)
            cb._triState = state
            cb._initialTriState = state
            ApplyTriStateVisual(cb, state)
            cb:SetScript("OnClick", function(self)
                self._triState = (self._triState + 1) % 3
                ApplyTriStateVisual(self, self._triState)
                local enable = self._triState == 1
                for _, name in ipairs(pluginNames) do Orbit:SetPluginEnabled(name, enable) end
                Orbit:SetBlizzardHidden(primaryPlugin, self._triState == 2)
                CheckPendingChanges()
                if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
            end)
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(displayName, 1, 1, 1)
                GameTooltip:AddLine(TRI_TOOLTIPS[self._triState], nil, nil, nil, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", GameTooltip_Hide)
        else
            cb._triState = nil
            cb._initialTriState = nil
            local allEnabled = true
            for _, name in ipairs(pluginNames) do
                if not Orbit:IsPluginEnabled(name) then allEnabled = false; break end
            end
            cb:SetChecked(allEnabled)
            cb:SetCheckedTexture(CHECK_TEXTURE)
            cb:GetCheckedTexture():SetVertexColor(1, 1, 1)
            cb:SetScript("OnEnter", nil)
            cb:SetScript("OnLeave", nil)
            local initialState = cb:GetChecked()
            cb._initialState = initialState
            local allLive = true
            for _, name in ipairs(pluginNames) do
                if not Orbit:IsLiveToggle(name) then allLive = false; break end
            end
            cb._allLiveToggle = allLive
            cb:SetScript("OnClick", function(self)
                local checked = self:GetChecked()
                if allLive then
                    for _, name in ipairs(pluginNames) do Orbit:LiveTogglePlugin(name, checked) end
                    self._initialState = checked
                    self:SetCheckedTexture(CHECK_TEXTURE)
                    if checked then self:GetCheckedTexture():SetVertexColor(1, 1, 1) end
                else
                    for _, name in ipairs(pluginNames) do Orbit:SetPluginEnabled(name, checked) end
                end
                CheckPendingChanges()
            end)
        end
        cb:Show()
        -- Spec-lock indicator
        local allSpecLocked = true
        for _, name in ipairs(pluginNames) do
            if not Orbit:IsPluginSpecLocked(name) then allSpecLocked = false; break end
        end
        if allSpecLocked then
            cb:Disable()
            cb:SetChecked(false)
            cb.text:SetText("|cFF666666" .. displayName .. "|r")
            cb:SetScript("OnClick", nil)
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(displayName, 0.4, 0.4, 0.4)
                GameTooltip:AddLine("Not available for your current specialization.", 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", GameTooltip_Hide)
        end
        -- Conflict indicator
        local hasConflict = false
        for _, name in ipairs(pluginNames) do
            local p = pluginMap[name]
            if p and p.conflicted then hasConflict = true; break end
        end
        if not allSpecLocked and hasConflict then
            cb.text:SetText("|cFFFF4444" .. displayName .. "|r")
            if not cb._isTriState then
                cb:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(displayName, 1, 0.27, 0.27)
                    GameTooltip:AddLine("Conflicting addon detected. Another addon is managing this element.", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
                cb:SetScript("OnLeave", GameTooltip_Hide)
            end
        end
        table.insert(checkboxes, cb)
        col = col + 1
        if col >= COLUMNS then
            col = 0
            yOffset = yOffset - CHECKBOX_HEIGHT
        end
        return yOffset, col
    end

    local function BuildCheckboxes()
        for _, cb in ipairs(checkboxes) do cb:Hide() end
        for _, h in ipairs(headerPool) do h:Hide() end
        wipe(checkboxes)
        pendingChanges = false
        cbIndex = 0
        headerIndex = 0
        local pluginMap = BuildPluginMap()
        local yOffset = -(HEADER_HEIGHT + 50)
        for _, group in ipairs(PLUGIN_GROUPS) do
            headerIndex = headerIndex + 1
            local groupHeader = headerPool[headerIndex]
            if not groupHeader then
                groupHeader = pluginContent:CreateFontString(nil, "OVERLAY", FONT_GROUP)
                headerPool[headerIndex] = groupHeader
            end
            groupHeader:ClearAllPoints()
            groupHeader:SetPoint("TOPLEFT", PADDING, yOffset)
            groupHeader:SetTextColor(GROUP_HEADER_COLOR.r, GROUP_HEADER_COLOR.g, GROUP_HEADER_COLOR.b)
            groupHeader:SetText(group.header)
            groupHeader:Show()
            yOffset = yOffset - GROUP_HEADER_HEIGHT
            local col = 0
            for _, entry in ipairs(group.names) do
                if type(entry) == "table" then
                    yOffset, col = AddCheckbox(pluginMap, entry.label, entry.plugins, yOffset, col, entry.triState)
                else
                    yOffset, col = AddCheckbox(pluginMap, entry, { entry }, yOffset, col, false)
                end
            end
            if col > 0 then yOffset = yOffset - CHECKBOX_HEIGHT end
            yOffset = yOffset - GROUP_SPACING
        end
        if not reloadButton then
            reloadButton = CreateFrame("Button", "OrbitPluginReloadButton", pluginContent, "UIPanelButtonTemplate")
            reloadButton:SetSize(RELOAD_BUTTON_WIDTH, RELOAD_BUTTON_HEIGHT)
            reloadButton:SetScript("OnClick", function() ReloadUI() end)
        end
        reloadButton:ClearAllPoints()
        reloadButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)
        reloadButton:SetEnabled(false)
        reloadButton:SetText("Reload UI")
        reloadButton:Show()
    end

    pluginContent:SetScript("OnShow", BuildCheckboxes)

    frame:SetScript("OnShow", function()
        -- Run migration on first show
        if Orbit.VisibilityEngine then Orbit.VisibilityEngine:Migrate() end
        SwitchTab(activeTab)
    end)
    return frame
end

-- [ SETTINGS REGISTRATION ]-------------------------------------------------------------------------
local function RegisterSettingsPanel()
    local panel = CreatePluginPanel()
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Orbit")
    Settings.RegisterAddOnCategory(category)
    Orbit._pluginSettingsCategoryID = category:GetID()
end

local regFrame = CreateFrame("Frame")
regFrame:RegisterEvent("PLAYER_LOGIN")
regFrame:SetScript("OnEvent", function()
    C_Timer.After(0.1, RegisterSettingsPanel)
    regFrame:UnregisterAllEvents()
end)
