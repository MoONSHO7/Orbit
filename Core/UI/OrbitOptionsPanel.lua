local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local Config = OrbitEngine.Config
local Constants = Orbit.Constants

-------------------------------------------------
-- ORBIT OPTIONS PANEL
-- Uses Orbit's standalone settings dialog
-------------------------------------------------

Orbit.OptionsPanel = {}
local Panel = Orbit.OptionsPanel

-------------------------------------------------
-- GLOBAL TAB
-------------------------------------------------
local GlobalPlugin = {
    name = "OrbitGlobal",
    settings = {},

    GetSetting = function(self, systemIndex, key)
        if not Orbit.db or not Orbit.db.GlobalSettings then
            return nil
        end
        return Orbit.db.GlobalSettings[key]
    end,

    SetSetting = function(self, systemIndex, key, value)
        if not Orbit.db then
            return
        end
        if not Orbit.db.GlobalSettings then
            Orbit.db.GlobalSettings = {}
        end
        Orbit.db.GlobalSettings[key] = value
    end,

    ApplySettings = function(self, systemFrame)
        -- Broadcast Global Changes to all registered plugins
        if OrbitEngine.systems then
            for _, plugin in ipairs(OrbitEngine.systems) do
                -- Prefer ApplyAll if available (e.g. CooldownManager handling multiple frames)
                if plugin.ApplyAll then
                    plugin:ApplyAll()
                elseif plugin.ApplySettings then
                    -- Call without arguments - plugins should handle their own frame references
                    plugin:ApplySettings()
                end
            end
        end
    end,
}

local function GetGlobalSchema()
    local controls = {
        {
            type = "texture",
            key = "Texture",
            label = "Texture",
            default = "Melli",
            previewColor = { r = 0.8, g = 0.8, b = 0.8 },
        },
        {
            type = "color",
            key = "BackdropColour",
            label = "Backdrop Colour",
            default = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }, -- Matches Orbit.Constants.Colors.Background
        },

        {
            type = "font",
            key = "Font",
            label = "Font",
            default = "PT Sans Narrow",
        },
        {
            type = "dropdown",
            key = "TextScale",
            label = "Text Scale",
            options = {
                { label = "Small", value = "Small" },
                { label = "Medium", value = "Medium" },
                { label = "Large", value = "Large" },
                { label = "Extra Large", value = "ExtraLarge" },
            },
            default = "Medium",
        },
        {
            type = "slider",
            key = "BorderSize",
            label = "Border Size",
            default = 2,
            min = 0,
            max = 5,
            step = 1,
            updateOnRelease = true, -- Prevent heavy updates during drag
        },
    }

    table.insert(controls, {
        type = "description",
        text = "|cFFFFD100Right Click:|r Lock an Edit Mode frame. (Can't be moved or anchored to)\n\n|cFFFFD100Anchor:|r Drag a frame to the edge of another frame to anchor it.\n\n|cFFFFD100Mouse Wheel:|r Scroll up and down on an anchored frame to adjust spacing between itself and its parent.",
    })

    return {
        hideNativeSettings = true,
        hideResetButton = false, -- We want a reset button
        headerHeight = Constants.Panel.HeaderHeight,
        controls = controls,
        onReset = function()
            -- Restore Defaults
            local d = Orbit.db.GlobalSettings
            if d then
                d.Texture = "Melli"
                d.Font = "PT Sans Narrow"
                d.BorderSize = 2
            end
            Orbit:Print("Global settings reset to defaults.")
        end,
    }
end

