---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local MasqueBridge = Orbit.Skin and Orbit.Skin.Masque

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local BUTTON_SIZE = 36
local INITIAL_FRAME_SIZE = 40
local PET_BAR_INDEX = 9
local STANCE_BAR_INDEX = 10
local POSSESS_BAR_INDEX = 11
local MIN_STANCE_ICONS = 2
local VEHICLE_EXIT_INDEX = 13
local VEHICLE_EXIT_ICON = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up"
local VEHICLE_EXIT_VISIBILITY = "[canexitvehicle] show; hide"

local BASE_VISIBILITY_DRIVER = "[petbattle][vehicleui] hide; show"
local PET_BAR_BASE_DRIVER = "[petbattle][vehicleui] hide; [nopet] hide; show"
local BAR1_BASE_DRIVER = "[petbattle][overridebar] hide; show"

local function GetVisibilityDriver(baseDriver)
    if Orbit.MountedVisibility then return Orbit.MountedVisibility:GetMountedDriver(baseDriver) end
    return baseDriver
end

local SPECIAL_BAR_INDICES = {
    [STANCE_BAR_INDEX] = true,
    [POSSESS_BAR_INDEX] = true,
}

local DROPPABLE_CURSOR_TYPES = {
    spell = true,
    petaction = true,
    flyout = true,
    item = true,
    macro = true,
    mount = true,
}

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local BAR_CONFIG = {
    -- Standard Action Bars
    {
        blizzName = "MainActionBar",
        orbitName = "OrbitActionBar1",
        label = "Action Bar 1",
        index = 1,
        buttonPrefix = "ActionButton",
        count = 12,
    },
    {
        blizzName = "MultiBarBottomLeft",
        orbitName = "OrbitActionBar2",
        label = "Action Bar 2",
        index = 2,
        buttonPrefix = "MultiBarBottomLeftButton",
        count = 12,
    },
    {
        blizzName = "MultiBarBottomRight",
        orbitName = "OrbitActionBar3",
        label = "Action Bar 3",
        index = 3,
        buttonPrefix = "MultiBarBottomRightButton",
        count = 12,
    },
    {
        blizzName = "MultiBarRight",
        orbitName = "OrbitActionBar4",
        label = "Action Bar 4",
        index = 4,
        buttonPrefix = "MultiBarRightButton",
        count = 12,
    },
    {
        blizzName = "MultiBarLeft",
        orbitName = "OrbitActionBar5",
        label = "Action Bar 5",
        index = 5,
        buttonPrefix = "MultiBarLeftButton",
        count = 12,
    },
    {
        blizzName = "MultiBar5",
        orbitName = "OrbitActionBar6",
        label = "Action Bar 6",
        index = 6,
        buttonPrefix = "MultiBar5Button",
        count = 12,
    },
    {
        blizzName = "MultiBar6",
        orbitName = "OrbitActionBar7",
        label = "Action Bar 7",
        index = 7,
        buttonPrefix = "MultiBar6Button",
        count = 12,
    },
    {
        blizzName = "MultiBar7",
        orbitName = "OrbitActionBar8",
        label = "Action Bar 8",
        index = 8,
        buttonPrefix = "MultiBar7Button",
        count = 12,
    },

    -- Special Bars
    {
        blizzName = "PetActionBar",
        orbitName = "OrbitPetBar",
        label = "Pet Bar",
        index = 9,
        buttonPrefix = "PetActionButton",
        count = 10,
        isSpecial = true,
    },
    {
        blizzName = "StanceBar",
        orbitName = "OrbitStanceBar",
        label = "Stance Bar",
        index = 10,
        buttonPrefix = "StanceButton",
        count = 10,
        isSpecial = true,
    },
    {
        blizzName = "PossessBarFrame",
        orbitName = "OrbitPossessBar",
        label = "Possess Bar",
        index = 11,
        buttonPrefix = "PossessButton",
        count = 2,
        isSpecial = true,
    },
}

local Plugin = Orbit:RegisterPlugin("Action Bars", "Orbit_ActionBars", {
    defaults = {
        Orientation = 0,
        Scale = 90,
        IconPadding = 2,
        Rows = 1,
        NumIcons = 12,
        Opacity = 100,
        HideEmptyButtons = false,
        UseGlobalTextStyle = true,
        DisabledComponents = {},
        ComponentPositions = {
            Keybind = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 1, offsetY = 7, justifyH = "RIGHT" },
            MacroText = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 1, offsetY = 6, justifyH = "LEFT", overrides = { FontSize = 10 } },
            Timer = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0, justifyH = "CENTER" },
            Stacks = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 1, offsetY = 5, justifyH = "RIGHT" },
        },

        GlobalComponentPositions = {
            Keybind = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 1, offsetY = 7, justifyH = "RIGHT" },
            MacroText = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 1, offsetY = 6, justifyH = "LEFT", overrides = { FontSize = 10 } },
            Timer = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0, justifyH = "CENTER" },
            Stacks = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 1, offsetY = 5, justifyH = "RIGHT" },
        },
        GlobalDisabledComponents = {},
        OutOfCombatFade = false,
        ShowOnMouseover = true,
        KeypressColor = { r = 1, g = 1, b = 1, a = 0.6 },
        BackdropColour = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 },
    },
})

Plugin.canvasMode = true

Mixin(Plugin, Orbit.NativeBarMixin)

