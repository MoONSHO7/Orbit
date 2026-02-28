-- [ ORBIT OPTIONS PANEL ]---------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local Config = OrbitEngine.Config
local Constants = Orbit.Constants

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local BUTTON_WIDTH = 180
local DROPDOWN_WIDTH = 200
local SPACER_SMALL = 10
local SPACER_LARGE = 20
local POPUP_PREFERRED_INDEX = 3

-- [ HELPERS ]---------------------------------------------------------------------------------------

Orbit.OptionsPanel = {}
local Panel = Orbit.OptionsPanel

local function RefreshAllPreviews()
    for _, plugin in ipairs(OrbitEngine.systems) do
        if plugin.ApplyPreviewVisuals then plugin:ApplyPreviewVisuals() end
    end
end

local function CreateGlobalSettingsPlugin(name, onSetOverride)
    return {
        name = name,
        settings = {},
        GetSetting = function(self, systemIndex, key)
            if not Orbit.db or not Orbit.db.GlobalSettings then return nil end
            return Orbit.db.GlobalSettings[key]
        end,
        SetSetting = function(self, systemIndex, key, value)
            if not Orbit.db then return end
            if not Orbit.db.GlobalSettings then Orbit.db.GlobalSettings = {} end
            Orbit.db.GlobalSettings[key] = value
            if onSetOverride then onSetOverride(key, value) end
        end,
        ApplySettings = function(self, systemFrame)
            for _, plugin in ipairs(OrbitEngine.systems) do
                if plugin.ApplyAll then plugin:ApplyAll()
                elseif plugin.ApplySettings then plugin:ApplySettings() end
            end
            RefreshAllPreviews()
        end,
    }
end

-- [ GLOBAL TAB ]------------------------------------------------------------------------------------

local GlobalPlugin = CreateGlobalSettingsPlugin("OrbitGlobal")

local function GetGlobalSchema()
    local controls = {
        { type = "font", key = "Font", label = "Font", default = "PT Sans Narrow" },
        {
            type = "dropdown", key = "TextScale", label = "Text Scale",
            options = {
                { label = "Small", value = "Small" }, { label = "Medium", value = "Medium" },
                { label = "Large", value = "Large" }, { label = "Extra Large", value = "ExtraLarge" },
            },
            default = "Medium",
        },
        {
            type = "dropdown", key = "FontOutline", label = "Outline",
            options = {
                { label = "None", value = "" }, { label = "Outline", value = "OUTLINE" },
                { label = "Thick Outline", value = "THICKOUTLINE" }, { label = "Monochrome", value = "MONOCHROME" },
            },
            default = "OUTLINE",
        },
        { type = "slider", key = "BorderSize", label = "Border Size", default = 2, min = 0, max = 5, step = 1, updateOnRelease = true },
    }

    table.insert(controls, {
        type = "checkbox", key = "HideWhenMounted", label = "Hide When Mounted", default = false,
        onChange = function(val)
            Orbit.db.GlobalSettings.HideWhenMounted = val
            Orbit.MountedVisibility:Refresh()
        end,
    })

    table.insert(controls, {
        type = "description",
        text = "|cFFFFD100Right Click:|r Open Canvas Mode\n\n|cFFFFD100Anchor:|r Drag a frame to the edge of another frame to anchor it.\n\n|cFFFFD100Shift + Drag:|r Precision mode. Hides overlays and disables anchoring.\n\n|cFFFFD100Mouse Wheel:|r Scroll up and down on an anchored frame to adjust spacing between itself and its parent.",
    })

    return {
        hideNativeSettings = true,
        hideResetButton = false,
        controls = controls,
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.Font = "PT Sans Narrow"
                d.TextScale = "Medium"
                d.FontOutline = "OUTLINE"
                d.BorderSize = 2
                d.HideWhenMounted = false
            end
            Orbit.MountedVisibility:Refresh()
            Orbit:Print("Global settings reset to defaults.")
        end,
    }
end

-- [ COLORS TAB ]------------------------------------------------------------------------------------

local ColorsPlugin = CreateGlobalSettingsPlugin("OrbitColors")

