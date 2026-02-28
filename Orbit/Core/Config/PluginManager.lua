-- [ PLUGIN MANAGER ]--------------------------------------------------------------------------------
-- WoW AddOns settings panel for enabling/disabling Orbit plugins.
-- Accessible via /orbit plugins or Game Menu > Options > AddOns > Orbit.

local _, Orbit = ...
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local CHECKBOX_HEIGHT = 26
local PADDING = 16
local HEADER_HEIGHT = 40
local RELOAD_BUTTON_HEIGHT = 32
local FONT_HEADER = "GameFontNormalLarge"
local FONT_HIGHLIGHT = "GameFontHighlight"
local FONT_SMALL = "GameFontNormalSmall"

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
    local checkboxes = {}
    local pendingChanges = false
    local reloadButton

    local function UpdateReloadButton()
        if not reloadButton then return end
        reloadButton:SetEnabled(pendingChanges)
        reloadButton:SetText(pendingChanges and "|cFFFF8800Reload UI to Apply|r" or "Reload UI")
    end

    local function BuildCheckboxes()
        for _, cb in ipairs(checkboxes) do cb:Hide() end
        wipe(checkboxes)
        pendingChanges = false

        if not OrbitEngine.systems then return end

        local yOffset = -(HEADER_HEIGHT + 30)
        for i, plugin in ipairs(OrbitEngine.systems) do
            local cb = checkboxPool[i] or CreateCheckbox(frame, i)
            checkboxPool[i] = cb

            cb:SetPoint("TOPLEFT", PADDING, yOffset)
            cb.text:SetText(plugin.name)
            cb:SetChecked(Orbit:IsPluginEnabled(plugin.name))

            local initialState = cb:GetChecked()
            cb._initialState = initialState
            cb:SetScript("OnClick", function(self)
                Orbit:SetPluginEnabled(plugin.name, self:GetChecked())
                pendingChanges = false
                for _, existing in ipairs(checkboxes) do
                    if existing._initialState ~= existing:GetChecked() then
                        pendingChanges = true
                        break
                    end
                end
                UpdateReloadButton()
            end)
            cb:Show()
            table.insert(checkboxes, cb)
            yOffset = yOffset - CHECKBOX_HEIGHT
        end

        if not reloadButton then
            reloadButton = CreateFrame("Button", "OrbitPluginReloadButton", frame, "UIPanelButtonTemplate")
            reloadButton:SetSize(160, RELOAD_BUTTON_HEIGHT)
            reloadButton:SetScript("OnClick", function() ReloadUI() end)
        end
        reloadButton:ClearAllPoints()
        reloadButton:SetPoint("TOPLEFT", PADDING, yOffset - 12)
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
