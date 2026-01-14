-- [ ORBIT SETTINGS DIALOG ]--------------------------------------------------------
-- Standalone settings dialog for Orbit-managed frames
-- Completely decoupled from Blizzard's EditModeSystemSettingsDialog
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-------------------------------------------------
-- CONSTANTS
-------------------------------------------------
local DIALOG_WIDTH = 350
local DIALOG_MIN_HEIGHT = 150
local TITLE_PADDING = 40 -- Space from top for Title

-------------------------------------------------
-- CREATE DIALOG FRAME
-------------------------------------------------
local Dialog = CreateFrame("Frame", "OrbitSettingsDialog", UIParent, "BackdropTemplate")
Dialog:SetSize(DIALOG_WIDTH, DIALOG_MIN_HEIGHT)
Dialog:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 220, -20)
Dialog:SetFrameStrata("DIALOG")
Dialog:SetFrameLevel(200)
Dialog:SetMovable(true)
Dialog:SetClampedToScreen(true)
Dialog:EnableMouse(true)
Dialog:RegisterForDrag("LeftButton")
Dialog:Hide()

-- Backdrop (matches Blizzard's DialogBorderTranslucentTemplate style)
Dialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
Dialog:SetBackdropColor(0.09, 0.09, 0.09, 0.95)

-- Drag handlers
Dialog:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

Dialog:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-------------------------------------------------
-- TITLE
-------------------------------------------------
Dialog.Title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
Dialog.Title:SetPoint("TOP", Dialog, "TOP", 0, -15)
Dialog.Title:SetText("Orbit Settings")

-------------------------------------------------
-- CLOSE BUTTON
-------------------------------------------------
Dialog.CloseButton = CreateFrame("Button", nil, Dialog, "UIPanelCloseButton")
Dialog.CloseButton:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", -2, -2)
Dialog.CloseButton:SetScript("OnClick", function()
    Dialog:Hide()
end)

-------------------------------------------------
-- ESC KEY SUPPORT
-------------------------------------------------
table.insert(UISpecialFrames, "OrbitSettingsDialog")

-- Keyboard handling for ESC
Dialog:SetPropagateKeyboardInput(true)
Dialog:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        if InCombatLockdown() then
            return
        end
        self:SetPropagateKeyboardInput(false)
        self:Hide()
        -- Restore propagation
        C_Timer.After(0.05, function()
            if not InCombatLockdown() then
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end
end)

-------------------------------------------------
-- ATTACHED SYSTEM TRACKING
-------------------------------------------------
Dialog.attachedToSystem = nil
Dialog.attachedPlugin = nil
Dialog.attachedSystemIndex = nil

-------------------------------------------------
-- CORE API: UpdateDialog
-------------------------------------------------
-- Matches Blizzard API pattern for easy migration
-- context = { system = pluginName, systemIndex = index, systemFrame = frame }
function Dialog:UpdateDialog(context)
    if not context then
        return
    end

    local systemFrame = context.systemFrame
    local pluginName = context.system
    local systemIndex = context.systemIndex or 1

    -- Look up plugin
    local plugin = Orbit:GetPlugin(pluginName)
    if not plugin then
        -- Fallback: try systemFrame.orbitPlugin
        if systemFrame and systemFrame.orbitPlugin then
            plugin = systemFrame.orbitPlugin
        end
    end

    if not plugin then
        return
    end

    -- Store references
    self.attachedToSystem = systemFrame
    self.attachedPlugin = plugin
    self.attachedSystemIndex = systemIndex

    -- STATE CLEANUP: Hide Orbit Options specific elements (tabs/divider)
    -- These will be re-shown by OrbitOptionsPanel:Open() if needed
    if self.OrbitTabs then
        for _, tab in ipairs(self.OrbitTabs) do
            tab:Hide()
        end
    end
    if self.OrbitHeaderDivider then
        self.OrbitHeaderDivider:Hide()
    end

    -- Update title
    local title = plugin.name
    if systemFrame and systemFrame.editModeName then
        title = systemFrame.editModeName
    end
    self.Title:SetText(title)

    -- Build mock systemFrame for Config:Render
    local renderContext = {
        system = pluginName,
        systemIndex = systemIndex,
        systemFrame = systemFrame,
    }

    -- Call plugin's AddSettings to populate the dialog
    if plugin.AddSettings then
        plugin:AddSettings(self, renderContext)
    end
end

-------------------------------------------------
-- SHOW/HIDE HANDLERS
-------------------------------------------------
Dialog:SetScript("OnShow", function(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)

    -- Mutual Exclusion: Ensure native dialog is hidden
    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end
end)

Dialog:SetScript("OnHide", function(self)
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

    -- Clear attachment state
    self.attachedToSystem = nil
    self.attachedPlugin = nil
    self.attachedSystemIndex = nil

    -- Notify selection system
    if OrbitEngine.FrameSelection then
        OrbitEngine.FrameSelection:DeselectAll()
    end
end)

-------------------------------------------------
-- POSITION HELPER
-------------------------------------------------
function Dialog:PositionNearButton()
    if Orbit.OptionsButton then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", Orbit.OptionsButton, "BOTTOMLEFT", -2, -10)
    end
end

-------------------------------------------------
-- INTEGRATION: Hide when native frame is selected
-------------------------------------------------
-- Called from NativeHook when Blizzard's EditModeManagerFrame:SelectSystem is triggered
function Dialog:OnNativeFrameSelected()
    self:Hide()
end

-------------------------------------------------
-- EDIT MODE LIFECYCLE
-------------------------------------------------
-- Hide dialog when Edit Mode exits
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", function()
        Dialog:Hide()
    end)
end

-------------------------------------------------
-- EXPORT
-------------------------------------------------
Orbit.SettingsDialog = Dialog