Plugin.containers = {}
Plugin.buttons = {}
Plugin.blizzBars = {}
Plugin.gridCache = {}

-- [ HELPERS ]------------------------------------------------------------------------------------
local function EnsureHiddenFrame()
    if not Orbit.ButtonHideFrame then
        Orbit.ButtonHideFrame = CreateFrame("Frame", "OrbitButtonHideFrame", UIParent)
        Orbit.ButtonHideFrame:Hide()
        Orbit.ButtonHideFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
    end
    return Orbit.ButtonHideFrame
end

-- [ SETTINGS UI ]--------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic

    local container = self.containers[systemIndex]

    local schema = { hideNativeSettings = true, controls = {} }

    if systemIndex == VEHICLE_EXIT_INDEX then
        WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
            key = "Scale",
            label = "Scale",
            default = 100,
            min = 50,
            max = 150,
        })
        Orbit.Config:Render(dialog, systemFrame, self, schema)
        return
    end

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local tabs = (systemIndex == 1) and { "Layout", "Colors", "Visibility" } or { "Layout", "Visibility" }
    local currentTab = WL:AddSettingsTabs(schema, dialog, tabs, "Layout")

    if currentTab == "Layout" then
        if systemIndex == 1 then
            table.insert(schema.controls, {
                type = "slider",
                key = "NumActionBars",
                label = "|cFFFFD100# Action Bars|r",
                default = 4,
                min = 2,
                max = 8,
                step = 1,
                updateOnRelease = true,
                onChange = function(val)
                    local current = Plugin:GetSetting(1, "NumActionBars") or 4
                    if current == val then
                        return
                    end
                    Plugin:SetSetting(1, "NumActionBars", val)
                    Plugin:ApplyAll()
                end,
            })
        end
        WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
            key = "Scale",
            label = "Scale",
            default = 100,
            min = 50,
            max = 150,
        })
        table.insert(schema.controls, { type = "slider", key = "IconPadding", label = "Padding", min = -1, max = 10, step = 1, default = 2 })

        local config = BAR_CONFIG[systemIndex]
        local isSpecialBar = config.isSpecial or SPECIAL_BAR_INDICES[systemIndex]
        if config and config.count > 1 and not isSpecialBar then
            table.insert(schema.controls, {
                type = "slider",
                key = "NumIcons",
                label = "# Icons",
                min = 1,
                max = config.count,
                step = 1,
                default = config.count,
                onChange = function(val)
                    self:SetSetting(systemIndex, "NumIcons", val)
                    local currentRows = self:GetSetting(systemIndex, "Rows") or 1
                    if val % currentRows ~= 0 then
                        self:SetSetting(systemIndex, "Rows", 1)
                    end
                    if self.refreshTimer then
                        self.refreshTimer:Cancel()
                    end
                    self.refreshTimer = C_Timer.NewTimer(0.2, function()
                        if dialog.orbitTabCallback then
                            dialog.orbitTabCallback()
                        end
                    end)
                    if self.ApplySettings then
                        self:ApplySettings(container)
                    end
                end,
            })
        end
        local numIcons = self:GetSetting(systemIndex, "NumIcons") or (config and config.count or 12)
        local factors = {}
        for i = 1, numIcons do
            if numIcons % i == 0 then
                table.insert(factors, i)
            end
        end
        local currentRows = self:GetSetting(systemIndex, "Rows") or 1
        local currentIndex = 1
        for i, v in ipairs(factors) do
            if v == currentRows then
                currentIndex = i
                break
            end
        end
        if #factors > 1 then
            table.insert(schema.controls, {
                type = "slider",
                key = "Rows_Slider",
                label = "Layout",
                min = 1,
                max = #factors,
                step = 1,
                default = currentIndex,
                formatter = function(v)
                    local rows = factors[v]
                    if not rows then
                        return ""
                    end
                    return rows .. " Row" .. (rows > 1 and "s" or "")
                end,
                onChange = function(val)
                    local rows = factors[val]
                    if rows then
                        self:SetSetting(systemIndex, "Rows", rows)
                        if self.ApplySettings then
                            self:ApplySettings(container)
                        end
                    end
                end,
            })
        end
        local isForcedHideEmpty = SPECIAL_BAR_INDICES[systemIndex]
        if not isForcedHideEmpty then
            table.insert(schema.controls, { type = "checkbox", key = "HideEmptyButtons", label = "Hide Empty Buttons", default = false })
        end
    elseif currentTab == "Colors" then
        local DEFAULT_BACKDROP = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 }
        local DEFAULT_KEYPRESS = { r = 1, g = 1, b = 1, a = 0.6 }
        local function ColorToCurve(c)
            return c and { pins = { { position = 0, color = c } } } or nil
        end
        local function CurveToColor(curve)
            local pin = curve and curve.pins and curve.pins[1]
            return pin and pin.color or nil
        end
        table.insert(schema.controls, {
            type = "colorcurve",
            key = "BackdropColour",
            label = "Backdrop",
            singleColor = true,
            default = { pins = { { position = 0, color = DEFAULT_BACKDROP } } },
            getValue = function() return ColorToCurve(self:GetSetting(1, "BackdropColour")) end,
            onChange = function(val)
                Orbit.db.GlobalSettings.BackdropColour = CurveToColor(val) or DEFAULT_BACKDROP
                self:ApplyAll()
            end,
        })
        table.insert(schema.controls, {
            type = "colorcurve",
            key = "KeypressColor",
            label = "Keypress Flash",
            singleColor = true,
            default = { pins = { { position = 0, color = DEFAULT_KEYPRESS } } },
            getValue = function() return ColorToCurve(self:GetSetting(1, "KeypressColor")) end,
            onChange = function(val)
                self:SetSetting(1, "KeypressColor", CurveToColor(val) or DEFAULT_KEYPRESS)
                self:ApplyAll()
            end,
        })
    elseif currentTab == "Visibility" then
        WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })
        table.insert(schema.controls, {
            type = "checkbox",
            key = "OutOfCombatFade",
            label = "Out of Combat Fade",
            default = false,
            tooltip = "Hide frame when out of combat with no target",
            onChange = function(val)
                self:SetSetting(systemIndex, "OutOfCombatFade", val)
                if Orbit.OOCFadeMixin then
                    Orbit.OOCFadeMixin:RefreshAll()
                end
                if dialog.orbitTabCallback then
                    dialog.orbitTabCallback()
                end
            end,
        })
        if self:GetSetting(systemIndex, "OutOfCombatFade") then
            table.insert(schema.controls, {
                type = "checkbox",
                key = "ShowOnMouseover",
                label = "Show on Mouseover",
                default = true,
                tooltip = "Reveal hidden frame when mousing over it",
                onChange = function(val)
                    self:SetSetting(systemIndex, "ShowOnMouseover", val)
                    self:ApplySettings(container)
                end,
            })
        end
    end

    schema.extraButtons = {
        {
            text = "Quick Keybind",
            callback = function()
                if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
                    HideUIPanel(EditModeManagerFrame)
                end
                if QuickKeybindFrame then
                    QuickKeybindFrame:Show()
                end
            end,
        },
    }

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]----------------------------------------------------------------------------------
function Plugin:OnLoad()
    self:InitializeContainers()
    self:CreateVehicleExitButton()

    for index, container in pairs(self.containers) do
        self:SetupCanvasPreview(container, index)
    end

    -- Need to set blizzard bars to 12 or our bars dissapear into the netherealm
    self:PatchEditModeNumIcons()

    if MasqueBridge and MasqueBridge.enabled then
        for _, config in ipairs(BAR_CONFIG) do
            local groupName = config.label
            local barIndex = config.index
            MasqueBridge:GetGroup(groupName)
            MasqueBridge:RegisterDisableCallback(groupName, function(_, isDisabled)
                if InCombatLockdown() then return end
                local container = self.containers[barIndex]
                if not container then return end
                local btns = self.buttons[barIndex]
                if btns and Orbit.Skin.Icons then
                    for _, btn in ipairs(btns) do
                        if isDisabled then
                            Orbit.Skin.Icons:StripMasqueSkin(btn)
                        else
                            Orbit.Skin.Icons:StripOrbitSkin(btn)
                        end
                    end
                end
                if not isDisabled then
                    MasqueBridge:ReSkinGroup(groupName)
                end
                self:ApplySettings(container)
            end)
        end
    end

    self.UpdateVisibilityDriver = function()
        if InCombatLockdown() then return end
        for index, container in pairs(self.containers) do
            if index == PET_BAR_INDEX then
                RegisterStateDriver(container, "visibility", GetVisibilityDriver(PET_BAR_BASE_DRIVER))
            elseif index == 1 then
                RegisterStateDriver(container, "visibility", BAR1_BASE_DRIVER)
            else
                RegisterStateDriver(container, "visibility", GetVisibilityDriver(BASE_VISIBILITY_DRIVER))
            end
        end
    end

    self:RegisterStandardEvents()

    Orbit.EventBus:On("PLAYER_REGEN_ENABLED", self.OnCombatEnd, self)

    Orbit.EventBus:On("UPDATE_MULTI_CAST_ACTIONBAR", function()
        C_Timer.After(0.1, function()
            self:ApplyAll()
        end)
    end, self)

    hooksecurefunc("ActionButton_UpdateRangeIndicator", function(btn, checksRange, inRange)
        if not btn or not btn.icon then return end
        local outOfRange = checksRange and not inRange
        btn.orbitOutOfRange = outOfRange
        btn.icon:SetDesaturated(outOfRange)
    end)

    hooksecurefunc(ActionBarActionButtonMixin, "Update", function(btn)
        if btn.orbitOutOfRange and btn.icon then
            btn.icon:SetDesaturated(true)
        end
    end)

    Orbit.EventBus:On("CURSOR_CHANGED", function()
        local cursorType = GetCursorInfo()
        local isDraggingDroppable = DROPPABLE_CURSOR_TYPES[cursorType]

        local wasDragging = self.isDraggingDroppable

        if isDraggingDroppable then
            self.isDraggingDroppable = true
        elseif wasDragging then
            self.isDraggingDroppable = false
        else
            return
        end

        if self.cursorTimer then
            self.cursorTimer:Cancel()
        end
        self.cursorTimer = C_Timer.NewTimer(0.05, function()
            if not InCombatLockdown() then
                self:ApplyAll()
            end
        end)
    end, self)