-------------------------------------------------
-- EDIT MODE TAB
-------------------------------------------------
local EditModePlugin = {
    name = "OrbitEditMode",
    settings = {},

    GetSetting = function(self, systemIndex, key)
        if not Orbit.db or not Orbit.db.GlobalSettings then
            return nil
        end
        return Orbit.db.GlobalSettings[key]
    end,

    SetSetting = function(self, systemIndex, key, value)
        if not Orbit.db then
            return
        end
        if not Orbit.db.GlobalSettings then
            Orbit.db.GlobalSettings = {}
        end
        Orbit.db.GlobalSettings[key] = value

        -- Force refresh of visuals if in Edit Mode
        if Orbit.Engine.FrameSelection then
             Orbit.Engine.FrameSelection:RefreshVisuals()
        end
    end,

    ApplySettings = function(self, systemFrame)
         -- Handled by SetSetting immediate refresh
    end,
}

local function GetEditModeSchema()
    return {
        hideNativeSettings = true,
        hideResetButton = false,
        headerHeight = Constants.Panel.HeaderHeight,
        controls = {
            {
                type = "checkbox",
                key = "ShowBlizzardFrames",
                label = "Show Blizzard Frames",
                default = true,
                tooltip = "Show selection overlays for native Blizzard frames in Edit Mode.",
            },
            {
                type = "checkbox",
                key = "ShowOrbitFrames",
                label = "Show Orbit Frames",
                default = true,
                tooltip = "Show selection overlays for Orbit-owned frames in Edit Mode.",
            },
            {
                type = "checkbox",
                key = "AnchoringEnabled",
                label = "Enable Frame Anchoring",
                default = true,
                tooltip = "Allow frames to anchor to other frames. Disabling preserves existing anchors but prevents new ones.",
            },
            {
                type = "color",
                key = "EditModeColor",
                label = "Orbit Frame Color",
                default = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 },
                tooltip = "Color of the selection overlay for Orbit-owned frames.",
            },
        },
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.ShowBlizzardFrames = true
                d.ShowOrbitFrames = true
                d.AnchoringEnabled = true
                d.EditModeColor = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 }
            end
             if Orbit.Engine.FrameSelection then
                 Orbit.Engine.FrameSelection:RefreshVisuals()
            end
            Orbit:Print("Edit Mode settings reset to defaults.")
        end,
    }
end

-------------------------------------------------
-- PLUGINS TAB
-------------------------------------------------

local PluginsPlugin = {
    name = "OrbitPlugins",
    settings = {},

    GetSetting = function(self, systemIndex, key)
        -- Dynamic Group Handling
        local groupKey = key:match("^(.*)Group$")
        if groupKey and Constants.PluginGroups[groupKey] then
            local targetGroup = Constants.PluginGroups[groupKey]
            -- Return true only if ALL grouped plugins are enabled
            for _, plugin in ipairs(OrbitEngine.systems) do
                if plugin.group == targetGroup then
                    if not Orbit:IsPluginEnabled(plugin.name) then
                        return false
                    end
                end
            end
            return true
        end
        return Orbit:IsPluginEnabled(key)
    end,

    SetSetting = function(self, systemIndex, key, value)
        -- Dynamic Group Handling
        local groupKey = key:match("^(.*)Group$")
        if groupKey and Constants.PluginGroups[groupKey] then
            local targetGroup = Constants.PluginGroups[groupKey]
            for _, plugin in ipairs(OrbitEngine.systems) do
                if plugin.group == targetGroup then
                    Orbit:SetPluginEnabled(plugin.name, value)
                end
            end
            return
        end
        Orbit:SetPluginEnabled(key, value)
    end,

    ApplySettings = function(self, systemFrame)
        Orbit:Print("Plugin change requires UI reload. Type /reload to apply.")
    end,
}

