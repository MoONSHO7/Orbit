---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local BUTTON_SIZE = 36
local INITIAL_FRAME_SIZE = 40
local PET_BAR_INDEX = 9
local STANCE_BAR_INDEX = 10
local POSSESS_BAR_INDEX = 11
local EXTRA_BAR_INDEX = 12

local VISIBILITY_DRIVER = "[petbattle][vehicleui] hide; show"

local SPECIAL_BAR_INDICES = {
    [STANCE_BAR_INDEX] = true,
    [POSSESS_BAR_INDEX] = true,
    [EXTRA_BAR_INDEX] = true,
}

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
-- Each action bar gets its own Orbit container (not using Blizzard Edit Mode)
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
        Orientation = 0, -- 0 = Horizontal, 1 = Vertical
        Scale = 100,
        IconPadding = 2,
        Rows = 1,
        Opacity = 100,
        HideEmptyButtons = false,
        -- Per-bar sync toggle (true = use global style, false = use local)
        UseGlobalTextStyle = true,
        -- Canvas Mode component visibility (Keybind enabled by default)
        DisabledComponents = {},
        -- Default component positions for Reset functionality
        ComponentPositions = {
            Keybind = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2, justifyH = "RIGHT" },
            MacroText = { anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 2, justifyH = "CENTER" },
            Timer = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0, justifyH = "CENTER" },
            Stacks = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2, justifyH = "LEFT" },
        },
        -- Global component positions (shared across all synced bars)
        GlobalComponentPositions = {
            Keybind = { anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2, justifyH = "RIGHT" },
            MacroText = { anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 2, justifyH = "CENTER" },
            Timer = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0, justifyH = "CENTER" },
            Stacks = { anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2, justifyH = "LEFT" },
        },
        GlobalDisabledComponents = {},
        OutOfCombatFade = false,
        ShowOnMouseover = true,
    },
}, Orbit.Constants.PluginGroups.ActionBars)

Plugin.canvasMode = true