end

-- [ EDIT MODE NUM ICONS PATCH ]------------------------------------------------------------------
StaticPopupDialogs["ORBIT_ACTIONBARS_RELOAD"] = {
    text = "Orbit has updated your Edit Mode action bar settings.\nA reload is required for changes to take effect.",
    button1 = "Reload UI",
    OnAccept = ReloadUI,
    timeout = 0, whileDead = true, hideOnEscape = false,
}

function Plugin:PatchEditModeNumIcons()
    Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
        local layoutInfo = not InCombatLockdown() and EditModeManagerFrame and EditModeManagerFrame.layoutInfo
        if not layoutInfo then return end
        local dirty = false
        for _, layout in ipairs(layoutInfo.layouts) do
            if not layout.systems then break end
            for _, sys in ipairs(layout.systems) do
                if sys.system == Enum.EditModeSystem.ActionBar then
                    for _, s in ipairs(sys.settings) do
                        if s.setting == Enum.EditModeActionBarSetting.NumIcons and s.value < 12 then
                            s.value = 12
                            dirty = true
                        end
                    end
                end
            end
        end
        if not dirty then return end
        C_EditMode.SaveLayouts(layoutInfo)
        StaticPopup_Show("ORBIT_ACTIONBARS_RELOAD")
    end, self)