local function GetPluginsSchema()
    local controls = {}

    -- Dynamic Plugin Groups
    -- Convert dictionary to sorted list for consistent display order
    local groups = {}
    for key, label in pairs(Constants.PluginGroups) do
        table.insert(groups, { key = key, label = label })
    end
    table.sort(groups, function(a, b)
        -- Custom Sort Order? Or Alphabetical?
        -- For now, UnitFrames first, then alphabetical
        if a.key == "UnitFrames" then
            return true
        end
        if b.key == "UnitFrames" then
            return false
        end
        return a.label < b.label
    end)

    for _, group in ipairs(groups) do
        table.insert(controls, {
            type = "checkbox",
            key = group.key .. "Group",
            label = group.label,
            default = true,
        })
    end

    -- Filter out grouped plugins from individual display
    local sortedPlugins = {}
    for _, p in ipairs(OrbitEngine.systems or {}) do
        if not p.group then
            table.insert(sortedPlugins, p)
        end
    end
    table.sort(sortedPlugins, function(a, b)
        return a.name < b.name
    end)

    for _, plugin in ipairs(sortedPlugins) do
        table.insert(controls, {
            type = "checkbox",
            key = plugin.name,
            label = plugin.name,
            default = true,
        })
    end

    return {
        hideNativeSettings = true,
        hideResetButton = true,
        headerHeight = Constants.Panel.HeaderHeight,
        controls = controls,
        extraButtons = {
            {
                text = "Toggle All",
                width = 100,
                callback = function()
                    local allEnabled = true

                    -- Check all plugins including grouped ones
                    if OrbitEngine.systems then
                        for _, plugin in ipairs(OrbitEngine.systems) do
                            if not Orbit:IsPluginEnabled(plugin.name) then
                                allEnabled = false
                                break
                            end
                        end
                    end

                    local newState = not allEnabled

                    -- Toggle all plugins
                    if OrbitEngine.systems then
                        for _, plugin in ipairs(OrbitEngine.systems) do
                            Orbit:SetPluginEnabled(plugin.name, newState)
                        end
                    end

                    Orbit:Print("All plugins " .. (newState and "enabled" or "disabled") .. ". Reload to apply.")

                    local dialog = Orbit.SettingsDialog
                    if dialog then
                        local mockFrame = CreateFrame("Frame")
                        mockFrame.systemIndex = 1
                        mockFrame.system = "Orbit_Plugins"
                        Config:Render(dialog, mockFrame, PluginsPlugin, GetPluginsSchema())
                    end
                end,
            },
            {
                text = "Reload UI",
                width = 100,
                callback = ReloadUI,
            },
        },
    }
end

-------------------------------------------------
-- PROFILES TAB
-------------------------------------------------
local ProfilesPlugin = {
    name = "OrbitProfiles",
    settings = {},
    GetSetting = function(self, systemIndex, key)
        if key == "CurrentProfile" then
            return Orbit.Profile:GetActiveProfileName()
        elseif key == "ActiveProfile" then
            return Orbit.Profile:GetActiveProfileName()
        elseif key == "SpecBinding" then
            local specIndex = GetSpecialization()
            if not specIndex then
                return "None"
            end
            local specID = GetSpecializationInfo(specIndex)
            if not specID then
                return "None"
            end

            return Orbit.Profile:GetProfileForSpec(specID) or "None"
        elseif key == "ProfileNotes" then
            local active = Orbit.Profile:GetActiveProfileName()
            return Orbit.db.profiles[active] and Orbit.db.profiles[active].notes or ""
        elseif key == "SpecSwitchingEnabled" then
            return Orbit.db.enableSpecSwitching
        elseif key == "AutoSpecProfiles" then
            return Orbit.db.autoSpecProfiles
        elseif key == "ProfileToDelete" then
            return Orbit.Profile._selectedToDelete or "Default"
        end
        return nil
    end,
    SetSetting = function(self, systemIndex, key, value)
        if key == "ProfileToDelete" then
            Orbit.Profile._selectedToDelete = value
        elseif key == "ActiveProfile" then
            Orbit.Profile:SetActiveProfile(value)
        elseif key == "SpecBinding" then
            local specIndex = GetSpecialization()
            if not specIndex then
                return
            end
            local specID = GetSpecializationInfo(specIndex)
            if not specID then
                return
            end

            if value == "None" then
                value = nil
            end
            Orbit.Profile:SetProfileForSpec(specID, value)
            Orbit:Print("Bound current specialization to profile: " .. (value or "None"))

            -- Trigger switch if enabled
            if Orbit.db.enableSpecSwitching then
                Orbit.Profile:CheckSpecProfile()
            end
        elseif key == "ProfileNotes" then
            local active = Orbit.Profile:GetActiveProfileName()
            if Orbit.db.profiles[active] then
                Orbit.db.profiles[active].notes = value
            end
        elseif key == "SpecSwitchingEnabled" then
            Orbit.db.enableSpecSwitching = value
            if value then
                Orbit.Profile:CheckSpecProfile()
            end
        elseif key == "AutoSpecProfiles" then
            Orbit.db.autoSpecProfiles = value
            if value then
                Orbit.Profile:CheckSpecProfile()
            end -- Trigger check immediately on enable
        end
    end,
    ApplySettings = function(self, systemFrame) end,
}

