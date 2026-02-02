---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- Local defaults (decoupled from Core Constants)
local BUTTON_SIZE = 36

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
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
    -- { TODO: This isn't working properly, add later.
    --     blizzName = "ExtraAbilityContainer",
    --     orbitName = "OrbitExtraBar",
    --     label = "Extra Action",
    --     index = 12,
    --     buttonPrefix = "ExtraActionButton",
    --     count = 1,
    --     isSpecial = true,
    -- },
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
    },
}, Orbit.Constants.PluginGroups.ActionBars)

Plugin.canvasMode = true

-- Apply NativeBarMixin for mouse-over fade
Mixin(Plugin, Orbit.NativeBarMixin)

-- Container references: index -> container frame
Plugin.containers = {}
-- Button references: index -> { buttons }
Plugin.buttons = {}
-- Original Blizzard bars: index -> blizzard bar
Plugin.blizzBars = {}

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function EnsureHiddenFrame()
    if not Orbit.ButtonHideFrame then
        Orbit.ButtonHideFrame = CreateFrame("Frame", "OrbitButtonHideFrame", UIParent)
        Orbit.ButtonHideFrame:Hide()
        Orbit.ButtonHideFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
    end
    return Orbit.ButtonHideFrame
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or 1
    local WL = OrbitEngine.WidgetLogic

    local container = self.containers[systemIndex]

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- Master Control: # Action Bars (only on Bar 1)
    -- This structural setting controls visibility of bars 2-8
    -- Stored per-profile in Action Bar 1 settings
    if systemIndex == 1 then
        table.insert(schema.controls, {
            type = "slider",
            key = "NumActionBars", -- Per-profile setting stored in Action Bar 1 config
            label = "|cFFFFD100# Action Bars|r", -- Gold text to indicate structural setting
            default = 4,
            min = 2,
            max = 8,
            step = 1,
            updateOnRelease = true, -- Prevent heavy updates during drag
            -- PERFORMANCE: Change detection + targeted refresh (only Action Bars)
            onChange = function(val)
                -- Change Detection: Skip if value unchanged
                local current = Plugin:GetSetting(1, "NumActionBars") or 4
                if current == val then
                    return
                end

                -- Store the value in per-profile plugin settings
                Plugin:SetSetting(1, "NumActionBars", val)

                -- Targeted refresh: Only Action Bars plugin
                Plugin:ApplyAll()
            end,
        })
    end

    -- 1. Scale
    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "Scale",
        label = "Scale",
        default = 100,
        min = 50,
        max = 150,
    })

    -- 2. Padding
    table.insert(schema.controls, {
        type = "slider",
        key = "IconPadding",
        label = "Padding",
        min = -1,
        max = 10,
        step = 1,
        default = 2,
    })

    local config = BAR_CONFIG[systemIndex]

    -- 3. # Icons (Limits total buttons shown)
    -- Only show for Standard bars with > 1 button potential
    -- Special bars (Pet, Stance, etc.) have fixed button counts logic
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

                -- Ensure current Rows setting is still valid, else reset to 1
                local currentRows = self:GetSetting(systemIndex, "Rows") or 1
                if val % currentRows ~= 0 then
                    self:SetSetting(systemIndex, "Rows", 1)
                end

                -- Debounced Refresh to prevent settings duplication during slide
                if self.refreshTimer then
                    self.refreshTimer:Cancel()
                end
                self.refreshTimer = C_Timer.NewTimer(0.2, function()
                    OrbitEngine.Layout:Reset(dialog)
                    self:AddSettings(dialog, systemFrame)
                end)

                if self.ApplySettings then
                    self:ApplySettings(container)
                end
            end,
        })
    end

    -- 4. Rows (Smart Slider based on valid factors)
    local numIcons = self:GetSetting(systemIndex, "NumIcons") or (config and config.count or 12)

    -- Calculate valid factors
    local factors = {}
    for i = 1, numIcons do
        if numIcons % i == 0 then
            table.insert(factors, i)
        end
    end

    -- Find current value index
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
            label = "Layout", -- Dummy key, we handle set manually
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

    -- 5. Opacity
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })

    -- 6. Hide Empty Buttons
    -- Always forced on for Stance, Possess, and Extra bars
    local isForcedHideEmpty = SPECIAL_BAR_INDICES[systemIndex]

    if not isForcedHideEmpty then
        table.insert(schema.controls, {
            type = "checkbox",
            key = "HideEmptyButtons",
            label = "Hide Empty Buttons",
            default = false,
        })
    end

    -- Out of Combat Fade
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
        end,
    })

    -- Add Quick Keybind Mode button to footer
    schema.extraButtons = {
        {
            text = "Quick Keybind",
            callback = function()
                -- Exit Edit Mode first (mirrors Blizzard's SettingsPanel behavior)
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

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
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
            -- Started or continuing a drag - show empty slots
            self.isDraggingDroppable = true
        elseif wasDragging then
            -- Was dragging but now cursor is empty (dropped) - re-hide empty slots
            self.isDraggingDroppable = false
        else
            -- Not dragging and wasn't dragging - ignore (filters out hand->sword changes)
            return
        end

        -- Debounce to avoid rapid re-layouts
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

-- Check if a component is disabled via Canvas Mode drag-to-disable feature
-- Multi-system override for Action Bars (systemIndex 1-11)
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

-- [ CANVAS MODE PREVIEW ]-----------------------------------------------------------------------
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
        -- Only include edgeFile when borderSize > 0 to avoid rendering glitches
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
        
        -- [ TEXT COMPONENTS ]------------------------------------------------------------
        -- Add draggable text labels for Keybind
        
        -- Get saved positions (use global if synced)
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
            local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7)  -- Highest sublevel
            fs:SetFont(fontPath, 12, "OUTLINE")
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
                    fs:Hide()  -- Hide original, comp has its own visual
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

-- [ TEXT COMPONENT SETTINGS ]-------------------------------------------------------------------
-- Apply Canvas Mode text component positions and styling to action buttons
function Plugin:ApplyTextSettings(button, systemIndex)
    if not button then return end
    
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
    if useGlobal ~= false then  -- default to true if nil
        positions = self:GetSetting(1, "GlobalComponentPositions") or {}
    else
        positions = self:GetSetting(systemIndex, "ComponentPositions") or {}
    end
    
    -- Button size for font scaling
    local w = button:GetWidth()
    if w < 20 then w = BUTTON_SIZE end
    
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
        local flags = "OUTLINE"
        if overrides.ShowShadow then
            flags = ""
        end
        
        return font, size, flags, pos, overrides
    end
    
    -- Helper to apply color overrides
    local function ApplyTextColor(textElement, overrides)
        if not textElement or not textElement.SetTextColor then return end
        if not overrides then return end
        
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
        if not textElement then return end
        
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
            anchorPoint = anchorY .. anchorX  -- e.g., "TOPRIGHT"
        end
        
        -- JustifyH-decoupled pattern: text element anchors by its alignment
        -- This ensures proper text flow while anchoring to corners
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
        button.HotKey:SetDrawLayer("OVERLAY", 7)  -- Consistent strata
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
        button.Name:SetDrawLayer("OVERLAY", 7)  -- Consistent strata
        
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
                timerText:SetDrawLayer("OVERLAY", 7)  -- Consistent strata
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
        button.Count:SetDrawLayer("OVERLAY", 7)  -- Consistent strata
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

-- [ CONTAINER CREATION ]----------------------------------------------------------------------------
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
    frame:SetSize(40, 40) -- Will be resized by layout
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
    -- Always hide in Pet Battle or Vehicle UI (Standard & Special bars)
    -- Pet Bar (index 9) has additional logic: only show when player has an active pet
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
    -- Buttons call getParent():GetSpellFlyoutDirection() to determine flyout orientation
    frame.GetSpellFlyoutDirection = function(f)
        local direction = "UP" -- Default
        local screenHeight = GetScreenHeight()
        local screenWidth = GetScreenWidth()
        local x, y = f:GetCenter()

        if x and y then
            -- Determine quadrant
            local isTop = y > (screenHeight / 2)
            local isLeft = x < (screenWidth / 2)

            -- Simple logic: if in top half, fly down. If in bottom half, fly up.
            -- We can refine this for side bars if needed (e.g. if near side edge, fly inward)
            -- For now, vertical bias is standard for horizontal bars
            direction = isTop and "DOWN" or "UP"

            -- If we are a vertical bar (Action Bar 4/5 usually), we might want LEFT/RIGHT
            -- Checking orientation from plugin settings would be better, but we can verify via dimensions
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
        -- Define the secure paging driver
        -- Priority: Vehicle > Override > Possess > Shapeshift > Bonus > Bar Paging > Default
        local pagingDriver = table.concat({
            "[vehicleui] 12", -- Vehicle Page
            "[overridebar] 14", -- Override Page
            "[possessbar] 12", -- Possess Page
            "[shapeshift] 13", -- Shapeshift Page

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

        -- Update Visibility Driver for Bar 1 handling Vehicle UI
        -- We WANT Bar 1 to show in Vehicle UI (it pages to 12), unlike other bars
        -- BUT if we are in an Override Bar state (e.g. Dragonriding/Complex Vehicles), we yield to Native UI
        UnregisterStateDriver(frame, "visibility")
        RegisterStateDriver(frame, "visibility", "[petbattle][overridebar] hide; show")
    end

    frame:Show()

    -- Apply Out of Combat Fade (skip for Pet Bar - it has pet-based visibility, not combat-based)
    if Orbit.OOCFadeMixin and config.index ~= PET_BAR_INDEX then
        Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, config.index, "OutOfCombatFade")
    end

    return frame
end

-- [ BUTTON REPARENTING ]----------------------------------------------------------------------------
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

    -- Always protect the native bar if it exists, regardless of button state
    -- This ensures that even if buttons aren't found immediately, the native bar frame is hidden/disabled
    if blizzBar then
        -- Use SEcureHide for ALL Blizzard action bars to prevent Taint.
        -- Previous use of Protect() (ClearAllPoints) or SetParent() caused "ADDON_ACTION_BLOCKED".
        OrbitEngine.NativeFrame:SecureHide(blizzBar)

        -- Hide decorations (These are usually insecure textures, so harmless to hide,
        -- but wrap in safe check just in case)
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

-- [ BUTTON LAYOUT AND SKINNING ]--------------------------------------------------------------------
function Plugin:LayoutButtons(index)
    if InCombatLockdown() then
        return
    end

    local container = self.containers[index]
    local buttons = self.buttons[index]

    -- Skip disabled containers
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
    -- EXCEPT for special bars (Stance, Possess, Extra) which don't accept drops
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
    -- Note: Container is scaled via ApplyScale, so we use base size here
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

    -- Determine grid wrapping limit
    -- Horizontal: Wrap after N columns (based on rows count)
    -- Vertical: Wrap after N rows
    local limitPerLine
    if orientation == 0 then
        limitPerLine = math.ceil(totalEffective / rows)
        if limitPerLine < 1 then
            limitPerLine = 1
        end
    else
        limitPerLine = rows
    end

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
            -- Handle HideEmptyButtons - check if button has an action
            -- Priority: button:HasAction() method > C_ActionBar.HasAction
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

                -- Position button based on array index (buttons keep their positions)
                button:ClearAllPoints()

                local x, y = OrbitEngine.Layout:ComputeGridPosition(i, limitPerLine, orientation, w, h, padding)
                -- Force pixel snap for button position within container
                if OrbitEngine.Pixel then
                     x = OrbitEngine.Pixel:Snap(x, button:GetEffectiveScale())
                     y = OrbitEngine.Pixel:Snap(y, button:GetEffectiveScale())
                end
                button:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
            end
        end
    end

    -- Calculate container size based on NumIcons (strict grid)
    -- This keeps the container the same size regardless of empty button visibility

    local finalW, finalH = OrbitEngine.Layout:ComputeGridContainerSize(
        totalEffective,
        limitPerLine,
        orientation,
        w, -- button width
        h, -- button height
        padding
    )

    container:SetSize(finalW, finalH)

    -- Store dimensions for anchoring
    container.orbitRowHeight = h
    container.orbitColumnWidth = w
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
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

    -- Ensure Blizzard bar is hidden regardless of Orbit enabled state
    -- Lazy load check
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
    -- Respect standard behavior for all bars, BUT preserve special drivers for index 1
    if index == 1 then
        -- Do nothing, as Bar 1 manages its own complex driver (created in InitializeContainers)
        -- Re-registering here would overwrite the [overridebar] logic with the default driver
    else
        RegisterStateDriver(actualFrame, "visibility", VISIBILITY_DRIVER)
    end

    -- Ensure buttons are reparented
    if not self.buttons[index] or #self.buttons[index] == 0 then
        self:ReparentButtons(index)
    end

    -- Apply Scale (Standard Mixin)
    self:ApplyScale(actualFrame, index, "Scale")

    -- Apply mouse-over fade (also handles opacity via ApplyHoverFade)
    self:ApplyMouseOver(actualFrame, index)

    -- Layout buttons (Sets size)
    self:LayoutButtons(index)

    -- Restore position (Requires size)
    OrbitEngine.Frame:RestorePosition(actualFrame, self, index)

    -- Force update flyout direction after position restore
    -- This ensures that if the bar moved past the vertical threshold, arrows flip immediately
    -- explicitely set direction on buttons because they might not find the parent correctly
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
