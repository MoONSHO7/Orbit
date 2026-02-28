---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local MasqueBridge = Orbit.Skin and Orbit.Skin.Masque
local ABC = Orbit.ActionBarsContainer
local ABText = Orbit.ActionBarsText
local ABPreview = Orbit.ActionBarsPreview

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local BUTTON_SIZE = 36
local PET_BAR_INDEX = 9
local STANCE_BAR_INDEX = 10
local POSSESS_BAR_INDEX = 11
local MIN_STANCE_ICONS = 2
local VEHICLE_EXIT_INDEX = 13
local VEHICLE_EXIT_VISIBILITY = "[canexitvehicle] show; hide"

local BASE_VISIBILITY_DRIVER = "[petbattle][vehicleui] hide; show"
local PET_BAR_BASE_DRIVER = "[petbattle][vehicleui] hide; [nopet] hide; show"
local BAR1_BASE_DRIVER = "[petbattle][overridebar] hide; show"

local function GetVisibilityDriver(baseDriver)
    return Orbit.MountedVisibility:GetMountedDriver(baseDriver)
end

local SPECIAL_BAR_INDICES = { [STANCE_BAR_INDEX] = true, [POSSESS_BAR_INDEX] = true }
local DROPPABLE_CURSOR_TYPES = { spell = true, petaction = true, flyout = true, item = true, macro = true, mount = true }

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local BAR_CONFIG = {
    { blizzName = "MainActionBar", orbitName = "OrbitActionBar1", label = "Action Bar 1", index = 1, buttonPrefix = "ActionButton", count = 12 },
    { blizzName = "MultiBarBottomLeft", orbitName = "OrbitActionBar2", label = "Action Bar 2", index = 2, buttonPrefix = "MultiBarBottomLeftButton", count = 12 },
    { blizzName = "MultiBarBottomRight", orbitName = "OrbitActionBar3", label = "Action Bar 3", index = 3, buttonPrefix = "MultiBarBottomRightButton", count = 12 },
    { blizzName = "MultiBarRight", orbitName = "OrbitActionBar4", label = "Action Bar 4", index = 4, buttonPrefix = "MultiBarRightButton", count = 12 },
    { blizzName = "MultiBarLeft", orbitName = "OrbitActionBar5", label = "Action Bar 5", index = 5, buttonPrefix = "MultiBarLeftButton", count = 12 },
    { blizzName = "MultiBar5", orbitName = "OrbitActionBar6", label = "Action Bar 6", index = 6, buttonPrefix = "MultiBar5Button", count = 12 },
    { blizzName = "MultiBar6", orbitName = "OrbitActionBar7", label = "Action Bar 7", index = 7, buttonPrefix = "MultiBar6Button", count = 12 },
    { blizzName = "MultiBar7", orbitName = "OrbitActionBar8", label = "Action Bar 8", index = 8, buttonPrefix = "MultiBar7Button", count = 12 },
    { blizzName = "PetActionBar", orbitName = "OrbitPetBar", label = "Pet Bar", index = 9, buttonPrefix = "PetActionButton", count = 10 },
    { blizzName = "StanceBar", orbitName = "OrbitStanceBar", label = "Stance Bar", index = 10, buttonPrefix = "StanceButton", count = 10, isSpecial = true },
    { blizzName = "PossessBarFrame", orbitName = "OrbitPossessBar", label = "Possess Bar", index = 11, buttonPrefix = "PossessButton", count = 2, isSpecial = true },
}

local Plugin = Orbit:RegisterPlugin("Action Bars", "Orbit_ActionBars", {
    defaults = {
        Orientation = 0, Scale = 90, IconPadding = 2, Rows = 1, NumIcons = 12,
        Opacity = 100, HideEmptyButtons = false, UseGlobalTextStyle = true,
        DisabledComponents = {},
        ComponentPositions = {}, GlobalComponentPositions = {
            Keybind = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2, justifyH = "RIGHT" },
            MacroText = { anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 2, justifyH = "CENTER" },
            Timer = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0, justifyH = "CENTER" },
            Stacks = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2, justifyH = "LEFT" },
        },
        GlobalDisabledComponents = {},
        OutOfCombatFade = false, ShowOnMouseover = true,
        KeypressColor = { r = 1, g = 1, b = 1, a = 0.6 },
        BackdropColour = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 },
    },
})