local function GetProfilesSchema()
    local currentSpecName = Orbit.Profile:GetCurrentSpecName() or "Unknown"
    local activeProfile = Orbit.Profile:GetActiveProfileName()

    -- Helper for profile dropdown
    local function GetAllProfileOptions()
        local opts = {}
        local names = Orbit.Profile:GetProfiles()
        for _, n in ipairs(names) do
            table.insert(opts, { text = n, value = n })
        end
        return opts
    end

    return {
        hideNativeSettings = true,
        hideResetButton = true,
        headerHeight = Constants.Panel.HeaderHeight,
        controls = {
            {
                type = "header",
                text = "Active Profile",
            },
            {
                type = "label",
                text = activeProfile,
                key = "ActiveProfileDisplay",
            },
            {
                type = "spacer",
                height = 10,
            },
            {
                type = "label",
                text = "Profiles are automatically managed per-specialization.",
                key = "AutoInfo",
            },
            {
                type = "spacer",
                height = 20,
            },
            {
                type = "header",
                text = "Manage Profiles",
            },
            {
                type = "dropdown",
                key = "ProfileToDelete",
                label = "Select Profile",
                options = GetAllProfileOptions,
                default = "Default",
                width = 200,
            },
            {
                type = "button",
                text = "Delete Selected Profile",
                width = 180,
                onClick = function()
                    local selected = Orbit.Profile._selectedToDelete
                    if not selected or selected == "" then
                        Orbit:Print("Please select a profile first.")
                        return
                    end
                    local currentActive = Orbit.Profile:GetActiveProfileName()
                    if selected == "Default" then
                        Orbit:Print("Cannot delete Default profile.")
                        return
                    end
                    if selected == currentActive then
                        Orbit:Print("Cannot delete active profile. Switch specs first.")
                        return
                    end
                    Orbit.Profile:DeleteProfile(selected)
                    Orbit:Print(selected .. " Profile Deleted.")
                    Orbit.Profile._selectedToDelete = nil
                    -- Force re-render the Profiles tab
                    if Orbit.OptionsPanel and Orbit.OptionsPanel.Toggle then
                        Orbit.OptionsPanel.currentTab = nil
                        Orbit.OptionsPanel:Toggle("Profiles")
                    end
                end,
            },
            {
                type = "spacer",
                height = 20,
            },
        },
        extraButtons = {
            {
                text = "Export",
                callback = function()
                    local str = Orbit.Profile:ExportProfile()
                    StaticPopupDialogs["ORBIT_EXPORT"] = {
                        text = "Copy your backup string (All Profiles):",
                        button1 = "Close",
                        hasEditBox = true,
                        OnShow = function(self)
                            self.EditBox:SetText(str)
                            self.EditBox:HighlightText()
                            self.EditBox:SetFocus()
                        end,
                        EditBoxOnEscapePressed = function(self)
                            self:GetParent():Hide()
                        end,
                        timeout = 0,
                        hideOnEscape = true,
                        preferredIndex = 3,
                    }
                    StaticPopup_Show("ORBIT_EXPORT")
                end,
            },
            {
                text = "Import",
                callback = function()
                    StaticPopupDialogs["ORBIT_IMPORT"] = {
                        text = "Paste profile string (Single or Backup):",
                        button1 = "Import",
                        button2 = "Cancel",
                        hasEditBox = true,
                        OnAccept = function(self)
                            local str = self.EditBox:GetText()
                            local success, err = Orbit.Profile:ImportProfile(str)
                            if success then
                                Orbit:Print("Import successful. Reloading UI is recommended.")
                                if Orbit.OptionsPanel and Orbit.OptionsPanel.Refresh then
                                    Orbit.OptionsPanel:Refresh()
                                end
                            else
                                print("Import Failed: " .. (err or "Unknown"))
                            end
                        end,
                        timeout = 0,
                        hideOnEscape = true,
                        preferredIndex = 3,
                    }
                    StaticPopup_Show("ORBIT_IMPORT")
                end,
            },
        },
    }
