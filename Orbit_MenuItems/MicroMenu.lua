---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
-- Using a custom ID to denote we are replacing the native bar behavior fully
local SYSTEM_ID = "Orbit_MicroMenu"
-- We still want to hook into the "EditModeSystem" for MicroMenu to hide the native selection if possible,
-- but the user effectively wants an Orbit Frame.
-- Let's use our own ID and specific "Micro Menu" label.

local Plugin = Orbit:RegisterPlugin("Menu Bar", SYSTEM_ID, {
    defaults = {
        Padding = -5,
        Rows = 1,
        Scale = 100,
        Opacity = 100,
    },
}, Orbit.Constants.PluginGroups.MenuItems)

-- Apply NativeBarMixin for mouseOver helpers
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function IsMicroButton(frame)
    if not frame then
        return false
    end
    -- Check for know types or properties
    if frame.layoutIndex then
        return true
    end

    local name = frame:GetName()
    if name and name:find("MicroButton") then
        return true
    end

    return false
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local WL = OrbitEngine.WidgetLogic

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- 1. Scale
    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "Scale",
        label = "Menu Size",
        default = 100,
        min = 50,
        max = 150,
    })

    -- 2. Layout (Rows)
    local numButtons = self:CountButtons()
    if numButtons == 0 then
        numButtons = 12
    end -- Fallback

    local factors = {}
    for i = 1, numButtons do
        if numButtons % i == 0 then
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
            key = "Layout_Slider",
            label = "Layout",
            min = 1,
            max = #factors,
            step = 1,
            default = currentIndex,
            formatter = function(v)
                local r = factors[v]
                if not r then
                    return ""
                end
                local cols = numButtons / r
                return r .. " Row" .. (r > 1 and "s" or "") .. " (" .. cols .. " Col" .. (cols > 1 and "s" or "") .. ")"
            end,
            onChange = function(val)
                local r = factors[val]
                if r then
                    self:SetSetting(systemIndex, "Rows", r)
                    if self.ApplySettings then
                        self:ApplySettings()
                    end
                end
            end,
        })
    end

    -- 3. Padding
    table.insert(schema.controls, {
        type = "slider",
        key = "Padding",
        label = "Nav Padding",
        min = -5,
        max = 5,
        step = 1,
        default = -5,
    })

    -- 4. Opacity
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create Container
    self.frame = CreateFrame("Frame", "OrbitMicroMenuContainer", UIParent)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Menu Bar"
    self.frame:SetSize(300, 40) -- Initial size
    self.frame:SetClampedToScreen(true) -- Prevent dragging off-screen

    -- Anchor Options: Allow anchoring but disable property sync
    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
        syncScale = false,
        syncDimensions = false,
    }

    -- Default Position
    self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 40)

    -- Register to Orbit
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()

    -- Hook AddButton to catch late additions
    if MicroMenu and MicroMenu.AddButton then
        hooksecurefunc(MicroMenu, "AddButton", function(f, button)
            self:CaptureButton(button)
        end)
    end

    -- Initial Capture
    self:ReparentAll()

    -- Listen for Main Menu updates (Store button enable/disable etc changes visibility)
    -- UpdateMicroButtons() is the global trigger.
    -- Listen for Main Menu updates (Store button enable/disable etc changes visibility)
    -- UpdateMicroButtons() is the global trigger.
    hooksecurefunc("UpdateMicroButtons", function()
        -- Debounce and check if a layout update is actually needed
        -- This prevents flickering when clicking buttons (which triggers an update but no layout change)
        if self.updateTimer then
            self.updateTimer:Cancel()
        end
        self.updateTimer = C_Timer.NewTimer(0.1, function()
            if InCombatLockdown() then
                return
            end

            -- Only re-apply if the number of visible buttons changed
            -- or if we suspect a new button appeared that we missed.
            -- Count current managed visible buttons vs actual visible buttons?
            -- Simplest efficient check:
            local currentCount = self:CountButtons()
            -- If we stored the last count, we could compare.

            if currentCount ~= self.lastButtonCount then
                self:ApplySettings()
                self.lastButtonCount = currentCount
            end
        end)
    end)
end

-- [ LOGIC ]-----------------------------------------------------------------------------------------
function Plugin:CaptureButton(button)
    if not button then
        return
    end
    if InCombatLockdown() then
        return
    end

    -- Filter out QueueStatusButton (handled by QueueStatus plugin)
    if button == QueueStatusButton then
        return
    end

    -- Reparent
    if button:GetParent() ~= self.frame then
        button:SetParent(self.frame)
        button:Show()
    end