end

-- [ VEHICLE EXIT BUTTON ]------------------------------------------------------------------------
function Plugin:CreateVehicleExitButton()
    if InCombatLockdown() then
        return
    end

    local container = CreateFrame("Frame", "OrbitVehicleExit", UIParent, "SecureHandlerStateTemplate")
    container:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    container.systemIndex = VEHICLE_EXIT_INDEX
    container.editModeName = "Vehicle Exit"
    container:EnableMouse(true)
    container:SetClampedToScreen(true)
    container.anchorOptions = { x = true, y = true, syncScale = false, syncDimensions = false }
    if OrbitEngine.Pixel then OrbitEngine.Pixel:Enforce(container) end

    container.Selection = container:CreateTexture(nil, "OVERLAY")
    container.Selection:SetColorTexture(1, 1, 1, 0.1)
    container.Selection:SetAllPoints()
    container.Selection:Hide()

    OrbitEngine.Frame:AttachSettingsListener(container, self, VEHICLE_EXIT_INDEX)

    local btn = CreateFrame("Button", "OrbitVehicleExitButton", container)
    btn:SetAllPoints(container)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetScript("OnClick", function()
        if UnitOnTaxi("player") then TaxiRequestEarlyLanding() else VehicleExit() end
    end)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(VEHICLE_EXIT_ICON)

    local bar1 = self.containers[1]
    if bar1 then
        container:SetPoint("LEFT", bar1, "RIGHT", 4, 0)
    else
        container:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 40)
    end

    RegisterStateDriver(container, "visibility", VEHICLE_EXIT_VISIBILITY)

    self.containers[VEHICLE_EXIT_INDEX] = container
    self.vehicleExitButton = container
end

function Plugin:IsComponentDisabled(componentKey, systemIndex)
    systemIndex = systemIndex or 1
    local disabled = self:GetSetting(systemIndex, "DisabledComponents") or {}
    for _, key in ipairs(disabled) do
        if key == componentKey then
            return true
        end
    end
    return false
end