end

-------------------------------------------------
-- MAIN LOGIC
-------------------------------------------------

local TABS = {
    { name = "Global", plugin = GlobalPlugin, schema = GetGlobalSchema },
    { name = "Edit Mode", plugin = EditModePlugin, schema = GetEditModeSchema },
    { name = "Plugins", plugin = PluginsPlugin, schema = GetPluginsSchema },
    { name = "Profiles", plugin = ProfilesPlugin, schema = GetProfilesSchema },
}

function Panel:CreateTabs(dialog)
    if dialog.OrbitTabs then
        return
    end

    dialog.OrbitTabs = {}
    local parent = dialog -- Anchor to the dialog itself

    -- Ensure MinimalTabTemplate is available or fallback
    local template = "MinimalTabTemplate"

    local lastTab = nil
    for i, tabDef in ipairs(TABS) do
        local tab = CreateFrame("Button", nil, parent, template)
        tab:SetSize(0, 30) -- Width dynamic

        -- Text
        tab.Text:SetText(tabDef.name)
        tab:SetWidth(tab.Text:GetStringWidth() + 30)

        -- Anchor
        if lastTab then
            tab:SetPoint("LEFT", lastTab, "RIGHT", 5, 0)
        else
            -- Top Left of the dialog content area
            tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -35)
        end

        -- Click
        tab:SetScript("OnClick", function()
            Panel:Open(tabDef.name)
        end)

        tab.definition = tabDef
        table.insert(dialog.OrbitTabs, tab)
        lastTab = tab
    end

    -- Header Divider (Visual Separator below tabs)
    if not dialog.OrbitHeaderDivider then
        local div = dialog:CreateTexture(nil, "ARTWORK")
        div:SetColorTexture(0.2, 0.2, 0.2, 1) -- Subtle grey
        div:SetHeight(1)
        -- Anchor to span the full width below tabs
        div:SetPoint("TOPLEFT", dialog, "TOPLEFT", 10, -65) -- Adjusted Y offset
        div:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -10, -55)
        dialog.OrbitHeaderDivider = div
    end
end

function Panel:UpdateTabs(dialog, activeTabName)
    if not dialog.OrbitTabs then
        return
    end

    for _, tab in ipairs(dialog.OrbitTabs) do
        local isSelected = (tab.definition.name == activeTabName)
        -- MinimalTabTemplate doesn't have built-in selection state visual other than disabled potentially
        -- But SettingsPanel tabs do have 'SetSelected'. Let's check.
        if tab.SetSelected then
            tab:SetSelected(isSelected)
        else
            -- Manual fallback: Dim if not selected
            if isSelected then
                tab.Text:SetTextColor(1, 1, 1)
                tab:Disable() -- Standard Blizz way to show active tab
            else
                tab.Text:SetTextColor(1, 0.82, 0)
                tab:Enable()
            end
        end
    end
