-- [ PLUGIN MANAGER CONTENT ]------------------------------------------------------------------------
-- Plugin enable/disable checkbox grid for the Orbit Advanced Settings panel.
local _, Orbit = ...
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local A = Layout.Advanced

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local CHECKBOX_HEIGHT = 26
local COLUMNS = 3
local RELOAD_BUTTON_WIDTH = 160
local RELOAD_BUTTON_HEIGHT = 32
local BODY_PADDING = 8

local PLUGIN_GROUPS = {
    { header = L.PLG_UNIT_FRAMES, names = {
        "Player Frame", "Player Power", "Player Cast Bar", "Player Resources", "Pet Frame",
        "Player Buffs", "Player Debuffs",
        { label = "Target Frame", plugins = { "Target Frame", "Target Power", "Target Cast Bar", "Target Buffs", "Target Debuffs", "Target of Target" } },
        { label = "Focus Frame",  plugins = { "Focus Frame", "Focus Power", "Focus Cast Bar", "Focus Buffs", "Focus Debuffs", "Target of Focus" }, triState = true },
    }},
    { header = L.PLG_GROUP_FRAMES, names = { "Group Frames", "Boss Frames" } },
    { header = L.PLG_COMBAT,       names = { "Action Bars", "Cooldown Manager", { label = "Tracked Cooldowns", plugins = { "Tracked Items" } }, "Damage Meter" } },
    { header = L.PLG_UI,           names = {
        { label = "Menu Bar", plugins = { "Menu Bar" }, triState = true },
        { label = "Bag Bar",  plugins = { "Bag Bar" },  triState = true },
        "Queue Status",
        { label = "Talking Head", plugins = { "Talking Head" }, triState = true },
        "Minimap", "Datatexts",
    }},
}

-- [ TRI-STATE HELPERS ]-----------------------------------------------------------------------------
local TRI_TOOLTIPS = {
    [0] = L.PLG_TRI_BLIZZARD,
    [1] = L.PLG_TRI_ORBIT,
    [2] = L.PLG_TRI_BOTH_DISABLED,
}

local function GetTriState(primaryPlugin, pluginNames)
    if Orbit:IsBlizzardHidden(primaryPlugin) then return 2 end
    for _, name in ipairs(pluginNames) do
        if not Orbit:IsPluginEnabled(name) then return 0 end
    end
    return 1
end

