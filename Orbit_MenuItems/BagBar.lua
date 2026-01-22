---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_BagBar"

local Plugin = Orbit:RegisterPlugin("Bag Bar", SYSTEM_ID, {
    defaults = {
        Scale = 100,
        Opacity = 100,
        MouseOver = false,
        Orientation = Enum.BagsOrientation.Horizontal,
        Direction = Enum.BagsDirection.Left,
    },
}, Orbit.Constants.PluginGroups.MenuItems)

-- Apply NativeBarMixin for mouseOver helpers
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local WL = OrbitEngine.WidgetLogic

    local currentOrientation = self:GetSetting(systemIndex, "Orientation")

    -- Direction options depend on orientation
    local dirOpts
    if currentOrientation == Enum.BagsOrientation.Horizontal then
        dirOpts = {
            { text = "Expand Left", value = Enum.BagsDirection.Left },
            { text = "Expand Right", value = Enum.BagsDirection.Right },
        }
    else
        dirOpts = {
            { text = "Expand Up", value = Enum.BagsDirection.Up },
            { text = "Expand Down", value = Enum.BagsDirection.Down },
        }
    end

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- 1. Orientation
    WL:AddOrientationSettings(self, schema, systemIndex, dialog, systemFrame, {
        options = {
            { text = "Horizontal", value = Enum.BagsOrientation.Horizontal },
            { text = "Vertical", value = Enum.BagsOrientation.Vertical },
        },
        default = Enum.BagsOrientation.Horizontal,
        onChange = function(val)
            self:SetSetting(systemIndex, "Orientation", val)

            if val == Enum.BagsOrientation.Horizontal then
                self:SetSetting(systemIndex, "Direction", Enum.BagsDirection.Left)
            else
                self:SetSetting(systemIndex, "Direction", Enum.BagsDirection.Up)
            end
            self:ApplySettings()

            OrbitEngine.Layout:Reset(dialog)
            self:AddSettings(dialog, systemFrame)
        end,
    })

    -- 2. Direction (Grow)
    table.insert(schema.controls, {
        type = "dropdown",
        key = "Direction",
        label = "Grow",
        options = dirOpts,
        default = Enum.BagsDirection.Left,
    })

    -- 3. Scale
    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "Scale",
        label = "Scale",
        default = 100,
        min = 50,
        max = 150,
    })

    -- 4. Opacity
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create Container
    self.frame = CreateFrame("Frame", "OrbitBagBarContainer", UIParent)
    self.frame:SetSize(200, 40) -- Initial size, will be resized to fit content
    self.frame:SetClampedToScreen(true) -- Prevent dragging off-screen
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Bag Bar"

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

    -- Delay initial capture to ensure BagsBar exists
    C_Timer.After(0.1, function()
        self:ReparentAll()
        self:ApplySettings()
    end)
end

-- [ LOGIC ]-----------------------------------------------------------------------------------------
function Plugin:ReparentAll()
    if not BagsBar then
        return
    end
    if InCombatLockdown() then
        return
    end

    -- Reparent BagsBar into our container
    if BagsBar:GetParent() ~= self.frame then
        BagsBar:SetParent(self.frame)
    end

    BagsBar:ClearAllPoints()
    BagsBar:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    BagsBar:Show()
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

    -- Visibility Guard (Pet Battle / Vehicle)
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
    local opacity = self:GetSetting(SYSTEM_ID, "Opacity") or 100
    local orientation = self:GetSetting(SYSTEM_ID, "Orientation")
    local direction = self:GetSetting(SYSTEM_ID, "Direction")

    -- Ensure reparented
    self:ReparentAll()

    -- Apply Scale and Opacity to container
    frame:SetScale(scale / 100)
    frame:SetAlpha(opacity / 100)
    frame:Show()

    -- Apply orientation and direction to BagsBar
    if BagsBar then
        -- Apply orientation using Mixin helper
        self:ApplyOrientation(BagsBar, orientation, Enum.BagsOrientation.Horizontal)

        -- Direction (BagBar-specific)
        BagsBar.direction = direction

        -- Trigger layout using Mixin helper
        self:TriggerLayout(BagsBar)

        -- Resize container to match BagsBar content
        local w, h = BagsBar:GetSize()
        if w and h and w > 0 and h > 0 then
            frame:SetSize(w, h)
        end
    end

    -- Apply MouseOver
    self:ApplyMouseOver(frame, SYSTEM_ID)
end