end

function Panel:Open(tabName)
    local dialog = Orbit.SettingsDialog
    if not dialog then
        Orbit:Print("Orbit Settings dialog not available")
        return
    end

    -- Use last used or default
    tabName = tabName or self.lastTab or "Global"

    -- Find Tab Definition
    local tabDef = nil
    for _, t in ipairs(TABS) do
        if t.name == tabName then
            tabDef = t
            break
        end
    end
    if not tabDef then
        tabDef = TABS[1]
    end -- Fallback

    -- Optimization: If already open and same tab, do nothing
    if
        dialog:IsShown()
        and self.lastTab == tabDef.name
        and (dialog.Title and dialog.Title:GetText() == "Orbit Options")
    then
        return
    end

    -- MUTUAL EXCLUSION: Close native dialog
    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end

    self.lastTab = tabDef.name

    -- 1. Show Dialog
    dialog:Show()

    -- 2. Create Tabs UI if missing
    self:CreateTabs(dialog)
    self:UpdateTabs(dialog, tabDef.name)

    -- 3. Set Title
    if dialog.Title then
        dialog.Title:SetText("Orbit Options")
    end

    -- 4. Mock System Frame
    local mockFrame = CreateFrame("Frame")
    mockFrame.systemIndex = 1
    mockFrame.system = "Orbit_" .. tabDef.name

    -- 5. Render with Tab Key
    Config:Render(dialog, mockFrame, tabDef.plugin, tabDef.schema(), tabDef.name)

    -- 6. Position (Below Orbit Button)
    dialog:PositionNearButton()

    -- 7. Show Tabs and Divider (they might be hidden if dialog was closed)
    if dialog.OrbitTabs then
        for _, t in ipairs(dialog.OrbitTabs) do
            t:Show()
        end
    end
    if dialog.OrbitHeaderDivider then
        dialog.OrbitHeaderDivider:Show()
    end
end

function Panel:Hide()
    local dialog = Orbit.SettingsDialog
    if dialog and dialog:IsShown() then
        dialog:Hide()
    end
end

-- OnHide cleanup is handled by OrbitSettingsDialog itself

-------------------------------------------------
-- TOGGLE LOGIC - Uses Orbit's standalone dialog
-------------------------------------------------
function Panel:Toggle(tab)
    local dialog = Orbit.SettingsDialog
    if not dialog then
        Orbit:Print("Orbit Settings dialog not available")
        return
    end

    -- If already showing the requested tab, toggle off
    if dialog:IsShown() and self.currentTab == tab then
        dialog:Hide()
        self.currentTab = nil
        return
    end

    -- MUTUAL EXCLUSION: Close native dialog
    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end

    -- Show requested tab
    self.currentTab = tab

    -- Create mock systemFrame
    local systemFrame = CreateFrame("Frame")
    systemFrame.systemIndex = 1
    systemFrame.system = "Orbit_" .. tab

    -- Set title on the dialog
    if dialog.Title then
        if tab == "Plugins" then
            dialog.Title:SetText("Plugins")
        elseif tab == "Profiles" then
            dialog.Title:SetText("Profiles - " .. Orbit.Profile:GetActiveProfileName())
        end
    end

    -- Render using Config
    if tab == "Plugins" then
        Config:Render(dialog, systemFrame, PluginsPlugin, GetPluginsSchema(), "Plugins")
    elseif tab == "Profiles" then
        Config:Render(dialog, systemFrame, ProfilesPlugin, GetProfilesSchema(), "Profiles")
    end

    dialog:Show()
    dialog:PositionNearButton()
end

function Panel:Refresh()
    if self.currentTab then
        local tab = self.currentTab
        self.currentTab = nil
        self:Toggle(tab)
    end
end

-- SLASH COMMAND - Opens Edit Mode and Orbit Options

-- SLASH COMMAND - Opens Edit Mode or executes CLI commands
SLASH_ORBIT1 = "/orbit"
SLASH_ORBIT2 = "/orb"