local function GetColorsSchema()
    local controls = {
        { type = "texture", key = "Texture", label = "Texture", default = "Melli", previewColor = { r = 0.8, g = 0.8, b = 0.8 } },
        { type = "texture", key = "OverlayTexture", label = "Overlay Texture", default = "Orbit Gradient", previewColor = { r = 0.5, g = 0.5, b = 0.5 } },
        {
            type = "checkbox", key = "OverlayAllFrames", label = "Unit Frame Overlay", default = false,
            tooltip = "Apply overlay texture to unit frames as well. If unchecked, overlay only affects non-unit frames.",
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "OverlayAllFrames", val)
                ColorsPlugin:ApplySettings()
                RefreshAllPreviews()
            end,
        },
        {
            type = "colorcurve", key = "FontColorCurve", label = "Font Color",
            default = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } },
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "FontColorCurve", val)
                Orbit.Async:Debounce("ColorsPanel_FontColor", function() ColorsPlugin:ApplySettings() end, 0.15)
            end,
        },
        {
            type = "colorcurve", key = "BarColorCurve", label = "Unit Frame Health",
            default = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.2, a = 1 } } } },
            tooltip = "Health bar color. Use the color picker to select class color or create custom gradients.",
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "BarColorCurve", val)
                Orbit.Async:Debounce("ColorsPanel_BarColor", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                end, 0.15)
            end,
        },
        {
            type = "colorcurve", key = "UnitFrameBackdropColourCurve", label = "Unit Frame Background",
            default = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } },
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "UnitFrameBackdropColourCurve", val)
                Orbit.Async:Debounce("ColorsPanel_UnitFrameBg", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                end, 0.15)
            end,
        },
        {
            type = "colorcurve", key = "BackdropColourCurve", label = "Backdrop Color",
            default = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } },
            tooltip = "Background color for castbars, action bars, resource bars, and other non-unit frame elements.",
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "BackdropColourCurve", val)
                Orbit.Async:Debounce("ColorsPanel_BackdropColour", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                    Orbit.EventBus:Fire("ORBIT_GLOBAL_BACKDROP_CHANGED")
                end, 0.15)
            end,
        },
    }

    return {
        hideNativeSettings = true,
        hideResetButton = false,
        controls = controls,
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.Texture = "Melli"
                d.OverlayAllFrames = false
                d.OverlayTexture = "Orbit Gradient"
                d.BarColorCurve = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.2, a = 1 } } } }
                d.UnitFrameBackdropColourCurve = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } }
                d.BackdropColourCurve = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } }
                d.FontColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } }
            end
            Orbit:Print("Colors settings reset to defaults.")
            if Orbit.OptionsPanel then Orbit.OptionsPanel:Refresh() end
        end,
    }
end

-- [ EDIT MODE TAB ]---------------------------------------------------------------------------------

local EditModePlugin = CreateGlobalSettingsPlugin("OrbitEditMode", function(key, value)
    if Orbit.Engine.FrameSelection then Orbit.Engine.FrameSelection:RefreshVisuals() end
end)

EditModePlugin.ApplySettings = function(self, systemFrame) end

local function GetEditModeSchema()
    return {
        hideNativeSettings = true,
        hideResetButton = false,
        controls = {
            { type = "checkbox", key = "ShowBlizzardFrames", label = "Show Blizzard Frames", default = true, tooltip = "Show selection overlays for native Blizzard frames in Edit Mode." },
            { type = "checkbox", key = "ShowOrbitFrames", label = "Show Orbit Frames", default = true, tooltip = "Show selection overlays for Orbit-owned frames in Edit Mode." },
            { type = "checkbox", key = "AnchoringEnabled", label = "Enable Frame Anchoring", default = true, tooltip = "Allow frames to anchor to other frames. Disabling preserves existing anchors but prevents new ones.\n\nHold Shift while dragging to temporarily bypass anchoring." },
            {
                type = "colorcurve", key = "EditModeColorCurve", label = "Orbit Frame Color",
                default = { pins = { { position = 0, color = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 } } } },
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
                d.EditModeColorCurve = { pins = { { position = 0, color = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 } } } }
            end
            if Orbit.Engine.FrameSelection then Orbit.Engine.FrameSelection:RefreshVisuals() end
            Orbit:Print("Edit Mode settings reset to defaults.")
        end,
    }
end

-- [ PROFILES TAB ]----------------------------------------------------------------------------------

