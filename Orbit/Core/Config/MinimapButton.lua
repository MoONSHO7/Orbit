-- [ MINIMAP BUTTON ]--------------------------------------------------------------------------------

local _, Orbit = ...

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local ICON_PATH = "Interface\\AddOns\\Orbit\\Core\\assets\\Orbit.png"
local BUTTON_NAME = "Orbit"

-- [ DATA BROKER ]-----------------------------------------------------------------------------------

local ldb = LibStub("LibDataBroker-1.1")
local dataObj = ldb:NewDataObject(BUTTON_NAME, {
    type = "launcher",
    icon = ICON_PATH,
    OnClick = function(self, button)
        if InCombatLockdown() then return end
        if button == "LeftButton" then
            if EditModeManagerFrame then
                if EditModeManagerFrame:IsShown() then
                    HideUIPanel(EditModeManagerFrame)
                    if Orbit.OptionsPanel then Orbit.OptionsPanel:Hide() end
                else
                    ShowUIPanel(EditModeManagerFrame)
                    if Orbit.OptionsPanel then Orbit.OptionsPanel:Open("Global") end
                end
            end
        elseif button == "RightButton" then
            if Orbit._pluginSettingsCategoryID then
                Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Orbit", 1, 1, 1)
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFF00FF00Left-click|r Edit Mode + Orbit Options", 0.8, 0.8, 0.8)
        tooltip:AddLine("|cFFFFFF00Right-click|r Advanced Options", 0.8, 0.8, 0.8)
    end,
})

-- [ REGISTER ]--------------------------------------------------------------------------------------

local icon = LibStub("LibDBIcon-1.0")
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    if not OrbitDB.minimap then OrbitDB.minimap = {} end
    icon:Register(BUTTON_NAME, dataObj, OrbitDB.minimap)
    icon:AddButtonToCompartment(BUTTON_NAME)
    self:UnregisterAllEvents()
end)