-- [ CANVAS MODE PREVIEW ]------------------------------------------------------------------------
function Plugin:SetupCanvasPreview(container, systemIndex)
    local plugin = self
    local LSM = LibStub("LibSharedMedia-3.0")

    container.CreateCanvasPreview = function(self, options)

        local w, h = BUTTON_SIZE, BUTTON_SIZE
        local parent = options.parent or UIParent
        local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        preview:SetSize(w, h)

        preview.sourceFrame = self
        local borderSize = Orbit.db.GlobalSettings.BorderSize
        local contentW = w - (borderSize * 2)
        local contentH = h - (borderSize * 2)
        preview.sourceWidth = contentW
        preview.sourceHeight = contentH
        preview.previewScale = 1
        preview.components = {}

        local iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        local buttons = plugin.buttons[systemIndex]
        if buttons then
            for _, btn in ipairs(buttons) do
                if btn:IsShown() and btn.icon then
                    local tex = btn.icon:GetTexture()
                    if tex then
                        iconTexture = tex
                        break
                    end
                end
            end
        end

        local icon = preview:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(iconTexture)

        local backdrop = {
            bgFile = "Interface\\BUTTONS\\WHITE8x8",
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        }
        if borderSize > 0 then
            backdrop.edgeFile = "Interface\\BUTTONS\\WHITE8x8"
            backdrop.edgeSize = borderSize
        end
        preview:SetBackdrop(backdrop)
        preview:SetBackdropColor(0, 0, 0, 0)
        if borderSize > 0 then
            preview:SetBackdropBorderColor(0, 0, 0, 1)
        end

        -- [ TEXT COMPONENTS ]-----------------------------------------------------------
        local useGlobal = plugin:GetSetting(systemIndex, "UseGlobalTextStyle")
        local savedPositions
        if useGlobal ~= false then
            savedPositions = plugin:GetSetting(1, "GlobalComponentPositions") or {}
        else
            savedPositions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        end

        local globalFontName = Orbit.db.GlobalSettings.Font
        local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"

        local textComponents = {
            { key = "Keybind", preview = "Q", anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2 },
            { key = "MacroText", preview = "Macro", anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 2 },
            { key = "Timer", preview = "5", anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
            { key = "Stacks", preview = "3", anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
        }

        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent

        for _, def in ipairs(textComponents) do

            local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7) -- Highest sublevel
            fs:SetFont(fontPath, 12, Orbit.Skin:GetFontOutline())
            fs:SetText(def.preview)
            fs:SetTextColor(1, 1, 1, 1)
            fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

            local saved = savedPositions[def.key] or {}
            local data = {
                anchorX = saved.anchorX or def.anchorX,
                anchorY = saved.anchorY or def.anchorY,
                offsetX = saved.offsetX or def.offsetX,
                offsetY = saved.offsetY or def.offsetY,
                justifyH = saved.justifyH or "CENTER",
                overrides = saved.overrides,
            }

            local halfW, halfH = contentW / 2, contentH / 2
            local startX, startY = saved.posX or 0, saved.posY or 0

            if not saved.posX then
                if data.anchorX == "LEFT" then
                    startX = -halfW + data.offsetX
                elseif data.anchorX == "RIGHT" then
                    startX = halfW - data.offsetX
                end
            end
            if not saved.posY then
                if data.anchorY == "BOTTOM" then
                    startY = -halfH + data.offsetY
                elseif data.anchorY == "TOP" then
                    startY = halfH - data.offsetY
                end
            end

            if CreateDraggableComponent then
                local comp = CreateDraggableComponent(preview, def.key, fs, startX, startY, data)
                if comp then
                    comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                    preview.components[def.key] = comp
                    fs:Hide()
                end
            end
        end

        return preview
    end
end

-- [ TEXT COMPONENT SETTINGS ]--------------------------------------------------------------------

function Plugin:ApplyTextSettings(button, systemIndex)
    if not button then
        return
    end

    local KeybindSystem = OrbitEngine.KeybindSystem
    local LSM = LibStub("LibSharedMedia-3.0", true)

    local globalFontName = Orbit.db.GlobalSettings.Font
    local baseFontPath = (Orbit.Fonts and Orbit.Fonts[globalFontName]) or Orbit.Constants.Settings.Font.FallbackPath
    if LSM then
        baseFontPath = LSM:Fetch("font", globalFontName) or baseFontPath
    end

    local useGlobal = self:GetSetting(systemIndex, "UseGlobalTextStyle")
    local positions
    if useGlobal ~= false then -- default to true if nil
        positions = self:GetSetting(1, "GlobalComponentPositions") or {}
    else
        positions = self:GetSetting(systemIndex, "ComponentPositions") or {}
    end

    local w = button:GetWidth()
    if w < 20 then
        w = BUTTON_SIZE
    end

    local OverrideUtils = OrbitEngine.OverrideUtils

    local function GetComponentOverrides(key)
        local pos = positions[key] or {}
        return pos.overrides or {}, pos
    end

    local function ApplyComponentPosition(textElement, key, defaultAnchorX, defaultAnchorY, defaultOffsetX, defaultOffsetY)
        if not textElement then
            return
        end

        if self:IsComponentDisabled(key, systemIndex) then
            textElement:Hide()
            return
        end

        textElement:Show()

        local pos = positions[key] or {}
        local anchorX = pos.anchorX or defaultAnchorX
        local anchorY = pos.anchorY or defaultAnchorY
        local offsetX = pos.offsetX or defaultOffsetX
        local offsetY = pos.offsetY or defaultOffsetY
        local justifyH = pos.justifyH or "CENTER"

        local anchorPoint
        if anchorY == "CENTER" and anchorX == "CENTER" then
            anchorPoint = "CENTER"
        elseif anchorY == "CENTER" then
            anchorPoint = anchorX
        elseif anchorX == "CENTER" then
            anchorPoint = anchorY
        else
            anchorPoint = anchorY .. anchorX -- e.g., "TOPRIGHT"
        end

        local textPoint
        if justifyH == "LEFT" then
            textPoint = "LEFT"
        elseif justifyH == "RIGHT" then
            textPoint = "RIGHT"
        else
            textPoint = "CENTER"
        end

        local finalOffsetX = anchorX == "LEFT" and offsetX or -offsetX
        local finalOffsetY = anchorY == "BOTTOM" and offsetY or -offsetY

        textElement:ClearAllPoints()
        textElement:SetPoint(textPoint, button, anchorPoint, finalOffsetX, finalOffsetY)

        if textElement.SetJustifyH then
            textElement:SetJustifyH(justifyH)
        end
    end

    if button.HotKey then
        local defaultSize = math.max(8, w * 0.28)
        local overrides = GetComponentOverrides("Keybind")

        OverrideUtils.ApplyOverrides(button.HotKey, overrides, { fontSize = defaultSize, fontPath = baseFontPath })
        button.HotKey:SetDrawLayer("OVERLAY", 7) -- Consistent strata

        if KeybindSystem then
            local shortKey = KeybindSystem:GetForButton(button)
            if shortKey and shortKey ~= "" then
                button.HotKey:SetText(shortKey)
            else

                button.HotKey:SetText("")
            end
        else

            button.HotKey:SetText("")
        end

        ApplyComponentPosition(button.HotKey, "Keybind", "RIGHT", "TOP", 2, 2)
    end

    if button.Name then
        local defaultSize = math.max(7, w * 0.22)
        local overrides = GetComponentOverrides("MacroText")

        OverrideUtils.ApplyOverrides(button.Name, overrides, { fontSize = defaultSize, fontPath = baseFontPath })
        button.Name:SetDrawLayer("OVERLAY", 7) -- Consistent strata

        if not button.orbitTextOverlay then
            button.orbitTextOverlay = CreateFrame("Frame", nil, button)
            button.orbitTextOverlay:SetAllPoints(button)
            button.orbitTextOverlay:SetFrameLevel(button:GetFrameLevel() + 10)
        end
        button.Name:SetParent(button.orbitTextOverlay)

        ApplyComponentPosition(button.Name, "MacroText", "CENTER", "BOTTOM", 0, 2)
    end

    local cooldown = button.cooldown or button.Cooldown
    if cooldown then
        if self:IsComponentDisabled("Timer", systemIndex) then
            if cooldown.SetHideCountdownNumbers then
                cooldown:SetHideCountdownNumbers(true)
            end
        else
            if cooldown.SetHideCountdownNumbers then
                cooldown:SetHideCountdownNumbers(false)
            end

            local timerText = cooldown.Text
            if not timerText then
                local regions = { cooldown:GetRegions() }
                for _, region in ipairs(regions) do
                    if region:GetObjectType() == "FontString" then
                        timerText = region
                        break
                    end
                end
            end

            if timerText and timerText.SetFont then
                local defaultSize = math.max(10, w * 0.35)
                local overrides, pos = GetComponentOverrides("Timer")

                OverrideUtils.ApplyOverrides(timerText, overrides, { fontSize = defaultSize, fontPath = baseFontPath })
                timerText:SetDrawLayer("OVERLAY", 7) -- Consistent strata

                if pos.anchorX then
                    ApplyComponentPosition(timerText, "Timer", "CENTER", "CENTER", 0, 0)
                end
            end
        end
    end

    if button.Count then
        local defaultSize = math.max(8, w * 0.28)
        local overrides = GetComponentOverrides("Stacks")

        OverrideUtils.ApplyOverrides(button.Count, overrides, { fontSize = defaultSize, fontPath = baseFontPath })
        button.Count:SetDrawLayer("OVERLAY", 7) -- Consistent strata

        ApplyComponentPosition(button.Count, "Stacks", "LEFT", "BOTTOM", 2, 2)
    end
end

function Plugin:OnCombatEnd()
    C_Timer.After(0.5, function()
        self:ApplyAll()
    end)
end

-- [ CONTAINER CREATION ]-------------------------------------------------------------------------
function Plugin:InitializeContainers()
    for _, config in ipairs(BAR_CONFIG) do
        if not self.containers[config.index] then
            self.containers[config.index] = self:CreateContainer(config)
        end
    end
end

function Plugin:CreateContainer(config)

    local frame = CreateFrame("Frame", config.orbitName, UIParent, "SecureHandlerStateTemplate")
    frame:SetSize(INITIAL_FRAME_SIZE, INITIAL_FRAME_SIZE)
    frame.systemIndex = config.index
    frame.editModeName = config.label
    frame.blizzBarName = config.blizzName
    frame.isSpecial = config.isSpecial

    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)

    frame.anchorOptions = {
        x = true,
        y = true,
        syncScale = false,
        syncDimensions = false,
    }

    if config.index == PET_BAR_INDEX then
        RegisterStateDriver(frame, "visibility", GetVisibilityDriver(PET_BAR_BASE_DRIVER))
    elseif config.index ~= 1 then
        RegisterStateDriver(frame, "visibility", GetVisibilityDriver(BASE_VISIBILITY_DRIVER))
    end

    OrbitEngine.Frame:AttachSettingsListener(frame, self, config.index)

    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()

    local yOffset = -150 - ((config.index - 1) * 50)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, yOffset)

    self.blizzBars[config.index] = _G[config.blizzName]

    -- [ SPELL FLYOUT SUPPORT ]
    frame.GetSpellFlyoutDirection = function(f)
        local direction = "UP" -- Default
        local screenHeight = GetScreenHeight()
        local screenWidth = GetScreenWidth()
        local x, y = f:GetCenter()

        if x and y then
            -- Determine quadrant
            local isTop = y > (screenHeight / 2)
            local isLeft = x < (screenWidth / 2)
            direction = isTop and "DOWN" or "UP"
            if f:GetHeight() > f:GetWidth() then
                -- Vertical bar
                direction = isLeft and "RIGHT" or "LEFT"
            end
        end
        return direction
    end

    -- [ ACTION BAR 1 PAGING ]

    if config.index == 1 then
        local pagingDriver = table.concat({
            "[vehicleui] 12",
            "[overridebar] 14",
            "[possessbar] 12",
            "[shapeshift] 13",

            -- Bar Paging (Manual Shift+1..6)
            "[bar:2] 2",
            "[bar:3] 3",
            "[bar:4] 4",
            "[bar:5] 5",
            "[bar:6] 6",

            -- Bonus Bars (Druid/Rogue/Stealth/etc)
            "[bonusbar:1] 7",
            "[bonusbar:2] 8",
            "[bonusbar:3] 9",
            "[bonusbar:4] 10",
            "[bonusbar:5] 11",

            "1", -- Default
        }, "; ")

        frame:SetAttribute(
            "_onstate-page",
            [[ 
            self:SetAttribute("actionpage", newstate)
            control:ChildUpdate("actionpage", newstate) -- Ensure children update if they don't inherit automatically
        ]]
        )
        RegisterStateDriver(frame, "page", pagingDriver)
        RegisterStateDriver(frame, "visibility", BAR1_BASE_DRIVER)
    end

    frame:Show()

    -- Apply Out of Combat Fade (skip for Pet Bar - it has pet-based visibility, not combat-based)
    if Orbit.OOCFadeMixin and config.index ~= PET_BAR_INDEX then
        local enableHover = self:GetSetting(config.index, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, config.index, "OutOfCombatFade", enableHover)
    end

    return frame