-- [ BUILD ]-----------------------------------------------------------------------------------------
function Orbit._AC.BuildPluginContent(pluginContent, frame)
    local header = Layout:CreateSectionHeader(pluginContent, L.CFG_PLUGIN_MANAGER)
    header:SetPoint("TOPLEFT", A.PADDING, A.TITLE_Y)
    header:SetPoint("TOPRIGHT", -A.PADDING, A.TITLE_Y)
    local desc = Layout:CreateDescription(pluginContent, L.CFG_PLUGIN_MANAGER_DESC, A.MUTED)
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)

    local widgets = {}
    local pendingChanges = false
    local reloadButton

    local function UpdateReloadButton()
        if not reloadButton then return end
        reloadButton:SetEnabled(pendingChanges)
        if reloadButton._label then reloadButton._label:SetText(L.PLG_RELOAD_UI) end
    end

    local function CheckPendingChanges()
        pendingChanges = false
        for _, w in ipairs(widgets) do
            if w._allLiveToggle then
            elseif w._isTriState then
                if w._initialTriState ~= w:GetTriState() then pendingChanges = true; break end
            else
                if w._initialState ~= w:GetChecked() then pendingChanges = true; break end
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

    local function AddWidget(body, pluginMap, displayName, pluginNames, yOffset, col, colWidth, isTriState)
        -- Single pass: existence, spec-lock, conflict, live-toggle, enabled
        local exists, allSpecLocked, hasConflict, allLive, allEnabled = false, true, false, true, true
        for _, name in ipairs(pluginNames) do
            local p = pluginMap[name]
            if p then exists = true; if p.conflicted then hasConflict = true end end
            if not Orbit:IsPluginSpecLocked(name) then allSpecLocked = false end
            if not Orbit:IsLiveToggle(name) then allLive = false end
            if not Orbit:IsPluginEnabled(name) then allEnabled = false end
        end
        if not exists then return yOffset, col end
        local w
        if isTriState then
            local primaryPlugin = pluginNames[1]
            local state = GetTriState(primaryPlugin, pluginNames)
            w = Layout:CreateCheckbox(body, displayName,
                function(f) return TRI_TOOLTIPS[f:GetTriState()] end,
                state,
                function(newState)
                    local enable = newState == 1
                    for _, name in ipairs(pluginNames) do Orbit:SetPluginEnabled(name, enable) end
                    Orbit:SetBlizzardHidden(primaryPlugin, newState == 2)
                    CheckPendingChanges()
                end,
                { compact = true, triState = true }
            )
            w._isTriState = true
            w._initialTriState = state
        else
            w = Layout:CreateCheckbox(body, displayName, nil, allEnabled,
                function(checked)
                    if allLive then
                        for _, name in ipairs(pluginNames) do Orbit:LiveTogglePlugin(name, checked) end
                        w._initialState = checked
                    else
                        for _, name in ipairs(pluginNames) do Orbit:SetPluginEnabled(name, checked) end
                    end
                    CheckPendingChanges()
                end,
                { compact = true }
            )
            w._initialState = allEnabled
            w._allLiveToggle = allLive
        end
        -- Apply spec-lock
        if allSpecLocked then
            w:SetEnabled(false)
            w:SetChecked(false)
            w:SetLabel("|cFF666666" .. displayName .. "|r")
            w:SetOnClick(nil)
            w:SetTooltip(function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(displayName, 0.4, 0.4, 0.4)
                GameTooltip:AddLine(L.PLG_SPEC_LOCKED, 0.6, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
        end
        -- Apply conflict
        if not allSpecLocked and hasConflict then
            w:SetLabel("|cFFFF4444" .. displayName .. "|r")
            if not isTriState then
                w:SetTooltip(function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(displayName, 1, 0.27, 0.27)
                    GameTooltip:AddLine(L.PLG_CONFLICT_DESC, 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
            end
        end
        -- Position in grid
        w:SetParent(body)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", BODY_PADDING + col * colWidth, yOffset)
        w:SetWidth(colWidth)
        w:Show()
        table.insert(widgets, w)
        col = col + 1
        if col >= COLUMNS then
            col = 0
            yOffset = yOffset - CHECKBOX_HEIGHT
        end
        return yOffset, col
    end

    -- Scrollable area
    local scrollFrame, scrollChild = Layout:CreateScrollArea(pluginContent, nil, A.PADDING + RELOAD_BUTTON_HEIGHT + 8)

    -- Build accordion sections
    local sections = {}
    for _, group in ipairs(PLUGIN_GROUPS) do
        local section = Layout:CreateAccordion(scrollChild, group.header)
        section:SetParent(scrollChild)
        section._group = group
        table.insert(sections, section)
    end

    local function LayoutSections()
        local y = 0
        for _, section in ipairs(sections) do
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", 0, y)
            section:SetPoint("TOPRIGHT", 0, y)
            y = y - section:GetHeight() - A.SECTION_SPACING
        end
        scrollFrame:UpdateContentHeight(math.abs(y) + 10)
    end

    local function BuildCheckboxes()
        for _, w in ipairs(widgets) do w:Hide() end
        wipe(widgets)
        pendingChanges = false
        local pluginMap = BuildPluginMap()
        for _, section in ipairs(sections) do
            local body = section:GetBody()
            local group = section._group
            local bodyWidth = scrollChild:GetWidth()
            if bodyWidth < 1 then bodyWidth = pluginContent:GetWidth() - (A.PADDING * 2) - 40 end
            local colWidth = (bodyWidth - BODY_PADDING * 2) / COLUMNS
            local yOffset = 0
            local col = 0
            for _, entry in ipairs(group.names) do
                if type(entry) == "table" then
                    yOffset, col = AddWidget(body, pluginMap, entry.label, entry.plugins, yOffset, col, colWidth, entry.triState)
                else
                    yOffset, col = AddWidget(body, pluginMap, entry, { entry }, yOffset, col, colWidth, false)
                end
            end
            if col > 0 then yOffset = yOffset - CHECKBOX_HEIGHT end
            section:SetContentHeight(math.max(CHECKBOX_HEIGHT, math.abs(yOffset)))
        end
        LayoutSections()
        if not reloadButton then
            reloadButton = CreateFrame("Button", "OrbitPluginReloadButton", pluginContent)
            reloadButton:SetSize(RELOAD_BUTTON_WIDTH, RELOAD_BUTTON_HEIGHT)
            reloadButton:SetNormalAtlas("128-RedButton-UP")
            reloadButton:SetPushedAtlas("128-RedButton-Pressed")
            reloadButton:SetDisabledAtlas("128-RedButton-Disable")
            local hl = reloadButton:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetAtlas("128-RedButton-UP")
            hl:SetBlendMode("ADD")
            hl:SetAlpha(0.25)
            reloadButton:SetNormalFontObject("GameFontNormal")
            reloadButton:SetHighlightFontObject("GameFontHighlight")
            reloadButton:SetDisabledFontObject("GameFontDisable")
            local label = reloadButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("CENTER")
            label:SetTextColor(1, 0.82, 0, 1)
            reloadButton._label = label
            reloadButton:SetScript("OnClick", function() ReloadUI() end)
        end
        reloadButton:ClearAllPoints()
        reloadButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -A.PADDING, A.PADDING)
        reloadButton:SetEnabled(false)
        if reloadButton._label then reloadButton._label:SetText(L.PLG_RELOAD_UI) end
        reloadButton:Show()
    end

    for _, section in ipairs(sections) do section._onToggle = LayoutSections end
    pluginContent:SetScript("OnShow", BuildCheckboxes)
end