local ProfilesPlugin = {
    name = "OrbitProfiles",
    settings = {},
    GetSetting = function(self, systemIndex, key)
        if key == "CurrentProfile" or key == "ActiveProfile" then
            return Orbit.Profile:GetActiveProfileName()
        elseif key == "SpecBinding" then
            local specIndex = GetSpecialization()
            if not specIndex then return "None" end
            local specID = GetSpecializationInfo(specIndex)
            if not specID then return "None" end
            return Orbit.Profile:GetProfileForSpec(specID) or "None"
        elseif key == "ProfileNotes" then
            local active = Orbit.Profile:GetActiveProfileName()
            return Orbit.db.profiles[active] and Orbit.db.profiles[active].notes or ""
        elseif key == "SpecSwitchingEnabled" then return Orbit.db.enableSpecSwitching
        elseif key == "AutoSpecProfiles" then return Orbit.db.autoSpecProfiles
        elseif key == "ProfileToDelete" then return Orbit.Profile._selectedToDelete or "Default"
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
            if not specIndex then return end
            local specID = GetSpecializationInfo(specIndex)
            if not specID then return end
            if value == "None" then value = nil end
            Orbit.Profile:SetProfileForSpec(specID, value)
            Orbit:Print("Bound current specialization to profile: " .. (value or "None"))
            if Orbit.db.enableSpecSwitching then Orbit.Profile:CheckSpecProfile() end
        elseif key == "ProfileNotes" then
            local active = Orbit.Profile:GetActiveProfileName()
            if Orbit.db.profiles[active] then Orbit.db.profiles[active].notes = value end
        elseif key == "SpecSwitchingEnabled" then
            Orbit.db.enableSpecSwitching = value
            if value then Orbit.Profile:CheckSpecProfile() end
        elseif key == "AutoSpecProfiles" then
            Orbit.db.autoSpecProfiles = value
            if value then Orbit.Profile:CheckSpecProfile() end
        end
    end,
    ApplySettings = function(self, systemFrame) end,
}

local function GetProfilesSchema()
    local activeProfile = Orbit.Profile:GetActiveProfileName()

    local function GetAllProfileOptions()
        local opts = {}
        for _, n in ipairs(Orbit.Profile:GetProfiles()) do
            table.insert(opts, { text = n, value = n })
        end
        return opts
    end

    return {
        hideNativeSettings = true,
        hideResetButton = true,
        controls = {
            { type = "header", text = "Active Profile" },
            { type = "label", text = activeProfile, key = "ActiveProfileDisplay" },
            { type = "spacer", height = SPACER_SMALL },
            { type = "label", text = "Profiles are automatically managed per-specialization.", key = "AutoInfo" },
            { type = "spacer", height = SPACER_LARGE },
            { type = "header", text = "Manage Profiles" },
            { type = "dropdown", key = "ProfileToDelete", label = "Select Profile", options = GetAllProfileOptions, default = "Default", width = DROPDOWN_WIDTH },
            {
                type = "button", text = "Copy From Above", width = BUTTON_WIDTH,
                onClick = function()
                    local selected = Orbit.Profile._selectedToDelete
                    if not selected or selected == "" then Orbit:Print("Please select a profile first."); return end
                    local currentActive = Orbit.Profile:GetActiveProfileName()
                    if selected == currentActive then Orbit:Print("Cannot copy from the active profile."); return end
                    local popup = StaticPopup_Show("ORBIT_CONFIRM_COPY_PROFILE", currentActive, selected)
                    if popup then popup.data = { source = selected, target = currentActive } end
                end,
            },
            {
                type = "button", text = "Delete Selected Profile", width = BUTTON_WIDTH,
                onClick = function()
                    local selected = Orbit.Profile._selectedToDelete
                    if not selected or selected == "" then Orbit:Print("Please select a profile first."); return end
                    local currentActive = Orbit.Profile:GetActiveProfileName()
                    if selected == "Default" then Orbit:Print("Cannot delete Default profile."); return end
                    if selected == currentActive then Orbit:Print("Cannot delete active profile. Switch specs first."); return end
                    Orbit.Profile:DeleteProfile(selected)
                    Orbit:Print(selected .. " Profile Deleted.")
                    Orbit.Profile._selectedToDelete = nil
                    if Orbit.OptionsPanel then
                        Orbit.OptionsPanel.lastTab = nil
                        Orbit.OptionsPanel:Open("Profiles")
                    end
                end,
            },
            { type = "spacer", height = SPACER_LARGE },
        },
        extraButtons = {
            {
                text = "Export",
                callback = function()
                    local str = Orbit.Profile:ExportProfile()
                    StaticPopupDialogs["ORBIT_EXPORT"] = {
                        text = "Copy your backup string (All Profiles):",
                        button1 = "Close", hasEditBox = true,
                        OnShow = function(self) self.EditBox:SetText(str); self.EditBox:HighlightText(); self.EditBox:SetFocus() end,
                        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
                        timeout = 0, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
                    }
                    StaticPopup_Show("ORBIT_EXPORT")
                end,
            },
            {
                text = "Import",
                callback = function()
                    StaticPopupDialogs["ORBIT_IMPORT"] = {
                        text = "Paste profile string (Single or Backup):",
                        button1 = "Import", button2 = "Cancel", hasEditBox = true,
                        OnAccept = function(self)
                            local str = self.EditBox:GetText()
                            local success, err = Orbit.Profile:ImportProfile(str)
                            if success then
                                Orbit:Print("Import successful. Reloading UI is recommended.")
                                if Orbit.OptionsPanel and Orbit.OptionsPanel.Refresh then Orbit.OptionsPanel:Refresh() end
                            else
                                print("Import Failed: " .. (err or "Unknown"))
                            end
                        end,
                        timeout = 0, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
                    }
                    StaticPopup_Show("ORBIT_IMPORT")
                end,
            },
        },
    }