Plugin.canvasMode = true
Plugin.supportsGlobalSync = true
Mixin(Plugin, Orbit.NativeBarMixin)
Plugin.containers = {}
Plugin.buttons = {}
Plugin.blizzBars = {}
Plugin.gridCache = {}

-- [ HELPERS ]------------------------------------------------------------------------------------
local function EnsureHiddenFrame()
    if not Orbit.ButtonHideFrame then
        Orbit.ButtonHideFrame = CreateFrame("Frame")
        Orbit.ButtonHideFrame:Hide()
        Orbit.ButtonHideFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
    end
    return Orbit.ButtonHideFrame
end

-- [ SETTINGS UI ]--------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or 1
    local SB = OrbitEngine.SchemaBuilder
    local container = self.containers[systemIndex]
    local schema = { hideNativeSettings = true, controls = {} }
    if systemIndex == 1 then
        schema.multiFrameOverride = {}
        for _, config in ipairs(BAR_CONFIG) do
            if self.containers[config.index] then table.insert(schema.multiFrameOverride, self.containers[config.index]) end
        end
    end
    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local tabs = (systemIndex == 1) and { "Layout", "Colors", "Visibility" } or { "Layout", "Visibility" }
    local currentTab = SB:AddSettingsTabs(schema, dialog, tabs, "Layout")
    if currentTab == "Layout" then
        if systemIndex == 1 then
            table.insert(schema.controls, { type = "slider", key = "NumActionBars", label = "|cFFFFD100# Action Bars|r", min = 1, max = 8, step = 1, default = 4, isGlobal = true,
                onChange = function(val)
                    self:SetSetting(1, "NumActionBars", val)
                    for index, cont in pairs(self.containers) do
                        if index <= 8 then self:ApplySettings(cont) end
                    end
                end })
        end
        local config = BAR_CONFIG[systemIndex]
        local isSpecialBar = config.isSpecial or SPECIAL_BAR_INDICES[systemIndex]
        if config and config.count > 1 and not isSpecialBar then
            table.insert(schema.controls, { type = "slider", key = "NumIcons", label = "# Icons", min = 1, max = config.count, step = 1, default = config.count,
                onChange = function(val)
                    self:SetSetting(systemIndex, "NumIcons", val)
                    self:ApplySettings(container)
                end })
        end
        table.insert(schema.controls, { type = "slider", key = "Orientation", label = "Orientation", min = 0, max = 1, step = 1, default = 0, formatter = function(v) return v == 0 and "Horizontal" or "Vertical" end })
        local numIcons = self:GetSetting(systemIndex, "NumIcons") or (config and config.count or 12)
        local factors = {}
        for i = 1, numIcons do if numIcons % i == 0 then table.insert(factors, i) end end
        local currentRows = self:GetSetting(systemIndex, "Rows") or 1
        local currentIndex = 1
        for i, v in ipairs(factors) do if v == currentRows then currentIndex = i; break end end
        if #factors > 1 then
            table.insert(schema.controls, { type = "slider", key = "_RowsSlider", label = "Rows", min = 1, max = #factors, step = 1, default = currentIndex,
                formatter = function(v) return tostring(factors[math.floor(v)] or 1) end,
                onChange = function(val)
                    local newRows = factors[math.floor(val)] or 1
                    if newRows ~= self:GetSetting(systemIndex, "Rows") then
                        self:SetSetting(systemIndex, "Rows", newRows)
                        if container then self:ApplySettings(container) end
                    end
                end })
        end
        local isForcedHideEmpty = SPECIAL_BAR_INDICES[systemIndex]
        if not isForcedHideEmpty then table.insert(schema.controls, { type = "checkbox", key = "HideEmptyButtons", label = "Hide Empty Buttons", default = false }) end
    elseif currentTab == "Colors" then
        local DEFAULT_BACKDROP = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }
        local DEFAULT_KEYPRESS = { r = 1, g = 1, b = 1, a = 0.6 }
        local function ColorToCurve(c) return { pins = { { position = 0, color = { r = c.r, g = c.g, b = c.b, a = c.a or 1 } } } } end
        local function CurveToColor(curve)
            if curve and curve.pins and curve.pins[1] then return curve.pins[1].color end
        end
        table.insert(schema.controls, { type = "colorcurve", key = "BackdropColour", label = "Backdrop Colour", singleColor = true,
            default = ColorToCurve(DEFAULT_BACKDROP),
            onChange = function(val)
                Orbit.db.GlobalSettings.BackdropColour = CurveToColor(val) or DEFAULT_BACKDROP
                self:ApplyAll()
            end })
        table.insert(schema.controls, { type = "colorcurve", key = "KeypressColor", label = "Keypress Flash", singleColor = true,
            default = ColorToCurve(DEFAULT_KEYPRESS),
            onChange = function(val)
                self:SetSetting(1, "KeypressColor", CurveToColor(val) or DEFAULT_KEYPRESS)
                self:ApplyAll()
            end })
    elseif currentTab == "Visibility" then
        SB:AddOpacitySettings(self, schema, systemIndex, systemFrame)
        table.insert(schema.controls, { type = "checkbox", key = "OutOfCombatFade", label = "Out of Combat Fade", default = false,
            onChange = function(val) self:SetSetting(systemIndex, "OutOfCombatFade", val); self:ApplySettings(container) end })
        if self:GetSetting(systemIndex, "OutOfCombatFade") then
            table.insert(schema.controls, { type = "checkbox", key = "ShowOnMouseover", label = "Show on Mouseover", default = true,
                onChange = function(val) self:SetSetting(systemIndex, "ShowOnMouseover", val); self:ApplySettings(container) end })
        end
    end
    schema.extraButtons = { { text = "Quick Keybind", callback = function()
        if EditModeManagerFrame and EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
        if QuickKeybindFrame then QuickKeybindFrame:Show() end
    end } }
    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]----------------------------------------------------------------------------------
