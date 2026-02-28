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
})

-- Apply NativeBarMixin for mouseOver helpers
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function IsMicroButton(frame)
    if not frame then
        return false
    end
    if frame.layoutIndex then
        return true
    end
    local name = frame:GetName()
    return name and name:find("MicroButton") or false
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- 1. Scale
    SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
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
        max = 15,
        step = 1,
        default = -5,
    })

    -- 4. Opacity
    SB:AddOpacitySettings(self, schema, systemIndex, systemFrame)

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
    self.mountedConfig = { frame = self.frame, hoverReveal = true }

    -- Hook AddButton to catch late additions
    if MicroMenu and MicroMenu.AddButton then
        hooksecurefunc(MicroMenu, "AddButton", function(f, button)
            self:CaptureButton(button)
        end)
    end

    -- Initial Capture
    self:ReparentAll()

    -- Listen for Main Menu updates
    hooksecurefunc("UpdateMicroButtons", function()
        if self.updateTimer then
            self.updateTimer:Cancel()
        end
        self.updateTimer = C_Timer.NewTimer(0.1, function()
            if InCombatLockdown() then
                return
            end
            local currentCount = self:CountButtons()
            if currentCount ~= self.lastButtonCount then
                self:ApplySettings()
                self.lastButtonCount = currentCount
            end
        end)
    end)
end

-- [ LOGIC ]-----------------------------------------------------------------------------------------
function Plugin:CaptureButton(button)
    if not button or InCombatLockdown() or button == QueueStatusButton then
        return
    end
    if button:GetParent() ~= self.frame then
        button:SetParent(self.frame)
        button:Show()
    end
end

function Plugin:ReparentAll()
    if not MicroMenu then
        return
    end

    local children = { MicroMenu:GetChildren() }
    for _, child in ipairs(children) do
        if IsMicroButton(child) then
            self:CaptureButton(child)
        end
    end

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
end

function Plugin:CountButtons()
    if not self.frame then
        return 12
    end
    local count = 0
    for _, child in ipairs({ self.frame:GetChildren() }) do
        if child:IsShown() and IsMicroButton(child) and child ~= QueueStatusButton then
            count = count + 1
        end
    end
    return count
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame or InCombatLockdown() then
        return
    end
    if (C_PetBattles and C_PetBattles.IsInBattle()) or (UnitHasVehicleUI and UnitHasVehicleUI("player")) then
        frame:Hide()
        return
    end

    local scale, padding, rows =
        self:GetSetting(SYSTEM_ID, "Scale") or 100, self:GetSetting(SYSTEM_ID, "Padding") or -5, self:GetSetting(SYSTEM_ID, "Rows") or 1
    self:ReparentAll()
    local buttons = {}
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsShown() and IsMicroButton(child) and child ~= QueueStatusButton then
            table.insert(buttons, child)
        end
    end
    table.sort(buttons, function(a, b)
        return (a.layoutIndex or 99) < (b.layoutIndex or 99)
    end)

    local numButtons = #buttons
    if numButtons == 0 then
        frame:Hide()
        return
    end

    frame:Show()
    frame:SetScale(scale / 100)

    local w, h = 28, 36
    if buttons[1] then
        w, h = buttons[1]:GetWidth(), buttons[1]:GetHeight()
    end
    local cols = math.ceil(numButtons / rows)
    for i, button in ipairs(buttons) do
        button:ClearAllPoints()
        local row, col = math.ceil(i / cols), (i - 1) % cols + 1
        local x = OrbitEngine.Pixel:Snap((col - 1) * (w + padding), frame:GetEffectiveScale())
        local y = OrbitEngine.Pixel:Snap((row - 1) * (h + padding) * -1, frame:GetEffectiveScale())
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    end

    local finalW, finalH = (cols * w) + ((cols - 1) * padding), (rows * h) + ((rows - 1) * padding)
    frame:SetSize(math.max(finalW, 1), math.max(finalH, 1))
    self:ApplyMouseOver(frame, SYSTEM_ID)

    for _, f in ipairs({ MicroMenu, MicroMenuContainer }) do
        if f then
            OrbitEngine.NativeFrame:SecureHide(f)
            if not InCombatLockdown() then
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9000, 9000)
            end
        end
    end
end