-- Apply NativeBarMixin for mouse-over fade
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

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Visibility" }, "Layout")

    if currentTab == "Layout" then
        if systemIndex == 1 then
            table.insert(schema.controls, {
                type = "slider", key = "NumActionBars", label = "|cFFFFD100# Action Bars|r",
                default = 4, min = 2, max = 8, step = 1, updateOnRelease = true,
                onChange = function(val)
                    local current = Plugin:GetSetting(1, "NumActionBars") or 4
                    if current == val then return end
                    Plugin:SetSetting(1, "NumActionBars", val)
                    Plugin:ApplyAll()
                end,
            })
        end
        WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
            key = "Scale", label = "Scale", default = 100, min = 50, max = 150,
        })
        table.insert(schema.controls, { type = "slider", key = "IconPadding", label = "Padding", min = -1, max = 10, step = 1, default = 2 })

        local config = BAR_CONFIG[systemIndex]
        local isSpecialBar = config.isSpecial or SPECIAL_BAR_INDICES[systemIndex]
        if config and config.count > 1 and not isSpecialBar then
            table.insert(schema.controls, {
                type = "slider", key = "NumIcons", label = "# Icons",
                min = 1, max = config.count, step = 1, default = config.count,
                onChange = function(val)
                    self:SetSetting(systemIndex, "NumIcons", val)
                    local currentRows = self:GetSetting(systemIndex, "Rows") or 1
                    if val % currentRows ~= 0 then self:SetSetting(systemIndex, "Rows", 1) end
                    if self.refreshTimer then self.refreshTimer:Cancel() end
                    self.refreshTimer = C_Timer.NewTimer(0.2, function()
                        if dialog.orbitTabCallback then dialog.orbitTabCallback() end
                    end)
                    if self.ApplySettings then self:ApplySettings(container) end
                end,
            })
        end
        local numIcons = self:GetSetting(systemIndex, "NumIcons") or (config and config.count or 12)
        local factors = {}
        for i = 1, numIcons do
            if numIcons % i == 0 then table.insert(factors, i) end
        end
        local currentRows = self:GetSetting(systemIndex, "Rows") or 1
        local currentIndex = 1
        for i, v in ipairs(factors) do
            if v == currentRows then currentIndex = i; break end
        end
        if #factors > 1 then
            table.insert(schema.controls, {
                type = "slider", key = "Rows_Slider", label = "Layout",
                min = 1, max = #factors, step = 1, default = currentIndex,
                formatter = function(v)
                    local rows = factors[v]
                    if not rows then return "" end
                    return rows .. " Row" .. (rows > 1 and "s" or "")
                end,
                onChange = function(val)
                    local rows = factors[val]
                    if rows then
                        self:SetSetting(systemIndex, "Rows", rows)
                        if self.ApplySettings then self:ApplySettings(container) end
                    end
                end,
            })
        end
        local isForcedHideEmpty = SPECIAL_BAR_INDICES[systemIndex]
        if not isForcedHideEmpty then
            table.insert(schema.controls, { type = "checkbox", key = "HideEmptyButtons", label = "Hide Empty Buttons", default = false })
        end
    elseif currentTab == "Visibility" then
        WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })
        table.insert(schema.controls, {
            type = "checkbox", key = "OutOfCombatFade", label = "Out of Combat Fade", default = false,
            tooltip = "Hide frame when out of combat with no target",
            onChange = function(val)
                self:SetSetting(systemIndex, "OutOfCombatFade", val)
                if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:RefreshAll() end
                if dialog.orbitTabCallback then dialog.orbitTabCallback() end
            end,
        })
        if self:GetSetting(systemIndex, "OutOfCombatFade") then
            table.insert(schema.controls, {
                type = "checkbox", key = "ShowOnMouseover", label = "Show on Mouseover", default = true,
                tooltip = "Reveal hidden frame when mousing over it",
                onChange = function(val)
                    self:SetSetting(systemIndex, "ShowOnMouseover", val)
                    self:ApplySettings(container)
                end,
            })
        end
    end

    schema.extraButtons = { {
        text = "Quick Keybind",
        callback = function()
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
            if QuickKeybindFrame then QuickKeybindFrame:Show() end
        end,
    } }

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]----------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create containers immediately
    self:InitializeContainers()

    -- Setup Canvas Mode previews for each container
    for index, container in pairs(self.containers) do
        self:SetupCanvasPreview(container, index)
    end

    -- Register standard events (Handle PEW, EditMode -> ApplySettings)
    self:RegisterStandardEvents()

    Orbit.EventBus:On("PLAYER_REGEN_ENABLED", self.OnCombatEnd, self)

    -- Catch delayed button creation/native bar updates
    Orbit.EventBus:On("UPDATE_MULTI_CAST_ACTIONBAR", function()
        C_Timer.After(0.1, function()
            self:ApplyAll()
        end)
    end, self)

    -- Force refresh range indicators when target changes (fixes desaturation persisting after target change)
    Orbit.EventBus:On("PLAYER_TARGET_CHANGED", function()
        -- Force all action buttons to update on any target change
        for index, buttons in pairs(self.buttons) do
            for _, button in ipairs(buttons) do
                if button and button.icon and button.action then
                    -- Check if action is in range
                    local inRange = IsActionInRange(button.action)
                    -- nil = no range requirement, true = in range, false = out of range
                    if inRange == false then
                        button.icon:SetDesaturated(true)
                    else
                        button.icon:SetDesaturated(false)
                    end
                end
            end
        end
    end, self)

    -- Register for cursor changes to show/hide empty slots when dragging spells
    Orbit.EventBus:On("CURSOR_CHANGED", function()
        -- Check if cursor is holding something droppable
        local cursorType = GetCursorInfo()
        local isDraggingDroppable = cursorType == "spell"
            or cursorType == "petaction"
            or cursorType == "flyout"
            or cursorType == "item"
            or cursorType == "macro"
            or cursorType == "mount"

        -- Track drag state to know when to re-hide buttons after drop
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
        -- Create preview matching single button size
        local w, h = BUTTON_SIZE, BUTTON_SIZE
        local parent = options.parent or UIParent
        local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        preview:SetSize(w, h)

        -- Required metadata for Canvas Mode
        preview.sourceFrame = self
        local borderSize = Orbit.db.GlobalSettings.BorderSize
        local contentW = w - (borderSize * 2)
        local contentH = h - (borderSize * 2)
        preview.sourceWidth = contentW
        preview.sourceHeight = contentH
        preview.previewScale = 1
        preview.components = {}

        -- Get first visible icon texture from the container's children
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

        -- Create icon display
        local icon = preview:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(iconTexture)

        -- Apply border matching Orbit style
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

        -- Get global font settings
        local globalFontName = Orbit.db.GlobalSettings.Font
        local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"

        -- Text component definitions with defaults
        local textComponents = {
            { key = "Keybind", preview = "Q", anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2 },
            { key = "MacroText", preview = "Macro", anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 2 },
            { key = "Timer", preview = "5", anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
            { key = "Stacks", preview = "3", anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
        }

        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent

        for _, def in ipairs(textComponents) do
            -- Create temporary FontString as source for cloning
            local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7) -- Highest sublevel
            fs:SetFont(fontPath, 12, Orbit.Skin:GetFontOutline())
            fs:SetText(def.preview)
            fs:SetTextColor(1, 1, 1, 1)
            fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

            -- Get saved position or use defaults
            local saved = savedPositions[def.key] or {}
            local data = {
                anchorX = saved.anchorX or def.anchorX,
                anchorY = saved.anchorY or def.anchorY,
                offsetX = saved.offsetX or def.offsetX,
                offsetY = saved.offsetY or def.offsetY,
                justifyH = saved.justifyH or "CENTER",
                overrides = saved.overrides,
            }

            -- Calculate start position (center-relative)
            local halfW, halfH = contentW / 2, contentH / 2
            local startX, startY = saved.posX or 0, saved.posY or 0

            -- If no posX/posY saved, convert from anchor/offset
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

            -- Create draggable component if available
            if CreateDraggableComponent then
                local comp = CreateDraggableComponent(preview, def.key, fs, startX, startY, data)
                if comp then
                    -- Ensure text is above the border
                    comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                    preview.components[def.key] = comp
                    fs:Hide()
                end
            else
                -- Fallback: just position the FontString directly
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
            end
        end

        return preview
    end
end

-- [ TEXT COMPONENT SETTINGS ]--------------------------------------------------------------------
-- Apply Canvas Mode text component positions and styling to action buttons
function Plugin:ApplyTextSettings(button, systemIndex)
    if not button then
        return
    end

    local KeybindSystem = OrbitEngine.KeybindSystem
    local LSM = LibStub("LibSharedMedia-3.0", true)

    -- Get global font settings
    local globalFontName = Orbit.db.GlobalSettings.Font
    local baseFontPath = (Orbit.Fonts and Orbit.Fonts[globalFontName]) or Orbit.Constants.Settings.Font.FallbackPath
    if LSM then
        baseFontPath = LSM:Fetch("font", globalFontName) or baseFontPath
    end

    -- Get Canvas Mode component positions (use global if synced)
    local useGlobal = self:GetSetting(systemIndex, "UseGlobalTextStyle")
    local positions
    if useGlobal ~= false then -- default to true if nil
        positions = self:GetSetting(1, "GlobalComponentPositions") or {}
    else
        positions = self:GetSetting(systemIndex, "ComponentPositions") or {}
    end

    -- Button size for font scaling
    local w = button:GetWidth()
    if w < 20 then
        w = BUTTON_SIZE
    end

    -- Helper to get style with Canvas Mode overrides
    local function GetComponentStyle(key, defaultSize)
        local pos = positions[key] or {}
        local overrides = pos.overrides or {}

        -- Font override
        local font = baseFontPath
        if overrides.Font and LSM then
            font = LSM:Fetch("font", overrides.Font) or baseFontPath
        end

        -- Size override
        local size = overrides.FontSize or defaultSize

        -- Flags override (shadow vs outline)
        local flags = Orbit.Skin:GetFontOutline()
        if overrides.ShowShadow then
            flags = ""
        end

        return font, size, flags, pos, overrides
    end

    -- Helper to apply color overrides
    local function ApplyTextColor(textElement, overrides)
        if not textElement or not textElement.SetTextColor then
            return
        end
        if not overrides then
            return
        end

        if overrides.UseClassColour then
            local _, playerClass = UnitClass("player")
            local classColor = RAID_CLASS_COLORS[playerClass]
            if classColor then
                textElement:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            end
        elseif overrides.CustomColor and overrides.CustomColorValue and type(overrides.CustomColorValue) == "table" then
            -- CustomColor is boolean toggle, CustomColorValue is the actual color table
            local c = overrides.CustomColorValue
            textElement:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
        end
    end

    -- Helper to position a text element based on Canvas Mode settings
    local function ApplyComponentPosition(textElement, key, defaultAnchorX, defaultAnchorY, defaultOffsetX, defaultOffsetY)
        if not textElement then
            return
        end

        -- Check if disabled via Canvas Mode
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

        -- Convert anchor pair to WoW anchor point (where on the button to anchor)
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

        -- Calculate offset direction based on anchor position
        local finalOffsetX = anchorX == "LEFT" and offsetX or -offsetX
        local finalOffsetY = anchorY == "BOTTOM" and offsetY or -offsetY

        textElement:ClearAllPoints()
        textElement:SetPoint(textPoint, button, anchorPoint, finalOffsetX, finalOffsetY)

        if textElement.SetJustifyH then
            textElement:SetJustifyH(justifyH)
        end
    end

    -- KEYBIND (HotKey)
    if button.HotKey then
        local defaultSize = math.max(8, w * 0.28)
        local font, size, flags, pos, overrides = GetComponentStyle("Keybind", defaultSize)

        button.HotKey:SetFont(font, size, flags)
        button.HotKey:SetTextColor(1, 1, 1, 1)
        button.HotKey:SetDrawLayer("OVERLAY", 7) -- Consistent strata
        ApplyTextColor(button.HotKey, overrides)

        -- Apply shadow if enabled
        if overrides.ShowShadow then
            button.HotKey:SetShadowOffset(1, -1)
            button.HotKey:SetShadowColor(0, 0, 0, 1)
        else
            button.HotKey:SetShadowOffset(0, 0)
        end

        -- Apply shortened keybind text using shared system
        if KeybindSystem then
            local shortKey = KeybindSystem:GetForButton(button)
            if shortKey and shortKey ~= "" then
                button.HotKey:SetText(shortKey)
            else
                -- Clear text if no keybind to prevent rendering artifacts
                button.HotKey:SetText("")
            end
        else
            -- No KeybindSystem available, clear text
            button.HotKey:SetText("")
        end

        ApplyComponentPosition(button.HotKey, "Keybind", "RIGHT", "TOP", 2, 2)
    end

    -- MACRO TEXT (Name)
    if button.Name then
        local defaultSize = math.max(7, w * 0.22)
        local font, size, flags, pos, overrides = GetComponentStyle("MacroText", defaultSize)

        button.Name:SetFont(font, size, flags)
        button.Name:SetTextColor(1, 1, 1, 0.9)
        button.Name:SetDrawLayer("OVERLAY", 7) -- Consistent strata

        -- Ensure text appears above border/glows by reparenting to a high-level overlay frame
        if not button.orbitTextOverlay then
            button.orbitTextOverlay = CreateFrame("Frame", nil, button)
            button.orbitTextOverlay:SetAllPoints(button)
            button.orbitTextOverlay:SetFrameLevel(button:GetFrameLevel() + 10)
        end
        button.Name:SetParent(button.orbitTextOverlay)

        ApplyTextColor(button.Name, overrides)

        if overrides.ShowShadow then
            button.Name:SetShadowOffset(1, -1)
            button.Name:SetShadowColor(0, 0, 0, 1)
        else
            button.Name:SetShadowOffset(0, 0)
        end

        ApplyComponentPosition(button.Name, "MacroText", "CENTER", "BOTTOM", 0, 2)
    end

    -- TIMER (Cooldown countdown)
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
                local font, size, flags, pos, overrides = GetComponentStyle("Timer", defaultSize)

                timerText:SetFont(font, size, flags)
                timerText:SetDrawLayer("OVERLAY", 7) -- Consistent strata
                ApplyTextColor(timerText, overrides)

                if overrides.ShowShadow then
                    timerText:SetShadowOffset(1, -1)
                    timerText:SetShadowColor(0, 0, 0, 1)
                else
                    timerText:SetShadowOffset(0, 0)
                end

                if pos.anchorX then
                    ApplyComponentPosition(timerText, "Timer", "CENTER", "CENTER", 0, 0)
                end
            end
        end
    end

    -- STACKS (Count)
    if button.Count then
        local defaultSize = math.max(8, w * 0.28)
        local font, size, flags, pos, overrides = GetComponentStyle("Stacks", defaultSize)

        button.Count:SetFont(font, size, flags)
        button.Count:SetTextColor(1, 1, 1, 1)
        button.Count:SetDrawLayer("OVERLAY", 7) -- Consistent strata
        ApplyTextColor(button.Count, overrides)

        if overrides.ShowShadow then
            button.Count:SetShadowOffset(1, -1)
            button.Count:SetShadowColor(0, 0, 0, 1)
        else
            button.Count:SetShadowOffset(0, 0)
        end

        ApplyComponentPosition(button.Count, "Stacks", "LEFT", "BOTTOM", 2, 2)
    end
end

function Plugin:OnCombatEnd()
    -- Re-apply settings after combat
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
    -- Use SecureHandlerStateTemplate for visibility drivers
    local frame = CreateFrame("Frame", config.orbitName, UIParent, "SecureHandlerStateTemplate")
    frame:SetSize(INITIAL_FRAME_SIZE, INITIAL_FRAME_SIZE)
    frame.systemIndex = config.index
    frame.editModeName = config.label
    frame.blizzBarName = config.blizzName
    frame.isSpecial = config.isSpecial

    frame:EnableMouse(true)
    frame:SetClampedToScreen(true) -- Prevent dragging off-screen

    -- Orbit anchoring options
    frame.anchorOptions = {
        x = true,
        y = true,
        syncScale = false,
        syncDimensions = false,
    }

    -- Visibility Driver
    if config.index == PET_BAR_INDEX then
        RegisterStateDriver(frame, "visibility", "[petbattle][vehicleui] hide; [nopet] hide; show")
    else
        RegisterStateDriver(frame, "visibility", VISIBILITY_DRIVER)
    end

    -- Attach to Orbit's frame system
    OrbitEngine.Frame:AttachSettingsListener(frame, self, config.index)

    -- Selection highlight for Orbit Edit Mode
    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()

    -- Default position
    local yOffset = -150 - ((config.index - 1) * 50)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, yOffset)

    -- Store Blizzard bar reference
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
    -- Only the main bar (Index 1) needs paging logic
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
        UnregisterStateDriver(frame, "visibility")
        RegisterStateDriver(frame, "visibility", "[petbattle][overridebar] hide; show")
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

    -- Try to find Blizzard bar if we haven't yet (Lazy Load fix)
    if not self.blizzBars[index] and config then
        self.blizzBars[index] = _G[config.blizzName]
    end
    local blizzBar = self.blizzBars[index]

    if not container then
        return
    end

    -- Get action buttons
    local buttons = {}

    -- Strategy 1: Explicit pattern (PetActionButton1, etc.)
    if config and config.buttonPrefix and config.count then
        for i = 1, config.count do
            local btnName = config.buttonPrefix .. i
            local btn = _G[btnName]
            if btn then
                table.insert(buttons, btn)
            end
        end
    end

    -- Strategy 2: Blizzard bar property (Standard bars)
    if #buttons == 0 and blizzBar and blizzBar.actionButtons then
        buttons = blizzBar.actionButtons
    end

    -- Strategy 3: Children scan (Fallback)
    if #buttons == 0 then
        local children = { blizzBar:GetChildren() }
        for _, child in ipairs(children) do
            if child.action or child.icon then
                table.insert(buttons, child)
            end
        end
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

    -- Store button references
    self.buttons[index] = buttons

    -- Reparent each button to our container
    for _, button in ipairs(buttons) do
        button:SetParent(container)
        button:Show()

        -- Special handling for Extra Action Button art
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

    -- Get settings
    local padding = self:GetSetting(index, "IconPadding") or 2
    local rows = self:GetSetting(index, "Rows") or 1
    local orientation = self:GetSetting(index, "Orientation") or 0
    local hideEmpty = self:GetSetting(index, "HideEmptyButtons")

    -- Force Hide Empty for special bars
    if SPECIAL_BAR_INDICES[index] then
        hideEmpty = true
    end

    -- CURSOR OVERRIDE: Show grid when dragging droppable content (spell, petaction, flyout, etc.)
    local cursorType = GetCursorInfo()
    local cursorOverridesHide = cursorType == "spell"
        or cursorType == "petaction"
        or cursorType == "flyout"
        or cursorType == "item"
        or cursorType == "macro"
        or cursorType == "mount"

    local isSpecialBar = SPECIAL_BAR_INDICES[index]
    if cursorOverridesHide and not isSpecialBar then
        hideEmpty = false -- Force show all slots when dragging (except special bars)
    end

    local config = BAR_CONFIG[index]
    local numIcons = self:GetSetting(index, "NumIcons") or (config and config.count or 12)

    -- Calculate button size
    local w = BUTTON_SIZE
    local h = w

    -- Skin settings
    local skinSettings = {
        style = 1,
        aspectRatio = "1:1",
        zoom = 8, -- 8% zoom in to fill to border
        borderStyle = 1,
        borderSize = Orbit.db.GlobalSettings.BorderSize,
        swipeColor = { r = 0, g = 0, b = 0, a = 0.8 },
        showTimer = true,
        hideName = false, -- Can expose this setting if needed
        backdropColor = self:GetSetting(index, "BackdropColour"),
    }

    -- Apply layout to each button
    local totalEffective = math.min(#buttons, numIcons)
    local limitPerLine
    if orientation == 0 then
        limitPerLine = math.ceil(totalEffective / rows)
        if limitPerLine < 1 then limitPerLine = 1 end
    else
        limitPerLine = rows
    end

    -- Lazy grid computation: cache positions by layout parameters
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
        -- Strict Icon Limit
        if i > numIcons then
            -- Reparent to hidden frame to completely prevent Blizzard from showing
            if not InCombatLockdown() then
                local hiddenFrame = EnsureHiddenFrame()
                button:SetParent(hiddenFrame)
                button:Hide()
            end
            button.orbitHidden = true
        else
            local hasAction = false

            -- Method 1: Button's own HasAction method (most reliable for all button types)
            if button.HasAction then
                hasAction = button:HasAction()
            -- Method 2: C_ActionBar.HasAction for standard action buttons
            elseif button.action and C_ActionBar.HasAction then
                hasAction = C_ActionBar.HasAction(button.action)
            end

            local shouldShow = true
            if hideEmpty and not hasAction then
                shouldShow = false
            end

            if not shouldShow then
                -- Reparent to hidden frame to prevent Blizzard from re-showing
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
                -- Only NOW reparent to container (after confirming it should show)
                if button.orbitHidden and not InCombatLockdown() then
                    button:SetParent(container)
                end
                button.orbitHidden = false
                button:Show()

                -- Resize button
                button:SetSize(w, h)

                -- Apply Orbit skin (handles texcoord, border, swipe, fonts, highlights)
                Orbit.Skin.Icons:ApplyActionButtonCustom(button, skinSettings)

                -- Apply Canvas Mode text component positions (Keybind, MacroText, Timer, Stacks)
                self:ApplyTextSettings(button, index)

                -- Position button from cached grid positions
                button:ClearAllPoints()
                local pos = cachedPositions[i]
                button:SetPoint("TOPLEFT", container, "TOPLEFT", pos.x, pos.y)
            end
        end
    end

    local finalW, finalH = OrbitEngine.Layout:ComputeGridContainerSize(
        totalEffective,
        limitPerLine,
        orientation,
        w,
        h,
        padding
    )

    container:SetSize(finalW, finalH)

    -- Store dimensions for anchoring
    container.orbitRowHeight = h
    container.orbitColumnWidth = w
end

-- [ SETTINGS APPLICATION ]-----------------------------------------------------------------------
function Plugin:ApplyAll()
    for index, container in pairs(self.containers) do
        -- Skip disabled containers logic inside ApplySettings
        self:ApplySettings(container)
    end
end

function Plugin:ApplySettings(frame)
    if not frame then
        self:ApplyAll()
        return
    end
    if InCombatLockdown() then
        return
    end

    -- Handle settings context object vs actual frame
    local actualFrame = frame
    local index = frame.systemIndex

    -- If frame is a settings context object, get the actual container
    if frame.systemFrame then
        actualFrame = frame.systemFrame
        index = frame.systemIndex
    end

    -- Fall back to getting container by index
    if not actualFrame or not actualFrame.SetAlpha then
        actualFrame = self.containers[index]
    end

    if not index or not actualFrame then
        return
    end

    -- Check Enabled setting (Per-profile slider on Bar 1 controls bars 1-8)
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
        -- FULL CLEANUP for disabled bars

        -- 1. Unregister state driver to prevent visibility override
        UnregisterStateDriver(actualFrame, "visibility")

        -- 2. Move buttons to hidden frame
        local buttons = self.buttons[index]
        if buttons and #buttons > 0 then
            local hiddenFrame = EnsureHiddenFrame()
            for _, button in ipairs(buttons) do
                button:SetParent(hiddenFrame)
                button:Hide()
                button.orbitHidden = true
            end
        end

        -- 3. Hide the container
        actualFrame:Hide()

        -- 4. Mark as disabled to skip in cursor updates
        OrbitEngine.FrameAnchor:SetFrameDisabled(actualFrame, true)
        return
    end

    -- Clear disabled flag
    OrbitEngine.FrameAnchor:SetFrameDisabled(actualFrame, false)

    -- Re-register visibility driver if it was disabled
    if index == 1 then
    else
        RegisterStateDriver(actualFrame, "visibility", VISIBILITY_DRIVER)
    end

    -- Ensure buttons are reparented
    if not self.buttons[index] or #self.buttons[index] == 0 then
        self:ReparentButtons(index)
    end

    -- Apply Scale (Standard Mixin)
    self:ApplyScale(actualFrame, index, "Scale")

    -- Re-apply OOC Fade with current ShowOnMouseover setting (allows dynamic toggle)
    if Orbit.OOCFadeMixin and index ~= PET_BAR_INDEX then
        local enableHover = self:GetSetting(index, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(actualFrame, self, index, "OutOfCombatFade", enableHover)
    end

    -- Apply mouse-over fade (also handles opacity via ApplyHoverFade)
    self:ApplyMouseOver(actualFrame, index)

    -- Layout buttons (Sets size)
    self:LayoutButtons(index)

    -- Restore position (Requires size)
    OrbitEngine.Frame:RestorePosition(actualFrame, self, index)

    -- Force update flyout direction after position restore
    if self.buttons[index] then
        local direction = "UP"
        if actualFrame.GetSpellFlyoutDirection then
            direction = actualFrame:GetSpellFlyoutDirection()
        end

        for _, button in ipairs(self.buttons[index]) do
            -- 1. Set Attribute: This makes UpdateFlyout() respect our direction on future events
            if not InCombatLockdown() then
                button:SetAttribute("flyoutDirection", direction)
            end

            -- 2. Immediate Visual Update: For instant feedback (mixins might not check attribute immediately)
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

function Plugin:GetContainerBySystemIndex(systemIndex)
    return self.containers[systemIndex]
end

function Plugin:GetFrameBySystemIndex(systemIndex)
    return self.containers[systemIndex]
end
