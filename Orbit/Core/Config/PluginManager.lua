-- [ PLUGIN MANAGER ]--------------------------------------------------------------------------------
-- WoW AddOns settings panel for enabling/disabling Orbit plugins.
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

-- Entries: string = single plugin, table = { label, plugins = { ... } } compound toggle
-- triState = true marks entries that support 3-state: off / on / hide-blizzard-too
local PLUGIN_GROUPS = {
    {
        header = "Unit Frames",
        names = {
            "Player Frame",
            "Player Power",
            "Player Cast Bar",
            "Player Resources",
            "Pet Frame",
            "Player Buffs",
            "Player Debuffs",
            { label = "Target Frame", plugins = { "Target Frame", "Target Power", "Target Cast Bar", "Target Buffs", "Target Debuffs", "Target of Target" } },
            {
                label = "Focus Frame",
                plugins = { "Focus Frame", "Focus Power", "Focus Cast Bar", "Focus Buffs", "Focus Debuffs", "Target of Focus" },
                triState = true,
            },
        },
    },
    { header = "Group Frames", names = { "Party Frames", "Raid Frames", "Boss Frames" } },
    { header = "Combat", names = { "Action Bars", "Cooldown Manager" } },
    {
        header = "UI",
        names = {
            { label = "Menu Bar", plugins = { "Menu Bar" }, triState = true },
            { label = "Bag Bar", plugins = { "Bag Bar" }, triState = true },
            "Queue Status",
            "Performance Info",
            "Combat Timer",
            { label = "Talking Head", plugins = { "Talking Head" }, triState = true },
        },
    },
    { header = "Experimental", names = { "Minimap" } },
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

-- [ PANEL CREATION ]--------------------------------------------------------------------------------

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
    -- Red (2): disabled + blizzard hidden
    if Orbit:IsBlizzardHidden(primaryPlugin) then
        return 2
    end
    -- Yellow (1): all sub-plugins enabled
    for _, name in ipairs(pluginNames) do
        if not Orbit:IsPluginEnabled(name) then
            return 0
        end
    end
    return 1
end

local function CreatePluginPanel()
    local frame = CreateFrame("Frame", "OrbitPluginManagerPanel")
    frame:Hide()

    local header = frame:CreateFontString(nil, "OVERLAY", FONT_HEADER)
    header:SetPoint("TOPLEFT", PADDING, -PADDING)
    header:SetText("Plugin Manager")

    local desc = frame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
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
            if existing._allLiveToggle then -- skip: applied immediately
            elseif existing._isTriState then
                if existing._initialTriState ~= existing._triState then
                    pendingChanges = true
                    break
                end
            else
                if existing._initialState ~= existing:GetChecked() then
                    pendingChanges = true
                    break
                end
            end
        end
        UpdateReloadButton()
    end

    -- Build a name->plugin lookup from OrbitEngine.systems
    local function BuildPluginMap()
        local map = {}
        if not OrbitEngine.systems then return map end
        for _, plugin in ipairs(OrbitEngine.systems) do
            map[plugin.name] = plugin
        end
        return map
    end

    local function AddCheckbox(pluginMap, displayName, pluginNames, yOffset, col, isTriState)
        -- Verify at least one plugin exists
        local exists = false
        for _, name in ipairs(pluginNames) do
            if pluginMap[name] then
                exists = true
                break
            end
        end
        if not exists then return yOffset, col end

        cbIndex = cbIndex + 1
        local cb = checkboxPool[cbIndex] or CreateCheckbox(frame, cbIndex)
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
                for _, name in ipairs(pluginNames) do
                    Orbit:SetPluginEnabled(name, enable)
                end
                Orbit:SetBlizzardHidden(primaryPlugin, self._triState == 2)
                CheckPendingChanges()
                if GameTooltip:IsOwned(self) then
                    self:GetScript("OnEnter")(self)
                end
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
                if not Orbit:IsPluginEnabled(name) then
                    allEnabled = false
                    break
                end
            end
            cb:SetChecked(allEnabled)
            cb:SetCheckedTexture(CHECK_TEXTURE)
            cb:GetCheckedTexture():SetVertexColor(1, 1, 1)
            cb:SetScript("OnEnter", nil)
            cb:SetScript("OnLeave", nil)
            local initialState = cb:GetChecked()
            cb._initialState = initialState
            -- Check if all plugins in this entry support live toggle
            local allLive = true
            for _, name in ipairs(pluginNames) do
                if not Orbit:IsLiveToggle(name) then
                    allLive = false
                    break
                end
            end
            cb._allLiveToggle = allLive
            cb:SetScript("OnClick", function(self)
                local checked = self:GetChecked()
                if allLive then
                    for _, name in ipairs(pluginNames) do
                        Orbit:LiveTogglePlugin(name, checked)
                    end
                    self._initialState = checked
                    self:SetCheckedTexture(CHECK_TEXTURE)
                    if checked then self:GetCheckedTexture():SetVertexColor(1, 1, 1) end
                else
                    for _, name in ipairs(pluginNames) do
                        Orbit:SetPluginEnabled(name, checked)
                    end
                end
                CheckPendingChanges()
            end)
        end

        cb:Show()

        -- Spec-lock indicator: greyed out + disabled when the plugin is not applicable to the current spec
        local allSpecLocked = true
        for _, name in ipairs(pluginNames) do
            if not Orbit:IsPluginSpecLocked(name) then
                allSpecLocked = false
                break
            end
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

        -- Conflict indicator: red text + tooltip when another addon controls this frame
        local hasConflict = false
        for _, name in ipairs(pluginNames) do
            local p = pluginMap[name]
            if p and p.conflicted then
                hasConflict = true
                break
            end
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
        for _, cb in ipairs(checkboxes) do
            cb:Hide()
        end
        for _, h in ipairs(headerPool) do
            h:Hide()
        end
        wipe(checkboxes)
        pendingChanges = false
        cbIndex = 0
        headerIndex = 0

        local pluginMap = BuildPluginMap()
        local yOffset = -(HEADER_HEIGHT + 30)

        for _, group in ipairs(PLUGIN_GROUPS) do
            -- Group header (spans full width)
            headerIndex = headerIndex + 1
            local groupHeader = headerPool[headerIndex]
            if not groupHeader then
                groupHeader = frame:CreateFontString(nil, "OVERLAY", FONT_GROUP)
                headerPool[headerIndex] = groupHeader
            end
            groupHeader:ClearAllPoints()
            groupHeader:SetPoint("TOPLEFT", PADDING, yOffset)
            groupHeader:SetTextColor(GROUP_HEADER_COLOR.r, GROUP_HEADER_COLOR.g, GROUP_HEADER_COLOR.b)
            groupHeader:SetText(group.header)
            groupHeader:Show()
            yOffset = yOffset - GROUP_HEADER_HEIGHT

            -- Checkboxes in 3-column grid
            local col = 0
            for _, entry in ipairs(group.names) do
                if type(entry) == "table" then
                    yOffset, col = AddCheckbox(pluginMap, entry.label, entry.plugins, yOffset, col, entry.triState)
                else
                    yOffset, col = AddCheckbox(pluginMap, entry, { entry }, yOffset, col, false)
                end
            end
            -- Finish partial row
            if col > 0 then yOffset = yOffset - CHECKBOX_HEIGHT end
            yOffset = yOffset - GROUP_SPACING
        end

        -- Reload button anchored to bottom-right
        if not reloadButton then
            reloadButton = CreateFrame("Button", "OrbitPluginReloadButton", frame, "UIPanelButtonTemplate")
            reloadButton:SetSize(RELOAD_BUTTON_WIDTH, RELOAD_BUTTON_HEIGHT)
            reloadButton:SetScript("OnClick", function() ReloadUI() end)
        end
        reloadButton:ClearAllPoints()
        reloadButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)
        reloadButton:SetEnabled(false)
        reloadButton:SetText("Reload UI")
        reloadButton:Show()
    end

    frame:SetScript("OnShow", BuildCheckboxes)
    return frame
end

-- [ SETTINGS REGISTRATION ]-------------------------------------------------------------------------

local function RegisterSettingsPanel()
    local panel = CreatePluginPanel()
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Orbit")
    Settings.RegisterAddOnCategory(category)
    Orbit._pluginSettingsCategoryID = category:GetID()
end

-- Register after PLAYER_LOGIN so all plugins are loaded
local regFrame = CreateFrame("Frame")
regFrame:RegisterEvent("PLAYER_LOGIN")
regFrame:SetScript("OnEvent", function()
    C_Timer.After(0.1, RegisterSettingsPanel)
    regFrame:UnregisterAllEvents()
end)
