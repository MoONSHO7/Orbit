-- [ ORBIT OPTIONS PANEL ]---------------------------------------------------------------------------
-- Shell for the Orbit Options dialog. Owns tab registration, open/hide/refresh lifecycle, and the
-- shared helpers each tab uses to build a Global-scoped settings plugin. Individual tab schemas
-- and plugins live in `Tabs/` and register themselves into `Panel.Tabs`.

local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local Config = OrbitEngine.Config
local L = Orbit.L

-- [ TAB ORDER ]-------------------------------------------------------------------------------------

local TAB_ORDER = { "Global", "Colors", "Edit Mode", "Profiles" }

-- [ PANEL ]-----------------------------------------------------------------------------------------

Orbit.OptionsPanel = {}
local Panel = Orbit.OptionsPanel

Panel.Tabs = {}
Panel.TabOrder = TAB_ORDER

-- [ SHARED HELPERS ]--------------------------------------------------------------------------------
-- Exposed on Panel._helpers so tab files can build Global-scoped settings plugins without
-- duplicating the GetSetting/SetSetting/ApplySettings wiring.

local function RefreshAllPreviews()
    for _, plugin in ipairs(OrbitEngine.systems) do
        if plugin.ApplyPreviewVisuals then plugin:ApplyPreviewVisuals() end
    end
end

-- [ FONT EVENT BROADCAST ]--------------------------------------------------------------------------
-- Resolves the current GlobalSettings font state and broadcasts it via Blizzard's shared
-- EventRegistry so external addons (e.g. Orbit-Talents) can mirror Orbit's font choices
-- without reading Orbit's tables directly. Payload is resolved (LSM path, not font name).
local FONT_KEYS = { Font = true, FontOutline = true, FontShadow = true }

local function FireFontChanged()
    if not Orbit.db or not Orbit.db.GlobalSettings then return end
    local g = Orbit.db.GlobalSettings
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontPath = (g.Font and LSM and LSM:Fetch("font", g.Font)) or "Fonts\\FRIZQT__.TTF"
    local outline = g.FontOutline or "OUTLINE"
    local shadow = g.FontShadow and true or false
    EventRegistry:TriggerEvent("OrbitFontChanged", fontPath, outline, shadow)
end

Orbit.EventBus:On("PLAYER_ENTERING_WORLD", FireFontChanged)

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
            if FONT_KEYS[key] then FireFontChanged() end
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

Panel._helpers = {
    RefreshAllPreviews = RefreshAllPreviews,
    CreateGlobalSettingsPlugin = CreateGlobalSettingsPlugin,
}

-- [ MAIN LOGIC ]------------------------------------------------------------------------------------

function Panel:Open(tabName)
    if InCombatLockdown() then return end
    local dialog = Orbit.SettingsDialog
    if not dialog then return end

    tabName = tabName or self.lastTab or TAB_ORDER[1]

    local resolvedName = self.Tabs[tabName] and tabName or TAB_ORDER[1]
    local tabDef = self.Tabs[resolvedName]
    if not tabDef then return end

    if dialog:IsShown() and self.lastTab == resolvedName and dialog.Title and dialog.Title:GetText() == "Orbit Options" then
        return
    end

    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end

    self.lastTab = resolvedName
    dialog.orbitCurrentTab = resolvedName
    dialog.attachedPlugin = nil
    dialog:Show()

    if dialog.Title then dialog.Title:SetText(L.CFG_ORBIT_OPTIONS) end

    local schema = tabDef.schema()
    table.insert(schema.controls, 1, {
        type = "tabs", tabs = TAB_ORDER, activeTab = resolvedName,
        onTabSelected = function(newTab) Panel:Open(newTab) end,
    })

    local mockFrame = CreateFrame("Frame")
    mockFrame.systemIndex = 1
    mockFrame.system = "Orbit_" .. resolvedName

    Config:Render(dialog, mockFrame, tabDef.plugin, schema, resolvedName)
    dialog:PositionNearButton()
end

function Panel:Hide()
    local dialog = Orbit.SettingsDialog
    if dialog and dialog:IsShown() then dialog:Hide() end
end

-- [ TOGGLE LOGIC ]----------------------------------------------------------------------------------

function Panel:Toggle(tab)
    local dialog = Orbit.SettingsDialog
    if not dialog then Orbit:Print(L.MSG_SETTINGS_UNAVAILABLE); return end

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
        dialog.Title:SetText(L.CFG_PROFILES_TITLE_F:format(Orbit.Profile:GetActiveProfileName()))
    end

    local tabDef = self.Tabs[tab]
    if tab == "Profiles" and tabDef then
        Config:Render(dialog, systemFrame, tabDef.plugin, tabDef.schema(), "Profiles")
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
