-- [ ORBIT SETTINGS DIALOG ]-------------------------------------------------------------------------

local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local L = Orbit.L

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

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

-- [ CREATE DIALOG FRAME ]---------------------------------------------------------------------------

local Dialog = CreateFrame("Frame", "OrbitSettingsDialog", UIParent)
Dialog:SetSize(DIALOG_WIDTH, DIALOG_MIN_HEIGHT)
Dialog:SetPoint("TOPLEFT", UIParent, "TOPLEFT", INITIAL_X, INITIAL_Y)
Dialog:SetFrameStrata(Orbit.Constants.Strata.Dialog)
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
    self.hasAutoPositionedNearButton = true
end)

Dialog:RegisterEvent("PLAYER_REGEN_DISABLED")
Dialog:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then self:Hide() end
end)

-- [ TITLE ]-----------------------------------------------------------------------------------------

Dialog.Title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
Dialog.Title:SetPoint("TOP", Dialog, "TOP", 0, -15)
Dialog.Title:SetText(L.CFG_ORBIT_SETTINGS)

-- [ CLOSE BUTTON ]----------------------------------------------------------------------------------

Dialog.CloseButton = CreateFrame("Button", nil, Dialog, "UIPanelCloseButton")
Dialog.CloseButton:SetPoint("TOPRIGHT", Dialog, "TOPRIGHT", CLOSE_BUTTON_OFFSET, CLOSE_BUTTON_OFFSET)
Dialog.CloseButton:SetScript("OnClick", function() Dialog:Hide() end)

-- [ ESC KEY SUPPORT ]-------------------------------------------------------------------------------

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

-- [ ATTACHED SYSTEM TRACKING ]----------------------------------------------------------------------

Dialog.attachedToSystem = nil
Dialog.attachedPlugin = nil
Dialog.attachedSystemIndex = nil
Dialog.hasAutoPositionedNearButton = false

-- [ CORE API: UpdateDialog ]------------------------------------------------------------------------

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

    if plugin ~= self.attachedPlugin then
        self.orbitCurrentTab = nil
        -- Stop preview animations from previous plugin
        if self.attachedPlugin and Orbit.PreviewAnimator then
            Orbit.PreviewAnimator:ExitAll(self.attachedPlugin)
        end
        self.orbitEyeToggle = nil
    end

    self.attachedToSystem = systemFrame
    self.attachedPlugin = plugin
    self.attachedSystemIndex = systemIndex
    self.attachedGroupFrames = nil

    local title = plugin.name
    if systemFrame and systemFrame.editModeName then title = systemFrame.editModeName end
    self.Title:SetText(title)

    local renderContext = { system = pluginName, systemIndex = systemIndex, systemFrame = systemFrame }

    if plugin.AddSettings then plugin:AddSettings(self, renderContext) end
end