function Plugin:OnLoad()
    self:InitializeContainers()
    ABC:CreateVehicleExit(self)
    for index, container in pairs(self.containers) do ABPreview:Setup(self, container, index) end
    for index, container in pairs(self.containers) do
        self:ReparentButtons(index)
        OrbitEngine.Frame:RestorePosition(container, self, index)
        self:LayoutButtons(index)
        if MasqueBridge then
            local config = BAR_CONFIG[index]
            if config then
                local groupName = config.label
                MasqueBridge:OnGroupSkinChange(groupName, function()
                    local isDisabled = false
                    if MasqueBridge.IsGroupEnabled then isDisabled = not MasqueBridge:IsGroupEnabled(groupName) end
                    for _, btn in ipairs(self.buttons[index] or {}) do
                        if isDisabled then Orbit.Skin.ActionButtonSkin:Apply(btn, { style = 1, aspectRatio = "1:1", zoom = 8, borderStyle = 1, borderSize = Orbit.db.GlobalSettings.BorderSize }) end
                    end
                    if not isDisabled then MasqueBridge:ReSkinGroup(groupName) end
                    self:ApplySettings(container)
                end)
            end
        end
    end
    self.UpdateVisibilityDriver = function()
        if InCombatLockdown() then return end
        local druidFormHide = Orbit.MountedVisibility:ShouldHide() and not IsMounted()
        for index, container in pairs(self.containers) do
            if index ~= PET_BAR_INDEX and index ~= VEHICLE_EXIT_INDEX then
                if druidFormHide then RegisterStateDriver(container, "visibility", "hide")
                elseif index == 1 then RegisterStateDriver(container, "visibility", BAR1_BASE_DRIVER)
                else RegisterStateDriver(container, "visibility", GetVisibilityDriver(BASE_VISIBILITY_DRIVER)) end
            end
        end
    end
    Orbit.EventBus:On("PLAYER_REGEN_ENABLED", self.OnCombatEnd, self)
    Orbit.EventBus:On("UPDATE_MULTI_CAST_ACTIONBAR", function() C_Timer.After(0.1, function() self:ApplyAll() end) end, self)
    hooksecurefunc("ActionButton_UpdateRangeIndicator", function(btn, checksRange, inRange)
        if not btn or not btn.icon then return end
        btn.orbitOutOfRange = checksRange and not inRange
        if btn.orbitOutOfRange then btn.icon:SetVertexColor(1, 0.2, 0.2) else btn.icon:SetVertexColor(1, 1, 1) end
    end)
    local function HideFlyoutBackground()
        local bg = SpellFlyoutBackgroundEnd
        if not bg then return end
        if bg.End then bg.End:Hide() end
        if bg.Start then bg.Start:Hide() end
        if bg.VerticalMiddle then bg.VerticalMiddle:Hide() end
        if bg.HorizontalMiddle then bg.HorizontalMiddle:Hide() end
    end
    local function SkinFlyoutButtons()
        HideFlyoutBackground()
        local flyout = SpellFlyout
        if not flyout or not flyout:IsShown() then return end
        if InCombatLockdown() then self.flyoutSkinPending = true; return end
        self.flyoutSkinPending = false
        local skinSettings = { style = 1, aspectRatio = "1:1", zoom = 8, borderStyle = 1, borderSize = Orbit.db.GlobalSettings.BorderSize, swipeColor = { r = 0, g = 0, b = 0, a = 0.8 }, showTimer = true, hideName = false, backdropColor = self:GetSetting(1, "BackdropColour"), keypressColor = self:GetSetting(1, "KeypressColor") or { r = 1, g = 1, b = 1, a = 0.6 } }
        local i = 1
        while true do
            local btn = _G["SpellFlyoutButton" .. i]
            if not btn then break end
            btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
            Orbit.Skin.ActionButtonSkin:Apply(btn, skinSettings)
            i = i + 1
        end
    end
    if SpellFlyout then
        SpellFlyout:HookScript("OnShow", SkinFlyoutButtons)
        hooksecurefunc(SpellFlyout, "UpdateBackground", HideFlyoutBackground)
    end
    Orbit.EventBus:On("PLAYER_REGEN_ENABLED", function() if self.flyoutSkinPending then SkinFlyoutButtons() end end, self)
    Orbit.EventBus:On("CURSOR_CHANGED", function()
        local cursorType = GetCursorInfo()
        local isDraggingDroppable = DROPPABLE_CURSOR_TYPES[cursorType]
        local wasDragging = self.isDraggingDroppable
        if isDraggingDroppable then self.isDraggingDroppable = true
        elseif wasDragging then self.isDraggingDroppable = false end
        if self.cursorTimer then self.cursorTimer:Cancel() end
        self.cursorTimer = C_Timer.NewTimer(0.05, function() if not InCombatLockdown() then self:ApplyAll() end end)
    end, self)
