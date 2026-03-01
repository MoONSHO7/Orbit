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
local PLUGIN_GROUPS = {
    { header = "Unit Frames", names = {
        "Player Frame", "Player Power", "Player Cast Bar", "Player Resources", "Pet Frame",
        { label = "Target Frame", plugins = { "Target Frame", "Target Power", "Target Cast Bar", "Target Buffs", "Target Debuffs", "Target of Target" } },
        { label = "Focus Frame",  plugins = { "Focus Frame", "Focus Power", "Focus Cast Bar", "Focus Buffs", "Focus Debuffs", "Target of Focus" } },
    }},
    { header = "Group Frames", names = { "Party Frames", "Raid Frames", "Boss Frames" } },
    { header = "Combat",       names = { "Action Bars", "Cooldown Manager" } },
    { header = "UI",           names = { "Menu Bar", "Bag Bar", "Queue Status", "Performance Info", "Combat Timer", "Talking Head" } },
}

-- [ PANEL CREATION ]--------------------------------------------------------------------------------

local function CreateCheckbox(parent, index)
    local cb = CreateFrame("CheckButton", "OrbitPluginToggle" .. index, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb.text = cb.text or cb:CreateFontString(nil, "OVERLAY", FONT_HIGHLIGHT)
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    return cb
end

local function CreatePluginPanel()
    local frame = CreateFrame("Frame", "OrbitPluginManagerPanel")
    frame:Hide()

    local header = frame:CreateFontString(nil, "OVERLAY", FONT_HEADER)
    header:SetPoint("TOPLEFT", PADDING, -PADDING)
    header:SetText("Plugin Manager")

    local desc = frame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetText("|cFF888888Toggle plugins on or off. Changes require a UI reload.|r")

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
            if existing._initialState ~= existing:GetChecked() then
                pendingChanges = true
                break
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

    local function AddCheckbox(pluginMap, displayName, pluginNames, yOffset, col)
        -- Verify at least one plugin exists
        local exists = false
        for _, name in ipairs(pluginNames) do
            if pluginMap[name] then exists = true; break end
        end
        if not exists then return yOffset, col end

        cbIndex = cbIndex + 1
        local cb = checkboxPool[cbIndex] or CreateCheckbox(frame, cbIndex)
        checkboxPool[cbIndex] = cb

        local xOffset = PADDING + (col * CHECKBOX_WIDTH)
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", xOffset, yOffset)
        cb.text:SetText(displayName)

        -- Compound: checked only if ALL sub-plugins are enabled
        local allEnabled = true
        for _, name in ipairs(pluginNames) do
            if not Orbit:IsPluginEnabled(name) then allEnabled = false; break end
        end
        cb:SetChecked(allEnabled)

        local initialState = cb:GetChecked()
        cb._initialState = initialState
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            for _, name in ipairs(pluginNames) do
                Orbit:SetPluginEnabled(name, checked)
            end
            CheckPendingChanges()
        end)
        cb:Show()
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
                    yOffset, col = AddCheckbox(pluginMap, entry.label, entry.plugins, yOffset, col)
                else
                    yOffset, col = AddCheckbox(pluginMap, entry, { entry }, yOffset, col)
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