end

-- [ BUTTON REPARENTING ]-------------------------------------------------------------------------
function Plugin:ReparentAllButtons()
    if InCombatLockdown() then
        return
    end

    for _, config in ipairs(BAR_CONFIG) do
        self:ReparentButtons(config.index)
    end
end

function Plugin:ReparentButtons(index)
    if InCombatLockdown() then
        return
    end

    local container = self.containers[index]
    local config = BAR_CONFIG[index]

    if not self.blizzBars[index] and config then
        self.blizzBars[index] = _G[config.blizzName]
    end
    local blizzBar = self.blizzBars[index]

    if not container then
        return
    end

    local buttons = {}
    if not config then return end
    for i = 1, config.count do
        local btn = _G[config.buttonPrefix .. i]
        if btn then table.insert(buttons, btn) end
    end

    if blizzBar then
        OrbitEngine.NativeFrame:SecureHide(blizzBar)
        if blizzBar.BorderArt and blizzBar.BorderArt.Hide then
            blizzBar.BorderArt:Hide()
        end
        if blizzBar.EndCaps and blizzBar.EndCaps.Hide then
            blizzBar.EndCaps:Hide()
        end
        if blizzBar.ActionBarPageNumber and blizzBar.ActionBarPageNumber.Hide then
            blizzBar.ActionBarPageNumber:Hide()
        end
    end

    if #buttons == 0 then
        return
    end

    self.buttons[index] = buttons
    for _, button in ipairs(buttons) do
        button:SetParent(container)
        button:Show()

        if config and config.buttonPrefix == "ExtraActionButton" and button.style then
            button.style:SetAlpha(0) -- Hide art
        end
    end