end

-- [ MAIN LOGIC ]------------------------------------------------------------------------------------

local TABS = {
    { name = "Global", plugin = GlobalPlugin, schema = GetGlobalSchema },
    { name = "Colors", plugin = ColorsPlugin, schema = GetColorsSchema },
    { name = "Edit Mode", plugin = EditModePlugin, schema = GetEditModeSchema },
    { name = "Profiles", plugin = ProfilesPlugin, schema = GetProfilesSchema },
}

function Panel:Open(tabName)
    if InCombatLockdown() then return end
    local dialog = Orbit.SettingsDialog
    if not dialog then return end

    tabName = tabName or self.lastTab or TABS[1].name

    local tabDef = nil
    for _, t in ipairs(TABS) do
        if t.name == tabName then tabDef = t; break end
    end
    tabDef = tabDef or TABS[1]

    if dialog:IsShown() and self.lastTab == tabDef.name and dialog.Title and dialog.Title:GetText() == "Orbit Options" then
        return
    end

    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end

    self.lastTab = tabDef.name
    dialog.orbitCurrentTab = tabDef.name
    dialog.attachedPlugin = nil
    dialog:Show()

    if dialog.Title then dialog.Title:SetText("Orbit Options") end

    local tabNames = {}
    for _, t in ipairs(TABS) do tabNames[#tabNames + 1] = t.name end

    local schema = tabDef.schema()
    table.insert(schema.controls, 1, {
        type = "tabs", tabs = tabNames, activeTab = tabDef.name,
        onTabSelected = function(newTab) Panel:Open(newTab) end,
    })

    local mockFrame = CreateFrame("Frame")
    mockFrame.systemIndex = 1
    mockFrame.system = "Orbit_" .. tabDef.name

    Config:Render(dialog, mockFrame, tabDef.plugin, schema, tabDef.name)
    dialog:PositionNearButton()
end

function Panel:Hide()
    local dialog = Orbit.SettingsDialog
    if dialog and dialog:IsShown() then dialog:Hide() end
end

-- [ TOGGLE LOGIC ]----------------------------------------------------------------------------------

function Panel:Toggle(tab)
    local dialog = Orbit.SettingsDialog
    if not dialog then Orbit:Print("Orbit Settings dialog not available"); return end

    if dialog:IsShown() and self.currentTab == tab then
        dialog:Hide()
        self.currentTab = nil
        return
    end

    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end

    self.currentTab = tab

    local systemFrame = CreateFrame("Frame")
    systemFrame.systemIndex = 1
    systemFrame.system = "Orbit_" .. tab

    if tab == "Profiles" and dialog.Title then
        dialog.Title:SetText("Profiles - " .. Orbit.Profile:GetActiveProfileName())
    end

    if tab == "Profiles" then
        Config:Render(dialog, systemFrame, ProfilesPlugin, GetProfilesSchema(), "Profiles")
    end

    dialog:Show()
    dialog:PositionNearButton()
end

function Panel:Refresh()
    local tabToRefresh = self.currentTab or self.lastTab
    if tabToRefresh then
        self.currentTab = nil
        self.lastTab = nil
        self:Open(tabToRefresh)
    end
end

-- [ SLASH COMMANDS ]--------------------------------------------------------------------------------

SLASH_ORBIT1 = "/orbit"
SLASH_ORBIT2 = "/orb"

StaticPopupDialogs["ORBIT_CONFIRM_RESET"] = {
    text = "|cFFFF0000WARNING:|r You are about to reset the '%s' profile to defaults.\n\nThis cannot be undone.",
    button1 = "Reset", button2 = "Cancel",
    OnAccept = function(self) Orbit.API:ResetProfile(self.data) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

StaticPopupDialogs["ORBIT_CONFIRM_HARD_RESET"] = {
    text = "|cFFFF0000DANGER|r\n\nYou are about to FACTORY RESET Orbit.\n\nAll profiles, settings, and data will be wiped.\nThe UI will reload immediately.\n\nAre you sure?",
    button1 = "Factory Reset", button2 = "Cancel",
    OnAccept = function(self) Orbit.API:HardReset() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

StaticPopupDialogs["ORBIT_CONFIRM_COPY_PROFILE"] = {
    text = "|cFFFF0000WARNING:|r This will overwrite your '%s' settings with '%s' settings.\n\nThis cannot be undone.",
    button1 = "Apply", button2 = "Decline",
    OnAccept = function(self)
        local success, err = Orbit.Profile:CopyProfileData(self.data.source)
        if success then
            ReloadUI()
        else
            Orbit:Print("Copy failed: " .. (err or "Unknown error"))
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

local function Help()
    print("|cFFAA77FFOrbit Commands:|r")
    print("  |cFFAA77FF/orbit|r |cFF00D4FF- Toggle Edit Mode / Options|r")
    print("  |cFFAA77FF/orbit plugins|r |cFF00D4FF- Open Plugin Manager|r")
    print("  |cFFAA77FF/orbit reset|r |cFF00D4FF- Reset CURRENT profile to defaults|r")
    print("  |cFFAA77FF/orbit hardreset|r |cFF00D4FF- Factory Reset (Wipe All Data)|r")
    print("  |cFFAA77FF/orbit portal|r |cFF00D4FF- Portal Dock commands|r")
    print("  |cFFAA77FF/orbit refresh <plugin>|r |cFF00D4FF- Force refresh a plugin|r")
end

SlashCmdList["ORBIT"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do table.insert(args, word) end
    local cmd = args[1] and args[1]:lower() or ""

    if cmd == "" then
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

    if cmd == "help" then Help()
    elseif cmd == "plugins" then
        if Orbit._pluginSettingsCategoryID then
            Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
        else
            Orbit:Print("Plugin Manager not yet loaded.")
        end
    elseif cmd == "reset" then
        local profile = Orbit.Profile:GetActiveProfileName()
        StaticPopup_Show("ORBIT_CONFIRM_RESET", profile, nil, profile)
    elseif cmd == "hardreset" then StaticPopup_Show("ORBIT_CONFIRM_HARD_RESET")
    elseif cmd == "portal" or cmd == "p" then
        local subCmd = args[2] and args[2]:lower() or ""
        Orbit.EventBus:Fire("ORBIT_PORTAL_COMMAND", subCmd)
    elseif cmd == "refresh" then
        local subCmd = args[2] or ""
        if subCmd == "" then
            Orbit:Print("Usage: /orbit refresh <plugin_system_id>")
            Orbit:Print("Example: /orbit refresh Orbit_CooldownViewer")
            return
        end
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons.regionCache = setmetatable({}, { __mode = "k" })
        end
        local plugin = Orbit:GetPlugin(subCmd)
        if plugin then
            if plugin.ReapplyParentage then plugin:ReapplyParentage() end
            if plugin.ApplyAll then plugin:ApplyAll()
            elseif plugin.ApplySettings then plugin:ApplySettings() end
            Orbit:Print(subCmd .. " refreshed.")
        else
            Orbit:Print("Plugin not found: " .. subCmd)
        end
    else
        Orbit:Print("Unknown command: " .. cmd)
        Help()
    end
end
