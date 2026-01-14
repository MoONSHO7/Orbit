local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
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
    {
        blizzName = "ExtraAbilityContainer",
        orbitName = "OrbitExtraBar",
        label = "Extra Action",
        index = 12,
        buttonPrefix = "ExtraActionButton",
        count = 1,
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
    },
})

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

    -- Register standard events (Handle PEW, EditMode -> ApplySettings)
    self:RegisterStandardEvents()

    Orbit.EventBus:On("PLAYER_REGEN_ENABLED", self.OnCombatEnd, self)

    -- Catch delayed button creation/native bar updates
    Orbit.EventBus:On("UPDATE_MULTI_CAST_ACTIONBAR", function()
        C_Timer.After(0.1, function()
            self:ApplyAll()
        end)
    end, self)

    -- Register for cursor changes to show/hide empty slots when dragging spells
    Orbit.EventBus:On("CURSOR_CHANGED", function()
        -- Debounce to avoid rapid re-layouts
        -- CRITICAL: Only proceed if cursor is actually holding something (filtering out hand->sword changes)
        if not GetCursorInfo() then
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
        syncScale = true,
        syncDimensions = false,
    }

    -- Visibility Driver
    -- Always hide in Pet Battle or Vehicle UI (Standard & Special bars)
    -- Special bars might have additional logic, but for now we apply this global rule
    RegisterStateDriver(frame, "visibility", VISIBILITY_DRIVER)

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
    local w = Orbit.Constants.ActionBars.ButtonSize
    local h = w

    -- Skin settings
    local skinSettings = {
        style = 1,
        aspectRatio = "1:1",
        zoom = 8, -- 8% zoom in to fill to border
        borderStyle = 1,
        borderSize = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderSize or 2,
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
            elseif button.action and C_ActionBar and C_ActionBar.HasAction then
                hasAction = C_ActionBar.HasAction(button.action)
            -- Method 3: Legacy fallback
            elseif button.action and HasAction then
                hasAction = HasAction(button.action)
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

                -- Position button based on array index (buttons keep their positions)
                button:ClearAllPoints()

                local x, y = OrbitEngine.Layout:ComputeGridPosition(i, limitPerLine, orientation, w, h, padding)
                button:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
            end -- end of if/else show/hide
        end -- end of if i > numIcons
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

    -- Check Enabled setting (Global Slider for bars 1-8)
    local enabled = true
    if index <= 8 then
        local numBars = Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.NumActionBars or 8
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
        actualFrame.orbitDisabled = true
        return
    end

    -- Clear disabled flag
    actualFrame.orbitDisabled = false

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

    -- Get settings
    local alpha = self:GetSetting(index, "Opacity") or 100

    -- Apply Scale (Standard Mixin)
    self:ApplyScale(actualFrame, index, "Scale")

    -- Apply opacity
    actualFrame:SetAlpha(alpha / 100)

    -- Apply mouse-over fade
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