end

-- [ EDIT MODE NUM ICONS PATCH ]------------------------------------------------------------------
StaticPopupDialogs["ORBIT_ACTIONBARS_RELOAD"] = { text = "Action bar icon count changed. A reload is required.", button1 = "Reload", button2 = "Later", OnAccept = function() ReloadUI() end, timeout = 0, whileDead = true, hideOnEscape = true }

Orbit.EventBus:On("EDIT_MODE_LAYOUTS_UPDATED", function()
    local layoutInfo = C_EditMode.GetLayouts()
    if not layoutInfo then return end
    local dirty = false
    for _, layout in ipairs(layoutInfo.layouts) do
        if not layout.systems then break end
        for _, sys in ipairs(layout.systems) do
            if sys.system == Enum.EditModeSystem.ActionBar then
                for _, s in ipairs(sys.settings) do
                    if s.setting == Enum.EditModeActionBarSetting.NumIcons and s.value < 12 then s.value = 12; dirty = true end
                end
            end
        end
    end
    if not dirty then return end
    C_EditMode.SaveLayouts(layoutInfo)
    StaticPopup_Show("ORBIT_ACTIONBARS_RELOAD")
end, Plugin)

-- [ FACADE DELEGATES ]--------------------------------------------------------------------------
function Plugin:InitializeContainers()
    for _, config in ipairs(BAR_CONFIG) do
        if not self.containers[config.index] then self.containers[config.index] = ABC:Create(self, config) end
    end
end

function Plugin:ReparentAllButtons()
    if InCombatLockdown() then return end
    for _, config in ipairs(BAR_CONFIG) do ABC:ReparentButtons(self, config.index, BAR_CONFIG) end
end

function Plugin:ReparentButtons(index) ABC:ReparentButtons(self, index, BAR_CONFIG) end
function Plugin:SetupCanvasPreview(container, systemIndex) ABPreview:Setup(self, container, systemIndex) end
function Plugin:ApplyTextSettings(button, systemIndex) ABText:Apply(self, button, systemIndex) end