-- Define Popup Dialogs for destructive actions
StaticPopupDialogs["ORBIT_CONFIRM_RESET"] = {
    text = "|cFFFF0000WARNING:|r You are about to reset the '%s' profile to defaults.\n\nThis cannot be undone.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function(self)
        Orbit.API:ResetProfile(self.data)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["ORBIT_CONFIRM_HARD_RESET"] = {
    text = "|cFFFF0000DANGER|r\n\nYou are about to FACTORY RESET Orbit.\n\nAll profiles, settings, and data will be wiped.\nThe UI will reload immediately.\n\nAre you sure?",
    button1 = "Factory Reset",
    button2 = "Cancel",
    OnAccept = function(self)
        Orbit.API:HardReset()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function Help()
    print("|cFF00FFFFOrbit Commands:|r")
    -- Use simple format without attempting column alignment (variable width font)
    print("  |cFF00FFFF/orbit|r - Toggle Edit Mode / Options")
    print("  |cFF00FFFF/orbit help|r - Show this list")
    print("  |cFF00FFFF/orbit status|r - Show Version, Profile, Spec")
    print("  |cFF00FFFF/orbit unlock|r - Rescue off-screen frames")
    print("  |cFF00FFFF/orbit export|r - Open Profile Export")
    print("  |cFF00FFFF/orbit debug|r - Dump debug info")
    print("  |cFF00FFFF/orbit reset|r - Reset CURRENT profile to defaults")
    print("  |cFF00FFFF/orbit hardreset|r - Factory Reset (Wipe All Data)")
end

SlashCmdList["ORBIT"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end

    local cmd = args[1] and args[1]:lower() or ""

    if cmd == "" then
        -- Default: Toggle UI
        if EditModeManagerFrame then
            if EditModeManagerFrame:IsShown() then
                HideUIPanel(EditModeManagerFrame)
                Panel:Hide()
            else
                ShowUIPanel(EditModeManagerFrame)
                Panel:Open("Global")
            end
        else
            Orbit:Print("Edit Mode not available.")
        end
        return
    end

    if cmd == "help" then
        Help()
    elseif cmd == "status" then
        local s = Orbit.API:GetState()
        print(string.format("Orbit v%s | Profile: %s | Spec: %s", s.Version, s.Profile, s.Spec))
    elseif cmd == "unlock" then
        Orbit.API:UnlockFrames()
    elseif cmd == "export" then
        local str = Orbit.Profile:ExportProfile()
        StaticPopupDialogs["ORBIT_EXPORT"] = {
            text = "Copy your backup string (All Profiles):",
            button1 = "Close",
            hasEditBox = true,
            OnShow = function(self)
                self.EditBox:SetText(str)
                self.EditBox:HighlightText()
                self.EditBox:SetFocus()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
            end,
            timeout = 0,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("ORBIT_EXPORT")
    elseif cmd == "debug" then
        local str = Orbit.API:DumpDebugInfo()
        -- Show in a copyable dialog
        StaticPopupDialogs["ORBIT_DEBUG_DUMP"] = {
            text = "Orbit Debug Info (Ctrl+C to copy):",
            button1 = "Close",
            hasEditBox = true,
            maxLetters = 99999,
            OnShow = function(self)
                self.EditBox:SetText(str)
                self.EditBox:HighlightText()
                self.EditBox:SetFocus()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
            end,
            timeout = 0,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("ORBIT_DEBUG_DUMP")
    elseif cmd == "reset" then
        local profile = Orbit.Profile:GetActiveProfileName()
        StaticPopup_Show("ORBIT_CONFIRM_RESET", profile, nil, profile)
    elseif cmd == "hardreset" then
        StaticPopup_Show("ORBIT_CONFIRM_HARD_RESET")
    else
        Orbit:Print("Unknown command: " .. cmd)
        Help()
    end
end