end

function Plugin:ReparentAll()
    if not MicroMenu then
        return
    end

    -- 1. Check MicroMenu children
    local children = { MicroMenu:GetChildren() }
    for _, child in ipairs(children) do
        if IsMicroButton(child) then
            self:CaptureButton(child)
        end
    end

    -- 2. Check Standard Global Names (just in case)
    local standardButtons = {
        "CharacterMicroButton",
        "ProfessionMicroButton",
        "PlayerSpellsMicroButton",
        "AchievementMicroButton",
        "QuestLogMicroButton",
        "GuildMicroButton",
        "LFDMicroButton",
        "CollectionsMicroButton",
        "EJMicroButton",
        "StoreMicroButton",
        "MainMenuMicroButton",
    }

    for _, name in ipairs(standardButtons) do
        local btn = _G[name]
        if btn then
            self:CaptureButton(btn)
        end
    end

    -- Hide Native Container to avoid ghosting (Wait, if we steal children, it's empty?)
    -- MicroMenuContainer has logic.
    -- Better to strip children and leave it empty so it collapses.
end

function Plugin:CountButtons()
    if not self.frame then
        return 12
    end
    local count = 0
    local children = { self.frame:GetChildren() }
    for _, child in ipairs(children) do
        if child:IsShown() and IsMicroButton(child) and child ~= QueueStatusButton then
            count = count + 1
        end
    end
    return count
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then
        return
    end
    if InCombatLockdown() then
        return
    end

    -- Visibility Guard
    if C_PetBattles and C_PetBattles.IsInBattle() then
        frame:Hide()
        return
    end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        frame:Hide()
        return
    end

    -- Get settings
    local scale = self:GetSetting(SYSTEM_ID, "Scale") or 100
    local padding = self:GetSetting(SYSTEM_ID, "Padding") or -5
    local rows = self:GetSetting(SYSTEM_ID, "Rows") or 1

    self:ReparentAll()

    -- Sort buttons by layoutIndex
    local buttons = {}
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        -- Only include visible buttons? layoutIndex implies order.
        -- UpdateMicroButtons() shows/hides them based on level.
        -- We should only include SHOWN buttons in the grid.
        if child:IsShown() and IsMicroButton(child) and child ~= QueueStatusButton then
            table.insert(buttons, child)
        end
    end

    table.sort(buttons, function(a, b)
        local ia = a.layoutIndex or 99
        local ib = b.layoutIndex or 99
        return ia < ib
    end)

    -- Layout
    local numButtons = #buttons
    if numButtons == 0 then
        frame:Hide()
        return
    end

    frame:Show()
    frame:SetScale(scale / 100)

    local w = 28 -- Approximate width of micro button (art is larger, but stride uses smaller)
    local h = 36
    -- Actual sizes vary?
    -- CharacterMicroButton: GetWidth() ?
    -- Usually they are uniform.
    if buttons[1] then
        w = buttons[1]:GetWidth()
        h = buttons[1]:GetHeight()
    end

    -- Grid Calculation
    local cols = math.ceil(numButtons / rows)

    for i, button in ipairs(buttons) do
        button:ClearAllPoints()

        -- Compute Row/Col
        -- Index 1..N
        -- Row-major?
        -- If 1 Row: 1 2 3 ...
        -- If 2 Row:
        -- 1 2 3 4 5 6
        -- 7 8 9 ...

        -- Row = ceil(i / cols)
        -- Col = (i-1) % cols + 1

        local row = math.ceil(i / cols)
        local col = (i - 1) % cols + 1

        local x = (col - 1) * (w + padding)
        local y = (row - 1) * (h + padding) * -1 -- Downward

        button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    end

    -- Set Container Size
    local finalW = (cols * w) + ((cols - 1) * padding)
    local finalH = (rows * h) + ((rows - 1) * padding)
    frame:SetSize(math.max(finalW, 1), math.max(finalH, 1))

    -- Apply MouseOver
    self:ApplyMouseOver(frame, SYSTEM_ID)

    -- Handle Standard Native Hiding
    local nativeFrames = { MicroMenu, MicroMenuContainer }
    for _, f in ipairs(nativeFrames) do
        if f then
            OrbitEngine.NativeFrame:SecureHide(f)
            -- Failsafe: Move offscreen if allowed (SecureHide might do this, but being explicit helps)
            if not InCombatLockdown() then
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9000, 9000)
            end
        end
    end
end