function Plugin:IsComponentDisabled(componentKey, systemIndex)
    systemIndex = systemIndex or 1
    local disabled = self:GetSetting(systemIndex, "DisabledComponents") or {}
    for _, key in ipairs(disabled) do if key == componentKey then return true end end
    return false
end

function Plugin:OnCombatEnd() C_Timer.After(0.5, function() self:ApplyAll() end) end

-- [ BUTTON LAYOUT AND SKINNING ]-----------------------------------------------------------------
function Plugin:LayoutButtons(index)
    if InCombatLockdown() then return end
    local container = self.containers[index]
    local buttons = self.buttons[index]
    if container and container.orbitDisabled then return end
    if not container or not buttons or #buttons == 0 then return end
    local padding = self:GetSetting(index, "IconPadding") or 2
    local rows = self:GetSetting(index, "Rows") or 1
    local orientation = self:GetSetting(index, "Orientation") or 0
    local hideEmpty = self:GetSetting(index, "HideEmptyButtons")
    if SPECIAL_BAR_INDICES[index] then hideEmpty = true end
    local cursorType = GetCursorInfo()
    local cursorOverridesHide = DROPPABLE_CURSOR_TYPES[cursorType]
    if cursorOverridesHide and not SPECIAL_BAR_INDICES[index] then hideEmpty = false end
    local config = BAR_CONFIG[index]
    local numIcons = self:GetSetting(index, "NumIcons") or (config and config.count or 12)
    local w, h = BUTTON_SIZE, BUTTON_SIZE
    local useMasque = MasqueBridge and MasqueBridge.enabled
    local masqueGroup = useMasque and (config and config.label or "Action Bar " .. index)
    local skinSettings = { style = 1, aspectRatio = "1:1", zoom = 8, borderStyle = 1, borderSize = Orbit.db.GlobalSettings.BorderSize, swipeColor = { r = 0, g = 0, b = 0, a = 0.8 }, showTimer = true, hideName = false, backdropColor = self:GetSetting(1, "BackdropColour"), keypressColor = self:GetSetting(1, "KeypressColor") or { r = 1, g = 1, b = 1, a = 0.6 } }
    local totalEffective = math.min(#buttons, numIcons)
    local limitPerLine
    if orientation == 0 then limitPerLine = math.max(1, math.ceil(totalEffective / rows))
    else limitPerLine = rows end
    local cacheKey = string.format("%d_%d_%d_%d_%d", numIcons, limitPerLine, orientation, w, padding)
    local cache = self.gridCache[index]
    if not cache or cache.key ~= cacheKey then
        local positions = {}
        local scale = buttons[1] and buttons[1]:GetEffectiveScale() or 1
        for i = 1, numIcons do
            local x, y = OrbitEngine.Layout:ComputeGridPosition(i, limitPerLine, orientation, w, h, padding)
            x = OrbitEngine.Pixel:Snap(x, scale); y = OrbitEngine.Pixel:Snap(y, scale)
            positions[i] = { x = x, y = y }
        end
        self.gridCache[index] = { key = cacheKey, positions = positions }
        cache = self.gridCache[index]
    end
    local cachedPositions = cache.positions
    for i, button in ipairs(buttons) do
        if i > numIcons then
            if not InCombatLockdown() then button:SetParent(EnsureHiddenFrame()); button:Hide() end
            button.orbitHidden = true
        else
            local hasAction = button.HasAction and button:HasAction() or false
            local shouldShow = not (hideEmpty and not hasAction)
            if not shouldShow then
                if not InCombatLockdown() then button:SetParent(EnsureHiddenFrame()); button:Hide() end
                button.orbitHidden = true
                if button.orbitBackdrop then button.orbitBackdrop:Hide() end
            else
                if button.orbitHidden and not InCombatLockdown() then button:SetParent(container) end
                button.orbitHidden = false; button:Show(); button:SetSize(w, h)
                if useMasque then MasqueBridge:AddActionButton(masqueGroup, button) end
                if not useMasque or not MasqueBridge:IsGroupEnabled(masqueGroup) then Orbit.Skin.ActionButtonSkin:Apply(button, skinSettings) end
                ABText:Apply(self, button, index)
                button:ClearAllPoints()
                local pos = cachedPositions[i]
                button:SetPoint("TOPLEFT", container, "TOPLEFT", pos.x, pos.y)
            end
        end
    end
    local sizeCount = totalEffective
    if index == STANCE_BAR_INDEX then
        local visibleCount = 0
        for i = 1, totalEffective do if buttons[i] and not buttons[i].orbitHidden then visibleCount = visibleCount + 1 end end
        sizeCount = math.max(visibleCount, MIN_STANCE_ICONS)
    end
    local sizeLimitPerLine = (orientation == 0) and math.max(1, math.ceil(sizeCount / rows)) or rows
    local finalW, finalH = OrbitEngine.Layout:ComputeGridContainerSize(sizeCount, sizeLimitPerLine, orientation, w, h, padding)
    container:SetSize(finalW, finalH)
    container.orbitRowHeight, container.orbitColumnWidth = h, w
end

-- [ SETTINGS APPLICATION ]-----------------------------------------------------------------------
function Plugin:ApplyAll()
    for index, container in pairs(self.containers) do self:ApplySettings(container) end
end

function Plugin:ApplySettings(frame)
    if not frame then self:ApplyAll(); return end
    if InCombatLockdown() then return end
    local actualFrame = frame.systemFrame or frame
    local index = frame.systemIndex or actualFrame.systemIndex
    if not index or not actualFrame then return end
    if index == VEHICLE_EXIT_INDEX then
        if Orbit:IsEditMode() then UnregisterStateDriver(actualFrame, "visibility"); actualFrame:Show()
        else RegisterStateDriver(actualFrame, "visibility", VEHICLE_EXIT_VISIBILITY) end
        self:ApplyScale(actualFrame, index, "Scale")
        OrbitEngine.Frame:RestorePosition(actualFrame, self, index)
        return
    end
    local enabled = true
    if index <= 8 then
        local numBars = self:GetSetting(1, "NumActionBars") or 4
        if index > numBars then enabled = false end
    end
    if not self.blizzBars[index] then local config = BAR_CONFIG[index]; if config then self.blizzBars[index] = _G[config.blizzName] end end
    local blizzBar = self.blizzBars[index]
    if blizzBar then OrbitEngine.NativeFrame:Protect(blizzBar) end
    if enabled == false then
        UnregisterStateDriver(actualFrame, "visibility")
        if blizzBar then OrbitEngine.NativeFrame:SecureHide(blizzBar) end
        local point, _, _, x, y = actualFrame:GetPoint(1)
        if point then self:SetSetting(index, "Position", { point = point, x = x, y = y }) end
        local buttons = self.buttons[index]
        if buttons and #buttons > 0 then
            local hiddenFrame = EnsureHiddenFrame()
            for _, button in ipairs(buttons) do button:SetParent(hiddenFrame); button:Hide(); button.orbitHidden = true end
        end
        actualFrame:Hide()
        OrbitEngine.FrameAnchor:SetFrameDisabled(actualFrame, true)
        return
    end
    OrbitEngine.FrameAnchor:SetFrameDisabled(actualFrame, false)
    if index ~= 1 then RegisterStateDriver(actualFrame, "visibility", GetVisibilityDriver(BASE_VISIBILITY_DRIVER)) end
    if not self.buttons[index] or #self.buttons[index] == 0 then self:ReparentButtons(index) end
    self:ApplyScale(actualFrame, index, "Scale")
    if index ~= PET_BAR_INDEX then
        local enableHover = self:GetSetting(index, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(actualFrame, self, index, "OutOfCombatFade", enableHover)
    end
    self:ApplyMouseOver(actualFrame, index)
    self:LayoutButtons(index)
    OrbitEngine.Frame:RestorePosition(actualFrame, self, index)
    if self.buttons[index] then
        local direction = "UP"
        if actualFrame.GetSpellFlyoutDirection then direction = actualFrame:GetSpellFlyoutDirection() end
        for _, button in ipairs(self.buttons[index]) do
            if not InCombatLockdown() then button:SetAttribute("flyoutDirection", direction) end
            if button.SetPopupDirection then button:SetPopupDirection(direction) end
            if button.UpdateFlyout then button:UpdateFlyout() end
        end
    end
    actualFrame:Show()
end

function Plugin:GetFrameBySystemIndex(systemIndex) return self.containers[systemIndex] end
