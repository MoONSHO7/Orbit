-- [ ORBIT ADVANCED SETTINGS ]------------------------------------------------------------------------
-- Orchestrator for the Orbit AddOns settings panel. Hosts three tabs:
-- 1. Plugin Manager — enable/disable Orbit plugins
-- 2. Visibility Engine — centralized frame visibility settings
-- 3. Quality of Life — expandable sections for misc QoL features
-- Content builders live in Config/Advanced/. This file provides the tab bar,
-- panel shell, and Settings API registration.
-- Accessible via /orbit plugins or Game Menu > Options > AddOns > Orbit.

local _, Orbit = ...
Orbit._AC = Orbit._AC or {}
local Pixel = Orbit.Engine.Pixel

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local PADDING = 16
local HEADER_HEIGHT = 40
local TAB_HEIGHT = 28
local TAB_PADDING = 4
local TAB_EXTRA_WIDTH = 16
local TAB_FONT = "GameFontNormal"
local TAB_ACTIVE_COLOR = { r = 1, g = 0.82, b = 0 }
local TAB_INACTIVE_COLOR = { r = 0.6, g = 0.6, b = 0.6 }

-- [ TAB BAR FACTORY ]--------------------------------------------------------------------------------
local function CreateTabBar(parent, tabs, onTabSelected)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TAB_HEIGHT)
    bar:SetPoint("TOPLEFT", PADDING, -PADDING)
    bar:SetPoint("TOPRIGHT", -PADDING, -PADDING)
    bar.buttons = {}
    local xOffset = 0
    for i, tabName in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, bar)
        Pixel:Enforce(btn)
        btn:SetHeight(TAB_HEIGHT)
        btn.label = btn:CreateFontString(nil, "OVERLAY", TAB_FONT)
        btn.label:SetPoint("CENTER")
        btn.label:SetText(tabName)
        local textW = btn.label:GetStringWidth()
        btn:SetWidth(textW + TAB_PADDING * 2 + TAB_EXTRA_WIDTH)
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

-- [ PANEL CREATION ]---------------------------------------------------------------------------------
local function CreatePluginPanel()
    local frame = CreateFrame("Frame", "OrbitPluginManagerPanel")
    frame:Hide()

    local TAB_NAMES = { "Plugin Manager", "Visibility Engine", "Quality of Life" }
    local activeTab = TAB_NAMES[1]

    -- Content containers
    local pluginContent = CreateFrame("Frame", nil, frame)
    pluginContent:SetAllPoints()
    local veContent = Orbit._AC.CreateVEContent(frame)
    local qolContent = Orbit._AC.CreateQoLContent(frame)
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

    -- Plugin Manager content
    Orbit._AC.BuildPluginContent(pluginContent, frame)

    frame:SetScript("OnShow", function()
        if Orbit.VisibilityEngine then Orbit.VisibilityEngine:Migrate() end
        SwitchTab(activeTab)
    end)
    return frame
end

-- [ SETTINGS REGISTRATION ]--------------------------------------------------------------------------
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
