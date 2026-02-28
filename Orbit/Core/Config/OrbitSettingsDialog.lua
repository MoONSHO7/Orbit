-- [ ORBIT SETTINGS DIALOG ]--------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]--------------------------------------------------------------------

local DIALOG_WIDTH = 350
local DIALOG_MIN_HEIGHT = 150
local TITLE_PADDING = 40
local DIALOG_FRAME_LEVEL = 200
local CLOSE_BUTTON_OFFSET = -2
local INITIAL_X = 220
local INITIAL_Y = -20
local ESC_RESTORE_DELAY = 0.05
local OPTIONS_BUTTON_OFFSET_X = -2
local OPTIONS_BUTTON_OFFSET_Y = -10

-- [ CREATE DIALOG FRAME ]----------------------------------------------------------

local Dialog = CreateFrame("Frame", "OrbitSettingsDialog", UIParent)
Dialog:SetSize(DIALOG_WIDTH, DIALOG_MIN_HEIGHT)
Dialog:SetPoint("TOPLEFT", UIParent, "TOPLEFT", INITIAL_X, INITIAL_Y)
Dialog:SetFrameStrata("DIALOG")
Dialog:SetFrameLevel(DIALOG_FRAME_LEVEL)
Dialog:SetMovable(true)
Dialog:SetClampedToScreen(true)
Dialog:EnableMouse(true)
Dialog:RegisterForDrag("LeftButton")
Dialog:Hide()

Dialog.Border = CreateFrame("Frame", nil, Dialog, "DialogBorderTranslucentTemplate")
Dialog.Border:SetAllPoints(Dialog)
Dialog.Border:SetFrameLevel(Dialog:GetFrameLevel())

Dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)

Dialog:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local top, left = self:GetTop(), self:GetLeft()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end)

Dialog:RegisterEvent("PLAYER_REGEN_DISABLED")
Dialog:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then self:Hide() end
end)

-- [ TITLE ]------------------------------------------------------------------------

Dialog.Title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
Dialog.Title:SetPoint("TOP", Dialog, "TOP", 0, -15)
Dialog.Title:SetText("Orbit Settings")

-- [ CLOSE BUTTON ]-----------------------------------------------------------------

Dialog.CloseButton = CreateFrame("Button", nil, Dialog, "UIPanelCloseButton")
Dialog.CloseButton:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", CLOSE_BUTTON_OFFSET, CLOSE_BUTTON_OFFSET)
Dialog.CloseButton:SetScript("OnClick", function() Dialog:Hide() end)

-- [ ESC KEY SUPPORT ]--------------------------------------------------------------

table.insert(UISpecialFrames, "OrbitSettingsDialog")

Dialog:SetPropagateKeyboardInput(true)
Dialog:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        if InCombatLockdown() then return end
        self:SetPropagateKeyboardInput(false)
        self:Hide()
        C_Timer.After(ESC_RESTORE_DELAY, function()
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
    end
end)

-- [ ATTACHED SYSTEM TRACKING ]-----------------------------------------------------

Dialog.attachedToSystem = nil
Dialog.attachedPlugin = nil
Dialog.attachedSystemIndex = nil

-- [ CORE API: UpdateDialog ]-------------------------------------------------------

function Dialog:UpdateDialog(context)
    if InCombatLockdown() then return end
    if not context then return end

    local systemFrame = context.systemFrame
    local pluginName = context.system
    local systemIndex = context.systemIndex or 1

    local plugin = Orbit:GetPlugin(pluginName)
    if not plugin and systemFrame and systemFrame.orbitPlugin then
        plugin = systemFrame.orbitPlugin
    end
    if not plugin then return end

    if plugin ~= self.attachedPlugin then self.orbitCurrentTab = nil end

    self.attachedToSystem = systemFrame
    self.attachedPlugin = plugin
    self.attachedSystemIndex = systemIndex

    local title = plugin.name
    if systemFrame and systemFrame.editModeName then title = systemFrame.editModeName end
    self.Title:SetText(title)

    local renderContext = { system = pluginName, systemIndex = systemIndex, systemFrame = systemFrame }

    if plugin.AddSettings then plugin:AddSettings(self, renderContext) end
end

-- [ SHOW/HIDE HANDLERS ]-----------------------------------------------------------

Dialog:SetScript("OnShow", function(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end
end)

Dialog:SetScript("OnHide", function(self)
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    self.attachedToSystem = nil
    self.attachedPlugin = nil
    self.attachedSystemIndex = nil
    OrbitEngine.FrameSelection:DeselectAll()
end)

-- [ POSITION HELPER ]--------------------------------------------------------------

function Dialog:PositionNearButton()
    if Orbit.OptionsButton then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", Orbit.OptionsButton, "BOTTOMLEFT", OPTIONS_BUTTON_OFFSET_X, OPTIONS_BUTTON_OFFSET_Y)
    end
end

-- [ INTEGRATION ]------------------------------------------------------------------

function Dialog:OnNativeFrameSelected() self:Hide() end

-- [ EDIT MODE LIFECYCLE ]----------------------------------------------------------

if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", function() Dialog:Hide() end)
end

-- [ EXPORT ]-----------------------------------------------------------------------

Orbit.SettingsDialog = Dialog
