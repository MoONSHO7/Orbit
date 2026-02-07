local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-------------------------------------------------
-- ORBIT OPTIONS BUTTON
-- A clickable field in the top-left corner during Edit Mode
-- Left click = Plugins, Right click = Profiles
-------------------------------------------------

local BUTTON_WIDTH = 200
local BUTTON_HEIGHT = 40
local BUTTON_PADDING = 20

-- Create the button
local Button = CreateFrame("Button", "OrbitOptionsButton", UIParent, "BackdropTemplate")
Button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
Button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", BUTTON_PADDING, -BUTTON_PADDING)
Button:SetFrameStrata("TOOLTIP")
Button:SetFrameLevel(100)
Button:Hide()

-- Backdrop (background + border unified)
Button:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
Button:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
Button:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)

-- Highlight on hover
Button.highlight = Button:CreateTexture(nil, "HIGHLIGHT")
Button.highlight:SetPoint("TOPLEFT", 4, -4)
Button.highlight:SetPoint("BOTTOMRIGHT", -4, 4)
Button.highlight:SetColorTexture(0.2, 0.4, 0.6, 0.3)

-- Label
Button.label = Button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
Button.label:SetPoint("CENTER", Button, "CENTER", 0, 0)
Button.label:SetText("Orbit Options")
Button.label:SetTextColor(0.9, 0.9, 0.95)

-- Tooltip
Button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Orbit Options", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFF00FF00Left-click|r: Toggle plugins on/off", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cFFFFFF00Right-click|r: Colors & textures", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

Button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Register for both mouse buttons
Button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Click Handler
Button:SetScript("OnClick", function(self, button)
    if InCombatLockdown() then
        return
    end

    if button == "LeftButton" then
        Orbit.OptionsPanel:Open("Global")
    elseif button == "RightButton" then
        Orbit.OptionsPanel:Open("Colors")
    end
end)

-------------------------------------------------
-- COMBAT INDICATOR
-------------------------------------------------

local PULSE_SPEED = 3

local function OnUpdate_Pulse(self, elapsed)
    self.pulseTimer = (self.pulseTimer or 0) + elapsed
    -- Pulse alpha between 0.3 and 1.0
    local alpha = 0.3 + 0.7 * math.abs(math.sin(self.pulseTimer * PULSE_SPEED))
    self:SetBackdropBorderColor(1, 0.2, 0.2, alpha)
    -- Also pulse text slightly for effect? No, just border per request.
end

Button:RegisterEvent("PLAYER_REGEN_DISABLED")
Button:RegisterEvent("PLAYER_REGEN_ENABLED")

Button:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Enter Combat State
        self.label:SetText("In Combat")
        self.label:SetTextColor(1, 0.2, 0.2)

        self:Disable() -- Disable clicks

        self.pulseTimer = 0
        self:SetScript("OnUpdate", OnUpdate_Pulse)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Exit Combat State
        self.label:SetText("Orbit Options")
        self.label:SetTextColor(0.9, 0.9, 0.95)

        self:Enable() -- Re-enable clicks

        self:SetScript("OnUpdate", nil)
        self:SetBackdropBorderColor(0.4, 0.4, 0.45, 1) -- Restore default border
    end
end)

-- Initial check
if InCombatLockdown() then
    Button.label:SetText("In Combat")
    Button.label:SetTextColor(1, 0.2, 0.2)
    Button:Disable()
    Button.pulseTimer = 0
    Button:SetScript("OnUpdate", OnUpdate_Pulse)
end

-------------------------------------------------
-- EDIT MODE LIFECYCLE
-------------------------------------------------

-- Show when Edit Mode enters
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function()
        Button:Show()
    end)

    EditModeManagerFrame:HookScript("OnHide", function()
        Button:Hide()
        -- Also hide the options panel
        if Orbit.OptionsPanel and Orbit.OptionsPanel.Hide then
            Orbit.OptionsPanel:Hide()
        end
    end)
end

-- Export
Orbit.OptionsButton = Button