end

-- [ BUTTON LAYOUT AND SKINNING ]-----------------------------------------------------------------
function Plugin:LayoutButtons(index)
    if InCombatLockdown() then
        return
    end
    local container = self.containers[index]
    local buttons = self.buttons[index]
    if container and container.orbitDisabled then
        return
    end
    if not container or not buttons or #buttons == 0 then
        return
    end

    local padding = self:GetSetting(index, "IconPadding") or 2
    local rows = self:GetSetting(index, "Rows") or 1
    local orientation = self:GetSetting(index, "Orientation") or 0
    local hideEmpty = self:GetSetting(index, "HideEmptyButtons")

    if SPECIAL_BAR_INDICES[index] then
        hideEmpty = true
    end

    local cursorType = GetCursorInfo()
    local cursorOverridesHide = DROPPABLE_CURSOR_TYPES[cursorType]

    local isSpecialBar = SPECIAL_BAR_INDICES[index]
    if cursorOverridesHide and not isSpecialBar then
        hideEmpty = false
    end

    local config = BAR_CONFIG[index]
    local numIcons = self:GetSetting(index, "NumIcons") or (config and config.count or 12)

    local w = BUTTON_SIZE
    local h = w

    local useMasque = MasqueBridge and MasqueBridge.enabled
    local masqueGroup = useMasque and (config and config.label or "Action Bar " .. index)

    local skinSettings = {
        style = 1,
        aspectRatio = "1:1",
        zoom = 8,
        borderStyle = 1,
        borderSize = Orbit.db.GlobalSettings.BorderSize,
        swipeColor = { r = 0, g = 0, b = 0, a = 0.8 },
        showTimer = true,
        hideName = false,
        backdropColor = self:GetSetting(1, "BackdropColour"),
        keypressColor = self:GetSetting(1, "KeypressColor") or { r = 1, g = 1, b = 1, a = 0.6 },
    }

    local totalEffective = math.min(#buttons, numIcons)
    local limitPerLine
    if orientation == 0 then
        limitPerLine = math.ceil(totalEffective / rows)
        if limitPerLine < 1 then
            limitPerLine = 1
        end
    else
        limitPerLine = rows
    end

    local cacheKey = string.format("%d_%d_%d_%d_%d", numIcons, limitPerLine, orientation, w, padding)
    local cache = self.gridCache[index]
    if not cache or cache.key ~= cacheKey then
        local positions = {}
        local scale = buttons[1] and buttons[1]:GetEffectiveScale() or 1
        for i = 1, numIcons do
            local x, y = OrbitEngine.Layout:ComputeGridPosition(i, limitPerLine, orientation, w, h, padding)
            if OrbitEngine.Pixel then
                x = OrbitEngine.Pixel:Snap(x, scale)
                y = OrbitEngine.Pixel:Snap(y, scale)
            end
            positions[i] = { x = x, y = y }
        end
        self.gridCache[index] = { key = cacheKey, positions = positions }
        cache = self.gridCache[index]
    end
    local cachedPositions = cache.positions

    for i, button in ipairs(buttons) do

        if i > numIcons then
            if not InCombatLockdown() then
                local hiddenFrame = EnsureHiddenFrame()
                button:SetParent(hiddenFrame)
                button:Hide()
            end
            button.orbitHidden = true
        else
            local hasAction = button.HasAction and button:HasAction() or false

            local shouldShow = true
            if hideEmpty and not hasAction then
                shouldShow = false
            end

            if not shouldShow then
                if not InCombatLockdown() then
                    local hiddenFrame = EnsureHiddenFrame()
                    button:SetParent(hiddenFrame)
                    button:Hide()
                end
                button.orbitHidden = true
                if button.orbitBackdrop then
                    button.orbitBackdrop:Hide()
                end
            else

                if button.orbitHidden and not InCombatLockdown() then
                    button:SetParent(container)
                end
                button.orbitHidden = false
                button:Show()

                button:SetSize(w, h)

                if useMasque then
                    MasqueBridge:AddActionButton(masqueGroup, button)
                end
                if not useMasque or not MasqueBridge:IsGroupEnabled(masqueGroup) then
                    Orbit.Skin.Icons:ApplyActionButtonCustom(button, skinSettings)
                end

                self:ApplyTextSettings(button, index)

                button:ClearAllPoints()
                local pos = cachedPositions[i]
                button:SetPoint("TOPLEFT", container, "TOPLEFT", pos.x, pos.y)
            end
        end
    end

    local sizeCount = totalEffective
    if index == STANCE_BAR_INDEX then
        local visibleCount = 0
        for i = 1, totalEffective do
            local btn = buttons[i]
            if btn and not btn.orbitHidden then
                visibleCount = visibleCount + 1
            end
        end
        sizeCount = math.max(visibleCount, MIN_STANCE_ICONS)
    end

    local sizeLimitPerLine = (orientation == 0) and math.ceil(sizeCount / rows) or rows
    if sizeLimitPerLine < 1 then
        sizeLimitPerLine = 1
    end

    local finalW, finalH = OrbitEngine.Layout:ComputeGridContainerSize(sizeCount, sizeLimitPerLine, orientation, w, h, padding)

    container:SetSize(finalW, finalH)

    container.orbitRowHeight = h
    container.orbitColumnWidth = w
end

-- [ SETTINGS APPLICATION ]-----------------------------------------------------------------------
function Plugin:ApplyAll()
    for index, container in pairs(self.containers) do

        self:ApplySettings(container)
    end
end

function Plugin:ApplySettings(frame)
    if not frame then self:ApplyAll() return end
    if InCombatLockdown() then return end
    local actualFrame = frame.systemFrame or frame
    local index = frame.systemIndex or actualFrame.systemIndex
    if not index or not actualFrame then return end

    if index == VEHICLE_EXIT_INDEX then
        if Orbit:IsEditMode() then
            UnregisterStateDriver(actualFrame, "visibility")
            actualFrame:Show()
        else
            RegisterStateDriver(actualFrame, "visibility", VEHICLE_EXIT_VISIBILITY)
        end
        self:ApplyScale(actualFrame, index, "Scale")
        OrbitEngine.Frame:RestorePosition(actualFrame, self, index)
        return
    end

    local enabled = true
    if index <= 8 then
        local numBars = self:GetSetting(1, "NumActionBars") or 4
        if index > numBars then
            enabled = false
        end
    end

    if not self.blizzBars[index] then
        local config = BAR_CONFIG[index]
        if config then
            self.blizzBars[index] = _G[config.blizzName]
        end
    end
    local blizzBar = self.blizzBars[index]

    if blizzBar then
        OrbitEngine.NativeFrame:Protect(blizzBar)
    end

    if enabled == false then
        -- cleanup disabled bars
        UnregisterStateDriver(actualFrame, "visibility")

        local buttons = self.buttons[index]
        if buttons and #buttons > 0 then
            local hiddenFrame = EnsureHiddenFrame()
            for _, button in ipairs(buttons) do
                button:SetParent(hiddenFrame)
                button:Hide()
                button.orbitHidden = true
            end
        end
        actualFrame:Hide()
        OrbitEngine.FrameAnchor:SetFrameDisabled(actualFrame, true)
        return
    end

    OrbitEngine.FrameAnchor:SetFrameDisabled(actualFrame, false)

    if index ~= 1 then
        RegisterStateDriver(actualFrame, "visibility", GetVisibilityDriver(BASE_VISIBILITY_DRIVER))
    end

    if not self.buttons[index] or #self.buttons[index] == 0 then
        self:ReparentButtons(index)
    end

    self:ApplyScale(actualFrame, index, "Scale")

    if Orbit.OOCFadeMixin and index ~= PET_BAR_INDEX then
        local enableHover = self:GetSetting(index, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(actualFrame, self, index, "OutOfCombatFade", enableHover)
    end

    self:ApplyMouseOver(actualFrame, index)
    self:LayoutButtons(index)

    OrbitEngine.Frame:RestorePosition(actualFrame, self, index)

    if self.buttons[index] then
        local direction = "UP"
        if actualFrame.GetSpellFlyoutDirection then
            direction = actualFrame:GetSpellFlyoutDirection()
        end

        for _, button in ipairs(self.buttons[index]) do

            if not InCombatLockdown() then
                button:SetAttribute("flyoutDirection", direction)
            end

            if button.SetPopupDirection then
                button:SetPopupDirection(direction)
            end
            if button.UpdateFlyout then
                button:UpdateFlyout()
            end
        end
    end

    actualFrame:Show()
end


function Plugin:GetFrameBySystemIndex(systemIndex)
    return self.containers[systemIndex]
end