function Dialog:UpdateGroupDialog(plugin, selectedFrames)
    if InCombatLockdown() then return end
    if not plugin or not selectedFrames then return end
    if plugin ~= self.attachedPlugin then
        self.orbitCurrentTab = nil
        if self.attachedPlugin and Orbit.PreviewAnimator then
            Orbit.PreviewAnimator:ExitAll(self.attachedPlugin)
        end
        self.orbitEyeToggle = nil
    end
    self.attachedPlugin = plugin
    self.attachedToSystem = nil
    self.attachedSystemIndex = nil
    self.attachedGroupFrames = selectedFrames
    self.Title:SetText(L.CFG_SETTINGS_GROUP_F:format(plugin.name or L.CFG_SETTINGS_FALLBACK))
    -- Collect sorted frames
    local frames = {}
    for frame in pairs(selectedFrames) do
        if frame.systemIndex then table.insert(frames, frame) end
    end
    table.sort(frames, function(a, b) return a.systemIndex < b.systemIndex end)
    if #frames == 0 then return end
    -- Capture schemas by intercepting Config:Render
    local Config = OrbitEngine.Config
    local capturedSchemas = {}
    local origRender = Config.Render
    Config.Render = function(_, dlg, sf, plg, schema)
        table.insert(capturedSchemas, schema)
    end
    for _, frame in ipairs(frames) do
        plugin:AddSettings(self, { systemIndex = frame.systemIndex, systemFrame = frame })
    end
    Config.Render = origRender
    if #capturedSchemas == 0 then return end
    -- Index controls by key for each schema
    local keySets = {}
    for i, schema in ipairs(capturedSchemas) do
        keySets[i] = {}
        for _, ctrl in ipairs(schema.controls or {}) do
            if ctrl.key then keySets[i][ctrl.key] = ctrl end
        end
    end
    -- Intersect tabs
    local firstSchema = capturedSchemas[1]
    local commonTabs
    for _, ctrl in ipairs(firstSchema.controls or {}) do
        if ctrl.type == "tabs" then
            commonTabs = {}
            for _, tabName in ipairs(ctrl.tabs) do
                local inAll = true
                for i = 2, #capturedSchemas do
                    local found = false
                    for _, c in ipairs(capturedSchemas[i].controls or {}) do
                        if c.type == "tabs" then
                            for _, t in ipairs(c.tabs) do
                                if t == tabName then found = true; break end
                            end
                            break
                        end
                    end
                    if not found then inAll = false; break end
                end
                if inAll then table.insert(commonTabs, tabName) end
            end
            break
        end
    end
    -- Build merged schema
    local merged = { hideNativeSettings = true, hideResetButton = true, controls = {} }
    for _, ctrl in ipairs(firstSchema.controls or {}) do
        if ctrl.type == "tabs" and commonTabs then
            table.insert(merged.controls, {
                type = "tabs", tabs = commonTabs, activeTab = self.orbitCurrentTab,
                onTabSelected = function(tabName)
                    self.orbitCurrentTab = tabName
                    if self.orbitTabCallback then self.orbitTabCallback() end
                end,
            })
        elseif ctrl.key then
            local inAll = true
            for i = 2, #capturedSchemas do
                if not keySets[i][ctrl.key] then inAll = false; break end
            end
            if inAll then
                local groupCtrl = {}
                for k, v in pairs(ctrl) do groupCtrl[k] = v end
                local key = ctrl.key
                groupCtrl.onChange = function(val)
                    for i, frame in ipairs(frames) do
                        local c = keySets[i][key]
                        if c and c.onChange then
                            c.onChange(val)
                        else
                            plugin:SetSetting(frame.systemIndex, key, val)
                            if plugin.ApplySettings then plugin:ApplySettings(frame) end
                        end
                    end
                end
                table.insert(merged.controls, groupCtrl)
            end
        end
    end
    merged.extraButtons = firstSchema.extraButtons
    -- Tab refresh for group mode
    self.orbitTabCallback = function()
        OrbitEngine.Layout:Reset(self)
        self:UpdateGroupDialog(plugin, selectedFrames)
    end
    Config:Render(self, { systemIndex = frames[1].systemIndex, systemFrame = frames[1] }, plugin, merged)
end

-- [ SHOW/HIDE HANDLERS ]----------------------------------------------------------------------------

Dialog:SetScript("OnShow", function(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end
end)

Dialog:SetScript("OnHide", function(self)
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    -- Stop preview animations
    if self.attachedPlugin and Orbit.PreviewAnimator then
        Orbit.PreviewAnimator:ExitAll(self.attachedPlugin)
    end
    self.orbitEyeToggle = nil
    self.attachedToSystem = nil
    self.attachedPlugin = nil
    self.attachedSystemIndex = nil
    self.attachedGroupFrames = nil
    OrbitEngine.FrameSelection:DeselectAll()
end)

-- [ POSITION HELPER ]-------------------------------------------------------------------------------

function Dialog:PositionNearButton()
    if not self.hasAutoPositionedNearButton and Orbit.OptionsButton then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", Orbit.OptionsButton, "BOTTOMLEFT", OPTIONS_BUTTON_OFFSET_X, OPTIONS_BUTTON_OFFSET_Y)
        self.hasAutoPositionedNearButton = true
    end
end

-- [ INTEGRATION ]-----------------------------------------------------------------------------------

function Dialog:OnNativeFrameSelected() self:Hide() end

-- [ EDIT MODE LIFECYCLE ]---------------------------------------------------------------------------

if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", function()
        Dialog.hasAutoPositionedNearButton = false
        Dialog:Hide()
    end)
end

-- [ EXPORT ]----------------------------------------------------------------------------------------

Orbit.SettingsDialog = Dialog
